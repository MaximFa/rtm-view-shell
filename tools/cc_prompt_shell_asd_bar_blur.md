# CC task — ASD-BAR-BLUR fix (shell): crisp Chart.js canvas via devicePixelRatio supersampling (ASD + DayTrend + reportDistribution) — AWAITING §4-BLESS

> Reject ASD-BAR-BLUR (234, screen «12»): Agent State Distribution bars have BLURRED edges (badges beside them are crisp).
> ROOT (coordinator LIVE-measured on 234 via JS): the ASD `<canvas>` bitmap = 327x209 but is DISPLAYED at 364x232 (×1.11 upscale) → blurred raster. Cause: `agentStateDistributionChart.js` chartOptions has NO `devicePixelRatio`, so Chart.js sizes the bitmap = CSS × window.devicePixelRatio (0.9 at the operator's browser zoom/DPR) → bitmap SMALLER than the display → upscale blur. DOM badges are vector → crisp. No ancestor transform/filter involved.
> FIX: force supersampling — set `devicePixelRatio: Math.max(2, window.devicePixelRatio || 1)` in the Chart.js options so the bitmap is always ≥ display size (browser downscales → crisp) regardless of zoom/DPR. Same defect class in ALL 3 Chart.js widgets → fix all three in one commit (prevents whack-a-mole). The translucent fill (`clr+'40'`, 25%) is intentional design (matches DayTrend) — DO NOT change it.
> ⚠ JS changes → MUST bump each file's `?v` in App.razor (PR234-1c: stale JS = old behavior). Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37). Report-scoped.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + BRANCH NORM (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3; verify HEAD == v3 tip (adbf5d7 or later, now on origin)
git fetch origin && git rev-parse origin/v3   # local should be == or ahead of origin/v3 (adbf5d7)
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
## BINDING 2026-07-06T??:??Z | spec: shell | directive: tools/cc_prompt_shell_asd_bar_blur.md | status: open
### DIRECTIVE (spec->CC): ASD-BAR-BLUR — add devicePixelRatio supersampling to the 3 Chart.js widget options (ASD+DayTrend+reportDistribution) + bump ?v in App.razor. v3, fix:, NO push, §4 + LIVE gate. Report build=0 + unit failed=0 WITH COUNTS.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/wwwroot/js/agentStateDistributionChart.js  — MODIFY (add devicePixelRatio to chartOptions)
- src/CcDashboard.Web/wwwroot/js/daytrendChart.js                — MODIFY (same)
- src/CcDashboard.Web/wwwroot/js/reportDistributionChart.js      — MODIFY (same)
- src/CcDashboard.Web/Components/App.razor                       — MODIFY (bump ?v=1 -> ?v=2 for those 3 <script> lines only)

## GROUNDING (object-store)
- Each JS file builds a `chartOptions` object with `responsive: true,` + `maintainAspectRatio: false,` then `new Chart(ctx, { type, data, options: chartOptions })`:
  · agentStateDistributionChart.js: `responsive:` L40, `maintainAspectRatio:` L41, `new Chart` L164.
  · daytrendChart.js: L27, L28, `new Chart` L144.
  · reportDistributionChart.js: L41, L42, `new Chart` L105.
- App.razor L40-42: `daytrendChart.js?v=1`, `agentStateDistributionChart.js?v=1`, `reportDistributionChart.js?v=1`.
- Coordinator 234 measure (ASD): DPR=0.9, canvas.width/height=327×209, getBoundingClientRect=364×232, css/attr=×1.11, no ancestor transform/filter.

## THE WORK — one line per chart file + the ?v bumps
### A. In EACH of the 3 JS files: add to the chartOptions object, immediately AFTER `maintainAspectRatio: false,`:
```javascript
devicePixelRatio: Math.max(2, window.devicePixelRatio || 1),
```
(Do NOT touch datasets, fill opacity `clr+'40'`, borders, scales, legend, or the `new Chart(...)` call. Only add the one option key to the existing chartOptions object.)
### B. App.razor L40-42: bump each of the 3 `?v=1` -> `?v=2` (only these three <script> lines; leave other scripts' ?v untouched).
### C. Do NOT change: any .razor widget component, .cs, the render/destroy interop signatures, or non-chart JS.

## VERIFY / DoD (role-shell §A — ⛔ LIVE gate, not object-store)
- **Object-store:** all 3 chartOptions carry `devicePixelRatio: Math.max(2, window.devicePixelRatio || 1)`; App.razor has `?v=2` for all 3; nothing else changed (fill opacity/borders/scales intact).
- **Soma (Profile A) — REPORT NUMBERS:** /ops/build = **0 errors** (+W); /ops/test?suite=unit = **failed=0** (+passed).
- **⛔ LIVE GATE (coordinator on 234, rebuild + hard-refresh — new ?v=2):** on screen «12», ASD bar edges are now CRISP (canvas bitmap ≥ display: verify `canvas.width >= getBoundingClientRect().width`); DayTrend + report distribution charts still render correctly (no regression); badges unchanged. Do NOT report GREEN without the live crisp-edge confirmation.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY the 4 claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): ASD-BAR-BLUR — Chart.js devicePixelRatio supersampling (ASD+DayTrend+reportDistribution) + ?v=2 [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B: "Chart.js on <canvas> blurs when the browser is at a fractional DPR/zoom (e.g. 0.9): Chart.js sizes the bitmap = CSS × window.devicePixelRatio, so a <1 DPR yields a bitmap SMALLER than the CSS display → upscale blur (DOM/vector siblings stay crisp, hence the contrast). FIX: set chart option devicePixelRatio: Math.max(2, window.devicePixelRatio||1) to supersample (bitmap always ≥ display, browser downscales → crisp). Rule: any Chart.js canvas widget must pin an explicit devicePixelRatio ≥ its display scale; never rely on the ambient (zoom-dependent) DPR. + JS change ⇒ App.razor ?v bump (PR234-1c)." SOURCE: coordinator 234 JS-measure ASD canvas 327×209 vs 364×232 @DPR0.9, 2026-07-06. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed n> . files agentStateDistributionChart.js + daytrendChart.js + reportDistributionChart.js + App.razor(?v=2 x3) . status done|failed . blockers . verified: object-store (LIVE crisp edges = coordinator 234 gate, pending)
```
