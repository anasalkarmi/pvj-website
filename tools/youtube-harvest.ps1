param(
    [Parameter(Mandatory = $true)][string]$OutFile,
    [string]$ChannelId = 'UCTDx9ovxVjT-F92cxOrQhmg',
    [int]$Max = 600
)

# Reads the PUBLIC video list of a YouTube channel (its "uploads" playlist) and
# each video's public title / description / duration / publish date.
# No login, no API key, read-only. Output: a UTF-8 JSON array.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$utf8 = New-Object Text.UTF8Encoding($false)
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
$clientCtx = '{"client":{"clientName":"WEB","clientVersion":"2.20240701.00.00","hl":"en-GB","gl":"GB"}}'

function Invoke-Post([string]$url, [string]$body) {
    $wc = New-Object Net.WebClient
    $wc.Encoding = $utf8
    $wc.Headers['User-Agent'] = $ua
    $wc.Headers['Content-Type'] = 'application/json'
    $wc.Headers['Accept-Language'] = 'en-GB,en;q=0.9'
    try { return $wc.UploadString($url, 'POST', $body) } finally { $wc.Dispose() }
}

function Invoke-Get([string]$url) {
    $wc = New-Object Net.WebClient
    $wc.Encoding = $utf8
    $wc.Headers['User-Agent'] = $ua
    $wc.Headers['Accept-Language'] = 'en-GB,en;q=0.9'
    $wc.Headers['Cookie'] = 'SOCS=CAI; CONSENT=YES+1'
    try { return $wc.DownloadString($url) } finally { $wc.Dispose() }
}

function Unescape-Json([string]$raw) {
    try { return (('"' + $raw + '"') | ConvertFrom-Json) } catch { return $raw }
}

function Get-Field([string]$text, [string]$key) {
    $m = [regex]::Match($text, '"' + $key + '":"((?:[^"\\]|\\.)*)"')
    if ($m.Success) { return (Unescape-Json $m.Groups[1].Value) }
    return $null
}

# ---- 1. list the uploads playlist (100 per page, follow continuations) ----
$uploads = 'VL' + 'UU' + $ChannelId.Substring(2)
$ids = New-Object Collections.Generic.List[string]
$resp = Invoke-Post 'https://www.youtube.com/youtubei/v1/browse?prettyPrint=false' ('{"context":' + $clientCtx + ',"browseId":"' + $uploads + '"}')
$page = 0
while ($true) {
    $page++
    $found = 0
    foreach ($m in [regex]::Matches($resp, '"playlistVideoRenderer":\{"videoId":"([A-Za-z0-9_-]{11})"')) {
        $id = $m.Groups[1].Value
        if (-not $ids.Contains($id)) { $ids.Add($id); $found++ }
    }
    if ($found -eq 0) {
        foreach ($m in [regex]::Matches($resp, '"contentId":"([A-Za-z0-9_-]{11})"')) {
            $id = $m.Groups[1].Value
            if (-not $ids.Contains($id)) { $ids.Add($id); $found++ }
        }
    }
    Write-Host ("page {0}: +{1} (total {2})" -f $page, $found, $ids.Count)
    $tok = [regex]::Match($resp, '"continuationCommand":\{"token":"([^"]+)"')
    if (-not $tok.Success -or $found -eq 0 -or $ids.Count -ge $Max) { break }
    $resp = Invoke-Post 'https://www.youtube.com/youtubei/v1/browse?prettyPrint=false' ('{"context":' + $clientCtx + ',"continuation":"' + $tok.Groups[1].Value + '"}')
}
if ($ids.Count -eq 0) {
    [IO.File]::WriteAllText(($OutFile + '.browse-debug.txt'), $resp.Substring(0, [Math]::Min(6000, $resp.Length)), $utf8)
    throw 'No videos found in the uploads playlist response (debug saved).'
}

# ---- 2. per-video details from the public watch page ----
$out = New-Object Collections.Generic.List[object]
$n = 0
foreach ($id in $ids) {
    $n++
    $html = $null
    for ($try = 1; $try -le 3 -and -not $html; $try++) {
        try { $html = Invoke-Get ('https://www.youtube.com/watch?v=' + $id) } catch { Start-Sleep -Milliseconds (700 * $try) }
    }
    if (-not $html) { Write-Host "  $id FAILED"; $out.Add([pscustomobject]@{ id = $id; error = 'fetch failed' }); continue }
    $len = [regex]::Match($html, '"lengthSeconds":"(\d+)"')
    $pub = [regex]::Match($html, '"publishDate":"([^"]+)"')
    $out.Add([pscustomobject]@{
        id          = $id
        title       = (Get-Field $html 'title')
        description = (Get-Field $html 'shortDescription')
        seconds     = $(if ($len.Success) { [int]$len.Groups[1].Value } else { $null })
        published   = $(if ($pub.Success) { $pub.Groups[1].Value } else { $null })
        channel     = (Get-Field $html 'ownerChannelName')
        isShort     = ($html -match '"isShortsEligible":true')
    })
    if ($n % 20 -eq 0) { Write-Host ("  details {0}/{1}" -f $n, $ids.Count) }
    Start-Sleep -Milliseconds 250
}

$json = ConvertTo-Json -InputObject @($out.ToArray()) -Depth 4
[IO.File]::WriteAllText($OutFile, $json, $utf8)
"videos: {0}  with errors: {1}" -f $out.Count, @($out | Where-Object { $_.error }).Count
