# CC task — DEVOPS: Garnet migration (INC-001 (d) durable fix — PHASE 2 of 3)
> §4-PENDING (authored by devops-0619 -> route coordinator-0612). Owner devops-0619. Branch **v2-backend**. NO push (§37).
> GATED ON: Phase-1 PoC GREEN (docs/incidents/INC-001_garnet_poc_results.md) — DONE. FREE/MIT only.
> §4-PASS: coordinator-0622 2026-06-22T04:21:42Z — content SOUND + security-aware: branch v2-backend correct; auth(--auth Password --password)/bind127.0.0.1(DEPLOY-08)/persistence(--recover+checkpointdir DEPLOY-11)/sc-failure(da4cd7e parity)/conn-string-password-no-hardcode(CODE-05/06)/Memurai-retained-rollback/4-prior-Update-fixes+§35-BOM preserved. PRE-FLIGHT correctly hard-STOPs on git-reconcile. EXEC-GATED on: (1) coordinator/native-CC git-reconcile (relocate Garnet 8392e56 + uncommitted PoC artifacts v3->v2-backend); (2) security §4 Garnet new-component gate (satisfiable from PoC evidence). NO new §4 needed once both gates clear.
> Phase 3 (fleet rollout 234/45) is a SEPARATE prompt. This phase makes the deploy chain install Garnet instead of Memurai.

## PRE-FLIGHT (do FIRST — do not skip)
- §0.2/§0.5 integrity by OBJECT-STORE (mount-git is flaky; HEAD was last seen on branch `v3` with the 8392e56-on-v3 anomaly).
  CONFIRM you are on **v2-backend** and git is healthy BEFORE any work. If not, STOP and report — coordinator owns the v3/branch reconcile.
- The Phase-1 PoC artifacts are currently UNCOMMITTED / on v3: `docs/incidents/INC-001_garnet_poc_results.md`,
  `infra/garnet-poc/BackplaneTest/**`, and the §35-BOM-fixed `infra/garnet-poc/Verify-GarnetPoC.ps1`. They must land on
  v2-backend as part of this phase (docs:/deploy: commits). Pull/relocate them per the coordinator's reconcile, do not lose them.
- §0.3 Python+fsync for any .coord write. Binding PREAMBLE -> .coord/cc/devops.md. commit.lock around each commit. §35 BOM+CRLF
  on EVERY .ps1 (verify head -c3 = ef bb bf + CRLF). NO push.
- ⚠ SERIALIZE (coordinator directive): branch v2-backend has ONE shared WT — run ONLY AFTER curator's spine commit lands; acquire commit.lock when curator releases. Do NOT run concurrently with another v2-backend committer.

## PoC findings to bake in (from INC-001_garnet_poc_results.md — verified live)
1. Auth = `--auth Password --password <pwd>` (NOT `--auth <pwd>`).
2. Persistence recovery needs `--recover` on startup; pair with a checkpoint frequency.
3. Shell conn-string MUST carry the password: `ConnectionStrings:Redis = "localhost:6379,password=<pwd>"` (host:port unchanged; app code unaffected; AbortOnConnectFail already in non-Dev).
4. Pin a TESTED Garnet version: **1.1.10**, win-x64 **net8.0** build from `win-x64-based-readytorun.zip` (the box has .NET 8 runtime; do NOT ship the net10.0 build).
5. Garnet binds 127.0.0.1:6379 (DEPLOY-08); checkpointdir = RDB-equivalent (DEPLOY-11).

## THE WORK

### A. Packaging — tools/Build-ProdRelease.ps1
Replace Memurai-MSI packaging (L4/L10/L28-29/L54/L75-120/L292 area) with Garnet:
- Cache + bundle the pinned Garnet net8.0 binaries (from `win-x64-based-readytorun.zip`, net8.0 folder) under e.g. `tools\cache\garnet-1.1.10-win-x64-net8\` -> package into the release `Extras\Garnet\`.
- Service wrapper: bundle **NSSM** (public-domain, free) `nssm.exe`, OR use `Garnet.worker.exe` + `sc.exe` (note discussion #1081 error 1053 with sc on readytorun — prefer NSSM unless you verify worker+sc works). Pick ONE, pin it, document why.
- Keep the Memurai MSI path as an OPTIONAL fallback param (rollback), but default = Garnet. Update the .SYNOPSIS/params.

### B. Fresh install — deploy/Install-RTMView.ps1, [ 2/6 ] block (~L150-191)
Replace the Memurai MSI install + the `Harden Memurai` resilience block (da4cd7e, ~L184-196) with Garnet:
- Install Garnet binaries to e.g. `C:\Garnet\` (net8.0 build) + `redis-cli` equivalent if needed for health probes.
- Register Garnet as a Windows Service (NSSM or sc+worker per A) named e.g. `Garnet`:
  args `--bind 127.0.0.1 --port 6379 --auth Password --password <RedisPassword> --checkpointdir C:\Garnet\data --recover --checkpoint-freq 300` (verify exact flag names against GarnetServer -h).
- Apply the SAME resilience as da4cd7e but for the Garnet service: `Set-Service -StartupType Automatic` + `sc.exe failure "Garnet" reset= 86400 actions= restart/5000/restart/10000/restart/60000` + `failureflag 1`. Keep the `if ($svc)` BOTH-branches pattern.
- Keep `-RedisPassword` param semantics (now Garnet `--password`). Keep `-SkipMemurai`->rename/alias `-SkipRedis` (back-compat alias OK).

### C. In-place migration — deploy/Update-RTMView.ps1
Update currently does NOT touch the cache service. Add a Memurai->Garnet migration step (idempotent) for EXISTING boxes:
- If a `Memurai` service exists: stop it, set StartupType=Disabled (do NOT uninstall in this phase — rollback safety), and ensure the `Garnet` service is installed+running with the args in B. (Redis state is ephemeral/TTL — no data migration needed; it re-populates.)
- If `Garnet` already present: ensure Automatic + recovery + running. Idempotent.
- Preserve §35 BOM+CRLF + the existing 4 Update-RTMView fixes (DB-apply -MigrationList / pg_dump / @() StrictMode / preserve appsettings.json — do NOT regress).

### D. Shell connection-string password
The Shell needs the Garnet password (PoC finding 3). Secrets are NOT in appsettings (REPLACE_ME pattern). The deploy must inject
`ConnectionStrings:Redis = "127.0.0.1:6379,password=<pwd>"` via the operator-preserved config (appsettings.json is preserved by Update per e46e849) OR an env/credential mechanism (§CODE-05/06). Document the exact place the deploy sets it; do NOT hardcode a password in source.

### E. Harness fixes — RECONCILE against 2a63f57 (do NOT double-commit)
ALREADY COMMITTED on v2-backend in 2a63f57: `docs/incidents/INC-001_garnet_poc_results.md` + `infra/garnet-poc/BackplaneTest/**` + `infra/garnet-poc/Verify-GarnetPoC.ps1`. Do NOT re-commit these.
- FIRST `git show HEAD:infra/garnet-poc/Verify-GarnetPoC.ps1` — see which fixes are already in 2a63f57 (BOM, REDISCLI_AUTH, TTL `[int]`-on-array, 8/8 summary). Apply ONLY the ones still missing.
- `infra/garnet-poc/garnet-args.txt`: `--auth <password>` -> `--auth Password --password <password>`; add `--recover` (skip if already in 2a63f57).

### F. Rollback (document in deploy/ROLLBACK.md or a Garnet section)
Garnet fails -> re-enable Memurai service (Startup=Automatic, Start-Service Memurai), revert the Shell conn-string password. Memurai binaries are NOT removed in Phase 2, so rollback is service-swap only.

## VERIFY (object-store + build)
- All touched .ps1: head -c3 = ef bb bf, CRLF==lines, parse clean (native PS).
- Build-ProdRelease produces a package whose Extras\ has Garnet (net8.0) + the service wrapper, NO Memurai-MSI dependency by default.
- Install/Update reference the Garnet service with `--auth Password --password` + `--recover` + Automatic + sc failure.
- The 4 prior Update-RTMView fixes still present (grep). PoC artifacts committed on v2-backend.

## COMMIT (deploy:/docs:, NO push) under commit.lock
Suggested: `deploy: INC-001(d) Phase 2 — migrate deploy chain Memurai->Garnet (Install/Update/Build-ProdRelease, NSSM service + --auth Password + --recover + sc-failure resilience; conn-string password; harness auth/BOM fixes; PoC results) [devops]`
then §0.6 post-commit + §0.7 re-sync + sync.

## ACCEPTANCE (Phase 2)
Fresh Install registers a hardened Garnet Windows Service (Automatic + recovery, internal bind, auth, --recover persistence);
Update migrates an existing Memurai box to Garnet idempotently with Memurai retained-but-disabled for rollback; Build-ProdRelease
packages Garnet (no paid Memurai); Shell conn-string carries the Garnet password; PoC artifacts + harness fixes committed on
v2-backend; §35 BOM+CRLF intact; 4 prior Update fixes intact. NO push. (Actual server deploy = Phase 3.)

## SECURITY CONDITIONS (security-0620 APPROVE 2026-06-22 — MUST fold, gate at post-commit)
- COND-1 [runbook]: Memurai->Garnet swap RESETS Redis-resident security state — revoked-JTI list (AUTH-API-05) + rate-limit/lockout counters (BFP-02) start EMPTY -> a revoked-but-unexpired access token (<=15min) is honored again on fresh Garnet; in-progress lockouts reset. DO the swap in a maintenance/low-traffic window + DOCUMENT this in the runbook/ROLLBACK section; for a hard guarantee on a just-deactivated user, bump their SecurityStamp post-swap.
- COND-2 [post-commit verify]: landed Install/Update/Build-ProdRelease source the Garnet --password via preserved-config/param ONLY — NO literal password in any .ps1/source (the PoC's TestPwd123 must not leak into migration scripts). security re-reviews at post-commit.
- COND-3 [minor]: use `127.0.0.1:6379` everywhere (not `localhost`) to match `--bind 127.0.0.1` (localhost->::1 could miss the IPv4-only bind).

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: commit hashes, files, verification, NO push. Phase 3 (fleet) authored after operator confirm on Phase 2.
