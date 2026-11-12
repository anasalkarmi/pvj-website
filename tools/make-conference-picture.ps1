param(
    [Parameter(Mandatory = $true)][string]$Main,
    [Parameter(Mandatory = $true)][string]$MainCrop,
    [Parameter(Mandatory = $true)][string]$Stills,
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Plate = ''
)

# Makes the 1280x720 picture a conference shows on its card and at the top of its page:
# the conference photo on the left (1080x720) and three interview stills stacked on the right.
# This is the layout the owner approved for PCCS 2026 and asked to repeat for RCPCH.
#
#   -Main      the conference photo
#   -MainCrop  "x,y,w,h" in the photo's own pixels; keep it 3:2 (it is scaled to 1080x720)
#   -Stills    three stills, comma separated, each "file:cropX". A bare name such as
#              "PVGv3GYIQoo-0.jpg" is looked up in src\thumbnails\stills. cropX is the same number
#              as in the thumbnail plan: the left edge of the 674 px slice that centres the face
#              in a 1280 px wide frame.
#   -Out       the JPEG to write (normally src\assets\img\conferences\<conference-slug>.jpg)
#   -Plate     optional logo (PNG with transparency) shown on a white plate at the top left,
#              for a photo that does not itself show whose conference it is
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$stillDir = Join-Path $root 'src\thumbnails\stills'

$W = 1280; $H = 720; $mainW = 1080; $gap = 4; $sideX = $mainW + $gap; $sideW = $W - $sideX
$tileY = @(0, 241, 483); $tileH = @(237, 238, 237)

$bmp = New-Object Drawing.Bitmap $W, $H
$g = [Drawing.Graphics]::FromImage($bmp)
$g.Clear([Drawing.Color]::White)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias

$c = @($MainCrop -split ',' | ForEach-Object { [int]$_.Trim() })
if ($c.Count -ne 4) { throw '-MainCrop needs four numbers: x,y,w,h' }
$src = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $Main).Path)
$g.DrawImage($src, (New-Object Drawing.Rectangle 0, 0, $mainW, $H), (New-Object Drawing.Rectangle $c[0], $c[1], $c[2], $c[3]), [Drawing.GraphicsUnit]::Pixel)
$src.Dispose()

$list = @($Stills -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($list.Count -ne 3) { throw '-Stills needs exactly three entries' }
for ($i = 0; $i -lt 3; $i++) {
    $cut = $list[$i].LastIndexOf(':')
    if ($cut -lt 1) { throw "still '$($list[$i])' needs the form file:cropX" }
    $file = $list[$i].Substring(0, $cut); $cropX = [int]$list[$i].Substring($cut + 1)
    if (-not (Test-Path -LiteralPath $file)) { $file = Join-Path $stillDir $file }
    $s = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $file).Path)
    # a full-height slice with the tile's proportions, centred where the thumbnail plan centres the face
    $scale = $s.Width / 1280.0
    $cw = [int][Math]::Round($s.Height * $sideW / $tileH[$i])
    $cx = [int][Math]::Round(($cropX + 337) * $scale - $cw / 2)
    if ($cx -lt 0) { $cx = 0 }; if ($cx + $cw -gt $s.Width) { $cx = $s.Width - $cw }
    $g.DrawImage($s, (New-Object Drawing.Rectangle $sideX, $tileY[$i], $sideW, $tileH[$i]), (New-Object Drawing.Rectangle $cx, 0, $cw, $s.Height), [Drawing.GraphicsUnit]::Pixel)
    $s.Dispose()
}

if ($Plate) {
    $logo = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $Plate).Path)
    $lw = 250; $lh = [int][Math]::Round($logo.Height * $lw / $logo.Width); $pad = 20; $x = 34; $y = 34
    $pw = $lw + 2 * $pad; $ph = $lh + 2 * $pad; $r = 16
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x, $y, 2 * $r, 2 * $r, 180, 90); $path.AddArc($x + $pw - 2 * $r, $y, 2 * $r, 2 * $r, 270, 90)
    $path.AddArc($x + $pw - 2 * $r, $y + $ph - 2 * $r, 2 * $r, 2 * $r, 0, 90); $path.AddArc($x, $y + $ph - 2 * $r, 2 * $r, 2 * $r, 90, 90)
    $path.CloseFigure()
    $g.FillPath([Drawing.Brushes]::White, $path); $path.Dispose()
    $g.DrawImage($logo, (New-Object Drawing.Rectangle ($x + $pad), ($y + $pad), $lw, $lh))
    $logo.Dispose()
}
$g.Dispose()

$outPath = $Out; if (-not [IO.Path]::IsPathRooted($outPath)) { $outPath = Join-Path (Get-Location).Path $outPath }
$codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]88)
$bmp.Save($outPath, $codec, $ep); $bmp.Dispose()
Write-Host ("wrote {0} ({1} KB)" -f $outPath, [int]((Get-Item -LiteralPath $outPath).Length / 1KB))
