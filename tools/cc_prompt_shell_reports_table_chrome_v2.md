# CC task — Reports widget table chrome v2 (shell): bounded-height flex-column card (R3/R5/R8/R6 live-RED) — AWAITING §4-BLESS
> Coordinator live-DOM-verified (Test66 / Prod Mirror 019e03e9): commit 55879dd passed object-store but FAILED the visual gate. `.report-widget-table-scroll` has `overflow-y:auto` but is NOT height-bounded → `clientHeight==scrollHeight==2244px`, `getBoundingClientRect().top==-660` (off-card). Cascade: R3 no scrollbar (outer canvas scrolls), R5/R8 sticky thead pins to the off-card top (headers out of view), R6 footer floats over rows instead of a bottom bar.
> ROOT CAUSE (object-store, confirmed): the markup is correct (`.report-widget-table-container` + `.report-widget-footer` are siblings), BUT `.report-widget-render` is a **centering row-flex** — `display:flex; align-items:center; justify-content:center` (app.css ~:3322) — NOT a fixed-height **column**. So the table-container is laid out as a centered row item, never clamped to the card height → it grows to full content height (2244px) and `overflow:auto` never engages. `.widget-content` (shared) already provides `height:100%` + `min-height:0` + `.widget-content > * { height:100% }` — so the card height IS available; it's `.report-widget-render` that breaks the chain.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37). claim=frontend (web).
> Parity-guard: report-scoped CSS ONLY. Do NOT touch `.widget-content` (shared) / ScreenEditorPage / dashboard widgets / shared selectors.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- pre-existing `D Installations/*` deletions are NOT ours — do not touch.
- §0.3 Python+fsync; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`. Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_table_chrome_v2.md | status: open
### DIRECTIVE (spec->CC): table-chrome v2 — .report-widget-render flex-column min-height:0 (drop centering) + footer flex:0 0 auto + state margin:auto. app.css report-scoped. fix:, NO push, §4 + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/wwwroot/app.css — MODIFY (`.report-widget-render` + `.report-widget-footer` + non-table state centering; report-scoped ONLY)
- src/CcDashboard.Web/Components/ReportWidgets/*ReportWidget.razor — MODIFY ONLY IF a non-table state needs a centering class (prefer pure CSS; minimal markup)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)
- DO NOT edit `.widget-content` (shared) or any dashboard/shared selector.

## GROUNDING (object-store v3, app.css + QueueIntervalReportWidget)
- `.report-widget-render` (~:3322): `display:flex; align-items:center; justify-content:center; height:100%; min-height:120px;` ← the centering-row that breaks height-bounding.
- `.report-widget-table-container` (~:3512): `display:flex; flex-direction:column; flex:1; min-height:0; overflow:hidden;` (good — but its PARENT must be a column that clamps it).
- `.report-widget-table-scroll` (~:3521): `flex:1; overflow-y:auto; overflow-x:auto; min-height:0;` (good once parent chain is bounded).
- `.report-widget-footer` (~:3543): flex row; needs explicit `flex:0 0 auto` so it pins at bottom and never grows.
- sticky thead rule already present (~:3529). `.widget-content` (~:1586) shared: `flex:1 1 0; min-height:0; overflow:hidden` + `> *{height:100%}` — leave it.
- Widget markup (all type widgets): the data branch renders `<div class="report-widget-table-container">…scroll…</div>` then `<div class="report-widget-footer">…</div>` as TWO siblings (correct). Non-data branches: alert-warning / alert-danger / spinner / alert-info (single child).

## THE WORK (app.css — report-scoped)
1. Change `.report-widget-render` to a fixed-height COLUMN:
   `.report-widget-render { display:flex; flex-direction:column; height:100%; min-height:0; }`
   — REMOVE `align-items:center; justify-content:center;` (they force the centered-row that prevents height-bounding). Keep the bg/text rule (~:3496) and the appearance var rules unchanged.
   (Drop or keep `min-height:120px` — keep only if it doesn't reintroduce growth; a fixed card height comes from `.widget-content`. Prefer removing it or making it not fight the column.)
2. `.report-widget-footer { flex: 0 0 auto; }` (add) — bottom bar, never grows, not overlay.
3. `.report-widget-table-container { flex: 1 1 auto; min-height: 0; }` (ensure `1 1 auto`, keep flex-direction:column + overflow:hidden). `.report-widget-table-scroll { flex: 1 1 auto; min-height: 0; overflow-y:auto; overflow-x:auto; }` (ensure `1 1 auto`).
4. Non-table states stay centered in the column: add report-scoped centering for the alert/spinner/placeholder so they don't top-stretch ugly — e.g. `.report-widget-render > .alert, .report-widget-render > .spinner-border, .report-widget-render > .report-widget-unconfigured, .report-widget-render > div.text-center { margin: auto; }` (verify the actual state element selectors; goal = single non-table child centers vertically+horizontally in the column). Keep it report-scoped.
5. Result chain (verify by reasoning): `.dashboard-widget` (fixed abs height) → `.widget-content` (height:100%, min-height:0, overflow:hidden) → `.report-widget-render` (flex column, height:100%, min-height:0) → `.report-widget-table-container` (flex:1 1 auto, min-height:0) → `.report-widget-table-scroll` (flex:1 1 auto, min-height:0, overflow:auto) [scrolls; sticky thead pins to visible top] + `.report-widget-footer` (flex:0 0 auto) [bottom bar]. The `min-height:0` at EVERY flex level is what lets the scroll container shrink below content (the fix for the 2244px).

## VERIFY / DoD (role-shell §A — ⛔ LIVE on Test66/Prod Mirror, NOT object-store / NOT "CSS present")
- **Object-store:** `.report-widget-render` is flex-column with min-height:0 and NO align/justify-center; `.report-widget-footer` has flex:0 0 auto; container/scroll flex:1 1 auto + min-height:0; non-table state centering added; `.widget-content`/dashboard/shared UNTOUCHED.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE (coordinator via Soma/Chrome or operator, real DOM):** open a widget with 25 rows on Prod Mirror → (a) header row VISIBLE at the top of the card; (b) on scrolling the body the headers STAY (sticky to the visible card top); (c) the scrollbar is INSIDE the card and the outer canvas does NOT move; (d) "Showing X of Y" + pager is a BOTTOM BAR, not floating over rows. Confirm `.report-widget-table-scroll` clientHeight < scrollHeight (bounded) and its rect.top is within the card. Do NOT report "done" without live confirmation.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY app.css (+ any minimal widget markup + role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports widget table chrome — bounded-height flex-column card so scroll/sticky-header/footer work [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (MANDATORY): "object-store 'CSS present' ≠ visual: `overflow:auto` does NOTHING unless the element has a BOUNDED height — every flex ancestor in the chain needs `min-height:0` AND the immediate parent must be a fixed-height flex-COLUMN (not a centering row-flex). A centering `.report-widget-render` (align/justify-center) let the scroll container grow to full content (2244px) → no scrollbar + sticky thead off-card. Always live-verify scroll/sticky (clientHeight<scrollHeight, rect.top in-card)." SOURCE:<commit> + coordinator live-DOM 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files app.css (+widgets if any) . status done|failed . blockers . verified: object-store (LIVE scroll/sticky/footer = coordinator gate, pending)
```
