# Sample thumbnails: approved design A applied to older RCPCH videos (options A teal, B red).
# Writes only into work\thumbnails\samples\ . Nothing is uploaded or published.
# Plain ASCII on purpose (Windows PowerShell 5.1).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$W      = Split-Path -Parent $PSScriptRoot
$Frames = Join-Path $W 'work\thumbnails\frames'
$Out    = Join-Path $W 'work\thumbnails\samples'
$Logo   = Join-Path $W 'src\brand\PVJ-red-blue-original.png'
$Ref    = 'C:\Users\Anas Alkarmi\Documents\Codex\2026-11-05\i-edited-a-project-for-rccph\new-batch\thumbnails\final-approved-A-safe\C020-approved-A.jpg'
$Dot    = [string][char]0x00B7

# ---- Photo crop offsets: left edge (px) of the 674 px wide crop inside the 1280x720 frame ----
# One row per video. Edit CropX to move the speaker left/right in the photo area.
$Items = @(
  @{ Id='PVGv3GYIQoo'; Speaker='Grace Hastie';           Pre='';          CropX=98;  Sub="2025 $Dot GLASGOW";    Head=@('Equity for','children seeking','asylum') },
  @{ Id='gxMqx95Kle4'; Speaker='Damian Roland';          Pre='Professor'; CropX=458; Sub="2025 $Dot GLASGOW";    Head=@('Standardising','paediatric early','warning systems') },
  @{ Id='yaH7wfjVIJQ'; Speaker='Mark Peters';            Pre='Professor'; CropX=440; Sub="2024 $Dot BIRMINGHAM"; Head=@('Phoenix criteria','for paediatric','sepsis') }
)
$Options = @(
  @{ Letter='A'; Accent='#155A75' },
  @{ Letter='B'; Accent='#9E2A2B' }
)

# ---- Layout numbers from C020-approved-A.svg (1280x720) ----
$PhotoW = 674; $BarX = 674; $BarW = 8; $TextX = 732
$HeadSize = 58; $HeadBase = @(280,345,410); $HeadColor = '#251B29'
$RuleX = 734; $RuleY = 475; $RuleW = 50; $RuleH = 3
$NameSize = 40; $NameColor = '#655A68'; $NameBase1 = 524; $NameBase2 = 568
$PanelColor = '#F7F4F0'
$LogoDest = @(732,588,118,105.37054044507241); $LogoSrc = @(403,163,2831,2528)
$MaxTextRight = 1232   # keep 48 px clear of the right edge

function C([string]$hex) { [Drawing.ColorTranslator]::FromHtml($hex) }

$FmtT = [Drawing.StringFormat]::GenericTypographic
$FmtT.FormatFlags = $FmtT.FormatFlags -bor [Drawing.StringFormatFlags]::NoWrap

function Get-Font([string]$family, [double]$px) {
  New-Object Drawing.Font($family, [single]$px, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
}
function Text-Width($g, [string]$s, $font) { $g.MeasureString($s, $font, 5000, $FmtT).Width }
function Draw-Base($g, [string]$s, $font, $brush, [double]$x, [double]$baseline) {
  $fam = $font.FontFamily
  $asc = $fam.GetCellAscent($font.Style) / $fam.GetEmHeight($font.Style) * $font.Size
  $g.DrawString($s, $font, $brush, [single]$x, [single]($baseline - $asc), $FmtT)
}

function Save-Jpeg($bmp, [string]$path, [int]$q) {
  $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $ep = New-Object Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]$q)
  $bmp.Save($path, $codec, $ep)
  $ep.Dispose()
}
function New-Graphics($bmp) {
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode = 'HighQuality'
  $g.CompositingQuality = 'HighQuality'
  $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAlias
  $g
}

New-Item -ItemType Directory -Force $Out | Out-Null
$logoImg = [Drawing.Image]::FromFile($Logo)
$ia = New-Object Drawing.Imaging.ImageAttributes
$ia.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)

foreach ($it in $Items) {
  $frame = [Drawing.Image]::FromFile((Join-Path $Frames ($it.Id + '.jpg')))
  foreach ($op in $Options) {
    $bmp = New-Object Drawing.Bitmap(1280, 720, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $bmp.SetResolution(96, 96)
    $g = New-Graphics $bmp
    $accent = New-Object Drawing.SolidBrush (C $op.Accent)
    $panel  = New-Object Drawing.SolidBrush (C $PanelColor)
    $g.FillRectangle($panel, 0, 0, 1280, 720)
    # photo (full height, 1:1 scale)
    $g.DrawImage($frame, (New-Object Drawing.Rectangle(0, 0, $PhotoW, 720)), $it.CropX, 0, $PhotoW, 720, [Drawing.GraphicsUnit]::Pixel)
    $g.FillRectangle($accent, $BarX, 0, $BarW, 720)

    # conference block
    $fSemi1 = Get-Font 'Inter SemiBold' 40
    $fSemi2 = Get-Font 'Inter SemiBold' 28
    Draw-Base $g 'RCPCH CONFERENCE' $fSemi1 $accent 733 146
    Draw-Base $g $it.Sub $fSemi2 $accent 734 196
    $fSemi1.Dispose(); $fSemi2.Dispose()

    # headline: shrink in steps until every line fits the width
    $size = $HeadSize
    while ($true) {
      $f = Get-Font 'Inter SemiBold' $size
      $maxw = 0
      foreach ($ln in $it.Head) { $maxw = [Math]::Max($maxw, (Text-Width $g $ln $f)) }
      if ($TextX + $maxw -le $MaxTextRight -or $size -le 44) { break }
      $f.Dispose(); $size -= 4
    }
    if ($TextX + $maxw -gt $MaxTextRight) { throw "Headline too wide for $($it.Id)" }
    $hb = New-Object Drawing.SolidBrush (C $HeadColor)
    for ($i = 0; $i -lt $it.Head.Count; $i++) { Draw-Base $g $it.Head[$i] $f $hb $TextX $HeadBase[$i] }
    $f.Dispose(); $hb.Dispose()
    Write-Host ("{0}-{1}: headline size {2}" -f $it.Id, $op.Letter, $size)

    # rule
    $g.FillRectangle($accent, $RuleX, $RuleY, $RuleW, $RuleH)

    # speaker name (title line only when present; name sits on the second baseline either way)
    $fn = Get-Font 'Inter' $NameSize
    $nb = New-Object Drawing.SolidBrush (C $NameColor)
    if ($it.Pre) { Draw-Base $g $it.Pre $fn $nb $TextX $NameBase1 }
    Draw-Base $g $it.Speaker $fn $nb $TextX $NameBase2
    if ($TextX + (Text-Width $g $it.Speaker $fn) -gt $MaxTextRight) { throw "Name too wide for $($it.Id)" }
    $fn.Dispose(); $nb.Dispose()

    # PVJ logo (cropped to its visible pixels)
    $dr = New-Object Drawing.RectangleF($LogoDest[0], $LogoDest[1], $LogoDest[2], $LogoDest[3])
    $g.DrawImage($logoImg, [Drawing.Rectangle]::Round($dr), $LogoSrc[0], $LogoSrc[1], $LogoSrc[2], $LogoSrc[3], [Drawing.GraphicsUnit]::Pixel, $ia)

    Save-Jpeg $bmp (Join-Path $Out ($it.Id + '-' + $op.Letter + '.jpg')) 92
    $accent.Dispose(); $panel.Dispose(); $g.Dispose(); $bmp.Dispose()
  }
  $frame.Dispose()
}

# ---- Overview contact sheet (1400 wide) ----
$tw = 640; $th = 360; $m = 40
$rowPitch = $th + 70
$H = 40 + $th + 80 + 3 * $rowPitch + 10
$sheet = New-Object Drawing.Bitmap(1400, $H, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
$sheet.SetResolution(96, 96)
$g = New-Graphics $sheet
$g.Clear((C '#E6E6E6'))
$lf = Get-Font 'Inter SemiBold' 24
$lb = New-Object Drawing.SolidBrush (C '#333333')
$ri = [Drawing.Image]::FromFile($Ref)
$g.DrawImage($ri, 380, 40, $tw, $th)
Draw-Base $g 'Approved 2026 design' $lf $lb 380 ($th + 40 + 34)
$ri.Dispose()
$y = 40 + $th + 80
foreach ($it in $Items) {
  $x = $m
  foreach ($op in $Options) {
    $im = [Drawing.Image]::FromFile((Join-Path $Out ($it.Id + '-' + $op.Letter + '.jpg')))
    $g.DrawImage($im, $x, $y, $tw, $th)
    $im.Dispose()
    $name = $it.Speaker
    if ($it.Pre) { $name = $it.Pre + ' ' + $it.Speaker }
    Draw-Base $g ("Option " + $op.Letter + " - " + $name) $lf $lb $x ($y + $th + 34)
    $x += $tw + $m
  }
  $y += $rowPitch
}
Save-Jpeg $sheet (Join-Path $Out 'overview.jpg') 92
$lf.Dispose(); $lb.Dispose(); $g.Dispose(); $sheet.Dispose()
$ia.Dispose(); $logoImg.Dispose()
Write-Host 'Done.'
