# CC task — CC-2 FIX: T2 B1 two product bugs (selection highlight + persist) (role-shell)
> §4-PASS by coordinator-0612 2026-06-17T11:11Z (operator product-floor 5239: B1 works; 2 bugs). Owner: role-shell. Executor: native CC.
> Claims: widget-resize.js + Components/Dashboard/ScreenEditorPage.razor + wwwroot/app.css. Commit `fix:`. **NO push**.
> #3 marquee/rubber-band = NEW SCOPE (CC-2b), NOT this task.

## INIT (role-shell §A + §C-green) + §40. §0.6a integrity + POST-VERIFY (ls+cat+git, NOT -f/-s). §42.6 sync shell-0609 (S1-S5). §0.3 Python+fsync. Binding PREAMBLE -> .coord/cc/shell.md.

## BUG #1 — selected widgets NOT visually highlighted (multi-select)
ROOT (object-store): CSS `.dashboard-widget.selected` EXISTS (app.css:1482 light, 2693 dark). BUT the widget div binds the class
ONLY to the single-select field: `ScreenEditorPage.razor:194 class="dashboard-widget @(SelectedWidgetId == widget.Id ? "selected" : "")"`.
The MULTI-select set lives in JS (`widget-resize.js selectedWidgets` Set + `updateSelectionClasses` classList.add). On any Blazor
re-render, the razor binding REWRITES the class attribute -> wipes the JS-added `.selected` for every multi-selected widget except
the single SelectedWidgetId. => multi-selected widgets show no outline (or flicker off on re-render). DUAL source of truth.
FIX (recommended — single source of truth, survives re-render): make BLAZOR own the multi-selection set.
  - Add a `HashSet<Guid> SelectedWidgetIds` (Blazor field). Bind the class from it: `@(SelectedWidgetIds.Contains(widget.Id) ? "selected" : "")` (keep single-select behaviour by also adding the clicked id to the set, or union with SelectedWidgetId).
  - JS notifies Blazor of selection changes via a [JSInvokable] (e.g. `OnSelectionChanged(Guid[] ids)`) so the set + render stay in sync; then `updateSelectionClasses` is for instant visual only and Blazor render no longer clobbers it (because the binding now reflects the set). Ensure any new [JSInvokable]/type has its @inject/@using (CS0103 guard — cf CC-3).
  (Alternative if simpler: keep selection in JS but stop the razor binding from overwriting — e.g. bind `.selected` from a method that consults the JS set via a synced Blazor field. EITHER way: ONE source of truth, outline persists across re-render.)
ACCEPTANCE: Ctrl/Shift-click -> EVERY selected widget shows the `.selected` outline and KEEPS it across re-renders/drag; light+dark+RTL.

## BUG #2 — selection clears on mouseup after a group move (should persist until click-empty)
ROOT: the move-end path (onMouseUp / OnWidgetsMoved commit) clears the selection. Plan acceptance = "click EMPTY canvas deselects",
NOT mouseup. FIX: after a group move + persist, DO NOT clear `selectedWidgets` (and DO NOT reset the Blazor set). Selection clears
ONLY on `clearSelection` (empty-canvas click, widget-resize.js:57) or a plain no-modifier single-widget click (standard reselect).
Find and remove the clear-on-mouseup. Keep single-widget drag behaviour unaffected.
ACCEPTANCE: select group -> move -> RELEASE mouse -> group STAYS selected (outlines remain); click empty canvas -> deselects; another modifier-click toggles.

## VERIFY — MANDATORY build cite (shell sandbox has no dotnet -> if you cannot build, SAY SO explicitly and the native runner/operator builds; do NOT claim "0 err" un-run)
- Object-store: razor binds .selected from the multi-set (not just SelectedWidgetId); no clear-on-mouseup in widget-resize.js; app.css?v bump if CSS touched.
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line into RESULT. If sandbox has no dotnet, write "BUILD: not run (no dotnet in sandbox) — needs native build" — do NOT claim pass.**
- Any new C# member/[JSInvokable] -> @inject/@using present (grep) BEFORE relying on it.

## §0.6b CAPTURE -> role-shell §B (e.g. dual source-of-truth for a CSS state class: Blazor binding clobbers JS classList on re-render -> pick ONE owner).

## Commit (fix:, NO push) under commit.lock: git add (changed claimed files + role-shell.md if CAPTURE) ; commit -m "fix: T2 B1 selection highlight (Blazor owns multi-select set) + persist selection until click-empty (not mouseup) [shell-0609]" ; §0.6 post-commit (git show HEAD) ; cc_post_commit.sh ; PD-007 re-sync ; sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; #1 .selected from multi-set (survives re-render); #2 no clear-on-mouseup; build cite OR explicit "not run (no dotnet)"; CAPTURE if any. NO push. verified: object-store (+ build if available).

## Report (chat): commit hash; both bugs' fix confirmed via git show HEAD; build line OR honest "not run"; product-floor=operator 5239. NO push.
