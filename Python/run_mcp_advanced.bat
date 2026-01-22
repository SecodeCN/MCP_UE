@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Run Unreal MCP Advanced Server (stdio) using MCP Inspector as the host.
REM This script is intended for Windows cmd.exe.
REM
REM Why this exists:
REM - The server runs with transport='stdio', so it must be launched by a host that keeps stdin/stdout open.
REM - mcp dev provides a local Inspector + host session for stdio servers.

cd /d "%~dp0"

echo.
echo [Unreal MCP] Working dir: %cd%
echo.

REM Activate the venv (cmd activation)
call ".\.venv\Scripts\activate.bat"

echo [Unreal MCP] Python: 
python --version
echo.

echo [Unreal MCP] Step: after python check
echo.

REM The Inspector UI used by mcp dev requires Node.js (npx).
REM Use a simple file existence check (more robust than `where` across shells/encodings).
if exist "C:\Program Files\nodejs\npx.cmd" (
	set "NPX=C:\Program Files\nodejs\npx.cmd"
) else (
	echo [Unreal MCP] ERROR: npx.cmd not found at "C:\Program Files\nodejs\npx.cmd".
	echo.
	echo Please install Node.js LTS from https://nodejs.org/ and reopen this terminal.
	echo After install, verify in a new terminal: node -v ^& npm -v ^& npx -v
	echo.
	pause
	exit /b 1
)

echo [Unreal MCP] npx.cmd found: %NPX%
echo.

REM Make npm/npx non-interactive for the Inspector install prompt.
REM This avoids: "Ok to proceed? (y)"
set "npm_config_yes=true"
set "npm_config_fund=false"
set "npm_config_audit=false"

REM Avoid accidental Ctrl+C prompts in some shells.
REM (If the user presses Ctrl+C, cmd may ask "Terminate batch job (Y/N)?")
REM We can't fully prevent that, but keeping the script non-interactive helps.

REM Ensure dependencies are present (uses uv.lock / pyproject.toml)
REM Comment out the next line if you don't want an automatic sync on every run.
uv sync
if errorlevel 1 (
	echo.
	echo [Unreal MCP] ERROR: uv sync failed. See output above.
	pause
	exit /b 1
)

echo [Unreal MCP] Step: after uv sync
echo.

echo.
echo [Unreal MCP] Starting MCP Inspector (this should open a local web UI)...
echo If a browser does not open automatically, look for a URL printed below and open it manually.
echo.

REM Start the MCP server with the MCP Inspector host
REM mcp dev will (a) start a local proxy, (b) print a URL, and (c) try to open a browser.
REM To ensure you always get the URL even if the browser doesn't open, we tee output to a log.
set "INSPECTOR_LOG=%cd%\mcp_inspector.log"

echo [Unreal MCP] Writing Inspector output to: %INSPECTOR_LOG%
echo.

REM Clear previous log so URL parsing is deterministic
if exist "%INSPECTOR_LOG%" del /q "%INSPECTOR_LOG%" >NUL 2>NUL

echo [Unreal MCP] Step: before mcp dev
echo.

REM IMPORTANT:
REM Run mcp dev in the current cmd.exe context and redirect output to a log.
REM (Wrapping this in an extra `cmd /c` with escaping can trigger: "此时不应有 to。" on some machines.)
mcp dev .\unreal_mcp_server_advanced.py 1>>"%INSPECTOR_LOG%" 2>>&1
if errorlevel 1 (
	echo.
	echo [Unreal MCP] ERROR: mcp dev exited with error. Showing last 80 log lines:
	powershell -NoProfile -Command "if (Test-Path '%INSPECTOR_LOG%') { Get-Content -Path '%INSPECTOR_LOG%' -Tail 80 } else { Write-Host 'Inspector log not found' }"
	pause
	exit /b 1
)

echo [Unreal MCP] Step: after mcp dev
echo.


REM Parse Inspector URL from the log using a simpler powershell one-liner
for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "^$p='%INSPECTOR_LOG%'; if (Test-Path ^$p) { ^$m=(Select-String -Path ^$p -Pattern 'http://localhost:\\d+/\\?MCP_PROXY_AUTH_TOKEN=\\S+' | Select-Object -First 1); if (^$m) { ^$m.Matches[0].Value } }"`) do (
	set "INSPECTOR_URL=%%L"
)

if defined INSPECTOR_URL (
	echo.
	echo [Unreal MCP] Opening: !INSPECTOR_URL!
	start "" "!INSPECTOR_URL!"
) else (
	echo.
	echo [Unreal MCP] WARNING: could not detect Inspector URL from log.
)

echo.
echo [Unreal MCP] Inspector output (last 30 lines):
powershell -NoProfile -Command "Get-Content -Path '%INSPECTOR_LOG%' -Tail 30"

echo.
echo [Unreal MCP] MCP Inspector exited.
pause

endlocal
