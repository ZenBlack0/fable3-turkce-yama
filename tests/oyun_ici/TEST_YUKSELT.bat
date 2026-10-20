@echo off
chcp 65001 >nul
title Fable III - Yukseltme testi (v1.1.0 - v1.1.1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0TEST_YUKSELT.ps1"
echo.
pause
