# CC task — ReportViewPage: date controls INTO header + show empty-state plashka (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Operator (2026-06-25): (1) move From/To/Apply UP into the fullscreen-header (remove the separate date-bar row); (2) show the "no widgets" empty-state plashka (currently hidden). Owner: role-shell. Executor: native CC. Branch: **v3** (tip d0fb4dd). Commit `fix:`. **NO push** (§37).
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-24T23:00Z). Object-store-grounded vs d0fb4dd (header/datebar/canvas-visibility-gate confirmed). Both changes touch ONLY ReportViewPage + our report-scoped CSS + App.razor ?v; ScreenFullscreenPage/ScreenEditorPage/shared selectors/widget-resize.js untouched; empty-state fix (_positionsApplied=true @0-widgets) is local + correct; date logic unchanged (markup-move only). fix:, NO push, commit.lock, binding — all present. CLEARED TO RUN.
> Parity-guard: ZERO edits to ScreenFullscreenPage.razor / ScreenEditorPage.razor / any EXISTING SHARED app.css selector / widget-resize.js. `.report-fullscreen-datebar` / `.report-date-bar` are OUR OWN report-scoped additive classes — free to modify/remove.

## INIT — branch v3 + role-shell §A/§C + §40
- BRANCH: `git checkout v3`; verify rev-parse=v3 + `git rev-parse v3` (object-store; tip d0fb4dd — re-verify; mount L-SC-04 → no escalate). role-shell §A (DoD block) + §C-green; §40.
- POST-VERIFY reliable floor (cat + git show v3 + hash-object). §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> .coord/cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push.

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/Reports/ReportViewPage.razor (MODIFY)
- src/CcDashboard.Web/wwwroot/app.css (modify OUR report-scoped .report-fullscreen-datebar block + any additive header-date styling) ; src/CcDashboard.Web/Components/App.razor (?v bump)
- (role-shell.md via git add -f if CAPTURE)
- S1 freeze-check (FULL line). **ZERO edits to ScreenFullscreenPage.razor / ScreenEditorPage.razor / existing shared app.css selectors / widget-resize.js.**

## GROUNDING (object-store v3 d0fb4dd — ReportViewPage current shape)
- `.fullscreen-header` = `<h1 class="fullscreen-title mb-0">@_report.Name</h1>` (left) + `<div class="d-flex gap-2">` right cluster: dark toggle, Export(disabled), Schedule(disabled), close-X(`fullscreen-close`→ExitToList).
- SEPARATE `<div class="report-fullscreen-datebar">` BELOW the header holds: From `<input type=date @bind="_from">` + To `<input @bind="_to">` + Apply `@onclick="ApplyDateRange"`.
- `.fullscreen-canvas style="@(_positionsApplied ? "" : "visibility: hidden;")"`; empty-state `@if (_report.Widgets.Count == 0){ <div class="text-center py-5 text-muted"><i bi-grid-3x3-gap/><p>@L["Reports_NoWidgets"]</p></div> }` lives INSIDE the canvas. `_positionsApplied` is only set true in OnAfterRender when `Widgets.Count > 0` → for a 0-widget report the canvas stays `visibility:hidden` → empty-state INVISIBLE (the bug).

## THE WORK
### 1. Move From/To/Apply INTO `.fullscreen-header`
- DELETE the separate `<div class="report-fullscreen-datebar">…</div>` block.
- Place the date controls inside the header's RIGHT control group, BEFORE the dark/Export/Schedule/close buttons (one flex row, `align-items-center`, `gap-2`). Compact inline: `From <input type="date" class="form-control form-control-sm" style="width:auto" @bind="_from"/> To <input … @bind="_to"/> <button class="btn btn-sm btn-primary" @onclick="ApplyDateRange"><i class="bi bi-check2 me-1"></i>@L["Report_Apply"]</button>`. Keep @L labels (Report_From/Report_To/Report_Apply). Labels may be compact (small) to fit the header.
- Keep ALL date logic unchanged (_from/_to/_rangeFrom/_rangeTo/ApplyDateRange cascade to widgets). Only the MARKUP location moves.
- The header must stay on ONE row and not overflow: wrap the date group + action group so on narrow widths it degrades gracefully (flex-wrap on the right cluster, or `.fullscreen-header` already flex justify-between — keep title left, everything else right). Dark-mode: date inputs already styled by `.fullscreen-dashboard.dark-mode` — verify contrast; add report-scoped additive rule ONLY if needed (e.g. `.fullscreen-header .report-header-datebar input`). RTL logical props.
- CSS: remove/empty the now-unused `.report-fullscreen-datebar` rules (ours) OR repurpose into a `.report-header-datebar` scoped helper. Do NOT touch `.fullscreen-header` shared selector beyond reusing it.

### 2. Show the empty-state plashka (0-widget report)
- Make the empty-state visible: when `_report.Widgets.Count == 0`, set `_positionsApplied = true` (e.g. at the end of OnInitializedAsync after load, or guard the canvas visibility so the empty-state branch is never hidden). Simplest: in OnInitializedAsync after `_report` loads, `if (_report is not null && _report.Widgets.Count == 0) _positionsApplied = true;`. Result: the `.fullscreen-canvas` (and its `bi-grid-3x3-gap` + `@L["Reports_NoWidgets"]` plashka) renders for empty reports, mirroring the dashboard's intended empty-state. Do NOT change ScreenFullscreenPage.

## VERIFY / DoD (role-shell §A — MANDATORY)
- Object-store: NO `.report-fullscreen-datebar` block remains in ReportViewPage; From/To/Apply now inside `.fullscreen-header`; `_positionsApplied=true` path for 0 widgets; ApplyDateRange cascade intact; ScreenFullscreenPage/ScreenEditorPage/shared selectors/widget-resize.js UNTOUCHED (diff-proven); @L 3 locales.
- **Soma (host-Chrome): /ops/build exit 0 + serilog [ERR]/[FTL] clean + /ops/health.** (unit deferred F-QA-4.)
- **VISUAL CHROME GATE (light+dark):** open `/reports/{id}` → From/To/Apply render IN the top header bar (no separate row); empty report shows the "no widgets" plashka; overlay still covers shell. Screenshot light+dark. + live-dashboard regression (/screens/{id}/fullscreen byte-identical).

## §0.6b CAPTURE -> role-shell §B (git add -f) if a real lesson (e.g. fullscreen-canvas visibility gate hides empty-state for 0-widget screens — inherited from ScreenFullscreenPage). Commit `fix:`, NO push, commit.lock. Binding RESULT -> cc/shell.md (Soma + visual light+dark). Report: commit, files, build/serilog/health, screenshots, parity confirm.
