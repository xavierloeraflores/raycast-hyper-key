# Raycast Hyper Key recovery

Two Raycast Script Commands for diagnosing an unresponsive Hyper Key and restarting Raycast to reload its keyboard handling.

| Command | What it does |
| --- | --- |
| **Diagnose Hyper Key** | Reports Secure Input status, available ownership hints, connected keyboards, key mappings, and the last reset result. |
| **Reset Hyper Key** | Checks for Secure Input, then closes and reopens Raycast using a one-time background job. |

Restarting can help when Raycast's keyboard handling or device mappings stop working. It is a recovery step, not a fix for every Hyper Key problem.

## Requirements

- macOS with a logged-in desktop session.
- Raycast installed at `/Applications/Raycast.app`.
- Python 3 available at `/usr/bin/python3`. The scripts use only its standard library.
- Hyper Key already configured in Raycast.

Check Python before installing:

```sh
/usr/bin/python3 --version
```

The scripts were tested on one Mac running macOS 26.5.2 and Raycast 1.104.31. Other versions have not been verified. The saved-settings diagnostic reads a Raycast v1 preference; a missing value on another version does not establish that Hyper Key is disabled.

## Install in Raycast

1. Download or clone this repository into a folder you intend to keep. Keep both `.sh` files together.
2. From that folder, make the scripts executable:

   ```sh
   chmod +x reset-hyper-key.sh diagnose-hyper-key.sh
   ```

3. Open **Raycast Settings → Extensions → + → Add Script Directory** and select that folder.
4. Open Raycast and search for **Diagnose Hyper Key**. Run it to verify the installation.
5. Confirm **Reset Hyper Key** also appears in search.

Use your usual Raycast launcher shortcut to reach these commands. If you assign a recovery shortcut, choose one that does not depend on Hyper Key.

## Use

When Hyper Key fails, run **Diagnose Hyper Key** first so you can inspect the state before changing it. If Secure Input is off, run **Reset Hyper Key**. Raycast will close and reopen after a short delay. Try a physical Hyper Key shortcut afterward.

Resetting interrupts active Raycast commands and AI tasks. Wait for any work you want to preserve to finish before running it.

You can also run the commands from this repository in Terminal:

```sh
# Read-only diagnostics
./diagnose-hyper-key.sh

# Restart Raycast
./reset-hyper-key.sh
```

### When Secure Input is active

macOS Secure Input can prevent Hyper Key from working. The reset command reports this condition and stops, because restarting Raycast cannot release another app's Secure Input session.

Leave password fields or dismiss authentication dialogs, then retry. If an app keeps Secure Input active, save your work and quit/reopen that app. If the owner is `loginwindow`, try locking and unlocking the Mac. Do not terminate `loginwindow`.

Owner detection is best-effort and can be unavailable or stale. Newer Raycast versions offer Secure Input Compatibility with limitations described in the [Hyper Key manual](https://manual.raycast.com/hyper-key).

## Agent prompt instructions

Give the following prompt to an agent that has access to your Mac and this repository:

```text
Install this repository's two Script Commands in my existing Raycast setup.

1. Read README.md and both shell scripts. Resolve the repository's actual
   absolute path; do not assume another user's username or directory layout.
2. Verify macOS, /Applications/Raycast.app, and /usr/bin/python3. Report missing
   prerequisites rather than installing software or changing system permissions.
3. Keep reset-hyper-key.sh and diagnose-hyper-key.sh together in this folder.
   Run bash -n on both files and make both executable with chmod +x.
4. In Raycast Settings > Extensions, check whether this folder is already a
   Script Directory. If absent, use + > Add Script Directory to add it once.
   Preserve all existing directories, shortcuts, and Hyper Key preferences.
   Use the supported UI rather than editing Raycast's internal database.
5. Search Raycast for Diagnose Hyper Key and run it. Confirm that diagnostic
   output appears. An active Secure Input warning is a diagnostic finding,
   not proof that installation failed.
6. Confirm Reset Hyper Key appears in Raycast search. Do not run the reset
   as part of installation; it interrupts active Raycast work. Do not assign
   shortcuts unless I request them, and never make recovery depend on Hyper Key.
7. Report the installed folder, commands found, and any verification limits.
   If UI automation is unavailable, provide the exact folder path and manual
   installation steps. Do not claim the commands are installed without evidence.

Keep diagnostic output local unless I explicitly ask to share it. Do not
commit logs, upload diagnostics, update Raycast, or change security settings.
```

## How the reset works

The script checks Secure Input, copies a worker into the current user's cache, and starts it through `launchd`. That worker survives Raycast exiting. It checks the target executable, sends `SIGTERM` to the current user's Raycast process, waits up to ten seconds for it to exit, and reopens `/Applications/Raycast.app`.

The job runs once, with automatic restarts disabled. It does not persist across login. The script does not directly rewrite keyboard mappings, delete preferences, force-kill Raycast, or reset permissions. It makes no network requests and requires no administrator access.

The worker and the two most recent reset logs are stored in:

```text
~/Library/Caches/local.raycast.hyperkey-reset/
```

A successful reset log confirms Raycast relaunched. Only trying your physical shortcut confirms that Hyper Key works again.

## Privacy and sharing diagnostics

Diagnostic output can contain application paths, process IDs, keyboard models, device identifiers, and local timestamps. Review and redact it before posting an issue. Runtime files live outside the repository; `.gitignore` also excludes common log and diagnostic folders if copied here.

## Uninstall

Remove this folder from Raycast's Script Directories. You can then delete the repository folder and its cache directory. To unload a reset job that is still registered, run:

```sh
launchctl remove "local.raycast.hyperkey-reset.$UID"
```

If the job has already finished, a service-not-found response is expected. Removing the commands does not change your Hyper Key preferences.

## References

- [Raycast Script Commands and installation](https://github.com/raycast/script-commands)
- [Raycast v1 Hyper Key troubleshooting](https://manual.raycast.com/v1/hyper-key)
- [Current Hyper Key documentation](https://manual.raycast.com/hyper-key)

This is an independent utility and is not affiliated with Raycast.
