# RTM View Shell — Project Status (session snapshot 2026-05-25)

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
| **T3** | Multi-tenancy integration (~30 tests) | Brief draft, §2 + **blocked by B1 #11** | Complete B1, sign §2 |
| **T4** | PG authorization semantics | **✅ CLOSED (commit `cb7af32`, 46 tests, SF-005 Critical fixed). 146 / 146 Tests.Security pass. PD-003 resolved via Backlog #14.** | Sprint done; pick next |
| **T5** | Widget framework (~30 tests) | Brief draft, §2 + Phase B blocked by B1 #11 | Sign §2; Phase A can start without B1 |

Briefs live in `docs/sprints/T{1..5}-*.md`.

---

## Code follow-on backlog

| ID | Task | Prompt status | Unblocks |
|---|---|---|---|
| **B1 (#11)** | Introduce `BackendEmulationDbContext` per ADR-007 | Prompt ready (see session 2026-05-17 log) | T3, T5 Phase B |
| **#12** | Widget-creator skill MetricType drift fix | Prompt ready (~15 min Claude Code task) | None |
| **#13** | `DatabaseInitializer` → `IDatabaseInitializer` interface (replace `virtual`) | Pending; spawned by PD-002 (T1 Phase C). Low priority, refactor only. | None |
| **#14** | `WebFixture`: disable `LoginRateLimitMiddleware` in test pipeline | **✅ CLOSED.** Reflection-based clearing of middleware static state. 146/146 tests pass. | — |
| **D1** | Documentation catch-up: TS v1.3 EN docx, CHANGELOG v1.2→v1.3, ADR-001..008 files (currently only `_index.md` placeholders), stakeholder summary, widget architecture, CLAUDE.md frontmatter bump to v1.3 | Pending; created 2026-05-25 after sanity-check finding (see Current state §). Sizing rough ~70h depending on TS depth. Architect decision required: full doc catch-up vs partial (just CHANGELOG + minimal ADR skeletons) vs defer until external review demands it. | External v1.3 review readiness; T5 (widget architecture is input) |

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

## How to resume in a new session

1. **Read this file first** (you're doing it).
2. **Check memory** — `feedback_development_process.md`, `project_data_ownership.md`,
   `project_rtm_view_shell.md`, `feedback_rtm_workflow.md` carry the
   "how we work" rules and project invariants.
3. **Find current pending action:**
   - T1 fully closed; T4 fully closed; T2 fully closed.
   - Pick next: **B1 #11** to unblock T3 / T5 Phase B, or
     **#12** (15-min skill drift fix), or **T5** Phase A (can start
     without B1).
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
       resuming work (PD-005).
4. **For each sprint to start:** architect (Max) signs `Decision:`
   lines in §2 of the brief, then Claude Code runs Phase A handover
   prompt from §7.
5. **For B1 / #12 / #13:** copy the prompt from session log;
   if lost, regenerate from ADR-007 / CLR-15 / PD-002
   respectively. (#14 closed — see `docs/sprints/backlog-14-gap-note.md`)

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

---

## Last session ended at

2026-05-25, after T2 completion.

**T1 status:** ✅ fully closed (79 tests, 0 skips, 87.88% Infrastructure coverage, 4 SF + 2 PD).
**T4 status:** ✅ fully closed (46 new tests, SF-005 Critical fixed).
**T2 status:** ✅ fully closed (20 new tests, SF-006 + SF-007 fixed). 166 / 166 `Tests.Security` pass.

Documentation sync completed this session:
- `docs/sprints/T2-gap-analysis.md` created (DoD-13)
- `docs/traceability-matrix.md` updated (LIC-01, AUTH-WEB-03, AUTH-API-06, USR-09)
- `analysis/security-findings.md` updated (SF-006, SF-007)
- PD-005 documented (session interruption recovery)

Next: pick **T3** (Multi-tenancy — blocked by B1 #11), **T5** (Widget framework),
**B1 #11** (refactor that unblocks T3 / T5 Phase B), or **#12** (widget-creator
drift, 15-min context switch).
