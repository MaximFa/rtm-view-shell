# CC TASK — Deploy-hardening bundle: 6 source fixes (canonical 234 package) — §4-gated

> Owner: role-devops. Branch: **v3** (only branch). status: DRAFT -> coordinator §4 -> operator runs.
> All 6 surfaced host-verified during the local prod-parity stand-up. ONE §4 -> ONE rebuild -> the canonical 234 pkg.
> ⚠ CROSS-CLAIM: fix 5 touches src/CcDashboard.Web/appsettings.json (web territory) — coordinator authorized under ЧП single-thread.
> NO push (ships with the Reports v1 barrier). §0.3 Python+fsync (Edit BANNED). Narrow-add ONLY the exact files. commit.lock.

## Mandatory reads
.claude/skills/role-devops/role-devops.md (§A+§C) ; session-coord (§1/§10) ; testing/prodparity_env_runbook.md.
RTM/RTM/appsettings.json Kestrel section (reference pattern). Reality wins.

## STEP 0 — Integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD   # MUST be v3
```
BINDING PREAMBLE -> .coord/cc/devops.md (status open).

## FIX 1 — tools/Build-ProdRelease.ps1 : native git/dotnet stderr under -Stop halts the build
Under `$ErrorActionPreference='Stop'` (L68) + PS5.1, a native cmd writing to stderr (git safecrlf warning) becomes a TERMINATING NativeCommandError -> build halts at [0/4] (L210 `& git diff`).
- Add a helper near the top (after L68):
```powershell
function Invoke-Native([scriptblock]$Sb){ $p=$ErrorActionPreference; $ErrorActionPreference='Continue'; try { & $Sb } finally { $ErrorActionPreference=$p } }
```
- Wrap EVERY native `& git ...` / `& dotnet ...` call (audit whole file — at least L129, L210, L213, L217, L228, L247) so stderr does not throw, e.g. `$modified = Invoke-Native { git diff --name-only HEAD 2>$null }`. Preserve each call's return capture.
- Goal: build must NOT depend on a machine-local `git config core.safecrlf false`; a fresh host with default safecrlf must build clean.

## FIX 2 — deploy/Install-RTMView.ps1 : $ScriptDir used before set (StrictMode halt)
The auto-detect Mode block (~L84-90) reads `$ScriptDir` but it's assigned at L95 (AFTER). Under `Set-StrictMode -Version Latest` (L81) -> throws `$ScriptDir cannot be retrieved because it has not been set`.
- MOVE `$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path` (L95) to IMMEDIATELY AFTER `Set-StrictMode -Version Latest` (L81), before the auto-detect block. Remove the old L95 line.

## FIX 3 — Garnet args (BOTH scripts, BOTH auth paths) : Garnet 1.1.10 crashes on bad args
Host-verified: `--recover` with no value -> 'bad format'; `--checkpoint-freq 300` -> 'unknown option' -> Garnet exits every start (the REAL flap root, not the PS-launch hypothesis). CONFIRMED WORKING: `--bind 127.0.0.1 --port 6379 --checkpointdir C:\Garnet\data --recover true`.
- deploy/Install-RTMView.ps1 L253 (bare/GarnetNoAuth) and L256 (prod --auth): `--recover` -> `--recover true`; DROP `--checkpoint-freq 300`.
- deploy/Update-RTMView.ps1 L354 (prod --auth) and any bare path: same fix.
- (Optional persistence for prod: if a periodic-checkpoint is needed, verify the correct Garnet 1.1.10 flag via `GarnetServer.exe --help`; for validation in-memory is fine — do NOT reintroduce an unknown option.)

## FIX 4 — deploy/Install-RTMView.ps1 : Shell PROD conn-string never injected (28P01)
-DBAppPassword is used ONLY in the DB-restore block (L359) which `-SkipDB` skips -> deployed Shell reads committed `Password=REPLACE_ME` (appsettings.json L7) -> Npgsql 28P01, service crashes.
- After the Shell files are deployed, and INDEPENDENT of `-SkipDB`, write ConnectionStrings:Default into the DEPLOYED **`C:\RTMView\Shell\appsettings.json`** (there is NO appsettings.Production.json — do NOT create/write one): `Host=localhost;Port=5432;Database=rtmviewdb;Username=ccdashboard_user;Password=<-DBAppPassword>;SSL Mode=Prefer`.
- Implement via a JSON read-modify-write in PS (ConvertFrom-Json/ConvertTo-Json or a targeted string replace of `Password=REPLACE_ME`). §25 CODE-05 note: env `ConnectionStrings__Default` via nssm AppEnvironmentExtra is the more-secure alt; the deployed appsettings.json (server-local, NOT committed) write is what the operator locked — implement that, keep the committed source placeholder REPLACE_ME.

## FIX 5 — Kestrel HTTPS via config (per-server FQDN/port/cert) — appsettings.json + Install
Operator: NO hardcoded values in committed source; FQDN+port+cert Subject are PER-INSTALL inputs written to config. Program.cs = NO CHANGE (CreateBuilder binds Kestrel + loads Store certs natively). Local validation uses http://localhost:5238 + https://localhost:5239 (ports UNCHANGED).
1. src/CcDashboard.Web/appsettings.json (COMMITTED) — add top-level Kestrel with PLACEHOLDERS only (no real domain/port/subject, no password):
```json
"Kestrel": { "Endpoints": {
  "Http":  { "Url": "http://REPLACE_FQDN:REPLACE_HTTP_PORT" },
  "Https": { "Url": "https://REPLACE_FQDN:REPLACE_HTTPS_PORT",
             "Certificate": { "Subject": "REPLACE_CERT_SUBJECT", "Store": "My", "Location": "LocalMachine", "AllowInvalid": "true" } }
} }
```
2. src/CcDashboard.Web/Program.cs — NO CHANGE.
3. deploy/Install-RTMView.ps1 —
   - DROP `--urls=http://localhost:$ShellPort` from the Shell `sc.exe create ... binPath=` (L374); Kestrel config now drives the listen URLs.
   - Add per-server params: `-Fqdn`, `-CertSubject` (Read-Host prompt when omitted — install is interactive; §35 Read-Host ban was BUILD-only, install prompting is OK). Keep `-ShellPort` as HTTP port and add `-ShellHttpsPort`. Defaults for LOCAL validation: `-Fqdn localhost -ShellPort 5238 -ShellHttpsPort 5239` (ports unchanged).
   - Write into the DEPLOYED C:\RTMView\Shell\appsettings.json (same JSON write as fix 4): Kestrel:Endpoints:Http:Url = `http://<Fqdn>:<ShellPort>`, Https:Url = `https://<Fqdn>:<ShellHttpsPort>`, Https:Certificate:Subject = `<CertSubject>` (Store My / LocalMachine / AllowInvalid true stay).
   - NOTE (flag, do not block): the install host must have the cert (Subject) in LocalMachine\My and resolve <Fqdn> to itself; AllowInvalid=true tolerates chain issues. For local: a localhost cert + Fqdn=localhost.

## FIX 6 — deploy/Update-RTMView.ps1 : audit for the same patterns
- Garnet args (L354) fixed in FIX 3. 
- git-stderr: L169-172 already saves/restores EAP around a native call — extend the same guard to ANY other native `& git`/`& dotnet` under -Stop if present.
- Conn-string + Kestrel: Update-RTMView preserves appsettings.json across updates (L247) — ensure an UPDATE does NOT clobber the operator's per-server Kestrel/conn-string in the deployed appsettings.json (preserve-list already includes appsettings.json; confirm). If Update writes any `--urls`, drop it to match Install.

## STEP 7 — Lint (best-effort in sandbox; operator confirms on host)
```bash
for f in tools/Build-ProdRelease.ps1 deploy/Install-RTMView.ps1 deploy/Update-RTMView.ps1; do echo "== $f =="; done
python3 -c "import json; json.load(open('src/CcDashboard.Web/appsettings.json')); print('appsettings.json valid JSON')"
```
(PS parse validated on the host run; sandbox has no pwsh 5.1.)

## STEP 8 — Commit (v3, NO push) — pre-commit + commit.lock
```bash
bash tools/pre-commit-check.sh tools/Build-ProdRelease.ps1 deploy/Install-RTMView.ps1 deploy/Update-RTMView.ps1 src/CcDashboard.Web/appsettings.json   # exit 0
# commit.lock -> narrow add ONLY those 4 files (NEVER D Installations/*, _DriftGateProbe.cs, package zips) ->
# git commit -m "deploy: 6-fix bundle — Build git-stderr guard, Install $ScriptDir order, Garnet --recover true/drop checkpoint-freq, Shell conn-string injection, Kestrel HTTPS per-server config [devops]"
# -> journal -> release lock
```
BINDING POSTAMBLE -> .coord/cc/devops.md RESULT (commit hash, per-fix summary, appsettings JSON valid, prod-defaults intact). **NO push** (§37). §0.7 re-sync all 4 files from HEAD.

## DO NOT
- NO push. Touch ONLY the 4 files. Do NOT hardcode any real FQDN/port/cert-subject/password in COMMITTED source (placeholders only). Do NOT create appsettings.Production.json. Do NOT change Program.cs. Do NOT reintroduce --checkpoint-freq. Do NOT stage D Installations/*, _DriftGateProbe.cs, or package zips. Do NOT commit to v2-backend.
