#!/bin/bash
set -euo pipefail

export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-15.6}"

UDID="$(python3 <<'PY'
import json, os, subprocess, sys, time
from itertools import zip_longest

MIN_IOS = os.environ["IPHONEOS_DEPLOYMENT_TARGET"]
NAME = "To-Do CI"
DEVICE_TYPES = [
    "com.apple.CoreSimulator.SimDeviceType.iPhone-15",
    "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
    "com.apple.CoreSimulator.SimDeviceType.iPhone-14",
]


def ver_ge(a, b):
    def vp(s):
        return [int(x) for x in s.replace(" ", "").split(".") if x.isdigit()]

    for x, y in zip_longest(vp(a), vp(b), fillvalue=0):
        if x != y:
            return x >= y
    return True


def ver_key(v):
    return tuple(int(x) for x in v.split(".") if x.isdigit())


raw = subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "-j"], text=True)
data = json.loads(raw)
runtimes = [
    r
    for r in data.get("runtimes", [])
    if r.get("isAvailable")
    and str(r.get("name", "")).startswith("iOS")
    and r.get("version")
    and ver_ge(r["version"], MIN_IOS)
]
if not runtimes:
    print("error: no iOS runtime >= %s" % MIN_IOS, file=sys.stderr)
    sys.exit(1)

runtimes.sort(key=lambda r: ver_key(r["version"]))
runtime_id = runtimes[0]["identifier"]
print(
    "Using runtime %s (%s)"
    % (runtimes[0].get("name"), runtime_id),
    file=sys.stderr,
)

raw_d = subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True)
dd = json.loads(raw_d)
for rid, devs in dd.get("devices", {}).items():
    for d in devs:
        if d.get("name") != NAME or not d.get("udid"):
            continue
        if rid == runtime_id:
            print("Found existing %s" % d["udid"], file=sys.stderr)
            print(d["udid"])
            raise SystemExit(0)
        print(
            "Deleting stale %s on other runtime %s" % (d["udid"], rid),
            file=sys.stderr,
        )
        subprocess.run(
            ["xcrun", "simctl", "delete", d["udid"]],
            capture_output=True,
            text=True,
        )

for dt in DEVICE_TYPES:
    try:
        out = subprocess.run(
            ["xcrun", "simctl", "create", NAME, dt, runtime_id],
            text=True,
            capture_output=True,
            check=True,
        )
        udid = out.stdout.strip()
        print("Created %s with %s" % (udid, dt), file=sys.stderr)
        time.sleep(5)
        print(udid)
        raise SystemExit(0)
    except subprocess.CalledProcessError as e:
        print(
            "create failed %s: %s" % (dt, (e.stderr or e.stdout or "")[:300]),
            file=sys.stderr,
        )
        continue

print("error: simctl create failed for all device types", file=sys.stderr)
raise SystemExit(1)
PY
)"

xcrun simctl bootstatus "${UDID}" -b >&2

printf '%s\n' "${UDID}"
