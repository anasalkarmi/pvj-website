param([Parameter(Mandatory = $true)][string]$Conf)

# Checks work/import/enrich-<Conf>.json against work/import/in-<Conf>.txt.
# Prints PASS/FAIL per check. Exit code 1 if anything fails.
$root = Split-Path -Parent $PSScriptRoot
$inPath = Join-Path $root "work\import\in-$Conf.txt"
$outPath = Join-Path $root "work\import\enrich-$Conf.json"
$utf8 = [Text.Encoding]::UTF8
$fail = 0
function Check([bool]$ok, [string]$label, [string]$detail = '') {
    if ($ok) { "PASS  $label" } else { $script:fail++; "FAIL  $label  $detail" }
}

if (-not (Test-Path $outPath)) { "FAIL  output file missing: $outPath"; exit 1 }
$inText = [IO.File]::ReadAllText($inPath, $utf8)
try { $data = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($outPath, $utf8)) } catch { "FAIL  JSON does not parse: $($_.Exception.Message)"; exit 1 }
$data = @($data | ForEach-Object { $_ })
"PASS  JSON parses"

# input blocks: id -> description text
$blocks = @{}
foreach ($b in ([regex]::Split($inText, '(?m)^##### VIDEO \d+\s*$') | Where-Object { $_.Trim() })) {
    $m = [regex]::Match($b, '(?m)^ID: (\S+)')
    if ($m.Success) { $blocks[$m.Groups[1].Value] = $b }
}
$allowed = @((ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $root 'content\topics.json'), $utf8))) | ForEach-Object { $_.slug })

Check ($data.Count -eq $blocks.Count) "entry count equals input count ($($blocks.Count))" "got $($data.Count)"
$ids = @($data | ForEach-Object { $_.id })
$missing = @($blocks.Keys | Where-Object { $ids -cnotcontains $_ })
$extra = @($ids | Where-Object { -not $blocks.ContainsKey($_) })
$dupes = @($ids | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
Check ($missing.Count -eq 0) 'every input ID is present' ("missing: " + ($missing -join ', '))
Check ($extra.Count -eq 0) 'no unknown IDs' ("unknown: " + ($extra -join ', '))
Check ($dupes.Count -eq 0) 'no duplicate IDs' ("dupes: " + ($dupes -join ', '))

$badTopics = @(); $badSummary = @(); $badTitle = @(); $badSpeaker = @(); $noSpeaker = @()
$strip = '(?i)\b(professor|prof|dr|mr|mrs|ms|miss|sir|dame|justice|mbe|obe|cbe)\b\.?'
foreach ($e in $data) {
    $t = @($e.topics | ForEach-Object { $_ })
    if ($t.Count -lt 1 -or $t.Count -gt 3 -or @($t | Where-Object { $allowed -cnotcontains $_ }).Count -gt 0) { $badTopics += "$($e.id) [$($t -join ',')]" }
    if (-not $e.summary -or $e.summary.Length -gt 160) { $badSummary += "$($e.id) ($([int]$e.summary.Length))" }
    if (-not $e.title -or $e.title.Contains(' | ')) { $badTitle += $e.id }
    $sp = @($e.speakers | ForEach-Object { $_ })
    if ($sp.Count -eq 0) { $noSpeaker += $e.id }
    foreach ($s in $sp) {
        $core = ([regex]::Replace($s.name, $strip, '') -replace '\([^)]*\)', '').Trim()
        $surname = ($core -split '\s+')[-1]
        if (-not $surname -or -not $blocks.ContainsKey($e.id) -or $blocks[$e.id].IndexOf($surname, [StringComparison]::OrdinalIgnoreCase) -lt 0) { $badSpeaker += "$($e.id) '$($s.name)'" }
    }
}
Check ($badTopics.Count -eq 0) 'topics: 1-3 per video, all from content/topics.json' ($badTopics -join '; ')
Check ($badSummary.Count -eq 0) 'summary present and <= 160 characters' ($badSummary -join '; ')
Check ($badTitle.Count -eq 0) 'title present and has no " | " suffix' ($badTitle -join '; ')
Check ($badSpeaker.Count -eq 0) 'every speaker surname appears in that video''s source text' ($badSpeaker -join '; ')
"INFO  videos with no speaker: $($noSpeaker.Count) $($noSpeaker -join ', ')"
"INFO  topic usage: " + (($data | ForEach-Object { $_.topics } | Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', ')
if ($fail -gt 0) { exit 1 }
