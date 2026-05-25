# RTM View Shell — Project Status (session snapshot 2026-05-25)

**Purpose:** quick orientation for any contributor (human or agent)
resuming work. Read this first, then drill into the linked artefacts.

---

## Current state

**v1.3 release: ✅ DELIVERED.**
**Test-coverage programme (T1..T5): in execution (T1 Phase A + B done; Phase C decision pending).**

| Track | Status |
|---|---|
| TS v1.3 EN (docx) | ✅ `CC_Dashboard_Shell_TZ_v1.3_EN.docx` |
| 12 ADRs | ✅ `decisions/ADR-001..ADR-012` (all Accepted) |
| CHANGELOG | ✅ `CHANGELOG_v1.2-to-v1.3.md` |
| Traceability matrix | ✅ `docs/traceability-matrix.md` (extended after T1 Phase B) |
| Stakeholder summary | ✅ `docs/v1.3-stakeholder-summary.md` |
| Widget architecture | ✅ `analysis/widgets/architecture.md` |
| CLAUDE.md (v1.3 sync) | ✅ updated |
| Security findings (SF-001..004) | ✅ `analysis/security-findings.md` |

---

## Sprint inventory

| Sprint | Subject | Status | Next action |
|---|---|---|---|
| **T1** | Security & cross-tenant isolation | **Phase A ✅ + Phase B ✅ (61/8 tests, 86.88% cov, 4 SF found). Phase C ready for execution — §2 signed 2026-05-25; hand-off prompt dispatched to Claude Code.** | Wait for Claude Code Phase C completion → close-out per §8 |
| **T2** | Licensing enforcement (~25 tests) | Brief draft, §2 micro-choices need architect sign-off | Sign §2 → Claude Code |
| **T3** | Multi-tenancy integration (~30 tests) | Brief draft, §2 + **blocked by B1 #11** | Complete B1, sign §2 |
| **T4** | PG authorization semantics (~20 tests) | Brief draft, §2 needs sign-off | Sign §2 → Claude Code |
| **T5** | Widget framework (~30 tests) | Brief draft, §2 + Phase B blocked by B1 #11 | Sign §2; Phase A can start without B1 |

Briefs live in `docs/sprints/T{1..5}-*.md`.

---

## Code follow-on backlog

| ID | Task | Prompt status | Unblocks |
|---|---|---|---|
| **B1 (#11)** | Introduce `BackendEmulationDbContext` per ADR-007 | Prompt ready (see session 2026-05-17 log) | T3, T5 Phase B |
| **#12** | Widget-creator skill MetricType drift fix | Prompt ready (~15 min Claude Code task) | None |

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

### Phase B — commit `b846f1b` (2026-05-25)
- **Tests:** 61 passing, 8 skipped (golden-path requires WebApplicationFactory → Phase C), 0 failing
- **Coverage:** 86.88% Infrastructure (target 60%)
- **DoD:** 6/7 ✅, 1/7 ⚠ (DoD-11 LICENSE-SESSION rejection-path only; success path needs WAF)
- **Production bugs found:** 1 (SF-004 Medium — JTI revocation crash on zero TTL)

### T1 totals (Phase A + B combined)
- **Tests:** 61 passing, 8 skipped — all 8 skips are documented and require Phase C / WAF
- **Coverage:** 86.88% on `CcDashboard.Infrastructure`
- **Security findings:** 4 (SF-001..004) — all fixed in the respective phase commits

Details: `docs/sprints/T1-gap-analysis-phase-a.md`, `docs/sprints/T1-gap-analysis-phase-b.md`, and `analysis/security-findings.md`.

---

## How to resume in a new session

1. **Read this file first** (you're doing it).
2. **Check memory** — `feedback_development_process.md`, `project_data_ownership.md`,
   `project_rtm_view_shell.md`, `feedback_rtm_workflow.md` carry the
   "how we work" rules and project invariants.
3. **Find current pending action:**
   - T1 Phase A + B both closed. **Architect decision needed on
     Phase C** — 8 skipped golden-path tests require
     `WebApplicationFactory` to exercise the full ASP.NET Core auth
     pipeline. Options: (a) Phase C brief now, (b) fold the 8 tests
     into T3 (multi-tenancy integration brings WAF anyway), or
     (c) defer with documented skip rationale.
   - In parallel: pick T2 / T4 (no blockers) or queue B1 #11 to
     unblock T3 / T5.
4. **For each sprint to start:** architect (Max) signs `Decision:`
   lines in §2 of the brief, then Claude Code runs Phase A handover
   prompt from §7.
5. **For B1 / #12:** copy the prompt from session log; if lost,
   regenerate from ADR-007 + CLR-15 respectively.

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

2026-05-25, after T1 Phase B close-out (commit `b846f1b`) and
authoring of T1 Phase C brief. Documentation sync done: SF-004 commit
ref recorded in `analysis/security-findings.md`, traceability matrix
extended with AUTH-API / BFP / LICENSE-SESSION rows, this status doc
refreshed, Phase C brief at `docs/sprints/T1-phase-c.md`.

Architect: open `docs/sprints/T1-phase-c.md` §2 — four `TBD`
decisions (MC-C1 WAF variant, MC-C2 cookie handling, MC-C3 HTTPS,
MC-C4 fixture reuse). Once signed, §7 hand-off prompt is ready to
paste into Claude Code. T2 and T4 remain valid parallel starts with
no blockers.
