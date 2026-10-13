#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Reset Hyper Key
# @raycast.mode fullOutput
# @raycast.packageName Raycast Hyper Key
# @raycast.description Restart Raycast to reload Hyper Key; report Secure Input blockers.

set -eu
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename -- "$0")"
APP=/Applications/Raycast.app
LABEL="local.raycast.hyperkey-reset.$UID"
RUNTIME_DIR="$HOME/Library/Caches/local.raycast.hyperkey-reset"
LOG_DIR="$RUNTIME_DIR/logs"

diagnose() {
  /usr/bin/python3 - <<'PY'
import ctypes, datetime, os, plistlib, re, subprocess, sys
print('Checked:', datetime.datetime.now().astimezone().isoformat(timespec='seconds'))
try:
    carbon = ctypes.CDLL('/System/Library/Frameworks/Carbon.framework/Carbon')
    carbon.IsSecureEventInputEnabled.restype = ctypes.c_ubyte
    secure = bool(carbon.IsSecureEventInputEnabled())
except Exception as e:
    print('Could not check Secure Input:', e)
    sys.exit(3)
print('Secure Input:', 'ACTIVE' if secure else 'off')
for path, key, title in [
    ('/Applications/Raycast.app/Contents/Info.plist', 'CFBundleShortVersionString', 'Raycast version'),
    (os.path.expanduser('~/Library/Preferences/com.raycast.macos.plist'), 'raycast_hyperKey_state', 'Saved v1 Hyper Key configuration'),
]:
    try:
        with open(path, 'rb') as f:
            print(title + ':', plistlib.load(f).get(key, 'not present'))
    except Exception as e:
        print(title + ': unavailable:', e)
if secure:
    # Best-effort ownership hint. macOS does not always expose an owner here.
    try:
        registry = subprocess.check_output(['/usr/sbin/ioreg', '-l', '-w', '0'], text=True, timeout=10)
        pids = sorted(set(re.findall(r'"kCGSSessionSecureInputPID"\s*=\s*(\d+)', registry)))
        for pid in pids:
            name = subprocess.run(['/bin/ps', '-p', pid, '-o', 'comm='], capture_output=True, text=True).stdout.strip()
            print('Possible Secure Input owner:', pid, name or 'unavailable')
        if not pids:
            print('macOS did not expose the Secure Input owner.')
    except Exception as e:
        print('Owner lookup unavailable:', e)
    print('Leave password fields and dismiss authentication dialogs, then retry.')
    print('If it remains stuck, quit/reopen the owning app after saving work.')
    print('If loginwindow owns it, try locking and unlocking the Mac. Do not kill loginwindow.')
    print('Restarting Raycast cannot release Secure Input owned by another app.')
sys.exit(2 if secure else 0)
PY
}

raycast_pids() {
  /usr/bin/pgrep -u "$UID" -x Raycast || true
}

case "${1:-}" in
  --diagnose)
    result=0
    diagnose || result=$?
    printf '\nConnected keyboards:\n'
    /usr/bin/hidutil list --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}' || true
    printf '\nPer-keyboard mappings:\n'
    /usr/bin/hidutil property --matching '{"PrimaryUsagePage":1,"PrimaryUsage":6}' --get UserKeyMapping || true
    printf '\nLast reset log:\n'
    if [ -f "$LOG_DIR/latest.log" ]; then /usr/bin/tail -30 "$LOG_DIR/latest.log"; else printf 'No reset has run yet.\n'; fi
    exit "$result"
    ;;
  --worker)
    # launchd owns this worker, so it survives Raycast exiting.
    # LaunchOnlyOnce prevents this worker from restarting itself.
    sleep 2
    diagnose
    old_pids="$(raycast_pids)"
    for pid in $old_pids; do
      actual="$(/bin/ps -p "$pid" -o comm= || true)"
      if [ "$actual" != "$APP/Contents/MacOS/Raycast" ]; then
        printf 'Unexpected Raycast executable: %s. Stopping.\n' "$actual"
        exit 1
      fi
    done
    for pid in $old_pids; do
      printf 'Requesting Raycast termination, PID %s.\n' "$pid"
      /bin/kill -TERM "$pid"
    done
    for ((i=0; i<40; i++)); do
      remaining=false
      for pid in $old_pids; do
        if /bin/kill -0 "$pid" 2>/dev/null; then remaining=true; fi
      done
      if [ "$remaining" = false ]; then break; fi
      sleep 0.25
    done
    if [ "${remaining:-false}" = true ]; then
      printf 'Raycast did not exit within 10 seconds. No force kill was attempted.\n'
      exit 1
    fi
    /usr/bin/open -g "$APP"
    for ((i=0; i<40; i++)); do
      if [ -n "$(raycast_pids)" ]; then
        printf 'Raycast is running again. Try a physical Caps Lock shortcut to verify recovery.\n'
        exit 0
      fi
      sleep 0.25
    done
    printf 'Raycast was opened, but its process was not detected within 10 seconds.\n'
    exit 1
    ;;
  '') ;;
  *) printf 'Usage: %s [--diagnose]\n' "$0"; exit 64 ;;
esac

[ -d "$APP" ] || { printf 'Raycast was not found at %s\n' "$APP"; exit 1; }
diagnose
if /bin/launchctl list "$LABEL" 2>/dev/null | /usr/bin/grep -q '"PID" ='; then
  printf 'A reset is already running. Check Diagnose Hyper Key shortly.\n'
  exit 0
fi
/bin/launchctl remove "$LABEL" 2>/dev/null || true
umask 077
mkdir -p "$LOG_DIR"
# A launchd child cannot inherit Raycast's access to Documents. Stage the worker
# in the user's cache instead of requesting broader privacy permissions.
cp "$SCRIPT_PATH" "$RUNTIME_DIR/worker.sh"
if [ -f "$LOG_DIR/latest.log" ]; then mv -f "$LOG_DIR/latest.log" "$LOG_DIR/previous.log"; fi
/usr/bin/python3 - "$LABEL" "$RUNTIME_DIR" "$LOG_DIR" <<'PY'
import plistlib, sys
label, runtime, logs = sys.argv[1:]
with open(runtime + '/job.plist', 'wb') as f:
    plistlib.dump({
        'Label': label,
        'ProgramArguments': ['/bin/bash', runtime + '/worker.sh', '--worker'],
        'RunAtLoad': True,
        'KeepAlive': False,
        'LaunchOnlyOnce': True,
        'StandardOutPath': logs + '/latest.log',
        'StandardErrorPath': logs + '/latest.log',
    }, f)
PY
/bin/launchctl bootstrap "gui/$UID" "$RUNTIME_DIR/job.plist"
printf '\nReset queued. Raycast will close and reopen in a few seconds.\n'
printf 'Run Diagnose Hyper Key afterward to inspect the result.\n'
