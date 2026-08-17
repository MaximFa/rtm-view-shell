---
artifact: security-session-handoff
slug: security-0620
role: security (InfoSec review-gate, review-only)
branch-map: v3=reports/BI (HEAD 5954a76 / origin db9d18e) · v2-backend=trunk+Maintenance+Garnet (HEAD 43bb430 / origin 51daa8a) · v2/v2-frontend=separate (not our target)
written: 2026-06-26T00:50:59Z
status: HANDOFF
---

# Security session handoff — security-0620 → next incarnation

## ⛔ ACTIVE TASK (do FIRST — MANDATORY gate, RUN-box is HELD pending this verdict)
**ARCH-02 Superadmin tenant-switch — impersonation/privilege review.** Re-posted by coordinator-0624 in
inbox/security.md (2026-06-26 11:00/12:50/13:45). NOTHING committed yet; backend's server prompt is §4-PASS on
mechanics. Feature does NOT land without the Security ack (peer of coordinator §4).
READ (object-store): `tools/cc_prompt_backend_arch02_tenant_switch.md` (full server design + shell contract) +
touched code: `src/CcDashboard.Infrastructure/Identity/CustomClaimsPrincipalFactory.cs` (adds `active_tenant_id`
claim), `src/CcDashboard.Application/Security/CurrentUserAccessor.cs`, TenantCircuitHandler/TenantResolutionMiddleware,
ITenantContext, the SwitchTenantCommand design, CLAUDE.md §29.2 (Superadmin IgnoreQueryFilters+explicit Where).
ASSESS 3 flagged surfaces (+add any):
1. GQF-for-Superadmin: active=X filters Superadmin to X; admin screens (Users §USR-14, PG, Tenants §ARCH-05) use
   IgnoreQueryFilters+explicit Where (claimed unaffected) — VERIFY; assess the MUTATION surface while impersonating X
   (can Superadmin wrongly WRITE X's or platform data while switched?).
2. AUTH-WEB-02: cookie re-issue (shell SSR endpoint) must keep SecurityStamp validation intact.
3. No-escalation: a non-Superadmin must NOT set/abuse `active_tenant_id` — override applies ONLY when Role==Superadmin,
   Role read from a TRUSTED claim, never from the forgeable active_tenant_id.
VERDICT → READY (ack, feature may land) or HOLD (specific finding) → inbox/coordinator.md (PERMANENT).

## OPEN findings (carry forward)
- **SF-SEC-001 [HIGH] — secret-in-source.** ccdashboard DB password plaintext in ~27 tracked files on BOTH branches
  (RTM/Shell appsettings, Grant.txt CREATE USER, Installations packages, CLAUDE.md §38/§39, ~13 tools/cc_prompt_*).
  Triage (in inbox/coordinator.md 06-22): (a) ROTATE = MANDATORY assume-compromised (operator/dba, all servers); (b)
  ACCEPT history after rotation, PRIORITIZE live-tree purge → REPLACE_ME/preserved-config (devops). NON-blocking for
  pushes (no NEW secret added by feature commits). Awaiting operator rotation window → then author/review purge,
  grep-zero verify. See memory sf-sec-001-db-password-in-source.
- **SF-BI-002 [LOW] — drop-log.** out-of-PG drop is silent; add a security-event log (userId, PG, dropped entries) for
  probe detection. OK to ride the Ф2/Ф5 scope-chain wiring. Not blocking.
- **SF-ARC-001/002/003 [HOLD] — future ChatMessage archive.** RTSData_ChatMessage has no TenantId; backend confirmed
  InteractionId NOT unique (ServerId=tenant discriminator). Ruling = write-time TenantId column (gated on R0c-style
  schema add) NOT JOIN-inference; orphan = unknown-bucket Superadmin-only; PII 7yr = encryption-at-rest+restricted
  role+erasure+audit. The 3 TenantId-bearing archive tables (interaction/userstatus/userstatuslog) PROCEEDED. Fold
  SF-ARC conditions into the spec when the ChatMessage-archive task is authored.
- **SF-MS-004..009 [BLOCKED] — Maintenance v2 write-plane.** Separate Security ack required BEFORE v2 write-plane build
  (write-plane stopped-by-default+start-gating; off-box audit; out-of-band single-use job-bound confirm; pull
  signature/checksum fail-closed + signing key off-box; mTLS thumbprint rotation/revocation; job-lock).

## Reports v1 specs — READY(spec), conditions to verify at CODE-LAND (post-commit re-review, bundled-barrier quorum)
- SMTP creds (Ф7): (a) edit form not round-trip password to browser; (b) password [JsonIgnore]/redacted in all
  serialization+logs+Send-test; (c) decrypted pwd transient-in-memory only; (d) Data Protection key ring persisted+ACL;
  (e) ✓ already cross-checked: soma_ro can't read tenant_settings (tenant_settings_safe drops EmailProviderConfig).
- BU∩PG scope: re-confirm the resolver chain (BuMembershipResolver→INTERSECT ReportScopeResolver→repo IN unconditional)
  + report_permissions+[Authorize]+Application (CODE-03) when code lands. Recommend adding menu.reports to the matrix
  (follow-up; v1 OK without it since enforcement is at Authorize+App, not menu-hiding).

## CLOSED / DONE (context)
- SF-SOMA-001 [MED] CLOSED (fix 9c6ac0e: REVOKE SELECT on identity.users/sso_configurations/tenant_settings from
  soma_ro + *_safe views; live PasswordHash→denied).
- SF-BI-001 [HIGH] CLOSED (53aa308 repo unconditional-filter-when-!FullScope + null-list non-bypassable + empty-PG DENY;
  Ф2 BuMembershipResolver 2a8cffe GREEN).
- SF-MS-001/002/003 v1 read-plane GREEN (scaffold c915d4d: 3-factor auth mTLS-thumbprint+token-TTL60+revoke+IP/loopback
  +127.0.0.1, ISecretScrubber streaming default-deny+/jobs, no write-plane endpoints; RCE contract 43bb430: enum
  allow-list + SignalScriptMap fail-fast + ArgumentArrayGuard arg-array + 52 injection tests + architecture no-.Arguments).
- Push-barrier acks given: v3 (243e4a4 + later 243e4a4..9c6ac0e), v2-backend (8bbee78..51daa8a), Garnet Phase-2 COND-GREEN
  (f3368d8). Barrier #2/#3 earlier.

## Conventions (do not drift)
- Write to the PERMANENT mailbox `inbox/coordinator.md` (NOT slug `coordinator-NNNN.md` — deprecated §26.1/§42.8).
- Recipient writes its own `> handled` marker; sender never marks what it sent.
- Ack file: `.coord/push/acks/security-0620.md` (overwrite per barrier).
- ALL .coord writes = Python + os.fsync (§0.3); verify via OBJECT-STORE `git show <rev>:<path>` — mount git status is
  unreliable (§0.5, truncates HEAD→'v2-'). Review-only: NO file claims, NO commits, NO push; findings→coordinator §4/§26.8.
- Process gotchas seen: barrier ranges re-committed by reconcile (verify NET content, not SHA); 'security ничего не видит'
  usually = fresh incarnation hasn't read inbox → run коорд:входящие at boot.
