@echo off
chcp 65001 >nul
title Fable III - Kayit testi (yalniz B)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0TEST.ps1" -Only B
echo.
pause
