<#
Install the local pre-commit hook by copying `scripts/pre-commit-hook` to `.git/hooks/pre-commit`.
Run from repository root in PowerShell: `.	ools\install-hooks.ps1` or `.	emplates\install-hooks.ps1` (this file)
#>
param(
  [string]$RepoRoot
)

if (-not $RepoRoot) {
  try { $RepoRoot = (& git rev-parse --show-toplevel).Trim() } catch { Write-Error 'Not in a git repository'; exit 2 }
}

$src = Join-Path $RepoRoot 'scripts/pre-commit-hook'
$dstDir = Join-Path $RepoRoot '.git/hooks'
$dst = Join-Path $dstDir 'pre-commit'

if (-not (Test-Path $src)) { Write-Error "Missing $src"; exit 2 }
if (-not (Test-Path $dstDir)) { Write-Error "Missing .git hooks directory at $dstDir"; exit 2 }

Copy-Item -Force -Path $src -Destination $dst
# Try to set executable bit on non-Windows environments
try { & chmod +x $dst 2>$null } catch {}

Write-Output "Installed pre-commit hook to $dst"
