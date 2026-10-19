# Oyun klasörü otomatik bulma + oyunu başlatma testleri (sahte klasörler; gerçek oyuna kurulum YAPILMAZ).
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ver = (Get-Content "$root\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json).tag
$Exe = if ($env:F3_EXE) { $env:F3_EXE } else { "$root\dist\$ver\Fable3_Turkce_Yama_$ver.exe" }
$ss = "$root\work\installer_ss"; New-Item -ItemType Directory -Force $ss | Out-Null
$orig = "$root\backup"
$sh = New-Object -ComObject WScript.Shell
$scan = 'C:\f3scan_test'
$fk = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Fable3_test_kaydi'
function Shot($name) {
    $r = New-Object Drawing.Rectangle 480, 160, 960, 700
    $bmp = New-Object Drawing.Bitmap $r.Width, $r.Height
    $gr = [Drawing.Graphics]::FromImage($bmp); $gr.CopyFromScreen($r.Location, [Drawing.Point]::Empty, $r.Size)
    $bmp.Save("$ss\$name.png"); $gr.Dispose(); $bmp.Dispose(); "  [ss] $name"
}
function Keys($k, $wait = 2) { $null = $sh.AppActivate('Kurulum yardımcısı'); if (-not $?) { $null = $sh.AppActivate('Fable III') }; Start-Sleep -Milliseconds 400; $sh.SendKeys($k); Start-Sleep $wait }
function Kill-All { Get-Process | Where-Object { $_.ProcessName -like 'Fable3_Turkce*' -or $_.ProcessName -like '*unins*' -or $_.ProcessName -eq 'FableLauncher' } | Stop-Process -Force -ErrorAction SilentlyContinue }
function New-Fake($g, [bool]$launcher) {
    New-Item -ItemType Directory -Force "$g\data\language\en-uk\text", "$g\data\language\en-uk\fonts" | Out-Null
    Copy-Item "$orig\book.babel.orig" "$g\data\language\en-uk\text\book.babel"; Copy-Item "$orig\gui_normal.bft.orig" "$g\data\language\en-uk\fonts\gui_normal.bft"
    if ($launcher) { Copy-Item "$env:SystemRoot\System32\cmd.exe" "$g\FableLauncher.exe" }
}
Kill-All
$base = Join-Path $env:TEMP ('f3_det_' + (Get-Random)); New-Item -ItemType Directory -Force $base | Out-Null

Write-Host "`n=== L1 oyunu başlat: normal launcher (ShellExec ile açılmalı)"
$g = "$base\L1\Oyun Klasörü\Fable 3"; New-Fake $g $true
$p0 = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$base\L1\app`" /GAME=`"$g`"" -PassThru; $script:p = $p0; Start-Sleep 5
Keys '{ENTER}'; Keys '{ENTER}' 1; Keys '{ENTER}' 6; Shot 'L1_bitti_baslat_kutulu'
Keys '{ENTER}' 5
Write-Host "  FableLauncher.exe süreci: $([bool](Get-Process FableLauncher -ErrorAction SilentlyContinue))"
Write-Host "  log: $((Get-Content "$base\L1\app\kurulum_log.txt" | Select-String 'başlat' | % Line) -join ' | ')"
Kill-All

Write-Host "`n=== L2 geçersiz launcher (başlatılamaz) -> Steam yedeği (test kancası: gerçekten çağrılmaz) + bilgi mesajı"
$g = "$base\L2\Oyun\Fable 3"; New-Fake $g $false; [IO.File]::WriteAllText("$g\FableLauncher.exe", 'bu bir exe degil')
$script:p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$base\L2\app`" /GAME=`"$g`" /TESTLAUNCH=1" -PassThru; Start-Sleep 5
Keys '{ENTER}'; Keys '{ENTER}' 1; Keys '{ENTER}' 6; Keys '{ENTER}' 3; Shot 'L2_baslatilamadi_bilgi_mesaji'
Keys '{ENTER}' 3
Write-Host "  log: $((Get-Content "$base\L2\app\kurulum_log.txt" | Select-String 'başlat|Steam' | % Line) -join ' | ')"
Kill-All

Write-Host "`n=== L3 yükseltme isteyen launcher: CreateProcess 740 verir (eski yöntem), ShellExecute kullanılıyor"
$cs = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (Test-Path $cs) {
    $adm = "$base\admin"; New-Item -ItemType Directory -Force $adm | Out-Null
    [IO.File]::WriteAllText("$adm\a.cs", 'class P{static void Main(){}}')
    [IO.File]::WriteAllText("$adm\a.manifest", '<?xml version="1.0" encoding="utf-8"?><assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1"><trustInfo xmlns="urn:schemas-microsoft-com:asm.v3"><security><requestedPrivileges><requestedExecutionLevel level="requireAdministrator" uiAccess="false"/></requestedPrivileges></security></trustInfo></assembly>')
    & $cs /nologo /out:"$adm\FableLauncher.exe" /win32manifest:"$adm\a.manifest" "$adm\a.cs" | Out-Null
    try { $psi = New-Object Diagnostics.ProcessStartInfo "$adm\FableLauncher.exe"; $psi.UseShellExecute = $false; [Diagnostics.Process]::Start($psi) | Out-Null; Write-Host '  CreateProcess: başladı (beklenmiyordu)' }
    catch { Write-Host "  CreateProcess (eski yöntem) hatası: $($_.Exception.Message) [kod $($_.Exception.NativeErrorCode)]" }
}

function Clean-Reg { reg delete 'HKCU\SOFTWARE\Fable3TurkceYama' /f 2>$null | Out-Null; reg delete 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1' /f 2>$null | Out-Null }
Clean-Reg
Write-Host "`n=== D1 otomatik bulma: iki sahte klasör + 'Fable' adlı uninstall kaydı"
New-Fake "$scan\Fable A" $true; New-Fake "$scan\Alt\Fable B" $true; New-Fake "$base\Kayitli\Oyun" $false
New-Item -Path $fk -Force | Out-Null
New-ItemProperty $fk -Name DisplayName -Value 'Fable III (test kaydi)' | Out-Null
New-ItemProperty $fk -Name InstallLocation -Value "$base\Kayitli\Oyun\" | Out-Null
$sw = [Diagnostics.Stopwatch]::StartNew()
$script:p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$base\D1\app`"" -PassThru
Start-Sleep 5
Write-Host "  pencere açılma süresi: $([math]::Round($sw.Elapsed.TotalSeconds,1)) sn (tarama dahil)"
Start-Sleep 2; Keys '{ENTER}' 1; Shot 'D1_birden_fazla_klasor_listesi'
Keys '{DOWN}' 1; Keys '{ENTER}' 2; Shot 'D2_secilen_klasor_oyun_sayfasinda'
Kill-All
Clean-Reg
Remove-Item $fk -Force -ErrorAction SilentlyContinue
Remove-Item $scan -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`ntemizlik: $(-not (Test-Path $scan)) | $(-not (Test-Path $fk)) ; çalışma klasörü $base"
