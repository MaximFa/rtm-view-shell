# CC task — Reports editor FIX-A (shell): rewire ReportEditorPage to the REAL widget-resize.js contract (G-MOVE / G-RESIZE / G-MULTIADD / position-persist) — AWAITING §4-BLESS
> Operator end-to-end NO-GO (2026-06-25): in the report editor a placed widget cannot be MOVED (G-MOVE), cannot be RESIZED (G-RESIZE), and a 2nd widget cannot be ADDED (G-MULTIADD). ROOT (object-store, shell-0609): `ReportEditorPage.razor` was written against a **phantom JS API** that does not exist in `wwwroot/js/widget-resize.js`, and it never calls `widgetResize.init(...)`, so the document mouse listeners never attach, the DotNet ref is null, positions never sync back, and Save reads positions from a non-existent function.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> Parity-guard: ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / **widget-resize.js** / existing shared app.css selectors. This is a one-file change to ReportEditorPage.razor that brings it to byte-for-byte behavioural parity with the dashboard editor's JS contract.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY against current code)
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
- NOTE: pre-existing `D Installations/*` deletions are NOT ours — do not stage/touch.
- §0.3 Python+fsync for ALL writes; the **Edit tool is BANNED**. After every write: `sync` + `tail -3` + `wc -l`.
- Compile via docs/Visual-Test-Preflight.md Profile A (`/ops/build` → `/shell/restart`; ONE build-class Soma op at a time — never /ops/build while a /shell/start is in flight).

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_editor_jswiring.md | status: open
### DIRECTIVE (spec->CC): FIX-A report editor JS rewire to widget-resize.js parity. Claim: ReportEditorPage.razor. fix:, NO push, §4-PASS gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — **READ-ONLY reference only** (do NOT edit)
- src/CcDashboard.Web/wwwroot/js/widget-resize.js — **READ-ONLY reference only** (do NOT edit)
- src/CcDashboard.Web/Components/Reports/ReportEditorPage.razor — **MODIFY** (sole edit target)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if a CAPTURE lesson is added)

## GROUNDING (object-store v3)
The REAL `widget-resize.js` API (used by the WORKING ScreenEditorPage) — confirmed by object-store:
- `widgetResize.init(dotNetRef)` — attaches document mousemove/mouseup/mousedown + marquee + guides. **MUST be called once on firstRender.**
- `widgetResize.startMove(widgetId, { clientX, clientY })`
- `widgetResize.startResize(widgetId, handle, { clientX, clientY })` — single fn; `handle` ∈ e,s,se,n,w,nw,ne,sw
- `widgetResize.applyAllWidgetPositions(arr)` / `widgetResize.applyWidgetPosition(id,x,y,w,h)` — exist (already used)
- `widgetResize.dispose()` — detaches listeners
- Server-side callbacks invoked BY the JS (require a DotNetObjectReference passed to init):
  - `OnWidgetMoved(string widgetIdStr, int left, int top)`
  - `OnWidgetResized(string widgetIdStr, int width, int height)`
  - `OnWidgetsMoved(List<WidgetMoveData> moves)`  (group move; `WidgetMoveData { string Id; int Left; int Top; }`)
  - `OnMarqueeSelect(string[] widgetIds)`

What ReportEditorPage.razor does WRONG today (object-store):
- :550-575 calls `widgetResize.startDragWidget` + `startResizeE/S/SE/N/W/NW/NE/SW` — **none exist**.
- :402 SaveLayout calls `widgetResize.getAllWidgetPositions` — **does not exist**.
- No `widgetResize.init(...)`, no `DotNetObjectReference`, no `[JSInvokable]` callbacks, no `widgetResize.dispose()`.
- Model `PlacedReportWidget` stores `PositionJson` (string) — NOT discrete X/Y/W/H. So callbacks must update `PositionJson`.

ScreenEditorPage reference pattern (object-store, do NOT copy its discrete-field model — adapt to PositionJson):
- :2895-2901 firstRender → `_dotNetRef = DotNetObjectReference.Create(this); JS.InvokeVoidAsync("widgetResize.init", _dotNetRef);`
- :3145-3153 `StartResize(id,handle,e)` → `startResize(id, handle, {clientX,clientY})`; `StartMove(id,e)` → `startMove(id, {clientX,clientY})`
- :2920/3155/3170/3197 the four `[JSInvokable]` callbacks update the C# model + `StateHasChanged()`
- :5263 Dispose → `JS.InvokeVoidAsync("widgetResize.dispose")`

## THE WORK (ReportEditorPage.razor ONLY)
1. **init + dispose:**
   - Add field `private DotNetObjectReference<ReportEditorPage>? _dotNetRef;`
   - In `OnAfterRenderAsync`, on `firstRender`: `_dotNetRef = DotNetObjectReference.Create(this); await JS.InvokeVoidAsync("widgetResize.init", _dotNetRef);` (keep the existing position-apply logic that runs after).
   - In `Dispose()`: add `_ = JS.InvokeVoidAsync("widgetResize.dispose"); _dotNetRef?.Dispose();` (keep `_cts.Cancel()`).
2. **Move handler:** change `StartMove` to call the REAL fn:
   `JS.InvokeVoidAsync("widgetResize.startMove", id.ToString(), new { clientX = e.ClientX, clientY = e.ClientY });`
3. **Resize handlers:** replace the 8 phantom `StartResizeE/S/SE/...` bodies with calls to the single real fn, passing the handle letter, e.g.:
   `private void StartResizeE(Guid id, MouseEventArgs e) => JS.InvokeVoidAsync("widgetResize.startResize", id.ToString(), "e", new { clientX = e.ClientX, clientY = e.ClientY });`
   …and likewise `"s","se","n","w","nw","ne","sw"`. (Razor markup at :178-185 already wires each handle to its StartResizeX method — keep the markup; only the method bodies change.)
4. **JSInvokable callbacks** — add a private helper that mutates `PositionJson` and the four callbacks:
```csharp
private void ApplyPos(Guid id, int? x = null, int? y = null, int? w = null, int? h = null)
{
    var widget = PlacedWidgets.FirstOrDefault(p => p.Id == id);
    if (widget is null) return;
    var pos = ParsePosition(widget.PositionJson);
    widget.PositionJson = JsonSerializer.Serialize(new {
        x = x ?? pos.X, y = y ?? pos.Y, width = w ?? pos.Width, height = h ?? pos.Height });
}

[JSInvokable] public void OnWidgetMoved(string widgetIdStr, int left, int top)
{ if (Guid.TryParse(widgetIdStr, out var id)) { ApplyPos(id, x: left, y: top); StateHasChanged(); } }

[JSInvokable] public void OnWidgetResized(string widgetIdStr, int width, int height)
{ if (Guid.TryParse(widgetIdStr, out var id)) { ApplyPos(id, w: width, h: height); StateHasChanged(); } }

[JSInvokable] public void OnWidgetsMoved(List<WidgetMoveData> moves)
{ foreach (var m in moves) if (Guid.TryParse(m.Id, out var id)) ApplyPos(id, x: m.Left, y: m.Top); StateHasChanged(); }

[JSInvokable] public void OnMarqueeSelect(string[] widgetIds)
{ /* single-select model: keep SelectedWidgetId behaviour. If >=1 id, set SelectedWidgetId = first parsed; else null. */ StateHasChanged(); }

public class WidgetMoveData { public string Id { get; set; } = ""; public int Left { get; set; } public int Top { get; set; } }
```
   - NOTE on OnMarqueeSelect: the report editor uses a single `SelectedWidgetId?` (not a multi-select set like the dashboard). Implement it minimally — do NOT introduce a multi-select set in this fix (out of scope). Setting `SelectedWidgetId` to the first selected id (or null) + StateHasChanged is sufficient; the JS still drives the visual `.selected` class via `updateSelectionClasses`, so no regression. Group-move (`OnWidgetsMoved`) still commits positions correctly even without multi-select UI.
5. **SaveLayout:** remove the `widgetResize.getAllWidgetPositions` call and the posDict reconciliation (:402-412). Positions are now kept current in `PlacedWidgets[].PositionJson` by the JSInvokable callbacks, so build `widgetRequests` directly from `PlacedWidgets` (PositionJson as-is). Keep everything else (SaveReportWidgetsCommand, UpdateReportScreenCommand, reload) unchanged.
6. Do NOT change: drag-from-palette/OnDropAtPosition, the canvas markup classes (`dashboard-canvas-grid` / `dashboard-widget` / `data-widget-id` / `widget-drag-handle` / `resize-handle resize-*` — already correct and match the JS selectors), GetWidgetStyle, ParsePosition.

## VERIFY / DoD (role-shell §A — ЧП: every visual detail critically RED, build-green is NOT sufficient)
- **Object-store:** ReportEditorPage.razor — `widgetResize.init` present (firstRender) + `_dotNetRef` created; `startDragWidget`=0, `startResizeE`=0 (phantom names gone); `widgetResize.startMove`=1 + `widgetResize.startResize`=8; the 4 `[JSInvokable]` callbacks present + `WidgetMoveData`; `getAllWidgetPositions`=0; `widgetResize.dispose`=1. ScreenEditorPage.razor / ScreenFullscreenPage.razor / widget-resize.js / shared app.css selectors UNTOUCHED (parity-guard).
- **Soma (Profile A):** `/ops/build` 0 errors + `/ops/test?suite=unit` 0 failed + serilog `[ERR]/[FTL]/[FATAL]` scan clean + `/ops/health`.
- **VISUAL CHROME GATE (light + dark) — MANDATORY (this fix renders UI):** report editor (`/reports/{id}/edit`) → place a widget → **drag it (moves)** → **resize from a corner and an edge (resizes)** → **add a 2nd widget (appears)** → reload/Save → positions persist. Screenshot/read-page evidence for both light and dark. This is the operator/QA functional bar — do NOT report GREEN from object-store alone (ЧП HARD rule).
- **live-dashboard regression:** open a normal dashboard editor (`/screens/{id}/edit`) → move/resize/add still work (widget-resize.js untouched, must be byte-identical behaviour).

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0 required.
- commit.lock acquire (atomic `open(...,"x")`, retry 5×60s); stage ONLY `src/CcDashboard.Web/Components/Reports/ReportEditorPage.razor` (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports editor — wire ReportEditorPage to real widget-resize.js contract (move/resize/multi-add + position-persist) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>` (journal + flush + lock release). §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed file from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "A new editor that reuses widget-resize.js MUST call widgetResize.init(dotNetRef) once on firstRender and implement the four [JSInvokable] callbacks + dispose(); calling phantom fn names (startDragWidget/startResizeE…) silently no-ops and drag/resize are dead. Mirror ScreenEditorPage's contract exactly; adapt only the model write (PositionJson vs discrete X/Y)." SOURCE:<commit>. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportEditorPage.razor . status done|failed . blockers . verified: object-store
```
