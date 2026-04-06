## note: to bypass this check, define env var SKIP_DETECT_SHRINK=1 before committing

param(
  [int]$Pct = 5,
  [long]$MinBytes = 1,
  [string]$Path = 'data/dat'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-Bytes([long]$n) {
  if ($n -lt 1024) { return "$n B" }
  if ($n -lt 1MB) { return "{0:N1} KB" -f ($n / 1KB) }
  if ($n -lt 1GB) { return "{0:N1} MB" -f ($n / 1MB) }
  return "{0:N1} GB" -f ($n / 1GB)
}

function Get-HeadSize([string]$filePath) {
  try {
    return [long](git cat-file -s ("HEAD:" + $filePath))
  } catch {
    return 0
  }
}

function Get-IndexSha([string]$filePath) {
  try {
    $entry = git ls-files -s -- $filePath
    if ([string]::IsNullOrWhiteSpace($entry)) { return '' }
    $parts = $entry -split '\s+'
    if ($parts.Length -lt 2) { return '' }
    return $parts[1]
  } catch {
    return ''
  }
}

function Get-BlobSize([string]$sha) {
  if ([string]::IsNullOrWhiteSpace($sha)) { return 0 }
  try {
    return [long](git cat-file -s $sha)
  } catch {
    return 0
  }
}

function Should-Flag([long]$oldSize, [long]$newSize) {
  $dec = $oldSize - $newSize
  if ($dec -lt $MinBytes) { return $false }
  if ($oldSize -le 0) { return $false }
  $pctDec = [int][math]::Floor(($dec * 100.0) / $oldSize)
  return $pctDec -ge $Pct
}

function Build-Line([string]$filePath, [long]$oldSize, [long]$newSize, [string]$area) {
  $dec = $oldSize - $newSize
  $pctDec = if ($oldSize -gt 0) { [int][math]::Floor(($dec * 100.0) / $oldSize) } else { 0 }
  return ("{0}: {1} -> {2}  (-{3}, -{4}%)  [{5}]" -f $filePath, (Format-Bytes $oldSize), (Format-Bytes $newSize), (Format-Bytes $dec), $pctDec, $area)
}

$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

if ($env:SKIP_DETECT_SHRINK -eq '1') {
  Write-Output 'SKIP_DETECT_SHRINK=1; skipping Detect-Shrink checks.'
  exit 0
}

$logFile = Join-Path $repoRoot 'scripts\detect_shrink.log'
try { Remove-Item -Force $logFile -ErrorAction SilentlyContinue } catch {}
Add-Content -Path $logFile -Value ("Detect-Shrink run: " + (Get-Date).ToString('s'))

$flagged = New-Object System.Collections.Generic.List[string]

git diff --name-only --cached -- $Path | ForEach-Object {
  $f = $_.Trim()
  if ([string]::IsNullOrWhiteSpace($f)) { return }

  $old = Get-HeadSize $f
  $new = Get-BlobSize (Get-IndexSha $f)

  if (Should-Flag $old $new) {
    $line = Build-Line $f $old $new 'STAGED(index vs HEAD)'
    $flagged.Add($line)
    Write-Output $line
    Add-Content -Path $logFile -Value $line
  }
}

git diff --name-only -- $Path | ForEach-Object {
  $f = $_.Trim()
  if ([string]::IsNullOrWhiteSpace($f)) { return }

  $idx = Get-BlobSize (Get-IndexSha $f)
  $work = if (Test-Path $f) { [long](Get-Item $f).Length } else { 0 }

  if (Should-Flag $idx $work) {
    $line = Build-Line $f $idx $work 'UNSTAGED(index vs work tree)'
    $flagged.Add($line)
    Write-Output $line
    Add-Content -Path $logFile -Value $line
  }
}

if ($flagged.Count -gt 0) { exit 1 } else { exit 0 }
