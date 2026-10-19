# "Yama zaten kurulu" sayfasının ekran görüntüsü (sahte oyun klasörü; gerçek oyuna dokunmaz)
param([string]$Exe = '', [string]$Out = '')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ver = (Get-Content "$root\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json).tag
if (-not $Exe) { $Exe = "$root\dist\$ver\Fable3_Turkce_Yama_$ver.exe" }
if (-not $Out) { $Out = "$root\work\installer_ss\instpage.png" }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$b = Join-Path $env:TEMP ('f3_shot_' + (Get-Random)); $g = "$b\Oyun\Fable 3"; $app = "$b\app"
New-Item -ItemType Directory -Force "$g\data\language\en-uk\text", "$g\data\language\en-uk\fonts", (Split-Path $Out) | Out-Null
Copy-Item "$root\backup\book.babel.orig" "$g\data\language\en-uk\text\book.babel"
Copy-Item "$root\backup\gui_normal.bft.orig" "$g\data\language\en-uk\fonts\gui_normal.bft"
Copy-Item "$env:SystemRoot\System32\cmd.exe" "$g\FableLauncher.exe"
Start-Process $Exe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /NORESTART /DIR=`"$app`" /GAME=`"$g`"" -Wait
$p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$app`" /GAME=`"$g`"" -PassThru
Start-Sleep 5
$sh = New-Object -ComObject WScript.Shell
$null = $sh.AppActivate('Kurulum yardımcısı'); Start-Sleep -Milliseconds 500; $sh.SendKeys('{ENTER}'); Start-Sleep 2
$r = New-Object Drawing.Rectangle 480, 160, 960, 700
$bmp = New-Object Drawing.Bitmap $r.Width, $r.Height
$gr = [Drawing.Graphics]::FromImage($bmp); $gr.CopyFromScreen($r.Location, [Drawing.Point]::Empty, $r.Size)
$bmp.Save($Out); $gr.Dispose(); $bmp.Dispose()
Get-Process | ? { $_.ProcessName -like 'Fable3_Turkce*' -or $_.ProcessName -like 'unins0*' } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 1
"kaydedildi: $Out"
