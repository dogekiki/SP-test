@echo off
chcp 65001 >nul
title 自动化开发工作流服务器
echo ========================================
echo   自动化开发工作流 - 交互服务器
echo ========================================
echo.
echo 启动服务器...
echo 前端页面: http://localhost:8765
echo.
echo 按 Ctrl+C 停止服务器
echo.
cd /d "%~dp0"
python server.py
pause
