@echo off
rem Kayitlari 01 ile alinan YEDEKTEN geri yukler: yedekteki dosyalar uzerine yazilir; testte olusan yeni dosyalar SILINMEZ,
rem "Fable 3_TEST_ARTIKLARI" klasorune tasinir. Sonunda klasor yedekle bayt bayt karsilastirilir.
call "%~dp0ayarlar.bat"
if defined OYUN_ACIK (echo Oyun ACIK. Once kapatin. & pause & exit /b 1)
if not exist "%YEDEK%" (echo YEDEK YOK: %YEDEK% & pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0kayit_geri_yukle.ps1" -Saves "%SAVES%" -Yedek "%YEDEK%" -Ts "%TS%"
if errorlevel 1 (echo GERI YUKLEME SORUNLU - yukaridaki ciktiyi bana iletin. & pause & exit /b 1)
echo.
echo Kayitlar yedekle ayni. Test artiklari (varsa): %USERPROFILE%\Saved Games\Lionhead Studios\Fable 3_TEST_ARTIKLARI\%TS%
pause
