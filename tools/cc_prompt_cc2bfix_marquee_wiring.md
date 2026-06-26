# CC task — CC-2b FIX: marquee not drawing + normal drag stutters (role-shell)
> §4-PASS by coordinator-0612 2026-06-17T13:03Z (operator 5239: marquee rect never appears; AND single-widget drag now stutters/freezes). Owner: role-shell. Executor: native CC.
> Claims: widget-resize.js + Components/Dashboard/ScreenEditorPage.razor + wwwroot/app.css (only if needed). Commit `fix:`. **NO push**.

## ROOT CAUSE (object-store verified — BOTH bugs share it)
Marquee start is routed through Blazor `@onmousedown="OnCanvasMouseDown"` on the canvas (SEP:192, NO stopPropagation). OnCanvasMouseDown
calls `JS widgetResize.startMarquee(new {clientX,clientY,shiftKey,target="canvas"}, _canvasRef)` (SEP:3250). But `startMarquee(e, canvasElement)`
(widget-resize.js:92) was written for a REAL DOM event: line 94 `if (e.target !== canvasElement && !e.target.classList.contains('dashboard-canvas-grid')) return false;`
Here `e.target` is the STRING "canvas" (serialized C# object), so `e.target.classList` is undefined -> **TypeError on the guard -> marquee never starts (BUG 1)**.
AND OnCanvasMouseDown fires on EVERY mousedown that bubbles to the canvas — including mousedown ON A WIDGET (widget body has no @onmousedown:stopPropagation unless drag-handle/hidden-header) -> startMarquee runs (and throws / sets stray marquee state) on widget drag-start -> **conflicts with the widget drag -> stutter/freeze (BUG 2)**.

## THE FIX — do marquee start in a REAL DOM listener (JS), remove the Blazor route
1. **widget-resize.js `init()`:** add a real `mousedown` DOM listener (document-level, or on the canvas). In it:
   - Find the canvas grid: `const canvas = e.target.closest('.dashboard-canvas-grid')` (or `.editor-canvas`). If none -> return (mousedown outside canvas).
   - **Empty-canvas check with REAL e.target:** only start marquee if the mousedown landed on the canvas itself, NOT on a widget: e.g. `if (e.target === canvas || e.target.classList.contains('dashboard-canvas-grid'))` proceed; if `e.target.closest('.dashboard-widget')` -> return (let the widget drag/select handle it). Also ignore if a move/resize is already active.
   - Call `this.startMarquee(e, canvas)` with the REAL DOM event (so e.target/e.clientX/e.shiftKey are native).
   - Bind/unbind with the existing _onMouseMove/_onMouseUp pattern; store the handler for dispose().
2. **`startMarquee`:** now receives a real DOM event -> the existing `e.target`/`getBoundingClientRect`/`e.clientX` logic works. Use `e.shiftKey` (real) for shift=add. Remove reliance on the serialized object.
3. **ScreenEditorPage.razor:** REMOVE the `@onmousedown="OnCanvasMouseDown"` marquee routing (and the OnCanvasMouseDown -> startMarquee interop at ~3250), OR make OnCanvasMouseDown a no-op for marquee. The marquee is now 100% JS DOM. Keep `_canvasRef` only if still used; remove if now dead. Ensure widget @onclick select (SelectWidget) + StartMove drag are untouched.
4. Verify normal single-widget drag NO LONGER stutters (no stray startMarquee on widget mousedown) and group-move (CC-2) still works.

## VERIFY (build-cite or honest 'not run')
- Object-store: init() binds a DOM mousedown that calls startMarquee with a real event; startMarquee guard uses real e.target; OnCanvasMouseDown marquee-interop removed/neutralized; no other regressions.
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line; else honest "BUILD: not run (no dotnet)".** @inject/@using guard for any new C#.
- PRODUCT (operator 5239): (a) drag a box on EMPTY canvas -> dashed marquee rect follows cursor; candidates dashed; release -> selection+group-move; (b) single-widget drag is SMOOTH again (no stutter); (c) Ctrl-click + click-empty unchanged.

## §0.6b CAPTURE -> role-shell §B: e.g. "routed a DOM-event-dependent JS fn (startMarquee, needs real e.target) through Blazor @onmousedown -> serialized MouseEventArgs has e.target as a string -> TypeError + fired on bubbled widget mousedowns -> broke marquee AND drag. RULE: DOM-event-dependent canvas handlers must bind a real JS DOM listener, not route a serialized MouseEventArgs."

## Commit (fix:, NO push) under commit.lock: git add (changed claimed + role-shell.md CAPTURE) ; commit -m "fix: marquee start via real JS DOM mousedown (was broken serialized e.target + fired on widget mousedown -> no rect + drag stutter) [shell-0609]" ; §0.6 post-commit ; cc_post_commit.sh ; PD-007 re-sync ; sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; marquee now real DOM listener (e.target native); OnCanvasMouseDown route removed; drag-stutter gone; build cite OR 'not run'; CAPTURE. NO push. verified: object-store (+build if avail).

## Report (chat): commit hash; both fixes via git show HEAD; build line OR honest not-run; product-floor=operator 5239 (marquee draws + drag smooth). NO push.
