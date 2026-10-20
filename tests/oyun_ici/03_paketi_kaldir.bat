@echo off
rem ADIM: DLC\99_tr_yama paketini oyundan CIKARIR (silmez; kit\_cikarilan klasorune tasir). Oyun yamasiz hale gelir.
call "%~dp0ayarlar.bat"
if defined OYUN_ACIK (echo Oyun ACIK. Once kapatin. & pause & exit /b 1)
if not exist "%GAME%\DLC\99_tr_yama" (echo Zaten yok: %GAME%\DLC\99_tr_yama & pause & exit /b 0)
robocopy "%GAME%\DLC\99_tr_yama" "%KIT%_cikarilan\%TS%_99_tr_yama" /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
if errorlevel 8 (echo TASIMA HATASI & pause & exit /b 1)
echo Paket cikarildi (kit\_cikarilan\%TS%_99_tr_yama). DLC klasoru:
dir /b "%GAME%\DLC"
pause
