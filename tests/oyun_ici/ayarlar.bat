@echo off
rem Ortak ayarlar. Oyun klasorunu F3_GAME ortam degiskeniyle verin ya da asagidaki GAME satirini duzenleyin.
set "GAME=C:\Program Files (x86)\Steam\steamapps\common\Fable 3"
if defined F3_GAME set "GAME=%F3_GAME%"
set "SAVES=%USERPROFILE%\Saved Games\Lionhead Studios\Fable 3"
set "YEDEK=%USERPROFILE%\Saved Games\Lionhead Studios\Fable 3_YEDEK_TESTSAVE"
set "KIT=%~dp0"
rem Zaman damgasi (dosya adlari icin)
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%t"
tasklist /FI "IMAGENAME eq Fable3.exe" 2>nul | find /i "Fable3.exe" >nul && set "OYUN_ACIK=1"
tasklist /FI "IMAGENAME eq FableLauncher.exe" 2>nul | find /i "FableLauncher.exe" >nul && set "OYUN_ACIK=1"
