# TEST_YUKSELT.ps1'i SAHTE oyun + sahte kayit klasoruyle (gercek kurucularla) dener
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path; $kit = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$py = $null; foreach ($c in "$env:LOCALAPPDATA\Python\pythoncore-3.14-64\python.exe", "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe") { if (-not $py -and (Test-Path $c)) { $py = $c } }
if (-not $py) { $py = (Get-Command python | Where-Object { $_.Source -notlike '*WindowsApps*' } | Select-Object -First 1).Source }
$r = "$env:TEMP\f3_yuk_sim"; if (Test-Path $r) { Remove-Item $r -Recurse -Force }
$out = & $py "$kit\sahte\fake_savetest.py" "$r\fs" 0      # yalnizca kayit klasoru icin
$saves = $out[1]
$g = "$r\Oyun\Fable 3"
foreach ($d in 'data\language\en-uk\text', 'data\language\en-uk\fonts') { New-Item -ItemType Directory -Force "$g\$d" | Out-Null }
Copy-Item "$root\backup\book.babel.orig" "$g\data\language\en-uk\text\book.babel"; Copy-Item "$root\backup\gui_normal.bft.orig" "$g\data\language\en-uk\fonts\gui_normal.bft"
[IO.File]::WriteAllBytes("$g\Fable3.exe", [byte[]](1..50)); Copy-Item "$env:SystemRoot\System32\cmd.exe" "$g\FableLauncher.exe"
New-Item -ItemType Directory "$g\DLC" | Out-Null; Copy-Item "$root\work\fake_dlc\DLC\*" "$g\DLC" -Recurse
$env:F3T_GAME = $g; $env:F3T_SAVES = $saves; $env:F3T_SIM = '1'
if ($args[0]) { $env:F3T_FAIL = $args[0] }
Remove-Item "$kit\SONUC.txt" -ErrorAction SilentlyContinue
powershell -NoProfile -ExecutionPolicy Bypass -File "$kit\TEST_YUKSELT.ps1" 2>&1 | Out-Null
Get-Content "$kit\SONUC.txt" -Encoding UTF8
"---- kalan: HKCU key: $(Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1')"
"---- kayit dosyalari (sahte):"; Get-ChildItem (Split-Path $saves -Parent) -Recurse -File | % { $_.FullName.Substring($r.Length) }
# ---- temizlik: sahte kurulumu kaldir (kayit defteri anahtari ve gecici klasorler)
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1'
if (Test-Path $k) {
    $env:F3_SAVESDIR = $saves
    $u = (Get-ItemProperty $k).UninstallString.Trim('"')
    $p = Start-Process $u -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait -PassThru; Start-Sleep 4
    Remove-Item Env:F3_SAVESDIR -ErrorAction SilentlyContinue
    "temizlik: kaldirici cikis=$($p.ExitCode); anahtar kaldi mi: $(Test-Path $k)"
}
Remove-Item $r, "$env:TEMP\f3_yukselt_app", "$kit\SONUC.txt" -Recurse -Force -ErrorAction SilentlyContinue
