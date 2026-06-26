# CC task — T5 (v1): viewer scale-to-fit responsiveness (role-shell)
> §4-PASS by coordinator-0612 2026-06-17T13:57Z (operator chose v1). Owner: role-shell. Executor: native CC.
> Claims: Components/Dashboard/ScreenFullscreenPage.razor (ratified Shell claim) + wwwroot/app.css + wwwroot/js/widget-resize.js (or a small viewer JS). Commit `feat:`. **NO push**.
> v1 = scale the VIEWER only (uniform zoom). EDITOR (ScreenEditorPage) stays 1:1, NOT touched. v2 %-coords / v3 grid-engine = deferred cross-territory.

## INIT (role-shell §A + §C-green) + §40. §0.6a integrity + POST-VERIFY (ls+cat+git, NOT -f/-s). §42.6 sync shell-0609 (S1-S5). §0.3 Python+fsync. Binding PREAMBLE -> .coord/cc/shell.md.

## ROOT / GROUNDING (object-store)
ScreenFullscreenPage.razor (runtime viewer): `.fullscreen-dashboard` > `.fullscreen-header` + `.fullscreen-canvas` (L44) > `.dashboard-canvas-grid` (L54, position:relative, min-height:calc(100vh-120px)) > widgets absolute px (`left:{X}px;top:{Y}px;width;height`, L61/66). No scaling today (widgets fixed px, COMPAT-02 fixed >=1280). v1 = uniformly zoom the whole board to fit the viewport (wall/TV).

## THE WORK — v1 scale-to-fit (VIEWER only)
1. **Design layer:** wrap the widget canvas (`.dashboard-canvas-grid` inside `.fullscreen-canvas`) in a fixed-size "design layer" div, e.g. `<div class="fullscreen-scale-wrap"><div class="fullscreen-design-layer" @ref=...>...grid...</div></div>`. The design layer holds the board at its NATURAL design size (the content extent).
2. **Design dimensions:** compute the board's design size = bounding box of all widgets = max(X+Width) x max(Y+Height) over PlacedWidgets (add a small padding). Set the design-layer width/height to that (so it's a fixed coordinate space the widgets already use).
3. **Scale on resize (JS):** add `scaleViewerToFit(wrapEl, designEl)`: `scale = Math.min(wrapW / designW, wrapH / designH)` (clamp max 1 if you don't want to upscale beyond 100%, OR allow upscale for TV — RECOMMEND allow upscale so it fills a wall; make it a simple min()). Apply `designEl.style.transform = 'scale('+scale+')'; transform-origin: top left;` and center via margins or translate. Recompute on `window resize` (debounced) + on viewer load (after positions applied).
4. app.css: `.fullscreen-scale-wrap { width:100%; height:100%; overflow:hidden; display:flex; align-items:center; justify-content:center; }` ; `.fullscreen-design-layer { transform-origin: top left; }` (JS sets the scale). Keep dark-mode + RTL safe.
5. Hook: call `scaleViewerToFit` from the viewer's OnAfterRenderAsync (after `_positionsApplied`) + register a window-resize listener (remove it in dispose to avoid leak — see role-shell §B lesson on listener leaks).
6. **DO NOT touch ScreenEditorPage** (editor stays 1:1).

## Acceptance (product on 5239, operator floor)
Open a screen in fullscreen viewer -> the whole board scales UNIFORMLY to fit the window (no scrollbars, aspect preserved); resize the window / different monitor -> board re-fits; widgets keep relative layout; editor mode is UNCHANGED (still 1:1, fixed px). Light+dark+RTL.

## VERIFY (build-cite or honest 'not run')
- Object-store: design-layer wrapper in ScreenFullscreenPage; scaleViewerToFit in JS (min ratio + transform); resize listener added + removed in dispose; ScreenEditorPage untouched; app.css wrap/design-layer rules; app.css?v bump.
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line; else honest "BUILD: not run (no dotnet)".** Any new C# (e.g. a design-size calc / @ref) -> @inject/@using guard.

## §0.6b CAPTURE -> role-shell §B if a real lesson (e.g. transform:scale on a design layer for uniform viewer fit; resize listener must be removed in dispose).

## Commit (feat:, NO push) under commit.lock: git add (changed claimed + role-shell.md if CAPTURE) ; commit -m "feat: fullscreen viewer scale-to-fit (uniform zoom of board to viewport; editor stays 1:1) (T5 v1) [shell-0609]" ; §0.6 post-commit ; cc_post_commit.sh ; PD-007 re-sync ; sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; design-layer + scaleViewerToFit(min ratio, transform-origin) + resize-listener(add/remove); editor untouched; build cite OR 'not run'; app.css?v; CAPTURE if any. NO push. verified: object-store (+build if avail).

## Report (chat): commit hash; viewer scale behaviour; editor untouched; build line OR honest not-run; product-floor=operator 5239. NO push.
