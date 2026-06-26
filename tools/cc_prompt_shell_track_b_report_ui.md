# CC task — Track B: Historical Reports UI (role-shell) — DRAFT for coordinator §4-review (do NOT execute pre-§4)
> Per §26.8: SUBMITTED for §4-review BEFORE execution. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`. **NO push** (§37).
> §4-PASS: coordinator-0622 2026-06-21T22:52:50Z — web/frontend-only; bound EXACTLY to Q1/Q5/A4/A5 + DTOs; SF-BI-001 server-scope respected (UI never re-filters/widens); NO App/Infra/Domain/db edits (clean of dba step-0); branch-v3 integrity; §0.3/commit.lock/binding/NO-push present. DECISION menu.reports = DEFER ([Authorize]-only v1, data scope-safe; PG-key=separate backend+docs task). EXECUTE authorized (native CC, v3).
> Unblocked by SF-BI-001 GATE CLOSED (53aa308 — ReportScopeResolver + repo non-bypassable, 11 tests). Track A data layer is DONE; Track B = the UI ONLY, on top of the existing MediatR queries. Claim web/frontend ONLY — no Application/Infrastructure/Domain/db edits (no overlap with dba step-0).

## INIT — branch v3 + role-shell §A/§C + §40
- **BRANCH RULE (coordinator-0622 BRANCH SYNC 22:39, no exceptions):** Track B / BI / reports = the **v3** line. FIRST: `git checkout v3` then verify `git rev-parse --abbrev-ref HEAD` = v3 + `git rev-parse v3` resolves (OBJECT-STORE, never mount `git status`). Do NOT let work cross to v2-backend. (v2-backend = backend trunk: Garnet/Redis/MaintenanceService/incident/RTM-DB — NOT this task.)
- **§0.2 integrity FIRST (v3):** `cat .git/HEAD` must be `ref: refs/heads/v3`; `cat .git/refs/heads/v3` resolves (8392e56-era). The mount FAILS `git rev-parse HEAD` on the fresh v3 ref (L-SC-04 read-loss) though `git status` works — verify NATIVELY (Windows CC), do NOT escalate as corruption.
- role-shell INIT §A + §C-green before acting. §40 skills (widget-planner/widget-creator/session-coord).
- POST-VERIFY by RELIABLE floor (cat + git show HEAD + git hash-object vs git rev-parse HEAD:<f>), NOT -f/-s stat (mount phantoms).

## §42.6 sync — slug shell-0609 (claims web/frontend only)
- S1 push-barrier: `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> STOP if match.
- S2 claims (coord_check_claims shell-0609 each):
  NEW: src/CcDashboard.Web/Components/Reports/ReportsPage.razor (landing + tab host)
  NEW: src/CcDashboard.Web/Components/Reports/QueueIntervalReport.razor
  NEW: src/CcDashboard.Web/Components/Reports/QueueWaitTimeReport.razor
  NEW: src/CcDashboard.Web/Components/Reports/AgentMonthlyReport.razor
  NEW: src/CcDashboard.Web/Components/Reports/AgentShiftDetailReport.razor
  NEW: src/CcDashboard.Web/Components/Reports/ReportFilterBar.razor (shared date-range + paging + optional filter)
  EXISTING (mine): src/CcDashboard.Web/Components/Layout/NavMenu.razor, src/CcDashboard.Web/wwwroot/app.css, src/CcDashboard.Web/Components/App.razor (css?v bump), 3× Resources/SharedResources.{en-US,ru-RU,he-IL}.resx
- S3 commit.lock around git add/commit (owner shell-0609). S4 cc_post_commit.sh. S5 NO push.
- §0.3 Edit BANNED — Python read/modify/write + os.fsync; verify by cat/git.

## GROUNDING (object-store — the layer you build ON, do NOT modify it)
SF-BI-001: ALL filtering is server-enforced in HistoricalReportHandlers via IReportScopeResolver (ResolveQueueScopeAsync/ResolveAgentScopeAsync). The UI just dispatches the query and renders rows — it MUST NOT re-implement scope/filtering and MUST NOT try to widen scope. Empty client filter = handler applies the user's full allowed scope; out-of-scope client entries are dropped server-side.

4 MediatR queries (src/CcDashboard.Application/HistoricalReports/Queries/) — request + result records (bind UI to these EXACTLY):
- **Q1 GetQueueIntervalReportQuery**(From, To, IReadOnlyList<string>? Workgroups, PageSize=100, Page=1) -> QueueIntervalReportResult(Rows, TotalCount, Page, PageSize); QueueIntervalRow(IntervalStart, Workgroup, QueueId?, Offered, Answered, Abandoned, AnsweredInSl, SumWaitAnswered, SumTalk, AbandonPct?, SlPct?, Asa?, QueueAht?)
- **Q5 GetQueueWaitTimeReportQuery**(From, To, Workgroups?, PageSize, Page) -> QueueWaitTimeReportResult(Rows, TotalCount, Page, PageSize, OverallAsa?); QueueWaitTimeRow(IntervalStart, Workgroup, Answered, SumWaitAnswered, Asa?, AnsweredInSl, SlPct?)
- **A4 GetAgentMonthlyReportQuery**(From, To, IReadOnlyList<string>? AgentExternalIds, PageSize, Page) -> AgentMonthlyReportResult(Rows, TotalCount, Page, PageSize); AgentMonthlyRow(YearMonth, AgentExternalId, AgentDisplayName?, Sum{Available,Onphone,Hold,Paperwork,Break,Training,LoggedIn}Ms, Handled, OccupancyPct?, AgentAht?, HoldPct?)
- **A5 GetAgentShiftDetailReportQuery**(From, To, AgentExternalIds?, PageSize, Page) -> AgentShiftDetailReportResult(...); AgentShiftDetailRow(IntervalStart, AgentExternalId, AgentDisplayName?, Sum*Ms..., Handled, OccupancyPct?, AgentAht?, HoldPct?, TalkPureMs)

IDENT (CLAUDE.md §46): queues keyed by NGC ExternalId (= Workgroup), agents by AgentExternalId — these are EXTERNAL CC ids, NOT ApplicationUser.Id.

## THE WORK — Track B UI
1. **ReportsPage.razor** `@page "/reports"` `@rendermode InteractiveServer` `@layout MainLayout` `@attribute [Authorize]` `@inject IMediator Mediator` `@inject IStringLocalizer<SharedResources> L`. Tab host for the 4 reports (Queue Interval, Queue Wait Time, Agent Monthly, Agent Shift Detail). All authenticated roles may open; data is auto-scoped by the resolver (Viewer/Editor/Admin = PG scope, Superadmin = full).
2. **ReportFilterBar.razor** (shared): From/To date pickers (default e.g. last 7 days), optional free-text/multi CSV of workgroups or agent-ids (v1: optional text -> split to list; leave empty = full allowed scope), PageSize selector (25/50/100), prev/next paging. Raises an event the host handles to (re)dispatch.
3. **Each <X>Report.razor**: on filter-apply, `await Mediator.Send(new Get...Query(From,To,filterList,PageSize,Page))`; render rows in a Bootstrap `table-responsive` `table-sm`; format ms columns to h:mm:ss (or mm:ss) and pct to 1 decimal; show TotalCount + page indicator; empty-state + loading spinner; surface a friendly "no data / out of scope" message when Rows empty. (QueueWaitTime: show OverallAsa header.)
4. **NavMenu.razor**: add a Reports NavLink (href "/reports"). Placement: a new `Nav_Reports` section OR under Content — your call; use @L for the label. NOTE/FLAG (do NOT silently add a permission key): there is NO `menu.reports` in the documented menu-key set (CLAUDE.md §6) — for v1 gate by `[Authorize]` only (data is scope-safe regardless). The `menu.reports` PG key + PermissionGroupsPage row + seed = a SEPARATE cross-territory decision; do not add it here.
5. **app.css**: report table styles, dark-mode + RTL (logical props) parity. **App.razor**: app.css?v bump.
6. **resx (3 locales)**: ALL strings via @L (I18N-03) — report titles, column headers, filter labels, empty/loading text. EN capitalised; provide real ru-RU + he-IL (not EN placeholders).

## OUT OF SCOPE v1 (flag as follow-ups, do NOT build)
- CSV/Excel export (AUD-08 async-job path) — v2.
- Scoped picker dropdowns populated from the user's allowed workgroups/agents (v1 = optional free-text filter; empty = all-allowed). A scope-list endpoint would be a small Application add = separate task.
- Charts/visualisations — tables only in v1.

## VERIFY (build-cite or honest 'not run')
- Object-store: 6 new razor files present; each report dispatches the correct MediatR query and binds the exact result DTO; NavMenu has /reports; no edits under Application/Infrastructure/Domain/db (git diff --name-only -> only Components/Reports, NavMenu, app.css, App.razor, 3 resx).
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line; else honest "BUILD: not run (no dotnet)".** @inject/@using guard (IMediator, IStringLocalizer, the Queries namespace) — CS0103/CS0246 check.
- Confirm every @L key resolves in all 3 resx.

## Acceptance (product floor — operator 5239)
Open /reports -> 4 tabs render; pick a date range -> each report returns scoped rows + pagination works; a Superadmin sees full data, a PG-scoped user sees ONLY their queues/agents (server-enforced — do not test by trying to widen in the UI); empty filter = full allowed scope; light+dark+RTL.

## §0.6b CAPTURE -> role-shell §B if a real lesson (e.g. report UI binds to server-scoped MediatR results; never re-filter client-side — SF-BI-001 scope is the floor).

## Commit (feat:, NO push) under commit.lock: pre-commit-check -> git add (6 new + NavMenu + app.css + App.razor + 3 resx, + role-shell.md if CAPTURE -f) -> commit -m "feat(web): Historical Reports UI Track B — 4 PG-scoped report views on ReportScopeResolver layer (SF-BI-001) [shell-0609]" -> §0.6 post-commit (git show HEAD) -> cc_post_commit.sh shell-0609 <hash> -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; 6 razor + NavMenu + css + resx; each report -> its MediatR query/DTO; no app/infra/domain/db edits; build cite OR 'not run'; menu.reports key FLAGGED not added; CAPTURE if any. NO push. verified: object-store.

## Report (chat): commit hash; files; build line OR honest not-run; restate scope server-enforced (SF-BI-001); menu.reports key flagged as cross-territory; product-floor = operator 5239. NO push.
