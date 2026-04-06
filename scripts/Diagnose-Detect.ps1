param(
  [int]$Pct = 5,
  [int]$MinBytes = 1,
  [string]$Path = 'data/dat'
)

function fmt($n){
  if ($n -lt 1024) { return "$n B" }
  if ($n -lt 1MB) { return "{0:N1} KB" -f ($n/1KB) }
  if ($n -lt 1GB) { return "{0:N1} MB" -f ($n/1MB) }
  return "{0:N1} GB" -f ($n/1GB)
}

function check($file, $old, $new){
  $dec = $old - $new
  $pct = 0
  if ($old -gt 0) { $pct = [int]([math]::Floor($dec*100.0/([math]::Max($old,1)))) }
  $willFlag = ($dec -ge $MinBytes) -and ($pct -ge $Pct)
  Write-Output ("CHECK {0}  old={1} new={2} dec={3} pct={4} flag={5}" -f $file, (fmt $old), (fmt $new), (fmt $dec), $pct, $willFlag)
}

Set-Location ((git rev-parse --show-toplevel).Trim())

Write-Output "=== STAGED (index vs HEAD) ==="
git diff --name-only --cached -- $Path | ForEach-Object {
  $f = $_.Trim()
  if ($f -eq '') { return }
  $old = 0
  try { $old = git cat-file -s ("HEAD:" + $f) } catch {}
  $idxSha = ''
  try { $idxSha = (git ls-files -s -- $f) -split '\s+' | Select-Object -Index 1 } catch {}
  $new = 0
  if ($idxSha) { try { $new = git cat-file -s $idxSha } catch {} }
  check $f $old $new
}

Write-Output "=== UNSTAGED (work vs index) ==="
git diff --name-only -- $Path | ForEach-Object {
  $f = $_.Trim()
  if ($f -eq '') { return }
  $idxSha = ''
  try { $idxSha = (git ls-files -s -- $f) -split '\s+' | Select-Object -Index 1 } catch {}
  $idx = 0
  if ($idxSha) { try { $idx = git cat-file -s $idxSha } catch {} }
  $work = 0
  try { if (Test-Path $f) { $work = (Get-Item $f).Length } } catch {}
  check $f $idx $work
}
