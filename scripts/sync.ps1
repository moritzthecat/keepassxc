# sync.ps1 — KeePassXC 2.8 Remote Sync (Windows)
#
# KeePassXC invokes the command WITHOUT a shell (QProcess splits the command line):
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\keepassxc\sync.ps1" download {TEMP_DATABASE}
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\keepassxc\sync.ps1" upload   {TEMP_DATABASE}
#
# Exit codes (the KeePassXC banner shows "exited with status code: N"):
#   1 = share not connected
#   2 = usage error
#   3 = database file missing on the share (first run: copy your local file once)
#   4 = backup of the existing remote file failed (upload aborted, remote untouched)
#   5 = file copy failed (permissions, antivirus, SMB quirk)
#   => an error banner is shown, the sync is aborted, the local database is untouched.
#
# Upload safety: before overwriting, the current remote file is kept as a rolling
# single backup (.bak, written atomically so a .bak is never a partial file).

param(
    [string]$Action,
    [string]$TempDb
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# EDIT THESE TWO LINES
#   UNC path  : '\\MyServer\keepassxc'     (network share, no drive letter)
#   mapped    : 'Z:\keepassxc'             (if the share is mapped to a drive)
# ---------------------------------------------------------------------------
$ShareDir  = '\\MyServer\keepassxc'
$ShareFile = 'keepassxc-shared.kdbx'

function Fail([string]$msg, [int]$code) {
    # stderr, so KeePassXC shows it in the error banner
    [Console]::Error.WriteLine($msg)
    exit $code
}

if (-not $Action -or -not $TempDb) {
    Fail("usage: sync.ps1 {download|upload} {TEMP_DATABASE}", 2)
}

$SharePath = Join-Path $ShareDir $ShareFile
$BakPath   = "$SharePath.bak"

if (-not (Test-Path -LiteralPath $ShareDir)) {
    Fail("share not connected: $ShareDir", 1)
}

switch ($Action.ToLower()) {

    'download' {
        if (-not (Test-Path -LiteralPath $SharePath)) {
            Fail("database file missing on the share: $SharePath", 3)
        }
        try {
            Copy-Item -LiteralPath $SharePath -Destination $TempDb -Force
        } catch {
            Fail("download from $SharePath failed: $_", 5)
        }
    }

    'upload' {
        if (-not (Test-Path -LiteralPath $TempDb)) {
            Fail("local temporary database not found: $TempDb", 3)
        }

        # Keep the current remote file as a backup before overwriting it.
        # Atomic (temp + rename) so the .bak is never a partial file.
        if (Test-Path -LiteralPath $SharePath) {
            $bakTmp = Join-Path $ShareDir 'kpxc-sync.bak.tmp'
            try {
                Copy-Item -LiteralPath $SharePath -Destination $bakTmp -Force
                Move-Item -LiteralPath $bakTmp -Destination $BakPath -Force
            } catch {
                Remove-Item -LiteralPath $bakTmp -Force -ErrorAction SilentlyContinue
                Fail("backup of $SharePath failed - aborting upload", 4)
            }
        }

        # Atomic replace: temp file + rename on the same filesystem
        $tmpOnShare = Join-Path $ShareDir 'kpxc-sync.tmp'
        try {
            Copy-Item -LiteralPath $TempDb -Destination $tmpOnShare -Force
            Move-Item -LiteralPath $tmpOnShare -Destination $SharePath -Force
        } catch {
            Remove-Item -LiteralPath $tmpOnShare -Force -ErrorAction SilentlyContinue
            Fail("upload to $SharePath failed: $_", 5)
        }
    }

    default {
        Fail("usage: sync.ps1 {download|upload} {TEMP_DATABASE}", 2)
    }
}

exit 0
