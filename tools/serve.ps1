param([int]$Port = 4173, [string]$Dir = 'docs')

# Tiny local preview server for the built site (no installs needed).
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\serve.ps1
# then open http://localhost:4173/   - press Ctrl+C to stop.
# Serves only to this computer (localhost). Keep this file plain ASCII.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$site = Join-Path $root $Dir
function LongPath([string]$p) { if ($p -match '^[A-Za-z]:\\') { return '\\?\' + $p } else { return $p } }
$types = @{
    '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.js' = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'; '.xml' = 'application/xml; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8'
    '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.webp' = 'image/webp'
}
$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "PVJ preview running at http://localhost:$Port/  (serving $site)"
try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        try {
            $rel = [uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
            $status = 200
            if ($rel.Contains('..')) { $status = 400; $file = $null }
            else {
                if ($rel.EndsWith('/')) { $rel += 'index.html' }
                $file = Join-Path $site ($rel.TrimStart('/').Replace('/', '\'))
                if ([IO.Directory]::Exists((LongPath $file))) {
                    # same behaviour as GitHub Pages: redirect /folder to /folder/
                    $ctx.Response.StatusCode = 301
                    $ctx.Response.RedirectLocation = $ctx.Request.Url.AbsolutePath + '/'
                    $ctx.Response.Close()
                    continue
                }
                if (-not [IO.File]::Exists((LongPath $file))) { $status = 404; $file = Join-Path $site '404.html' }
            }
            if ($file -and [IO.File]::Exists((LongPath $file))) {
                $bytes = [IO.File]::ReadAllBytes((LongPath $file))
                $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
                $ctype = $types[$ext]; if (-not $ctype) { $ctype = 'application/octet-stream' }
            } else {
                $bytes = [Text.Encoding]::UTF8.GetBytes('Not found'); $ctype = 'text/plain; charset=utf-8'
            }
            $ctx.Response.StatusCode = $status
            $ctx.Response.ContentType = $ctype
            $ctx.Response.Headers['Cache-Control'] = 'no-store'
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $ctx.Response.Close()
            Write-Host ("{0} {1}" -f $status, $ctx.Request.Url.AbsolutePath)
        } catch {
            Write-Host ("error serving {0}: {1}" -f $ctx.Request.Url.AbsolutePath, $_.Exception.Message)
            try { $ctx.Response.Abort() } catch { }
        }
    }
} finally {
    $listener.Stop()
}
