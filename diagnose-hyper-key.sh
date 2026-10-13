#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Diagnose Hyper Key
# @raycast.mode fullOutput
# @raycast.packageName Raycast Hyper Key
# @raycast.description Check Secure Input, keyboard mappings, and the last Hyper Key reset.
set -eu
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
exec /bin/bash "$SCRIPT_DIR/reset-hyper-key.sh" --diagnose
