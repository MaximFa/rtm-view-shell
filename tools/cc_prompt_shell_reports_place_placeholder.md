# CC task — Reports editor FIX-B (shell): unconfigured-widget placeholder at place-time (G-PLACE-ERR) — AWAITING §4-BLESS
> Operator end-to-end NO-GO (2026-06-25): placing a widget shows a RED error on the canvas (G-PLACE-ERR). ROOT (object-store, shell-0609): a freshly-placed widget has `ConfigJson = null` → the type widget runs `RunReportWidgetQuery` with an empty config → `ReportWidgetConfigWithTypeValidator` rejects the empty Scope → the handler returns `CreateError(...)` → the type widget renders it as `alert-danger`. The error is *honest validation*, but it should not be shown for a widget the user simply hasn't configured yet. Fix = render a neutral "configure me" placeholder when there is no scope (parity with how dashboard widgets show an unconfigured stub instead of erroring).
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> Parity-guard: ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / widget-resize.js / existing shared app.css selectors.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- pre-existing `D Installations/*` deletions are NOT ours — do not touch.
- §0.3 Python+fsync for ALL writes; **Edit tool BANNED**; after every write `sync` + `tail -3` + `wc -l`.
- Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_place_placeholder.md | status: open
### DIRECTIVE (spec->CC): FIX-B place-time unconfigured placeholder in RenderReportWidget. Claim: RenderReportWidget.razor (+resx). fix:, NO push, §4-PASS gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/ReportWidgets/RenderReportWidget.razor — **MODIFY** (sole code target)
- src/CcDashboard.Web/Resources/SharedResources.en-US.resx, .ru-RU.resx, .he-IL.resx — **MODIFY** (one new string key)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING (object-store v3)
`RenderReportWidget.razor` (dispatcher) parses `ConfigJson` → `_config` in `OnParametersSet`, then `switch`es on `WidgetType` to the 5 type widgets (QueueInterval/QueueWaitTime/AgentMonthly/AgentShiftDetail/Distribution). The type widgets each run the query and render `alert-danger` on a validation error (e.g. QueueIntervalReportWidget.razor:16-21 + :115 `configJson = Config?.ToJson() ?? "{}"`).
Scope model: `ReportWidgetConfig.Scope` has `Mode` ("queues"|"bu"), `QueueIds`, `BusinessUnitIds`. "No scope" = `_config` is null, OR `_config.Scope` is null, OR (Mode=="queues" with empty/no QueueIds) AND (no BusinessUnitIds) — i.e. nothing selected. Confirm exact property names against ReportWidgetConfig/ReportScope by object-store before coding.

## THE WORK (RenderReportWidget.razor)
1. Add a computed flag `_unconfigured` set in `OnParametersSet` after parsing `_config`: true when there is no usable scope (no queues selected AND no BUs selected; treat null `_config`/null `Scope` as unconfigured).
2. When `_unconfigured` is true, render a NEUTRAL placeholder INSTEAD of the `switch` to the type widget — do not dispatch the query at all:
```razor
@if (_unconfigured)
{
    <div class="report-widget-unconfigured text-center text-muted py-4">
        <i class="bi bi-gear fs-3 d-block mb-2 opacity-50"></i>
        <span>@L["ReportWidget_Unconfigured"]</span>
    </div>
}
else
{
    @* existing switch on WidgetType *@
}
```
3. Add the resx key `ReportWidget_Unconfigured` to all THREE resx files (en/ru/he), starting with a capital letter (role-shell §29.1 convention):
   - en-US: "Configure this widget — select a scope (queue or business unit)."
   - ru-RU: "Настройте виджет — выберите область (очередь или бизнес-юнит)."
   - he-IL: "הגדירו את הווידג'ט — בחרו היקף (תור או יחידה עסקית)." (RTL — no layout changes needed; text only)
4. Styling: use existing utility classes only (text-muted / py-4 / Bootstrap icon). If a `.report-widget-unconfigured` rule is wanted, add it report-scoped to app.css (additive, new selector — NEVER edit an existing shared selector). Prefer utility classes to avoid any CSS change; only add the scoped rule if needed for spacing.
5. Do NOT change the type widgets themselves, the handler, or the validator. Once the user sets a scope (via the config modal) the placeholder disappears and the real widget queries normally.

## VERIFY / DoD (role-shell §A — ЧП: every visual detail critically RED)
- **Object-store:** RenderReportWidget renders the placeholder branch when scope is empty and only dispatches to the type widget when scope is present; `ReportWidget_Unconfigured` present in all 3 resx; no edits to type widgets / handler / validator / ScreenEditorPage / shared selectors.
- **Soma (Profile A):** `/ops/build` 0 + `/ops/test?suite=unit` 0 failed + serilog `[ERR]/[FTL]` clean + `/ops/health`.
- **VISUAL CHROME GATE (light + dark) — MANDATORY:** report editor → place a widget → it shows the neutral "Configure this widget" placeholder (NO red error) → open gear → set a Scope (queue/BU) → Save → the widget now renders data (or the honest Report_NoData info if the scope has no rows in range) — NOT alert-danger. Screenshot light + dark.
- **Regression:** an already-configured saved widget (with scope) still renders its table/data unchanged in both editor preview and the View page.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY RenderReportWidget.razor + the 3 resx (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports — show 'configure widget' placeholder for unconfigured report widgets instead of validation error at place-time [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "A report widget with no scope must render a neutral 'configure me' placeholder, not run the query and surface the validator's alert-danger — parity with the dashboard unconfigured-stub. Gate the dispatch on scope-present in the RenderReportWidget dispatcher." SOURCE:<commit>. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files RenderReportWidget.razor +3 resx . status done|failed . blockers . verified: object-store
```
