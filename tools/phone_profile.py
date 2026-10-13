"""Read-only Android power/CPU/GPU sampling and KGPROF capture over ADB.

Battery watts are net battery discharge, not app-only consumption. Keep both
displays, brightness, refresh rate, radios and game context equal across runs.
Wireless ADB and sampling add overhead; use the same collector for every phase.
"""
import argparse
import json
from pathlib import Path
import subprocess
import threading
import time


SAMPLE = r'''
pid=$(pidof com.theboisclub.pokemonred)
read -r up idle < /proc/uptime
printf 'uptime %s\n' "$up"
for f in /sys/class/power_supply/battery/current_now /sys/class/power_supply/battery/voltage_now /sys/class/power_supply/battery/temp /sys/class/power_supply/battery/status /sys/class/kgsl/kgsl-3d0/gpubusy /sys/class/kgsl/kgsl-3d0/gpuclk /sys/class/kgsl/kgsl-3d0/temp /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do
  value=unavailable
  read -r value < "$f" 2>/dev/null
  printf '%s %s\n' "$f" "$value"
done
if [ -n "$pid" ]; then
  read -r stat < /proc/$pid/stat
  printf 'process %s\n' "$stat"
  cat /proc/$pid/task/*/stat 2>/dev/null
fi
'''


def proc_stat(text):
    end = text.rindex(')')
    fields = text[end + 2:].split()
    return {"id": int(text.split(' ', 1)[0]), "name": text[text.index('(') + 1:end],
            "ticks": int(fields[11]) + int(fields[12]), "start": int(fields[19])}


def parse_sample(text):
    row = {"threads": {}, "sensors": {}}
    for line in text.splitlines():
        key, _, value = line.partition(' ')
        if (key in {'process', 'thread'} or key.isdigit()) and value:
            stat = proc_stat(line if key.isdigit() else value)
            if key == 'process':
                row['process'] = stat
            else:
                row['threads'][str(stat['id'])] = stat
        elif key == 'uptime':
            row['uptime'] = float(value.split()[0])
        elif key.startswith('/sys/'):
            row['sensors'][key] = value.strip()
    sensors = row['sensors']
    try:
        current = int(sensors['/sys/class/power_supply/battery/current_now'])
        voltage = int(sensors['/sys/class/power_supply/battery/voltage_now'])
        if sensors.get('/sys/class/power_supply/battery/status') == 'Discharging':
            row['battery_discharge_w'] = -current * voltage / 1e12
    except (KeyError, ValueError):
        pass
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--serial', required=True)
    parser.add_argument('--seconds', type=int, default=60)
    parser.add_argument('--label', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 3600:
        parser.error('seconds must be between 1 and 3600')
    adb = [args.adb, '-s', args.serial]
    identity = subprocess.check_output(adb + ['shell', 'getprop', 'ro.serialno'], timeout=10).decode().strip()
    ticks = int(subprocess.check_output(adb + ['shell', 'getconf', 'CLK_TCK'], timeout=10))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    log_path = args.output.with_suffix('.log')
    logcat = subprocess.Popen(adb + ['logcat', '-v', 'epoch', '-T', '1', '-s', 'SDL/APP:I'],
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

    def logs():
        with log_path.open('w', encoding='utf-8') as output:
            for raw in iter(logcat.stdout.readline, b''):
                line = raw.decode('utf-8', errors='replace')
                if 'KGPROF ' in line:
                    output.write(line)
                    output.flush()

    reader = threading.Thread(target=logs, daemon=True)
    reader.start()
    start = time.monotonic()
    previous = None
    with args.output.open('w', encoding='utf-8') as output:
        output.write(json.dumps({'kind': 'capture', 'label': args.label, 'device_serial': identity,
                                 'utc_epoch': time.time(), 'clock_ticks_per_second': ticks,
                                 'sampling': '1 Hz; wireless ADB overhead included'}) + '\n')
        try:
            while time.monotonic() - start < args.seconds:
                sampled = time.monotonic()
                raw = subprocess.run(adb + ['shell', SAMPLE], capture_output=True, timeout=10)
                if raw.returncode:
                    raise RuntimeError(raw.stderr.decode(errors='replace'))
                row = parse_sample(raw.stdout.decode(errors='replace'))
                row.update(kind='sample', utc_epoch=time.time(), elapsed_s=sampled-start,
                           collection_ms=(time.monotonic()-sampled)*1000)
                if previous and row.get('uptime', 0) > previous.get('uptime', 0):
                    elapsed = row['uptime'] - previous['uptime']
                    for name in ('process',):
                        current, before = row.get(name), previous.get(name)
                        if current and before and (current['id'], current['start']) == (before['id'], before['start']):
                            current['cpu_percent_one_core'] = (current['ticks']-before['ticks'])/ticks/elapsed*100
                    for tid, current in row['threads'].items():
                        before = previous['threads'].get(tid)
                        if before and before['start'] == current['start']:
                            current['cpu_percent_one_core'] = (current['ticks']-before['ticks'])/ticks/elapsed*100
                output.write(json.dumps(row) + '\n')
                output.flush()
                previous = row
                time.sleep(max(0, 1-(time.monotonic()-sampled)))
        finally:
            logcat.terminate()
            logcat.wait(timeout=5)
            reader.join(timeout=5)
    print(f'Captured {args.label}: {args.output}; profiler: {log_path}')


if __name__ == '__main__':
    main()
