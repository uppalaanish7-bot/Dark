@echo off
cd /d "%~dp0"
set "RELIC_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
echo Open http://127.0.0.1:8080 in your browser. Keep this window open.
if exist "%RELIC_PYTHON%" (
  "%RELIC_PYTHON%" tools\serve_web.py
) else (
  py -3 tools\serve_web.py
)
pause
