# Iki klasoru goreli yol + SHA-256 ile karsilastirir (YALNIZCA OKUR). Fark yoksa cikis 0.
param([Parameter(Mandatory)][string]$A, [Parameter(Mandatory)][string]$B)
function Map($root) {
    $h = @{}
    $r = (Resolve-Path $root).Path.TrimEnd('\')
    Get-ChildItem $root -Recurse -File -Force | ForEach-Object {
        $h[$_.FullName.Substring($r.Length + 1).ToLower()] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    }
    $h
}
$ma = Map $A; $mb = Map $B
$bad = 0
foreach ($k in $ma.Keys) {
    if (-not $mb.ContainsKey($k)) { "  YEDEKTE YOK: $k"; $bad++ }
    elseif ($ma[$k] -ne $mb[$k]) { "  FARKLI: $k"; $bad++ }
}
foreach ($k in $mb.Keys) { if (-not $ma.ContainsKey($k)) { "  KAYITLARDA YOK: $k"; $bad++ } }
"Dosya sayisi: $($ma.Count) | $($mb.Count) | fark: $bad"
if ($bad) { exit 1 } else { exit 0 }
