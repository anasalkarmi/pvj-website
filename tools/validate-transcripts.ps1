param([int]$Batch = 0)

# Checks the tidied transcripts in content/transcripts against the raw captions.
#   -Batch K : only the videos listed in work/transcripts/in-batch-K.txt (0 = every video with captions)
# Prints one FAIL line per problem and a summary. Exit code 1 if anything fails.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$root = Split-Path -Parent $PSScriptRoot
$capDir = Join-Path (Join-Path $root 'work') 'captions'
$packDir = Join-Path (Join-Path $root 'work') 'transcripts'
$doneDir = Join-Path (Join-Path $root 'content') 'transcripts'
$enc = [Text.Encoding]::UTF8
$videos = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path (Join-Path $root 'content') 'videos.json'), $enc))
$byId = @{}; foreach ($v in $videos) { $byId[$v.youtubeId] = $v }

if ($Batch -gt 0) {
    $ids = @([regex]::Matches([IO.File]::ReadAllText((Join-Path $packDir "in-batch-$Batch.txt"), $enc), '(?m)^ID: (\S+)') | ForEach-Object { $_.Groups[1].Value })
} else {
    $ids = @($videos | Where-Object { Test-Path -LiteralPath (Join-Path $capDir ($_.youtubeId + '.txt')) } | ForEach-Object { $_.youtubeId })
}
function Tokens([string]$s) { return @([regex]::Matches($s.ToLowerInvariant(), "[a-z0-9]+") | ForEach-Object { $_.Value }) }

$fail = 0; $ok = 0; $ratios = @()
foreach ($id in $ids) {
    $problems = @()
    $file = Join-Path $doneDir ($id + '.txt')
    if (-not (Test-Path -LiteralPath $file)) { "FAIL  $id  file missing: content/transcripts/$id.txt"; $fail++; continue }
    $t = [IO.File]::ReadAllText($file, $enc).Replace("`r", '')
    $m = [regex]::Match($t, '(?s)^\s*KEY POINTS[ \t]*\n(.*?)\nTRANSCRIPT[ \t]*\n(.*)$')
    if (-not $m.Success) { "FAIL  $id  wrong layout (needs KEY POINTS then TRANSCRIPT)"; $fail++; continue }
    $points = @($m.Groups[1].Value -split "\n" | Where-Object { $_.Trim() })
    $text = $m.Groups[2].Value.Trim()
    if ($points.Count -ne 0 -and ($points.Count -lt 2 -or $points.Count -gt 3)) { $problems += "has $($points.Count) key points (need 3; 2 or none only for clips with too little content)" }
    foreach ($p in $points) {
        if ($p -notmatch '^- \S') { $problems += "key point not in '- text' form: $p" }
        elseif ($p.Length -gt 172) { $problems += "key point over 170 characters ($($p.Length - 2))" }
    }
    $raw = [IO.File]::ReadAllText((Join-Path $capDir ($id + '.txt')), $enc)
    # Two bracketed marks are allowed in a transcript: [unclear] where a word could not be made out,
    # and the closing note for a recording whose captions become unintelligible part-way through.
    $cutNote = '[The rest of this recording could not be transcribed clearly.]'
    $isCut = $text.Contains($cutNote)
    $plain = $text.Replace($cutNote, '').Replace('[unclear]', '')
    $rawTok = Tokens $raw; $txtTok = Tokens $plain
    if ($rawTok.Count -gt 0) {
        $ratio = [Math]::Round($txtTok.Count / $rawTok.Count, 2); if (-not $isCut) { $ratios += $ratio }
        if ((-not $isCut -and $ratio -lt 0.72) -or $ratio -gt 1.08) { $problems += "transcript length is $ratio of the captions (allowed 0.72 to 1.08): content was dropped or added" }
    }
    # words that appear in neither the captions nor the video's own title/description/speaker details
    $known = @{}
    foreach ($w in $rawTok) { $known[$w] = 1 }
    $v = $byId[$id]
    $context = $v.title + ' ' + $v.description + ' ' + ((@($v.speakers) | ForEach-Object { $_.name + ' ' + $_.role }) -join ' ')
    foreach ($w in (Tokens $context)) { $known[$w] = 1 }
    $new = @($txtTok | Where-Object { -not $known.ContainsKey($_) } | Select-Object -Unique)
    $share = 0; if ($txtTok.Count -gt 0) { $share = [Math]::Round(@($txtTok | Where-Object { -not $known.ContainsKey($_) }).Count / $txtTok.Count, 3) }
    if ($share -gt 0.06) { $problems += "$([Math]::Round($share * 100, 1))% of the words are in neither the captions nor the description (limit 6%): " + (($new | Select-Object -First 14) -join ', ') }
    if ($text -match '(?m)^\s*-\s') { $problems += 'transcript contains list lines' }
    if ($plain -match '\[|\]|\(inaudible|\(unclear') { $problems += 'transcript contains bracketed editor notes other than [unclear]' }
    foreach ($p in $points) { if ($p -match '\[unclear\]') { $problems += 'a key point contains [unclear]' } }
    if ($problems.Count -gt 0) { $fail++; foreach ($p in $problems) { "FAIL  $id  $p" } } else { $ok++ }
}
$avg = 0; if ($ratios.Count -gt 0) { $avg = [Math]::Round(($ratios | Measure-Object -Average).Average, 2) }
"checked $($ids.Count) videos: $ok pass, $fail with problems; average length ratio $avg"
if ($fail -gt 0) { exit 1 }
