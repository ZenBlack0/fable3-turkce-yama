@echo off
rem Mevcut durumu gosterir (YALNIZCA OKUR).
call "%~dp0ayarlar.bat"
if defined OYUN_ACIK (echo Oyun acik: EVET) else (echo Oyun acik: hayir)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0durum.ps1" -Game "%GAME%"
pause
