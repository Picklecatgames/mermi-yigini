<#
 Tek kontrol koşucusu. Her kontrol için tek satır: "ad: GEÇTİ/KALDI (süre)". Tam günlük dosyaya
 gider, KALDI ise yalnız son ~15 anlamlı satır (kapanış uyarıları süzülmüş) yazılır.

 Örnekler:
   powershell -File tools/run_checks.ps1 day_night net_check
   powershell -File tools/run_checks.ps1 -Checks cheat_check,down_check -TimeoutSec 240
   powershell -File tools/run_checks.ps1 -Shot shot -ShotArgs "ev_on" -ShotScale 0.5   # çekim, 640x360 önizleme
   powershell -File tools/run_checks.ps1 -List                                          # kontrol adları

 - Ad: "day_night", "day_night_check" ya da "tools/day_night_check.gd" hepsi olur.
 - Godot yalnız kendi PID'iyle öldürülür (isimle öldürme yok), süre aşımında çocuklarıyla.
 - --import yalnız .godot yoksa ya da eskiyse (ya da -Import ile).
 - 127.0.0.1 kullanan (ağ) kontroller ortak kilidi alır: %LOCALAPPDATA%\Temp\godot_net.lock.
 - Başka Godot süreçleri çoksa (-BusyAt, varsayılan 4) ve zaman ölçen kontrol KALDI ise
   "makine meşgul olabilir" diye işaretler, tek başına yeniden koşmayı önerir.
 - Günlükler: %TEMP%\mermi_checks\<ad>.log   (-Full: tam günlüğü de ekrana yazar)
 - Dosya UTF-8 BOM'lu olmalı (Windows PowerShell 5.1 Türkçe harfleri öyle okur).
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Names,
    [string[]]$Checks,
    [int]$TimeoutSec = 180,
    [switch]$Import,
    [switch]$Full,
    [switch]$List,
    [int]$BusyAt = 4,
    [string]$Shot,
    [string]$ShotArgs = "",
    [double]$ShotScale = 0.5,
    [string]$Godot = "C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe"
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'log_filter.ps1')
$proj = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDir = Join-Path $env:TEMP 'mermi_checks'
New-Item -ItemType Directory -Force $logDir | Out-Null
$TimeSensitive = @('day_night_check', 'perf_check', 'wave_check')   # duvar saatine bağlı; makine meşgulse yanlış kalabilir

if ($List) {
    Get-ChildItem (Join-Path $proj 'tools') -Filter '*_check.gd' | ForEach-Object { $_.BaseName }
    return
}

function Get-GodotCount { @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' }).Count }

function Invoke-Godot([string]$ArgLine, [string]$LogBase, [int]$Limit) {
    $out = "$LogBase.out"; $err = "$LogBase.err"
    $p = Start-Process -FilePath $Godot -ArgumentList $ArgLine -WorkingDirectory $proj -PassThru -NoNewWindow `
        -RedirectStandardOutput $out -RedirectStandardError $err
    $null = $p.Handle   # ExitCode'un okunabilmesi için tutamağı önbelleğe al
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $done = $p.WaitForExit($Limit * 1000)
    $timedOut = -not $done
    if ($timedOut) { & taskkill /T /F /PID $p.Id *> $null }   # yalnız bu PID ve çocukları
    $sw.Stop()
    $lines = @()
    if (Test-Path $out) { $lines += Get-Content $out }
    if (Test-Path $err) { $lines += Get-Content $err }
    Set-Content -LiteralPath "$LogBase.log" -Value $lines -Encoding utf8
    Remove-Item $out, $err -ErrorAction SilentlyContinue
    $code = if ($timedOut) { -1 } else { $p.ExitCode }
    [pscustomobject]@{ Code = $code; TimedOut = $timedOut; Secs = [math]::Round($sw.Elapsed.TotalSeconds, 1); Lines = $lines; Log = "$LogBase.log" }
}

# --import yalnız gerekirse
$cache = Join-Path $proj '.godot/global_script_class_cache.cfg'
$needImport = $Import -or -not (Test-Path (Join-Path $proj '.godot/imported')) -or -not (Test-Path $cache)
if (-not $needImport) {
    $needImport = (Get-Item (Join-Path $proj 'project.godot')).LastWriteTime -gt (Get-Item $cache).LastWriteTime
}
if ($needImport) {
    Write-Output "import: başlıyor (.godot yok ya da eski)..."
    $r = Invoke-Godot "--headless --path `"$proj`" --import" (Join-Path $logDir '_import') 900
    $st = if ($r.TimedOut -or $r.Code -ne 0) { 'KALDI' } else { 'tamam' }
    Write-Output ("import: {0} ({1}s)" -f $st, $r.Secs)
}

# ---- Çekim kipi ----
if ($Shot) {
    $name = ($Shot -replace '\.gd$', '') -replace '^tools[/\\]', ''
    $before = Get-Date
    $argLine = "--path `"$proj`" --position -10000,-10000 --resolution 1280x720 -s res://tools/$name.gd"
    if ($ShotArgs) { $argLine += " -- $ShotArgs" }
    $r = Invoke-Godot $argLine (Join-Path $logDir $name) $TimeoutSec
    $pngs = @(Get-ChildItem $proj -Filter '*.png' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $before.AddSeconds(-1) })
    $prevDir = Join-Path $logDir 'onizleme'
    New-Item -ItemType Directory -Force $prevDir | Out-Null
    Add-Type -AssemblyName System.Drawing
    $paths = foreach ($f in $pngs) {
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        $w = [int]($img.Width * $ShotScale); $h = [int]($img.Height * $ShotScale)
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = 'HighQualityBicubic'; $g.DrawImage($img, 0, 0, $w, $h); $g.Dispose(); $img.Dispose()
        $dst = Join-Path $prevDir $f.Name
        $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
        $dst
    }
    $bad = $r.TimedOut -or $r.Code -ne 0
    $st = if ($bad) { 'KALDI' } else { 'GEÇTİ' }
    "{0}: {1} ({2}s), {3} çekim, önizleme {4}x: {5}" -f $name, $st, $r.Secs, $pngs.Count, $ShotScale, $prevDir
    $paths | ForEach-Object { "  $_" }
    if ($bad) { @(Get-MeaningfulLines $r.Lines) | Select-Object -Last 15 | ForEach-Object { "    $_" } }
    "  tam günlük: $($r.Log)"
    return
}

# ---- Kontroller ----
$want = @(); if ($Checks) { $want += $Checks }; if ($Names) { $want += $Names }
if (-not $want) { Write-Output "Kullanım: run_checks.ps1 <kontrol> [...]   (liste: -List)"; return }

$failed = 0
foreach ($n in $want) {
    $base = ($n -replace '\.gd$', '') -replace '^tools[/\\]', ''
    if ($base -notmatch '_check$') { $base += '_check' }
    $script = Join-Path $proj "tools/$base.gd"
    if (-not (Test-Path $script)) { Write-Output "${base}: YOK (tools/$base.gd bulunamadı)"; $failed++; continue }

    $needsLock = Select-String -Path $script -Pattern '127\.0\.0\.1' -Quiet
    $lock = Join-Path $env:LOCALAPPDATA 'Temp/godot_net.lock'
    $gotLock = $false
    if ($needsLock) {
        $until = (Get-Date).AddSeconds(300)
        while (-not $gotLock -and (Get-Date) -lt $until) {
            try { New-Item -ItemType Directory $lock -ErrorAction Stop | Out-Null; $gotLock = $true } catch { Start-Sleep -Seconds 3 }
        }
        if (-not $gotLock) { Write-Output "${base}: KALDI (ağ kilidi 300 sn içinde alınamadı)"; $failed++; continue }
    }
    try {
        $others = Get-GodotCount
        $r = Invoke-Godot "--headless --path `"$proj`" -s res://tools/$base.gd" (Join-Path $logDir $base) $TimeoutSec
    } finally { if ($gotLock) { Remove-Item $lock -Force -Recurse -ErrorAction SilentlyContinue } }

    $meaningful = @(Get-MeaningfulLines $r.Lines)
    $scriptErr = @($meaningful | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Failed to load script' })
    $ok = (-not $r.TimedOut) -and $r.Code -eq 0 -and $scriptErr.Count -eq 0
    $tag = ''
    if (-not $ok) {
        if ($r.TimedOut) { $tag = " süre aşımı ${TimeoutSec}s" }
        if (($others -ge $BusyAt) -and (($TimeSensitive -contains $base) -or $r.TimedOut)) {
            $tag += " [makine meşgul olabilir: $others Godot süreci; yük inince tek başına yeniden koş]"
        }
    }
    $st = if ($ok) { 'GEÇTİ' } else { 'KALDI' }
    Write-Output ("{0}: {1} ({2}s){3}" -f $base, $st, $r.Secs, $tag)
    if (-not $ok) {
        $meaningful | Select-Object -Last 15 | ForEach-Object { "    $_" }
        "    tam günlük: $($r.Log)"
        $failed++
    }
    if ($Full) { $r.Lines }
}
if ($failed) { exit 1 }
