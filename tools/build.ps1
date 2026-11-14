param(
    [string]$Out = 'docs',
    [string]$BasePath,
    [string]$SiteUrl
)

# PVJ static site generator.
# Reads content/*.json + content/pages/*.html + src/assets and writes a complete
# static website into ./docs (the folder GitHub Pages serves).
# Runs on Windows PowerShell 5.1 and PowerShell 7. Keep this file plain ASCII.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1
#   ... -BasePath /repo-name -SiteUrl https://user.github.io   (project-page preview)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture

$sep = [IO.Path]::DirectorySeparatorChar
# Windows refuses paths over 260 characters unless they carry the \\?\ prefix.
# (not named "LP": that is a built-in alias for Out-Printer)
function LongPath([string]$p) { if ($script:sep -eq '\' -and $p -match '^[A-Za-z]:\\') { return '\\?\' + $p } else { return $p } }
function Read-Text([string]$p) { return [IO.File]::ReadAllText((LongPath $p), [Text.Encoding]::UTF8) }
function Read-Json([string]$p) { return (ConvertFrom-Json -InputObject (Read-Text $p)) }
# (not named "H": that is a built-in alias for Get-History and aliases win over functions)
function Esc([string]$s) { if ($null -eq $s) { return '' }; return [System.Net.WebUtility]::HtmlEncode($s) }
function X([string]$s) { if ($null -eq $s) { return '' }; return [Security.SecurityElement]::Escape($s) }
function J([string]$s) {
    if ($null -eq $s) { return '' }
    $t = $s.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", '\n').Replace("`t", ' ')
    return $t.Replace('</', '<\/')
}
function Slug([string]$s) {
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $n.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($ch) }
    }
    $t = $sb.ToString().ToLowerInvariant()
    # Only the straight apostrophe is dropped; a curly one becomes a hyphen ("parent-s"). Leave it so:
    # video and speaker addresses were made this way and must not change.
    $t = [regex]::Replace($t, '['']', '')
    return ([regex]::Replace($t, '[^a-z0-9]+', '-')).Trim('-')
}
function DateLong([string]$d) { return ([datetime]::ParseExact($d, 'yyyy-MM-dd', $inv)).ToString('d MMMM yyyy', $inv) }
function DateShort([string]$d) { return ([datetime]::ParseExact($d, 'yyyy-MM-dd', $inv)).ToString('d MMM yyyy', $inv) }
function Dur([int]$s) { return ('{0}:{1:00}' -f [int][math]::Floor($s / 60), ($s % 60)) }
function DurIso([int]$s) { return ('PT{0}M{1}S' -f [int][math]::Floor($s / 60), ($s % 60)) }
function Plural([int]$n, [string]$word) { if ($n -eq 1) { return "$n $word" } else { return "$n ${word}s" } }

# ---------------------------------------------------------------- config
$site = Read-Json (Join-Path $root 'content\site.json')
if ($PSBoundParameters.ContainsKey('BasePath')) { $cfgBase = $BasePath } else { $cfgBase = [string]$site.basePath }
if ($PSBoundParameters.ContainsKey('SiteUrl')) { $cfgUrl = $SiteUrl } else { $cfgUrl = [string]$site.url }
$cfgBase = ([string]$cfgBase).TrimEnd('/')
$cfgUrl = ([string]$cfgUrl).TrimEnd('/')
$isPreview = [bool]$site.preview
function U([string]$path) { return $script:cfgBase + $path }
function AbsUrl([string]$path) { if ($script:cfgUrl) { return $script:cfgUrl + $script:cfgBase + $path } else { return '' } }

$outDir = Join-Path $root $Out
if (-not $outDir.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or $outDir.TrimEnd('\') -eq $root.TrimEnd('\')) { throw "Refusing to build into $outDir" }
if ([IO.Directory]::Exists((LongPath $outDir))) { [IO.Directory]::Delete((LongPath $outDir), $true) }
[void][IO.Directory]::CreateDirectory((LongPath $outDir))

# ---------------------------------------------------------------- data
$topics = @(Read-Json (Join-Path $root 'content\topics.json'))
$conferences = @(Read-Json (Join-Path $root 'content\conferences.json') | Sort-Object sortDate -Descending)
$pages = @(Read-Json (Join-Path $root 'content\pages.json'))
# Weekly research roundups: content/roundups/<slug>.json (dates, headline, intro lines) with the
# page body in <slug>.html, which tools/make-roundup.ps1 writes from the checked report.
$roundups = @()
$roundupDir = Join-Path $root 'content\roundups'
if (Test-Path -LiteralPath $roundupDir) {
    $roundups = @(Get-ChildItem -LiteralPath $roundupDir -Filter *.json | ForEach-Object { Read-Json $_.FullName } | Where-Object { Test-Path -LiteralPath (Join-Path $roundupDir ([string]$_.slug + '.html')) } | Sort-Object compiled -Descending)
}
$videos = @(Read-Json (Join-Path $root 'content\videos.json'))

# Optional per-video file content/transcripts/<youtubeId>.txt:
#   KEY POINTS / "- point" lines / TRANSCRIPT / paragraphs separated by blank lines
$transDir = Join-Path (Join-Path $root 'content') 'transcripts'
# content/transcripts/_hold.tsv lists videos whose transcript still needs a human check; those stay off the site.
$transHold = @{}
$holdFile = Join-Path $transDir '_hold.tsv'
if (Test-Path -LiteralPath $holdFile) {
    foreach ($line in ((Read-Text $holdFile) -split "`n")) {
        $l = $line.Trim(); if (-not $l -or $l.StartsWith('#')) { continue }
        $transHold[($l -split "`t")[0].Trim()] = 1
    }
}
function Read-Transcript([string]$id) {
    if ($script:transHold.ContainsKey($id)) { return $null }
    $f = Join-Path $script:transDir ($id + '.txt')
    if (-not (Test-Path -LiteralPath $f)) { return $null }
    $t = (Read-Text $f).Replace("`r", '')
    $m = [regex]::Match($t, '(?s)KEY POINTS[ \t]*\n(.*?)\nTRANSCRIPT[ \t]*\n(.*)$')
    if (-not $m.Success) { return $null }
    $points = @($m.Groups[1].Value -split "\n" | ForEach-Object { ($_ -replace '^\s*-\s*', '').Trim() } | Where-Object { $_ })
    return [pscustomobject]@{ points = $points; text = $m.Groups[2].Value.Trim() }
}

$topicBySlug = @{}; foreach ($t in $topics) { $topicBySlug[$t.slug] = $t }
$confBySlug = @{}; foreach ($c in $conferences) { $confBySlug[$c.slug] = $c }

$problems = New-Object Collections.ArrayList
$seenSlug = @{}; $seenId = @{}
$i = 0
foreach ($v in $videos) {
    Add-Member -InputObject $v -NotePropertyName idx -NotePropertyValue $i; $i++
    if (-not $v.slug -or $seenSlug.ContainsKey($v.slug)) { [void]$problems.Add("duplicate or missing slug: $($v.slug)") } else { $seenSlug[$v.slug] = 1 }
    if ($v.youtubeId -cnotmatch '^[A-Za-z0-9_-]{11}$' -or $seenId.ContainsKey($v.youtubeId)) { [void]$problems.Add("bad or duplicate youtubeId on $($v.slug)") } else { $seenId[$v.youtubeId] = 1 }
    if (-not $confBySlug.ContainsKey([string]$v.conference)) { [void]$problems.Add("unknown conference '$($v.conference)' on $($v.slug)") }
    foreach ($t in @($v.topics)) { if (-not $topicBySlug.ContainsKey([string]$t)) { [void]$problems.Add("unknown topic '$t' on $($v.slug)") } }
    if ($v.published -notmatch '^\d{4}-\d{2}-\d{2}$') { [void]$problems.Add("bad published date on $($v.slug)") }
}
if ($problems.Count -gt 0) { $problems | ForEach-Object { Write-Host "DATA PROBLEM: $_" }; throw "content/videos.json has $($problems.Count) problem(s)." }

$videos = @($videos | Sort-Object @{ Expression = { $_.published }; Descending = $true }, @{ Expression = { $_.idx }; Descending = $false })

# ---- speakers are derived from the videos
$honorifics = '^(?:(?:professor|prof\.?|dr\.?|mr justice|mr\.?|mrs\.?|ms\.?|miss|sir|dame)\s+)+'
$postnominals = '\s+(?:mbe|obe|cbe|kbe|dbe)\.?$'
function PersonCore([string]$name) {
    $c = [regex]::Replace($name, $script:honorifics, '', 'IgnoreCase')
    do { $prev = $c; $c = [regex]::Replace($c, $script:postnominals, '', 'IgnoreCase') } while ($c -ne $prev)
    $c = [regex]::Replace($c, '\s*\([^)]*\)', '')
    return $c.Trim()
}
$speakers = @{}
foreach ($v in $videos) {
    $people = @()
    if ($v.speakers) {
        foreach ($s in @($v.speakers)) {
            $core = PersonCore $s.name
            $words = @($core -split '\s+' | Where-Object { $_ })
            if ($words.Count -gt 1) { $slug = Slug $core } else { $slug = Slug $s.name }
            $initials = $words[0].Substring(0, 1).ToUpperInvariant()
            if ($words.Count -gt 1) { $initials += $words[-1].Substring(0, 1).ToUpperInvariant() }
            if (-not $speakers.ContainsKey($slug)) {
                $speakers[$slug] = [pscustomobject]@{ slug = $slug; name = [string]$s.name; role = [string]$s.role; sort = ($words[-1] + ' ' + $core).ToLowerInvariant(); letter = $words[-1].Substring(0, 1).ToUpperInvariant(); initials = $initials; videos = (New-Object Collections.ArrayList) }
            }
            # videos are newest first, so a speaker's page uses their most recent stated role
            if (-not $speakers[$slug].role -and $s.role) { $speakers[$slug].role = [string]$s.role }
            [void]$speakers[$slug].videos.Add($v)
            $people += [pscustomobject]@{ name = [string]$s.name; role = [string]$s.role; slug = $slug; initials = $initials }
        }
    }
    Add-Member -InputObject $v -NotePropertyName people -NotePropertyValue $people
    Add-Member -InputObject $v -NotePropertyName url -NotePropertyValue ('/videos/' + $v.slug + '/')
}
# a video whose own description gave no role borrows the speaker's known role
foreach ($v in $videos) { foreach ($p in $v.people) { if (-not $p.role) { $p.role = $speakers[$p.slug].role } } }
$speakerList = @($speakers.Values | Sort-Object sort)

$topicVideos = @{}; foreach ($t in $topics) { $topicVideos[$t.slug] = New-Object Collections.ArrayList }
$confVideos = @{}; foreach ($c in $conferences) { $confVideos[$c.slug] = New-Object Collections.ArrayList }
foreach ($v in $videos) {
    [void]$confVideos[$v.conference].Add($v)
    foreach ($t in @($v.topics)) { [void]$topicVideos[$t].Add($v) }
}
$liveTopics = @($topics | Where-Object { $topicVideos[$_.slug].Count -gt 0 } | Sort-Object name)

# ---------------------------------------------------------------- assets
$assetSrc = Join-Path (Join-Path $root 'src') 'assets'
$assetOut = Join-Path $outDir 'assets'
foreach ($f in [IO.Directory]::GetFiles((LongPath $assetSrc), '*', [IO.SearchOption]::AllDirectories)) {
    $dest = (LongPath $assetOut) + $f.Substring((LongPath $assetSrc).Length)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))
    [IO.File]::Copy($f, $dest, $true)
}
function FileHash8([string]$p) {
    $md5 = [Security.Cryptography.MD5]::Create()
    try { return ([BitConverter]::ToString($md5.ComputeHash([IO.File]::ReadAllBytes($p))) -replace '-', '').Substring(0, 8).ToLowerInvariant() } finally { $md5.Dispose() }
}
$cssV = FileHash8 (Join-Path (Join-Path $assetSrc 'css') 'site.css')
$jsV = FileHash8 (Join-Path (Join-Path $assetSrc 'js') 'site.js')
$imgSrc = Join-Path $assetSrc 'img'
$hasLogo = Test-Path (Join-Path $imgSrc 'pvj-logo.png')
$ogDefault = AbsUrl '/assets/img/og-default.png'
$logoAbs = AbsUrl '/assets/img/pvj-logo.png'
$crumbItems = $null

# ---------------------------------------------------------------- components
function Thumb($v, [string]$sizes, [bool]$eager = $false) {
    $load = 'lazy'; if ($eager) { $load = 'eager' }
    return ('<img src="https://i.ytimg.com/vi/{0}/mqdefault.jpg" srcset="https://i.ytimg.com/vi/{0}/mqdefault.jpg 320w, https://i.ytimg.com/vi/{0}/hqdefault.jpg 480w, https://i.ytimg.com/vi/{0}/sddefault.jpg 640w" sizes="{1}" alt="" width="320" height="180" loading="{2}" decoding="async">' -f $v.youtubeId, $sizes, $load)
}
function Who($v) { return (@($v.people | ForEach-Object { $_.name }) -join ' and ') }
# A speaker's picture is a square crop of the thumbnail of their most recent solo interview;
# speakers who only appear in joint interviews keep their initials. Every PVJ thumbnail has the
# photo in its left half, so the crop starts at the left edge; a conference whose thumbnails are
# laid out differently can set "photoPosition" (a CSS object-position) in conferences.json.
function Avatar([string]$slug, [string]$initials) {
    $sp = $script:speakers[$slug]
    $solo = $null
    if ($sp) { $solo = @($sp.videos | Where-Object { $_.people.Count -eq 1 }) | Select-Object -First 1 }
    if (-not $solo) { return '<span class="avatar" aria-hidden="true">' + $initials + '</span>' }
    $pos = [string]$script:confBySlug[$solo.conference].photoPosition
    if (-not $pos) { $pos = '0% 50%' }
    return '<span class="avatar photo" aria-hidden="true"><img src="https://i.ytimg.com/vi/' + $solo.youtubeId + '/mqdefault.jpg" alt="" width="52" height="52" loading="lazy" decoding="async" style="object-position:' + $pos + '"></span>'
}
function SearchText($v) {
    $parts = @($v.title) + @($v.people | ForEach-Object { $_.name; $_.role }) + @($v.topics | ForEach-Object { $script:topicBySlug[$_].name }) + @($script:confBySlug[$v.conference].name, $script:confBySlug[$v.conference].organiser)
    return ($parts -join ' ').ToLowerInvariant()
}
function Card($v, [bool]$showConf = $true, [bool]$withSummary = $false) {
    $c = $script:confBySlug[$v.conference]
    $who = Who $v
    $whoHtml = ''; if ($who) { $whoHtml = '<p class="who">' + (Esc $who) + '</p>' }
    $sumHtml = ''; if ($withSummary -and $v.summary) { $sumHtml = '<p class="sum">' + (Esc $v.summary) + '</p>' }
    if ($showConf) { $meta = '<a href="' + (U "/conferences/$($c.slug)/") + '">' + (Esc $c.name) + '</a> &middot; ' + (DateShort $v.published) } else { $meta = (DateShort $v.published) }
    return @"
<article class="card" data-search="$(Esc (SearchText $v))" data-conference="$($v.conference)" data-topics="$(@($v.topics) -join ' ')">
<a class="thumb" href="$(U $v.url)" tabindex="-1" aria-hidden="true">$(Thumb $v '(max-width: 480px) 100vw, (max-width: 780px) 50vw, 300px')<span class="dur">$(Dur $v.seconds)</span></a>
<div class="card-body">
<h3><a href="$(U $v.url)">$(Esc $v.title)</a></h3>
$sumHtml
$whoHtml
<p class="meta">$meta</p>
</div>
</article>
"@
}
function Grid($list, [bool]$showConf = $true, [string]$extra = '', [bool]$withSummary = $false) {
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('<div class="grid' + $extra + '">')
    foreach ($v in $list) { [void]$sb.Append((Card $v $showConf $withSummary)) }
    [void]$sb.Append('</div>')
    return $sb.ToString()
}
function SideItem($v) {
    return @"
<li class="side-item">
<a class="thumb" href="$(U $v.url)" tabindex="-1" aria-hidden="true">$(Thumb $v '140px')<span class="dur">$(Dur $v.seconds)</span></a>
<div><h3><a href="$(U $v.url)">$(Esc $v.title)</a></h3><p>$(Esc (Who $v))</p></div>
</li>
"@
}
function Crumbs($items) {
    $script:crumbItems = @($items)
    $parts = @('<a href="' + (U '/') + '">Home</a>')
    foreach ($it in $items) { if ($it.href) { $parts += '<a href="' + (U $it.href) + '">' + (Esc $it.label) + '</a>' } else { $parts += (Esc $it.label) } }
    return '<p class="crumbs">' + ($parts -join '<span>/</span>') + '</p>'
}
function Paras([string]$text) {
    $sb = New-Object Text.StringBuilder
    $linker = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $u = $m.Value
        $href = $u; if ($u -like 'www.*') { $href = 'https://' + $u }
        return '<a href="' + $href + '" rel="noopener">' + $u + '</a>'
    }
    foreach ($p in [regex]::Split([string]$text, '(?:\r?\n)+')) {
        $t = $p.Trim(); if (-not $t) { continue }
        $h = [regex]::Replace((Esc $t), '(?<![\w/@.])(?:https?://|www\.)[^\s<]*[^\s<.,;:)]', $linker)
        [void]$sb.Append("<p>$h</p>")
    }
    return $sb.ToString()
}

# ---------------------------------------------------------------- layout
$navItems = @(
    @{ key = 'videos'; label = 'Videos'; href = '/videos/' },
    @{ key = 'topics'; label = 'Topics'; href = '/topics/' },
    @{ key = 'conferences'; label = 'Conferences'; href = '/conferences/' },
    @{ key = 'speakers'; label = 'Speakers'; href = '/speakers/' },
    @{ key = 'about'; label = 'About'; href = '/about/' }
)
$sitemap = New-Object Collections.ArrayList
$pageCount = 0
$transcriptCount = 0
$year = (Get-Date).Year

function Write-Out([string]$path, [string]$content) {
    $rel = $path; if ($path.EndsWith('/')) { $rel = $path + 'index.html' }
    $file = LongPath (Join-Path $script:outDir ($rel.TrimStart('/').Replace('/', [string]$script:sep)))
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($file))
    [IO.File]::WriteAllText($file, $content, $script:utf8)
}

function Write-Page([string]$path, [string]$title, [string]$desc, [string]$body, [hashtable]$opt = @{}) {
    # The home page's search title comes from site.json "homeTitle" (the visible heading does not change).
    if ($path -eq '/') { $fullTitle = (Esc $site.name) + ' | ' + (Esc $site.fullName); if ([string]$site.homeTitle) { $fullTitle = Esc ([string]$site.homeTitle) } } else {
        $titleText = $title; if ($opt.headTitle) { $titleText = [string]$opt.headTitle }
        $titleSuffix = $site.name; if (($titleText + ' | ' + $site.name).Length -lt 40) { $titleSuffix = $site.fullName }
        $fullTitle = (Esc $titleText) + ' | ' + (Esc $titleSuffix)
    }
    $canonical = AbsUrl $path
    $image = $script:ogDefault; if ($opt.image) { $image = $opt.image }
    $ogType = 'website'; if ($opt.ogType) { $ogType = $opt.ogType }
    # "preview": true in site.json keeps search engines away until the real domain is live
    $noindex = [bool]$opt.noindex -or $script:isPreview
    $head = New-Object Text.StringBuilder
    if ($canonical -and -not $noindex) { [void]$head.AppendLine('<link rel="canonical" href="' + $canonical + '">') }
    if ($canonical) { [void]$head.AppendLine('<meta property="og:url" content="' + $canonical + '">') }
    if ($noindex) { [void]$head.AppendLine('<meta name="robots" content="noindex">') }
    if ($image) { [void]$head.AppendLine('<meta property="og:image" content="' + $image + '">') }
    if ($script:cfgUrl) { [void]$head.AppendLine('<link rel="alternate" type="application/rss+xml" title="PVJ - latest videos" href="' + (U '/feed.xml') + '">') }
    if ($opt.jsonld) { [void]$head.AppendLine('<script type="application/ld+json">' + $opt.jsonld + '</script>') }
    if ($script:crumbItems -and $canonical) {
        $bcList = '{"@type":"ListItem","position":1,"name":"Home","item":"' + (J (AbsUrl '/')) + '"}'
        $bcPos = 1
        foreach ($bc in $script:crumbItems) {
            $bcPos++
            $bcUrl = $canonical; if ($bc.href) { $bcUrl = AbsUrl $bc.href }
            $bcList += ',{"@type":"ListItem","position":' + $bcPos + ',"name":"' + (J ([string]$bc.label)) + '","item":"' + (J $bcUrl) + '"}'
        }
        [void]$head.AppendLine('<script type="application/ld+json">{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[' + $bcList + ']}</script>')
    }
    $script:crumbItems = $null

    $nav = New-Object Text.StringBuilder
    foreach ($n in $script:navItems) {
        $cur = ''; if ($opt.nav -eq $n.key) { $cur = ' aria-current="page"' }
        [void]$nav.Append('<a href="' + (U $n.href) + '"' + $cur + '>' + $n.label + '</a>')
    }
    $logo = '<b>PVJ</b>'
    $footLogo = ''
    if ($script:hasLogo) {
        $logo = '<img src="' + (U '/assets/img/pvj-logo.png') + '" alt="PVJ" width="49" height="44">'
        $footLogo = '<span class="foot-logo"><img src="' + (U '/assets/img/pvj-logo.png') + '" alt="PVJ" width="51" height="46" loading="lazy"></span>'
    }
    $html = @"
<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$fullTitle</title>
<meta name="description" content="$(Esc $desc)">
<meta property="og:site_name" content="$(Esc $site.fullName)">
<meta property="og:type" content="$ogType">
<meta property="og:title" content="$(Esc $title)">
<meta property="og:description" content="$(Esc $desc)">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#155a75">
$($head.ToString().TrimEnd())
<link rel="icon" type="image/png" sizes="32x32" href="$(U '/assets/img/favicon-32.png')">
<link rel="apple-touch-icon" href="$(U '/assets/img/apple-touch-icon.png')">
<link rel="preconnect" href="https://i.ytimg.com">
<link rel="stylesheet" href="$(U '/assets/css/site.css')?v=$script:cssV">
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<div class="notice">$(Esc $site.notice)</div>
<header class="site-header">
<div class="wrap">
<a class="brand" href="$(U '/')" aria-label="$(Esc $site.fullName) - home">$logo<span class="brand-name">The Paediatric<b>Video Journal</b></span></a>
<button class="nav-toggle" type="button" aria-expanded="false" aria-controls="site-nav">Menu</button>
<nav class="nav" id="site-nav" aria-label="Main">
$($nav.ToString())
<form class="header-search" action="$(U '/videos/')" method="get" role="search"><label class="sr-only" for="hs-q">Search videos</label><input id="hs-q" type="search" name="q" placeholder="Search videos" autocomplete="off"></form>
<a class="nav-cta" href="$(U '/work-with-us/')">Work with PVJ</a>
</nav>
</div>
</header>
<main id="main">
$body
</main>
<footer class="site-footer">
<div class="wrap">
<div class="foot-grid">
<div class="foot-brand">
$footLogo
<p>$(Esc $site.tagline)</p>
</div>
<div>
<h2>Journal</h2>
<ul>
<li><a href="$(U '/videos/')">All videos</a></li>
<li><a href="$(U '/topics/')">Topics</a></li>
<li><a href="$(U '/conferences/')">Conferences</a></li>
<li><a href="$(U '/speakers/')">Speakers</a></li>
$(if ($script:roundups.Count -gt 0) { '<li><a href="' + (U '/research-roundup/') + '">Research roundup</a></li>' })
</ul>
</div>
<div>
<h2>PVJ</h2>
<ul>
<li><a href="$(U '/about/')">About</a></li>
<li><a href="$(U '/about/editorial-policy/')">Editorial policy</a></li>
<li><a href="$(U '/work-with-us/')">Work with PVJ</a></li>
<li><a href="$(U '/contact/')">Contact</a></li>
</ul>
</div>
<div>
<h2>Follow</h2>
<ul>
<li><a href="$(Esc $site.youtubeUrl)" rel="noopener">YouTube</a></li>
<li><a href="$(Esc $site.linkedinUrl)" rel="noopener">LinkedIn</a></li>
<li><a href="$(U '/privacy/')">Privacy</a></li>
<li><a href="$(U '/terms/')">Terms of use</a></li>
</ul>
</div>
</div>
<div class="foot-legal">
<p>The Paediatric Video Journal publishes educational content intended for healthcare professionals. It is not medical advice. Views expressed in the videos are those of the speakers.</p>
<p>&copy; $script:year The Paediatric Video Journal. All rights reserved.</p>
</div>
</div>
</footer>
$(if ($path -ne '/contact/') { '<a class="contact-fab" href="' + (U '/contact/') + '">Contact us</a>' })
<script src="$(U '/assets/js/site.js')?v=$script:jsV" defer></script>
</body>
</html>
"@
    Write-Out $path $html
    $script:pageCount++
    if (-not $opt.noindex) { [void]$script:sitemap.Add($path) }
}

# ---------------------------------------------------------------- home
# Order set by the owner (12 November 2026): what PVJ is, then the clinical areas, then the
# conferences, then the latest videos. The home page must read as a video journal for all of
# paediatrics, not as the site of one conference or one specialty.
# Topics with "group": "theme" in topics.json are cross-cutting subjects; the rest are clinical areas.
function TopicTile($t) { return '<a class="tile" href="' + (U "/topics/$($t.slug)/") + '"><b>' + (Esc $t.name) + '</b><span>' + (Plural $topicVideos[$t.slug].Count 'video') + '</span></a>' }
# A clinical area is shown as a small badge: an icon from src/icons/clinical/<slug>.svg (inlined, so it
# takes the badge colour) above a short name. The owner wants every clinical area visible on the first
# screen of the home page, without counts. The themes are listed on the Topics page only.
$iconDir = Join-Path (Join-Path (Join-Path $root 'src') 'icons') 'clinical'
function AreaTile($t) {
    $svg = ''
    $f = Join-Path $iconDir "$($t.slug).svg"
    if (Test-Path -LiteralPath $f) { $svg = ([regex]::Replace([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8), '<\?xml[^>]*\?>', '')).Trim() }
    return '<a class="area" href="' + (U "/topics/$($t.slug)/") + '"><span class="area-icon" aria-hidden="true">' + $svg + '</span><b>' + (Esc $t.name) + '</b></a>'
}
$areaTiles = (@($liveTopics | Where-Object { [string]$_.group -ne 'theme' } | ForEach-Object { AreaTile $_ }) -join '')
$themeTiles = (@($liveTopics | Where-Object { [string]$_.group -eq 'theme' } | ForEach-Object { TopicTile $_ }) -join '')
$confCards = New-Object Text.StringBuilder
foreach ($c in $conferences) {
    $cv = @($confVideos[$c.slug]); if ($cv.Count -eq 0) { continue }
    # "image" in conferences.json is a photo of the conference itself (a path under /assets/img/).
    # Until one is supplied the card shows the thumbnail of the conference's newest video.
    # "logo" is the conference's own badge, shown to the left of the card text (owner's request).
    # A round badge is the default; "logoShape": "wide" is for a wordmark (about 5:1), shown uncropped.
    $logoImg = ''
    if ([string]$c.logo) {
        if ([string]$c.logoShape -eq 'wide') { $logoImg = '<img class="conf-logo wide" src="' + (U ([string]$c.logo)) + '" alt="" width="84" height="16" loading="lazy" decoding="async">' }
        else { $logoImg = '<img class="conf-logo" src="' + (U ([string]$c.logo)) + '" alt="" width="60" height="60" loading="lazy" decoding="async">' }
    }
    $pic = Thumb $cv[0] '(max-width: 480px) 100vw, (max-width: 780px) 50vw, 380px'
    if ([string]$c.image) { $pic = '<img src="' + (U ([string]$c.image)) + '" alt="" width="640" height="360" loading="lazy" decoding="async">' }
    [void]$confCards.Append(@"
<article class="card">
<a class="thumb" href="$(U "/conferences/$($c.slug)/")" tabindex="-1" aria-hidden="true">$pic</a>
<div class="card-body conf-body">
$logoImg
<div>
<h3><a href="$(U "/conferences/$($c.slug)/")">$(Esc $c.name)</a></h3>
<p class="who">$(Esc $c.location) &middot; $(Esc $c.date)</p>
<p class="meta"><a href="$(U "/conferences/$($c.slug)/")">Watch the videos from this conference</a></p>
</div>
</div>
</article>
"@)
}
$heroLogo = ''
if ($hasLogo) { $heroLogo = '<img class="hero-logo" src="' + (U '/assets/img/pvj-logo.png') + '" alt="PVJ" width="134" height="120">' }

$homeBody = @"
<section class="hero solo">
<div class="wrap">
<div class="hero-brand">
$heroLogo
<div>
<span class="eyebrow">Open-access video journal</span>
<h1>The Paediatric <em>Video Journal</em></h1>
</div>
</div>
<p class="lede">$(Esc $site.tagline)</p>
</div>
</section>

<section class="section tight" id="clinical-areas">
<div class="wrap">
<div class="section-head"><h2>Browse by clinical area</h2><a class="more" href="$(U '/topics/')">All topics</a></div>
<div class="areas">$areaTiles</div>
</div>
</section>

<section class="section alt">
<div class="wrap">
<div class="section-head"><h2>Conference coverage</h2><a class="more" href="$(U '/conferences/')">All conferences</a></div>
<div class="grid three">$($confCards.ToString())</div>
</div>
</section>

<section class="section">
<div class="wrap">
<div class="section-head"><h2>Latest videos</h2><a class="more" href="$(U '/videos/')">View all $($videos.Count) videos</a></div>
$(Grid @($videos | Select-Object -First 8))
</div>
</section>

<section class="section tight">
<div class="wrap">
<div class="cta">
<div>
<h2>Work with PVJ</h2>
<p>We record, edit and publish short interviews with your speakers and delegates, and share them with the child health community.</p>
</div>
<div class="hero-actions">
<a class="btn light" href="$(U '/work-with-us/')">Work with PVJ</a>
<a class="btn outline-light" href="$(U '/contact/')">Contact us</a>
</div>
</div>
</div>
</section>

<section class="section tight">
<div class="wrap">
<div class="follow">
<h2>Follow PVJ</h2>
<div class="hero-actions">
<a class="btn ghost" href="$(Esc $site.youtubeUrl)" rel="noopener">YouTube</a>
<a class="btn ghost" href="$(Esc $site.linkedinUrl)" rel="noopener">LinkedIn</a>
</div>
</div>
</div>
</section>
"@
$orgLd ='{"@context":"https://schema.org","@type":"Organization","name":"' + (J $site.fullName) + '","alternateName":["' + (J $site.name) + '","The Pediatric Video Journal"],"sameAs":["' + (J $site.youtubeUrl) + '","' + (J $site.linkedinUrl) + '"]' + $(if ($cfgUrl) { ',"url":"' + (J (AbsUrl '/')) + '","logo":"' + (J $logoAbs) + '"' } else { '' }) + '}'
Write-Page '/' $site.fullName $site.metaDescription $homeBody @{ jsonld = $orgLd }

# ---------------------------------------------------------------- videos index
$confOptions = ($conferences | Where-Object { $confVideos[$_.slug].Count -gt 0 } | ForEach-Object { '<option value="' + $_.slug + '">' + (Esc $_.name) + '</option>' }) -join ''
$topicOptions = ($liveTopics | ForEach-Object { '<option value="' + $_.slug + '">' + (Esc $_.name) + '</option>' }) -join ''
$videosBody = @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Videos' }))
<h1>All videos</h1>
<p class="lede">Every PVJ video in one place. Search by speaker, subject or organisation, or narrow the list by conference and topic.</p>
</div>
<div class="filters">
<div><label class="sr-only" for="f-q">Search videos</label><input id="f-q" type="search" placeholder="Search by title, speaker or organisation" autocomplete="off"></div>
<div><label class="sr-only" for="f-conference">Conference</label><select id="f-conference"><option value="">All conferences</option>$confOptions</select></div>
<div><label class="sr-only" for="f-topic">Topic</label><select id="f-topic"><option value="">All topics</option>$topicOptions</select></div>
</div>
<p class="filter-status" id="f-status" aria-live="polite"><span>$(Plural $videos.Count 'video')</span><button type="button" hidden>Clear filters</button></p>
<div data-filter-list data-noun="video">
<h2 class="sr-only">Videos</h2>
$(Grid $videos)
</div>
<p class="empty" id="f-empty">No videos match those filters. Try a different search, or clear the filters.</p>
</div>
<div class="section tight"></div>
"@
Write-Page '/videos/' 'All videos' "Browse all $($videos.Count) PVJ videos in paediatrics and child health. Search by speaker or filter by clinical area, topic and conference." $videosBody @{ nav = 'videos' }

# ---------------------------------------------------------------- video pages
foreach ($v in $videos) {
    $c = $confBySlug[$v.conference]
    $id = $v.youtubeId
    $pageUrl = AbsUrl $v.url

    $peopleHtml = ''
    if ($v.people.Count -gt 0) {
        $li = New-Object Text.StringBuilder
        foreach ($p in $v.people) {
            $role = ''; if ($p.role) { $role = '<span>' + (Esc $p.role) + '</span>' }
            [void]$li.Append('<li class="person">' + (Avatar $p.slug $p.initials) + '<div><b><a href="' + (U "/speakers/$($p.slug)/") + '">' + (Esc $p.name) + '</a></b>' + $role + '</div></li>')
        }
        $peopleHtml = '<ul class="people">' + $li.ToString() + '</ul>'
    }

    # key points + transcript (optional), citation line
    $kpHtml = ''; $trHtml = ''; $ldTranscript = ''
    $tr = Read-Transcript $id
    if ($tr) {
        if ($tr.points.Count -gt 0) { $kpHtml = '<h2 class="block-title">Key points</h2><ul class="keypoints">' + ((@($tr.points) | ForEach-Object { '<li>' + (Esc $_) + '</li>' }) -join '') + '</ul>' }
        if ($tr.text) {
            $trNote = 'Automatic transcript, lightly edited for readability. It may contain errors, so check it against the video before quoting.'
            if ($tr.text.Contains('[unclear]')) { $trNote += ' Words that could not be made out are marked [unclear].' }
            $trHtml = '<details class="transcript"><summary>Read the transcript</summary><p class="note">' + $trNote + '</p>' + (Paras $tr.text) + '</details>'
            $ldTranscript = ',"transcript":"' + (J ($tr.text -replace '\s+', ' ')) + '"'
            $script:transcriptCount++
        }
    }
    $citeWho = Who $v
    $cite = ''; if ($citeWho) { $cite = (Esc $citeWho) + '. ' }
    $cite += '&ldquo;' + (Esc $v.title) + '.&rdquo; <em>The Paediatric Video Journal</em>, ' + (DateLong $v.published) + '.'
    if ($pageUrl) { $cite += ' ' + $pageUrl }
    $citeHtml = '<h2 class="block-title">Cite this video</h2><p class="cite">' + $cite + '</p>'
    $chips = (@($v.topics) | ForEach-Object { '<li><a class="chip" href="' + (U "/topics/$_/") + '">' + (Esc $topicBySlug[$_].name) + '</a></li>' }) -join ''

    $share = New-Object Text.StringBuilder
    if ($pageUrl) {
        [void]$share.Append('<a href="https://www.linkedin.com/sharing/share-offsite/?url=' + [uri]::EscapeDataString($pageUrl) + '" rel="noopener" target="_blank">Share on LinkedIn</a>')
        [void]$share.Append('<a href="https://twitter.com/intent/tweet?url=' + [uri]::EscapeDataString($pageUrl) + '&amp;text=' + [uri]::EscapeDataString($v.title) + '" rel="noopener" target="_blank">Share on X</a>')
    }
    [void]$share.Append('<button type="button" data-copy="' + $pageUrl + '">Copy link</button>')
    [void]$share.Append('<a href="https://www.youtube.com/watch?v=' + $id + '" rel="noopener" target="_blank">Watch on YouTube</a>')
    if ($v.linkedinUrl) { [void]$share.Append('<a href="' + (Esc $v.linkedinUrl) + '" rel="noopener" target="_blank">Discuss on LinkedIn</a>') }

    # sidebar: same speaker first, then related by shared topics / conference
    $mine = @{}; foreach ($p in $v.people) { $mine[$p.slug] = 1 }
    $bySpeaker = @($videos | Where-Object { $_.slug -ne $v.slug -and @($_.people | Where-Object { $mine.ContainsKey($_.slug) }).Count -gt 0 } | Select-Object -First 4)
    $taken = @{}; $taken[$v.slug] = 1; foreach ($o in $bySpeaker) { $taken[$o.slug] = 1 }
    $vt = @($v.topics)
    $scored = foreach ($o in $videos) {
        if ($taken.ContainsKey($o.slug)) { continue }
        $shared = @(@($o.topics) | Where-Object { $vt -contains $_ }).Count
        $score = $shared * 2; if ($o.conference -eq $v.conference) { $score += 1 }
        if ($vt.Count -gt 0 -and @($o.topics)[0] -eq $vt[0]) { $score += 1 }
        if ($score -gt 0) { [pscustomobject]@{ v = $o; score = $score; idx = $o.idx } }
    }
    $related = @($scored | Sort-Object @{ Expression = { $_.score }; Descending = $true }, idx | Select-Object -First 6 | ForEach-Object { $_.v })
    $side = New-Object Text.StringBuilder
    if ($bySpeaker.Count -gt 0) {
        $label = 'More from this speaker'; if ($v.people.Count -gt 1) { $label = 'More from these speakers' }
        [void]$side.Append('<h2>' + $label + '</h2><ul class="side-list">' + ((@($bySpeaker) | ForEach-Object { SideItem $_ }) -join '') + '</ul>')
    }
    if ($related.Count -gt 0) {
        [void]$side.Append('<h2>Related videos</h2><ul class="side-list">' + ((@($related) | ForEach-Object { SideItem $_ }) -join '') + '</ul>')
    }
    [void]$side.Append('<a class="btn ghost" href="' + (U "/conferences/$($c.slug)/") + '">All ' + (Esc $c.name) + ' videos</a>')

    $body = @"
<div class="wrap watch">
$(Crumbs @(@{ label = 'Conferences'; href = '/conferences/' }, @{ label = $c.name; href = "/conferences/$($c.slug)/" }))
<div class="watch-grid">
<article>
<div class="player" data-yt="$id" data-title="$(Esc $v.title)">
<img src="https://i.ytimg.com/vi/$id/maxresdefault.jpg" alt="$(Esc $v.title)" width="1280" height="720">
<button type="button" aria-label="Play video: $(Esc $v.title)"><span class="play" aria-hidden="true"></span></button>
</div>
<p class="player-note">Pressing play loads the video from YouTube. <a href="$(U '/privacy/')">Privacy</a></p>
<h1>$(Esc $v.title)</h1>
<ul class="watch-meta">
<li><a href="$(U "/conferences/$($c.slug)/")">$(Esc $c.name)</a></li>
<li>$(Esc $c.location)</li>
<li>Published $(DateLong $v.published)</li>
<li>$(Dur $v.seconds) min</li>
</ul>
$peopleHtml
$kpHtml
<div class="desc">$(Paras $v.description)</div>
$trHtml
<h2 class="block-title">Topics</h2>
<ul class="chips">$chips</ul>
<h2 class="block-title">Share</h2>
<div class="share">$($share.ToString())</div>
$citeHtml
<p class="disclaimer">This interview is educational content intended for healthcare professionals and is not medical advice. Views expressed are those of the speaker. &copy; The Paediatric Video Journal. All rights reserved.</p>
</article>
<aside class="side" aria-label="More videos">
$($side.ToString())
</aside>
</div>
</div>
"@
    $ld = '{"@context":"https://schema.org","@type":"VideoObject","name":"' + (J $v.title) + '","description":"' + (J $v.summary) + '","thumbnailUrl":["https://i.ytimg.com/vi/' + $id + '/maxresdefault.jpg"],"uploadDate":"' + $v.published + 'T00:00:00+00:00","duration":"' + (DurIso $v.seconds) + '","embedUrl":"https://www.youtube-nocookie.com/embed/' + $id + '","contentUrl":"https://www.youtube.com/watch?v=' + $id + '"' + $ldTranscript + ',"publisher":{"@type":"Organization","name":"' + (J $site.fullName) + '"' + $(if ($cfgUrl) { ',"logo":{"@type":"ImageObject","url":"' + (J $logoAbs) + '"}' } else { '' }) + '}}'
    $who = Who $v
    $ogTitle = $v.title; if ($who) { $ogTitle = $v.title + ' - ' + $who }
    $headTitle = ''; if (($ogTitle + ' | ' + $site.name).Length -gt 70) { $headTitle = [string]$v.title }
    Write-Page $v.url $ogTitle $v.summary $body @{ headTitle = $headTitle; nav = 'videos'; image = "https://i.ytimg.com/vi/$id/maxresdefault.jpg"; ogType = 'video.other'; jsonld = $ld }
}

# ---------------------------------------------------------------- conferences
$confItems = New-Object Text.StringBuilder
foreach ($c in $conferences) {
    $cv = @($confVideos[$c.slug]); if ($cv.Count -eq 0) { continue }
    # Same picture and logo as the conference's card on the home page (owner's request, 13 November 2026);
    # the newest video's thumbnail is only the fallback for a conference without a picture.
    $cPic = Thumb $cv[0] '(max-width: 760px) 92vw, 300px'
    if ([string]$c.image) { $cPic = '<img src="' + (U ([string]$c.image)) + '" alt="" width="640" height="360" loading="lazy" decoding="async">' }
    $cLogo = ''
    if ([string]$c.logo) {
        if ([string]$c.logoShape -eq 'wide') { $cLogo = '<img class="conf-logo wide" src="' + (U ([string]$c.logo)) + '" alt="" width="84" height="16" loading="lazy" decoding="async">' }
        else { $cLogo = '<img class="conf-logo" src="' + (U ([string]$c.logo)) + '" alt="" width="60" height="60" loading="lazy" decoding="async">' }
    }
    [void]$confItems.Append(@"
<article class="conf-item">
<a class="thumb" href="$(U "/conferences/$($c.slug)/")" tabindex="-1" aria-hidden="true">$cPic</a>
<div>
$cLogo
<h2><a href="$(U "/conferences/$($c.slug)/")">$(Esc $c.name)</a></h2>
<p class="meta">$(Esc $c.organiser) &middot; $(Esc $c.location) &middot; $(Esc $c.date)</p>
<p>$(Esc $c.description)</p>
<a class="btn ghost" href="$(U "/conferences/$($c.slug)/")">Watch $(Plural $cv.Count 'video')</a>
</div>
</article>
"@)
}
Write-Page '/conferences/' 'Conferences' 'PVJ conference coverage: short video interviews recorded at leading paediatric meetings.' @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Conferences' }))
<h1>Conferences</h1>
<p class="lede">PVJ records interviews on site at paediatric conferences. Choose a meeting to watch its full collection.</p>
</div>
<div class="conf-list">$($confItems.ToString())</div>
</div>
<div class="section tight"></div>
"@ @{ nav = 'conferences' }

foreach ($c in $conferences) {
    $cv = @($confVideos[$c.slug]); if ($cv.Count -eq 0) { continue }
    $partner = ''
    if ($c.partnerLogo -and (Test-Path (Join-Path $imgSrc ([string]$c.partnerLogo).Replace('/', [string]$sep)))) {
        $partner = '<div class="partner"><small>' + (Esc $c.partnerLabel) + '</small><img src="' + (U "/assets/img/$($c.partnerLogo)") + '" alt="' + (Esc $c.organiser) + '" loading="lazy"></div>'
    }
    $playlist = ''; if ($c.playlistUrl) { $playlist = '<a class="btn ghost" href="' + (Esc $c.playlistUrl) + '" rel="noopener" target="_blank">YouTube playlist</a>' }
    $cTopics = @($liveTopics | Where-Object { $s = $_.slug; @($cv | Where-Object { @($_.topics) -contains $s }).Count -gt 0 })
    $cChips = ($cTopics | ForEach-Object { '<li><a class="chip" href="' + (U "/topics/$($_.slug)/") + '">' + (Esc $_.name) + '</a></li>' }) -join ''
    Write-Page "/conferences/$($c.slug)/" $c.name ("Watch $($cv.Count) PVJ interviews from $($c.name), $($c.location).") @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Conferences'; href = '/conferences/' }, @{ label = $c.name }))
<div class="conf-head">
<div>
<h1>$(Esc $c.name)</h1>
<ul class="facts"><li>$(Esc $c.organiser)</li><li>$(Esc $c.location)</li><li>$(Esc $c.date)</li><li>$(Plural $cv.Count 'video')</li></ul>
<p class="lede">$(Esc $c.description)</p>
$playlist
</div>
$partner
</div>
$(if ([string]$c.image) { '<img class="conf-banner" src="' + (U ([string]$c.image)) + '" alt="" width="1280" height="720" decoding="async">' })
</div>
<h2 class="block-title">Topics covered</h2>
<ul class="chips">$cChips</ul>
<div class="section tight"></div>
$(Grid $cv $false '' $true)
</div>
<div class="section tight"></div>
"@ @{ nav = 'conferences'; image = "https://i.ytimg.com/vi/$($cv[0].youtubeId)/maxresdefault.jpg" }
}

# ---------------------------------------------------------------- topics
Write-Page '/topics/' 'Topics' 'Browse PVJ videos by clinical area and topic, from critical care, neurology and neonatology to research, education and patient safety.' @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Topics' }))
<h1>Topics</h1>
<p class="lede">Find videos by clinical area or by theme. A video can appear under more than one.</p>
</div>
<h2 class="sub-head">Clinical areas</h2>
<div class="areas">$areaTiles</div>
<h2 class="sub-head">More topics</h2>
<div class="tiles">$themeTiles</div>
</div>
<div class="section tight"></div>
"@ @{ nav = 'topics' }

foreach ($t in $liveTopics) {
    $tv = @($topicVideos[$t.slug])
    # Related topics: the topics that most often share a video with this one (links between topic pages).
    $coTopics = @{}
    foreach ($rv in $tv) { foreach ($rs in @($rv.topics)) { if ($rs -ne $t.slug) { $coTopics[$rs] = 1 + [int]$coTopics[$rs] } } }
    $relTopics = @($coTopics.Keys | Sort-Object @{ Expression = { $coTopics[$_] }; Descending = $true }, @{ Expression = { $topicBySlug[$_].name }; Descending = $false } | Select-Object -First 8)
    $relHtml = ''
    if ($relTopics.Count -gt 0) {
        $relHtml = '<h2 class="sub-head">Related topics</h2><ul class="chips">' + (($relTopics | ForEach-Object { '<li><a class="chip" href="' + (U "/topics/$_/") + '">' + (Esc $topicBySlug[$_].name) + '</a></li>' }) -join '') + '</ul>'
    }
    Write-Page "/topics/$($t.slug)/" $t.name ("$($t.description) $(Plural $tv.Count 'video') from PVJ.") @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Topics'; href = '/topics/' }, @{ label = $t.name }))
<span class="eyebrow">Topic</span>
<h1>$(Esc $t.name)</h1>
<p class="lede">$(Esc $t.description)</p>
$(if ([string]$t.about) { '<p class="about">' + (Esc ([string]$t.about)) + '</p>' })
</div>
<p class="filter-status">$(Plural $tv.Count 'video')</p>
<h2 class="sr-only">Videos</h2>
$(Grid $tv $true '' $true)
$relHtml
</div>
<div class="section tight"></div>
"@ @{ nav = 'topics'; headTitle = ($t.name + ' videos') }
}
# A topic that replaced an older one lists the old slug in "aliases": the old address forwards to it.
foreach ($t in $liveTopics) {
    foreach ($oldSlug in @($t.aliases | Where-Object { $_ })) {
        $to = U "/topics/$($t.slug)/"
        Write-Out "/topics/$oldSlug/" ('<!doctype html><html lang="en-GB"><head><meta charset="utf-8"><title>' + (Esc $t.name) + ' | ' + (Esc $site.name) + '</title><meta name="robots" content="noindex"><link rel="canonical" href="' + (AbsUrl "/topics/$($t.slug)/") + '"><meta http-equiv="refresh" content="0; url=' + $to + '"></head><body><p><a href="' + $to + '">' + (Esc $t.name) + '</a></p></body></html>')
    }
}

# ---------------------------------------------------------------- speakers
$letters = @($speakerList | ForEach-Object { $_.letter } | Select-Object -Unique)
$az = ($letters | ForEach-Object { '<li><a href="#letter-' + $_ + '">' + $_ + '</a></li>' }) -join ''
$groups = New-Object Text.StringBuilder
foreach ($L in $letters) {
    [void]$groups.Append('<section data-filter-group><h2 class="letter" id="letter-' + $L + '">' + $L + '</h2><ul class="speaker-grid">')
    foreach ($s in @($speakerList | Where-Object { $_.letter -eq $L })) {
        $role = ''; if ($s.role) { $role = '<span>' + (Esc $s.role) + '</span>' }
        [void]$groups.Append('<li data-search="' + (Esc (($s.name + ' ' + $s.role).ToLowerInvariant())) + '"><a class="speaker-card" href="' + (U "/speakers/$($s.slug)/") + '">' + (Avatar $s.slug $s.initials) + '<span><b>' + (Esc $s.name) + '</b>' + $role + '</span></a></li>')
    }
    [void]$groups.Append('</ul></section>')
}
Write-Page '/speakers/' 'Speakers' "An A to Z of the $($speakerList.Count) clinicians, researchers, nurses and families interviewed by PVJ." @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Speakers' }))
<h1>Speakers</h1>
<p class="lede">The people interviewed by PVJ, listed by surname.</p>
</div>
<div class="filters single">
<div><label class="sr-only" for="f-q">Search speakers</label><input id="f-q" type="search" placeholder="Search by name or organisation" autocomplete="off"></div>
</div>
<p class="filter-status" id="f-status" aria-live="polite"><span>$(Plural $speakerList.Count 'speaker')</span><button type="button" hidden>Clear search</button></p>
<ul class="az">$az</ul>
<div data-filter-list data-noun="speaker">
$($groups.ToString())
</div>
<p class="empty" id="f-empty">No speakers match that search.</p>
</div>
<div class="section tight"></div>
"@ @{ nav = 'speakers' }

foreach ($s in $speakerList) {
    $sv = @($s.videos)
    $role = ''; if ($s.role) { $role = '<p>' + (Esc $s.role) + '</p>' }
    $descrHead = "Watch $(Plural $sv.Count 'PVJ video interview') with $($s.name)"
    $descrTail = ', on ' + [string]$site.fullName + '.'
    $descrRole = ''
    if ($s.role) {
        $roleMax = [Math]::Min(100, 158 - $descrHead.Length - $descrTail.Length - 2)
        $descrRole = ([string]$s.role).Trim()
        if ($descrRole.Length -gt $roleMax) {
            $descrRole = $descrRole.Substring(0, $roleMax)
            $cutAt = $descrRole.LastIndexOf(' ')
            if ($cutAt -gt 0) { $descrRole = $descrRole.Substring(0, $cutAt) }
            $descrRole = $descrRole.TrimEnd(' ', ',', ';', ':', '-')
        }
        $descrRole = ', ' + $descrRole
    }
    $descr = $descrHead + $descrRole + $descrTail
    $personLd = ''
    if ($cfgUrl) {
        $personLd = '{"@context":"https://schema.org","@type":"Person","name":"' + (J ([string]$s.name)) + '","url":"' + (J (AbsUrl "/speakers/$($s.slug)/")) + '"' + $(if ($s.role) { ',"description":"' + (J ([string]$s.role)) + '"' } else { '' }) + '}'
    }
    Write-Page "/speakers/$($s.slug)/" $s.name $descr @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Speakers'; href = '/speakers/' }, @{ label = $s.name }))
<div class="speaker-head">
$(Avatar $s.slug $s.initials)
<div><h1>$(Esc $s.name)</h1>$role</div>
</div>
</div>
<p class="filter-status">$(Plural $sv.Count 'video')</p>
<h2 class="sr-only">Videos</h2>
$(Grid $sv $true '' $true)
</div>
<div class="section tight"></div>
"@ @{ nav = 'speakers'; jsonld = $personLd }
}

# ---------------------------------------------------------------- research roundups
function PeriodText([string]$from, [string]$to) {
    $d1 = [datetime]::ParseExact($from, 'yyyy-MM-dd', $inv); $d2 = [datetime]::ParseExact($to, 'yyyy-MM-dd', $inv)
    if ($d1.Year -eq $d2.Year -and $d1.Month -eq $d2.Month) { return $d1.Day.ToString() + ' to ' + $d2.ToString('d MMMM yyyy', $inv) }
    if ($d1.Year -eq $d2.Year) { return $d1.ToString('d MMMM', $inv) + ' to ' + $d2.ToString('d MMMM yyyy', $inv) }
    return $d1.ToString('d MMMM yyyy', $inv) + ' to ' + $d2.ToString('d MMMM yyyy', $inv)
}
if ($roundups.Count -gt 0) {
    $ruList = New-Object Text.StringBuilder
    foreach ($ru in $roundups) {
        $ruPeriod = PeriodText ([string]$ru.from) ([string]$ru.to)
        $ruPath = "/research-roundup/$($ru.slug)/"
        $ruFrag = (Read-Text (Join-Path $roundupDir ([string]$ru.slug + '.html'))).Trim()
        $ruLd = ''
        if ($cfgUrl) {
            $ruLd = '{"@context":"https://schema.org","@type":"Article","headline":"' + (J ([string]$ru.headline)) + '","description":"' + (J ([string]$ru.summary)) + '","datePublished":"' + [string]$ru.compiled + 'T00:00:00+00:00","mainEntityOfPage":"' + (J (AbsUrl $ruPath)) + '","author":{"@type":"Organization","name":"' + (J $site.fullName) + '","url":"' + (J (AbsUrl '/')) + '"},"publisher":{"@type":"Organization","name":"' + (J $site.fullName) + '","logo":{"@type":"ImageObject","url":"' + (J (AbsUrl '/assets/img/pvj-logo.png')) + '"}}}'
        }
        Write-Page $ruPath ([string]$ru.headline) ([string]$ru.summary) @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Research roundup'; href = '/research-roundup/' }, @{ label = $ruPeriod }))
<span class="eyebrow">Weekly research roundup</span>
<h1>$(Esc ([string]$ru.headline))</h1>
<p class="lede">$(Esc ([string]$ru.lede))</p>
<ul class="facts"><li>Research published $ruPeriod</li><li>Compiled $(DateLong ([string]$ru.compiled))</li></ul>
</div>
<div class="roundup">
$ruFrag
</div>
</div>
<div class="section tight"></div>
"@ @{ headTitle = "Paediatric research roundup, $ruPeriod"; jsonld = $ruLd; ogType = 'article' }
        [void]$ruList.Append('<a class="ru-issue" href="' + (U $ruPath) + '"><span class="eyebrow">' + (Esc $ruPeriod) + '</span><b>' + (Esc ([string]$ru.headline)) + '</b><span>' + (Esc ([string]$ru.summary)) + '</span></a>')
    }
    Write-Page '/research-roundup/' 'Research roundup' 'The paediatric research papers attracting the most attention and the ones most likely to change practice, with links to the original studies.' @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Research roundup' }))
<h1>Research roundup</h1>
<p class="lede">The paediatric research papers attracting the most attention, and the ones most likely to change practice, with links to the original studies.</p>
</div>
<div class="ru-issues">$($ruList.ToString())</div>
</div>
<div class="section tight"></div>
"@ @{ headTitle = 'Paediatric research roundup' }
}

# ---------------------------------------------------------------- static pages
foreach ($p in $pages) {
    $src = Join-Path $root ('content\pages\' + $p.file)
    if (-not (Test-Path $src)) { Write-Host "WARNING: missing page file $($p.file) - page skipped"; continue }
    $frag = Read-Text $src
    $frag = [regex]::Replace($frag, '(?s)<!--.*?-->', '')
    $frag = $frag.Replace('{{base}}', $cfgBase).Trim()
    $crumbs = @(); if ($p.parentLabel) { $crumbs += @{ label = $p.parentLabel; href = $p.parentHref } }; $crumbs += @{ label = $p.title }
    # "cta": true in pages.json adds an enquiry panel under the page
    $ctaHtml = ''
    if ($p.cta) {
        $ctaBtn = '<a class="btn light" href="' + (U '/contact/') + '">Contact us</a>'
        if ($site.contactEmail) { $ctaBtn = '<a class="btn light" href="mailto:' + (Esc $site.contactEmail) + '?subject=' + [uri]::EscapeDataString('Conference coverage enquiry') + '">Email us about your event</a><a class="btn outline-light" href="' + (U '/contact/') + '">Other ways to reach us</a>' }
        $ctaHtml = '<div class="section tight"><div class="cta"><div><h2>Planning a conference?</h2><p>Tell us the event, the dates and roughly how many interviews you have in mind, and we will come back to you.</p></div><div class="hero-actions">' + $ctaBtn + '</div></div></div>'
    }
    Write-Page $p.path $p.title $p.description @"
<div class="wrap">
<div class="page-head">
$(Crumbs $crumbs)
<h1>$(Esc $p.title)</h1>
</div>
<div class="prose">
$frag
</div>
$ctaHtml
</div>
"@ @{ nav = [string]$p.nav }
}

# ---------------------------------------------------------------- contact
$cards = New-Object Text.StringBuilder
if ($site.contactEmail) { [void]$cards.Append('<li><a href="mailto:' + (Esc $site.contactEmail) + '"><b>Email</b><span>' + (Esc $site.contactEmail) + '</span></a></li>') }
[void]$cards.Append('<li><a href="' + (Esc $site.linkedinUrl) + '" rel="noopener"><b>LinkedIn</b><span>Message PVJ on our LinkedIn page</span></a></li>')
[void]$cards.Append('<li><a href="' + (Esc $site.youtubeUrl) + '" rel="noopener"><b>YouTube</b><span>Subscribe to The Paediatric Video Journal</span></a></li>')
Write-Page '/contact/' 'Contact' 'Get in touch with The Paediatric Video Journal about a video, a correction, working with PVJ or anything else.' @"
<div class="wrap">
<div class="page-head">
$(Crumbs @(@{ label = 'Contact' }))
<h1>Contact PVJ</h1>
<p class="lede">Questions about a video, a correction, or coverage for your conference? We would like to hear from you.</p>
</div>
<div class="prose">
<ul class="contact-cards">$($cards.ToString())</ul>
<h2>Conference organisers and societies</h2>
<p>If you would like PVJ to record interviews at your meeting, read <a href="$(U '/work-with-us/')">how we work with partners</a> and then get in touch.</p>
<h2>Speakers</h2>
<p>If you appear in a PVJ interview and need a detail corrected, tell us which video and what should change. Our <a href="$(U '/about/editorial-policy/')">editorial policy</a> explains how we handle corrections and removal requests.</p>
</div>
</div>
"@ @{ nav = 'about' }

# ---------------------------------------------------------------- 404, feeds, housekeeping
Write-Page '/404.html' 'Page not found' 'That page could not be found.' @"
<div class="wrap">
<div class="page-head">
<span class="eyebrow">Error 404</span>
<h1>Page not found</h1>
<p class="lede">That page does not exist or has moved. Try the video library or head back to the home page.</p>
<div class="hero-actions"><a class="btn" href="$(U '/videos/')">Browse videos</a><a class="btn ghost" href="$(U '/')">Home</a></div>
</div>
</div>
<div class="section"></div>
"@ @{ noindex = $true }

if ($isPreview) {
    Write-Out '/robots.txt' "User-agent: *`nDisallow: /`n"
    Write-Host 'NOTE: preview mode ("preview": true in site.json) - every page is marked noindex and there is no sitemap or feed.'
} elseif ($cfgUrl) {
    $sm = New-Object Text.StringBuilder
    [void]$sm.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sm.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:video="http://www.google.com/schemas/sitemap-video/1.1">')
    $videoByUrl = @{}
    foreach ($vx in $videos) { $videoByUrl[[string]$vx.url] = $vx }
    foreach ($p in $sitemap) {
        $vx = $videoByUrl[[string]$p]
        if ($vx) {
            $vxPub = [string]$vx.published
            $vxLine = '<url><loc>' + (X (AbsUrl $p)) + '</loc><lastmod>' + $vxPub + '</lastmod><video:video>'
            $vxLine += '<video:thumbnail_loc>https://i.ytimg.com/vi/' + $vx.youtubeId + '/maxresdefault.jpg</video:thumbnail_loc>'
            $vxLine += '<video:title>' + (X ([string]$vx.title)) + '</video:title><video:description>' + (X ([string]$vx.summary)) + '</video:description>'
            $vxLine += '<video:player_loc>https://www.youtube-nocookie.com/embed/' + $vx.youtubeId + '</video:player_loc>'
            $vxLine += '<video:duration>' + [int]$vx.seconds + '</video:duration><video:publication_date>' + $vxPub + 'T00:00:00+00:00</video:publication_date></video:video></url>'
            [void]$sm.AppendLine($vxLine)
        } else { [void]$sm.AppendLine('<url><loc>' + (X (AbsUrl $p)) + '</loc></url>') }
    }
    [void]$sm.AppendLine('</urlset>')
    Write-Out '/sitemap.xml' $sm.ToString()

    $rss = New-Object Text.StringBuilder
    [void]$rss.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$rss.AppendLine('<rss version="2.0"><channel>')
    [void]$rss.AppendLine('<title>' + (X $site.fullName) + '</title><link>' + (X (AbsUrl '/')) + '</link><description>' + (X $site.metaDescription) + '</description><language>en-gb</language>')
    foreach ($v in @($videos | Select-Object -First 40)) {
        $pub = ([datetime]::ParseExact($v.published, 'yyyy-MM-dd', $inv)).ToString('ddd, dd MMM yyyy', $inv) + ' 12:00:00 GMT'
        [void]$rss.AppendLine('<item><title>' + (X $v.title) + '</title><link>' + (X (AbsUrl $v.url)) + '</link><guid>' + (X (AbsUrl $v.url)) + '</guid><pubDate>' + $pub + '</pubDate><description>' + (X $v.summary) + '</description></item>')
    }
    [void]$rss.AppendLine('</channel></rss>')
    Write-Out '/feed.xml' $rss.ToString()
    Write-Out '/robots.txt' ("User-agent: *`nAllow: /`n`nSitemap: " + (AbsUrl '/sitemap.xml') + "`n")
} else {
    Write-Out '/robots.txt' "User-agent: *`nAllow: /`n"
    Write-Host 'NOTE: site.json "url" is empty - canonical links, share buttons, sitemap.xml and feed.xml were left out. Set it once the domain is known.'
}
Write-Out '/.nojekyll' ''
if ($site.domain) { Write-Out '/CNAME' ([string]$site.domain + "`n") }
# Google Search Console ownership file. site.json "googleSiteVerification" holds the file name Google gave
# (for example google0123456789abcdef.html). Removing it un-verifies the site in Search Console.
if ([string]$site.googleSiteVerification -match '^google[0-9a-f]+\.html$') {
    Write-Out ('/' + [string]$site.googleSiteVerification) ('google-site-verification: ' + [string]$site.googleSiteVerification)
}

Write-Host ("Built {0} pages -> {1}  ({2} videos, {3} with transcripts, {4} speakers, {5} topics, {6} conferences)" -f $pageCount, $outDir, $videos.Count, $transcriptCount, $speakerList.Count, $liveTopics.Count, $conferences.Count)
