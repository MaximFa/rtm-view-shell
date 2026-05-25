# RTM View Shell — Project Status (session snapshot 2026-05-25)

**Purpose:** quick orientation for any contributor (human or agent)
resuming work. Read this first, then drill into the linked artefacts.

---

## Current state

**v1.3 release: ✅ DELIVERED.**
**Test-coverage programme (T1..T5): in execution (T1 Phase A done; B pending).**

| Track | Status |
|---|---|
| TS v1.3 EN (docx) | ✅ `CC_Dashboard_Shell_TZ_v1.3_EN.docx` |
| 12 ADRs | ✅ `decisions/ADR-001..ADR-012` (all Accepted) |
| CHANGELOG | ✅ `CHANGELOG_v1.2-to-v1.3.md` |
| Traceability matrix | ✅ `docs/traceability-matrix.md` |
| Stakeholder summary | ✅ `docs/v1.3-stakeholder-summary.md` |
| Widget architecture | ✅ `analysis/widgets/architecture.md` |
| CLAUDE.md (v1.3 sync) | ✅ updated |
| Security findings (SF-001..003) | ✅ `analysis/security-findings.md` |

---

## Sprint inventory

| Sprint | Subject | Status | Next action |
|---|---|---|---|
| **T1** | Security & cross-tenant isolation | **Phase A ✅ (32 tests, 86.3% cov, 3 SF found); Phase B awaiting Claude Code** | Run T1 Phase B handover prompt (saved in session log; also see brief §7) |
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

## T1 Phase A results — quick reference

- **Commit:** `ca0ccd9` — `test(Sprint T1A): tenancy + web auth foundation...`
- **Tests:** 32 passing, 3 skipped (golden-path → Phase B), 0 failing
- **Coverage:** 86.3% Infrastructure (target 60%)
- **DoD:** 5/5 ✅
- **Production bugs found:** 3 (SF-001 Critical, SF-002/003 High) — all fixed in same commit

Details: `docs/sprints/T1-gap-analysis-phase-a.md` and `analysis/security-findings.md`.

---

## How to resume in a new session

1. **Read this file first** (you're doing it).
2. **Check memory** — `feedback_development_process.md`, `project_data_ownership.md`,
   `project_rtm_view_shell.md`, `feedback_rtm_workflow.md` carry the
   "how we work" rules and project invariants.
3. **Find current pending action:**
   - T1 Phase B awaiting Claude Code execution → use the handover
     prompt structure (see `docs/sprints/T1-security-and-tenant-isolation.md`
     §7 Phase B + the post-Phase-A approval message in the prior
     session).
   - OR pick another sprint (T2/T4 no blockers; T3/T5 blocked by B1).
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

2026-05-25, immediately after Phase A T1 review approval and Phase B
handover prompt preparation. No outstanding write actions on my side.

If you (architect) are reading this: next sensible step is to paste
the T1 Phase B handover prompt into Claude Code, or to start any
parallel sprint (T2 / T4 — no blockers).
