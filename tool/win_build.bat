@echo off
REM ── Guest Windows build script for the UTM workflow (see AGENTS.md) ──
REM Pushed to the guest (e.g. C:\win_build.bat) and run via `utmctl exec`.
REM Run as nt authority\system, so it cannot rely on the user profile.
REM
REM EDIT THESE TWO PATHS for your setup (the only per-machine values):
set "PROJECT_DIR=C:\Users\dev\dev\FinanceCopilot"
set "FLUTTER_BAT=C:\Users\dev\dev\flutter\bin\flutter.bat"
REM ─────────────────────────────────────────────────────────────────

cd /d "%PROJECT_DIR%"
REM Load the guest .env (a .bat expands %VAR% line-by-line, so the
REM dart-defines below pick up the values set by this loop — unlike a
REM one-line `cmd /c` which expands them at parse time, before the loop).
for /f "usebackq tokens=1,* delims==" %%a in (".env") do set "%%a=%%b"

"%FLUTTER_BAT%" build windows --release --dart-define=GOOGLE_CLIENT_ID=%GOOGLE_CLIENT_ID% --dart-define=GOOGLE_CLIENT_SECRET=%GOOGLE_CLIENT_SECRET% --dart-define=GOOGLE_WEB_CLIENT_ID=%GOOGLE_WEB_CLIENT_ID% --dart-define=GOOGLE_ANDROID_CLIENT_ID=%GOOGLE_ANDROID_CLIENT_ID% --dart-define=DB_FILE_NAME=%DB_FILE_NAME% > C:\fc_build.log 2>&1
echo DONE_EXITCODE=%ERRORLEVEL% >> C:\fc_build.log
