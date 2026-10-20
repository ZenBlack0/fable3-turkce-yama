@echo off
chcp 65001 >nul
title Fable III - Kayit / DLC paketi testi
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0TEST.ps1"
echo.
pause
