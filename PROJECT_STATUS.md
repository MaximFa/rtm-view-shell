# RTM View Shell — Project Status (session snapshot 2026-05-27)

**Purpose:** quick orientation for any contributor (human or agent)
resuming work. Read this first, then drill into the linked artefacts.

---

## Current state

**v1.3 release status — corrected 2026-05-25 after filesystem sanity check:**

The codebase is on the v1.3 *code* track (T1 + T4 test coverage delivered,
SF-001..005 closed). But the prior version of this document claimed
"v1.3 DELIVERED" with 9 ✅ tracks, of which **only 3 actually exist in
the repository** (verified against `git log --all` for each file).
The other 6 tracks were aspirational placeholders that propagated from
stale memory. Corrected table below.

| Track | Previously claimed | Actual state | Disposition |
|---|---|---|---|
| TS v1.3 EN (docx) | ✅ | ❌ NEVER existed in git; only v1.0, v1.1, v1.2, v1.2_EN present | Backlog D1 |
| 12 ADRs Accepted | ✅ | ❌ 0 ADR-NNN files exist; `decisions/_index.md` lists **8** *Open* (ADR-001..008) with no content | Backlog D1 |
| CHANGELOG v1.2→v1.3 | ✅ | ❌ NEVER existed in git | Backlog D1 |
| Traceability matrix | ✅ | ✅ `docs/traceability-matrix.md` real, T1 + T4 rows populated | — |
| Stakeholder summary | ✅ | ❌ NEVER existed in git | Backlog D1 |
| Widget architecture | ✅ | ❌ NEVER existed (no `analysis/widgets/` directory) | Backlog D1 / T5 input |
| CLAUDE.md (v1.3 sync) | ✅ | ⚠ file exists; frontmatter says `TZ version: 1.2 \| CLAUDE.md last updated: 2026-05-09` — **not** bumped to v1.3 | Backlog D1 |
| Security findings (SF-001..005) | ✅ | ✅ `analysis/security-findings.md` real, 5 entries | — |
| Process deviations (PD-001..004) | ✅ | ✅ `analysis/process-deviations.md` real, 4 entries | — |

**Implication:** "v1.3 release ✅ DELIVERED" was an overstatement. What
exists today is: v1.2 codebase + T1 (Phase A+B+C) + T4 + #14 test-coverage
work + traceability matrix + SF/PD logs. Documentation deliverables (TS
docx update, CHANGELOG, ADR files, stakeholder summary, widget
architecture) are **Backlog D1** (created as a result of this sanity
check; see below).

---

## Sprint inventory

| Sprint | Subject | Status | Next action |
|---|---|---|---|
| **T1** | Security & cross-tenant isolation | **✅ FULLY CLOSED. Phase A + B + C complete (79 tests, 0 skips, 87.88% Infrastructure coverage, 4 SF + 2 PD found).** | Sprint done; pick next |
| **T2** | Licensing enforcement | **✅ CLOSED (2026-05-25). 20 new tests, SF-006 + SF-007 fixed. 166 / 166 Tests.Security pass.** | Sprint done; pick next |
| **T3** | Multi-tenancy integration | **✅ CLOSED (commit `7b85269`, 2026-05-25). 36 new tests, no SF-008 (OQ-1 resolved). 204 Tests.Security, 285 solution-wide.** | Sprint done; pick next |
| **T4** | PG authorization semantics | **✅ CLOSED (commit `cb7af32`, 46 tests, SF-005 Critical fixed). 146 / 146 Tests.Security pass. PD-003 resolved via Backlog #14.** | Sprint done; pick next |
| **T5** | Widget framework | **✅ CLOSED (commit `fbf89fd`, 2026-05-25). 28 new tests, OQ-16 verified, no SF. 313 / 313 solution-wide pass.** | Sprint done |
| **T6** | User Management + Audit Trail | **✅ CLOSED (commits `22b087a`, `119b5a9`, 2026-05-26). Phase A: 35 tests (USR-01..14, GAP-T6-01..04 fixed). Phase B: 44 tests (AUD-01..08). 382 / 382 solution-wide pass (after #15 removed NgcIsolationTests -10).** | Sprint done |
| **CC-003** | RTM Relay Infrastructure — server-side SignalR relay, single-port browser model | **✅ CLOSED (commit `0c3c902`, 2026-05-31). 7 files: Domain models, IRtmRelayService, RtmRelayService (677 lines), RtmRelayHub. Uses existing SignalRConnectionUrl. No migration needed.** | Done |

Briefs live in `docs/sprints/T{1..6}-*.md`.

---

## Code follow-on backlog

| ID | Task | Prompt status | Unblocks |
|---|---|---|---|
| **B1 (#11)** | Introduce `BackendEmulationDbContext` per ADR-007 | **✅ CLOSED** (commit `80974b0`, 2026-05-25) | — |
| **#12** | Widget-creator skill MetricType drift fix | **✅ CLOSED** (commit `5eab846`, 2026-05-25) | — |
| **#13** | `DatabaseInitializer` → `IDatabaseInitializer` interface | **✅ CLOSED** commit `80645f1` (2026-05-25) | Closed |
| **#14** | `WebFixture`: disable `LoginRateLimitMiddleware` in test pipeline | **✅ CLOSED.** Reflection-based clearing of middleware static state. 146/146 tests pass. | — |
| **#15** | Separate NGC_*/RTS_* tables: AppDbContext → BackendEmulationDbContext (ADR-007) | **✅ CLOSED** commit `bf8a79e` (2026-05-26). NO-OP AppDbContext migration + BE IF NOT EXISTS. 382 / 382 pass. Post-migration: clear `__BackendEmulationMigrationsHistory`, reimport `Metrics_fixed.sql` (190 rows). | — |
| **D1** | Documentation catch-up: TS v1.3 EN docx, CHANGELOG v1.2→v1.3, ADR-001..008 files, stakeholder summary, widget architecture, CLAUDE.md frontmatter bump to v1.3 | **✅ CLOSED (commit `b16d2e5`, 2026-05-25). 1,378 insertions across 13 files. All 6 deliverables delivered.** | Done |
| **CC-001** | RTSData entities + StatusGroup column | **✅ CLOSED (commit `cd99e46`, 2026-05-26).** RTSData_* tables in BackendEmulationDbContext; StatusGroup column migration. | Done |
| **CC-002** | DayTrend widget — PostgreSQL functions, query handler, Blazor component, config modal, seed | **✅ CLOSED (commit `04bc370`, 2026-05-27). 4 widgets live on dashboard: DataSlot, AgentGrid, QueueGrid, DayTrend. Dark mode. Chart.js multi-line. BU dropdown fix. Pushed to origin.** | Done |
| **#16** | Widget catalogue cleanup: remove 3 mock components (KpiWidget, AgentStatusWidget, QueueSummaryWidget) + 11 stub catalogue entries. Keep only SignalR-backed AgentGrid/QueueGrid/DataSlot. | **✅ CLOSED (commit `9cc4d9b`, 2026-05-26). RenderWidget.razor trimmed to 3 cases. DatabaseInitializer cleans obsolete entries on next startup. Stub .razor files emptied to single comment line (0 errors build).** | Done |
| **#17** | DataSlot RTS persistence: implement `SaveDataSlotRtsCommand` (1×1×1 structure in RTSGrid_* tables). Wire into `ScreenEditorPage`: save on config modal, deferred delete on SaveLayout. Existence-check-before-UPDATE guards against stale ConfigJson IDs. | **✅ CLOSED (CC session 2026-05-26). New file: `SaveDataSlotRtsCommand.cs`. Changed: `ScreenEditorPage.razor` (4 RTS ID fields on WidgetConfig, OpenWidgetConfig/SaveWidgetConfig/ConfirmDeleteWidget/SaveLayout). Build 0 errors. No test yet for SaveDataSlotRtsCommand (tracked in gap analysis).** | Done |
| **CC-003** | RTM Relay Infrastructure: Domain models, IRtmRelayService, RtmRelayService (Singleton, ref-count, grace timer, snapshot), RtmRelayHub, DI wiring. Reference: RTMView RtmHubService. See CLAUDE.md §34. | **✅ CLOSED (commit `0c3c902`, 2026-05-31). 677-line RtmRelayService with (TenantId, UnionId/GridId) composite keys, Redis URL cache, DisconnectTenantAsync. Build 0 errors.** | Done |
| **#18** | AgentGrid RTS ID fix: `SaveAgentGridRtsCommand` was called with `DashboardWidget.GridId` (auto-increment 14/15/16) instead of `Config.RtsUserGridId` (RTS GridId = 1). Deletion targeted non-existent records, leaving orphan data. | **✅ CLOSED (CC session 2026-05-26). Changed: `ScreenEditorPage.razor` — new `WidgetConfig.RtsUserGridId` field; SaveWidgetConfig uses `Config.RtsUserGridId ?? 0`; delete uses `Config.RtsUserGridId`; template drop resets `RtsUserGridId=null`. Orphan RTSUserGrid_Column rows (ColumnsSetId=14) deleted. All 13 RtsGridLifecycleTests pass.** | Done |

Both prompts are in the chat history of session 2026-05-17. If lost,
both are short enough to regenerate from this status doc + relevant
ADRs.

---

## T1 results — quick reference

### Phase A — commit `ca0ccd9`
- **Tests:** 32 passing, 3 skipped (golden-path → Phase C), 0 failing
- **Coverage:** 86.3% Infrastructure (target 60%)
- **DoD:** 5/5 ✅
- **Production bugs found:** 3 (SF-001 Critical, SF-002/003 High)

### Phase B — commit `b846f1b`
- **Tests:** 61 passing, 8 skipped (golden-path requires WebApplicationFactory → Phase C), 0 failing
- **Coverage:** 86.88% Infrastructure (target 60%)
- **DoD:** 6/7 ✅, 1/7 ⚠ (DoD-11 LICENSE-SESSION rejection-path only; success path needs WAF)
- **Production bugs found:** 1 (SF-004 Medium — JTI revocation crash on zero TTL)

### Phase C — commit `77e1537` (2026-05-25)
- **Tests:** 79 passing, 0 skipped, 0 failing
- **Coverage:** 87.88% Infrastructure (target ≥80%)
- **DoD:** 7/7 ✅ (DoD-13..19)
- **Production bugs found:** 0
- **Process deviations:** 2 (PD-001 `Program.cs` partial class; PD-002 `DatabaseInitializer` virtual). Both accepted; PD-002 spawned backlog item #13.

### T1 totals (Phase A + B + C combined)
- **Tests:** 79 passing, 0 skipped, 0 failing
- **Coverage:** 87.88% on `CcDashboard.Infrastructure`
- **Security findings:** 4 (SF-001..004) — all fixed in their respective phase commits
- **Process deviations:** 2 (PD-001..002) — documented in `analysis/process-deviations.md`
- **Total investment:** ~50 hours (20+15+~12 across A/B/C)

Details: `docs/sprints/T1-gap-analysis-phase-{a,b,c}.md`, `analysis/security-findings.md`, `analysis/process-deviations.md`.

---

## T4 results — quick reference

### T4 — commit `cb7af32` (2026-05-25)
- **Tests:** 46 new (9 test files in `Tests.Security/Authorization/`)
- **`Tests.Security` total after T4:** 146 passing, 0 failing, 0 skipped (PD-003 resolved via Backlog #14)
- **DoD:** 12/12 ✅ (DoD-11 zero failing achieved after Backlog #14 fix)
- **Production bugs found:** 1 (SF-005 Critical — `AuthorizationBehavior.RequiredPermission` was a silent no-op TODO; latent — no command in repo declared it yet, but first declaration would have shipped unenforced)
- **Production code added:** `IPermissionService` interface (Domain) + `PermissionService` implementation (Infrastructure, Redis-backed) + wiring in `AuthorizationBehavior` — all pre-approved per MC-T4-1
- **Process deviations:** 2 (PD-003 failing E2E tests under shared rate-limit state — **resolved via #14**; PD-004 separate gap-analysis file not created)

### Cumulative test coverage after T1 + T4 + Backlog #14
- **Tests.Security:** 146 passing, 0 failing, 0 skipped
- **Tests.Unit:** existing PG handler tests unchanged
- **Security findings:** 5 (SF-001..005)
- **Process deviations:** 4 (PD-001..004; PD-003 resolved)
- **Total investment:** ~74 hours (T1 ~50h + T4 ~23h + #14 ~1h)

Details: `analysis/security-findings.md` (SF-005), `analysis/process-deviations.md` (PD-003, PD-004), `docs/traceability-matrix.md` (Permission Groups + AUD-01).

---

## T2 results — quick reference

### T2 — 2026-05-25
- **Tests:** 20 new (4 test files in Authentication/ and Licensing/)
- **`Tests.Security` total after T2:** 166 passing, 0 failing, 0 skipped
- **DoD:** 13/13 ✅
- **Production bugs found:** 2 (SF-006 Medium, SF-007 High)
  - SF-006: Missing audit event on LICENSE-USER rejection
  - SF-007: TOCTOU race condition on concurrent user creation
- **Production code changes:**
  - `UserManagementService.CreateAsync`: audit emission on rejection (4 LOC)
  - `UserManagementService.CreateAsync`: transaction + `SELECT ... FOR UPDATE` for race protection
- **New test files:**
  - `Tests.Security/Authentication/ForceLogoutTests.cs` (4 tests — AUTH-WEB-03, USR-09)
  - `Tests.Security/Authentication/JwtKeyConfigurationTests.cs` (6 tests — AUTH-API-06)
  - `Tests.Security/Licensing/LicenseUserAuditTests.cs` (3 tests — LIC-01, AUD-01)
  - (+ updates to existing `LicenseUserLimitTests.cs` for race test)

### Cumulative test coverage after T1 + T4 + T2
- **Tests.Security:** 166 passing, 0 failing, 0 skipped
- **Total solution tests:** 247 passing (1+72+8+166)
- **Security findings:** 7 (SF-001..007)
- **Process deviations:** 5 (PD-001..005; PD-003, PD-005 resolved)
- **Total investment:** ~77 hours (T1 ~50h + T4 ~23h + #14 ~1h + T2 ~3h)

Details: `docs/sprints/T2-gap-analysis.md`, `analysis/security-findings.md` (SF-006, SF-007), `docs/traceability-matrix.md` (LIC-01, AUTH-WEB-03, AUTH-API-06, USR-09).


---

## T3 results — quick reference

### T3 — commit `7b85269` (2026-05-25)
- **Tests:** 36 new test cases (6 files in Tests.Security/)
  - `MultiTenancy/NgcIsolationTests.cs` — 8 tests (DoD-2 + DoD-3)
  - `MultiTenancy/TenantResolutionTests.cs` — 5 tests (DoD-4)
  - `PasswordPolicy/PasswordPolicyTests.cs` — 8 tests (DoD-5)
  - `Infrastructure/RedisKeyPrefixTests.cs` — 4 tests (DoD-6)
  - `Authentication/JwtClaimsTests.cs` — 5 tests (DoD-7)
  - `Authentication/ConfigWriteProtectionTests.cs` — 6 tests (DoD-8)
- **`Tests.Security` total after T3:** 204 passing, 0 failing, 0 skipped
- **DoD:** 10/10 ✅
- **Production code fix:** `TokenService.NotBefore = now` (ensures clock mock works in JWT claims tests)
- **Security findings:** 0 (OQ-1 resolved — GQF already present on all junction tables; no SF-008)
- **Open questions resolved:**
  - OQ-1: GQF present on all 3 junction tables (AppDbContext lines 298, 310, 322) — no gap
  - OQ-2: RtsGridMetric is intentionally cross-tenant — confirmed by T1 CrossTenantEntitiesTests
  - OQ-3: `TokenService.CreateTokenPairAsync` accepts userId/tenantId/role/pgId directly

### Cumulative test coverage after T1 + T4 + T2 + T3
- **Tests.Security:** 204 passing, 0 failing, 0 skipped
- **Tests (solution total):** 285 passing
- **Security findings:** 7 (SF-001..007; SF-008 not needed)
- **Process deviations:** 5 (PD-001..005; PD-003, PD-005 resolved)
- **Total investment:** ~81 hours (T1 ~50h + T4 ~23h + #14 ~1h + T2 ~3h + T3 ~4h)

Details: `docs/sprints/T3-gap-analysis.md`, `docs/traceability-matrix.md` (ARCH-03, ARCH-08, AUTH-API-01, PWD-01..05).

---

## B1 #11 results — quick reference

### B1 #11 — commit `80974b0` (2026-05-25)
- **Files added:** `BackendEmulationDbContext.cs`, `Migrations/BackendEmulation/InitialBackendSchema` (+snapshot), `InfrastructureServiceExtensions` updated, `DatabaseInitializer` updated, `PostgresFixture` updated
- **DoD:** 7/7 ✅
- **Tests:** 247 / 247 pass (no regressions); 0 build warnings
- **Unblocks:** T3 (fully), T5 Phase B
- **Note:** Brief listed 11 DbSets, implementation includes 12 (all entities enumerated in brief §2 were included)


---

## T5 results — quick reference

### T5 — commit `fbf89fd` (2026-05-25)
- **Tests:** 28 new test cases (4 files in Tests.Security/Widgets/ + Infrastructure/)
  - `Widgets/WidgetCatalogTests.cs` — 6 tests (WGT-01 cross-tenant visibility, WGT-02/03 access control, deactivated items)
  - `Widgets/DashboardWidgetTests.cs` — 5 tests (WGT-04 lifecycle, soft-delete, GridId round-trip)
  - `Widgets/RtsGridLifecycleTests.cs` — 13 tests (Agent/Queue grid CRUD + dual-write API hook assertions)
  - `Infrastructure/SignalRTenantGuardTests.cs` — 4 tests (ARCH-09 TenantId guard)
- **`Tests` total after T5:** 313 passing, 0 failing, 0 skipped (solution-wide)
- **DoD:** 10/10 ✅
- **Production code added:**
  - `GridNotificationHub.cs` — SignalR Hub stub for ARCH-09 unit tests
  - Queue Grid entities in `RtsEntities.cs` for BeDb assertions
- **Security findings:** 0 (OQ-16 verified — no schema mismatch on `QueueId`)
- **Open questions resolved:**
  - OQ-16: `NgcBusinessUnitQueueClassification.QueueId` is string — no mismatch
  - OQ-17: `SaveQueueGridRtsCommand` exists
  - OQ-18: `GetWidgetCatalogQuery` correctly filters deactivated items for non-Superadmin

### Cumulative test coverage after T1 + T4 + T2 + T3 + T5
- **Tests (solution total):** 313 passing, 0 failing, 0 skipped
- **Security findings:** 7 (SF-001..007; no new SF in T3, T5)
- **Process deviations:** 5 (PD-001..005)
- **Total investment:** ~85 hours (T1 ~50h + T4 ~23h + #14 ~1h + T2 ~3h + T3 ~4h + T5 ~4h)

Details: `docs/sprints/T5-gap-analysis.md`, `docs/traceability-matrix.md` (WGT-01..04, ARCH-09).

---

## How to resume in a new session

1. **Read this file first** (you're doing it).
2. **Check memory** — `feedback_development_process.md`, `project_data_ownership.md`,
   `project_rtm_view_shell.md`, `feedback_rtm_workflow.md` carry the
   "how we work" rules and project invariants.
3. **Find current pending action:**
   - T1 ✅ T2 ✅ T3 ✅ T4 ✅ T5 ✅ all closed.
   - Pick next: **Backlog D1** (documentation catch-up: TS v1.3 EN docx, CHANGELOG,
     ADR-001..008 files, CLAUDE.md v1.3 bump) or define **T6**.
     Confirmed sequence complete: T1→T2→T4→T3→T5 ✅
   - Apply learning from PD-001..005 when authoring the next
     sprint's hand-off prompt:
     * Whitelist `partial class Program {}` for WAF-using sprints
       (PD-001), keep abort gate for everything else (PD-002).
     * Note: PD-003 resolved — `WebFixture` now clears
       `LoginRateLimitMiddleware` state automatically via
       `ClearLoginRateLimitState()` before each `LoginAsync()`.
     * Require `docs/sprints/T{N}-gap-analysis.md` as the **first**
       close-out artefact, not the last (PD-004).
     * After session recovery: check for truncated files before
       resuming work; use Python for file edits; see §0 CLAUDE.md (PD-005).
4. **For each sprint to start:** architect (Max) signs `Decision:`
   lines in §2 of the brief, then Claude Code runs Phase A handover
   prompt from §7.
5. **For #13:** regenerate from PD-002 if needed (low priority refactor).
   (B1 closed `80974b0`; #12 closed `5eab846`; #14 closed — see `docs/sprints/backlog-14-gap-note.md`)

---

## Open dependencies on external teams

- **Real backend SignalR protocol** (OQ-13 / OQ-Sim-1) — closes
  TS §7.9 placeholder; blocks `Session.RejectedLicenseLimit` channel
  = `SignalRWidget` test (deferred from T2 to T5).
- **Real backend REST API** for `IConfigurationApiHook` (OQ-14 /
  OQ-008-1) — replaces `NoOpConfigurationApiHook` stub; blocks
  dual-write payload assertions.
- **Backend team coordination** on `NGC_BusinessUnitQueueClassification`
  attributes (OQ-16 / OQ-010-3) — affects T3 / T5 row models.

These are project-management items; track them with backend team.

---

## Memory files in use

Located under your local `spaces/.../memory/` per Cowork conventions:

- `MEMORY.md` — index
- `project_rtm_view_shell.md` — project state (stack, structure, active areas)
- `project_data_ownership.md` — the 5-category table-ownership model + dev/prod boundary
- `feedback_rtm_workflow.md` — Cowork workflow patterns (RU dialog, skill copy, code-Q → CC prompt rule)
- `feedback_development_process.md` — full process discipline including sprint patterns + SF-NNN pattern + T1 ROI validation

When in doubt about "how do we do X here", read these.

T3 close-out: `docs/sprints/T3-gap-analysis.md` (DoD-1..9 verified, OQ-1..3 resolved).

---

## Last session ended at

2026-05-25, after T5 completion.

**T1 status:** ✅ fully closed (79 tests, 0 skips, 87.88% Infrastructure coverage, 4 SF + 2 PD).
**T4 status:** ✅ fully closed (46 new tests, SF-005 Critical fixed).
**T2 status:** ✅ fully closed (20 new tests, SF-006 + SF-007 fixed). 166 / 166 `Tests.Security` pass.
**T3 status:** ✅ fully closed (36 new tests, no SF-008). 204 Tests.Security pass, 285 solution-wide.
**T5 status:** ✅ fully closed (28 new tests, no SF). 313 solution-wide pass.

Documentation sync completed this session:
- `docs/sprints/T2-gap-analysis.md` created (DoD-13)
- `docs/traceability-matrix.md` updated (LIC-01, AUTH-WEB-03, AUTH-API-06, USR-09)
- `analysis/security-findings.md` updated (SF-006, SF-007)
- PD-005 documented (session interruption recovery)

Next: **new widget types** — RT vs Historical (RTSData_* tables, read-only). Awaiting RTSData_* table structures from CC. 2FA/SSO testing deferred to last.
D1: `b16d2e5` · T6: `22b087a`+`119b5a9` · #15: `bf8a79e`
T1 ✅ → T2 ✅ → B1#11 ✅ → T3 ✅ → T4 ✅ → T5 ✅ → T6 ✅ → #15 ✅ → #16 ✅ → #17 ✅ → #18 ✅ → #19 ✅ → #20 ✅

## D1 — Documentation Catch-up Results

**Commit:** b16d2e5 (2026-05-25)
**Deliverables:**

| # | Deliverable | Lines / Size | Status |
|---|---|---|---|
| 1 | ADR-001..ADR-008 (8 files in decisions/) | 88–104 lines each | Delivered |
| 2 | CHANGELOG.md | 177 lines | Delivered |
| 3 | docs/architecture/widget-framework.md | 319 lines | Delivered |
| 4 | docs/RTM-View-Shell-Stakeholder-Summary-v1.3.md | 141 lines | Delivered |
| 5 | docs/CC_Dashboard_Shell_TZ_v1.3_EN.docx | 30 KB | Delivered |
| 6 | CLAUDE.md footer bumped to TZ v1.3 / 2026-05-25 | 1 line | Delivered |

**ADR decisions recorded:** ADR-001 (widget catalogue scope), ADR-002 (nav menu), ADR-003 (licensing), ADR-004 (SignalR seam), ADR-005 (theming), ADR-006 (PG model redesign), ADR-007 (DB boundary), ADR-008 (dual-write)

**Total documentation added:** 1,378 insertions across 13 files
---

## Technical Debt Backlog

| ID | Issue | Impact | Priority |
|---|---|---|---|
| TD-001 | `Microsoft.EntityFrameworkCore.Relational` version conflict in `CcDashboard.Tests.Architecture` — MSB3277 warning on every build. Fix: align all EF Core package versions to 8.x across all .csproj files. | Warning only, build succeeds | Low |



---

## Checkpoint 2026-06-09 — Shell specialist + dark-mode (coordinator-0608)

**New:** standing specialist session **Shell + UI/UX** (`.coord/sessions/shell-0609.md`) — first of the
9-specialist roster. Owns Shell chrome, configurator modal, theming/dark-mode, RTL/i18n UI.
Skills: ux-ui-expert, frontend-design, blazor-frontend-design, blazor-server-expert, app-cyber-security-expert.

**First task issued (awaiting CC run):** configurator dark-mode parity — 9 operator-harvested gaps in the
widget Configure modal. Prompt: `tools/cc_prompt_shell_darkmode.md`. Spec: `tools/darkmode_config_gaps_0609.md`.
All gaps in `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor` + dark CSS `wwwroot/app.css`
(~2850-2913). Run: `Выполни задачу из файла tools/cc_prompt_shell_darkmode.md`.

**Claim handover:** `metrics-2-0607` (L2 i18n) + `test-5-0607` (dark-mode/MetricWizard) were doing UX/UI out
of lane -> set **on-hold**, ScreenEditorPage.razor EXCLUSIVE transferred to shell-0609 (operator decision).

**Queue (Cowork-A):** (1) devops-2 orchestrator consolidated patch — holes E-010 (self-describing per-server
deploy-state), E-015 (psql stderr + rollback-on-abort), E-016 (sig-agnostic NGC DROP), E-018 (kill orphan
CcDashboard.Web.exe). (2) Method charter v0.2 (Lab branch). (3) Cowork-B sync.

**Verified state:** 234 deploy GREEN (done). Push barrier cleared. No commit.lock. Full session map: `.coord/sessions/`.
