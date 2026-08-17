---
session: RTM shell (UI/UX)
slug: shell-0609
role: shell
status: active
started: 2026-06-25T19:33Z
heartbeat: 2026-07-02T04:59:47Z
resumed_at: 2026-06-26T00:00Z
claims: [web]   # src/CcDashboard.Web/ (Components, Pages, wwwroot/js, app.css, Resources/*.resx)
cc_task: none
---

# shell-0609 — ACTIVE (resumed from handoff under ЧП)

INIT runbook complete (this turn):
- §0.2 integrity: restored 15 PD-007-truncated code/test files + 1 CRLF-drift file (ReportEditorPage.razor) from HEAD via object-store. PROJECT_STATUS.md WT>HEAD (+1, real B-UX-1 row, not mine, not touched). Installations/* D = not mine.
- role-shell §A read (ЧП ACTIVE at top). §C VERIFY 5/5 PASS (widget-resize.js, .dark-mode=116, IRtmRelayService=4, ScreenEditorPage, resx=3). No supersessions.
- session-coord read (§1/§10, ЧП shorthand . / ..).
- Bus read: no push barrier; cc/shell.md last RESULT consumed 18:55; inbox read.

## Current task (ЧП, no-run-without-bless)
Root-cause by OBJECT-STORE the 6 reports-editor defects (G-MOVE/G-MULTIADD/G-RESIZE/G-PLACE-ERR/G-THRESH/G-APPEAR) + PARAMOUNT G-DATA (data output unverifiable — the whole package targets data output; bi STEP-1 seed-vehicle in flight).
Acceptance bar = docs/Reports-v1-Acceptance-Checklist-and-Gap-Plan.md (36 VCs). Columns = v1.1.
Output = root-cause + per-defect fix plan → coordinator §4. Do NOT run anything. Reports v1 frontend OPEN until full functional pass GREEN.

## Claims
release-owner of web (src/CcDashboard.Web/). Parity-guard: never edit ScreenEditorPage/ScreenFullscreenPage/widget-resize.js shared base or shared app.css selectors when fixing reports — report-scoped only.

## Delivered + unpushed (mine, all in v3 log; NONE pushed)
50f27a5, fd73c1c, 1aa65d1, d0fb4dd, 582563d, 33a4f8d, a3a0d25, 298fdc0 — all §4-PASS + object-store verified.
> predecessor HANDOFF block consumed by this (same-slug) resume 2026-06-26T00:00Z.


## 2026-07-06T10:58:06Z | heartbeat + TEMP file-mode claim (ASD missing-grid guard, coordinator-0703 §4-BLESS + territory ruling: shell commits)
status: active · cc_task: none · heartbeat: 2026-07-06T10:58:06Z
TEMP file-mode claim (Application/Infra — coordinator verified NO active claim; backend-0626/bi-0626 idle cc_task=none, no open CC binding on these files):
claims-temp:
  - src/CcDashboard.Application/Interfaces/IRtsRepository.cs
  - src/CcDashboard.Infrastructure/Persistence/Repositories/RtsRepository.cs
  - src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs
  - tests/CcDashboard.Tests.Unit/** (new recreate test)
Released on guard commit. Also holding web (release-owner). Two run-boxes out: asd_bar_blur + asd_missing_grid_guard.

## 2026-07-06T19:16:02Z | RELEASE temp guard file-mode claim — guard+test committed (21ecb84,12480b2). heartbeat 2026-07-06T19:16:02Z. status active, cc_task none. Holding web (release-owner) only.

## 2026-07-13T01:21:32Z | RESUME heartbeat (was stale 07-02) — status active, cc_task none. Holding [web] (release-owner). Task: TENANT-RESOLUTION fallback authored → §4-review. Program.cs NOT touched (backend 72882f0).
