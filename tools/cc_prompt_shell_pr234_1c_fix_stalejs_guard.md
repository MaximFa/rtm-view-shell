# CC task — PR234-1c fix (shell): scale toggle crashes circuit — stale JS cache (no ?v on widget-resize.js) + unguarded interop — AWAITING §4-BLESS
> REOPENED BLOCKER (v3, live Test14 ?v=30 df95ff3): clicking the View scale toggle TERMINATES the Blazor circuit (Dark/Light dead after; console: "unhandled exception ... circuit will be terminated" + "No interop methods are registered for renderer 1").
> ROOT (shell-diagnosed, object-store): 1c (df95ff3) ADDED `viewerScale.resetToActual` to `wwwroot/js/widget-resize.js` (:820-832), BUT `App.razor:38` loads `js/widget-resize.js` with **NO `?v` cache-bust** (only app.css/tokens.css are versioned). The browser runs the STALE cached widget-resize.js that LACKS `resetToActual` → `ToggleScaleMode` (ScreenFullscreenPage.razor:123) awaits `JS.InvokeVoidAsync("viewerScale.resetToActual")` → JSException → UNHANDLED in the async handler → circuit terminated. "No interop methods registered for renderer 1" = downstream symptom of the dead renderer receiving later global events. Server JS is correct; browser cache is stale (PR234-2's app.css bump doesn't touch JS caching).
> TWO shell fixes: (A) cache-bust the project JS includes so browsers fetch current JS; (B) guard the toggle's interop so a JS hiccup can NEVER terminate the circuit. Do NOT change viewerScale's scale math.
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37). Report-scoped.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + BRANCH NORM (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3 (checkout v3 if not); verify HEAD == v3 tip
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- ALL commits to **v3** only. §0.3 Python+fsync; Edit BANNED. `D Installations/*` = not ours.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING 2026-07-02T12:49:41Z | spec: shell | directive: tools/cc_prompt_shell_pr234_1c_fix_stalejs_guard.md | status: open
### DIRECTIVE (spec->CC): PR234-1c fix — cache-bust project JS in App.razor (?v) + try/catch-guard ToggleScaleMode interop (stale widget-resize.js -> resetToActual missing -> circuit crash). v3, fix:, NO push, §4 + LIVE gate. Report build=0 + unit failed=0 WITH COUNTS.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/App.razor — MODIFY (add `?v=1` to the PROJECT JS <script> tags, lines 37-42)
- src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor — MODIFY (guard ToggleScaleMode interop in try/catch)

## THE WORK
### A. Cache-bust the project JS (App.razor:37-42) — Python+fsync, Edit BANNED
Add `?v=1` to each PROJECT-owned script (parallels app.css?v):
- `js/app.js` -> `js/app.js?v=1`
- `js/widget-resize.js` -> `js/widget-resize.js?v=1`
- `js/daytrendChart.js` -> `js/daytrendChart.js?v=1`
- `js/agentStateDistributionChart.js` -> `js/agentStateDistributionChart.js?v=1`
- `js/reportDistributionChart.js` -> `js/reportDistributionChart.js?v=1`
LEAVE `_framework/blazor.web.js` and `js/chart.umd.min.js` (vendor) UNCHANGED. (Going forward, bump these `?v` whenever the JS changes — same rule as app.css §29.1.)

### B. Guard the toggle interop (ScreenFullscreenPage.razor ToggleScaleMode, :123-135)
Wrap BOTH `JS.InvokeVoidAsync("viewerScale.init"...)` and `JS.InvokeVoidAsync("viewerScale.resetToActual")` in a single try/catch:
```csharp
try
{
    if (_scaleMode == "fit")
        await JS.InvokeVoidAsync("viewerScale.init", _designLayerRef, _designWidth, _designHeight);
    else
        await JS.InvokeVoidAsync("viewerScale.resetToActual");
}
catch (Exception ex)
{
    Logger.LogWarning(ex, "viewerScale interop failed in ToggleScaleMode (scaleMode={Mode})", _scaleMode);
}
```
(Confirm `@inject ILogger<ScreenFullscreenPage> Logger` exists; if not, inject it.) Rationale: a missing/failing JS fn must degrade gracefully, NEVER terminate the circuit. Do NOT alter the scale math or _scaleMode flip.

## VERIFY / DoD (role-shell §A — ⛔ LIVE gate, not object-store)
- **Object-store:** App.razor project JS scripts carry `?v=1` (blazor.web.js + chart.umd vendor untouched); ToggleScaleMode interop wrapped in try/catch + Logger; scale math unchanged; v3.
- **Soma (Profile A) — REPORT NUMBERS (new standing rule):** /ops/build = **0 errors** (+ warnings count); /ops/test?suite=unit = **failed=0** (+ passed count). If any unit FAIL → list, do NOT call green. + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE (operator/coordinator on 234, rebuild + hard-refresh):** open a dashboard View → click the scale toggle → it switches fit↔actual **WITHOUT terminating the circuit**; Dark/Light STILL works after; NO console "circuit terminated" / "No interop methods registered"; verify the actual scale effect on a board LARGER than the viewport (add big/multiple widgets → fit shrinks-to-fit, actual = 1:1 with scroll). Do NOT report GREEN without this.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY App.razor + ScreenFullscreenPage.razor (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): PR234-1c scale toggle circuit crash — cache-bust project JS (?v) + guard viewerScale interop [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B: "PROJECT JS (js/*.js) was NEVER cache-busted in App.razor — only app.css/tokens.css carry ?v. Any JS change (e.g. 1c's viewerScale.resetToActual) ships STALE to returning browsers → a razor call to the new JS fn throws JSException → UNHANDLED in an async event handler → Blazor circuit TERMINATED ('No interop methods registered for renderer N' is the dead-circuit downstream symptom). FIX: add ?v to project JS includes (bump on every JS change, §29.1 parity) AND wrap viewer JS-interop in try/catch so a stale/missing JS fn degrades, not crashes. Consider a durable content-hash bust for both css+js." SOURCE:App.razor:37-42 + df95ff3 widget-resize.js + coordinator live 2026-07-02. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed n> . files App.razor + ScreenFullscreenPage.razor . status done|failed . blockers . verified: object-store (LIVE toggle-no-crash = operator/coordinator gate, pending)
```
