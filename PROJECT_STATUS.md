# RTM View Shell — Project Status (session snapshot 2026-05-25)

**Purpose:** quick orientation for any contributor (human or agent)
resuming work. Read this first, then drill into the linked artefacts.

---

## Current state

**v1.3 release: ✅ DELIVERED.**
**Test-coverage programme (T1..T5): T1 ✅ + T4 ✅; T2 / T3 / T5 awaiting starts.**

| Track | Status |
|---|---|
| TS v1.3 EN (docx) | ✅ `CC_Dashboard_Shell_TZ_v1.3_EN.docx` |
| 12 ADRs | ✅ `decisions/ADR-001..ADR-012` (all Accepted) |
| CHANGELOG | ✅ `CHANGELOG_v1.2-to-v1.3.md` |
| Traceability matrix | ✅ `docs/traceability-matrix.md` (T1 + T4 reflected) |
| Stakeholder summary | ✅ `docs/v1.3-stakeholder-summary.md` |
| Widget architecture | ✅ `analysis/widgets/architecture.md` |
| CLAUDE.md (v1.3 sync) | ✅ updated |
| Security findings (SF-001..005) | ✅ `analysis/security-findings.md` |
| Process deviations (PD-001..004) | ✅ `analysis/process-deviations.md` |

---

## Sprint inventory

| Sprint | Subject | Status | Next action |
|---|---|---|---|
| **T1** | Security & cross-tenant isolation | **✅ FULLY CLOSED. Phase A + B + C complete (79 tests, 0 skips, 87.88% Infrastructure coverage, 4 SF + 2 PD found).** | Sprint done; pick next |
| **T2** | Licensing enforcement (~25 tests) | Brief draft, §2 micro-choices need architect sign-off | Sign §2 → Claude Code |
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

## How to resume in a new session

1. **Read this file first** (you're doing it).
2. **Check memory** — `feedback_development_process.md`, `project_data_ownership.md`,
   `project_rtm_view_shell.md`, `feedback_rtm_workflow.md` carry the
   "how we work" rules and project invariants.
3. **Find current pending action:**
   - T1 fully closed; T4 fully closed (Backlog #14 fixed PD-003).
   - Pick next: **T2** (Licensing, no blockers), **B1 #11** to
     unblock T3 / T5, or **#12** (15-min skill drift fix).
   - Apply learning from PD-001..004 when authoring the next
     sprint's hand-off prompt:
     * Whitelist `partial class Program {}` for WAF-using sprints
       (PD-001), keep abort gate for everything else (PD-002).
     * Note: PD-003 resolved — `WebFixture` now clears
       `LoginRateLimitMiddleware` state automatically via
       `ClearLoginRateLimitState()` before each `LoginAsync()`.
     * Require `docs/sprints/T{N}-gap-analysis.md` as the **first**
       close-out artefact, not the last (PD-004).
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

2026-05-25, after Backlog #14 fix.

**T1 status:** ✅ fully closed (79 tests, 0 skips, 87.88% Infrastructure coverage, 4 SF + 2 PD).
**T4 status:** ✅ fully closed (46 new tests, SF-005 Critical fixed). 146 / 146 `Tests.Security` pass. PD-003 resolved via Backlog #14.

Documentation sync completed this session: PD-003 marked resolved in
`process-deviations.md`, traceability matrix totals updated to 146/146,
`docs/sprints/backlog-14-gap-note.md` created, backlog #14 closed.

Next: pick **T2** (Licensing — no blockers), **B1 #11** (refactor that
unblocks T3 / T5 Phase B), or **#12** (widget-creator drift, 15-min
context switch).
