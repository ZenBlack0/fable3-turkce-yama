@echo off
rem ADIM: oyunun DLC klasorune test paketini kurar.  Kullanim: 02_paket_kur.bat V0|V1|V1x|V1y|V2
rem Mevcut DLC\99_tr_yama varsa SILINMEZ; kit\_cikarilan klasorune TASINIR.
call "%~dp0ayarlar.bat"
if "%~1"=="" (echo Kullanim: 02_paket_kur.bat V0 ^| V1 ^| V1x ^| V1y ^| V2 & pause & exit /b 1)
if not exist "%KIT%paketler\%~1\99_tr_yama\content.xbx" (echo Bilinmeyen varyant: %~1 & pause & exit /b 1)
if defined OYUN_ACIK (echo Oyun ACIK. Once kapatin. & pause & exit /b 1)
if not exist "%GAME%\DLC" (echo DLC klasoru yok: %GAME%\DLC - ayarlar.bat icindeki GAME yolunu duzeltin. & pause & exit /b 1)
if exist "%GAME%\DLC\99_tr_yama" (
  echo Mevcut 99_tr_yama kit\_cikarilan\ altina tasiniyor...
  robocopy "%GAME%\DLC\99_tr_yama" "%KIT%_cikarilan\%TS%_99_tr_yama" /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
  if errorlevel 8 (echo TASIMA HATASI & pause & exit /b 1)
)
robocopy "%KIT%paketler\%~1\99_tr_yama" "%GAME%\DLC\99_tr_yama" /E /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
if errorlevel 8 (echo KOPYALAMA HATASI & pause & exit /b 1)
echo Kuruldu: varyant %~1  ->  %GAME%\DLC\99_tr_yama
pause
