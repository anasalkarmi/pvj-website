param([string]$Domain = 'paediatricvj.com', [string]$Ip = '185.199.108.153')

# Checks the published site by talking to GitHub Pages directly (so a stale DNS
# cache on this PC does not matter). Certificates are verified by curl.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Continue'
function Probe([string]$label, [string]$hostName, [string]$url, [string]$fmt) {
    $port = 443; if ($url.StartsWith('http://')) { $port = 80 }
    $r = (& curl.exe -sS -o NUL -m 25 -w $fmt --resolve "${hostName}:${port}:$Ip" $url 2>&1 | ForEach-Object { "$_" }) -join ' '
    if ($r -match 'SEC_E_WRONG_PRINCIPAL|\(60\)') { $r = 'certificate is not valid for this name' }
    elseif ($r -match 'curl: \((\d+)\)') { $r = "curl error $($Matches[1])" }
    "{0,-30} {1}" -f $label, $r
}
function Fetch([string]$path) { return ((& curl.exe -sS -m 25 --resolve "${Domain}:443:$Ip" ("https://$Domain" + $path) 2>&1 | ForEach-Object { "$_" }) -join "`n") }

Probe "https://$Domain" $Domain "https://$Domain/" '%{http_code}'
Probe "https://www.$Domain" "www.$Domain" "https://www.$Domain/" '%{http_code} -> %{redirect_url}'
Probe "http://$Domain" $Domain "http://$Domain/" '%{http_code} -> %{redirect_url}'
Probe "http://www.$Domain" "www.$Domain" "http://www.$Domain/" '%{http_code} -> %{redirect_url}'
Probe 'sitemap.xml' $Domain "https://$Domain/sitemap.xml" '%{http_code}'
Probe 'feed.xml' $Domain "https://$Domain/feed.xml" '%{http_code}'
Probe 'videos page' $Domain "https://$Domain/videos/" '%{http_code}'
Probe 'missing page' $Domain "https://$Domain/no-such-page/" '%{http_code}'
$homePage = Fetch '/'
"home page title:               " + [regex]::Match($homePage, '(?is)<title[^>]*>(.*?)</title>').Groups[1].Value
"hidden from search engines:    " + ($homePage -match 'name="robots" content="noindex"')
"canonical link:                " + [regex]::Match($homePage, 'rel="canonical" href="([^"]+)"').Groups[1].Value
"robots.txt:                    " + ((Fetch '/robots.txt') -replace "\s*\n\s*", ' | ')
exit 0
