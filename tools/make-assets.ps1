# make-assets.ps1 - generates PVJ web image assets into <root>\src\assets\img
# Re-runnable; overwrites only its own outputs. Plain ASCII only.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$W   = Split-Path -Parent $PSScriptRoot
$Out = Join-Path $W 'src\assets\img'
# Original artwork lives in the repository, in src\brand
$Src = Join-Path $W 'src\brand'
$LogoSrc = Join-Path $Src 'PVJ-red-blue-original.png'
$PccsSrc = Join-Path $Src 'PCCS-society-original.png'

New-Item -ItemType Directory -Force -Path $Out | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Out 'partners') | Out-Null

function New-Gfx([System.Drawing.Bitmap]$bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingMode    = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    return $g
}

function Draw-Scaled($g, [System.Drawing.Bitmap]$img, [double]$x, [double]$y, [int]$w, [int]$h) {
    $ia = New-Object System.Drawing.Imaging.ImageAttributes
    $ia.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $dest = New-Object System.Drawing.Rectangle ([int][math]::Round($x)), ([int][math]::Round($y)), $w, $h
    $g.DrawImage($img, $dest, 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $ia.Dispose()
}

function Save-Png([System.Drawing.Bitmap]$bmp, [string]$path) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

# ---- load logo as 32bppArgb copy and find alpha bounds ----
$raw = [System.Drawing.Image]::FromFile($LogoSrc)
$full = New-Object System.Drawing.Bitmap ($raw.Width), ($raw.Height), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g0 = [System.Drawing.Graphics]::FromImage($full)
$g0.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$g0.DrawImage($raw, 0, 0, $raw.Width, $raw.Height)
$g0.Dispose(); $raw.Dispose()

$rect = New-Object System.Drawing.Rectangle 0, 0, $full.Width, $full.Height
$bd = $full.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $bd.Stride
$buf = New-Object byte[] ($stride * $full.Height)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $buf, 0, $buf.Length)
$full.UnlockBits($bd)
$minX = $full.Width; $minY = $full.Height; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $full.Height; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $full.Width; $x++) {
        if ($buf[$row + $x * 4 + 3] -gt 8) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
$buf = $null
if ($maxX -lt 0) { throw 'Logo has no visible pixels' }
Write-Host ("Alpha bounds (alpha>8): x {0}-{1}, y {2}-{3} of {4}x{5}" -f $minX, $maxX, $minY, $maxY, $full.Width, $full.Height)

# ---- crop with ~2% padding (2% of the larger visible side, all four sides) ----
$vw = $maxX - $minX + 1; $vh = $maxY - $minY + 1
$pad = [int][math]::Round(0.02 * [math]::Max($vw, $vh))
$cx0 = [math]::Max(0, $minX - $pad); $cy0 = [math]::Max(0, $minY - $pad)
$cx1 = [math]::Min($full.Width - 1, $maxX + $pad); $cy1 = [math]::Min($full.Height - 1, $maxY + $pad)
$cw = $cx1 - $cx0 + 1; $ch = $cy1 - $cy0 + 1
Write-Host ("Crop: x {0}-{1}, y {2}-{3} = {4}x{5} (pad {6})" -f $cx0, $cx1, $cy0, $cy1, $cw, $ch, $pad)
$crop = $full.Clone((New-Object System.Drawing.Rectangle $cx0, $cy0, $cw, $ch), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$full.Dispose()

# ---- 1. pvj-logo.png (240 px tall, transparent) ----
$lh = 240; $lw = [int][math]::Round($cw * $lh / $ch)
$b = New-Object System.Drawing.Bitmap $lw, $lh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = New-Gfx $b; $g.Clear([System.Drawing.Color]::Transparent)
Draw-Scaled $g $crop 0 0 $lw $lh
$g.Dispose(); Save-Png $b (Join-Path $Out 'pvj-logo.png'); $b.Dispose()

# ---- 2. square icons on white, logo at 78% ----
function Make-Icon([int]$S, [string]$name) {
    $b = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = New-Gfx $b; $g.Clear([System.Drawing.Color]::White)
    $box = 0.78 * $S
    $sc = [math]::Min($box / $crop.Width, $box / $crop.Height)
    $w = [int][math]::Round($crop.Width * $sc); $h = [int][math]::Round($crop.Height * $sc)
    Draw-Scaled $g $crop (($S - $w) / 2.0) (($S - $h) / 2.0) $w $h
    $g.Dispose(); Save-Png $b (Join-Path $Out $name); $b.Dispose()
}
Make-Icon 32  'favicon-32.png'
Make-Icon 180 'apple-touch-icon.png'
Make-Icon 512 'icon-512.png'

# ---- 3. og-default.png ----
$OW = 1200; $OH = 630
$fam = $null
foreach ($n in 'Segoe UI Semibold', 'Segoe UI', 'Arial') {
    $f = New-Object System.Drawing.FontFamily $n
    if ($f.Name -eq $n) { $fam = $n; break }
}
$boldStyle = [System.Drawing.FontStyle]::Regular
if ($fam -ne 'Segoe UI Semibold') { $boldStyle = [System.Drawing.FontStyle]::Bold }
$b = New-Object System.Drawing.Bitmap $OW, $OH, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = New-Gfx $b
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#F7F4EF'))
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

$logoH = 330; $logoW = [int][math]::Round($cw * $logoH / $ch)
$logoX = 110; $logoY = [int][math]::Round(($OH - 8 - $logoH) / 2.0)
Draw-Scaled $g $crop $logoX $logoY $logoW $logoH

$textX = $logoX + $logoW + 80
$maxTextW = $OW - 60 - $textX
$sf = [System.Drawing.StringFormat]::GenericTypographic
$sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap
$headSize = 64.0; $subSize = 28.0
$headFont = New-Object System.Drawing.Font $fam, ([single]$headSize), $boldStyle, ([System.Drawing.GraphicsUnit]::Pixel)
$subFont  = New-Object System.Drawing.Font 'Segoe UI', ([single]$subSize), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$subText = 'Open-access video interviews in child health'
$subW = $g.MeasureString($subText, $subFont, 5000, $sf).Width
while ($subW -gt $maxTextW -and $subSize -gt 18) {
    $subSize -= 0.5
    $subFont.Dispose()
    $subFont = New-Object System.Drawing.Font 'Segoe UI', ([single]$subSize), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $subW = $g.MeasureString($subText, $subFont, 5000, $sf).Width
}
$w1 = $g.MeasureString('The Paediatric', $headFont, 5000, $sf).Width
$w2 = $g.MeasureString('Video Journal', $headFont, 5000, $sf).Width
Write-Host ("OG: font '{0}' head {1}px, sub {2}px; widths {3:N0}/{4:N0}/{5:N0} of max {6}; logo {7}x{8} at x={9}; text x={10}" -f $fam, $headSize, $subSize, $w1, $w2, $subW, $maxTextW, $logoW, $logoH, $logoX, $textX)
if ([math]::Max($w1, $w2) -gt $maxTextW) { throw 'Headline does not fit in available width' }

$pitch = 74.0; $gap = 22.0
$blockH = $pitch + $headSize + $gap + $subSize
$top = ($OH - 8 - $blockH) / 2.0
$cHead = [System.Drawing.ColorTranslator]::FromHtml('#1F1A24')
$cSub  = [System.Drawing.ColorTranslator]::FromHtml('#4A4553')
$bH = New-Object System.Drawing.SolidBrush $cHead
$bS = New-Object System.Drawing.SolidBrush $cSub
$g.DrawString('The Paediatric', $headFont, $bH, [single]$textX, [single]$top, $sf)
$g.DrawString('Video Journal',  $headFont, $bH, [single]$textX, [single]($top + $pitch), $sf)
$g.DrawString($subText, $subFont, $bS, [single]$textX, [single]($top + $pitch + $headSize + $gap), $sf)
$bar = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#155A75'))
$g.FillRectangle($bar, 0, $OH - 8, $OW, 8)
$bH.Dispose(); $bS.Dispose(); $bar.Dispose(); $headFont.Dispose(); $subFont.Dispose()
$g.Dispose(); Save-Png $b (Join-Path $Out 'og-default.png'); $b.Dispose()

# ---- 4. partners\pccs.png straight copy ----
Copy-Item -LiteralPath $PccsSrc -Destination (Join-Path $Out 'partners\pccs.png') -Force

$crop.Dispose()
Write-Host 'Done.'
