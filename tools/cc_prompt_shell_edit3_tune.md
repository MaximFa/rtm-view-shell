# CC task — edit-3 TUNE (shell): pagination reachable (table offset) + filter funnel top-aligned — §4 (one change-set, one rebuild)
> Coordinator 140 visual of 73ed34b: edits 1/2/4 GREEN. Two follow-ups (batch into ONE change-set):
> TUNE-A — pagination CUT OFF. `.table-responsive{max-height:calc(100vh-220px)}` is too tight; on the longest list (/admin/configuration/metrics, 202 rows) `.pagination-bar` bottom=934px > viewport 855px and an ancestor clips (document.scrollHeight<=innerHeight) → paging UNREACHABLE. Pages are normal-flow (header + optional search row + `.table-responsive` + sibling `.pagination-bar`), not a bounded flex card. FIX: shrink the table so table+pagination fit — increase the offset ≥~90px. Use `max-height: calc(100vh - 320px)` (tunable; coordinator re-verifies `.pagination-bar` bottom <= innerHeight on Metrics). app.css change → App.razor app.css?v=31 -> ?v=32.
> TUNE-B — filter funnel DROPPED below the header text. Root: th inner = `<span>text+caret</span>` then `<button>funnel</button>` in inline flow → when the header wraps to 2 lines the funnel flows AFTER the text (funnel_top≈33px), not at the top. `vertical-align:top` on the button doesn't fix (separate flow element after wrapping text). FIX: wrap the text-span + funnel-button of EACH header th in a `display:flex; align-items:flex-start` container so the funnel top-anchors next to line 1 (funnel_top≈0), text wraps beneath. Keep the filter dropdown OUTSIDE the flex (still in the th, absolute). AgentGrid + QueueGrid (DataSlot has no funnel). Keep edits 1/2 (As-Is + pre-line + overflow-wrap:normal) + RTL logical props.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix(web):`. **NO push**. Narrow claim.

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
## BINDING 2026-07-14T09:58:29Z | spec: shell | directive: tools/cc_prompt_shell_edit3_tune.md | status: open
### DIRECTIVE (spec->CC): edit-3 tune — .table-responsive offset 220->320 (pagination reachable) + app.css?v=32 + funnel top-align (flex align-items:flex-start on th inner, AgentGrid+QueueGrid). v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/wwwroot/app.css  (.table-responsive max-height offset)
- src/CcDashboard.Web/Components/App.razor  (app.css?v=31 -> ?v=32)
- src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor  (header th inner flex)
- src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor  (header th inner flex — BOTH the queue-name th and the metric-loop th)

## THE WORK
### TUNE-A — app.css `.table-responsive` (added in 73ed34b):
change `max-height: calc(100vh - 220px);` -> `max-height: calc(100vh - 320px);` (keep overflow-y:auto). App.razor: `app.css?v=31` -> `?v=32`. (Tunable; requirement = on Metrics/202 the table scrolls internally, sticky header holds, AND `.pagination-bar` is fully visible without page scroll.)
### TUNE-B — funnel top-align (AgentGridWidget.razor header th ~:74; QueueGridWidget.razor header th ~:76 queue-name + ~:103 metric loop):
For EACH header `<th ... style="@GetTheadCellStyle()">`, wrap its sort-`<span>` + filter-`<button>` in a flex container, leaving the `@if(...FilterOpen){ dropdown }` OUTSIDE the flex:
```razor
<th scope="col" class="text-start position-relative" style="@GetTheadCellStyle()">
    <div style="display: flex; align-items: flex-start; gap: 0.25rem;">
        <span style="cursor: pointer; flex: 1 1 auto; min-width: 0;" @onclick="...sort..." role="button"> @Name @* + caret *@ </span>
        <button class="btn btn-link btn-sm p-0" style="@GetFilterButtonStyle(hasFilter)" @onclick="...filter..." @onclick:stopPropagation="true" ...> <i class="bi ...funnel..."></i> </button>
    </div>
    @if (isFilterOpen) { @* dropdown — unchanged, stays direct child of th (absolute) *@ }
</th>
```
- `align-items: flex-start` anchors the funnel to the TOP (line 1) while the text wraps beneath; `span flex:1 min-width:0` lets the text wrap (pre-line + overflow-wrap:normal from edits 1/2 still apply). Keep the sort caret inside the span. Do NOT change GetTheadCellStyle / GetFilterButtonStyle logic (the button's `vertical-align:top` from before is now harmless/redundant — leave or drop). Keep `ms-1` off the button or replace with the flex `gap` (avoid double spacing). RTL: `gap`/`flex` are neutral; no physical L/R.
- Apply to ALL header th in both grids (AgentGrid metric-loop th; QueueGrid queue-name th + metric-loop th). DataSlot: no funnel, no change.

## VERIFY / DoD
- Object-store: app.css `.table-responsive` max-height calc(100vh-320px); App.razor app.css?v=32; each header th inner wrapped in `display:flex; align-items:flex-start`; dropdown still in th; edits 1/2 intact; RTL logical/neutral.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- ⛔ LIVE (coord 140 post-rebuild): (A) on Metrics/202 → internal scroll + sticky header + `.pagination-bar` fully visible (bottom <= innerHeight); (B) filter funnels top-aligned with the header's FIRST line for both 1-line and 2-line headers (funnel_top ≈ 0, not dropped below).

## COMMIT
- pre-commit-check → commit.lock → stage the 4 files → `fix(web): edit-3 tune — table offset for reachable pagination (app.css?v=32) + funnel top-align (flex align-items:flex-start) [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync. Standalone rebuild (or batch if something else pending).

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files app.css + App.razor(?v=32) + AgentGrid.razor + QueueGrid.razor . status . verified: object-store (LIVE pagination-visible + funnel-top = coord 140)
```
