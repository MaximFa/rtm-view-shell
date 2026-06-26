# CC task — Ф5b-2 FIX R3 (shell, defensive): ReportWidgetConfigModal — load Queues/BUs INDEPENDENTLY + log errors (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Found in E visual gate (2026-06-25): the Scope-tab pickers were BOTH empty. ROOT (pinned): `GetQueuesQuery()` resolves to null tenant for Superadmin and fails → ReportWidgetConfigModal's SINGLE `catch` then blanks BOTH `_queues` AND `_businessUnits` and swallows the error (so even the working BU list disappears). The PRIMARY query fix is backend-0620's (GetQueuesQuery Superadmin fallback). THIS task = the shell DEFENSIVE half. Owner: role-shell. Executor: native CC. Branch: **v3** (tip a3a0d25). Commit `fix:`. **NO push** (§37).
> Parity-guard: ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / existing shared app.css selectors / widget-resize.js.

## INIT — branch v3 + role-shell §A/§C + §40 + integrity. §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push. Compile via docs/Visual-Test-Preflight.md Profile A (/ops/build → /shell/restart; one build-class op at a time).

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor (MODIFY — LoadDataSources + @inject ILogger)
- (role-shell.md via git add -f if CAPTURE)

## GROUNDING (object-store v3, ReportWidgetConfigModal.razor)
Current `LoadDataSources()` (~line 286):
```
try {
    var queuesTask = Mediator.Send(new GetQueuesQuery());
    var busTask    = Mediator.Send(new GetMyBusinessUnitsQuery());
    _queues = await queuesTask;
    _businessUnits = await busTask;
}
catch { _queues = []; _businessUnits = []; }   // ← blanks BOTH + swallows
finally { _queuesLoading = false; _busLoading = false; }
```
`@inject`: only `IStringLocalizer` + `IMediator` (no ILogger).

## THE WORK
1. Add `@inject ILogger<ReportWidgetConfigModal> Logger`.
2. Rewrite `LoadDataSources()` so Queues and BUs load **INDEPENDENTLY** — a failure of one MUST NOT blank the other, and errors are logged, not swallowed:
```
_queuesLoading = true; _busLoading = true; StateHasChanged();
try { _queues = await Mediator.Send(new GetQueuesQuery()); }
catch (Exception ex) { _queues = []; Logger.LogError(ex, "ReportWidgetConfigModal: failed to load queues"); }
finally { _queuesLoading = false; }
try { _businessUnits = await Mediator.Send(new GetMyBusinessUnitsQuery()); }
catch (Exception ex) { _businessUnits = []; Logger.LogError(ex, "ReportWidgetConfigModal: failed to load business units"); }
finally { _busLoading = false; }
StateHasChanged();
```
(Sequential awaits are fine; if you keep them parallel, still use one try/catch PER list so one failure can't blank the other. Never a bare catch — Logger.LogError always.)
3. No other behavioural change. Strings unchanged. Dark/light untouched.

## NOTE — depends on backend half for full fix
Queues will still be empty for Superadmin until backend-0620's GetQueuesQuery Superadmin→user.TenantId fallback lands. This shell fix ALONE makes the BU picker populate (its query already works) and surfaces errors; both halves are needed for queues. Re-visual after BOTH land.

## VERIFY / DoD (role-shell §A)
- Object-store: LoadDataSources has TWO independent try/catch (queues, BUs) each with Logger.LogError; no shared swallow-both catch; `@inject ILogger` added; ScreenEditorPage/ScreenFullscreenPage/shared/widget-resize UNTOUCHED.
- **Soma (Profile A): /ops/build 0 + /ops/test?suite=unit 0-failed + serilog [ERR]/[FTL] clean + /ops/health.**
- **VISUAL CHROME (light+dark):** report editor → widget → gear → Scope tab → the **Business Units** picker now populates (independent of the queues query); after backend half lands, Queues populate too; pick Scope+Columns → Save → widget no longer errors. (If only this half is in, confirm BUs populate + queues-fail no longer blanks BUs.)

## §0.6b CAPTURE -> role-shell §B (extends 2026-06-23 bare-catch lesson): "a single catch around two independent loads blanks BOTH on one failure and hides the cause — load each independently, Logger.LogError each, never swallow." Commit fix:, NO push. Binding RESULT -> cc/shell.md.
