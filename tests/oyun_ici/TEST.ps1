# TEK TIKLAMALI KAYIT/DLC-PAKETI TESTI (TEST.bat bunu calistirir).
# Kullanici yalnizca oyunu acip bakar ve E/H tuslar. Kayitlar once yedeklenir; sonunda yedekten geri yuklenir; hicbir sey silinmez.
# Ic test degiskenleri (yalnizca sahte klasorlerde deneme icin): F3T_GAME, F3T_SAVES, F3T_SIM=1, F3T_ANS="E,E", F3T_FAIL=B
param([string]$Only = '')      # TEST_B.bat: -Only B (A adimini atlar)
$ErrorActionPreference = 'Stop'
$kit = $PSScriptRoot
$ts = Get-Date -Format yyyyMMdd_HHmmss
$sim = ($env:F3T_SIM -eq '1')
$ans = @(); if ($env:F3T_ANS) { $ans = @($env:F3T_ANS -split ',') }

# ---- ayarlar
$ortak = Get-Content (Join-Path $kit 'ayarlar.bat') -Raw
$game = $env:F3T_GAME; if (-not $game) { $game = $env:F3_GAME }
if (-not $game) { $game = [regex]::Match($ortak, 'set "GAME=(.*?)"').Groups[1].Value }
$saves = $env:F3T_SAVES; if (-not $saves) { $saves = Join-Path $env:USERPROFILE 'Saved Games\Lionhead Studios\Fable 3' }
$yedek = $saves + '_YEDEK_TESTSAVE_' + $ts
$stash = Join-Path $kit '_cikarilan'
$dlcDir = Join-Path $game 'DLC'
$pkgDir = Join-Path $dlcDir '99_tr_yama'
$sonuc = Join-Path $kit 'SONUC.txt'

# ---- ekran yardimcilari
function Banner([string]$title, [string[]]$lines, [string]$color = 'Yellow') {
    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor $color
    Write-Host ('  ' + $title) -ForegroundColor $color
    Write-Host ('=' * 78) -ForegroundColor $color
    foreach ($l in $lines) { Write-Host ('  ' + $l) -ForegroundColor White }
    Write-Host ('=' * 78) -ForegroundColor $color
    Write-Host ''
}
function Info([string]$m) { Write-Host ('  ' + $m) -ForegroundColor Gray }
$log = New-Object System.Collections.Generic.List[string]
function Log([string]$m) { $log.Add($m) }

function GameRunning {
    if ($sim) { return $false }
    [bool](Get-Process -Name 'Fable3', 'FableLauncher' -ErrorAction SilentlyContinue)
}
function WaitClosed([string]$why) {
    if (-not (GameRunning)) { return }
    Banner 'OYUNU KAPATIN' @($why, 'Oyunu ve baslaticiyi (FableLauncher) tamamen kapatin.', 'Kapaninca bu pencere kendiliginden devam eder.') 'Red'
    while (GameRunning) { Start-Sleep -Seconds 2 }
    Start-Sleep -Seconds 2
}
function Ask([string]$q) {
    Write-Host ''
    Write-Host ('  ' + $q + '   [E = Evet / H = Hayir]') -ForegroundColor Cyan
    if ($ans.Count -gt 0) { $a = $ans[0]; $script:ans = @($ans | Select-Object -Skip 1); Write-Host "  (otomatik cevap: $a)"; return $a.ToUpper() }
    while ($true) {
        $k = [Console]::ReadKey($true).KeyChar.ToString().ToUpper()
        if ($k -eq 'E' -or $k -eq 'H') { Write-Host "  Cevap: $k" -ForegroundColor Green; return $k }
    }
}
# Oyun oturumu: once acilmasini, sonra kapanmasini bekler. 'I' tusu = iptal.
function WaitSession([scriptblock]$simAction) {
    if ($sim) { if ($simAction) { & $simAction }; return }
    Write-Host '  Oyunun acilmasi bekleniyor... (testi iptal etmek icin I tusuna basin)' -ForegroundColor DarkGray
    while (-not (GameRunning)) {
        Start-Sleep -Milliseconds 700
        if ([Console]::KeyAvailable) { if ([Console]::ReadKey($true).KeyChar.ToString().ToUpper() -eq 'I') { throw 'Kullanici testi iptal etti.' } }
    }
    Write-Host '  Oyun acildi. Isiniz bitince oyunu KAPATIN; bu pencere kendiliginden devam eder.' -ForegroundColor DarkGray
    $closed = 0
    while ($closed -lt 3) { if (GameRunning) { $closed = 0 } else { $closed++ }; Start-Sleep -Seconds 1 }
}

# ---- dosya yardimcilari
function Snap([string]$dir) {
    $h = @{}
    if (Test-Path $dir) {
        $r = (Resolve-Path $dir).Path.TrimEnd('\')
        Get-ChildItem $dir -Recurse -File -Force | ForEach-Object { $h[$_.FullName.Substring($r.Length + 1).ToLower()] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash }
    }
    $h
}
function SameSnap($a, $b) {
    if ($a.Count -ne $b.Count) { return $false }
    foreach ($k in $a.Keys) { if (-not $b.ContainsKey($k) -or $a[$k] -ne $b[$k]) { return $false } }
    $true
}
function FileHash([string]$p) { if (Test-Path $p) { (Get-FileHash $p -Algorithm SHA256).Hash } else { '-' } }
function GameState {
    [ordered]@{
        book = FileHash (Join-Path $game 'data\language\en-uk\text\book.babel')
        font = FileHash (Join-Path $game 'data\language\en-uk\fonts\gui_normal.bft')
        dlc  = ((Get-ChildItem $dlcDir -Directory | Sort-Object Name | ForEach-Object { $_.Name }) -join ',')
        pkg  = Snap $pkgDir
    }
}
function RoboMove([string]$from, [string]$to) {
    & robocopy $from $to /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Tasima hatasi: $from -> $to (robocopy $LASTEXITCODE)" }
    if (Test-Path $from) { Remove-Item $from -ErrorAction SilentlyContinue }      # yalnizca BOS klasor silinir (ozyinelemeli degil)
}
function RoboCopy2([string]$from, [string]$to) {
    & robocopy $from $to /E /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Kopyalama hatasi: $from -> $to (robocopy $LASTEXITCODE)" }
}
$script:origStash = $null
$script:origExisted = $false
function InstallVariant([string]$v) {
    $src = Join-Path $kit "paketler\$v\99_tr_yama"
    if (-not (Test-Path (Join-Path $src 'content.xbx'))) { throw "Paket yok: $src" }
    if (Test-Path $pkgDir) {
        $isOrig = ($script:origExisted -and -not $script:origStash)     # testten ONCE var olan paket yalnizca bir kez 'orijinal' olarak saklanir
        $dst = Join-Path $stash ("{0}_{1}_{2}_99_tr_yama" -f $ts, $(if ($isOrig) { 'orijinal' } else { 'test' }), (Get-Random -Maximum 9999))
        New-Item -ItemType Directory -Force $stash | Out-Null
        RoboMove $pkgDir $dst
        if ($isOrig) { $script:origStash = $dst }
    }
    RoboCopy2 $src $pkgDir
}
function SaveInfo([string]$file) {
    $b = [IO.File]::ReadAllBytes($file)
    $t = [Text.Encoding]::UTF8.GetString($b, 4, $b.Length - 4)
    $e = $t.LastIndexOf('</SaveInfo>'); if ($e -lt 0) { return $null }
    $x = $t.Substring(0, $e + 11)
    $ids = {
        param($tag)
        @([regex]::Matches($x, "<$tag>\s*<PackageId type=""uint"">(\d+)</PackageId>") | ForEach-Object { [int]$_.Groups[1].Value })
    }
    [pscustomobject]@{ Installed = (& $ids 'InstalledPackage'); Required = (& $ids 'RequiredPackage') }
}
function NewestSave($since) {
    if (-not (Test-Path $saves)) { return $null }
    Get-ChildItem $saves -Recurse -File -Filter '*chaptersave.bin' | Where-Object { (-not $since) -or $_.LastWriteTime -gt $since } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
function Fmt($a) { if ($a) { ($a -join ',') } else { '(bos)' } }

# ---- sonuc kaydi
$R = [ordered]@{ A_cevap = '-'; B_dlc_turkce = '-'; B_yeni_kayit = '-'; B_Installed = '-'; B_Required = '-'; B_120_121_zorunlu = '-'
    baslangic_kayit = '-'; baslangic_zorunlu = '-'; geri_yukleme = '-'; paket_geri = '-'; oyun_dosyalari = '-'; hata = '' }
$restoreDone = $false
function Restore-All {
    if ($script:restoreDone) { return }
    $script:restoreDone = $true
    Banner 'KAYITLAR VE PAKET ESKI HALINE DONDURULUYOR' @('Lutfen bekleyin; pencereyi kapatmayin.') 'Cyan'
    try { WaitClosed 'Geri yukleme icin oyun kapali olmali.' } catch { }
    # 1) kayitlar
    try {
        if (Test-Path $yedek) {
            $o = & (Join-Path $kit 'kayit_geri_yukle.ps1') -Saves $saves -Yedek $yedek -Ts $ts 2>&1 | Out-String
            Log "--- kayit geri yukleme ciktisi ---`r`n$o"
            $ok = ($LASTEXITCODE -eq 0)
            $nMoved = ([regex]::Matches($o, 'kenara alindi')).Count; $nBack = ([regex]::Matches($o, 'geri yazildi')).Count
            $R.geri_yukleme = if ($ok) { "TAMAM: kayitlar yedekle bayt bayt AYNI | testte olusan ve kenara alinan yeni dosya: $nMoved" + $(if ($nMoved) { " (Fable 3_TEST_ARTIKLARI\$ts altinda, silinmedi)" } else { ' (yeni dosya olusmamis)' }) + " | yedekten geri yazilan (test sirasinda degismis) dosya: $nBack" } else { 'SORUNLU (ayrintilar asagida)' }
        } else { $R.geri_yukleme = 'YEDEK YOK (yedek alinmadan hata oldu; kayitlara dokunulmadi)' }
    } catch { $R.geri_yukleme = 'HATA: ' + $_.Exception.Message }
    # 2) paket
    try {
        if (Test-Path $pkgDir) { New-Item -ItemType Directory -Force $stash | Out-Null; RoboMove $pkgDir (Join-Path $stash ("{0}_test_son_99_tr_yama" -f $ts)) }
        if ($script:origStash -and (Test-Path $script:origStash)) { RoboMove $script:origStash $pkgDir }
        $now = GameState
        $same = (SameSnap $now.pkg $script:before.pkg)
        $R.paket_geri = if ($same) { 'TAMAM: DLC\99_tr_yama testten onceki haliyle AYNI' + $(if ($script:before.pkg.Count -eq 0) { ' (testten once yoktu; simdi de yok)' } else { '' }) } else { 'FARKLI: DLC\99_tr_yama testten oncekiyle ayni DEGIL' }
        $ok = ($now.book -eq $script:before.book) -and ($now.font -eq $script:before.font) -and ($now.dlc -eq $script:before.dlc) -and $same
        $R.oyun_dosyalari = if ($ok) { 'TAMAM: book.babel, gui_normal.bft, DLC klasorleri ve 99_tr_yama testten onceki haliyle AYNI (hash dogrulandi)' } else { 'FARKLI: oyun dosyalari baslangictan farkli (ayrintilar asagida)' }
        if (-not $ok) { Log ("onceki: book=$($script:before.book) font=$($script:before.font) dlc=$($script:before.dlc)`r`nsimdi : book=$($now.book) font=$($now.font) dlc=$($now.dlc)") }
    } catch { $R.paket_geri = 'HATA: ' + $_.Exception.Message }
}
function Write-Sonuc {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('KAYIT/DLC-PAKETI TESTI SONUCU  (' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ')')
    [void]$sb.AppendLine('Oyun klasoru : ' + $game)
    [void]$sb.AppendLine('Kayit klasoru: ' + $saves)
    [void]$sb.AppendLine('Yedek        : ' + $yedek)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('BASLANGIC (testten once en yeni kayit)')
    [void]$sb.AppendLine('  kayit: ' + $R.baslangic_kayit)
    [void]$sb.AppendLine('  Required listesinde 120/121 (yama paketi) var mi: ' + $R.baslangic_zorunlu + '   (EVET beklenir: v1.1.0 kaydi)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('ADIM A - YER TUTUCU (V2): yama kuruluyken alinmis eski kayit acildi mi?  CEVAP = ' + $R.A_cevap + '   (beklenen: E)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('ADIM B - DUZELTILMIS PAKET (V1)')
    [void]$sb.AppendLine('  DLC metinleri Turkce miydi?  CEVAP = ' + $R.B_dlc_turkce + '   (beklenen: E)')
    [void]$sb.AppendLine('  Yeni kayit bulundu mu: ' + $R.B_yeni_kayit)
    [void]$sb.AppendLine('  Installed : ' + $R.B_Installed)
    [void]$sb.AppendLine('  Required  : ' + $R.B_Required)
    [void]$sb.AppendLine('  Required listesinde 120/121 var mi: ' + $R.B_120_121_zorunlu + '   (HAYIR beklenir)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('GERI YUKLEME')
    [void]$sb.AppendLine('  kayitlar : ' + $R.geri_yukleme)
    [void]$sb.AppendLine('  paket    : ' + $R.paket_geri)
    [void]$sb.AppendLine('  oyun     : ' + $R.oyun_dosyalari)
    if ($R.hata) { [void]$sb.AppendLine(''); [void]$sb.AppendLine('HATA/IPTAL: ' + $R.hata) }
    if ($log.Count) { [void]$sb.AppendLine(''); [void]$sb.AppendLine('--- ayrintilar ---'); foreach ($l in $log) { [void]$sb.AppendLine($l) } }
    Set-Content -Path $sonuc -Value $sb.ToString() -Encoding UTF8
}

# =====================================================================================================
$script:before = $null
try {
    Clear-Host
    Banner 'FABLE III - KAYIT / DLC PAKETI TESTI' @(
        'Bu test kayitlarinizi KORUR: once tam yedek alinir, sonunda yedekten geri yuklenir. Hicbir dosya silinmez.',
        'Siz yalnizca oyunu acip bakacak ve E / H tuslayacaksiniz. Gerisini bu pencere yapar.',
        'Uyari cikarsa "Download Now / Simdi indir"e ASLA basmayin.') 'Green'
    if (-not (Test-Path $dlcDir)) { throw "DLC klasoru bulunamadi: $dlcDir  (F3_GAME ortam degiskenini ya da ayarlar.bat icindeki GAME yolunu duzeltin)" }
    if (-not (Test-Path $saves)) { throw "Kayit klasoru bulunamadi: $saves" }

    # ---- 0) oyun kapali mi
    WaitClosed 'Teste baslamadan once oyun kapali olmali.'

    # ---- 1) yedek
    Banner 'ADIM 1/4 - KAYITLAR YEDEKLENIYOR' @('Kayit klasoru kopyalanip hash ile dogrulaniyor...')
    & robocopy $saves $yedek /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Yedekleme basarisiz (robocopy $LASTEXITCODE)" }
    $o = & (Join-Path $kit 'kayit_karsilastir.ps1') -A $saves -B $yedek 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { Log $o; throw 'Yedek dogrulanamadi: test BASLATILMADI.' }
    Info ('Yedek hazir ve dogrulandi: ' + $yedek)
    $script:before = GameState
    $script:origExisted = (Test-Path $pkgDir)
    $n0 = NewestSave $null
    if ($n0) {
        $i0 = SaveInfo $n0.FullName
        $R.baslangic_kayit = $n0.FullName.Substring($saves.Length).TrimStart('\') + '  [' + $n0.LastWriteTime + ']'
        $R.baslangic_zorunlu = if ($i0 -and (($i0.Required -contains 120) -or ($i0.Required -contains 121))) { 'EVET' } else { 'HAYIR' }
        Info ('Baslangic kaydi: Required listesinde 120/121 = ' + $R.baslangic_zorunlu)
    }

    # ---- A) yer tutucu
    if ($Only -ne 'B') {
        Banner 'ADIM 2/4 - TEST A: YER TUTUCU PAKET' @('Paket kuruluyor (yer tutucu: icinde metin yok)...') 'Cyan'
        InstallVariant 'V2'
        Banner 'SIMDI SIZIN SIRANIZ (A)' @(
            '1) OYUNU ACIN (FableLauncher).',
            '2) YAMA KURULUYKEN ALDIGINIZ KAYDI YUKLEYIN.',
            '3) Kayit ACILDI MI, yoksa "downloadable content" uyarisi mi cikti? (Uyari cikarsa "Download Now"a BASMAYIN.)',
            '4) KAYDETMEDEN OYUNU KAPATIN.',
            '',
            'Oyunu kapattiginizda soru ekranda gorunecek.') 'Yellow'
        WaitSession $null
        $a = Ask 'Kayit ACILDI mi? (uyari cikmadan yuklendi mi)'
        $R.A_cevap = $a
    } else { $R.A_cevap = '(bu kosuda atlandi)' }

    # ---- B) duzeltilmis paket
    Banner 'ADIM 3/4 - TEST B: DUZELTILMIS PAKET' @('Paket kuruluyor (Turkce DLC metinli, "zorunlu degil" isaretli)...') 'Cyan'
    $bStart = Get-Date
    Start-Sleep -Seconds 1
    InstallVariant 'V1'
    if ($env:F3T_FAIL -eq 'B') { throw 'F3T_FAIL=B (deneme amacli hata)' }
    $snapB = Snap $saves            # B oncesi kayit klasoru (degisen/yeni dosya tespiti icin; yalnizca OKUR)
    $simSave = @(); if ($env:F3T_SIMSAVE) { $simSave = @($env:F3T_SIMSAVE -split ',') }
    $found = $null; $attempt = 0
    while (-not $found) {
        $attempt++
        Banner ('SIMDI SIZIN SIRANIZ (B)  -  deneme ' + $attempt) @(
            '1) OYUNU ACIN.',
            '2) Kaydi yukleyin; DLC METINLERI TURKCE MI BAKIN (ornek: Bay Boyle gorevi, Traitor''s Keep hapishane).',
            '3) OYUNDA KAYIT ALINMASINI SAGLAYIN:  Fable III''te her kahramanin TEK kayit yuvasi vardir (otomatik kayit);',
            '   "yeni yuva" yoktur. UST UNE YAZILMASI SORUN DEGIL: yedek var, test sonunda geri yuklenecek.',
            '   -> Baska bir bolgeye gecin (kapidan girin/cikin ya da yeni bolgeye yuruyun) ve ekranin kosesinde',
            '      "kaydediliyor" simgesi gorunene KADAR bekleyin. Sonra Duraklat menusunden Ana Menuye donun / cikin.',
            '4) OYUNU KAPATIN.',
            '',
            'Oyunu kapattiginizda sorular ekranda gorunecek.') 'Yellow'
        $simMode = if ($simSave.Count -ge $attempt) { $simSave[$attempt - 1] } else { 'inplace' }
        WaitSession {
            # (yalnizca sahte test) oyunun kayit yazmasini taklit et: none | inplace (ayni dosya yeniden yazilir) | new
            if ($simMode -eq 'none') { return }
            $src = NewestSave $null
            $b = [IO.File]::ReadAllBytes($src.FullName)
            $t = [Text.Encoding]::UTF8.GetString($b, 4, $b.Length - 4)
            $t = [regex]::Replace($t, '<RequiredPackage>\s*<PackageId type="uint">(120|121)</PackageId>\s*</RequiredPackage>\s*', '')
            $nb = New-Object byte[] 4; [Array]::Copy($b, $nb, 4)
            $dst = if ($simMode -eq 'new') { Join-Path (Split-Path $src.FullName -Parent) 'hero1testyeni_chaptersave.bin' } else { $src.FullName }
            [IO.File]::WriteAllBytes($dst, ($nb + [Text.Encoding]::UTF8.GetBytes($t)))
        }
        if ($attempt -eq 1) { $R.B_dlc_turkce = Ask 'DLC metinleri TURKCE miydi?' }
        # degisen/yeni dosyalari HASH ile bul (zaman damgasina guvenme)
        $snapNow = Snap $saves
        $changed = @($snapNow.Keys | Where-Object { (-not $snapB.ContainsKey($_)) -or ($snapB[$_] -ne $snapNow[$_]) })
        Log ("B deneme ${attempt}: degisen/yeni dosya sayisi = " + $changed.Count + $(if ($changed.Count) { ' -> ' + ($changed -join '; ') } else { '' }))
        $cs = @($changed | Where-Object { $_ -like '*chaptersave.bin' })
        if ($cs.Count) {
            $cands = $cs | ForEach-Object { Get-Item (Join-Path (Resolve-Path $saves).Path $_) } | Sort-Object LastWriteTime -Descending
            $found = $cands | Select-Object -First 1
        } else {
            # baska yerlere kayit yazilmis mi? (yalnizca bilgi)
            foreach ($rt in @((Split-Path $saves -Parent), (Join-Path $env:APPDATA 'Lionhead Studios'), (Join-Path $env:LOCALAPPDATA 'Lionhead Studios'))) {
                if (Test-Path $rt) {
                    $o = Get-ChildItem $rt -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $bStart -and $_.FullName -notlike "$saves*" -and $_.FullName -notlike '*TEST_ARTIKLARI*' -and $_.FullName -notlike '*YEDEK*' }
                    foreach ($f in $o) { Log ('   (baska yerde degisen dosya) ' + $f.FullName) }
                }
            }
            Banner 'KAYIT ALINMADI' @(
                'Kayit klasorunde yeni/degisen kayit dosyasi gorulmedi (oyun kayit yazmadi ya da kapanmadan once yazamadi).',
                'Bu yuzden Required listesi OKUNAMADI. Lutfen tekrar deneyin ve kayit simgesini gorun.') 'Red'
            if ($attempt -ge 3) { Log 'B: 3 denemede de kayit dosyasi degismedi.'; break }
            $again = Ask 'Tekrar denemek ister misiniz?'
            if ($again -ne 'E') { break }
        }
    }
    if ($found) {
        $info = SaveInfo $found.FullName
        $R.B_yeni_kayit = $found.FullName.Substring($saves.Length).TrimStart('\') + '  [' + $found.LastWriteTime + ']'
        if ($info) {
            $R.B_Installed = Fmt $info.Installed
            $R.B_Required = Fmt $info.Required
            $zor = ($info.Required -contains 120) -or ($info.Required -contains 121)
            $R.B_120_121_zorunlu = if ($zor) { 'EVET  (beklenmiyordu!)' } else { 'HAYIR  (beklendigi gibi)' }
        } else { $R.B_120_121_zorunlu = 'kayit XML okunamadi' }
        Banner 'OTOMATIK KAYIT OKUMA SONUCU' @(('Kayit: ' + $R.B_yeni_kayit), ('Installed: ' + $R.B_Installed), ('Required : ' + $R.B_Required), ('Required listesinde 120/121: ' + $R.B_120_121_zorunlu)) 'Cyan'
    } else {
        $R.B_yeni_kayit = 'KAYIT ALINAMADI/BULUNAMADI (kayit klasorunde yeni ya da degisen dosya yok)'
        $R.B_120_121_zorunlu = 'OLCULEMEDI (B testi gecersiz: kayit alinmadi)'
    }
}
catch {
    $R.hata = $_.Exception.Message
    Banner 'HATA / IPTAL' @($R.hata, 'Kayitlar ve paket simdi eski haline donduruluyor...') 'Red'
}
finally {
    Banner 'ADIM 4/4 - GERI YUKLEME' @('Kayitlar yedekten geri yukleniyor, paket testten onceki haline donduruluyor...') 'Cyan'
    if ($script:before) { Restore-All } else { $R.geri_yukleme = 'Yedek alinmadigi icin geri yukleme gerekmedi (kayitlara hic dokunulmadi)' }
    Write-Sonuc
}
Banner 'TEST BITTI' @(
    ('SONUC DOSYASI:  ' + $sonuc),
    '',
    'Bu dosyanin ICERIGINI kopyalayip Claude Code''a YAPISTIRIN.',
    '(Dosyayi simdi Not Defteri ile aciyorum.)') 'Green'
if (-not $sim) { Start-Process notepad.exe $sonuc }
