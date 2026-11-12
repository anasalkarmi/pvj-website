param([int]$BatchSize = 25)

# Turns the caption parts saved by caption-receiver.ps1 (work/captions/part-N.json,
# each a JSON object { youtubeId: "caption text" }) into
#   work/captions/<youtubeId>.txt        raw captions, one file per video
#   work/transcripts/in-batch-K.txt      work packs for the people/agents who tidy them
# Only videos that do not yet have content/transcripts/<youtubeId>.txt are packed.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding($false)
$capDir = Join-Path (Join-Path $root 'work') 'captions'
$packDir = Join-Path (Join-Path $root 'work') 'transcripts'
$doneDir = Join-Path (Join-Path $root 'content') 'transcripts'
[void][IO.Directory]::CreateDirectory($packDir); [void][IO.Directory]::CreateDirectory($doneDir)

$n = 0
foreach ($part in Get-ChildItem $capDir -Filter 'part-*.json') {
    $obj = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($part.FullName, [Text.Encoding]::UTF8))
    foreach ($p in $obj.PSObject.Properties) {
        [IO.File]::WriteAllText((Join-Path $capDir ($p.Name + '.txt')), [string]$p.Value, $utf8); $n++
    }
}
"caption files written from parts: $n"

$videos = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path (Join-Path $root 'content') 'videos.json'), [Text.Encoding]::UTF8))
Get-ChildItem $packDir -Filter 'in-batch-*.txt' | Remove-Item -Force
$todo = @(); $noCaps = @()
foreach ($v in $videos) {
    if (Test-Path -LiteralPath (Join-Path $doneDir ($v.youtubeId + '.txt'))) { continue }
    if (-not (Test-Path -LiteralPath (Join-Path $capDir ($v.youtubeId + '.txt')))) { $noCaps += $v.youtubeId; continue }
    $todo += $v
}
$k = 0
for ($i = 0; $i -lt $todo.Count; $i += $BatchSize) {
    $k++
    $sb = New-Object Text.StringBuilder
    foreach ($v in $todo[$i..([Math]::Min($i + $BatchSize, $todo.Count) - 1)]) {
        $caps = ([IO.File]::ReadAllText((Join-Path $capDir ($v.youtubeId + '.txt')), [Text.Encoding]::UTF8) -replace '\s+', ' ').Trim()
        [void]$sb.AppendLine('##### VIDEO')
        [void]$sb.AppendLine('ID: ' + $v.youtubeId)
        [void]$sb.AppendLine('CONFERENCE: ' + $v.conference)
        [void]$sb.AppendLine('TITLE: ' + $v.title)
        [void]$sb.AppendLine('SPEAKERS: ' + ((@($v.speakers) | ForEach-Object { $_.name + ' (' + $_.role + ')' }) -join '; '))
        [void]$sb.AppendLine('DESCRIPTION: ' + ($v.description -replace '\s+', ' '))
        [void]$sb.AppendLine('RAW CAPTIONS (' + ($caps -split ' ').Count + ' words): ' + $caps)
        [void]$sb.AppendLine()
    }
    [IO.File]::WriteAllText((Join-Path $packDir "in-batch-$k.txt"), $sb.ToString(), $utf8)
    "batch ${k}: " + ([Math]::Min($i + $BatchSize, $todo.Count) - $i) + " videos, " + $sb.Length + " characters"
}
"videos to tidy: $($todo.Count) in $k batch(es); already done: $(@($videos).Count - $todo.Count - $noCaps.Count); no captions: $($noCaps.Count) $($noCaps -join ' ')"
