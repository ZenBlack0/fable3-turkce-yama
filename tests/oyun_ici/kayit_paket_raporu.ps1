# Kayitlarin *chaptersave.bin dosyalarindaki paket listesini yazdirir. YALNIZCA OKUR; hicbir dosyayi degistirmez.
param([string]$Root = "$env:USERPROFILE\Saved Games\Lionhead Studios\Fable 3")
if (-not (Test-Path $Root)) { "Kayit klasoru yok: $Root"; exit 1 }
$files = Get-ChildItem $Root -Recurse -File -Filter '*chaptersave.bin' | Sort-Object LastWriteTime
if (-not $files) { "chaptersave.bin bulunamadi."; exit 0 }
foreach ($f in $files) {
    $b = [IO.File]::ReadAllBytes($f.FullName)
    $t = [Text.Encoding]::UTF8.GetString($b, 4, $b.Length - 4)
    $end = $t.LastIndexOf('</SaveInfo>')
    if ($end -lt 0) { "$($f.Name): XML okunamadi"; continue }
    $x = $t.Substring(0, $end + 11)
    function Ids($tag) {
        ([regex]::Matches($x, "<$tag>\s*<PackageId type=""uint"">(\d+)</PackageId>") | ForEach-Object { [int]$_.Groups[1].Value }) -join ','
    }
    $inst = Ids 'InstalledPackage'; $req = Ids 'RequiredPackage'
    $reqIds = $req -split ',' | Where-Object { $_ }
    $zor = ($reqIds -contains '120') -or ($reqIds -contains '121')
    $ins = (($inst -split ',') -contains '120') -or (($inst -split ',') -contains '121')
    "--- $($f.FullName.Substring($Root.Length).TrimStart('\'))   [$($f.LastWriteTime)]"
    "    Installed : $inst"
    "    Required  : $req"
    "    Turkce yama paketi (120/121):  kurulu=$(if($ins){'EVET'}else{'hayir'})   ZORUNLU=$(if($zor){'EVET  <-- yama kaldirilirsa bu kayit acilmaz'}else{'hayir  (yama olmadan da acilir)'})"
}
