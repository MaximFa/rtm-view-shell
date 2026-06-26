# CC task — CC-3: T3 left-palette PUSH+collapse + T4 edit-canvas grid background (role-shell)
> §4-PASS by coordinator-0612 2026-06-17T09:08Z (operator/Маяк sequence: next = T3+T4). Owner: role-shell. Executor: native CC.
> Claims: src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor + wwwroot/app.css + Components/App.razor (css?v bump). Commit `feat:`. **NO push**.
> Anchors VERIFIED by git show HEAD: .editor-palette @app.css:2457 (position:fixed+translateX overlay), .editor-canvas @2503, [dir=rtl] .editor-palette @2474, dark-mode @2614+; PaletteOpen/TogglePalette @ScreenEditorPage 47/101/174/2257-2258; .dashboard-canvas-grid @app.css:1441 (no grid pattern).

## INIT (role-shell) + §40
- role-shell INIT: read role-shell.md §A + §C verify-green.
- §40: widget-planner / widget-creator / session-coord skills.

## §0.6a integrity + POST-VERIFY norm — RELIABLE FLOOR ONLY (ls+cat+git show HEAD, NOT -f/-s stat; mount phantoms -> escalate operator real-FS)
branch v2-backend; hash-verify the 3 claimed files vs HEAD before editing.

## §42.6 sync — slug shell-0609
- S1 `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> STOP. S2 `python3 tools/coord_check_claims.py shell-0609 <3 files>`.
- S3 commit.lock (owner shell-0609; if mount shows held -> verify by cat empty/absent, escalate if ambiguous). S4 cc_post_commit.sh. S5 NO push.
## §0.3 Edit BANNED — Python+os.fsync; verify by cat/git, not stat.

## Binding PREAMBLE -> .coord/cc/shell.md: ## 2026-06-17T09:08Z | binding: shell <-> CC | directive: tools/cc_prompt_cc3_palette_push_grid.md | status: open / ### DIRECTIVE: T3 palette in-flow push+collapse + T4 canvas grid bg. feat:. NO push.

## T3 — left palette PUSHES canvas (in-flow) + collapse-to-zero (NOT overlay)
Current = `.editor-palette` is `position:fixed; transform:translateX(-100%)`, `.open->translateX(0)` -> slides OVER canvas, hides widgets. Fix to in-flow push:
1. ScreenEditorPage.razor (~L101-174): wrap `.editor-palette` + `.editor-canvas` in a new `<div class="editor-body">...</div>`.
2. app.css: add `.editor-body { display:flex; flex:1; min-height:0; }`.
3. app.css `.editor-palette` (~2457): REMOVE `position:fixed`, `transform`/translateX, overlay `box-shadow`. Make in-flow: `flex:0 0 auto; width:0; overflow:hidden; transition:width var(--dur-slow) var(--ease-out);` keep inline-end border. `.editor-palette.open { width:300px; }` -> opening GROWS the column, canvas reflows.
4. app.css `.editor-canvas` (~2503): add `flex:1; min-width:0;` (min-width:0 so it can shrink) -> canvas is PUSHED right by open palette, reclaims full width when closed.
5. REMOVE the `[dir=rtl] .editor-palette` translateX rule (~2474) — flex order already puts palette inline-start; verify in he-IL. Check the dark-mode `.editor-palette` rule (~2614+) doesn't re-set position.
6. Persist open/closed per-user: localStorage key `cc:screeneditor:palette:{userId}` (§41 — userId in key, no PII; cleared on logout via existing cc: prefix clear). Restore on load, save on TogglePalette.
**Acceptance:** open palette pushes canvas right (widgets fully visible, never covered); close collapses to literal 0 width, canvas fills screen; smooth width transition; state persists per-user; 1280-wide + light/dark + LTR/RTL OK; palette drag&drop to canvas still works.

## T4 — edit-canvas faint background grid (folds into T3 CSS)
Add a faint ~32px grid background to `.dashboard-canvas-grid` (app.css:1441) in EDITOR mode ONLY (NOT `.viewer-mode` @1447). Use a repeating linear-gradient grid, low-contrast in BOTH light and dark (e.g. `background-image: linear-gradient(...) ; background-size: 32px 32px;` with a dark-mode override under `.editor-fullscreen.dark-mode`). Pairs with T1 guides/snap. No markup change (class exists).
**Acceptance:** editor canvas shows a faint 32px grid (light+dark); viewer mode unchanged (no grid); widgets/guides still readable over it.

## VERIFY
- `dotnet build src/CcDashboard.Web -c Debug` -> 0 errors.
- app.css: `.editor-body` present; `.editor-palette` no longer position:fixed (grep); `.editor-canvas` has flex:1 min-width:0; rtl translateX rule gone; `.dashboard-canvas-grid` has grid background-image (editor) + dark override. app.css?v bumped in App.razor.
- ScreenEditorPage: `.editor-body` wraps palette+canvas; localStorage palette persist wired (§41 userId key).
- PRODUCT ACCEPTANCE (operator on 5239): palette pushes canvas (no overlay), collapses to 0, grid visible in editor; report = code-correct by object-store, product-floor = operator.

## §0.6b CAPTURE -> role-shell §B (git add -f) if a real lesson (e.g. in-flow flex push vs fixed-overlay; localStorage §41 per-user key).

## Commit (feat:, NO push) under commit.lock
pre-commit-check ; git add (3 changed claimed files + role-shell.md if CAPTURE) ; git commit -m "feat: editor left-palette in-flow push+collapse-to-zero (per-user persist) + faint canvas grid background [shell-0609]" ; rev-parse HEAD ; §0.6 post-commit (git show HEAD verify) ; cc_post_commit.sh shell-0609 <hash> ; PD-007 re-sync ; sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; palette in-flow push+collapse (no fixed/translateX), per-user persist; canvas grid bg light+dark; build 0 err; app.css?v bumped; CAPTURE if any. NO push. verified: object-store. product-floor=operator 5239.

## Report (chat): commit hash; T3 (palette push/collapse, persist) + T4 (grid) confirmed via git show HEAD; build; app.css?v; note product-floor=operator. NO push.
