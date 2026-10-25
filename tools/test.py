"""Run Gear's Lua fixtures against an explicit, local Recomp SDK checkout."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mod/kanto_gear"
GEN1 = ["red", "blue", "yellow"]
GEN2 = ["gold", "silver", "crystal"]
GEN3 = ["firered", "leafgreen", "emerald", "ruby", "sapphire"]


def editions(name):
    if name == "display_setup_runtime_test": return ["red", "crystal", "firered", "emerald"]
    if name == "phone_runtime_test": return ["red", "crystal", "firered", "emerald"]
    if name.startswith("rs_"): return GEN3[3:]
    if name.startswith("emerald_"): return ["emerald"]
    if name in {"gen3_native_test", "gen3_runtime_test", "gen3_progress_test", "gen3_online_test", "gen3_controls_test"}: return GEN3[:2]
    if name in {"gen3_gifts_test", "gen3_trades_test", "gen3_move_learning_test", "gen3_battle_hints_test", "gen3_relearner_test", "achievement_find3_test"}: return GEN3[:3]
    if name == "gen3_pokeblock_test": return GEN3[2:]
    if name.startswith("gen3_") or name in {"native_dex3_test", "explorer_items3_test", "explorer_snapshot3_test", "held_item_test", "party_storage_test", "unified_summary_test"}: return GEN3
    if name.startswith("gen2_"): return GEN2
    if name.startswith("gen1_"): return GEN1
    if name in {"compat_test", "battle_modes_test", "level_up_runtime_test", "native_dex_test", "touch_companion_test", "party_summary_test", "legacy_party_test", "third_party_modules_test"}: return GEN1 + GEN2
    if name in {"daycare_runtime_test", "calendar_runtime_test", "shiny_hunt_runtime_test", "moments_runtime_test"}: return ["red", "crystal"]
    if name in {"notices_runtime_test", "notice_settings_test"}: return ["crystal"]
    if name in {"home_runtime_test", "motion_runtime_test", "haptics_test", "achievements_test", "bag_runtime_test", "legacy_bag_test", "team_widget_test", "auto_battle_screen_test", "standard_battle_test"}: return ["red", "crystal"]
    return ["red"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True, help="local SDK/cache paths; see test-config.example.json")
    parser.add_argument("--only", help="comma-separated suite names, without .lua")
    parser.add_argument("--edition", choices=GEN1 + GEN2 + GEN3)
    parser.add_argument("--report", type=Path, default=ROOT / "diagnostics/tests/results.json")
    parser.add_argument("--browser", action="store_true", help="also run the headless Phone Display browser suite")
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding="utf-8-sig"))
    host = Path(config["host"]).resolve()
    if not (host / "tests/modkit.lua").exists() and not (host / "tests/modkit/init.lua").exists():
        parser.error("host must contain Recomp's tests/modkit SDK")
    selected = set(args.only.split(",")) if args.only else None
    tests = sorted((MOD / "tests").glob("*_test.lua"))
    if selected and selected - {p.stem for p in tests}:
        parser.error("unknown suites: " + ", ".join(sorted(selected - {p.stem for p in tests})))
    cases = [(ed, p) for p in tests if not selected or p.stem in selected
             for ed in editions(p.stem) if not args.edition or ed == args.edition]
    if not cases: parser.error("no cases match the selected suites/edition")
    args.report.parent.mkdir(parents=True, exist_ok=True)

    def run(case):
        edition, path = case
        generation = "1" if edition in GEN1 else "2" if edition in GEN2 else "3"
        env = dict(os.environ, POKEPORT_VERSION=edition, KANTO_GEAR_TEST_GEN=generation,
                   KANTO_GEAR_TEST_GENERATION=generation, KANTO_GEAR_MOD_PATH=MOD.as_posix())
        if edition in config.get("gba_caches", {}): env["POKEPORT_GBA_CACHE"] = config["gba_caches"][edition]
        if config.get("gen1_data"): env["KANTO_GEAR_NATIVE_GEN1"] = config["gen1_data"]
        if edition in config.get("gen2_data", {}): env["KANTO_GEAR_NATIVE_GEN2"] = config["gen2_data"][edition]
        source = path.read_text(encoding="utf-8")
        sdk = any(token in source for token in ['require("tests.', 'require("src.', "require('tests.", "/tests/"])
        command = [config.get("luajit", "luajit")]
        if sdk:
            env["KANTO_GEAR_MOD_PATH"] = os.path.relpath(MOD, host).replace("\\", "/")
            command.append(str(ROOT / "tools/test_loader.lua"))
        command.append(str(path))
        try:
            result = subprocess.run(command, cwd=host if sdk else ROOT, env=env, capture_output=True, timeout=90)
            log = (result.stdout + result.stderr).decode("utf-8", errors="replace")
            passed = result.returncode == 0 and "FAIL " not in log and "FAILURES" not in log
        except subprocess.TimeoutExpired:
            log, passed = "TIMEOUT after 90 seconds", False
        logfile = args.report.parent / f"{edition}-{path.stem}.log"
        logfile.write_text(log, encoding="utf-8")
        return {"edition": edition, "test": path.stem, "passed": passed, "log": str(logfile)}

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(run, cases))
    if args.browser:
        env = dict(os.environ)
        for key in ("node_modules", "chromium"):
            if config.get(key): env["KANTO_GEAR_" + key.upper()] = config[key]
        browser = subprocess.run([config.get("node", "node"), str(MOD / "tests/phone_browser_test.cjs")],
                                 cwd=ROOT, env=env, capture_output=True, timeout=120)
        log = args.report.parent / "phone-browser.log"
        log.write_bytes(browser.stdout + browser.stderr)
        results.append({"edition": "browser", "test": "phone_browser_test", "passed": browser.returncode == 0, "log": str(log)})
    args.report.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    failed = [r for r in results if not r["passed"]]
    for row in failed: print("FAIL", row["edition"], row["test"], "->", row["log"])
    print(f"{len(results) - len(failed)}/{len(results)} cases passed; report: {args.report}")
    return bool(failed)


if __name__ == "__main__":
    sys.exit(main())
