param([string]$Message = 'Publish site', [switch]$NoPush)

# Builds the site and publishes it: the contents of ./docs become the tip of the
# "gh-pages" branch on GitHub, which GitHub Pages serves.
# The source (content, tools, assets) lives on "main"; push that with normal git.
#   -NoPush : build and commit to the local gh-pages branch only
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$gitExe = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $gitExe) {
    $desktop = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'GitHubDesktop') -Directory -Filter 'app-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($desktop) { $gitExe = Join-Path $desktop.FullName 'resources\app\git\cmd\git.exe' }
}
if (-not $gitExe -or -not (Test-Path $gitExe)) { throw 'git was not found (install Git for Windows or GitHub Desktop).' }

# Run git and stop on failure.
function RunGit { & $script:gitExe @args; if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed ($LASTEXITCODE)" } }
# Run git as a yes/no question: returns the exit code, hides output, never throws.
function AskGit {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
    try { & $script:gitExe @args 2>$null | Out-Null } catch { }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    return $code
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build.ps1')
if ($LASTEXITCODE -ne 0) { throw 'build failed' }

# A second working copy of the same repository, checked out on gh-pages.
$pages = Join-Path (Join-Path $root 'work') 'gh-pages'
Set-Location $root
if (-not (Test-Path (Join-Path $pages '.git'))) {
    if (Test-Path $pages) { cmd /c rmdir /s /q "\\?\$pages" }
    RunGit worktree prune
    if ((AskGit show-ref --verify --quiet refs/heads/gh-pages) -eq 0) { RunGit worktree add $pages gh-pages }
    elseif ((AskGit ls-remote --exit-code --heads origin gh-pages) -eq 0) { RunGit fetch origin gh-pages; RunGit worktree add -B gh-pages $pages origin/gh-pages }
    else { RunGit worktree add --orphan -b gh-pages $pages }
}

# GitHub sometimes commits to gh-pages itself (the Pages settings rewrite the CNAME file),
# so start from what is published right now. Everything in this working copy is generated.
if (-not $NoPush -and (AskGit ls-remote --exit-code --heads origin gh-pages) -eq 0) {
    RunGit fetch -q origin gh-pages
    Set-Location $pages
    try { RunGit reset -q --hard origin/gh-pages } finally { Set-Location $root }
}

# Mirror docs -> the gh-pages working copy (robocopy copes with long paths; keep .git).
robocopy (Join-Path $root 'docs') $pages /MIR /XD .git /XF .git /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }

Set-Location $pages
try {
    RunGit add -A
    if ((AskGit diff --cached --quiet) -eq 0) { Write-Host 'Nothing changed - the published site is already up to date.' }
    else { RunGit commit -q -m $Message; Write-Host 'Committed the new build to gh-pages.' }
    if ($NoPush) { Write-Host 'Not pushed (-NoPush).' }
    else {
        RunGit push origin gh-pages
        Write-Host 'Published. GitHub Pages usually updates within a minute or two.'
    }
} finally { Set-Location $root }
