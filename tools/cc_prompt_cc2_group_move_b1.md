# CC task — CC-2: T2 widget grouping B1 (ephemeral multi-select + move-as-block) (role-shell)
> §4-PASS by coordinator-0612 2026-06-17T10:35Z (operator chose B1; CC-3 product-verified). Owner: role-shell. Executor: native CC.
> Claims: src/CcDashboard.Web/wwwroot/js/widget-resize.js + Components/Dashboard/ScreenEditorPage.razor + wwwroot/app.css + 3 SharedResources.*.resx. Commit `feat:`. **NO push**.
> B1 = ephemeral selection (NO data model, NO migration). B2 persistent groups = DEFERRED cross-territory (not this task).

## INIT (role-shell §A + §C-green) + §40 reads.

## §0.6a integrity + POST-VERIFY (RELIABLE FLOOR: ls+cat+git show HEAD, NOT -f/-s stat; mount phantoms -> escalate operator real-FS). branch v2-backend; hash-verify claimed files vs HEAD.
## §42.6 sync slug shell-0609: S1 barrier · S2 coord_check_claims (the 5 files) · S3 commit.lock · S4 cc_post_commit · S5 NO push. §0.3 Edit BANNED (Python+fsync).
## Binding PREAMBLE -> .coord/cc/shell.md: ## 2026-06-17T10:35Z | binding: shell <-> CC | directive: tools/cc_prompt_cc2_group_move_b1.md | status: open / ### DIRECTIVE: T2 B1 ephemeral multi-select + group move. feat:. NO push.

## THE WORK — B1 (grounded in widget-resize.js move loop + ScreenEditorPage canvas)
1. **Selection set (JS):** Ctrl/Cmd-click (and Shift-click) on a widget toggles it in a selection set; click on EMPTY canvas clears the set. Track in widget-resize.js (and/or a Blazor field). Selected widgets get a `.selected` class/outline.
2. **Render:** ScreenEditorPage.razor — wire the modifier-click handlers (don't break normal single-click select/drag); add `.selected` to the widget div when in the set. app.css: `.dashboard-widget.selected` outline (dark+RTL safe) + optional group bounding-box style.
3. **Group move:** in widget-resize.js `startMove`/`onMouseMove` (mode==='move'): if the widget being dragged IS in the selection set (size>1), apply the SAME delta (dx,dy) to ALL selected widgets' live style.left/top. T1 alignment guides reference the group's bounding box (not just the dragged widget) when a group is active.
4. **Commit:** on `onMouseUp`, persist EVERY moved widget. Prefer a batch JSInvokable `OnWidgetsMoved([{id,left,top},...])` (one round-trip) — if you add it to ScreenEditorPage, ENSURE every type/service it uses is already injected/usable (the CS0103 class: a new C# member needs its @inject/@using). Else call existing `OnWidgetMoved` per widget. Selection set is ephemeral — NOT persisted.
5. resx: any new UI label (e.g. selection hint) -> en/ru/he parity.
6. app.css?v bump in App.razor (new CSS class).

## Acceptance (product on 5239, operator floor)
Ctrl/Shift-click selects multiple (`.selected` outline); dragging any selected widget moves ALL by the same delta; each new position PERSISTS (refresh shows them moved); click empty canvas deselects; SINGLE-widget drag is unaffected; alignment guides reference the group bbox; light+dark+RTL OK.

## VERIFY — MANDATORY, NO EXCEPTIONS (the build-cite rule — 2 false build claims today)
- **ACTUALLY run `dotnet build src/CcDashboard.Web -c Debug` -> 0 errors. PASTE the "Build succeeded / 0 Error(s)" line into the report AND the binding RESULT.** A binding that claims build-pass WITHOUT a cited build run will be REJECTED at §4.
- JS parses; object-store: `.selected` handling in widget-resize.js + ScreenEditorPage; `.dashboard-widget.selected` in app.css; batch commit (OnWidgetsMoved or per-widget); resx parity; app.css?v bumped.
- If you add ANY new C# member/usage to ScreenEditorPage -> confirm its @inject/@using exists (grep) BEFORE build (CS0103 guard).

## §0.6b CAPTURE -> role-shell §B (git add -f) — real lesson if any (e.g. group-delta move; batch JSInvokable round-trip).

## Commit (feat:, NO push) under commit.lock
pre-commit-check ; git add (changed claimed files + role-shell.md if CAPTURE) ; git commit -m "feat: widget ephemeral multi-select + move-as-block (T2 B1) [shell-0609]" ; rev-parse HEAD ; §0.6 post-commit (git show HEAD) ; cc_post_commit.sh shell-0609 <hash> ; PD-007 re-sync ; sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; B1 multi-select + group-move + batch commit; **dotnet build CITED: <0-Error line>**; app.css?v bumped; CAPTURE if any. NO push. verified: object-store + REAL build.

## Report (chat): commit hash; the ACTUAL build output line (0 err); B1 behaviour; app.css?v; note product-floor=operator 5239. NO push.
