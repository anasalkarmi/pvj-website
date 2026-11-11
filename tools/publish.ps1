param([string]$Message = 'Publish site')

# Builds the site and publishes it: the contents of ./docs become the tip of the
# "gh-pages" branch on GitHub, which GitHub Pages serves.
# The source (content, tools, assets) lives on "main"; push that with normal git.
# Keep this file plain ASCII (Windows PowerShell 5.1).

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) {
    $desktop = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'GitHubDesktop') -Directory -Filter 'app-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($desktop) { $git = Join-Path $desktop.FullName 'resources\app\git\cmd\git.exe' }
}
if (-not $git -or -not (Test-Path $git)) { throw 'git was not found (install Git for Windows or GitHub Desktop).' }
function Git { & $script:git @args; if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed ($LASTEXITCODE)" } }

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build.ps1')
if ($LASTEXITCODE -ne 0) { throw 'build failed' }

# A second working copy of the same repository, checked out on gh-pages.
$pages = Join-Path (Join-Path $root 'work') 'gh-pages'
Set-Location $root
if (-not (Test-Path (Join-Path $pages '.git'))) {
    if (Test-Path $pages) { cmd /c rmdir /s /q "\\?\$pages" }
    & $git show-ref --verify --quiet refs/heads/gh-pages
    if ($LASTEXITCODE -eq 0) { Git worktree add $pages gh-pages }
    else {
        & $git ls-remote --exit-code --heads origin gh-pages *> $null
        if ($LASTEXITCODE -eq 0) { Git fetch origin gh-pages; Git worktree add -B gh-pages $pages origin/gh-pages }
        else { Git worktree add --orphan -b gh-pages $pages }
    }
}

# Mirror docs -> the gh-pages working copy (robocopy copes with long paths; keep .git).
robocopy (Join-Path $root 'docs') $pages /MIR /XD .git /XF .git /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }

Set-Location $pages
Git add -A
& $git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host 'Nothing changed - the published site is already up to date.' }
else {
    Git commit -q -m $Message
    Write-Host 'Committed the new build to gh-pages.'
}
Git push origin gh-pages
Set-Location $root
Write-Host 'Published. GitHub Pages usually updates within a minute or two.'
