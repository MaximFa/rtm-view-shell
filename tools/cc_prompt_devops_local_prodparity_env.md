# CC TASK — Stand up the LOCAL validation env as FULL prod-parity (Garnet+Shell+RTM as services) — INC-001d / test-env norm

> Owner: role-devops. Branch: **v3** (only branch). status: DRAFT -> coordinator §4 -> operator runs (ADMIN host).
> Operator chose FULL prod-identity NOW (not Garnet-first): the local validation env must run ALL components as the
> SAME prod Windows services (NSSM, StartupType=Automatic + sc.exe failure-recovery) via deploy/Install-RTMView.ps1,
> BEFORE QA resumes — so QA validates the exact PROD topology.
> HYPOTHESIS for the GARNET-FLAP (root still OPEN — only /health=503 is coordinator-verified, NOT the cause):
> a foreground-PS Garnet launch is fragile. Service-ifying removes that variable; if it STILL flaps as a SERVICE,
> root-cause it (STEP 6). Local dev = BARE Garnet (no --auth; conn-string localhost:6379); prod = --auth password.

## Mandatory reads
.claude/skills/role-devops/role-devops.md (§A + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10).
deploy/Install-RTMView.ps1 (esp. [2/6] Garnet NSSM+recovery branch to REUSE) ; tools/Build-ProdRelease.ps1 (-Mode Full). Reality wins.

## OPERATOR PREREQUISITES / SECRETS (operator supplies at run — do NOT hardcode)
- rtmviewdb already exists locally WITH the prod-mirror seed -> run with **-SkipDB** to PRESERVE it (do NOT recreate/wipe). Migrations already reconciled (DB-INTAKE-01).
- DB app password (ccdashboard_user) for the Shell service conn-string -> operator passes -DBAppPassword.
- Garnet binaries (GarnetServer.exe) + nssm.exe present (from the -Mode Full package Extras\; the build in STEP 2 produces them).
- HTTPS cert for the Shell service (local self-signed acceptable) — call out if the service needs one.

## STEP 0 — Integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3
```
BINDING PREAMBLE -> .coord/cc/devops.md (status open, directive ref).

## STEP 1 — Edit deploy/Install-RTMView.ps1 (Python+fsync, §0.3). Two OPT-IN switches; PROD default UNCHANGED.
- Add params: `[switch]$GarnetNoAuth` (local: omit --auth/--password) and `[switch]$CacheOnly` (Garnet-only; not used in the FULL run but harmless).
- Garnet [2/6]: when `$GarnetNoAuth` — skip the "RedisPassword REQUIRED" error and build $garnetArgs WITHOUT `--auth Password --password` (`--bind 127.0.0.1 --port 6379 --checkpointdir "$checkpointDir" --recover --checkpoint-freq 300`). Prod path (switch off) = verbatim existing args.
- Keep the NSSM install + SERVICE_AUTO_START + Set-Service Automatic + sc.exe failure-recovery block EXACTLY as-is (the prod service model to reuse).
- `$CacheOnly`: run only [2/6], skip [3/6]-[6/6].

## STEP 2 — Build a FULL prod package from the CURRENT v3 (local validation build)
```
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Full -DBPassword <op>   # produces Installations\<ts>_Full.zip with Shell\ RTM\ Extras\Garnet Extras\nssm
```
Unzip the package to a staging dir for the installer (it reads Shell\/RTM\/Extras from ScriptDir).

## STEP 3 — Stop the HAND-RUN dev components (they are NOT services yet)
- Shell dev (dotnet/watch on http:5238 / https:5239): stop via Soma `POST /shell/stop` (or Stop-Process the CcDashboard.Web/dotnet-watch by path). Confirm 5238/5239 freed.
- RTM: if hand-run, stop it too. (Garnet foreground PS, if running, will be replaced by the service — stop it.)

## STEP 4 — Install ALL as prod services (ADMIN, host)
```
powershell -ExecutionPolicy Bypass -File <staging>\Install-RTMView.ps1 -Mode Full -GarnetNoAuth -SkipDB `
   -DBAppPassword <op> -ShellPort 5238 -RTMPort 8088   # COORDINATOR DECISION 2026-07-02: ShellPort 5238(http)/5239(https) = dev ports, so Soma shellHealthUrl(:5238) + Chrome /health verify stay unchanged; RTMPort prod-default 8088
```
- **-SkipDB** (preserve seeded rtmviewdb). -GarnetNoAuth (bare local Garnet).
- CALL OUT every local-vs-prod delta as encountered: ShellPort (prod default 5000 vs dev 5238/5239), cert, conn-string (rtmviewdb / localhost:6379 no password), appsettings.Production.json. These are CONFIG; the SERVICE model stays identical to prod.
- ⚠ Soma health probe: Soma's shellHealthUrl currently = :5238. If the Shell SERVICE runs on a different port, either install the Shell service on 5238 OR update Soma appsettings shellHealthUrl to the new port (+ operator Soma restart) so /ops/health + /health checks resolve. Flag the chosen port.

## STEP 5 — ACCEPTANCE (operator captures; coordinator re-verifies live via Chrome)
- `Get-Service Garnet, RTMViewShell, RTMService` -> all Running, StartType Automatic.
- Kill-resilience: stop each (Stop-Process / stop svc) -> auto-restarts within the sc.exe recovery window. Confirm.
- Shell `/health` + `/health/ready` = **200 SUSTAINED** (no flap) over a watch window.
- Report: which components WERE hand-run vs now-service, full `Get-Service` output, the port/config deltas used, sustained health.

## STEP 6 — If Garnet STILL flaps as a SERVICE (root still OPEN)
Root-cause: service restart count (`Get-Service`/Event Log `System`), Garnet's own log, sc.exe recovery loop, port 6379 contention, resource, auth mismatch (should be none w/ bare). Report findings -> coordinator + INC-001d ledger. Do NOT paper over a real Garnet defect (candidate showstopper for the Memurai replacement).

## STEP 7 — Commit the script change (v3, NO push) — pre-commit + commit.lock
```bash
bash tools/pre-commit-check.sh deploy/Install-RTMView.ps1   # exit 0
# commit.lock -> narrow add ONLY deploy/Install-RTMView.ps1 (NEVER D Installations/*, _DriftGateProbe.cs, or the built package zip) ->
# git commit -m "deploy: Install-RTMView -GarnetNoAuth + -CacheOnly — local bare Garnet + full prod-parity local env (INC-001d) [devops]"
# -> journal -> release lock
```
BINDING POSTAMBLE -> .coord/cc/devops.md RESULT (commit hash, switches, prod-default-unchanged, STEP5 acceptance from operator, deltas list, flap-status). **NO push** (§37). §0.7 re-sync deploy/Install-RTMView.ps1 from HEAD.

## DO NOT
- NO push. Code-touch ONLY deploy/Install-RTMView.ps1. Do NOT change the PROD (auth) Garnet path — switches are OPT-IN. Do NOT recreate/wipe rtmviewdb (use -SkipDB). Do NOT hand-roll a service model — reuse the installer's NSSM+recovery. Do NOT commit D Installations/*, _DriftGateProbe.cs, or the package zip. Do NOT commit to v2-backend. Do NOT claim the flap root is 'the PS launch' — it's a HYPOTHESIS; verify by sustained-200 on the service, root-cause if it recurs.
