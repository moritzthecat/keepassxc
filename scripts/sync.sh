#!/bin/sh
# sync.sh — KeePassXC 2.8 Remote Sync (download + upload in one script)
#
# KeePassXC invokes the command WITHOUT a shell:
#   /path/to/sync.sh download {TEMP_DATABASE}     remote -> local temp copy
#   /path/to/sync.sh upload   {TEMP_DATABASE}     local temp copy -> remote
#
# Exit codes (the KeePassXC banner shows "exited with status code: N"):
#   1 = share not connected
#   2 = usage error
#   3 = database file missing on the share (first run: copy your local file once)
#   4 = backup of the existing remote file failed (upload aborted, remote untouched)
#   => an error banner is shown, the sync is aborted, the local database is untouched.
#
# Upload safety: before overwriting, the current remote file is kept as a rolling
# single backup (.bak, written atomically so a .bak is never a partial file).
# The remote file always exists at upload time: the workflow downloads first and
# aborts with exit 3 if the file is missing.

set -u

# ---------------------------------------------------------------------------
# EDIT THESE TWO LINES (or set KPXC_SHARE_DIR / KPXC_SHARE_FILE in the environment)
#   mount point of your share, e.g. /Volumes/MyShare/keepassxc
#   name of the database file on the share
# ---------------------------------------------------------------------------
SHARE_DIR="${KPXC_SHARE_DIR:-/Volumes/MyShare/keepassxc}"
SHARE_FILE="${KPXC_SHARE_FILE:-$SHARE_DIR/keepassxc-shared.kdbx}"

[ -d "$SHARE_DIR" ] || { echo "share not connected: $SHARE_DIR" >&2; exit 1; }

case "$1" in
    download)
        [ -f "$SHARE_FILE" ] || { echo "database file missing on the share: $SHARE_FILE" >&2; exit 3; }
        cp "$SHARE_FILE" "$2"
        ;;
    upload)
        # Keep the current remote file as a backup before overwriting it.
        # rsync -t preserves the original timestamp (cp -p does not work on
        # some SMB shares); temp + rename so the .bak is never partial.
        if [ -f "$SHARE_FILE" ]; then
            if ! { rsync -t "$SHARE_FILE" "$SHARE_DIR/kpxc-sync.bak.tmp" &&
                  mv "$SHARE_DIR/kpxc-sync.bak.tmp" "$SHARE_FILE.bak"; }; then
                rm -f "$SHARE_DIR/kpxc-sync.bak.tmp"
                echo "backup of $SHARE_FILE failed - aborting upload" >&2
                exit 4
            fi
        fi
        # Atomic replace: temp file + rename on the same filesystem
        cp "$2" "$SHARE_DIR/kpxc-sync.tmp" && mv "$SHARE_DIR/kpxc-sync.tmp" "$SHARE_FILE"
        ;;
    *)
        echo "usage: $0 {download|upload} {TEMP_DATABASE}" >&2
        exit 2
        ;;
esac

exit 0
