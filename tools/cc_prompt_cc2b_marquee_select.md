# CC task — CC-2b: rubber-band marquee selection + dashed group outline (role-shell, NEW scope)
> §4-PASS by coordinator-0612 2026-06-17T12:43Z (operator #3, new scope on top of CC-2 B1). Owner: role-shell. Executor: native CC.
> Claims: widget-resize.js + Components/Dashboard/ScreenEditorPage.razor + wwwroot/app.css (+ 3 resx if labels). Commit `feat:`. **NO push**.
> Builds on the CC-2-fix selection model (Blazor SelectedWidgetIds owns highlight; JS selectedWidgets drives move; the two STAY IN SYNC — marquee MUST update BOTH so highlighted==moved).

## INIT (role-shell §A + §C-green) + §40. §0.6a integrity + POST-VERIFY (ls+cat+git, NOT -f/-s). §42.6 sync shell-0609 (S1-S5). §0.3 Python+fsync. Binding PREAMBLE -> .coord/cc/shell.md.

## THE WORK — marquee (rubber-band) area select
1. **Start:** mousedown on EMPTY canvas (NOT on a widget / handle) begins a marquee. (Widget mousedown = drag/move, unchanged. Empty-canvas plain click still = clearSelection per CC-2-fix; distinguish a click from a drag by a small move threshold.)
2. **Drag:** draw a marquee rectangle (a reusable div appended to the canvas, `position:absolute`, dashed border, faint fill, `pointer-events:none`, high z-index) that tracks from the mousedown point to the current cursor (handle all 4 drag directions). Class e.g. `.widget-marquee` in app.css (dark+RTL safe).
3. **Live candidate group:** while dragging, compute which widgets' boxes INTERSECT the marquee rect; mark those candidates with a DASHED outline (e.g. `.dashboard-widget.marquee-candidate`) UNTIL release (operator: "пока тянешь — группа отмечена пунктиром, до отпускания"). Cache widget rects at marquee start (they don't move) for O(n) per mousemove.
4. **Finalize (mouseup):** the intersected widgets become the selection. Update the SELECTION via the SAME path Ctrl-click uses so BOTH sets sync: JS `selectedWidgets` AND Blazor `SelectedWidgetIds` (so highlight == move, as verified for Ctrl-click). Remove the marquee div + the `.marquee-candidate` dashed marks (the finalized set shows the normal `.selected` highlight). Default = REPLACE selection; if Shift held during marquee = ADD to existing selection (standard).
5. Ctrl-click selection (CC-2) keeps working unchanged; marquee is an ADDITIONAL way to select.
6. app.css?v bump in App.razor (new classes). resx if any new label.

## Acceptance (product on 5239, operator floor)
Drag a box over empty canvas -> dashed marquee rect follows the cursor; widgets inside get a DASHED candidate outline while dragging; on release they become the selection (solid `.selected` highlight) and MOVE together as a group (highlighted==moved); Shift+marquee adds to selection; Ctrl-click still works; click-empty (no drag) still deselects; light+dark+RTL.

## VERIFY (build-cite or honest 'not run')
- Object-store: marquee handlers in widget-resize.js (empty-canvas mousedown threshold, rect draw, intersect, finalize syncing BOTH sets); `.widget-marquee` + `.marquee-candidate` in app.css; SelectedWidgetIds updated on finalize; app.css?v bump.
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line. If sandbox has no dotnet -> write "BUILD: not run (no dotnet)" — do NOT claim pass.** Any new C# member/[JSInvokable] -> @inject/@using present (CS0103 guard).

## §0.6b CAPTURE -> role-shell §B if a real lesson (e.g. marquee must update BOTH selection sets to keep highlight==move).

## Commit (feat:, NO push) under commit.lock: git add (changed claimed + role-shell.md if CAPTURE) ; commit -m "feat: rubber-band marquee area-select + dashed candidate outline (CC-2b) [shell-0609]" ; §0.6 post-commit ; cc_post_commit.sh ; PD-007 re-sync ; sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; marquee draw+intersect+finalize (BOTH sets synced), dashed candidate while dragging; build cite OR 'not run (no dotnet)'; app.css?v; CAPTURE if any. NO push. verified: object-store (+build if avail).

## Report (chat): commit hash; marquee behaviour; build line OR honest not-run; note highlighted==moved + product-floor=operator 5239. NO push.
