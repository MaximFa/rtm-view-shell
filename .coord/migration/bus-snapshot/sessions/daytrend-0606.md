---
session: RTM DayTrend Debug2
slug: daytrend-0606
started: 2026-06-06T08:10:00Z
heartbeat: 2026-06-06T23:55:33Z
status: done
role: work
modules: []
files: [docs/RTMViewShell_SecurityOverview.docx, db/functions/02_rtsdata_functions.sql, db/migrations/20260606_008_daytrend_fn_bu_scope.sql, src/CcDashboard.Infrastructure/Handlers/DayTrendQueryHandler.cs, src/CcDashboard.Application/Queries/Widgets/DayTrendQuery.cs, src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor]
cc_task: none
---
Task: debug DayTrend Widget historical agent data — full chain from RTM Service DB write
to Shell display.

taken over by Debug2 after predecessor hung, 2026-06-06 (operator-confirmed; predecessor made
no commits). Slug, claims and scope preserved unchanged.

Claims: rtm in FILE-MODE (not whole module) because metrics-0605 holds RTM/RTM/Union.cs and
RTM/RTM/UserManager.cs in file-mode (calc quarantine). I read those freely; if the bug lands
in their calc logic I file a §9 REQUEST before any write.
web in file-mode: DayTrend components + RtmRelayService chain.

Watch (operator note): metrics holds web catalogue files. On collision with shared web files
(Program.cs, NavMenu.razor, RtsEntities.cs) -> §9 queue, never parallel.
Investigation phase is read-only; write-claims above gate commits only.

superseded by daytrend-2-0607 (takeover 2026-06-07); claims migrated.
