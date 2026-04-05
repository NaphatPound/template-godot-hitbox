@echo off
REM Serve the web export on localhost:8080
REM Run this after building the web export
cd /d "%~dp0export\web"
echo Serving Boss Rush at http://localhost:8080
echo Press Ctrl+C to stop.
python -m http.server 8080
