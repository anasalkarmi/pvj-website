# Confirms that YouTube serves the thumbnail sizes the site uses for every video
# in content/videos.json. Prints any that are missing. Read-only.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
$videos = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path (Join-Path $root 'content') 'videos.json'), [Text.Encoding]::UTF8))
$sizes = 'mqdefault', 'hqdefault', 'sddefault', 'maxresdefault'
$missing = 0; $n = 0
foreach ($v in $videos) {
    $n++
    foreach ($s in $sizes) {
        $url = "https://i.ytimg.com/vi/$($v.youtubeId)/$s.jpg"
        $ok = $false
        try {
            $req = [Net.WebRequest]::Create($url); $req.Method = 'HEAD'; $req.Timeout = 15000
            $resp = $req.GetResponse(); $ok = ([int]$resp.StatusCode -eq 200); $resp.Close()
        } catch { $ok = $false }
        if (-not $ok) { $missing++; "MISSING  $s  $($v.youtubeId)  $($v.title)" }
    }
}
"checked $n videos x $($sizes.Count) sizes; missing: $missing"
