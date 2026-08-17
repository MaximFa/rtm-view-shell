# .coord/queue.md — file-claim queue (FIFO). Spec: skill session-coord §9.
# Format:
# <UTC> | REQUEST | <path> | wants: <slug> | holder: <slug> | <note>
# <UTC> | GRANT   | <path> | to: <slug>
2026-06-06T07:50Z | REQUEST | db/migrations/20260606_001_metrics_defect_fixes.sql | wants: metrics-0605 | holder: test4-0606 | new defect-fix migration (CurLoginTimeStamp dead metric)
2026-06-06T07:59Z | COORD-NOTE | tools/metric_longdesc_catalogtype.tsv | arbiter: session-sync-0605 | handoff to metrics-0605 (keep untracked; metrics decides keep-or-discard — derived from committed docs/metrics-catalog.json). test4 does NOT commit it.
2026-06-06T07:59Z | COORD-NOTE | db/migrations/20260606_001_metrics_defect_fixes.sql | arbiter: session-sync-0605 | belongs to metrics-0605 (EF Code-First: needs entity+migration, web+db). Transfer to metrics; test4 out of scope.
2026-06-06T08:03Z | ACCEPT | db/migrations/20260606_001_metrics_defect_fixes.sql | by: metrics-0605 | taken into claims; will redo as EF/seed-consistent fix (MAINT-04), not raw SQL
2026-06-06T08:03Z | ACCEPT | tools/metric_longdesc_catalogtype.tsv | by: metrics-0605 | taken into claims; likely regenerated from docs/metrics-catalog.json, keep-or-discard decided in Stage 2
2026-06-07T12:57:13Z | REQUEST | db/functions/02_rtsdata_functions.sql | wants: devops-2-0607 | holder: daytrend-2-0607 | RTM-SEC-002: RTSData_SetInteraction is stale FUNCTION, must become PROCEDURE (fresh-install 42809 fix)
2026-06-07T14:09:08Z | REQUEST | src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | wants: daytrend-2-0607 | holder: metrics-2-0607 | add 2 UNAVAILABLE entries to GetDefaultDayTrendAgentMetrics (P3 config-UI gap: fn emits them, widget has colors, config modal lacks toggles)
2026-06-07T14:10:42Z | GRANT | db/functions/02_rtsdata_functions.sql | to: devops-2-0607 | by: daytrend-2-0607 | my P3 fn_daytrendagentstatus work committed+pushed (74db217, ==HEAD origin/v2=fae4845); removed from my claims, file is clean. Re-read from fresh HEAD before editing.
2026-06-07T14:38Z | COORD-NOTE | src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | arbiter: coordinator-0606 | DEFER post-release: UNAVAILABLE config-toggles (daytrend wants, metrics holds) is fast-follow, NOT release-1 critical. Release-set frozen to fae4845+repo-fix. Re-open after Full PG17 build is cut.
2026-06-08T18:10:04Z | WITHDRAW | src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | by: daytrend-2-0607 | ack coordinator DEFER (14:38 COORD-NOTE): UNAVAILABLE config-toggles = post-release fast-follow; standing down the active request, will re-open after Full PG17 build. exact 2-line diff is in coordinator inbox 14:09.
---
## REQUEST | 2026-06-09T11:30Z | requester: backend-0609

Resource: db/functions/01_ngc_functions.sql
Holder: devops-2-0607
Reason: NGC INSERT Id-fix E-004 (23502 NULL violation on NGC_Queues/NGC_AgentGroups — missing Id + IsActive in INSERT)
Action when released: add Id=gen_random_uuid(), IsActive=true to INSERT in NGC_GetOrCreateQueue + NGC_GetOrCreateAgentGroup
Notes: coordinator-0609 arbitrating; backend is SECOND in queue (devops FIRST with E-016 sig-agnostic DROP)
Status: WAITING
2026-06-12T07:00:00Z | REQUEST | db/setup/02_catowner_role.sql | wants: devops-2-0607 | holder: dba-0610 | server-45 BLOCKER fix DEFECT-1 (psql :'var'-in-DO -> session GUC); coordinator-0612 directive cc_prompt_fix_applysvc_provision_0612.md
2026-06-12T09:19Z | GRANT | db/setup/02_catowner_role.sql | to: devops-2-0607 | holder dba-0610 DORMANT (HB 06-10, >3h) + operator-authorised ('подключай девопса'); coordinator-0612 arbitration
