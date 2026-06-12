# Security Review — Hot-Reload Metrics Feature

**Reviewer:** RTM Security (security-0609, standing gate-keeper, Cowork-A)
**Date:** 2026-06-09
**Changeset:** 9cc8a66 (RTM compile) · a6f5572 (Shell deploy-tab) · cfa2925+f098cb7 (ApplyService+ledger) · 160259a (NGC fix) · e17d898 (catowner role) · 9db8ffd (orchestrator deploy)
**Scope:** Roslyn runtime-compile, ApplyService write-path, inter-service token, Deploy AuthZ, audit, tenant-scope, SignalR trigger + §25 PR checklist.
**Status:** This review GATES the Server-234 deploy (push-barrier / rebuild / 234). HALT held until ACK or required-fixes closed.

---

## OVERALL GATE: **PASS-WITH-REQUIRED-FIXES**

The net-new apply/trigger machinery is well-built (CSRNG secrets, registry-env storage, 127.0.0.1-only, const-time compare, parameterised ledger, least-privilege catowner, two-level Superadmin authZ). It is **not** clean enough to deploy as-is: one trivial auth fail-open (F-2), an unauthenticated RTM hub (F-3), and a fail-open audit (F-5) are deploy-blocking. The pre-existing Roslyn compile path (F-1) is a Critical RCE-by-design that this feature now exposes on-demand; it needs expression validation as a required fast-follow, with documented compensating controls accepted for 234.

---

## Findings by severity

### F-1 — Metric expression → arbitrary C# RCE in RTM process  **[CRITICAL — pre-existing, newly exposed]**
`Engine.cs` `CompileAndSetMetricFunction` / `CompileAndSetMetricInteractionsFunction` / `CompileAndSetUserMetricFunction`: the metric's `Parameter` and `Format` (from `RTSGrid_Metric`) are string-interpolated **verbatim** into C# source, compiled against the **full** `TRUSTED_PLATFORM_ASSEMBLIES` (entire BCL — `System.Diagnostics.Process`, `System.IO`, `System.Net`), `Assembly.Load`-ed and executed in-process. There is **no whitelist, no AST/expression validation, no sandbox** (and .NET 8 has no CAS sandbox). `TransformQuery` only word-boundary-prefixes known property names with `i.` — it does not constrain the grammar. A `Parameter` such as `true).ToList(); System.Diagnostics.Process.Start(...); return Bag.Where(i=>true` breaks out of the lambda.
**Net effect:** whoever can INSERT a row into `RTSGrid_Metric` gets code execution as the RTM service account. `Function` is safe (keyed into a hard-coded `MetricFunctionList`); the injection vectors are **`Parameter` and `Format`**.
**Why the feature matters:** previously metrics compiled only at RTM startup from a DBA-curated table. Hot-reload makes INSERT + compile happen at runtime, triggered from the Shell UI — expanding the exposure window and the set of actors.
**Required:** (a) validate/whitelist `Parameter`/`Format` before persist AND before compile (allow-list of operators/identifiers/literals, reject `;`, method-call escapes, statement terminators); OR (b) formally accept the compensating control that only Superadmin + DBA-authored migration packages introduce metrics, document the trust boundary, and land validation as fast-follow. Compile failures are currently swallowed (logged only) — also surface them.

### F-2 — ApplyService token fail-open on empty/unconfigured token  **[HIGH — deploy-blocking]**
`Program.cs:43` `expectedToken = config["ApplyService:Token"] ?? ""`. `ConstantTimeEquals("", "")` returns **true** (equal length 0, diff 0). If the token env var is ever unset/misconfigured, an attacker sending `Authorization: Bearer ` (empty) **bypasses auth** and reaches the privileged write-path. `appsettings.json` ships the literal `REPLACE_AT_DEPLOY`; if env injection fails the token silently becomes a known constant.
**Required:** refuse to start (or 503 every request) when `ApplyService:Token` is empty, shorter than N chars, or equals `REPLACE_AT_DEPLOY`. Never compare against an empty expected secret.

### F-3 — RTM SignalR hub has no authentication on any method  **[HIGH — deploy-blocking or compensating-control]**
`RTMHub.cs`: no `[Authorize]` anywhere. `compileMetrics(string[])` — and the data-injection methods `startInteraction` / `setStatistic` — are callable by **any** client that can reach the hub. The Shell-side `RtmRelayService` opens the connection with **no credentials** (none exist to send). Security reduces entirely to network isolation (CLAUDE.md §34 "internal-only"), which is undocumented-as-enforced and violates §25 "[Authorize] on every Hub method; verify identity inside".
**Required:** add a hub-level shared-secret/token check (verify inside the method), OR verify+document on 234 that the RTM hub port is firewalled to the Shell host only (DEPLOY-08) and treat that as the accepted compensating control. Combined with F-1, an unauthenticated `compileMetrics` is the trigger leg of the RCE chain.

### F-4 — Migration package SQL executed verbatim, no integrity check  **[HIGH]**
`Program.cs:138-139` `ExecuteSqlRawAsync(migrationSql)` runs the **entire** migration file as raw SQL with catowner privileges. Path-traversal on `migrationRef` is blocked (good), but the file **content** is neither hashed nor signature-verified. Whoever can write to `PackageMigrationsDir` controls the SQL → INSERT a malicious `RTSGrid_Metric` row → chains to F-1.
**Mitigation (credit):** catowner is least-privilege — `INSERT, SELECT` on 3 tables + `INSERT` on audit only; **no DDL/UPDATE/DELETE**. Blast radius is INSERT-only, but that still reaches the F-1 RCE via a crafted metric row.
**Required:** verify package manifest/migration hash (signed manifest or SHA-256 pinned in the deploy ledger) before execution; lock NTFS ACLs on `PackageMigrationsDir` to admin-write only.

### F-5 — Audit write is fail-open (non-blocking)  **[MEDIUM — deploy-blocking for a privileged op]**
`Program.cs:214-218`: if the audit write throws, the deploy still **commits and returns 200**. A privileged metric deploy can therefore occur with **no audit trail**. Also the audit actor (`UserName`=`TriggeredBy`) is **client-asserted** — any token holder can forge it; `TenantId`/`UserId`/`IpAddress` are null.
**Required:** for `System.MetricsDeployed`, fail-closed on audit failure (or hard-flag + alarm). Treat the client-asserted actor as advisory only; the authoritative actor is the Shell-enforced Superadmin (capture the real UserId server-side where possible).

### F-6 — MetricIds not validated against manifest before apply  **[MEDIUM]**
Manifest mismatch only produces a non-blocking warning; the migration SQL is the real authority and the Shell `metricIds` list is advisory for ledger/compile. Acceptable, but add a guard so a metricId absent from the manifest does not get ledgered/recompiled.

### F-7 — DB connection not verify-full; appsettings placeholders  **[LOW — loopback-mitigated]**
catowner conn string built in deploy has no `sslmode=verify-full`; checked-in appsettings uses `Trust Server Certificate=true`. Loopback-only (127.0.0.1) mitigates MITM. CODE-06 deviation; document as accepted for loopback.

### F-8 — Port default inconsistency  **[LOW — operational]**
ApplyService default 5099 (Program.cs / deploy) vs `MetricsApplyOptions.BaseUrl` default 5050. Deploy patches BaseUrl, so prod is consistent, but a missed patch could send the Bearer token to a wrong loopback listener. Align defaults.

---

## Positive controls (credit — do not regress)
- Token + catowner password generated via **CSRNG** (`RandomNumberGenerator`, 256-bit), not `Get-Random`.
- Secrets stored in **service-env registry** (`HKLM\...\Services\<svc>\Environment`), **not** appsettings.json — CODE-05 satisfied.
- ApplyService Kestrel binds **127.0.0.1 only** (DEPLOY-08); registered as auto-start Windows service.
- **Constant-time** token comparison (timing-attack resistant).
- Ledger + db_patch_history INSERTs are **parameterised** (`ExecuteSqlInterpolatedAsync`) — CODE-01.
- Audit via **separate** `AuditDbContext` — AUD-01.
- Shell deploy tab: **two-level** authZ — `@attribute [Authorize(Roles="Superadmin")]` + `CurrentUser.Role != "Superadmin"` re-check in `ExecuteDeploy` — CODE-03.
- catowner **least-privilege** grants (INSERT/SELECT only, no DDL/UPDATE/DELETE).
- Compile trigger is **server-to-server** and **tenant-scoped** via per-tenant `TenantSettings.SignalRConnectionUrl`; the browser never connects to the RTM hub.

---

## Per-point verdicts (operator scope)
1. **Roslyn runtime-compile** — **FAIL** (no expression validation/whitelist/sandbox; F-1). Required fix or accepted compensating control before 234.
2. **ApplyService write-path** — **PASS-WITH-FIXES** (arbitrary migration SQL is the by-design "view-container"; catowner grants minimal = good; require F-4 integrity check + F-2 token guard).
3. **Inter-service token** — **PASS-WITH-FIXES** (strong gen/storage/const-time; fix F-2 empty-token fail-open).
4. **Deploy AuthZ (Superadmin-only)** — **PASS** (two-level at Shell). ApplyService itself is machine-trust only — acceptable on 127.0.0.1 + token.
5. **Audit (System.MetricsDeployed, tamper-proof)** — **PASS-WITH-FIXES** (separate ctx good; fix F-5 fail-open; actor client-asserted).
6. **Tenant-scope** — **PASS** (per-tenant hub; metrics cross-tenant by design WGT-01; isolation intact).
7. **SignalR compileMetrics** — **FAIL/PASS-WITH-FIXES** (no hub auth; F-3 required: hub token or verified+documented network isolation).

§25 PR checklist: secrets ✅(env) · input-validation ❌(F-1) · raw-SQL ⚠(F-4 by-design migration; ledger ✅param) · [Authorize] ⚠(Shell ✅ / RTM hub ❌ F-3) · CORS n/a(127.0.0.1) · headers n/a(internal svc).

---

## Deploy-234 gate decision
HALT remains until, at minimum:
- **F-2** (token fail-open) — fix (trivial, deploy-blocking).
- **F-3** (RTM hub auth) — fix OR verify+document firewall isolation of the RTM hub port on 234 (compensating control).
- **F-5** (audit fail-open) — fix (deploy-blocking for a privileged op) OR accept with documented monitoring.
- **F-1** (metric expression validation) — accepted compensating control for 234 (Superadmin-only + DBA-curated migration packages, documented trust boundary) + REQUIRED fast-follow validation/whitelist.
- **F-4** (package integrity + ACLs) — required fast-follow; verify `PackageMigrationsDir` ACLs on 234 as interim.

Findings route to owning sessions via coordinator §4: F-1/F-3 → backend (RTM Engine/Hub); F-2/F-4/F-5/F-6 → devops (ApplyService); F-7/F-8 → devops (deploy/config). Shell legs reviewed clean.


---

# RE-REVIEW #1 — 2026-06-10T02:55Z (security-0609)

Triggered by coordinator: devops deploy-blocking fixes landed (deb6aa6 + 60b0cb2). Re-reviewed the diffs.

## Condition A — deploy-blocking real fixes: **VERIFIED ✓**

**F-2 token fail-closed (deb6aa6)** — RESOLVED.
- Startup guard: `throw` if token null/whitespace/`REPLACE_AT_DEPLOY` → service refuses to start.
- Request path: `expectedToken = config[...]` with NO `?? ""` fallback; null/whitespace → 503. The empty-vs-empty
  `ConstantTimeEquals` bypass is gone; const-time compare retained against a guaranteed non-empty secret.

**F-4 migration integrity (deb6aa6 + 60b0cb2)** — RESOLVED.
- Manifest missing/parse-error → 409 fail-closed (was: warning + continue).
- Migration must carry a SHA-256 in the manifest, else 409; computed hash compared case-insensitively, mismatch → 409.
- TOCTOU-safe: the exact bytes that were hashed (`migrationBytes`) are the bytes executed — no re-read between check and use.
- Deploy anchor (60b0cb2): `icacls /inheritance:r`, SYSTEM+Administrators Full, service acct RX-only, **Users + Authenticated
  Users removed** on PackageMigrationsDir + manifest → tampering requires admin. Hash-check + ACL = real integrity.

**F-5 audit fail-closed + real actor (deb6aa6)** — RESOLVED.
- Audit failure now returns 500 (was: warning + success) → privileged deploy can no longer complete silently un-audited.
- Actor = server principal `"ApplyService"` (NOT client-asserted `TriggeredBy`); IpAddress = server-observed RemoteIpAddress;
  client value retained only as labelled `clientAssertedTriggeredBy`.
- Residual (accepted, documented): audit is a separate context (AUD-01) written after the business commit, so an audit-DB
  outage yields committed-catalogue + 500 (visible, idempotent-retryable) rather than rollback. The 500 is the required
  hard-flag; acceptable under AUD-01.

**F-6 metricIds validation (deb6aa6)** — RESOLVED. `request.MetricIds ⊄ manifest` → 400 reject (was: warning only).

Hardening nits (non-blocking, fold into fast-follow if convenient): ApplyService default service identity is LocalSystem
(SYSTEM:F) — over-privileged vs DEPLOY-01 least-privilege; consider a dedicated low-priv service account. The
`${ApplySvcName}:RX` icacls grant may no-op if the bare name doesn't resolve to `NT SERVICE\…` — harmless (SYSTEM covers it).

## Condition B — F-1 trust boundary: **DOCUMENTED (honest boundary)**

Coordinator confirmed `MetricsPage.razor` exposes **free-text `Parameter` (≈line 339) and `Format` (≈line 320)** that
persist to `RTSGrid_Metric` and are compiled. Therefore "no arbitrary input" is **false**. The accepted boundary for 234 is:

> **BOUNDARY [F-1]: "Superadmin = trusted-as-DBA."** An application Superadmin, via the free-text metric `Parameter`/`Format`
> fields, can reach **server-side arbitrary-code execution in the RTM Service process** (the legacy Roslyn compile path,
> unchanged by this feature). This is a **real privilege escalation beyond the application role boundary** and is accepted
> for 234 ONLY because: (a) metric create/edit is **Superadmin-only**, enforced two-level (page `[Authorize(Roles=
> "Superadmin")]` + `ExecuteDeploy` role re-check) — reviewed good; (b) Superadmins are operationally trusted as
> database-administrators; (c) compilation occurs at RTM startup / hot-reload Deploy by that same trusted Superadmin.
> **This trust is removed by fast-follow FF-1** (grammar/AST allow-list validator). Until FF-1 ships, treat Superadmin as a
> DBA-equivalent privilege and restrict the role accordingly.

## Condition C — F-3 firewall isolation: **OUTSTANDING (blocks ACK)**

Compensating control for the un-authenticated RTM hub (`compileMetrics`/`startInteraction`/`setStatistic`, no `[Authorize]`).
Awaiting devops proof on 234 that the RTM hub port is unreachable from browser/external (DEPLOY-08), recorded (firewall
rule / scan output). **No final ACK until this proof is in the bus.**

## Condition D — fast-follow tickets: **to confirm registered**

FF-1 = grammar/AST allow-list validator for `Parameter`/`Format` (parse expression; allow only IDInteraction/ChatMessage
property identifiers + comparison/boolean operators + literals; forbid method-call, member-access outside whitelist, `;`,
lambda-exit). **NOT** a character blocklist (bypassable via string-concat). FF-3 = bearer-token auth verified inside RTMHub
methods (not network-isolation alone). Confirm both are in backlog as my accept condition.

## Gate status after re-review
- A **VERIFIED** · B **DOCUMENTED** · C **OUTSTANDING** · D **pending confirmation**.
- **234 ACK = HELD** pending C (firewall proof) + D (FF tickets registered). On both → I issue ACK with explicit record:
  accepted compensating controls (F-1 boundary, F-3 isolation) + fast-follow register (FF-1, FF-3).


---

# RE-REVIEW #2 — 2026-06-10T06:30Z (security-0609) — F-1 read-only (b7b20e4) + decisions

## B [F-1] LEVEL-2 (request-reachable mutation path) = **CLOSED ✓**
Independently verified tree@b7b20e4 (not on coordinator's word):
- All 4 MediatR commands/handlers/validators/DTOs removed (ConfigurationCommands -168, CommandValidators -65,
  ConfigurationDtos -30, MetricsPage -448 = 701 del). `class/record SaveRtsGridMetricCommand[Handler]` etc.
  = **NOT DEFINED anywhere in src/** at b7b20e4. No request-reachable mutation of RTSGrid_Metric remains (CODE-03 met).
- Leftover repo `Update(RtsGridMetric)`/`Delete(RtsGridMetric)`/`DeleteTranslation` in NgcRepositories — **NO remaining
  caller**: every `repo.Update/Delete` caller is site/BU/SG/PermissionGroup/Tenant, none is metric. Dead plumbing, not reachable.
- Apply-service (catowner, INSERT-only) + startup seeding = the only metric writers. RCE input-path via UI/command = removed.

## RV-1 — orphaned Security test breaks the build  **[REQUIRED cleanup — quality/CI gate]**
`tests/CcDashboard.Tests.Security/Configuration/RtsGridMetricCatalogueTests.cs` @b7b20e4 still references the DELETED
`SaveRtsGridMetricCommandHandler`/`SaveRtsGridMetricRequest`/`SaveRtsGridMetricCommand` → `CcDashboard.Tests.Security`
cannot compile. Coordinator's "build 0-errors" cannot include this project. Consequence: (a) broken build hides ALL
Tests.Security results; (b) the cross-tenant write-rejection regression test is lost. **Required before barrier:** remove
or rewrite the orphaned test (it now asserts behaviour of a deleted command — replace with a "no mutation command exists /
metric repo write is unreachable or REVOKEd" assertion). Fast fix; route to Shell or Test owner.

## RV-2 — dead repo write-methods remain  **[recommend remove / DB-REVOKE closes durably]**
`Update/Delete(RtsGridMetric)` + `DeleteTranslation` remain in repo/interface with no caller. Latent surface. Remove with
the FF, and/or the DB-level REVOKE makes them inert at the DB regardless.

## DECISIONS (operator/coordinator questions)
1. **DB-REVOKE — CODE-level (A) is SUFFICIENT for 234.** Request-reachable mutation removed (verified) + catowner
   isolation + F-4 integrity + no metric-repo caller. **B' (migrate seeding to a privileged role, then `REVOKE
   INSERT/UPDATE/DELETE ON "RTSGrid_Metric" FROM ccdashboard_user`) = accepted as FF** — register concretely; fold RV-2
   dead-code removal into it. DB-level read-only is the durable closure; not a 234 blocker given A.
2. **F-3 loopback-rebind = APPROVED as a REAL fix** (superior to the failed firewall compensator; aligns §34
   server-to-server). The firewall "assumed internal" was FALSE (hub bound `::`:8088 = all interfaces) — exactly why
   verification is mandatory; good catch. **Require:** rebind landed + post-deploy proof `Get-NetTCPConnection` showing
   LocalAddress 127.0.0.1 only (no `::`/0.0.0.0). FF-3 bearer-token stays defense-in-depth.
3. **Integration tests (72bd997) = HARD-GATE, satisfied by a GREEN run** (Docker now up). Authored-only insufficient.
   Give me the run result as proof. NOTE: 72bd997 is Tests.Integration; RV-1 breaks Tests.Security (separate project) —
   the integration run going green does NOT clear RV-1. Both required.

## Gate status after RE-REVIEW #2
- A (devops fixes) VERIFIED · B (F-1 LEVEL-2) CLOSED · DB-REVOKE A-accepted(+B' FF) · F-3 rebind APPROVED-pending-land+proof.
- **Outstanding before 234 ACK:** (i) RV-1 orphaned-test cleanup (build green incl. Tests.Security); (ii) F-3 rebind landed
  + loopback proof; (iii) 72bd997 integration run GREEN proof.
- On all three → I ISSUE ACK with record: real fixes (F-1 input-path removed, F-2/4/5/6, F-3 loopback) + FF register
  (FF-1 grammar-validator DiD, FF-3 hub bearer-token, B' DB-REVOKE+dead-code, LocalSystem low-priv).


---

# RE-REVIEW #3 — 2026-06-10T08:20Z (security-0609) — F-3 verify, tests, sole blocker

- **(ii) F-3 loopback rebind = VERIFIED ✓.** 6b82eba: RTM hub `http://*:8088` → `http://127.0.0.1:8088` (no longer
  all-interfaces). cd576d4: deploy-time assert/patch of Kestrel bind to loopback + B2 sets `tenant_settings.
  SignalRConnectionUrl` to loopback (relay preserved). Real fix, replaces failed firewall compensator. **Deploy-time
  acceptance:** operator `Get-NetTCPConnection` on 234 must show LocalAddress 127.0.0.1 only — recorded as a deploy-gate step.
- **(iii) Integration tests = CLOSED ✓** (3168068, all 31 green on real Postgres). Security 10/10 assert F-2 (401 /
  startup-throw), F-4 (tampered/no-hash → 409), F-5 (audit actor=ApplyService / 500 on fail), F-6 (unknown id → 400).
  F-5 `IpAddress` non-null NOT asserted = in-memory harness has null RemoteIpAddress; **prod code sets it** —
  grep-verified HEAD Program.cs L274/283 (`IpAddress = remoteIp`). Harness caveat, not a prod defect — accepted.
- **(i) RV-1 = OPEN — SOLE REMAINING BLOCKER.** `tests/CcDashboard.Tests.Security/Configuration/
  RtsGridMetricCatalogueTests.cs` @HEAD still has 6 refs to the removed `SaveRtsGridMetricCommandHandler` →
  `CcDashboard.Tests.Security` will not compile. Routed to Shell.

## ACK CONDITION (single, explicit)
I ISSUE the 234 deploy ACK the moment RV-1 lands AND I verify: (a) `git grep SaveRtsGridMetric* tests/` = EMPTY, and
(b) full `dotnet build CcDashboard.sln` green INCLUDING CcDashboard.Tests.Security. All other legs verified/closed.
ACK will record: real fixes [F-1 input-path removed (b7b20e4), F-2/F-4/F-5/F-6 (deb6aa6/60b0cb2), F-3 loopback (6b82eba/
cd576d4), tests green (72bd997/3168068)] + FF register [FF-1 grammar-validator DiD, FF-3 RTMHub bearer-token, B' DB-REVOKE
+RV-2 dead-code, LocalSystem low-priv] + deploy-time gate [F-3 loopback proof on 234].


---

# SECURITY ACK — Server-234 deploy (hot-reload metrics) — 2026-06-10T09:45Z (security-0609)

**GATE RESULT: ACK GRANTED** for the hot-reload metrics changeset to Server-234 (iter-1).

## Verification basis (independent, HEAD object store — mount-zombie caveat heeded)
- **(i) F-1 input-path removed + RV-1/RV-1b** — CLOSED ✓. HEAD-tree: zero live refs to the 8 metric-mutation types in
  `tests/` (only string literals inside the F-1 absence-regression `RtsGridMetricCatalogueTests.cs`); 2 pure-metric
  `Tests.Unit` orphans GONE from HEAD; `DeleteConfigurationCommandsTests` keeps BU/SG (valid), metric class dropped.
  b7b20e4 (read-only) + 78bf89c (RV-1) + a247d2f (RV-1b). Coordinator native `dotnet build CcDashboard.sln` = 0 errors.
- **(ii) F-3 loopback rebind** — code VERIFIED ✓. 6b82eba `*:8088→127.0.0.1:8088`; cd576d4 deploy-assert + relay URL loopback.
- **(iii) integration tests** — GREEN ✓. 72bd997 + 3168068 = 31/31 on real Postgres; security 10/10 assert F-2/F-4/F-5/F-6.
- **A — F-2/F-4/F-5/F-6 ApplyService fixes** — VERIFIED ✓ (deb6aa6 + 60b0cb2), runtime guards intact at HEAD.

## ACK is conditional on (deploy-time, operator-enforced at 234)
- **DG-1 [F-3 loopback proof]:** at deploy, `Get-NetTCPConnection` on the RTM hub port (8088) MUST show LocalAddress
  127.0.0.1 only (no `::`/0.0.0.0). If the hub is not loopback-bound at runtime, this ACK is VOID for that deploy.
- **DG-2 [ApplyService secrets]:** confirm `ApplyService:Token` + catowner conn are provisioned via service-env registry
  (not placeholder); F-2 startup guard will refuse to start otherwise — acceptable, but verify it started.

## FAST-FOLLOW register (tracked in backlog; NOT 234 blockers — required before broad rollout)
- **FF-1** grammar/AST allow-list validator for any future metric authoring path (defense-in-depth; NOT char-blocklist).
- **FF-3** bearer-token auth inside RTMHub methods (compileMetrics/startInteraction/setStatistic) — network isolation alone is not auth.
- **B' + RV-2** migrate seeding to a privileged role, then `REVOKE INSERT/UPDATE/DELETE ON "RTSGrid_Metric" FROM
  ccdashboard_user`, and remove the dead repo `Update/Delete(RtsGridMetric)` methods — durable DB-level read-only.
- **LocalSystem nit** run ApplyService under a dedicated low-privilege service account (DEPLOY-01).

## Scope
This ACK covers THIS changeset for the 234 iter-1 deploy only. Per my standing mandate (§42.7 + §44), future
changes/features/fixes each require their own Security gate + a fresh ACK at their barrier. On the push-barrier opening
for this bundle, I will place a `READY` ack in `.coord/push/acks/security-0609.md` reflecting this verified state.

**HALT (Security) LIFTED for 234 iter-1, subject to DG-1/DG-2.**


---

# SECURITY ACK — Server-234 deploy (hot-reload metrics) — 2026-06-10T09:45Z (security-0609)

**GATE RESULT: ACK GRANTED** for the hot-reload metrics changeset to Server-234 (iter-1).

## Verification basis (independent, HEAD object store — mount-zombie caveat heeded)
- **(i) F-1 input-path removed + RV-1/RV-1b** — CLOSED ✓. HEAD-tree: zero live refs to the 8 metric-mutation types in
  `tests/` (only string literals inside the F-1 absence-regression `RtsGridMetricCatalogueTests.cs`); 2 pure-metric
  `Tests.Unit` orphans GONE from HEAD; `DeleteConfigurationCommandsTests` keeps BU/SG (valid), metric class dropped.
  b7b20e4 (read-only) + 78bf89c (RV-1) + a247d2f (RV-1b). Coordinator native `dotnet build CcDashboard.sln` = 0 errors.
- **(ii) F-3 loopback rebind** — code VERIFIED ✓. 6b82eba `*:8088→127.0.0.1:8088`; cd576d4 deploy-assert + relay URL loopback.
- **(iii) integration tests** — GREEN ✓. 72bd997 + 3168068 = 31/31 on real Postgres; security 10/10 assert F-2/F-4/F-5/F-6.
- **A — F-2/F-4/F-5/F-6 ApplyService fixes** — VERIFIED ✓ (deb6aa6 + 60b0cb2), runtime guards intact at HEAD.

## ACK is conditional on (deploy-time, operator-enforced at 234)
- **DG-1 [F-3 loopback proof]:** at deploy, `Get-NetTCPConnection` on the RTM hub port (8088) MUST show LocalAddress
  127.0.0.1 only (no `::`/0.0.0.0). If the hub is not loopback-bound at runtime, this ACK is VOID for that deploy.
- **DG-2 [ApplyService secrets]:** confirm `ApplyService:Token` + catowner conn are provisioned via service-env registry
  (not placeholder); F-2 startup guard will refuse to start otherwise — acceptable, but verify it started.

## FAST-FOLLOW register (tracked in backlog; NOT 234 blockers — required before broad rollout)
- **FF-1** grammar/AST allow-list validator for any future metric authoring path (defense-in-depth; NOT char-blocklist).
- **FF-3** bearer-token auth inside RTMHub methods (compileMetrics/startInteraction/setStatistic) — network isolation alone is not auth.
- **B' + RV-2** migrate seeding to a privileged role, then `REVOKE INSERT/UPDATE/DELETE ON "RTSGrid_Metric" FROM
  ccdashboard_user`, and remove the dead repo `Update/Delete(RtsGridMetric)` methods — durable DB-level read-only.
- **LocalSystem nit** run ApplyService under a dedicated low-privilege service account (DEPLOY-01).

## Scope
This ACK covers THIS changeset for the 234 iter-1 deploy only. Per my standing mandate (§42.7 + §44), future
changes/features/fixes each require their own Security gate + a fresh ACK at their barrier. On the push-barrier opening
for this bundle, I will place a `READY` ack in `.coord/push/acks/security-0609.md` reflecting this verified state.

**HALT (Security) LIFTED for 234 iter-1, subject to DG-1/DG-2.**


---

# SECURITY ACK — server-45 PROD (push 3 commits + in-place deploy) — 2026-06-11T15:45Z (security-0609)

**GATE RESULT: ACK GRANTED** to push (65e6ca1, 7ba6250, 0ef423b) and deploy to server-45 (existing PROD, PG17, in-place),
subject to deploy-time conditions DG-1..DG-4 below.

## 234 iter-1 — accepted (closes prior open questions)
- DG-1 (8088 loopback) + DG-2 (RTMApplyService Running, REAL env token so F-2 not triggered, POST no-token → 401) = GREEN
  on 234 per coordinator 14:00. The 12:20 DG-2 durable-hosting question is RESOLVED by 7ba6250 — iter-1 ACCEPTED.
- Delta disclosure (7ba6250 rode onto 234): reviewed — non-security (see below). iter-1 ACK HOLDS; no separate re-review owed.

## Prod changeset review (independent)
- **65e6ca1** — docs only (rtm-metrics-expert quote-fix). No runtime. ✓
- **7ba6250** — exactly 2 lines: `Microsoft.Extensions.Hosting.WindowsServices` pkg + `builder.Host.UseWindowsService()`.
  No change to the 127.0.0.1 bind, auth, or F-2/F-4/F-5/F-6 logic. SCM hosting only. Non-security ✓.
- **0ef423b** — deploy backport. NO new attack surface; re-applies the SAME controls, now correctly:
  - **F-4 ACL FIXED:** icacls grant changed bare `${ApplySvcName}` → `NT SERVICE\${ApplySvcName}` (resolves my earlier
    nit where the bare name could no-op). SYSTEM+Admin Full, service RX-only; **Users + Authenticated Users still removed**
    (HEAD L757/758/766/767/774/775). Real least-privilege on the package/manifest dirs. ✓
  - **F-3 preserved:** ApplyService Kestrel + Shell MetricsApply BaseUrl both stay `http://127.0.0.1` (Add-Member -Force). ✓
  - **A6 tenant-isolation assert (security-POSITIVE):** post-deploy asserts RTM:TenantId ≠ null/Guid.Empty, FATAL throw if
    clobbered — protects §33 isolation / RTM-SEC-001 (empty TenantId → cross-tenant MidnightClear risk). ✓
  - No plaintext secret committed (paranoia grep of all 3 commits = clean). catowner pw stays CSRNG-once → ALTER +
    service-env single-source. StrictMode kept; orphan-kill-by-path = operational. ✓

## Deploy-time conditions on server-45 (operator-enforced, PROD)
- **DG-1:** `Get-NetTCPConnection` :8088 LocalAddress 127.0.0.1 only post-deploy (F-3).
- **DG-2:** RTMApplyService Running with real env token (not placeholder) + POST /apply-metrics no-token → 401 (F-2/auth).
- **DG-3 [new, backport]:** deploy log shows "Verified RTM:TenantId = <uuid>" (A6 assertion green) — tenant isolation intact on PROD.
- **DG-4 [new, backport]:** Phase-7 item 8 — `icacls "<InstallRoot>\Packages"` shows `NT SERVICE\<svc>` grant lines
  (not "No mapping between account names") — confirms F-4 ACL actually applied on 45.
- Recommend the Phase-7 e2e smoke be run (45 is PROD).

## Minor finding (FF, non-blocking)
- **MF-1 [415-before-401]:** an empty/malformed POST returns 415 (media-type check) before 401. Auth IS enforced on a
  well-formed request; the 415 leaks only endpoint existence to an unauthenticated caller, and the endpoint is 127.0.0.1-only.
  Low severity. FF: short-circuit the Bearer check ahead of content negotiation.

## FF register (carried, backlog)
FF-1 grammar/AST validator · FF-3 RTMHub bearer-token · B'+RV-2 (REVOKE ccdashboard_user on RTSGrid_Metric + dead-repo
removal + seeding→privileged) · LocalSystem→low-priv service account (partially mitigated by NT SERVICE ACL; full = run as
the service vSID not LocalSystem) · MF-1 415-before-401.

## Scope
Covers these 3 commits + the server-45 in-place deploy. Future changes each need their own gate (§42.7 + §44).
On push-barrier open I drop READY to `.coord/push/acks/security-0609.md` reflecting this verified state.
