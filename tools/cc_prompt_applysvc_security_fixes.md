# CC Task — ApplyService SECURITY fixes F-2/F-5/F-4/F-6 (234 deploy-BLOCKING, FULL fix per operator)

> Session devops-2-0607. Closes the 4 Security findings on the hot-reload apply path (security-0609, 23:25/23:40).
> Operator chose FULL fix, NO compensating shortcuts. ALL FOUR must close + Security re-ACK before 234.
> Touches: src/CcDashboard.ApplyService/Program.cs (F-2/F-5/F-4/F-6) + deploy/Apply-Server45Upgrade.ps1 (F-4 ACL).
> TWO commits (web: + deploy:), NO push (234 on HALT; rides barrier after Security re-ACK).

## 0. §0.6a integrity FIRST. 0b. §40 reads. Standard preamble.
## Sync (§42.6) slug devops-2-0607. Claims (file-mode): `src/CcDashboard.ApplyService/Program.cs`, `deploy/Apply-Server45Upgrade.ps1`.
- S1 marker barrier; S2 coord_check_claims; S3 commit.lock /tmp/acquire_lock.py; S4 cc_post_commit.sh.
## §37 NO push. §0.3 Python+fsync (Edit BANNED). §35 PS1 = BOM+CRLF.

---

# FILE A — src/CcDashboard.ApplyService/Program.cs

## F-2 (HIGH) — token FAIL-CLOSED (currently fail-OPEN: `expectedToken ?? ""` + ConstantTimeEquals("","")=true lets empty/placeholder + "Bearer " bypass)
- STARTUP GUARD: read ApplyService:Token (env ApplyService__Token). If null / whitespace / equals a known placeholder
  ("REPLACE_AT_DEPLOY" or any shipped literal) → **throw at startup** (service does NOT start; log Fatal "ApplyService token unset/placeholder — refusing to start"). Fail-closed.
- PER-REQUEST: REMOVE the `?? ""` fallback. If the configured token is null/empty at request time → 503 (mis-provisioned), never ConstantTimeEquals against "". Only compare when a real token exists. Keep the constant-time compare for the non-empty case.

## F-5 (MED, deploy-blocking for a privileged op) — audit FAIL-CLOSED + REAL actor
- Audit MUST be blocking: write `System.MetricsDeployed` and AWAIT it; if the audit write throws → return **500** (do NOT return 200 without a persisted audit row). Order: catalogue+ledger tx commits first (idempotent ON CONFLICT), THEN audit (separate AuditDbContext per AUD-01); audit failure → 500. Retry is safe (idempotent re-apply). Add a code comment: committed-but-audit-failed surfaces as 500 + is idempotent-retryable (acceptable; AUD-01 keeps audit in its own context).
- REAL actor (stop trusting the client): the AUDIT actor = server-side identity = the token-authenticated caller principal (e.g. "ShellService" / the service identity), NOT the client-asserted `TriggeredBy`. Keep `TriggeredBy` only as a clearly-labelled client-asserted informational field in Details.
- FILL the audit columns from SERVER context: IpAddress = HttpContext.Connection.RemoteIpAddress (will be 127.0.0.1); UserId = null (no user principal at the service) — do NOT copy the spoofable client value into UserId; TenantId = the platform/cross-tenant context (RTSGrid_Metric is cross-tenant, WGT-01) — set the platform tenant id or null per AUD schema, NOT a client value. Details carries {migrationRef, sourceCommit, appliedMetricIds, clientAssertedTriggeredBy}.

## F-4 (HIGH) — migration INTEGRITY before verbatim execution (currently ExecuteSqlRawAsync of file bytes with NO integrity → tamper of PackageMigrationsDir = arbitrary SQL under catowner)
- BEFORE ExecuteSqlRawAsync: compute SHA-256 of the migration file bytes; compare to the **manifest-declared expected SHA-256** for that migrationRef.
- Mismatch OR manifest lacks an expected hash for the file → **REJECT (409, do NOT execute)**, log a security event. Fail-closed (no hash ⇒ no apply).
- ⚠ MANIFEST CONTRACT DEPENDENCY: this requires the manifest to carry a per-migration SHA-256. That is a METRICS contract addition (manifest schema) — coordinator relays to metrics-3. Implement the apply-side check now to REQUIRE the field (reject if absent); it stays fail-closed until the manifest ships hashes.
- (NTFS-ACL lock of PackageMigrationsDir = FILE B.)

## F-6 (MED) — validate metricIds vs manifest (currently advisory/warning-only)
- Validate request.metricIds ⊆ the manifest's MetricId set for that migrationRef. Any requested MetricId NOT in the manifest → **400 (reject)**, not a warning. (Manifest stays the source of truth for what the migration legitimately defines.)

---

# FILE B — deploy/Apply-Server45Upgrade.ps1

## F-4 ACL — lock PackageMigrationsDir + ManifestPath (defense for the integrity anchor)
- After deploying the package, set NTFS ACL on PackageMigrationsDir AND the manifest file: grant the RTMApplyService service account READ+EXECUTE only; REMOVE write for non-Administrators (icacls: remove Users/Authenticated Users write, keep SYSTEM/Administrators). So tampering requires admin (raises the bar; combined with F-4 hash-check = real integrity).
- Idempotent (re-run safe). Log the applied ACL. Emit in report.

---

## Self-tests (no server)
- ApplyService: `dotnet build CcDashboard.sln` 0 errors. greps:
  F-2 startup throw on empty/placeholder token (grep the guard + Fatal log); no `?? ""` before ConstantTimeEquals.
  F-5 audit awaited + 500-on-failure (grep try/throw→500); actor = server principal not TriggeredBy; RemoteIpAddress used; client value NOT written to UserId/TenantId.
  F-4 SHA256 compute + manifest-hash compare + reject-on-mismatch/absent before ExecuteSqlRawAsync.
  F-6 metricIds ⊄ manifest → 400.
- Orchestrator: AST 0 err; icacls on PackageMigrationsDir+manifest present; BOM ok.
- (Behavioural verification = the integration-tests prompt, separate — it will add: empty-token-no-start, audit-fail→500, hash-mismatch→409, unknown-metricId→400.)

## Commit — TWO commits (§39.3)
COMMIT 1 web:  `git add src/CcDashboard.ApplyService/Program.cs` → `git commit -m "web: ApplyService security fixes F-2 token fail-closed, F-5 audit fail-closed+real actor, F-4 migration hash-integrity, F-6 metricIds validation"`
COMMIT 2 deploy: `git add deploy/Apply-Server45Upgrade.ps1` → `git commit -m "deploy: NTFS-ACL lock PackageMigrationsDir+manifest (F-4 integrity anchor)"`
pre-commit-check.sh→0 ; commit.lock ; §0.6 verify ; cc_post_commit.sh per commit ; HEAD re-sync. NO push.

## Report back
build ; F-2/F-5/F-4/F-6 grep proofs (each finding's fix located) ; the SERVER-side audit actor/IP/tenant handling ;
F-4 manifest-hash-required confirmation + the metrics manifest-contract dependency restated ; icacls present ; BOM ; 2 hashes. NO push. (Then Security re-review ACK gates 234.)
