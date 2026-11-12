param([int]$Batches = 4)

# Step 1 of making thumbnails for videos that still use a raw video frame
# (every video whose conference slug starts with "rcpch").
# For each video it downloads YouTube's four frame candidates
#   <id>-0.jpg (the current thumbnail), <id>-1.jpg, <id>-2.jpg, <id>-3.jpg   into work/thumbnails/frames
# and draws work/thumbnails/candidates/<id>.jpg : the four frames in a 2x2 grid, each
# labelled with its number and carrying a ruler in SOURCE pixels (0..1280) so a face
# position can be read off. It also writes work/thumbnails/batch-K.txt work lists.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$tdir = Join-Path (Join-Path $root 'work') 'thumbnails'
$frames = Join-Path $tdir 'frames'; $cands = Join-Path $tdir 'candidates'
[void][IO.Directory]::CreateDirectory($frames); [void][IO.Directory]::CreateDirectory($cands)
$utf8 = New-Object Text.UTF8Encoding($false)
$videos = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path (Join-Path $root 'content') 'videos.json'), [Text.Encoding]::UTF8))
$todo = @($videos | Where-Object { ([string]$_.conference).StartsWith('rcpch') })

$names = @('maxresdefault', 'maxres1', 'maxres2', 'maxres3')
$font = New-Object Drawing.Font('Segoe UI', 22, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$small = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$missing = 0
foreach ($v in $todo) {
    $id = $v.youtubeId
    for ($n = 0; $n -lt 4; $n++) {
        $file = Join-Path $frames ("$id-$n.jpg")
        if (Test-Path -LiteralPath $file) { continue }
        $wc = New-Object Net.WebClient
        try { $wc.DownloadFile("https://i.ytimg.com/vi/$id/$($names[$n]).jpg", $file) } catch { $missing++ } finally { $wc.Dispose() }
    }
    $sheet = New-Object Drawing.Bitmap(1280, 760, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [Drawing.Graphics]::FromImage($sheet)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAlias
    $g.Clear([Drawing.Color]::FromArgb(30, 30, 30))
    for ($n = 0; $n -lt 4; $n++) {
        $file = Join-Path $frames ("$id-$n.jpg")
        $x = ($n % 2) * 640; $y = [Math]::Floor($n / 2) * 380
        if (Test-Path -LiteralPath $file) {
            $ok = $true
            try { $im = [Drawing.Image]::FromFile($file) } catch { $ok = $false }
            if ($ok) {
                if ($im.Width -ge 1000) { $g.DrawImage($im, $x, $y + 20, 640, 360) } else { $ok = $false }
                $im.Dispose()
            }
            if (-not $ok) { Remove-Item -LiteralPath $file -Force }
        }
        # ruler: source pixels 0..1280 map to 640 px here
        $g.FillRectangle([Drawing.Brushes]::Black, $x, $y, 640, 20)
        for ($t = 0; $t -le 1280; $t += 160) {
            $tx = $x + $t / 2
            $g.DrawLine([Drawing.Pens]::Yellow, [single]$tx, [single]$y, [single]$tx, [single]($y + 20))
            if ($t -lt 1280) { $g.DrawString([string]$t, $small, [Drawing.Brushes]::Yellow, [single]($tx + 2), [single]($y + 2)) }
        }
        $label = "frame $n"; if (-not (Test-Path -LiteralPath $file)) { $label = "frame $n - not available" }
        $g.FillRectangle([Drawing.Brushes]::Black, $x + 6, $y + 26, 250, 32)
        $g.DrawString($label, $font, [Drawing.Brushes]::White, [single]($x + 12), [single]($y + 28))
    }
    $codec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]80)
    $sheet.Save((Join-Path $cands ($id + '.jpg')), $codec, $ep)
    $ep.Dispose(); $g.Dispose(); $sheet.Dispose()
}
$font.Dispose(); $small.Dispose()

$per = [Math]::Ceiling($todo.Count / $Batches)
for ($b = 0; $b -lt $Batches; $b++) {
    $sb = New-Object Text.StringBuilder
    $slice = @($todo | Select-Object -Skip ($b * $per) -First $per)
    foreach ($v in $slice) {
        [void]$sb.AppendLine('ID: ' + $v.youtubeId)
        [void]$sb.AppendLine('CONFERENCE: ' + $v.conference)
        [void]$sb.AppendLine('TITLE: ' + $v.title)
        [void]$sb.AppendLine('SPEAKERS: ' + ((@($v.speakers) | ForEach-Object { $_.name }) -join '; '))
        [void]$sb.AppendLine()
    }
    [IO.File]::WriteAllText((Join-Path $tdir ("batch-" + ($b + 1) + ".txt")), $sb.ToString(), $utf8)
    "batch $($b + 1): $($slice.Count) videos"
}
"videos: $($todo.Count)   frames that could not be downloaded: $missing"
