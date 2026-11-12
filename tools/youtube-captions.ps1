param([string[]]$Only, [switch]$Force)

# Downloads the public captions of every video in content/videos.json into
# work/captions/<youtubeId>.txt (plain text, one caption line per line).
# Read-only against YouTube, no login. Skips videos already downloaded.
#   -Only id1,id2 : just these videos      -Force : download again
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ }) }
$outDir = Join-Path (Join-Path $root 'work') 'captions'
[void][IO.Directory]::CreateDirectory($outDir)
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

function Get-Url([string]$url) {
    $wc = New-Object Net.WebClient
    $wc.Encoding = $utf8
    $wc.Headers['User-Agent'] = $ua
    $wc.Headers['Accept-Language'] = 'en-GB,en;q=0.9'
    $wc.Headers['Cookie'] = 'SOCS=CAI; CONSENT=YES+1'
    try { return $wc.DownloadString($url) } finally { $wc.Dispose() }
}
function Post-Json([string]$url, [string]$body) {
    $wc = New-Object Net.WebClient
    $wc.Encoding = $utf8
    $wc.Headers['User-Agent'] = $ua
    $wc.Headers['Content-Type'] = 'application/json'
    try { return $wc.UploadString($url, 'POST', $body) } finally { $wc.Dispose() }
}
function Unescape-Json([string]$raw) { try { return (('"' + $raw + '"') | ConvertFrom-Json) } catch { return $raw } }

# Route 1: the caption track listed on the watch page.
function Captions-FromTrack([string]$html) {
    $m = [regex]::Match($html, '"captionTracks":\[\{"baseUrl":"((?:[^"\\]|\\.)*)"')
    if (-not $m.Success) { return $null }
    $url = (Unescape-Json $m.Groups[1].Value) + '&fmt=json3'
    $json = Get-Url $url
    if (-not $json -or $json.Length -lt 20) { return $null }
    $lines = New-Object Collections.Generic.List[string]
    foreach ($ev in [regex]::Matches($json, '"segs":\[(.*?)\]\s*[,}]')) {
        $text = ''
        foreach ($s in [regex]::Matches($ev.Groups[1].Value, '"utf8":"((?:[^"\\]|\\.)*)"')) { $text += (Unescape-Json $s.Groups[1].Value) }
        $text = ($text -replace '\s+', ' ').Trim()
        if ($text) { $lines.Add($text) }
    }
    if ($lines.Count -eq 0) { return $null }
    return $lines
}
# Route 2: the "Show transcript" panel.
function Captions-FromPanel([string]$html) {
    $m = [regex]::Match($html, '"getTranscriptEndpoint":\{"params":"([^"]+)"')
    if (-not $m.Success) { return $null }
    $body = '{"context":{"client":{"clientName":"WEB","clientVersion":"2.20240701.00.00","hl":"en-GB","gl":"GB"}},"params":"' + $m.Groups[1].Value + '"}'
    $json = Post-Json 'https://www.youtube.com/youtubei/v1/get_transcript?prettyPrint=false' $body
    $lines = New-Object Collections.Generic.List[string]
    foreach ($seg in [regex]::Matches($json, '"transcriptSegmentRenderer":\{.*?"snippet":\{"runs":\[(.*?)\]\}')) {
        $text = ''
        foreach ($s in [regex]::Matches($seg.Groups[1].Value, '"text":"((?:[^"\\]|\\.)*)"')) { $text += (Unescape-Json $s.Groups[1].Value) }
        $text = ($text -replace '\s+', ' ').Trim()
        if ($text) { $lines.Add($text) }
    }
    if ($lines.Count -eq 0) { return $null }
    return $lines
}

$videos = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path (Join-Path $root 'content') 'videos.json'), [Text.Encoding]::UTF8))
$done = 0; $skipped = 0; $failed = New-Object Collections.Generic.List[string]
foreach ($v in $videos) {
    $id = $v.youtubeId
    if ($Only -and ($Only -cnotcontains $id)) { continue }
    $file = Join-Path $outDir ($id + '.txt')
    if ((Test-Path -LiteralPath $file) -and -not $Force) { $skipped++; continue }
    $lines = $null; $route = ''
    try {
        $html = Get-Url ('https://www.youtube.com/watch?v=' + $id)
        try { $lines = Captions-FromTrack $html; if ($lines) { $route = 'track' } } catch { }
        if (-not $lines) { try { $lines = Captions-FromPanel $html; if ($lines) { $route = 'panel' } } catch { } }
    } catch { }
    if ($lines) {
        [IO.File]::WriteAllLines($file, $lines, $utf8)
        $done++
        Write-Host ("{0}  {1,4} lines  via {2}" -f $id, $lines.Count, $route)
    } else {
        $failed.Add($id)
        Write-Host ("{0}  NO CAPTIONS" -f $id)
    }
    Start-Sleep -Milliseconds 300
}
"downloaded: $done   already had: $skipped   failed: $($failed.Count)"
if ($failed.Count -gt 0) { "failed ids: " + ($failed -join ' ') }
