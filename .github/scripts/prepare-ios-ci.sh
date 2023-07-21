#!/bin/bash
set -euo pipefail

sudo xcodebuild -runFirstLaunch

sudo launchctl kickstart -k system/com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true

echo "=== simctl runtimes ==="
xcrun simctl list runtimes || true

download_ios_platform() {
  local attempt=1
  local max_attempts=5
  while [[ "$attempt" -le "$max_attempts" ]]; do
    if xcodebuild -downloadPlatform iOS; then
      echo "=== downloadPlatform iOS succeeded ==="
      xcrun simctl list runtimes || true
      xcrun simctl list devices available | head -40 || true
      return 0
    fi
    echo "downloadPlatform failed (attempt $attempt/$max_attempts), retry in 45s..."
    sleep 45
    attempt=$((attempt + 1))
  done
  return 1
}

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo "=== GITHUB_ACTIONS: download iOS platform for selected Xcode ==="
  download_ios_platform || {
    echo "warning: downloadPlatform failed; continuing anyway" >&2
  }
  exit 0
fi

if python3 - <<'PY'
import json, subprocess
try:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        text=True,
    )
except subprocess.CalledProcessError:
    raise SystemExit(1)
data = json.loads(raw)
for devs in data.get("devices", {}).values():
    for d in devs:
        if d.get("isAvailable") and "iPhone" in (d.get("name") or ""):
            raise SystemExit(0)
raise SystemExit(1)
PY
then
  echo "=== iPhone simulator already available — skip downloadPlatform ==="
  xcrun simctl list devices available | head -40 || true
  exit 0
fi

download_ios_platform || {
  echo "error: xcodebuild -downloadPlatform iOS failed" >&2
  exit 1
}
