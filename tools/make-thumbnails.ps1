param([Parameter(Mandatory = $true)][string]$Plan, [string]$SheetName = '')

# Step 2: renders finished 1280x720 thumbnails in the approved PVJ layout
# (photo left, panel right, accent in PVJ red - "option B") from a plan file.
#
# Plan = tab-separated text, one video per line, lines starting with # ignored:
#   id <TAB> frame(0-3) <TAB> cropX <TAB> line above the name (e.g. Professor, or empty)
#      <TAB> name line <TAB> headline line 1 <TAB> line 2 <TAB> line 3 (2 and 3 may be empty)
# cropX = left edge, in source pixels, of the 674 px wide slice of the 1280 px frame.
# Output: work/thumbnails/final/<id>.jpg, and with -SheetName X a contact sheet
# work/thumbnails/final/sheet-X.jpg of everything in the plan.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$W = Split-Path -Parent $PSScriptRoot
$Frames = Join-Path $W 'work\thumbnails\frames'
$Out = Join-Path $W 'work\thumbnails\final'
$Logo = Join-Path $W 'src\brand\PVJ-red-blue-original.png'
[void][IO.Directory]::CreateDirectory($Out)
$Dot = [string][char]0x00B7
# (named AccentHex, not Accent: PowerShell names are case-insensitive and the loop has an $accent brush)
$AccentHex = '#9E2A2B'

$videos = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $W 'content\videos.json'), [Text.Encoding]::UTF8))
$confOf = @{}; foreach ($v in $videos) { $confOf[$v.youtubeId] = [string]$v.conference }
$subOf = @{ 'rcpch-2025' = "2025 $Dot GLASGOW"; 'rcpch-2024' = "2024 $Dot BIRMINGHAM" }

# layout numbers from the approved 2026 design
$PhotoW = 674; $BarX = 674; $BarW = 8; $TextX = 732
$HeadSize = 58; $HeadBase = @(280, 345, 410); $HeadColor = '#251B29'
$RuleX = 734; $RuleY = 475; $RuleW = 50; $RuleH = 3
$NameSize = 40; $NameColor = '#655A68'; $NameBase1 = 524; $NameBase2 = 568
$PanelColor = '#F7F4F0'
$LogoDest = @(732, 588, 118, 105); $LogoSrc = @(403, 163, 2831, 2528)
$MaxTextRight = 1232

function C([string]$hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
$FmtT = [Drawing.StringFormat]::GenericTypographic
$FmtT.FormatFlags = $FmtT.FormatFlags -bor [Drawing.StringFormatFlags]::NoWrap
function Get-Font([string]$family, [double]$px) { New-Object Drawing.Font($family, [single]$px, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel) }
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
    $bmp.Save($path, $codec, $ep); $ep.Dispose()
}
function New-Graphics($bmp) {
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'; $g.CompositingQuality = 'HighQuality'
    $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAlias
    $g
}

$rows = @()
foreach ($line in [IO.File]::ReadAllLines($Plan, [Text.Encoding]::UTF8)) {
    if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
    $c = $line -split "`t"
    while ($c.Count -lt 8) { $c += '' }
    $rows += [pscustomobject]@{ id = $c[0].Trim(); frame = $c[1].Trim(); cropX = [int]$c[2].Trim(); pre = $c[3].Trim(); name = $c[4].Trim(); head = @($c[5].Trim(), $c[6].Trim(), $c[7].Trim() | Where-Object { $_ }) }
}

$logoImg = [Drawing.Image]::FromFile($Logo)
$ia = New-Object Drawing.Imaging.ImageAttributes
$ia.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
$problems = 0; $made = @()
foreach ($r in $rows) {
    try {
        if (-not $confOf.ContainsKey($r.id)) { throw 'id is not in content/videos.json' }
        $sub = $subOf[$confOf[$r.id]]; if (-not $sub) { throw "no label for conference $($confOf[$r.id])" }
        $framePath = Join-Path $Frames ("$($r.id)-$($r.frame).jpg")
        if (-not (Test-Path -LiteralPath $framePath)) { throw "frame $($r.frame) does not exist" }
        if ($r.head.Count -lt 1) { throw 'no headline' }
        if ($r.cropX -lt 0 -or $r.cropX -gt 606) { throw "cropX $($r.cropX) is outside 0..606" }
        if (-not $r.name) { throw 'no name line' }
        $frame = [Drawing.Image]::FromFile($framePath)
        $bmp = New-Object Drawing.Bitmap(1280, 720, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $bmp.SetResolution(96, 96)
        $g = New-Graphics $bmp
        $accent = New-Object Drawing.SolidBrush (C $AccentHex)
        $panel = New-Object Drawing.SolidBrush (C $PanelColor)
        $g.FillRectangle($panel, 0, 0, 1280, 720)
        $g.DrawImage($frame, (New-Object Drawing.Rectangle(0, 0, $PhotoW, 720)), $r.cropX, 0, $PhotoW, 720, [Drawing.GraphicsUnit]::Pixel)
        $g.FillRectangle($accent, $BarX, 0, $BarW, 720)
        $f1 = Get-Font 'Inter SemiBold' 40; $f2 = Get-Font 'Inter SemiBold' 28
        Draw-Base $g 'RCPCH CONFERENCE' $f1 $accent 733 146
        Draw-Base $g $sub $f2 $accent 734 196
        $f1.Dispose(); $f2.Dispose()
        # headline: shrink in steps until every line fits
        $size = $HeadSize
        while ($true) {
            $f = Get-Font 'Inter SemiBold' $size
            $maxw = 0; foreach ($ln in $r.head) { $maxw = [Math]::Max($maxw, (Text-Width $g $ln $f)) }
            if ($TextX + $maxw -le $MaxTextRight -or $size -le 42) { break }
            $f.Dispose(); $size -= 4
        }
        $tooWide = ($TextX + $maxw -gt $MaxTextRight)
        $hb = New-Object Drawing.SolidBrush (C $HeadColor)
        for ($i = 0; $i -lt $r.head.Count; $i++) { Draw-Base $g $r.head[$i] $f $hb $TextX $HeadBase[$i] }
        $f.Dispose(); $hb.Dispose()
        $g.FillRectangle($accent, $RuleX, $RuleY, $RuleW, $RuleH)
        # name lines: shrink together if the longer one does not fit
        $nsize = $NameSize
        while ($true) {
            $fn = Get-Font 'Inter' $nsize
            $nw = [Math]::Max((Text-Width $g $r.name $fn), (Text-Width $g $r.pre $fn))
            if ($TextX + $nw -le $MaxTextRight -or $nsize -le 28) { break }
            $fn.Dispose(); $nsize -= 2
        }
        $nameWide = ($TextX + $nw -gt $MaxTextRight)
        $nb = New-Object Drawing.SolidBrush (C $NameColor)
        if ($r.pre) { Draw-Base $g $r.pre $fn $nb $TextX $NameBase1 }
        Draw-Base $g $r.name $fn $nb $TextX $NameBase2
        $fn.Dispose(); $nb.Dispose()
        $g.DrawImage($logoImg, (New-Object Drawing.Rectangle($LogoDest[0], $LogoDest[1], $LogoDest[2], $LogoDest[3])), $LogoSrc[0], $LogoSrc[1], $LogoSrc[2], $LogoSrc[3], [Drawing.GraphicsUnit]::Pixel, $ia)
        $outFile = Join-Path $Out ($r.id + '.jpg')
        Save-Jpeg $bmp $outFile 92
        $accent.Dispose(); $panel.Dispose(); $g.Dispose(); $bmp.Dispose(); $frame.Dispose()
        $made += $r
        if ($tooWide) { $problems++; "PROBLEM  $($r.id)  headline too wide even at 42 px: shorten a line" }
        elseif ($nameWide) { $problems++; "PROBLEM  $($r.id)  name line too wide: shorten or split it" }
        else { "ok       $($r.id)  headline $size px, name $nsize px" }
    } catch { $problems++; "PROBLEM  $($r.id)  $($_.Exception.Message)" }
}
$logoImg.Dispose(); $ia.Dispose()

if ($SheetName -and $made.Count -gt 0) {
    $cols = 4; $tw = 400; $th = 225; $pad = 16; $lab = 26
    $rowsN = [Math]::Ceiling($made.Count / $cols)
    $sheet = New-Object Drawing.Bitmap(($cols * ($tw + $pad) + $pad), ($rowsN * ($th + $lab + $pad) + $pad), [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = New-Graphics $sheet; $g.Clear((C '#E6E6E6'))
    $lf = Get-Font 'Segoe UI' 15; $lb = New-Object Drawing.SolidBrush (C '#333333')
    for ($i = 0; $i -lt $made.Count; $i++) {
        $x = $pad + ($i % $cols) * ($tw + $pad); $y = $pad + [Math]::Floor($i / $cols) * ($th + $lab + $pad)
        $im = [Drawing.Image]::FromFile((Join-Path $Out ($made[$i].id + '.jpg')))
        $g.DrawImage($im, $x, $y, $tw, $th); $im.Dispose()
        $g.DrawString($made[$i].id, $lf, $lb, [single]$x, [single]($y + $th + 3))
    }
    Save-Jpeg $sheet (Join-Path $Out ("sheet-$SheetName.jpg")) 88
    $lf.Dispose(); $lb.Dispose(); $g.Dispose(); $sheet.Dispose()
    "contact sheet: work\thumbnails\final\sheet-$SheetName.jpg"
}
"rendered $($made.Count) of $($rows.Count); problems: $problems"
if ($problems -gt 0) { exit 1 }
