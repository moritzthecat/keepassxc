@echo off
REM Wrapper so the script can be called directly by KeePassXC.
REM Prefer the explicit powershell.exe invocation (see README.md).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync.ps1" %1 %2
