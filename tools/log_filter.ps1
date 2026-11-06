<#
 Godot kontrol günlüğünden kapanış gürültüsünü süzer (kontrollerin kendisine dokunmaz).
 Kullanım:  powershell -File tools/log_filter.ps1 -Path günlük.txt [-Tail 15]
 Dot-source: . tools/log_filter.ps1 ; Get-MeaningfulLines $satirlar
 Süzülenler: "Pages in use", "resources still in use", "Leaked instance", ObjectDB/RID/StringName
 sızıntı uyarıları ile bunların "at:" satırları, motor başlık/sürücü satırları, boş satırlar.
#>
param([string]$Path, [int]$Tail = 15)

$script:NoisePattern = '(?i)(Pages in use|resources? still in use|Leaked instance|ObjectDB instances leaked|WARNING: ObjectDB|RID allocations? of type|Orphan StringName|^\s*Godot Engine v|^\s*Vulkan \d|^\s*OpenGL API|^\s*Mesa |Using .* for rendering|^\s*Initialize|^\s*Loaded .*\.(res|tres)\s*$|^\s*at: (cleanup|~|_?memdelete|unref|queue_free)|^\s*Leaked instance .*\s*$|ERROR: \d+ RID|ERROR: \d+ resources|Pages in use by|bytes? leaked|^\s*Attempting to .*(shutdown|terminate)|^\s*$)'

function Get-MeaningfulLines {
    param([string[]]$Lines)
    $skipAt = $false
    foreach ($l in $Lines) {
        if ($l -match $script:NoisePattern) { $skipAt = $true; continue }
        # Gürültü uyarısının arkasından gelen "   at: ..." izleri
        if ($skipAt -and $l -match '^\s+at:\s') { continue }
        $skipAt = $false
        $l
    }
}

if ($Path) {
    $all = Get-Content -LiteralPath $Path -ErrorAction Stop
    $m = @(Get-MeaningfulLines $all)
    "süzülen: $($all.Count - $m.Count) / $($all.Count) satır"
    $m | Select-Object -Last $Tail
}
