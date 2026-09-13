#Requires -Version 5.1
<#
  BOX LOCAL / adapter-aa19743
  WHERE IT RUNS : the LOCAL workstation (host name is a gate). NO server, NO database, NO deploy, NO service
                  touched. 234 is not addressed by a single command. C:\IceDash is not read or written.
  WHAT IT WRITES: a fresh clone of branch adapters at D:\Claude\Build\rtm_adapters_aa19743 , two publish
                  folders under D:\Claude\Build\adapter_publish_aa19743 and adapter_publish_parent , one zip
                  of the first publish, and its own report. Nothing else. The working repository is only READ
                  and no index-touching git command runs against it. The foreign worktree
                  D:\Claude\Projects\RTMView-adapters-wt is NOT touched - a branch checked out elsewhere is
                  someone else's working state, so this box clones instead of borrowing it.
  WHAT IT DOES  : builds the ADAPTER package - its own publish from branch adapters at aa19743, per the
                  coordinator decision called variant B - and then proves, with BOTH halves, that the fix
                  travels in it.

  THE POINT OF THE TWO PUBLISHES. Edit 2 adds log4net.config to the publish output of RTM.Twilio. Without
  that file the adapter starts, connects to Twilio and relays nothing: AsyncLogger.InitializeLog4Net throws
  on a missing file, and it is called in the TwilioAdapter constructor BEFORE RTMAdapter.connect, so the pipe
  connection never happens and the error goes to the logger that has just failed. Two days of silence on 234
  were this. The positive half - the packaged publish CONTAINS the file - was reported by the session that
  made the edit and never verified independently; the negative half - the publish of the PARENT commit does
  NOT contain it - was never run at all. Both are run here, because a publish that always contains the file
  would make the green half meaningless. The parent is fc51ae0.

  HASHES, both named before the run, and they differ for a benign reason. The blob in the commit is 740
  bytes, LF, sha256 D55DCCD4...41D0. The same file in a working copy after checkout is 761 bytes, CRLF,
  sha256 1D520F4D...13FA2, byte-identical to the reference recovered from server 140. The 21-byte difference
  is exactly 21 line endings: branch adapters carries no .gitattributes, v3 does, so the behaviour differs by
  branch. What must be in the publish is the CHECKOUT form, 761 bytes, 1D520F4D...13FA2. A mismatch is a STOP
  to the coordinator, not a shrug about normalisation.

  Every expectation is printed BEFORE the measured value. Every negative control is a GATE.
#>

$ErrorActionPreference = 'Continue'

$HOSTGATE   = 'LAPTOP-M4B1MKEC'
$REV        = 'aa1974351c72cbba24f76216c8d17d12102c508f'
$PARENT     = 'fc51ae076815092221e4c3f3534c6ee24b36d4e1'
$SRC        = 'D:\Claude\Projects\RTM View Shell'
$CLONE      = 'D:\Claude\Build\rtm_adapters_aa19743'
$PUBNEW     = 'D:\Claude\Build\adapter_publish_aa19743'
$PUBOLD     = 'D:\Claude\Build\adapter_publish_parent'
$OutDir     = 'D:\Claude\Build'
$SHA_CHECKOUT = '1D520F4D7AD2451BBBA4BD6CB7BAAFD0BE3C06AB407C8DD1ACD86D7FAE613FA2'
$SHA_BLOB     = 'D55DCCD41E3CD0E7AD1171BEC3A593589752939AFC95B9285404C2524FC541D0'
$BYTES_CHECKOUT = 761

$stamp   = Get-Date -Format yyyyMMdd_HHmmss
$outf    = Join-Path $OutDir ('LOCAL_' + $stamp + '_adapter-aa19743.txt')
$logNew  = Join-Path $OutDir ('LOCAL_' + $stamp + '_adapter-publish-new.txt')
$logOld  = Join-Path $OutDir ('LOCAL_' + $stamp + '_adapter-publish-parent.txt')
$zipPath = Join-Path $OutDir ('adapter_aa19743_' + $stamp + '.zip')

$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add('')
    [void]$ProbeLines.Add($(if ($pass) { 'VERDICT: PASS' } else { 'VERDICT: FAIL' }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT        : ' + $outf)
    Write-Host ('PUBLISH LOG   : ' + $logNew)
    Write-Host ('PARENT LOG    : ' + $logOld)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { 'ABSENT' } }
function Normalise-EntryName($name) { return ($name -replace [regex]::Escape([string][char]92), '/') }

Say '===== G1  machine and instrument first, each control a gate ====='
Say ('  host is {0} , expected {1}' -f $env:COMPUTERNAME, $HOSTGATE)
if ($env:COMPUTERNAME -ne $HOSTGATE) { Say '  *** wrong machine - stop'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
Say ('  this box   : {0}' -f $MyInvocation.MyCommand.Path)
Say ('  its sha256 : {0}   compare with the number named BEFORE the run' -f (Get-Sha256Of $MyInvocation.MyCommand.Path))
Say ('  NEGCTL sha of a missing path : {0}   expected ABSENT' -f (Get-Sha256Of 'C:\zzz-no-such-file.bin'))
if ((Get-Sha256Of 'C:\zzz-no-such-file.bin') -ne 'ABSENT') { Say '  *** cannot report absence - stop'; Fin $false }
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($null -eq $git) { Say '  *** git.exe NOT FOUND - stop'; Fin $false }
$dotnet = Get-Command dotnet.exe -ErrorAction SilentlyContinue
if ($null -eq $dotnet) { Say '  *** dotnet.exe NOT FOUND - stop'; Fin $false }
Say ('  git {0}' -f $git.Source)
Say ('  dotnet {0}   version {1}' -f $dotnet.Source, ("$(& $dotnet.Source --version 2>&1)").Trim())
$freeGb = (Get-PSDrive D).Free / 1GB
Say ('  free space on D: {0:N1} GB   expected at least 10' -f $freeGb)
if ($freeGb -lt 10) { Say '  *** less than 10 GB free - stop'; Fin $false }
Say ('  matcher POSCTL a backslash entry name normalises : {0}   expected True' -f ((Normalise-EntryName ('a' + [string][char]92 + 'b')) -eq 'a/b'))
Say ('  matcher NEGCTL an unrelated name does not match  : {0}   expected False' -f ((Normalise-EntryName 'a/c') -eq 'a/b'))
if ((Normalise-EntryName ('a' + [string][char]92 + 'b')) -ne 'a/b') { Say '  *** matcher broken - stop'; Fin $false }
foreach ($d in @($CLONE, $PUBNEW, $PUBOLD)) {
    Say ('  must NOT exist yet : {0}   exists {1}   expected False' -f $d, (Test-Path $d))
    if (Test-Path $d) { Say '  *** that directory already exists. Nothing here is reused or overwritten: rename it and re-run.'; Fin $false }
}
Say ('  foreign worktree left alone : {0}   (present {1}, and this box never touches it)' -f 'D:\Claude\Projects\RTMView-adapters-wt', (Test-Path 'D:\Claude\Projects\RTMView-adapters-wt'))
Say '  G1 PASS'
Say ''

Say '===== G2  the source repo names both revisions BEFORE anything is cloned ====='
foreach ($r in @($REV, $PARENT)) {
    $null = & $git.Source -C $SRC cat-file -e ($r + '^{commit}') 2>&1
    Say ('  cat-file -e {0} : exit {1}   expected 0' -f $r, $LASTEXITCODE)
    if ($LASTEXITCODE -ne 0) { Say '  *** revision missing in the source repo - stop'; Fin $false }
}
$null = & $git.Source -C $SRC cat-file -e 'deadbee0000000000000000000000000000dead^{commit}' 2>&1
Say ('  NEGCTL cat-file -e on an impossible sha : exit {0}   expected non-zero' -f $LASTEXITCODE)
if ($LASTEXITCODE -eq 0) { Say '  *** the existence predicate cannot say no - stop'; Fin $false }
Say ('  subject of aa19743 : {0}' -f ("$(& $git.Source -C $SRC log -1 --format=%h%x20%s $REV 2>&1)").Trim())
Say ('  subject of parent  : {0}' -f ("$(& $git.Source -C $SRC log -1 --format=%h%x20%s $PARENT 2>&1)").Trim())
Say '  G2 PASS'
Say ''

Say '===== 1  clone branch adapters and check out aa19743 ====='
$cloneOut = & $git.Source clone --no-hardlinks --quiet "$SRC" "$CLONE" 2>&1
Say ('  clone exit {0}   expected 0' -f $LASTEXITCODE)
foreach ($cl in @($cloneOut)) { Say ('      ' + "$cl") }
if (-not (Test-Path $CLONE)) { Say '  *** clone failed - stop'; Fin $false }
$coOut = & $git.Source -C $CLONE checkout --quiet --detach $REV 2>&1
Say ('  checkout exit {0}   expected 0' -f $LASTEXITCODE)
foreach ($cl in @($coOut)) { Say ('      ' + "$cl") }
$head = ("$(& $git.Source -C $CLONE rev-parse HEAD 2>&1)").Trim()
Say ('  HEAD expected {0}' -f $REV)
Say ('  HEAD actual   {0}' -f $head)
if ($head -ne $REV) { Say '  *** not the revision asked for - stop'; Fin $false }
$dirty = @(& $git.Source -C $CLONE status --porcelain 2>&1)
Say ('  working tree entries expected 0 : {0}' -f $dirty.Count)
if ($dirty.Count -ne 0) { foreach ($dl in $dirty) { Say ('      ' + "$dl") }; Say '  *** clone not clean - stop'; Fin $false }
Say ''

$fails = 0

Say '===== 2  the reference file in the clone, in its CHECKOUT form ====='
$cfg = Join-Path $CLONE 'RTM.Twilio\log4net.config'
Say ('  expected : {0} bytes , sha256 {1}' -f $BYTES_CHECKOUT, $SHA_CHECKOUT)
if (-not (Test-Path $cfg)) { Say '  ABSENT in the clone -> FAIL'; $fails++ }
else {
    $bytes = [IO.File]::ReadAllBytes($cfg)
    $crCount = @($bytes | Where-Object { $_ -eq 13 }).Count
    Say ('  actual   : {0} bytes , sha256 {1}' -f $bytes.Length, (Get-Sha256Of $cfg))
    Say ('  CR bytes {0}   BOM {1}   expected CR above zero, BOM False' -f $crCount, ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191))
    if ((Get-Sha256Of $cfg) -ne $SHA_CHECKOUT) { Say '  -> FAIL  not the reference bytes recovered from 140'; $fails++ }
    if ($bytes.Length -ne $BYTES_CHECKOUT) { Say '  -> FAIL  wrong length'; $fails++ }
}
Say ('  for the record, the blob in the commit is {0} bytes, LF, sha256 {1} - stated so nobody hunts corruption' -f 740, $SHA_BLOB)
Say ('  the PARENT commit tree carries log4net anywhere : {0}   expected 0' -f @(& $git.Source -C $CLONE ls-tree -r --name-only $PARENT | Where-Object { $_ -like '*log4net*' }).Count)
Say ''

Say '===== 3  PUBLISH of aa19743 - the adapter package itself ====='
$proj = Join-Path $CLONE 'RTM.Twilio\RTM.Twilio.csproj'
Say ('  project : {0}' -f $proj)
Say '  command : dotnet publish -c Release -r win-x64 --self-contained true , per FolderProfile.pubxml settings'
$t0 = Get-Date
$outNew = & $dotnet.Source publish $proj -c Release -r win-x64 --self-contained true -o $PUBNEW 2>&1
$rcNew = $LASTEXITCODE
[IO.File]::WriteAllLines($logNew, @($outNew | ForEach-Object { "$_" }), (New-Object System.Text.UTF8Encoding($false)))
Say ('  exit {0}   expected 0 ; elapsed {1:N0} s ; console lines {2}' -f $rcNew, ((Get-Date) - $t0).TotalSeconds, @($outNew).Count)
if ($rcNew -ne 0) {
    Say '  *** PUBLISH FAILED - last 25 lines:'
    foreach ($bl in (@($outNew) | Select-Object -Last 25)) { Say ('      ' + "$bl") }
    Fin $false
}
$filesNew = @(Get-ChildItem $PUBNEW -Recurse -File)
Say ('  files in the publish : {0}' -f $filesNew.Count)
Say ('  RTM.Twilio.exe present : {0}   expected True' -f (Test-Path (Join-Path $PUBNEW 'RTM.Twilio.exe')))
if (-not (Test-Path (Join-Path $PUBNEW 'RTM.Twilio.exe'))) { Say '  -> FAIL  no executable in the publish'; $fails++ }
$cfgNew = @($filesNew | Where-Object { $_.Name -eq 'log4net.config' })
Say ('  POSITIVE HALF  copies of log4net.config in the publish : {0}   expected at least 1' -f $cfgNew.Count)
if ($cfgNew.Count -lt 1) { Say '  -> FAIL  the fix did NOT travel into the publish'; $fails++ }
foreach ($c in $cfgNew) {
    $cb = [IO.File]::ReadAllBytes($c.FullName)
    Say ('      {0}' -f $c.FullName)
    Say ('      {0} bytes , CR {1} , sha256 {2}' -f $cb.Length, @($cb | Where-Object { $_ -eq 13 }).Count, (Get-Sha256Of $c.FullName))
    Say ('      equals the 140 reference {0} : {1}   expected True' -f $SHA_CHECKOUT, ((Get-Sha256Of $c.FullName) -eq $SHA_CHECKOUT))
    if ((Get-Sha256Of $c.FullName) -ne $SHA_CHECKOUT) { Say '      -> FAIL  STOP to the coordinator: the packaged config is not the reference'; $fails++ }
}
Say ''

Say '===== 4  NEGATIVE HALF - publish of the PARENT commit must NOT carry the file ====='
Say '  This half was never run before. Without it the green above proves nothing: a publish that always'
Say '  contains the file would look identical.'
$coOld = & $git.Source -C $CLONE checkout --quiet --detach $PARENT 2>&1
Say ('  checkout parent exit {0}   expected 0' -f $LASTEXITCODE)
$headOld = ("$(& $git.Source -C $CLONE rev-parse HEAD 2>&1)").Trim()
Say ('  HEAD now {0}   expected {1}' -f $headOld, $PARENT)
if ($headOld -ne $PARENT) { Say '  *** cannot reach the parent - the negative half is NOT MEASURED, and I say so rather than skipping it'; $fails++ }
else {
    $t1 = Get-Date
    $outOld = & $dotnet.Source publish (Join-Path $CLONE 'RTM.Twilio\RTM.Twilio.csproj') -c Release -r win-x64 --self-contained true -o $PUBOLD 2>&1
    $rcOld = $LASTEXITCODE
    [IO.File]::WriteAllLines($logOld, @($outOld | ForEach-Object { "$_" }), (New-Object System.Text.UTF8Encoding($false)))
    Say ('  exit {0}   expected 0 ; elapsed {1:N0} s' -f $rcOld, ((Get-Date) - $t1).TotalSeconds)
    if ($rcOld -ne 0) {
        Say '  *** the parent publish failed - the negative half is NOT MEASURED. Last 15 lines:'
        foreach ($bl in (@($outOld) | Select-Object -Last 15)) { Say ('      ' + "$bl") }
        $fails++
    } else {
        $cfgOld = @(Get-ChildItem $PUBOLD -Recurse -File | Where-Object { $_.Name -eq 'log4net.config' })
        Say ('  copies of log4net.config in the PARENT publish : {0}   expected 0' -f $cfgOld.Count)
        foreach ($c in $cfgOld) { Say ('      ' + $c.FullName) }
        if ($cfgOld.Count -ne 0) { Say '  -> FAIL  the file ships on the parent too, so the edit is not what puts it there'; $fails++ }
        Say ('  and the parent publish does have its executable : {0}   expected True - proves the publish itself worked' -f (Test-Path (Join-Path $PUBOLD 'RTM.Twilio.exe')))
        if (-not (Test-Path (Join-Path $PUBOLD 'RTM.Twilio.exe'))) { Say '  -> FAIL  an empty publish would make the zero above meaningless'; $fails++ }
    }
}
$null = & $git.Source -C $CLONE checkout --quiet --detach $REV 2>&1
Say ('  clone returned to {0} : {1}' -f $REV, ("$(& $git.Source -C $CLONE rev-parse HEAD 2>&1)").Trim())
Say ''

Say '===== 5  the adapter package as one artifact, with its own hash ====='
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $zipPath) { Say '  *** the zip name is taken - stop instead of overwriting'; Fin $false }
[System.IO.Compression.ZipFile]::CreateFromDirectory($PUBNEW, $zipPath)
Say ('  zip : {0}' -f $zipPath)
Say ('  {0:N1} MB , sha256 {1}' -f ((Get-Item $zipPath).Length/1MB), (Get-Sha256Of $zipPath))
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $names = @($zip.Entries | ForEach-Object { Normalise-EntryName $_.FullName })
    Say ('      entries {0}' -f $zip.Entries.Count)
    Say ('      NEGCTL entries equal to an impossible name : {0}   expected 0' -f @($names | Where-Object { $_ -eq 'ZzzNoSuch.config' }).Count)
    Say ('      POSCTL entries equal to RTM.Twilio.exe : {0}   expected 1' -f @($names | Where-Object { $_ -eq 'RTM.Twilio.exe' }).Count)
    if (@($names | Where-Object { $_ -eq 'RTM.Twilio.exe' }).Count -lt 1) { Say '      *** the matcher cannot find the executable - stop'; $zip.Dispose(); Fin $false }
    $hits = @($zip.Entries | Where-Object { (Normalise-EntryName $_.FullName) -eq 'log4net.config' })
    Say ('      log4net.config in the zip : {0}   expected at least 1' -f $hits.Count)
    if ($hits.Count -lt 1) { Say '      -> FAIL  the packaged artifact does not carry the fix'; $fails++ }
    foreach ($h in $hits) {
        $ms = New-Object System.IO.MemoryStream
        $es = $h.Open(); try { $es.CopyTo($ms) } finally { $es.Dispose() }
        $raw = $ms.ToArray(); $ms.Dispose()
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $zsha = ([BitConverter]::ToString($sha.ComputeHash($raw))) -replace '-', ''
        $sha.Dispose()
        Say ('      entry {0} : {1} bytes , sha256 {2}' -f $h.FullName, $raw.Length, $zsha)
        Say ('      equals the 140 reference : {0}   expected True' -f ($zsha -eq $SHA_CHECKOUT))
        if ($zsha -ne $SHA_CHECKOUT) { Say '      -> FAIL  STOP to the coordinator'; $fails++ }
    }
} finally { $zip.Dispose() }
Say ''

Say '===== SUMMARY ====='
Say ('  adapter revision : {0}   parent {1}' -f $REV, $PARENT)
Say ('  publish (new)    : {0}' -f $PUBNEW)
Say ('  publish (parent) : {0}   exists only to make the green half mean something' -f $PUBOLD)
Say ('  artifact         : {0}' -f $zipPath)
Say ('  artifact sha256  : {0}' -f (Get-Sha256Of $zipPath))
Say ('  failures         : {0}   anything above zero means DO NOT SEND THIS ANYWHERE' -f $fails)
Say '  STILL NOT PROVEN HERE: that the live C:\RTMView\RTM.Twilio\log4net.config on 234 matches the'
Say '  reference. That sha is an obligatory item of the next READING box on 234, by the condition the'
Say '  coordinator recorded in the backlog - not of this build.'
Say '  NOTHING WAS INSTALLED, SENT, RESTARTED OR DELETED. NO SERVER AND NO DATABASE WAS CONTACTED.'
Say '===== END-OF-RUN MARKER: ADAPTER-AA19743-COMPLETE ====='
Fin ($fails -eq 0)
