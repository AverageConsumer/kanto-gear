"""Summarize KGPROF lines captured with adb logcat. No external dependencies.

Times are host-call wall times, NOT GPU execution or Android presentation
timestamps. frame_interval is the interval between render.compose calls, which
includes pacing, app suspension and work outside Gear. Scopes overlap: never
sum their timings. p95le/p99le are histogram upper bounds, not exact quantiles.
"""
import argparse
import json
import re
from pathlib import Path


def parse(text):
    runs, windows, current = [], {}, None
    for line in text.splitlines():
        if "KGPROF " not in line:
            continue
        values = dict(re.findall(r"(\w+)=([^\s]+)", line.split("KGPROF ", 1)[1]))
        if values.get("v") != "1":
            continue
        if values.get("kind") == "build":
            current = {"build": values, "windows": []}
            runs.append(current)
            windows = {}
            continue
        if current is None:
            current = {"build": {"version": "capture-started-after-build-marker"}, "windows": []}
            runs.append(current)
        seq = values.get("seq")
        if not seq:
            continue
        window = windows.get(seq)
        if window is None:
            window = {"sequence": seq, "metrics": {}, "complete": False}
            windows[seq] = window
            current["windows"].append(window)
        if values.get("kind") == "window":
            if not all(key in values for key in ("context", "mixed", "at", "seconds", "frames", "bytes", "metrics")):
                continue
            window["expected_metrics"] = int(values["metrics"])
            window["context"] = values["context"]
            window["mixed"] = values["mixed"] == "true"
            for key in ("at", "seconds", "frames", "bytes"):
                window[key] = float(values[key])
        elif values.get("kind") == "metric":
            if not all(key in values for key in ("name", "n", "mean", "p95le", "p99le", "max", "over20", "over34", "over250", "peak")):
                continue
            window["metrics"][values["name"]] = {
                key: values[key] if key == "peak" else float(values[key])
                for key in ("n", "mean", "p95le", "p99le", "max", "over20", "over34", "over250", "peak")
            }
        elif values.get("kind") == "end":
            window["complete"] = "context" in window and window.get("expected_metrics") == len(window["metrics"])
    return runs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    runs = parse(args.log.read_text(encoding="utf-8-sig", errors="replace"))
    if args.json:
        args.json.write_text(json.dumps(runs, indent=2), encoding="utf-8")
    if not runs:
        raise SystemExit("No KGPROF data found; install the diagnostic build and capture its log.")
    for run in runs:
        print("Build:", run["build"].get("version", "unknown"))
        for w in run["windows"]:
            print(f"\nWindow {w['sequence']}: {w.get('context', 'incomplete header')}"
                  f" | complete={w['complete']} mixed={w.get('mixed', 'unknown')}")
            if w.get("seconds", 0) > 0:
                print(f"Transfer: {w['bytes'] / w['seconds'] / 1_000_000:.2f} MB/s")
            print("scope                 calls   mean ms   p99 <= ms    max ms   >20 ms")
            for name, m in w["metrics"].items():
                print(f"{name:22} {m['n']:5.0f} {m['mean']:9.4f} {m['p99le']:11.4f}"
                      f" {m['max']:9.4f} {m['over20']:8.0f}")


if __name__ == "__main__":
    main()
