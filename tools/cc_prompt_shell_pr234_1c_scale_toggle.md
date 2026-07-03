# CC task — PR234-1c (shell): View scale-mode toggle (A scale-to-fit / B 1:1) in fullscreen topbar — AWAITING §4-BLESS
> Operator ruling on the Edit↔View size "mismatch" (which is the INTENTIONAL scale-to-fit from 55cbf2d, editor stays 1:1): NOT a revert — add a **scale-mode toggle** in View mode.
> - **A = scale-to-fit** (current `viewerScale` uniform zoom of the board to the viewport) — **DEFAULT**.
> - **B = 1:1** (editor-parity absolute size; add scroll when the board is larger than the viewport).
> Toggle in the ScreenFullscreenPage topbar, NEXT TO the Dark/Light toggle; switches viewerScale on/off live; clear icon/label. Persisting the choice = optional v1 (localStorage per §41: key `cc:{feature}:{userId}`, cleared on logout) — if you persist, follow §41 EXACTLY; else session-scoped.
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `feat:`. **NO push** (§37). Report-scoped, parity-guard (do NOT touch the editor or shared selectors; ScreenFullscreenPage + its viewerScale usage only).

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY; §41 localStorage if persisting)
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
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_pr234_1c_scale_toggle.md | status: open
### DIRECTIVE (spec->CC): PR234-1c View scale-mode toggle (A fit default / B 1:1) in ScreenFullscreenPage topbar. v3, feat:, NO push, §4 + QA gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor — MODIFY (topbar toggle + scale-mode state + conditional viewerScale)
- src/CcDashboard.Web/wwwroot/app.css — MODIFY ONLY IF a 1:1 scroll-container style is needed (report/fullscreen-scoped, additive)
- src/CcDashboard.Web/wwwroot/js/app.js OR js/widget-resize.js (viewerScale) — MODIFY ONLY IF a `viewerScale.reset/disable` helper is needed (do NOT change existing scale math)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx — MODIFY (toggle labels)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING (object-store v3, ScreenFullscreenPage.razor)
- Scale-to-fit today: `.fullscreen-scale-wrap` (:54) → design layer `style="width:_designWidth px; height:_designHeight px; position:relative"` (:56); `_designWidth/_designHeight = PlacedWidgets.Max(w=>w.X+w.Width)+32 / +... +32` (:170-171); `viewerScale.init(_designLayerRef, _designWidth, _designHeight)` applied once after positions (:194-198); `viewerScale.dispose()` on Dispose (:299). viewerScale sets CSS transform:scale on the design layer to fit the wrap.
- The topbar already has a Dark/Light toggle button (find it — place the new toggle next to it). `_darkMode` toggle exists.

## THE WORK
1. Add `_scaleMode` state: `"fit"` (A, default) | `"actual"` (B). If persisting per §41: read `cc:screenview:scalemode:{userId}` on init (default "fit"); write on toggle; ensure LogoutPage `cc:`-clear covers it (it does via prefix). Else session-scoped.
2. Topbar: add a toggle button NEXT TO the Dark/Light toggle — e.g. an icon toggling between "fit-to-screen" and "1:1" (bi-aspect-ratio / bi-arrows-angle-expand vs bi-1-square) + a title/label. `@onclick` flips `_scaleMode` and applies live (below).
3. Apply live:
   - **A (fit):** current behaviour — `viewerScale.init(_designLayerRef, _designWidth, _designHeight)`; `.fullscreen-scale-wrap` clips/centers (no scroll).
   - **B (1:1):** DISABLE the scale — remove the transform (call a `viewerScale.dispose()`/reset so the design layer is at natural px), and make `.fullscreen-scale-wrap` (or a wrapper) `overflow:auto` so the full-size board scrolls when larger than the viewport. Widgets then match the EDITOR absolute size.
   - On toggle, switch WITHOUT reload: re-apply/tear-down viewerScale + set the wrap overflow accordingly; recompute on window resize only in fit mode (keep the existing resize listener behaviour for A; in B no scaling).
4. Keep the editor 1:1 (do NOT touch ScreenEditorPage). Do NOT change viewerScale's scale math (only enable/disable it). New CSS is fullscreen-scoped + additive.

## VERIFY / DoD (role-shell §A — ⛔ LIVE gate, not object-store)
- **Object-store:** ScreenFullscreenPage has `_scaleMode` (default "fit") + a topbar toggle next to Dark/Light; A calls viewerScale.init, B disables scale + overflow:auto scroll; editor untouched; scale math unchanged; (if persisted) §41-compliant key + logout-clear.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE (operator/coordinator on 234):** open a dashboard in View → default = scale-to-fit (whole board fits); click the toggle → **1:1** = widgets at editor-parity absolute size with scroll when larger than viewport; toggle back → fit. (If persisted: choice survives reload; cleared on logout.) Do NOT report without live confirmation.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY claimed files (+ role-skill if CAPTURE). Commit `feat(web): PR234-1c View scale-mode toggle (scale-to-fit / 1:1) in fullscreen topbar [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed): "Edit↔View size difference is the intentional viewer scale-to-fit (55cbf2d); operator wanted CHOICE not revert → scale-mode toggle (A fit default / B 1:1+scroll) in the View topbar, enabling/disabling viewerScale live (don't change its math)." SOURCE:<commit> + operator 2026-07-02. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0/unit n/0> . files ScreenFullscreenPage.razor (+app.css/js/resx) . status done|failed . blockers . verified: object-store (LIVE A/B toggle = operator gate, pending)
```
