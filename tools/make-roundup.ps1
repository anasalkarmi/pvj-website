param([Parameter(Mandatory = $true)][string]$Issue, [Parameter(Mandatory = $true)][string]$Report)

# Turns a checked weekly research roundup report into the page body the site shows.
#
#   -Issue   the issue's slug, the date it was compiled, for example 2026-11-13.
#            content\roundups\<slug>.json must exist (headline, dates, intro lines, notes).
#   -Report  the checked roundup report (Markdown) with: two tables of exactly ten rows whose
#            first column is "Rank" (most discussed, then most clinically important), and a
#            section "## E. ..." holding five stories, each as a bold "**n. Headline**" line,
#            a summary line and a <https://doi.org/...> line.
#
# Writes content\roundups\<slug>.html. Every title, figure and link is copied from the report,
# so nothing is retyped by hand. Run tools\build.ps1 afterwards.
# Keep this file plain ASCII (Windows PowerShell 5.1). Do not name a function after an alias.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$enc = New-Object Text.UTF8Encoding $false
$dir = Join-Path (Join-Path $root 'content') 'roundups'
$metaFile = Join-Path $dir ($Issue + '.json')
if (-not (Test-Path -LiteralPath $metaFile)) { throw "missing $metaFile" }
$meta = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($metaFile, [Text.Encoding]::UTF8))
$lines = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Report).Path, [Text.Encoding]::UTF8) -split "`r?`n"

function HtmlEnc([string]$s) { return [Net.WebUtility]::HtmlEncode($s) }
# inline Markdown (bold, [text](link), <link>) to HTML
function InlineHtml([string]$s) {
    $s = $s.Trim(); $store = New-Object Collections.ArrayList
    $s = [regex]::Replace($s, '<(https?://[^>]+)>', { param($m) [void]$store.Add('<a href="' + (HtmlEnc $m.Groups[1].Value) + '" rel="noopener">' + (HtmlEnc ($m.Groups[1].Value -replace '^https?://', '')) + '</a>'); return [string][char]1 + ($store.Count - 1) + [string][char]2 })
    $s = [regex]::Replace($s, '\[([^\]]+)\]\((https?://[^)\s]+)\)', { param($m) [void]$store.Add('<a href="' + (HtmlEnc $m.Groups[2].Value) + '" rel="noopener">' + (HtmlEnc $m.Groups[1].Value) + '</a>'); return [string][char]1 + ($store.Count - 1) + [string][char]2 })
    $s = HtmlEnc $s
    $s = [regex]::Replace($s, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $s = [regex]::Replace($s, '(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])', '<em>$1</em>')
    $s = [regex]::Replace($s, [string][char]1 + '(\d+)' + [string][char]2, { param($m) $store[[int]$m.Groups[1].Value] })
    return $s
}
function PlainText([string]$s) { return ([regex]::Replace(([regex]::Replace($s, '\[([^\]]+)\]\((https?://[^)\s]+)\)', '$1')), '\*\*|<|>', '')).Trim() }
function DoiUrl([string]$cell) { $m = [regex]::Match($cell, '<(https://doi\.org/[^>]+)>'); if (-not $m.Success) { throw "no DOI link in: $cell" }; return $m.Groups[1].Value }
function JournalName([string]$cell) { return ([regex]::Replace($cell, '\s*\(\d{4};.*\)\s*$', '')).Trim() }

$tables = New-Object Collections.ArrayList; $cur = $null
foreach ($l in $lines) {
    if ($l -match '^\|\s*Rank\s*\|') { $cur = New-Object Collections.ArrayList; [void]$tables.Add($cur); continue }
    if ($null -ne $cur) { if ($l -match '^\|\s*\d+\s*\|') { $c = @($l -split '\|' | ForEach-Object { $_.Trim() }); [void]$cur.Add($c[1..($c.Count - 2)]) } elseif ($l -notmatch '^\|') { $cur = $null } }
}
if ($tables.Count -ne 2 -or $tables[0].Count -ne 10 -or $tables[1].Count -ne 10) { throw "expected two tables of ten rows in the report" }

$pop = @($tables[0] | ForEach-Object { $c = $_; $score = [regex]::Match($c[9], '\*\*(\d+)\*\*'); if (-not $score.Success) { throw "no score in row $($c[0])" }
    $before = $c[3] -match 'before the window'; $date = ([regex]::Replace($c[3], '\s*\(\*\*published before the window\*\*[^)]*\)', '')).Trim()
    [pscustomobject]@{ rank = [int]$c[0]; title = $c[1]; journal = (JournalName $c[2]); date = $date; before = $before; country = $c[4]; design = $c[5]; findings = $c[6]; why = $c[7]; url = (DoiUrl $c[8]); attention = $c[9]; score = [int]$score.Groups[1].Value } })
$clin = @($tables[1] | ForEach-Object { $c = $_
    [pscustomobject]@{ rank = [int]$c[0]; title = $c[1]; journal = (JournalName $c[2]); date = $c[3]; country = $c[4]; design = $c[5]; findings = $c[6]; why = $c[7]; limits = $c[8]; url = (DoiUrl $c[9]) } })
$max = ($pop | Measure-Object score -Maximum).Maximum

$stories = New-Object Collections.ArrayList
$e = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## E\.') { $e = $i; break } }
if ($e -lt 0) { throw 'no "## E." section with the five stories in the report' }
for ($i = $e + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^## ') { break }
    $m = [regex]::Match($lines[$i], '^\*\*\d+\.\s*(.+?)\*\*\s*$')
    if ($m.Success) {
        $body = ([regex]::Replace($lines[$i + 1], '\s*\*\(\d+ words\)\*\s*$', '')).Trim(); $url = (DoiUrl $lines[$i + 2])
        $row = @($clin | Where-Object { $_.url -eq $url })[0]; if (-not $row) { $row = @($pop | Where-Object { $_.url -eq $url })[0] }
        if (-not $row) { throw "story link not in the tables: $url" }
        [void]$stories.Add([pscustomobject]@{ head = $m.Groups[1].Value; body = $body; url = $url; row = $row })
    }
}
if ($stories.Count -ne 5) { throw "expected five stories, found $($stories.Count)" }

$storyHtml = ($stories | ForEach-Object { $d = [regex]::Replace($_.row.date, '\s*\(.*$', '')
@"
<article class="ru-story">
<p class="ru-kicker">$(HtmlEnc $_.row.journal) <span>&middot;</span> $(HtmlEnc $d)</p>
<h3>$(InlineHtml $_.head)</h3>
<p class="ru-sum">$(InlineHtml $_.body)</p>
<p class="ru-src"><span>$(HtmlEnc (PlainText $_.row.country))</span><a href="$(HtmlEnc $_.url)" rel="noopener">Read the paper</a></p>
</article>
"@ }) -join "`n"

$popHtml = ($pop | ForEach-Object { $w = [Math]::Max(0.6, [Math]::Round(100.0 * $_.score / $max, 1))
@"
<li class="ru-item">
<span class="ru-rk" aria-hidden="true">$($_.rank)</span>
<div class="ru-body">
<h3><a href="$(HtmlEnc $_.url)" rel="noopener">$(InlineHtml $_.title)</a></h3>
<p class="ru-meta">$(HtmlEnc $_.journal) <span>&middot;</span> $(HtmlEnc $_.date)$(if ($_.before) { ' <span class="ru-flag">Published before this week</span>' })</p>
<div class="ru-score" role="img" aria-label="Altmetric Attention Score $($_.score)"><span class="ru-track"><span class="ru-bar" style="width: $($w.ToString([Globalization.CultureInfo]::InvariantCulture))%"></span></span><b>$($_.score)</b></div>
<details>
<summary>Findings and why it is being discussed</summary>
<dl>
<dt>Study</dt><dd>$(InlineHtml $_.design). $(InlineHtml $_.country).</dd>
<dt>Key findings</dt><dd>$(InlineHtml $_.findings)</dd>
<dt>Why the attention</dt><dd>$(InlineHtml $_.why)</dd>
<dt>Measured attention</dt><dd>$(InlineHtml $_.attention)</dd>
</dl>
</details>
</div>
</li>
"@ }) -join "`n"

$clinHtml = ($clin | ForEach-Object {
@"
<li class="ru-item">
<span class="ru-rk" aria-hidden="true">$($_.rank)</span>
<div class="ru-body">
<h3><a href="$(HtmlEnc $_.url)" rel="noopener">$(InlineHtml $_.title)</a></h3>
<p class="ru-meta">$(HtmlEnc $_.journal) <span>&middot;</span> $(InlineHtml $_.date)</p>
<p class="ru-lbl">Why it matters</p>
<p class="ru-why">$(InlineHtml $_.why)</p>
<details>
<summary>Evidence and limitations</summary>
<dl>
<dt>Study</dt><dd>$(InlineHtml $_.design). $(InlineHtml $_.country).</dd>
<dt>Key findings</dt><dd>$(InlineHtml $_.findings)</dd>
<dt>Limitations</dt><dd>$(InlineHtml $_.limits)</dd>
</dl>
</details>
</div>
</li>
"@ }) -join "`n"

$notesHtml = (@($meta.notes) | ForEach-Object { '<li>' + (HtmlEnc ([string]$_)) + '</li>' }) -join "`n"

$page = @"
<nav class="ru-jump" aria-label="In this issue"><a href="#stories">Five stories</a><a href="#discussed">Most discussed</a><a href="#important">Most clinically important</a><a href="#method">How this was compiled</a></nav>

<section class="ru-sec" id="stories">
<div class="ru-head"><h2>Five stories this week</h2><p>$(HtmlEnc ([string]$meta.storiesIntro))</p></div>
<div class="ru-stories">
$storyHtml
</div>
</section>

<section class="ru-sec" id="discussed">
<div class="ru-head"><h2>Most discussed</h2><p>$(HtmlEnc ([string]$meta.discussedIntro))</p></div>
<ol class="ru-rank">
$popHtml
</ol>
</section>

<section class="ru-sec" id="important">
<div class="ru-head"><h2>Most clinically important</h2><p>$(HtmlEnc ([string]$meta.importantIntro))</p></div>
<ol class="ru-rank">
$clinHtml
</ol>
</section>

<section class="ru-sec" id="method">
<div class="ru-head"><h2>How this was compiled</h2><p>What was searched, how attention was measured, and what could not be checked.</p></div>
<ul class="ru-notes">
$notesHtml
</ul>
<p class="ru-caution">$(HtmlEnc ([string]$meta.caution))</p>
</section>
"@
$out = Join-Path $dir ($Issue + '.html')
[IO.File]::WriteAllText($out, $page.Replace("`r`n", "`n"), $enc)
Write-Host ("wrote {0}: 5 stories, 10 most discussed (top score {1}), 10 clinical" -f $out, $max)
