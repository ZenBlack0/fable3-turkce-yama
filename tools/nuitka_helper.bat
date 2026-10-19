@echo off
rem f3patch'i Nuitka --standalone (klasor ciktisi) + MSVC ile derler. --onefile ve UPX KULLANILMAZ.
rem Kullanim: nuitka_helper.bat <python.exe> <repo_koku> <cikti_klasoru> <surum 1.1.0>
setlocal
set "PYEXE=%~1"
set "ROOT=%~2"
set "OUTD=%~3"
set "VER=%~4"
rem vcvars64.bat: F3_VCVARS ortam degiskeni verilmisse o; yoksa bilinen Visual Studio konumlari denenir.
set "VCVARS=%F3_VCVARS%"
if not defined VCVARS (
  for %%V in (18 2022 17 2019) do (
    for %%E in (Community Professional Enterprise BuildTools) do (
      if not defined VCVARS if exist "C:\Program Files\Microsoft Visual Studio\%%V\%%E\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS=C:\Program Files\Microsoft Visual Studio\%%V\%%E\VC\Auxiliary\Build\vcvars64.bat"
      if not defined VCVARS if exist "C:\Program Files (x86)\Microsoft Visual Studio\%%V\%%E\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\%%V\%%E\VC\Auxiliary\Build\vcvars64.bat"
    )
  )
)
if not defined VCVARS (
  echo MSVC bulunamadi. Visual Studio Build Tools kurun ya da F3_VCVARS ortam degiskenini vcvars64.bat yoluna ayarlayin.
  exit /b 11
)
if not exist "%VCVARS%" (
  echo MSVC bulunamadi: %VCVARS%
  exit /b 11
)
call "%VCVARS%" >nul
if errorlevel 1 exit /b 12
where cl.exe >nul 2>nul
if errorlevel 1 (
  echo cl.exe PATH'te yok
  exit /b 13
)
set "PYTHONPATH=%ROOT%\tools"
"%PYEXE%" -m nuitka --standalone --msvc=latest ^
  --output-dir="%OUTD%" --output-filename=f3patch.exe --remove-output ^
  --windows-console-mode=force ^
  --company-name=ZenBlack0 --product-name="Fable III Turkce Yama" ^
  --file-description="Fable III Turkce Yama - f3patch yardimcisi" ^
  --file-version=%VER%.0 --product-version=%VER%.0 ^
  --copyright="Copyright (c) 2026 Kerim" ^
  --include-module=babel --include-module=repack --include-module=flags ^
  --include-module=dlc_bnk --include-module=dlc_build --include-module=dlc_package ^
  --nofollow-import-to=tkinter,unittest,pydoc,test,ssl,socket,select,http,urllib,email,xml,multiprocessing,asyncio ^
  "%ROOT%\tools\helper\f3patch.py"
exit /b %errorlevel%
