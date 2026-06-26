# CC — Columns OPTIONAL for v1 + server default-columns (coordinator ruling (b))
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-25T17:50Z, ruling (b)). Object-store-grounded: ReportWidgetConfigValidator Scope rules L22-39 STAY (SF-BI-001 intact); Columns rule L41 → remove NotEmpty (Columns optional); per-WidgetType DefaultColumns + RunReportWidgetQuery effective = config.Columns ?? DefaultColumns(type) so a Scope-only widget renders the standard set, not an error; 4 tests; NO migration; all process blocks present. This is the SOLE fix for the last v1 blocker (shell Save-gate is already scope-only — confirmed, no-op). Full Columns picker = v1.1. CLEARED TO RUN.

> Owner: role-bi (bi-0619). Execute: NATIVE CC. Branch: v3 (tip 1e3efce — checkout by SHA, §0.5). §4-bless BEFORE run.
> LAST blocker to a functional reports v1 editor: Columns required-but-stub disabled Save. Ruling (b): Columns OPTIONAL v1,
> server supplies default columns; full Columns picker -> v1.1. Touches the Ф2.5 validator + RunReportWidgetQuery path. NO migration. fix:.

## STEP 0 — integrity + branch-by-SHA (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git rev-parse HEAD
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do H=$(git show HEAD:"$f" 2>/dev/null|wc -l); W=$(wc -l <"$f" 2>/dev/null); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo "RESTORED $f"; } || echo "OK $f"; done; sync
```
## STEP 1 — reads (role-bi §A/§C + session-coord) + sync block (file-mode): slug bi-0619, claims:
`src/CcDashboard.Application/HistoricalReports/Validators/ReportWidgetConfigValidator.cs`,
`src/CcDashboard.Application/HistoricalReports/ReportWidgetConfig.cs` (if a DefaultColumns helper lands here),
`src/CcDashboard.Infrastructure/Handlers/RunReportWidgetQueryHandler.cs`,
`tests/CcDashboard.Tests.Unit/HistoricalReports/ReportWidgetConfigValidatorTests.cs` + `RunReportWidgetQueryTests.cs`. NO shell overlap.
## STEP 2 — binding PREAMBLE -> .coord/cc/bi.md.

## THE WORK
### A. Validator — Columns OPTIONAL
ReportWidgetConfigValidator: REMOVE the `RuleFor(x => x.Columns).NotEmpty()` ("Columns cannot be empty", ~L41-43).
Columns becomes optional (null/empty allowed). **Scope rules STAY required** (Mode + QueueIds/BusinessUnitIds — SF-BI-001
unaffected). pageSize/interval rules unchanged. A Scope-only ConfigJson (no Columns) is now VALID.

### B. Default columns per WidgetType (server)
Define a per-WidgetType DEFAULT/standard column set (derive from the existing row DTO fields per type — QueueIntervalRow,
QueueWaitTime, AgentMonthly, AgentShiftDetail, Distribution): a static `DefaultColumns(ReportWidgetType)` map.
In the RunReportWidgetQuery path: when ConfigJson.Columns is null/empty -> use that type's default set (so a Scope-only
widget renders the STANDARD columns, never an error). If the queries already return the full row (columns are a display
selection), expose the resolved column set on the result/handler so the frontend renders the default set when none chosen.
Keep it minimal — no per-column query projection change; just the "effective columns = config.Columns ?? DefaultColumns(type)".

### Tests
(1) Scope-only config (Columns null AND empty) = VALID (validator); (2) RunReportWidgetQuery with no Columns -> effective
columns = DefaultColumns(WidgetType) for each of the 5 types; (3) Columns-present (subset) still honoured; (4) Scope rules
still enforced (missing Mode/QueueIds/BU still invalid).

## ACCEPTANCE: Soma /ops/build 0 + /ops/test?suite=unit GREEN (validator + default-columns tests) + serilog. Scope-only widget valid + renders default columns. SF-BI-001 scope rules intact. NO migration. Full Columns picker = v1.1 backlog (note).
## STEP 3 — binding POSTAMBLE RESULT -> cc/bi.md (commit, build/test). §0.6b CAPTURE if lesson. cc_post_commit.sh + §0.6/PD-007.
## COMMIT: fix: (Columns optional + default-columns), commit.lock 5x60s, object-store verify, NO push (§37, bundled barrier).
