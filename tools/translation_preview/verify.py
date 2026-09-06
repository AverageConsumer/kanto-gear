"""Verify all standard generated language packs against Gear and real LÖVE fonts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--love", required=True)
    parser.add_argument("--luajit", default="luajit")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    engine, fixtures, output = (p.resolve() for p in (args.engine, args.fixtures, args.output))
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, KANTO_GEAR_ROOT=str(root))
    env["KANTO_GEAR_MOD_PATH"] = os.path.relpath(root / "mod/kanto_gear", engine).replace("\\", "/")
    results = []
    startup = None
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE

    def run(name, command, cwd):
        try:
            result = subprocess.run(command, cwd=cwd, env=env, startupinfo=startup,
                                    capture_output=True, timeout=180)
            log = (result.stdout + result.stderr).decode("utf-8", errors="replace")
            code = result.returncode
        except subprocess.TimeoutExpired:
            log, code = "Timed out after 180 seconds", -1
        (output / (name + ".log")).write_text(log, encoding="utf-8")
        results.append({"case": name, "exit_code": code})
        print(name, "PASS" if code == 0 else "FAIL", flush=True)

    packs = {}
    for family, languages, versions in (
        ("rby", ("de", "es", "fr", "it", "ja-Hrkt"), ("red", "blue", "yellow")),
        ("gsc", ("de", "es", "fr", "it", "ja-Hrkt", "ko"), ("gold", "silver", "crystal")),
    ):
        for language in languages:
            key = family + "-" + language
            pack = fixtures / key
            assert (pack / "manifest.json").is_file(), f"Missing generated fixture: {pack}"
            packs[key] = {str(p.relative_to(pack)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sorted(pack.rglob("*")) if p.is_file()}
            env["KANTO_TRANSLATION_MOD"] = os.path.relpath(pack, engine).replace("\\", "/")
            for version in versions:
                env["KANTO_GEAR_TEST_VERSION"] = version
                run(key + "-" + version, [args.luajit, str(root / "mod/kanto_gear/tests/translation_runtime_test.lua")], engine)
            preview = output / key
            preview.mkdir(exist_ok=True)
            for stale in ("checks.txt", "error.txt"):
                (preview / stale).unlink(missing_ok=True)
            env["KANTO_TRANSLATION_MOD"], env["KANTO_TRANSLATION_OUT"] = str(pack), str(preview)
            run(key + "-render", [args.love, str(root / "tools/translation_preview")], root)
            if results[-1]["exit_code"] == 0:
                results[-1]["checks"] = (preview / "checks.txt").read_text(encoding="utf-8")

    def revision(path):
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=path, text=True).strip()

    report = {"gear_commit": revision(root), "engine_commit": revision(engine),
              "gear_tracked_diff": subprocess.check_output(["git", "diff", "HEAD"], cwd=root).decode("utf-8"),
              "fixtures_sha256": packs, "results": results}
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    failures = sum(r["exit_code"] != 0 for r in results)
    print(f"{len(results) - failures}/{len(results)} cases passed; report: {output / 'report.json'}")
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
