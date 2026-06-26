# CC task — CC-2b FIX-2: marquee selects then trailing click WIPES it (+ dispose mousedown leak) (role-shell)
> §4-PASS by coordinator-0612 2026-06-17T13:18Z (operator 5239: marquee rect draws + candidates dash, but on release widgets are NOT selected/grouped). Owner: role-shell. Executor: native CC.
> Claims: widget-resize.js + Components/Dashboard/ScreenEditorPage.razor. Commit `fix:`. **NO push**.

## ROOT CAUSE (object-store verified)
`finalizeMarquee` correctly selects the intersecting widgets (-> selectedWidgets + OnMarqueeSelect -> Blazor SelectedWidgetIds). BUT a
marquee drag is mousedown+mouseup on the canvas, so the browser then fires a `click` -> `@onclick="OnCanvasClick"` (SEP:182) ->
`OnCanvasClick` (SEP:3227) does `SelectedWidgetIds.Clear()` + `widgetResize.clearSelection()` on a plain (no-modifier) click ->
**immediately WIPES the selection finalizeMarquee just made**. So: rect draws + candidates dash, but release = no selection (the trailing click deselects).

## FIX 1 — suppress the post-marquee trailing click-deselect
- widget-resize.js: in `finalizeMarquee`, when `wasActive` (a real marquee drag happened, regardless of whether anything was selected), set `this._marqueeJustFinished = true`.
- Add a JS method `consumeMarqueeFlag: function () { const v = this._marqueeJustFinished === true; this._marqueeJustFinished = false; return v; }`.
- ScreenEditorPage.razor `OnCanvasClick` (3227): at the TOP, consult+consume the flag and SKIP clearing if a marquee just finished:
  `if (await JS.InvokeAsync<bool>("widgetResize.consumeMarqueeFlag")) return;`
  (uses existing JS object + returns bool -> no new C# type/service, no CS0103). A PLAIN empty-canvas click (no marquee) -> flag false -> clears as before (CC-2-fix #2 behaviour preserved).
- RESULT: marquee drag -> selection STAYS after release (highlight + group-move); plain click on empty canvas still deselects.

## FIX 2 — dispose() mousedown listener leak (Shell's own nit, fold in)
- widget-resize.js `dispose()`: add `if (this._onMouseDown) document.removeEventListener('mousedown', this._onMouseDown);` (currently only mousemove/mouseup are removed -> the new mousedown listener leaks/duplicates on Blazor circuit re-init).

## VERIFY (build-cite or honest 'not run')
- Object-store: finalizeMarquee sets _marqueeJustFinished on wasActive; consumeMarqueeFlag present; OnCanvasClick consults it FIRST; dispose removes mousedown.
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line; else honest "BUILD: not run (no dotnet)".** OnCanvasClick now awaits a JS bool — confirm it stays `async Task` (it already is).
- PRODUCT (operator 5239): marquee drag -> on RELEASE widgets STAY selected (solid highlight) and move together as a group; plain click on empty canvas still deselects; single drag smooth.

## §0.6b CAPTURE -> role-shell §B: "a mousedown+mouseup drag (marquee) also fires a trailing click -> a click-deselect handler wipes the just-made selection. RULE: a drag-gesture's terminal click must be suppressed for handlers that treat click as a plain action."

## Commit (fix:, NO push) under commit.lock: git add (2 files + role-shell.md CAPTURE) ; commit -m "fix: marquee selection wiped by trailing click-deselect (suppress post-marquee click) + dispose mousedown leak [shell-0609]" ; §0.6 post-commit ; cc_post_commit.sh ; PD-007 re-sync ; sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; FIX1 _marqueeJustFinished flag + OnCanvasClick consumes it (selection survives release); FIX2 dispose mousedown removeEventListener; build cite OR 'not run'; CAPTURE. NO push. verified: object-store (+build if avail).

## Report (chat): commit hash; both fixes via git show HEAD; build line OR honest not-run; product-floor=operator 5239 (selection sticks after marquee release). NO push.
