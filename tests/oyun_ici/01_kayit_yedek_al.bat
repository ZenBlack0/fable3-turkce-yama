@echo off
rem ADIM 1: kayit klasorunun TAM YEDEGINI alir ve dogrular. Kayitlariniza DOKUNMAZ (yalnizca okur/kopyalar).
call "%~dp0ayarlar.bat"
if defined OYUN_ACIK (echo Oyun ACIK. Once oyunu ve baslaticiyi kapatin. & pause & exit /b 1)
if not exist "%SAVES%" (echo Kayit klasoru bulunamadi: %SAVES% & pause & exit /b 1)
if exist "%YEDEK%" (
  echo YEDEK ZATEN VAR: %YEDEK%
  echo Ustune yazmiyorum. Elle kontrol edin; ayni yedegi kullanacaksaniz bu adimi atlayin.
  pause & exit /b 1
)
robocopy "%SAVES%" "%YEDEK%" /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
if errorlevel 8 (echo KOPYALAMA HATASI & pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0kayit_karsilastir.ps1" -A "%SAVES%" -B "%YEDEK%"
if errorlevel 1 (echo YEDEK DOGRULANAMADI. Teste BASLAMAYIN. & pause & exit /b 1)
echo.
echo Yedek hazir ve dogrulandi: %YEDEK%
pause
