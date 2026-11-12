param([int]$Port = 4174, [int]$Parts = 1)

# One-off helper for collecting YouTube captions gathered in the browser.
# YouTube only serves captions to its own pages, so they are collected there and
# handed to this local receiver: the browser tab is sent to
#   http://localhost:<Port>/recv?part=N#<url-encoded JSON>
# and the page served here posts that JSON back, which is written to
#   work/captions/part-N.json
# Listens on localhost only and stops after the expected number of parts.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path (Join-Path $root 'work') 'captions'
[void][IO.Directory]::CreateDirectory($outDir)
$utf8 = New-Object Text.UTF8Encoding($false)
$page = @'
<!doctype html><meta charset="utf-8"><title>PVJ caption receiver</title>
<body style="font:16px system-ui;padding:40px"><p id="s">Saving...</p>
<script>
(async function () {
  var part = new URLSearchParams(location.search).get('part') || '1';
  var data = decodeURIComponent(location.hash.slice(1));
  try {
    var r = await fetch('/save?part=' + encodeURIComponent(part), {method: 'POST', headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: data});
    document.getElementById('s').textContent = 'Saved part ' + part + ': ' + (await r.text());
    document.title = 'saved ' + part;
  } catch (e) { document.getElementById('s').textContent = 'Failed: ' + e; document.title = 'failed ' + part; }
})();
</script>
'@
$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "caption receiver listening on http://localhost:$Port/ (expecting $Parts part(s))"
$saved = 0
try {
    while ($saved -lt $Parts) {
        $ctx = $listener.GetContext()
        $path = $ctx.Request.Url.AbsolutePath
        if ($ctx.Request.HttpMethod -eq 'POST' -and $path -eq '/save') {
            $part = [regex]::Replace([string]$ctx.Request.QueryString['part'], '[^0-9]', '')
            if (-not $part) { $part = '1' }
            $reader = New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd(); $reader.Close()
            [IO.File]::WriteAllText((Join-Path $outDir "part-$part.json"), $body, $utf8)
            $msg = "$($body.Length) characters"
            $bytes = [Text.Encoding]::UTF8.GetBytes($msg)
            $saved++
            Write-Host "saved part $part ($msg)"
        } else {
            $bytes = [Text.Encoding]::UTF8.GetBytes($page)
            $ctx.Response.ContentType = 'text/html; charset=utf-8'
        }
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $ctx.Response.Close()
    }
} finally { $listener.Stop() }
Write-Host 'receiver finished'
