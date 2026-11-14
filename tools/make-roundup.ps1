param([Parameter(Mandatory = $true)][string]$Issue, [Parameter(Mandatory = $true)][string]$Report)

# Turns a checked weekly research roundup report into the page body the site shows.
#
#   -Issue   the issue's slug, the date it was compiled, for example 2026-11-13.
#            content\roundups\<slug>.json must exist. It holds the headline, dates, intro lines and
#            notes, and PVJ's own short text for each ranked paper:
#              "discussed": ten entries { "doi", "headline", "summary", "topic" }   (first table)
#              "important": ten entries { "doi", "summary", "topic" }               (second table)
#            "doi" is the paper's https://doi.org/... link as the report gives it. "headline" is a
#            plain-language headline; the paper's own title goes under "The paper and its
#            attention". "summary" is one paragraph: who did the work, why it matters, the method,
#            the findings. "topic" names the picture: a file in src\icons\clinical\ without ".svg".
#   -Report  the checked roundup report (Markdown) with: two tables of exactly ten rows whose
#            first column is "Rank" (ranked by attention, then PVJ's priority papers), and a
#            section "## E. ..." holding five stories, each as a bold "**n. Headline**" line,
#            a summary line and a <https://doi.org/...> line.
#
# Writes content\roundups\<slug>.html. Titles, journals, dates, links and the detail under each
# paper are copied from the report. The headlines and summaries come from the issue file, and the
# script stops if one of them carries a number that is not in that paper's row of the report.
# Run tools\build.ps1 afterwards.
# Keep this file plain ASCII (Windows PowerShell 5.1). Do not name a function after an alias.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$enc = New-Object Text.UTF8Encoding $false
$dir = Join-Path (Join-Path $root 'content') 'roundups'
$iconDir = Join-Path (Join-Path (Join-Path $root 'src') 'icons') 'clinical'
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

# The picture beside a paper: the clinical-area icon named by "topic" (see src\icons\README.md).
function IconSvg([string]$topic) {
    if ($topic -notmatch '^[a-z0-9-]+$') { throw "bad topic '$topic'" }
    $f = Join-Path $iconDir ($topic + '.svg')
    if (-not (Test-Path -LiteralPath $f)) { throw "no picture for topic '$topic': $f is missing" }
    return ([regex]::Replace([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8), '<\?xml[^>]*\?>', '')).Trim()
}
# PVJ's own text for one paper, found by its DOI link in the issue file.
function EditorialFor($list, [string]$url, [string]$what) {
    $hit = @(@($list) | Where-Object { [string]$_.doi -eq $url })
    if ($hit.Count -ne 1) { throw ('content\roundups\' + $Issue + '.json: expected one "' + $what + '" entry with doi ' + $url + ', found ' + $hit.Count) }
    return $hit[0]
}
# A headline or summary may only carry numbers that stand in that paper's row of the report.
$dashes = '[' + [string][char]0x2013 + [string][char]0x2014 + [string][char]0x2212 + ']'
function FigureText([string]$s) { $s = $s -replace $dashes, '-'; $s = $s -replace ',(?=\d{3})', ''; return $s.Replace([string][char]0xA0, ' ') }
function CheckFigures([string]$text, [string]$rowText, [string]$label) {
    $rowN = FigureText $rowText
    foreach ($m in [regex]::Matches((FigureText $text), '\d+(?:\.\d+)?')) {
        if ($rowN -notmatch ('(?<![\d.])' + [regex]::Escape($m.Value) + '(?!\d)')) { throw ($label + ': the figure ' + $m.Value + ' is not in that paper''s row of the report') }
    }
}

$tables = New-Object Collections.ArrayList; $cur = $null
foreach ($l in $lines) {
    if ($l -match '^\|\s*Rank\s*\|') { $cur = New-Object Collections.ArrayList; [void]$tables.Add($cur); continue }
    if ($null -ne $cur) { if ($l -match '^\|\s*\d+\s*\|') { $c = @($l -split '\|' | ForEach-Object { $_.Trim() }); [void]$cur.Add($c[1..($c.Count - 2)]) } elseif ($l -notmatch '^\|') { $cur = $null } }
}
if ($tables.Count -ne 2 -or $tables[0].Count -ne 10 -or $tables[1].Count -ne 10) { throw "expected two tables of ten rows in the report" }

$pop = @($tables[0] | ForEach-Object { $c = $_; $score = [regex]::Match($c[9], '\*\*(\d+)\*\*'); if (-not $score.Success) { throw "no score in row $($c[0])" }
    $before = $c[3] -match 'before the window'; $date = ([regex]::Replace($c[3], '\s*\(\*\*published before the window\*\*[^)]*\)', '')).Trim()
    [pscustomobject]@{ rank = [int]$c[0]; title = $c[1]; journal = (JournalName $c[2]); date = $date; before = $before; country = $c[4]; design = $c[5]; findings = $c[6]; why = $c[7]; url = (DoiUrl $c[8]); attention = $c[9]; score = [int]$score.Groups[1].Value; raw = ($c -join ' | ') } })
$clin = @($tables[1] | ForEach-Object { $c = $_
    [pscustomobject]@{ rank = [int]$c[0]; title = $c[1]; journal = (JournalName $c[2]); date = $c[3]; country = $c[4]; design = $c[5]; findings = $c[6]; why = $c[7]; limits = $c[8]; url = (DoiUrl $c[9]); raw = ($c -join ' | ') } })
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

# First list: a plain-language headline, a picture and one paragraph; the paper's own title,
# the study detail and the attention figures sit one tap away.
$popHtml = ($pop | ForEach-Object {
    $ed = EditorialFor $meta.discussed $_.url 'discussed'
    $head = ([string]$ed.headline).Trim(); $sum = ([string]$ed.summary).Trim()
    if (-not $head -or $head.Length -gt 100) { throw "discussed $($_.rank): headline missing or longer than 100 characters" }
    if (-not $sum) { throw "discussed $($_.rank): summary missing" }
    CheckFigures ($head + ' ' + $sum) $_.raw ('discussed ' + $_.rank)
@"
<li class="ru-item">
<div class="ru-pic" aria-hidden="true"><span class="ru-rk">$($_.rank)</span>$(IconSvg ([string]$ed.topic))</div>
<h3><a href="$(HtmlEnc $_.url)" rel="noopener">$(HtmlEnc $head)</a></h3>
<div class="ru-body">
<p class="ru-sum">$(HtmlEnc $sum)</p>
<p class="ru-meta">$(HtmlEnc $_.journal) <span>&middot;</span> $(HtmlEnc $_.date)$(if ($_.before) { ' <span class="ru-flag">Published before this week</span>' }) <span>&middot;</span> <a href="$(HtmlEnc $_.url)" rel="noopener">Read the paper</a></p>
<details>
<summary>The paper and its attention</summary>
<dl>
<dt>Paper</dt><dd>$(InlineHtml $_.title)</dd>
<dt>Study</dt><dd>$(InlineHtml $_.design). $(InlineHtml $_.country).</dd>
<dt>Findings in full</dt><dd>$(InlineHtml $_.findings)</dd>
<dt>Why the attention</dt><dd>$(InlineHtml $_.why)</dd>
<dt>Measured attention</dt><dd>$(InlineHtml $_.attention)</dd>
</dl>
</details>
</div>
</li>
"@ }) -join "`n"

# Second list: the paper's own title, a picture and one paragraph.
$clinHtml = ($clin | ForEach-Object {
    $ed = EditorialFor $meta.important $_.url 'important'
    $sum = ([string]$ed.summary).Trim()
    if (-not $sum) { throw "important $($_.rank): summary missing" }
    CheckFigures $sum $_.raw ('important ' + $_.rank)
@"
<li class="ru-item">
<div class="ru-pic" aria-hidden="true"><span class="ru-rk">$($_.rank)</span>$(IconSvg ([string]$ed.topic))</div>
<h3><a href="$(HtmlEnc $_.url)" rel="noopener">$(InlineHtml $_.title)</a></h3>
<div class="ru-body">
<p class="ru-sum">$(HtmlEnc $sum)</p>
<p class="ru-meta">$(HtmlEnc $_.journal) <span>&middot;</span> $(InlineHtml $_.date) <span>&middot;</span> <a href="$(HtmlEnc $_.url)" rel="noopener">Read the paper</a></p>
<details>
<summary>Evidence and limitations</summary>
<dl>
<dt>Study</dt><dd>$(InlineHtml $_.design). $(InlineHtml $_.country).</dd>
<dt>Findings in full</dt><dd>$(InlineHtml $_.findings)</dd>
<dt>Why it matters</dt><dd>$(InlineHtml $_.why)</dd>
<dt>Limitations</dt><dd>$(InlineHtml $_.limits)</dd>
</dl>
</details>
</div>
</li>
"@ }) -join "`n"

$notesHtml = (@($meta.notes) | ForEach-Object { '<li>' + (HtmlEnc ([string]$_)) + '</li>' }) -join "`n"

$page = @"
<nav class="ru-jump" aria-label="In this issue"><a href="#stories">Five stories</a><a href="#discussed">Top 10 in focus</a><a href="#important">Top 10 priority papers</a><a href="#method">How this was compiled</a></nav>

<section class="ru-sec" id="stories">
<div class="ru-head"><h2>Five stories this week</h2><p>$(HtmlEnc ([string]$meta.storiesIntro))</p></div>
<div class="ru-stories">
$storyHtml
</div>
</section>

<section class="ru-sec" id="discussed">
<div class="ru-head"><h2>Top 10 in focus</h2><p>$(HtmlEnc ([string]$meta.discussedIntro))</p></div>
<ol class="ru-rank">
$popHtml
</ol>
</section>

<section class="ru-sec" id="important">
<div class="ru-head"><h2>Top 10 priority papers</h2><p>$(HtmlEnc ([string]$meta.importantIntro))</p></div>
<ol class="ru-rank ru-alt">
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
Write-Host ("wrote {0}: 5 stories, 10 in focus (top score {1}), 10 priority papers" -f $out, $max)
