# CC task — WIDGET-STICK fix (shell): move drag/resize START to a synchronous real-DOM mousedown listener (kill Blazor-interop race) — AWAITING §4-BLESS
> Reject (234): editor widgets "stick" on click — drag with the mouse, never release. ROOT (coordinator+shell object-store): move/resize START goes native mousedown → Blazor `@onmousedown` → C# StartMove/StartResize* → `await JS.InvokeVoidAsync("widgetResize.startMove/startResize")` (ScreenEditorPage:3160/3165). On Blazor SERVER that's a SignalR round-trip → the native **mouseup fires BEFORE startMove runs** → `onMouseUp` early-returns at `if(!this.activeWidget) return` (widget-resize.js:571) → THEN startMove sets activeWidget+mode='move' → widget is in move mode with NO upcoming mouseup → STICKS. onMouseUp itself is correct; the defect is ORDER caused by async interop.
> FIX: start move/resize SYNCHRONOUSLY from the EXISTING real-DOM mousedown listener `widgetResize.onMouseDown` (widget-resize.js:31/49 — already used for marquee), detecting the drag-handle / resize-handle via DOM (`data-widget-id` + classes) → call startMove/startResize IMMEDIATELY (activeWidget set before any mouseup). Remove the Blazor `@onmousedown` START triggers. Keep the Blazor END-notify (onMouseUp → OnWidgetMoved/OnWidgetResized/OnWidgetsMoved — unchanged).
> ⚠ widget-resize.js changes → MUST bump its cache-bust `?v` in App.razor (PR234-1c lesson: stale JS = missing-fn crash). Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37). Report-scoped.

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
## BINDING 2026-07-05T11:01:10Z | spec: shell | directive: tools/cc_prompt_shell_widget_stick_sync_mousedown.md | status: open
### DIRECTIVE (spec->CC): WIDGET-STICK — start move/resize from synchronous JS onMouseDown (widget-resize.js), remove Blazor @onmousedown START triggers, bump widget-resize.js ?v. v3, fix:, NO push, §4 + LIVE gate. Report build=0 + unit failed=0 WITH COUNTS.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/wwwroot/js/widget-resize.js — MODIFY (extend onMouseDown to start move/resize synchronously)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — MODIFY (remove Blazor @onmousedown START triggers; keep @onclick select + data-widget-id + toolbar; remove now-unused StartMove/StartResize* C# methods)
- src/CcDashboard.Web/Components/App.razor — MODIFY (bump `js/widget-resize.js?v=1` → `?v=2`)

## GROUNDING (object-store v3)
- DOM (ScreenEditorPage): `.dashboard-widget[data-widget-id]` (:196); move header `.widget-header.widget-drag-handle` (:218-219 `@onmousedown=StartMove`+:stopPropagation); HideHeader → `.dashboard-widget.header-hidden` draggable via `.dashboard-widget @onmousedown` (:201-202); 8 resize handles `.resize-handle.resize-{e,s,se,n,w,nw,ne,sw}` each `@onmousedown=StartResize*`+:stopPropagation (:236-243); toolbar buttons `.widget-toolbar .widget-toolbar-btn` (config/delete/template, @onclick+:stopPropagation).
- JS (widget-resize.js): `onMouseDown(e)` (:49) real-DOM listener — currently `if (e.target.closest('.dashboard-widget')) return;` then startMarquee. `startMove(widgetId, {clientX,clientY})` (:285) + `startResize(widgetId, handle, {clientX,clientY})` (:266) both `querySelector([data-widget-id])` + set `activeWidget`/`mode` synchronously (handle ∈ e/s/se/n/w/nw/ne/sw). `onMouseUp` (:551) notifies Blazor on END (keep).
- C#: `StartMove` (:3163) + `StartResize*` (:~3150-3161) only wrap `JS.InvokeVoidAsync` → become UNUSED after this fix. `[JSInvokable] OnWidgetMoved/OnWidgetsMoved/OnWidgetResized/OnMarqueeSelect` are called FROM JS → KEEP.

## THE WORK
### A. widget-resize.js `onMouseDown(e)` — start move/resize synchronously
Before the marquee/canvas branch, add widget drag/resize detection (only when not already in a mode):
```javascript
const widgetEl = e.target.closest('.dashboard-widget');
if (widgetEl) {
    if (this.activeWidget || this.activeModal || this.marquee) return;
    const widgetId = widgetEl.getAttribute('data-widget-id');
    if (!widgetId) return;
    // toolbar buttons / interactive content → let Blazor @onclick handle it
    if (e.target.closest('.widget-toolbar, button, a, input, select, textarea')) return;
    // resize handle → start resize
    const rh = e.target.closest('.resize-handle');
    if (rh) {
        const dir = Array.from(rh.classList).map(c => c.startsWith('resize-') && c !== 'resize-handle' ? c.slice('resize-'.length) : null).find(Boolean);
        if (dir) { this.startResize(widgetId, dir, { clientX: e.clientX, clientY: e.clientY }); e.preventDefault(); }
        return;
    }
    // drag handle (header) OR header-hidden widget → start move
    if (e.target.closest('.widget-drag-handle') || widgetEl.classList.contains('header-hidden')) {
        this.startMove(widgetId, { clientX: e.clientX, clientY: e.clientY }); e.preventDefault();
        return;
    }
    return; // mousedown on widget content → no drag; @onclick selects
}
// ...existing marquee path (e.target not in a widget)...
```
(Keep the existing early bailouts + the existing marquee start for empty-canvas mousedown. Do NOT change startMove/startResize internals or the scale/align math.)
### B. ScreenEditorPage.razor — remove the Blazor mousedown START triggers
- `.dashboard-widget` (:201-202): remove the `@onmousedown="e => { if (widget.Config?.HideHeader == true) StartMove(...); }"` + `@onmousedown:stopPropagation`. KEEP `@onclick=SelectWidget`+:stopPropagation and `data-widget-id`.
- `.widget-drag-handle` (:219-220): remove `@onmousedown=StartMove` + `:stopPropagation` (keep the element + its content).
- 8 resize handles (:236-243): remove `@onmousedown=StartResize*` + `:stopPropagation` (keep the divs + classes — the JS listener drives them now).
- Remove the now-unused C# `StartMove` + `StartResizeE/S/SE/N/W/NW/NE/SW` methods (they only called JS.InvokeVoidAsync). KEEP all `[JSInvokable]` methods.
### C. App.razor — bump `js/widget-resize.js?v=1` → `?v=2` (JS changed; else stale cache).
### D. Preserve: marquee (empty canvas), group-move, alignment guides, onMouseUp END-notify, click-to-select, toolbar buttons. No change to non-editor pages.

## VERIFY / DoD (role-shell §A — ⛔ LIVE gate, not object-store)
- **Object-store:** onMouseDown starts move/resize synchronously via data-widget-id + handle classes (toolbar/content excluded); Blazor @onmousedown START triggers removed; unused StartMove/StartResize* C# removed; [JSInvokable] end-callbacks intact; App.razor widget-resize.js?v=2; marquee path intact.
- **Soma (Profile A) — REPORT NUMBERS:** /ops/build = **0 errors** (+W); /ops/test?suite=unit = **failed=0** (+passed). If unit blocked → report verbatim, not green.
- **⛔ LIVE GATE (operator/coordinator on 234, rebuild + hard-refresh — new ?v=2):** click+drag a widget by its header → it MOVES and **RELEASES on mouseup** (no stick); repeat rapidly → still releases; resize via each handle → resizes + releases; a plain click (no drag) still SELECTS; toolbar config/delete/template still work; marquee still works on empty canvas; header-hidden widget draggable by its body. object-store ≠ functional — do NOT report GREEN without the live no-stick confirmation (lesson 2026-06-26).

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY the 3 claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): WIDGET-STICK — start widget move/resize from synchronous JS mousedown (kill Blazor-interop race) + widget-resize.js?v=2 [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B: "Widget move/resize START via Blazor `@onmousedown`→C#→`JS.InvokeVoidAsync` is a SignalR round-trip on Blazor Server → native mouseup beats startMove → onMouseUp early-returns → widget stuck in move mode with no upcoming mouseup (STICK). FIX: start drag/resize from a SYNCHRONOUS real-DOM mousedown listener (widget-resize.js onMouseDown, keyed by data-widget-id + handle classes); Blazor only END-notifies. Rule: pointer-DOWN that begins a native drag/gesture must be handled synchronously in JS, NEVER via server interop; reserve interop for gesture END. + any widget-resize.js change requires an App.razor ?v bump (PR234-1c)." SOURCE:ScreenEditorPage:201-243/3160-3165 + widget-resize.js:49/266/285/551 + coordinator live 2026-07-04. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed n> . files widget-resize.js + ScreenEditorPage.razor + App.razor(?v=2) . status done|failed . blockers . verified: object-store (LIVE no-stick move+resize = operator gate, pending)
```
