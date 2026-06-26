# CC task — Reports widget table chrome + pagination (shell): R3/R5/R8/R6/R4 — AWAITING §4-BLESS
> Cross-tenant View + real data now render (QueueInterval shows real rows). Operator UI-reject pack on the report-widget table (all FRONTEND):
> - **R3** vertical scroll INSIDE the widget card (content above card height scrolls within the card; card does not stretch). +horizontal scroll for wide tables.
> - **R5** column headers must be VISIBLE (the table headers are clipped/scroll away today).
> - **R8** column headers STICKY (stay pinned on vertical scroll).
> - **R6** move "Showing X of Y" out of the corner → into a card FOOTER.
> - **R4** pagination controls in the footer (prev/next + page indicator), wired to the existing `RunReportWidgetQuery.Page`; rows-per-page already exists in config General (`ReportWidgetConfig.PageSize` + modal General select — NO backend change).
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `feat:`/`fix:`. **NO push** (§37). claim=frontend (web).
> Parity-guard: report-scoped only — do NOT edit ScreenEditorPage/ScreenFullscreen/widget-resize/dashboard widgets/shared selectors. New report-scoped CSS only (additive).

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
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_widget_table_chrome.md | status: open
### DIRECTIVE (spec->CC): R3/R5/R8/R6/R4 report-widget table chrome+pagination across 5 type widgets + report CSS. fix:, NO push, §4 + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/ReportWidgets/{QueueInterval,QueueWaitTime,AgentMonthly,AgentShiftDetail,Distribution}ReportWidget.razor — MODIFY (table chrome + footer + page state)
- src/CcDashboard.Web/wwwroot/app.css — MODIFY (NEW report-scoped table-chrome rules, additive)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx — MODIFY (footer/pagination labels if new)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING (object-store v3)
- The 5 type widgets render `<div class="table-responsive"><table class="report-table report-widget-table">` with a `<thead>` of localized `<th>` + a tbody; QueueInterval also has a "Showing {Rows} of {TotalCount}" block (~:74-79). (R5 headers EXIST in markup → the fix is keeping them VISIBLE + sticky inside a scroll container, not adding from scratch — but VERIFY each of the 5 has a localized thead; add any missing.)
- The result records expose `Rows`, `TotalCount`, `Page`, `PageSize` (e.g. QueueIntervalReportResult). The widgets call `new RunReportWidgetQuery(type, configJson, From, To, Page, TenantId)` — `Page` is already a param; widgets currently pass page 1 (no nav).
- `ReportWidgetConfig.PageSize` exists; modal General has the rows-per-page select (no backend/validator change needed for R4).
- report-widget render CSS already has overflow rules (~:64/75) — adjust so the TABLE area scrolls and the thead sticks; the card itself must not stretch.

## THE WORK (apply consistently to ALL 5 type widgets + report CSS)
1. **Scroll container (R3):** ensure each widget's table sits in a vertically-scrollable area that fills the card body and does NOT stretch the card — `overflow-y:auto` (+`overflow-x:auto`) on the table-responsive/body container; the card stays fixed-height (its height comes from the widget position). Header/date area (if any) stays put.
2. **Visible + sticky headers (R5+R8):** confirm each of the 5 widgets renders a localized `<thead>` (add if missing); make the thead sticky via report-scoped CSS: `.report-widget-render table.report-widget-table thead th { position: sticky; top: 0; z-index: 1; }` + a solid header background (light + dark, reuse the dashboard/table-bg tokens so it doesn't show rows bleeding through). Verify in both light + dark.
3. **Footer (R6):** move the "Showing X of Y" text out of the inline corner into a card FOOTER row at the bottom of the widget (a small `.report-widget-footer` report-scoped bar). Keep it for all widgets that page (QueueInterval/QueueWaitTime/AgentMonthly/AgentShiftDetail; Distribution is chart/aggregate — footer optional, no pager).
4. **Pagination (R4):** in the footer, add prev/next page controls + a page indicator (e.g. "Page p / ceil(TotalCount/PageSize)"), wired to a `_page` state in the widget; on prev/next, clamp to bounds and re-run `RunReportWidgetQuery(..., Page=_page, TenantId)`; disable prev at page 1 / next at last page. PageSize comes from the result/config (already applied server-side). Reset `_page=1` when From/To/Config change. NO new config field, NO backend change.
5. Report-scoped CSS only (`.report-widget-render …`, `.report-widget-footer`, sticky thead). Do NOT touch dashboard/shared selectors. Keep dark-mode parity (footer + sticky header readable in dark).

## VERIFY / DoD (role-shell §A — ЧП: LIVE gate, NOT object-store)
- **Object-store:** all 5 widgets have a localized thead; report-scoped sticky-thead + scroll CSS added (no shared/dashboard selector touched); "Showing X of Y" in a footer; footer prev/next page controls wired to RunReportWidgetQuery.Page with a `_page` state + bounds; no new config field / backend change.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE — MANDATORY (operator/coordinator on 234, real data):** open a report with >1 page of rows → the card shows a vertical scrollbar INSIDE the card; column headers are VISIBLE and STAY pinned on scroll (light+dark); "Showing X of Y" + prev/next pager in the footer; paging re-queries and shows the next page; wide tables scroll horizontally. Do NOT report from object-store.

## R7 (separate — investigation only, NO shell build)
Export + Schedule buttons (ReportViewPage:57-61) are `disabled` by design (titles `Reports_ExportStub` / `Reports_ScheduleStub`). Enabling them needs BACKEND (CSV export per AUD-08; report schedules) — NOT shell. Do NOT enable/fake them here. (Spec reports this finding to the coordinator separately; this prompt does not touch them.)

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY the claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `feat(web): reports widget table chrome — sticky headers + in-card scroll + footer "showing X of Y" + pagination [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "Report-widget table chrome: a scroll container inside the fixed-height card + `thead th{position:sticky;top:0}` (solid bg light+dark) keeps headers visible; 'Showing X of Y' + prev/next pager live in a report-scoped footer wired to RunReportWidgetQuery.Page (_page state, bounds, reset on From/To/Config change). PageSize already in config — no backend." SOURCE:<commit> + operator R3-R8 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files 5 type widgets + app.css (+resx) . status done|failed . blockers . verified: object-store (LIVE scroll/sticky/pager = operator gate, pending)
```
