#!/bin/bash
set -euo pipefail
_PROJECT="${1:?}"
_SCHEME="${2:?}"
UDID="${3:?}"

echo "platform=iOS Simulator,id=${UDID}"
