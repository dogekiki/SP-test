@echo off
chcp 65001 >nul 2>&1
title Workflow Automation Server
echo ========================================
echo   Workflow Automation - Interaction Server
echo ========================================
echo.
echo Starting server...
echo Frontend: http://localhost:8765
echo WebSocket: ws://localhost:8766
echo.
echo Press Ctrl+C to stop server
echo.
cd /d "%~dp0"
python server.py
pause