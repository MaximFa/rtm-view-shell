# CC task — WIDGET-STICK COMPLETION (shell): add the MISSING Part-A (widget-resize.js onMouseDown sync move/resize start) — AWAITING §4-BLESS
> ⚠ 8b285eb ("WIDGET-STICK …") is INCOMPLETE/BROKEN: it removed the Blazor `@onmousedown` START triggers + the C# StartMove/StartResize* AND bumped widget-resize.js?v=2, BUT it did NOT modify `widget-resize.js` — the `onMouseDown` handler still `return`s on `.dashboard-widget` and NEVER starts move/resize. Net effect on v3 right now: **widgets can no longer be moved OR resized at all** (no trigger). This task adds the missing Part-A so drag/resize work again (synchronously, no stick). Do NOT re-remove anything from 8b285eb — that half is correct; only widget-resize.js needs the addition.
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
git rev-parse --abbrev-ref HEAD    # MUST be v3; verify HEAD == v3 tip (should be 8b285eb or later)
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- ALL commits to **v3** only. §0.3 Python+fsync; Edit BANNED.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING 2026-07-05T12:35:48Z | spec: shell | directive: tools/cc_prompt_shell_widget_stick_complete.md | status: open
### DIRECTIVE (spec->CC): WIDGET-STICK COMPLETION — add the missing widget-resize.js onMouseDown sync move/resize start (8b285eb removed old triggers but skipped this → move/resize dead). v3, fix:, NO push, §4 + LIVE gate. Report build=0 + unit failed=0 WITH COUNTS.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/wwwroot/js/widget-resize.js — MODIFY (onMouseDown ONLY — add widget drag/resize detection)
- (App.razor already ?v=2 from 8b285eb — do NOT re-bump; but VERIFY it's still ?v=2. If for any reason it regressed, set it to ?v=2.)

## GROUNDING (object-store, HEAD)
- `widget-resize.js` `onMouseDown(e)` (~:49) currently:
```javascript
onMouseDown: function (e) {
    if (this.activeWidget || this.activeModal || this.marquee) return;
    const canvas = e.target.closest('.dashboard-canvas-grid');
    if (!canvas) return;
    if (e.target.closest('.dashboard-widget')) return;   // <-- leaves widgets unhandled (was Blazor's job; now nothing)
    this.startMarquee(e, canvas);
},
```
- DOM (ScreenEditorPage, unchanged by 8b285eb): `.dashboard-widget[data-widget-id]`; `.widget-header.widget-drag-handle`; `.dashboard-widget.header-hidden` (whole-body drag); 8 `.resize-handle.resize-{e,s,se,n,w,nw,ne,sw}`; toolbar `.widget-toolbar`/buttons.
- `startMove(widgetId, {clientX,clientY})` (:285) + `startResize(widgetId, handle, {clientX,clientY})` (:266) set activeWidget/mode synchronously. onMouseUp END-notifies Blazor (intact).

## THE WORK — replace the `if (e.target.closest('.dashboard-widget')) return;` line with widget drag/resize detection
```javascript
const widgetEl = e.target.closest('.dashboard-widget');
if (widgetEl) {
    const widgetId = widgetEl.getAttribute('data-widget-id');
    if (!widgetId) return;
    // toolbar buttons / interactive content → let Blazor @onclick handle it
    if (e.target.closest('.widget-toolbar, button, a, input, select, textarea')) return;
    // resize handle → start resize synchronously
    const rh = e.target.closest('.resize-handle');
    if (rh) {
        const dir = Array.from(rh.classList).map(c => (c.startsWith('resize-') && c !== 'resize-handle') ? c.slice('resize-'.length) : null).find(Boolean);
        if (dir) { this.startResize(widgetId, dir, { clientX: e.clientX, clientY: e.clientY }); e.preventDefault(); }
        return;
    }
    // drag handle (header) OR header-hidden widget → start move synchronously
    if (e.target.closest('.widget-drag-handle') || widgetEl.classList.contains('header-hidden')) {
        this.startMove(widgetId, { clientX: e.clientX, clientY: e.clientY }); e.preventDefault();
        return;
    }
    return; // mousedown on widget content → no drag; Blazor @onclick selects
}
// (unchanged below) marquee path for empty-canvas mousedown:
if (!canvas) return; ... this.startMarquee(e, canvas);
```
Keep the early `if (this.activeWidget || this.activeModal || this.marquee) return;` at the top. Do NOT change startMove/startResize internals, the marquee path, scale/align math, or anything from 8b285eb. widget-resize.js changed ⇒ App.razor must remain `?v=2` (already so).

## VERIFY / DoD (role-shell §A — ⛔ LIVE gate, not object-store)
- **Object-store:** onMouseDown starts move (drag-handle / header-hidden) + resize (handle class → dir) synchronously via data-widget-id, excludes toolbar/content, keeps marquee; App.razor widget-resize.js?v=2.
- **Soma (Profile A) — REPORT NUMBERS:** /ops/build = **0 errors** (+W); /ops/test?suite=unit = **failed=0** (+passed).
- **⛔ LIVE GATE (operator/coordinator on 234, rebuild + hard-refresh):** click+drag a widget by its header → MOVES and **RELEASES on mouseup** (no stick); rapid repeat still releases; each resize handle resizes+releases; plain click still SELECTS; toolbar config/delete/template work; marquee works on empty canvas; header-hidden widget drags by body. Do NOT report GREEN without the live no-stick + move-actually-works confirmation.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY widget-resize.js (+ App.razor only if it needed the ?v=2 restore; + role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): WIDGET-STICK completion — add synchronous move/resize start in widget-resize.js onMouseDown (8b285eb removed triggers only) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B: "A two-part fix (remove old trigger + add new sync trigger) was committed with ONLY the removal half → move/resize left with NO trigger (dead). Lesson: when a fix REPLACES a mechanism, verify BOTH the removal AND the replacement landed in the SAME commit (git show --stat must include ALL claimed files); a commit missing a claimed file is an incomplete fix even if it compiles." SOURCE:8b285eb (2 files, widget-resize.js absent). Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed n> . files widget-resize.js . status done|failed . blockers . verified: object-store (LIVE move+resize work + no-stick = operator gate, pending)
```
