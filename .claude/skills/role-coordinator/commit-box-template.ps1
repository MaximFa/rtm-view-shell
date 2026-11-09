$ErrorActionPreference = 'Stop'
$D = 'D:\Claude\Projects\RTM View Shell\.coord\measure\commit-v4-asd-1109'
$ExpHead = '6b76608db428'
$ExpTree = '04f224ec0f4a7c216cdbd44b5e385cd9353339c7'
$ExpN = 27
$ExpDel = 0
Set-Location 'D:\Claude\Projects\RTM-design'
Start-Transcript -Path "$D\commit_transcript.txt" -Force | Out-Null
$ok = $false
$add = @(); $del = @(); $want = @{}
foreach ($l in (Get-Content "$D\add_paths.txt")) {
  if (-not $l.Trim()) { continue }
  $x = $l.Split(' ')
  if ($x[1] -eq 'DELETE') { $del += $x[0] } else { $add += $x[0]; $want[$x[0]] = $x[1] }
}
$all = @($add + $del)
try {
  "PATHS add $($add.Count) del $($del.Count) (expect $($ExpN - $ExpDel) / $ExpDel)"
  if ($all.Count -ne $ExpN -or $del.Count -ne $ExpDel) { throw 'path count' }
  $hd = git rev-parse --short=12 HEAD
  "HEAD $hd (expect $ExpHead)"
  if ($hd -ne $ExpHead) { throw 'head mismatch' }
  $idx = @(git diff --cached --name-only)
  "INDEX before: $($idx.Count) (expect 0)"
  if ($idx.Count -ne 0) { throw 'index not empty' }
  foreach ($p in $add) {
    $b = (git hash-object -- $p).Substring(0, 12)
    "BLOB $b want $($want[$p])  $p"
    if ($b -ne $want[$p]) { throw "blob mismatch $p" }
  }
  foreach ($p in $del) {
    $present = Test-Path -LiteralPath $p
    "DEL $p  on disk: $present (expect False)"
    if ($present) { throw "file to delete still on disk $p" }
  }
  git add -f -- $add
  if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
  if ($del.Count -gt 0) {
    git rm -q --cached -- $del
    if ($LASTEXITCODE -ne 0) { throw 'git rm failed' }
  }
  $st = @(git diff --cached --name-only)
  $sd = @(git diff --cached --name-only --diff-filter=D)
  "STAGED $($st.Count) (expect $ExpN), deleted $($sd.Count) (expect $ExpDel)"
  if ($st.Count -ne $ExpN -or $sd.Count -ne $ExpDel) { throw 'staged count' }
  git commit -q -F "$D\msg.txt"
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
  $new = git rev-parse --short=12 HEAD
  $tr = git rev-parse 'HEAD^{tree}'
  $ch = @(git diff-tree --no-commit-id --name-only -r HEAD)
  $sig = @(git log -1 --format=%B | git interpret-trailers --parse | Select-String -Pattern '^(Co-Authored-By|Claude-Session|Generated with):').Count
  "COMMIT $new"
  "TREE $tr"
  "EXPECT $ExpTree"
  "CHANGED $($ch.Count) (expect $ExpN)"
  "SIGNATURES $sig (expect 0)"
  if ($tr -ne $ExpTree) { throw 'tree mismatch' }
  if ($ch.Count -ne $ExpN) { throw 'changed count' }
  if ($sig -ne 0) { throw 'signature found' }
  $ok = $true
}
catch {
  "ERROR: $_"
  if (-not $ok -and ((git rev-parse --short=12 HEAD) -eq $ExpHead)) {
    git reset -q -- $all
    "INDEX after reset: $(@(git diff --cached --name-only).Count)"
  }
}
finally {
  "ITOG ok=$ok"
  Stop-Transcript | Out-Null
}
