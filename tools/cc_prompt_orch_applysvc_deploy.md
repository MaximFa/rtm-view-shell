# CC Task — Orchestrator [1]: deploy CcDashboard.ApplyService (234 hot-reload critical path)

> Session devops-2-0607. Extend Apply-Server45Upgrade.ps1 to deploy the NEW CcDashboard.ApplyService
> (Kestrel Windows-service, 127.0.0.1 only) + provision the catalogue-owner DB role + wire the apply-endpoint
> token into BOTH ApplyService and Shell config. Coordinator §4 decisions (20:55Z) are baked in below.
> ONE commit-set (deploy: + db:), NO push (rides next barrier). Source/run NATIVE on Windows.

## 0. §0.6a integrity FIRST. 0b. §40 skill reads. Standard preamble.

## Multi-session sync (§42.6) — slug devops-2-0607
Claims (file-mode): `deploy/Apply-Server45Upgrade.ps1`, `db/setup/02_catowner_role.sql` (NEW).
- S1 marker barrier (`grep -q "FREEZE ACTIVE" .coord/push/request.md` → STOP). S2 coord_check_claims. S3 commit.lock /tmp/acquire_lock.py. S4 cc_post_commit.sh.
## §37 NO push. §0.3 Python+fsync, Edit BANNED. §35 Apply-Server45Upgrade.ps1 = UTF-8 BOM+CRLF; setup SQL = BOM-less.

## §4 DECISIONS (coordinator 20:55Z — bake in, do not re-litigate)
(a) Host = Windows-service "RTMApplyService" (Kestrel), **bind 127.0.0.1:{port} ONLY** (loopback, never 0.0.0.0; no firewall rule — DEPLOY-08).
(b) DB role = dedicated least-privilege **ccdashboard_catowner** (NOT superuser). GRANT INSERT on RTSGrid_Metric + metric_deploy_log + db_patch_history + audit.audit_logs (+ SELECT on RTSGrid_Metric, metric_deploy_log). Provision as postgres in a new phase.
(c) Token + catowner DB password = random (CSRNG) each deploy. CORRECTED by coordinator (verified a6f5572 via object store): MetricApplyHttpClient binds `MetricsApply:Token` as PLAINTEXT IOptions (no Unprotect). => do NOT Data-Protect (caller can't decrypt) and do NOT write secrets to appsettings (CODE-05/06 forbid plaintext secrets in config). RESOLUTION: inject ALL secrets as ENVIRONMENT VARIABLES on the service processes (ASP.NET Core EnvironmentVariables provider binds them to the existing plaintext IOptions, UNCHANGED caller, CODE-05/06-compliant). Non-secret config (BaseUrl/port/dirs) MAY stay in appsettings.
(d) Shell CALLER already exists (a6f5572: MetricApplyHttpClient reads MetricsApply:BaseUrl + MetricsApply:Token; RtmRelayService.InvokeCompileMetricsAsync; MetricDeployLedgerReader). NO Shell code — deploy only PROVISIONS the config keys.

---

# FILE A — db/setup/02_catowner_role.sql (NEW, BOM-less, run as postgres)
Idempotent. Password passed as a psql var (NEVER hardcoded):
```sql
-- run: psql -U postgres -d <db> -v catowner_pw='<generated>' -f 02_catowner_role.sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ccdashboard_catowner') THEN
    EXECUTE format('CREATE ROLE ccdashboard_catowner LOGIN PASSWORD %L', :'catowner_pw');
  ELSE
    EXECUTE format('ALTER ROLE ccdashboard_catowner WITH LOGIN PASSWORD %L', :'catowner_pw');
  END IF;
END $$;
GRANT USAGE ON SCHEMA public, audit TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public."RTSGrid_Metric"        TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.metric_deploy_log        TO ccdashboard_catowner;
GRANT INSERT, SELECT ON public.db_patch_history         TO ccdashboard_catowner;
GRANT INSERT        ON audit.audit_logs                 TO ccdashboard_catowner;
```
(Exact table identifiers/quoting verify vs db/schema.sql. RTSGrid_Metric is quoted PascalCase; metric_deploy_log/db_patch_history lowercase. NO blanket grants. Idempotent re-run safe.)

---

# FILE B — deploy/Apply-Server45Upgrade.ps1 (extend; keep all existing phases/behaviour)

## B1 — params
Add: `[string]$ApplyServicePublish=""`, `[int]$ApplyServicePort=5099`, `[string]$ApplySvcName="RTMApplyService"`,
`[string]$ShellAppSettingsPath=""` (path to deployed Shell appsettings to patch; default-derive from InstallRoot).
Document each in `.PARAMETER`.

## B2 — Phase 1 stop: also `Stop-ServiceAndExe $ApplySvcName` (helper already exists from E-018). Skip silently if service absent.

## B3 — NEW Phase (after migrations+functions, BEFORE service start) — provision + config wiring. Guard: only if $ApplyServicePublish non-empty.
1. Generate secrets (CSRNG): `$catownerPw` and `$applyToken` via [System.Security.Cryptography.RandomNumberGenerator] (NOT Get-Random). URL-safe base64, ≥32 bytes.
2. Provision role: run db/setup/02_catowner_role.sql as **postgres** (SuperUser), `-v catowner_pw=$catownerPw`, EAP=Continue + $LASTEXITCODE gate (E-015 pattern). Fail → abort (try/catch → Invoke-Rollback if -AutoRollback).
3. ApplyService config: NON-SECRET keys in appsettings.json (Kestrel/Urls = http://127.0.0.1:$ApplyServicePort; PackageMigrationsDir + ManifestPath). SECRETS via ENV VARS on the RTMApplyService process registry-Environment (NOT appsettings): the catalogue-owner connection password ($catownerPw) and ApplyService token ($applyToken) — e.g. `ConnectionStrings__CatalogueOwner` (full conn with password=$catownerPw) + `ApplyService__Token`. Set via the service's HKLM\\SYSTEM\\CurrentControlSet\\Services\\$ApplySvcName\\Environment REG_MULTI_SZ (or equivalent). Verify the ApplyService binds these via IConfiguration env provider.
4. SECRET AT-REST = ENV VARS (coordinator-confirmed, no inspection needed). a6f5572 caller binds plaintext IOptions -> the same token VALUE goes to BOTH services as ENV VARS, never to an appsettings file:
   - Shell service env: `MetricsApply__Token=$applyToken` (double-underscore = config `MetricsApply:Token`).
   - ApplyService env: `ApplyService__Token=$applyToken` + the catowner connection (step 3).
   Set per-service via registry Environment (REG_MULTI_SZ) so the secret lives in the service env, not on disk. EMIT note: 'DPAPI/Credential Manager = future hardening; env-var is the CODE-05-sanctioned v1 path; caller unchanged.'
5. Patch Shell appsettings ($ShellAppSettingsPath): set ONLY the NON-SECRET `MetricsApply:BaseUrl = http://127.0.0.1:$ApplyServicePort` (read-modify-write JSON, preserve all other keys — same care as appsettings-preserve hole#1 in 5a16226). The TOKEN is NOT written here — it is the Shell-service env var `MetricsApply__Token` from step 4 (no plaintext secret on disk).

## B4 — Phase 3 deploy: copy $ApplyServicePublish → the ApplyService install dir (alongside Shell/RTM dirs under InstallRoot).

## B5 — register service: if `Get-Service $ApplySvcName` absent → `New-Service -Name $ApplySvcName -BinaryPathName '"<installdir>\CcDashboard.ApplyService.exe>"' -StartupType Automatic -DisplayName "RTM Apply Service"`. Idempotent (skip if present; update binPath via sc.exe config if changed).

## B6 — Phase 6 start: `Start-Service $ApplySvcName`; verify Running (wait loop). Health: GET http://127.0.0.1:$ApplyServicePort/health if the service exposes one (optional).

## B7 — manifest (E-010a): add `ApplyServiceDeployed: $([bool]$ApplyServicePublish)` + `ApplyServicePort: $ApplyServicePort` to SERVER.md.

---

## Self-tests (no server)
- AST parse 0 errors. BOM ok on the PS1; setup SQL BOM-less.
- greps: 3 new params present; `Stop-ServiceAndExe $ApplySvcName`; role-provision invokes 02_catowner_role.sql as SuperUser with -v catowner_pw; RandomNumberGenerator (not Get-Random) for both secrets; same `$applyToken` injected as ENV VAR (MetricsApply__Token + ApplyService__Token) to BOTH services, NOT to any appsettings file; `New-Service`/`$ApplySvcName`; `Start-Service $ApplySvcName`; bind string is `127.0.0.1:` (never 0.0.0.0).
- setup SQL: idempotent role DO-block, the 4 INSERT grants, no blanket grant, identifiers match db/schema.sql.
- Shell-appsettings patch is read-modify-write (preserves other keys) — grep proof.

## Commit — TWO commits (§39.3)
COMMIT 1 db:  `git add db/setup/02_catowner_role.sql` → `git commit -m "db: ccdashboard_catowner least-privilege role for apply-service"`
COMMIT 2 deploy: `git add deploy/Apply-Server45Upgrade.ps1` → `git commit -m "deploy: orchestrator deploys CcDashboard.ApplyService (svc+catowner role+token wiring, 127.0.0.1)"`
pre-commit-check.sh → 0 ; commit.lock around both ; §0.6 verify ; cc_post_commit.sh per commit ; HEAD re-sync. NO push.

## Report back
files ; AST parse ; the grep proofs (params, Stop-ServiceAndExe, role-provision, CSRNG secrets, token-to-both, New-Service, Start, 127.0.0.1 bind, Shell-patch read-modify-write) ; **confirm secrets are ENV VARS (MetricsApply__Token / ApplyService__Token / catowner conn) on the service processes — NO secret in any appsettings file** ; setup-SQL idempotency/grant proof ; BOM ; 2 commit hashes. NO push.
