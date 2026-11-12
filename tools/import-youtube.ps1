param([switch]$Check, [switch]$Rebuild)

# Adds videos to content/videos.json.
#
# Inputs (all in work/import):
#   youtube-harvest.json   - made by tools/youtube-harvest.ps1 (titles, descriptions, dates, durations)
#   enrich-*.json          - speakers, topics and summary per video; file name gives the conference slug
#   text-fixes.json        - optional corrections for typos in the YouTube text
#   pccs-2026-publication.json - optional, LinkedIn post links
#
# Default: videos already in content/videos.json are kept exactly as they are (it is the
# hand-editable source of truth) and only NEW videos are added.
#   -Rebuild : regenerate every entry from the inputs (slugs are still kept)
#   -Check   : print the cross-checks only, write nothing
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
function Read-Json([string]$p) { return (ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8))) }
function Slug([string]$s) {
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $n.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($ch) }
    }
    # Only the straight apostrophe is dropped; a curly one becomes a hyphen ("parent-s"). Leave it so:
    # it matches tools/build.ps1 and the addresses already published.
    $t = [regex]::Replace($sb.ToString().ToLowerInvariant(), '['']', '')
    return ([regex]::Replace($t, '[^a-z0-9]+', '-')).Trim('-')
}
function Q([string]$s) {
    if ($null -eq $s) { return '""' }
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        if ($ch -eq '\') { [void]$sb.Append('\\') }
        elseif ($ch -eq '"') { [void]$sb.Append('\"') }
        elseif ($code -eq 10) { [void]$sb.Append('\n') }
        elseif ($code -eq 13) { }
        elseif ($code -eq 9) { [void]$sb.Append(' ') }
        elseif ($code -lt 32) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}
function Squash([string]$s) { return ([regex]::Replace([string]$s, '\s+', ' ')).Trim() }

$imp = Join-Path (Join-Path $root 'work') 'import'
$harvest = @(Read-Json (Join-Path $imp 'youtube-harvest.json'))
$confOf = @{}; $enrich = @{}
foreach ($f in Get-ChildItem $imp -Filter 'enrich-*.json') {
    $conf = $f.BaseName.Substring(7)
    foreach ($e in @(Read-Json $f.FullName)) { $enrich[$e.id] = $e; $confOf[$e.id] = $conf }
}
$fixes = @()
$fixFile = Join-Path $imp 'text-fixes.json'
if (Test-Path $fixFile) { $fixes = @(Read-Json $fixFile) }
$pub = @{}
$pubFile = Join-Path $imp 'pccs-2026-publication.json'
if (Test-Path $pubFile) { foreach ($r in @((Read-Json $pubFile).interviews)) { $pub[$r.video_id] = $r } }

$existing = @{}
$videosPath = Join-Path (Join-Path $root 'content') 'videos.json'
if (Test-Path $videosPath) { foreach ($v in @(Read-Json $videosPath)) { $existing[$v.youtubeId] = $v } }

try { $tz = [TimeZoneInfo]::FindSystemTimeZoneById('GMT Standard Time') } catch { $tz = [TimeZoneInfo]::FindSystemTimeZoneById('Europe/London') }
$strip = '(?i)\b(professor|prof|dr|mr|mrs|ms|miss|sir|dame|justice|mbe|obe|cbe)\b\.?'
$warn = New-Object Collections.ArrayList
$note = New-Object Collections.ArrayList
$used = @{}; foreach ($v in $existing.Values) { $used[$v.slug] = 1 }
$rows = New-Object Collections.ArrayList
$added = 0; $kept = 0

foreach ($h in $harvest) {
    if ($existing.ContainsKey($h.id) -and -not $Rebuild) {
        $x = $existing[$h.id]
        [void]$rows.Add([pscustomobject]@{ slug = $x.slug; id = $x.youtubeId; title = $x.title; speakers = @($x.speakers | ForEach-Object { $_ }); conference = $x.conference; topics = @($x.topics | ForEach-Object { $_ }); summary = $x.summary; description = $x.description; published = $x.published; seconds = [int]$x.seconds; linkedin = [string]$x.linkedinUrl })
        $kept++
        continue
    }
    $e = $enrich[$h.id]
    if (-not $e) { [void]$warn.Add("NEW VIDEO NOT ENRICHED YET (left out): $($h.id)  $($h.title)"); continue }

    $rawDesc = [string]$h.description
    foreach ($fx in $fixes) { $rawDesc = $rawDesc.Replace([string]$fx.find, [string]$fx.replace) }

    # --- cross-checks of the hand-copied fields against the source text
    $srcTitle = Squash $h.title
    if ($srcTitle.Contains(' | ')) { $srcTitle = $srcTitle.Substring(0, $srcTitle.LastIndexOf(' | ')) }
    if ((Squash $e.title) -cne $srcTitle) { [void]$warn.Add("TITLE differs $($h.id): '$($e.title)' vs YouTube '$srcTitle'") }
    $flat = Squash $rawDesc
    foreach ($s in @($e.speakers)) {
        if ($flat.IndexOf((Squash $s.name), [StringComparison]::Ordinal) -lt 0) { [void]$warn.Add("NAME not found in description $($h.id): '$($s.name)'") }
        if ($s.role -and $flat.IndexOf((Squash $s.role), [StringComparison]::OrdinalIgnoreCase) -lt 0) { [void]$note.Add("role edited from the description wording $($h.id): '$($s.role)'") }
    }
    if ($pub.ContainsKey($h.id)) {
        $mine = (@($e.speakers | ForEach-Object { $_.name }) -join ' and ')
        if ((Squash $mine) -ne (Squash $pub[$h.id].speaker)) { [void]$warn.Add("SPEAKER differs from publication record $($h.id): '$mine' vs '$($pub[$h.id].speaker)'") }
    }
    $conf = $confOf[$h.id]

    # --- description: drop the copyright boilerplate (the site prints its own notice)
    $paras = @([regex]::Split($rawDesc.Replace("`r", ''), "\n+") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '(?i)^(this work is|these works are)\b.*copyright' -and $_ -notmatch '(?i)on the PVJ website:\s*https?://' })
    $desc = $paras -join "`n`n"

    # --- slug: never changes once a video has one
    if ($existing.ContainsKey($h.id)) { $slug = $existing[$h.id].slug }
    else {
        $base = Slug $e.title
        if ($base.Length -gt 64) { $base = $base.Substring(0, 64); $cut = $base.LastIndexOf('-'); if ($cut -gt 30) { $base = $base.Substring(0, $cut) } }
        $sp = @($e.speakers)
        if ($sp.Count -gt 0) {
            $core = ([regex]::Replace($sp[0].name, $strip, '') -replace '\([^)]*\)', '').Trim()
            $base = $base + '-' + (Slug (($core -split '\s+')[-1]))
        }
        $slug = $base; $n = 2
        while ($used.ContainsKey($slug)) { $slug = "$base-$n"; $n++ }
        $used[$slug] = 1
    }

    $date = [TimeZoneInfo]::ConvertTime([DateTimeOffset]::Parse($h.published, $inv), $tz).ToString('yyyy-MM-dd', $inv)
    $li = ''; if ($pub.ContainsKey($h.id)) { $li = [string]$pub[$h.id].linkedin_url }
    [void]$rows.Add([pscustomobject]@{ slug = $slug; id = $h.id; title = (Squash $e.title); speakers = @($e.speakers | ForEach-Object { $_ }); conference = $conf; topics = @($e.topics | ForEach-Object { $_ }); summary = (Squash $e.summary); description = $desc; published = $date; seconds = [int]$h.seconds; linkedin = $li })
    $added++
}
$onYouTube = @{}; foreach ($h in $harvest) { $onYouTube[$h.id] = 1 }
foreach ($id in $existing.Keys) { if (-not $onYouTube.ContainsKey($id)) { [void]$warn.Add("ON THE SITE BUT NO LONGER ON YOUTUBE (dropped from the site): $id  $($existing[$id].title)") } }

"videos: $($rows.Count)   new or regenerated: $added   kept as-is: $kept   warnings: $($warn.Count)   notes: $($note.Count)"
$warn | ForEach-Object { "  WARNING  $_" }
$note | ForEach-Object { "  note     $_" }
if ($Check) { return }

$sb = New-Object Text.StringBuilder
[void]$sb.Append("[`n")
for ($i = 0; $i -lt $rows.Count; $i++) {
    $r = $rows[$i]
    [void]$sb.Append("  {`n")
    [void]$sb.Append('    "slug": ' + (Q $r.slug) + ",`n")
    [void]$sb.Append('    "youtubeId": ' + (Q $r.id) + ",`n")
    [void]$sb.Append('    "title": ' + (Q $r.title) + ",`n")
    $sp = @($r.speakers | ForEach-Object { '      { "name": ' + (Q (Squash $_.name)) + ', "role": ' + (Q (Squash $_.role)) + ' }' })
    if ($sp.Count -gt 0) { [void]$sb.Append('    "speakers": [' + "`n" + ($sp -join ",`n") + "`n    ],`n") } else { [void]$sb.Append('    "speakers": [],' + "`n") }
    [void]$sb.Append('    "conference": ' + (Q $r.conference) + ",`n")
    [void]$sb.Append('    "topics": [' + ((@($r.topics) | ForEach-Object { Q $_ }) -join ', ') + "],`n")
    [void]$sb.Append('    "summary": ' + (Q $r.summary) + ",`n")
    [void]$sb.Append('    "description": ' + (Q $r.description) + ",`n")
    [void]$sb.Append('    "published": ' + (Q $r.published) + ",`n")
    if ($r.linkedin) { [void]$sb.Append('    "seconds": ' + $r.seconds + ",`n" + '    "linkedinUrl": ' + (Q $r.linkedin) + "`n") } else { [void]$sb.Append('    "seconds": ' + $r.seconds + "`n") }
    if ($i -lt $rows.Count - 1) { [void]$sb.Append("  },`n") } else { [void]$sb.Append("  }`n") }
}
[void]$sb.Append("]`n")
[IO.File]::WriteAllText($videosPath, $sb.ToString(), $utf8)
"wrote $videosPath"
