> ⚠ SUPERSEDED 2026-07-02 by tools/cc_prompt_devops_local_prodparity_env.md (operator chose FULL prod-parity, not Garnet-first). The -GarnetNoAuth/-CacheOnly script change is folded into the full-env prompt. Do NOT run this one.

# CC TASK — Install Garnet as a LOCAL Windows SERVICE (prod-parity) — GARNET-FLAP INC-001d root fix

> Owner: role-devops. Branch: **v3** (only branch). status: DRAFT -> coordinator §4 -> operator runs (ADMIN host).
> ROOT of the flap (coordinator live-verified): Garnet was HAND-LAUNCHED in a foreground PowerShell session ->
> drops on any session hiccup -> /health/ready flaps 200<->503; and it means we are NOT validating the prod topology.
> FIX: install Garnet LOCALLY as a Windows SERVICE using the SAME prod tooling path (NSSM + StartupType=Automatic +
> sc.exe failure-recovery) that deploy/Install-RTMView.ps1 already uses — do NOT hand-roll a new service model.
> Local dev = BARE (no --auth; conn-string 'localhost:6379'); prod stays --auth password. SERVICE model identical.

## Mandatory reads
.claude/skills/role-devops/role-devops.md (§A + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10).
deploy/Install-RTMView.ps1 [2/6] Garnet branch (~L207-278) — the NSSM+recovery commands to REUSE. Reality wins.

## OPERATOR PREREQUISITES (confirm before running — flag coordinator if missing)
- GarnetServer.exe present locally (the Garnet 1.1.10 binaries the operator was hand-launching). Point -GarnetInstallDir at them, OR copy them into C:\Garnet.
- nssm.exe available locally (from a prior built package Extras\nssm, or on PATH). The script copies it from the package; for a local-only install it must exist.
- Run in an ADMIN PowerShell (service install needs elevation). §35: run the .ps1 with -ExecutionPolicy Bypass; Unblock-File if zip-sourced.

## STEP 0 — Integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3
```
BINDING PREAMBLE -> .coord/cc/devops.md (status open, directive ref).

## STEP 1 — Edit deploy/Install-RTMView.ps1 (Python+fsync, §0.3 — Edit tool BANNED). Two gated switches; PROD default UNCHANGED.
1. Add params (param block ~L46):
   - `[switch]$GarnetNoAuth`   # local dev: install Garnet WITHOUT --auth/--password (matches passwordless conn-string)
   - `[switch]$CacheOnly`      # install ONLY the Garnet cache service (skip DB/Shell/RTM steps)
2. In the Garnet [2/6] branch:
   - RedisPassword requirement: skip the "RedisPassword is REQUIRED" error when `$GarnetNoAuth` is set.
   - $garnetArgs: when `$GarnetNoAuth`, build args WITHOUT `--auth Password --password $RedisPassword`:
     `--bind 127.0.0.1 --port 6379 --checkpointdir "$checkpointDir" --recover --checkpoint-freq 300`
     (prod path — $GarnetNoAuth NOT set — keeps the existing `--auth Password --password $RedisPassword` args verbatim.)
   - Keep the NSSM install + AppDirectory + SERVICE_AUTO_START + DisplayName + the Set-Service Automatic + sc.exe failure-recovery block EXACTLY as-is (that IS the prod service model to reuse).
3. `$CacheOnly` wiring: when set — force the [2/6] Garnet step to run (bypass the `-not $InstallRTM` gate) and SKIP [3/6]-[6/6] (no DB/Shell/RTM). Set `$InstallShell=$false; $InstallRTM=$false` after mode-detect, and run the cache block unconditionally when `$CacheOnly`.

## STEP 2 — Build/lint the script (no host exec here)
```bash
pwsh -NoProfile -Command "$null = [System.Management.Automation.Language.Parser]::ParseFile('deploy/Install-RTMView.ps1',[ref]$null,[ref]$errs); if($errs){$errs|%{$_};exit 1}else{'PS parse OK'}" 2>/dev/null || echo "parse-check via operator if pwsh absent in sandbox"
```
(If pwsh unavailable in the sandbox, the operator confirms parse on the host run.)

## STEP 3 — OPERATOR runs (ADMIN), host-side — install Garnet as a bare local service
```
powershell -ExecutionPolicy Bypass -File deploy\Install-RTMView.ps1 -CacheOnly -GarnetNoAuth -GarnetInstallDir "C:\Garnet"
```
(Adjust -GarnetInstallDir to where GarnetServer.exe lives.)

## STEP 4 — ACCEPTANCE (operator captures; coordinator re-verifies live via Chrome)
- `Get-Service Garnet` -> Status Running, StartType Automatic.
- Resilience: `Stop-Process -Name GarnetServer -Force` (or stop the svc) -> within recovery window the service auto-restarts (sc.exe failure recovery). Confirm it comes back.
- Shell /health + /health/ready = **200 SUSTAINED** (no flap) — Garnet reachable at localhost:6379 (no password).
- Report: service name, `Get-Service Garnet` output, restart-resilience result, sustained health.

## STEP 5 — Commit the script change (v3, NO push) — pre-commit + commit.lock
```bash
bash tools/pre-commit-check.sh deploy/Install-RTMView.ps1   # exit 0
# commit.lock -> narrow add ONLY deploy/Install-RTMView.ps1 (NEVER D Installations/* nor the _DriftGateProbe.cs) ->
# git commit -m "deploy: Install-RTMView -GarnetNoAuth + -CacheOnly — local bare Garnet as a Windows service (prod-parity, GARNET-FLAP root fix) [devops]"
# -> journal -> release lock
```
BINDING POSTAMBLE -> .coord/cc/devops.md RESULT (commit hash, switches added, prod-default-unchanged, STEP4 acceptance from operator, status). **NO push** (§37). §0.7 re-sync deploy/Install-RTMView.ps1 from HEAD.

## DO NOT
- NO push. Touch ONLY deploy/Install-RTMView.ps1. Do NOT change the PROD (auth) Garnet path — $GarnetNoAuth/$CacheOnly are OPT-IN; default behaviour identical. Do NOT hand-roll a new service model — reuse the NSSM + sc.exe recovery block. Do NOT stage D Installations/* or _DriftGateProbe.cs. Do NOT commit to v2-backend.
