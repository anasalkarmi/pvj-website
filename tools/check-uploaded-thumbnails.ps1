param([string]$Only = '', [int]$Threshold = 14)

# Checks which of the thumbnails in work/thumbnails/final are live on YouTube.
# For each <id>.jpg it downloads the public thumbnail and compares it, shrunk to
# 32x18 pixels, with (a) our rendered file and (b) the old video frame saved in
# work/thumbnails/frames/<id>-0.jpg. "live" = it looks like our file and not like the old frame.
# YouTube can take a few minutes to serve a new thumbnail, so "old" straight after
# an upload is not proof of failure: run it again later.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$thumbs = Join-Path (Join-Path $root 'work') 'thumbnails'
$final = Join-Path $thumbs 'final'
$frames = Join-Path $thumbs 'frames'

function Tiny([Drawing.Image]$img) {
    $b = New-Object Drawing.Bitmap 32, 18
    $g = [Drawing.Graphics]::FromImage($b)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, 32, 18)
    $g.Dispose()
    $v = New-Object 'int[]' (32 * 18 * 3)
    $i = 0
    for ($y = 0; $y -lt 18; $y++) { for ($x = 0; $x -lt 32; $x++) { $p = $b.GetPixel($x, $y); $v[$i] = $p.R; $v[$i + 1] = $p.G; $v[$i + 2] = $p.B; $i += 3 } }
    $b.Dispose()
    return ,$v
}
function TinyFile([string]$path) {
    $img = [Drawing.Image]::FromFile($path)
    try { return ,(Tiny $img) } finally { $img.Dispose() }
}
function Gap($a, $b) {
    $s = 0
    for ($i = 0; $i -lt $a.Length; $i++) { $s += [Math]::Abs($a[$i] - $b[$i]) }
    return [Math]::Round($s / $a.Length, 1)
}

$ids = @(Get-ChildItem $final -Filter '*.jpg' | Where-Object { $_.BaseName -notmatch '^sheet-' } | ForEach-Object { $_.BaseName })
if ($Only) { $want = @($Only -split '[,\s]+' | Where-Object { $_ }); $ids = @($ids | Where-Object { $want -contains $_ }) }
$wc = New-Object Net.WebClient
$live = 0; $old = 0; $other = 0
foreach ($id in $ids) {
    $state = 'unclear'; $gNew = -1; $gOld = -1
    try {
        $bytes = $wc.DownloadData("https://i.ytimg.com/vi/$id/maxresdefault.jpg?t=" + [DateTime]::UtcNow.Ticks)
        $ms = New-Object IO.MemoryStream (, $bytes)
        $img = [Drawing.Image]::FromStream($ms)
        $now = Tiny $img
        $img.Dispose(); $ms.Dispose()
        $gNew = Gap $now (TinyFile (Join-Path $final "$id.jpg"))
        $oldFile = Join-Path $frames "$id-0.jpg"
        if (Test-Path $oldFile) { $gOld = Gap $now (TinyFile $oldFile) }
        if ($gNew -le $Threshold -and ($gOld -lt 0 -or $gNew -lt $gOld)) { $state = 'live' }
        elseif ($gOld -ge 0 -and $gOld -le $Threshold -and $gOld -lt $gNew) { $state = 'old' }
    } catch { $state = 'error: ' + $_.Exception.Message }
    if ($state -eq 'live') { $live++ } elseif ($state -eq 'old') { $old++ } else { $other++ }
    "{0}`t{1}`tnew {2}`told {3}" -f $id, $state, $gNew, $gOld
}
"checked: $($ids.Count)   live: $live   still the old frame: $old   unclear or error: $other"
