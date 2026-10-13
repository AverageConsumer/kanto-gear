"""Compile Lua sources and report the size of the production code."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mod/kanto_gear"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luajit", default="luajit")
    parser.add_argument("--report", type=Path, default=ROOT / "diagnostics/structure.json")
    args = parser.parse_args()
    temporary_root = ROOT / "diagnostics"
    temporary_root.mkdir(exist_ok=True)
    rows, errors = [], []
    sources = sorted(MOD.rglob("*.lua"))
    with tempfile.TemporaryDirectory(prefix="gear-check-", dir=temporary_root) as temporary:
        for path in sources:
            result = subprocess.run([args.luajit, "-b", str(path), str(Path(temporary) / "check.bin")], capture_output=True)
            if result.returncode: errors.append(result.stderr.decode("utf-8", errors="replace"))
            if "tests" not in path.relative_to(MOD).parts:
                rows.append({"path": path.relative_to(ROOT).as_posix(),
                             "lines": len(path.read_text(encoding="utf-8").splitlines()), "bytes": path.stat().st_size})
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    for error in errors: print(error)
    print(f"Lua: {len(sources) - len(errors)}/{len(sources)} compile; production: {sum(r['lines'] for r in rows)} lines")
    for row in sorted(rows, key=lambda r: r["lines"], reverse=True)[:8]: print(row["lines"], row["path"])
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
