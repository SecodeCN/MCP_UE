@echo off
setlocal

REM Run Unreal MCP Advanced Server using the project's venv + uv
REM This script is intended for Windows cmd.exe.

cd /d "%~dp0"

REM Activate the venv (cmd activation)
call ".\.venv\Scripts\activate.bat"

REM Start the MCP server via uv
uv run python ".\unreal_mcp_server_advanced.py"

endlocal
