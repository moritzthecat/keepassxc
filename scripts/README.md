# Remote sync helper scripts (examples)

These are **examples**, not part of KeePassXC. They show one way to implement the
download and upload commands for a shared database on a network share. Replace the
paths with your own.

## Files

| File | Platform |
|---|---|
| `sync.sh` | macOS / Linux (POSIX shell) |
| `sync.ps1` | Windows (PowerShell) |
| `sync.cmd` | Windows wrapper around `sync.ps1` |

## Configure

`sync.sh` — two lines at the top, or set `KPXC_SHARE_DIR` / `KPXC_SHARE_FILE` in the environment:

```sh
SHARE_DIR="/Volumes/MyShare/keepassxc"
SHARE_FILE="$SHARE_DIR/keepassxc-shared.kdbx"
```

`sync.ps1` — two lines at the top:

```powershell
$ShareDir  = '\\MyServer\keepassxc'   # or 'Z:\keepassxc' if the share is mapped
$ShareFile = 'keepassxc-shared.kdbx'
```

## Wire them into KeePassXC

**Database → Remote sync → Add profile**

macOS / Linux:

```
/path/to/sync.sh download {TEMP_DATABASE}
/path/to/sync.sh upload   {TEMP_DATABASE}
```

Windows (explicit is safer than the `.cmd` wrapper):

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\keepassxc\sync.ps1" download {TEMP_DATABASE}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\keepassxc\sync.ps1" upload   {TEMP_DATABASE}
```

`{TEMP_DATABASE}` is replaced by KeePassXC with the path of the local temporary copy.
The commands are executed directly, without a shell.

## First run

The scripts do not create the file on the share. Copy your database to the share once,
by hand. Until that is done the sync exits with code 3.

## Exit codes

| Code | Meaning | Effect |
|---|---|---|
| 0 | success | success banner |
| 1 | the share is not connected | error banner, sync aborted, local file untouched |
| 2 | usage error | error banner |
| 3 | the database file does not exist on the share yet | error banner |
| 4 | the backup of the existing remote file failed | upload aborted, remote file untouched |
| 5 | the file copy failed (Windows only) | upload aborted, remote file untouched |

## What the scripts guarantee

- **A backup before every upload** that overwrites an existing remote file. The
  previous remote file is kept as `<name>.kdbx.bak`. It is written to a temporary file
  and renamed, so the backup is never a partial file. The very first upload to an empty
  share creates no backup, because there is nothing to back up.
- **Atomic replace.** The upload writes to `kpxc-sync.tmp` and then renames, so the
  remote file is either the old version or the new one, never half-written.
- **No silent failure.** Every failure writes to stderr, which KeePassXC shows in the
  banner together with the exit code.

## Notes

- Automatic retries are not implemented and are not needed: the trigger moments are
  open, save and close, so the next save or lock tries again.
- The backup file lives on the share. If several clients sync the same database, the
  backup reflects the last upload, not the state of a particular client.
