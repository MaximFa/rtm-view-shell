# CC task — CHART no-animation on refresh (shell): DayTrend + ASD draw instantly (Chart.js animation off) — §4 (4-edit batch)
> EDIT 4: DayTrend + AgentStateDistribution charts ANIMATE-redraw on each live refresh (uncomfortable). ROOT (object-store): the widgets call `.render` on EVERY refresh (DayTrendWidget.razor:490, AgentStateDistributionWidget.razor:405) — NOT `.update` — and the JS `render()` chart config has NO `animation` key → Chart.js default animation runs on every re-render. (The `update()` path already uses `chart.update('none')` but the widgets don't call it.)
> FIX: disable animation in the `render()` chart config for both charts. widget-resize/JS files change → App.razor `?v` bump. Do NOT touch fills/scales/dpr (prior fixes).
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix(web):`. **NO push**. Narrow claim.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/session-coord/session-coord.md

## INIT — §0.6a integrity + BRANCH NORM
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null); [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }; done; sync
```

## §0.6b BINDING PREAMBLE — .coord/cc/shell.md
```
## BINDING 2026-07-14T08:45:15Z | spec: shell | directive: tools/cc_prompt_shell_chart_no_anim.md | status: open
### DIRECTIVE (spec->CC): charts no-animation on refresh — daytrendChart.js + agentStateDistributionChart.js render() animation off + App.razor ?v bump. v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/wwwroot/js/daytrendChart.js  (render() config)
- src/CcDashboard.Web/wwwroot/js/agentStateDistributionChart.js  (render() config)
- src/CcDashboard.Web/Components/App.razor  (bump ?v=2 -> ?v=3 for THOSE TWO script lines only)

## GROUNDING (object-store)
- daytrendChart.js: `render:` (:5) builds a chart-options object then `this._charts[elementId] = new Chart(ctx, {... options})` (:145). `update:` (:152) already does `chart.update('none')` (:165). No `animation` key in the render options.
- agentStateDistributionChart.js: `render:` (:5), `new Chart` (:165), `update` (:172) `chart.update('none')` (:187). No `animation` key in render options.
- Widgets call `.render` on refresh (DayTrendWidget.razor:490 `dayTrendChart.render`; AgentStateDistributionWidget.razor:405 `agentStateDistributionChart.render`); `.destroy` only on dispose.
- App.razor:40-41 `daytrendChart.js?v=2`, `agentStateDistributionChart.js?v=2`.

## THE WORK
### A. In EACH render() chart-options object, disable refresh animation.
Preferred (keeps a one-time initial animation, kills per-refresh): compute BEFORE creating the chart
```javascript
var isRefresh = !!this._charts[elementId];   // chart already exists → this render is a live refresh
```
and set in the options object: `animation: isRefresh ? false : undefined,` (undefined = Chart.js default on first draw).
- If `render()` destroys/removes the existing chart from `this._charts` BEFORE this check (so isRefresh can't be read reliably), instead set `animation: false` unconditionally (simplest; instant draw always — acceptable for a realtime dashboard). Pick whichever is correct for the file's actual render flow; the REQUIREMENT is: NO animation on live refresh.
- Also acceptable/robust: keep `animation:false` in options AND leave the existing `update('none')`. Do NOT remove the update('none').
### B. App.razor — bump `daytrendChart.js?v=2` -> `?v=3` and `agentStateDistributionChart.js?v=2` -> `?v=3` (only those two lines; leave others).
### C. Do NOT change datasets, scales, fills, borders, devicePixelRatio, legend, or the reportDistributionChart.

## VERIFY / DoD
- Object-store: both render() configs disable animation on refresh; App.razor those 2 at ?v=3; no other chart option changed.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- ⛔ LIVE (coord 140 post-rebuild): DayTrend + ASD update on live refresh with NO redraw animation (instant); initial render acceptable; other charts unaffected.

## COMMIT
- pre-commit-check → commit.lock → stage the 3 files → `fix(web): charts — disable Chart.js animation on live refresh (DayTrend+ASD) + ?v=3 [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync. BATCH with the other 3 edits → ONE Shell rebuild.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files daytrendChart.js + agentStateDistributionChart.js + App.razor(?v=3 x2) . status . verified: object-store (LIVE no-anim = coord 140)
```
