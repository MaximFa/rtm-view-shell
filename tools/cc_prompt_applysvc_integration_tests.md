# CC Task — ApplyService integration tests (gate) + move inline checks out of Program.cs

> Session devops-2-0607. The iter-1 GATE (alongside Security re-ACK). Adds Testcontainers integration coverage
> for the apply path INCLUDING the 4 security fixes (deb6aa6), and closes the 19:05 deviation (inline unit checks
> in the production entrypoint). Push-independent (234 HALT). ONE web: commit set, NO push.

## 0. §0.6a integrity FIRST. 0b. §40 reads. Standard preamble.
## Sync (§42.6) slug devops-2-0607. Claims (file-mode):
  `tests/CcDashboard.Tests.Integration/ApplyService/` (NEW test dir), `src/CcDashboard.ApplyService/Program.cs` (minimal testability + inline-removal).
- S1 marker barrier; S2 coord_check_claims; S3 commit.lock; S4 cc_post_commit.sh.
## §37 NO push. §0.3 Python+fsync (Edit BANNED).

---

## PART 1 — make ApplyService testable + remove inline checks (Program.cs — PRESERVE all F-2/F-4/F-5/F-6 logic VERBATIM)
- Expose the host for WebApplicationFactory: add `public partial class Program { }` at the end (or InternalsVisibleTo "CcDashboard.Tests.Integration"). Minimal, no behaviour change.
- REMOVE the inline unit-check blocks (constant-time compare / path-traversal demos) from Program.cs — they move to PART 2 as real unit tests. Do NOT touch the security logic (startup token guard, 503/401, SHA-256 hash check/409, audit fail-closed/500/server-actor, metricIds/400).
- Make the audit writer/AuditDbContext OVERRIDABLE via DI so a test can inject a failing one (for the audit-fail→500 scenario). If already DI-registered, fine; otherwise register via interface.

## PART 2 — tests/CcDashboard.Tests.Integration/ApplyService/* (Testcontainers Postgres + WebApplicationFactory<Program>)
Fixture: spin Postgres (Testcontainers), apply db/schema.sql + migration 20260609_010 (metric_deploy_log) + seed RTSGrid_Metric baseline; build a temp PackageMigrationsDir with a fixture metric-migration .sql (idempotent INSERT ON CONFLICT into RTSGrid_Metric) + a manifest JSON {Migrations:[{FileName, Sha256}], Metrics:[{MetricId, MetricType:RT|History}]} with the CORRECT SHA-256; provision a valid ApplyService__Token env for the test host.

FUNCTIONAL scenarios:
1. apply-twice idempotent: 1st apply → success, ledgerRows populated, RTSGrid_Metric rows inserted; 2nd apply (same migrationRef) → success, ledgerRows EMPTY + warning, RTSGrid_Metric unchanged (count stable).
2. RT-only appliedRtMetricIds: manifest has 1 RT + 1 History MetricId; response.appliedRtMetricIds contains ONLY the RT id (History excluded).
3. bad migration (syntax error .sql) → 500; tx rolled back: metric_deploy_log has NO new rows, no audit row written, RTSGrid_Metric unchanged.

SECURITY scenarios (cover deb6aa6):
4. F-2 wrong token → 401 ; mis-provisioned (empty configured token) → 503 ; startup guard: a host built with empty/placeholder ApplyService__Token THROWS at startup (assert the InvalidOperationException / host fails to start).
5. F-5 audit-fail → 500: inject a failing AuditDbContext (broken conn / throwing wrapper) → apply returns 500 (no 200 without a persisted audit). On the SUCCESS path assert the audit row: UserName="ApplyService" (server principal), IpAddress set (RemoteIpAddress), UserId=null, TenantId=null, Details.clientAssertedTriggeredBy = the request value.
6. F-4 integrity: (a) tamper the migration file so its bytes ≠ manifest Sha256 → 409, NOT executed (RTSGrid_Metric unchanged); (b) manifest missing the hash for the file → 409 (fail-closed).
7. F-6: request.MetricIds contains an id NOT in manifest.Metrics → 400 (reject), nothing applied.

UNIT (moved from Program.cs): constant-time token compare (equal/!equal/length-diff) ; path-traversal rejection of migrationRef ("..", separators) → reject.

## Self-tests / run
- `dotnet build CcDashboard.sln` 0 err. Run `dotnet test tests/CcDashboard.Tests.Integration --filter ApplyService` IF Docker/Testcontainers available; else report "Testcontainers unavailable — tests authored, not executed" + assert they compile.
- grep: Program.cs still contains the 4 security markers (REPLACE_AT_DEPLOY guard, SHA256.HashData, RemoteIpAddress, metricIds 400) AFTER the inline-removal — prove no security regression.

## Commit — web: (one commit; both the Program.cs touch + tests are web)
pre-commit-check.sh→0 ; commit.lock ; `git add src/CcDashboard.ApplyService/Program.cs tests/CcDashboard.Tests.Integration` → `git commit -m "web: ApplyService integration tests (functional+security gate) + move inline checks to test project"` ; §0.6 verify ; cc_post_commit.sh ; HEAD re-sync. NO push.

## Report back
build ; test run result (executed vs Testcontainers-unavailable) ; per-scenario pass/authored (the 7 + unit) ; the no-security-regression grep (4 markers still in Program.cs) ; commit hash. NO push.
