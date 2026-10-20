@echo off
rem Kayitlardaki paket listesini gosterir (YALNIZCA OKUR). Her kayit icin Installed / Required paket kimlikleri; 120/121 = Turkce yama paketi.
call "%~dp0ayarlar.bat"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0kayit_paket_raporu.ps1" -Root "%SAVES%"
pause
