# CC task — Reports editor FIX-C (shell): Appearance full table-parity (config + render) + Thresholds honest v1.1 note — AWAITING §4-BLESS
> Operator end-to-end NO-GO (2026-06-25), two scope-forks RULED by operator:
> - **G-APPEAR** → FORK-APPEAR = (a): the report config-modal Appearance tab must reach FULL table-applicable parity with the DASHBOARD widget-config Appearance tab, in v1 — AND the settings must actually be APPLIED when the widget renders (today the report type widgets apply NOTHING).
> - **G-THRESH** → FORK-THRESH = (b): Thresholds defer to v1.1 (coupled to the Columns picker, also v1.1). The Thresholds tab must show an HONEST "v1.1" note (parity with the Columns tab's honest note) — NOT an empty/stub tab, NOT a full editor.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> Parity-guard: REUSE the dashboard Appearance markup/behaviour as the reference but REPORT-SCOPED — ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / widget-resize.js / existing shared app.css selectors. New report-scoped selectors only (additive).

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
- §0.3 Python+fsync for ALL writes; **Edit tool BANNED**; after every write `sync`+`tail -3`+`wc -l`.
- Compile via docs/Visual-Test-Preflight.md Profile A (one build-class Soma op at a time).

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_fixc_appearance_thresh.md | status: open
### DIRECTIVE (spec->CC): FIX-C Appearance full table-parity (config+render) + Thresholds honest v1.1 note. Claims: ReportWidgetConfigModal.razor, ReportWidgetConfig.cs, RenderReportWidget.razor, app.css(additive), 3 resx. fix:, NO push, §4-PASS gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — **READ-ONLY reference** (Appearance tab ~:506-1224; @code fields :2296-2297 ConfigFontSize/ConfigHeaderFontSize, palette builders :2778-2781, tenant load :2965-2987 — do NOT edit)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor — MODIFY (Appearance tab → parity; Thresholds tab → honest note)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfig.cs — MODIFY (AppearanceConfig: +2 table-bg fields)
- src/CcDashboard.Web/Components/ReportWidgets/RenderReportWidget.razor — MODIFY (apply appearance via CSS vars on the wrapper)
- src/CcDashboard.Web/wwwroot/app.css — MODIFY (NEW report-scoped selectors only, additive)
- src/CcDashboard.Web/Resources/SharedResources.{en-US,ru-RU,he-IL}.resx — MODIFY (Thresholds honest note + any new Appearance labels)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING (object-store v3)
**Dashboard Appearance fields (reference, ScreenEditorPage):** font sizes from `_tenantFontSizes` (ConfigFontSize/ConfigHeaderFontSize, :544-556); background swatches light+dark from `BackgroundColors` (:756-792); text colour light+dark from `FontColors` (:802-961 area); table-background light+dark from `TableBackgroundColors` (:1029-1065). Tenant palettes loaded via `GetTenantSettingsQuery(TenantId)` → `.BackgroundColorPalette` / `.FontColorPalette` / `.FontSizes` with `GetDefault*` fallbacks (:2965-2987). Swatch picker pattern: a current-swatch (GetColorStyle/GetColorName) + ToggleColorPalette(key) + a popover foreach over the palette rendering `clr-swatch` with `selected` class + onclick SelectX.
**Report model today (ReportWidgetConfig.cs):** `AppearanceConfig` ALREADY has TableFontSize, HeaderFontSize, LightBackground, LightTextColor, DarkBackground, DarkTextColor. **MISSING: light + dark table-background.**
**Report config modal today (ReportWidgetConfigModal.razor):** Appearance tab (:163-199) = reduced (dark bg + dark text via raw `<input type=color>`, hardcoded small/normal/large font sizes); Thresholds tab (:157-162) = `@L["ReportWidget_ThresholdsHint"]` info alert; Columns tab (:151-156) = `@L["ReportWidget_ColumnsHint"]` honest note (the model for the Thresholds note).
**Report render today:** `RenderReportWidget.razor` wraps the 5 type widgets in `<div class="report-widget-render">` (:6). The 5 type widgets (QueueInterval/QueueWaitTime/AgentMonthly/AgentShiftDetail/Distribution) render plain `<table class="report-table report-widget-table">` and apply NO appearance.

## FIELD PARITY MAP (dashboard → report) — implement EXACTLY this set; EXCLUDE grid-only
| Dashboard field | Report AppearanceConfig field | Source |
|---|---|---|
| ConfigFontSize | TableFontSize | `_tenantFontSizes` (tenant palette) |
| ConfigHeaderFontSize | HeaderFontSize | `_tenantFontSizes` |
| ConfigBackgroundColor (light) | LightBackground | `BackgroundColors` swatch palette |
| ConfigDarkBackgroundColor | DarkBackground | `BackgroundColors` |
| ConfigTextColor (light) | LightTextColor | `FontColors` swatch palette |
| ConfigDarkTextColor | DarkTextColor | `FontColors` |
| ConfigTableBackgroundColor (light) | **LightTableBackground (ADD)** | `TableBackgroundColors` |
| ConfigDarkTableBackgroundColor | **DarkTableBackground (ADD)** | `TableBackgroundColors` |
| ConfigPriorityHigh*/avatar* | — EXCLUDED | grid-only (priority cells / avatars) — N/A to report tables; CONFIRM grid-specific by object-store before omitting |

## THE WORK
### C1 — model
1. `ReportWidgetConfig.cs` / `AppearanceConfig`: add `LightTableBackground` (json `lightTableBackground`) + `DarkTableBackground` (json `darkTableBackground`). No other model changes.

### C2 — config-modal Appearance tab (parity)
2. `ReportWidgetConfigModal.razor` Appearance tab: replace the reduced markup with dashboard-parity fields, REPORT-SCOPED (reuse the dashboard's swatch-picker structure/behaviour as the reference — same look, report-scoped selectors):
   - Font sizes: table + header, sourced from the **tenant palette** (load `_tenantFontSizes` via `GetTenantSettingsQuery(TenantId)` like the dashboard; TenantId from `ICurrentUserAccessor` or pass from the editor). Fallback to `GetDefaultFontSizes()` equivalent on failure (independent try/catch, Logger.LogError — never bare-catch, role-shell §B).
   - Background colour: LIGHT + DARK, from the tenant `BackgroundColorPalette` swatches.
   - Text colour: LIGHT + DARK, from the tenant `FontColorPalette` swatches.
   - Table background: LIGHT + DARK, from the tenant table-background palette.
   - Bind each to the corresponding `_appearance*` field; persist into `AppearanceConfig` on Save (round-trip: Save→reopen→intact is DoD).
   - EXCLUDE priority-cell + avatar colours (grid-only).
3. Reuse/load the SAME tenant palette source as the dashboard (GetTenantSettingsQuery). Do NOT invent a separate palette.

### C-render — apply appearance when the widget renders (REQUIRED — fork ruling (a))
4. `RenderReportWidget.razor`: on the wrapper `<div class="report-widget-render">`, emit inline CSS custom properties from the parsed `_config.Appearance`, choosing light vs dark by `DarkMode`:
   `style="--rw-bg:{bg}; --rw-text:{text}; --rw-table-bg:{tableBg}; --rw-table-font:{tableFontPx}; --rw-header-font:{headerFontPx};"` (omit a var if its value is null/empty so defaults apply).
   Map font-size tokens → px the same way the dashboard does (reuse its size→px mapping).
5. `app.css` (NEW report-scoped selectors only — additive, never edit shared):
   ```
   .report-widget-render { background: var(--rw-bg, transparent); color: var(--rw-text, inherit); }
   .report-widget-render table.report-widget-table { font-size: var(--rw-table-font, inherit); }
   .report-widget-render table.report-widget-table thead { font-size: var(--rw-header-font, inherit); background: var(--rw-table-bg, inherit); }
   ```
   (Adjust selectors to the actual rendered table classes; keep ALL new, report-scoped. This applies appearance to ALL 5 type widgets WITHOUT editing them — they render inside `.report-widget-render`.)
   Verify the var names/fallbacks don't collide with any existing selector.

### C-thresh — honest v1.1 note
6. `ReportWidgetConfigModal.razor` Thresholds tab: keep it a clear, HONEST v1.1 note (parity with the Columns tab's note) — e.g. reuse the Columns-note style. Update `ReportWidget_ThresholdsHint` in all 3 resx to an explicit "Per-column thresholds — available in v1.1 (together with the full Columns picker)." (en/ru/he, capitalised). NOT empty, NOT a fake editor.

## VERIFY / DoD (role-shell §A — ЧП: every visual detail critically RED; build-green NOT sufficient)
- **Object-store:** AppearanceConfig has +LightTableBackground+DarkTableBackground; Appearance tab exposes font(table+header from tenant palette) + bg(light+dark) + text(light+dark) + table-bg(light+dark) swatches, NO priority/avatar; RenderReportWidget emits the --rw-* vars from Appearance+DarkMode; app.css additions are NEW report-scoped selectors (no shared-selector edits); Thresholds tab shows the honest v1.1 note in 3 resx; ScreenEditorPage/ScreenFullscreen/widget-resize UNTOUCHED.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **VISUAL CHROME GATE (light + dark) — MANDATORY:** report config modal → Appearance tab is **visually identical to the dashboard Appearance tab** (same fields, swatch pickers, tenant fonts) in light AND dark; set bg/text/table-bg/fonts → Save → reopen → values intact (round-trip); the configured widget RENDERS with those colours/fonts applied (light AND dark). Thresholds tab shows the honest v1.1 note (no empty/red). Screenshots both modes. (authed render = operator/QA login floor.)
- **Regression:** dashboard widget-config Appearance unchanged; an existing report widget with no Appearance still renders default.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY the claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports — Appearance tab dashboard-parity (config + render-applied) + Thresholds honest v1.1 note [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "Report-widget Appearance is applied without touching the 5 type widgets: RenderReportWidget wrapper emits --rw-* CSS vars from config.Appearance×DarkMode, consumed by report-scoped .report-widget-render selectors. Reuse the dashboard tenant palette (GetTenantSettingsQuery) — never a separate palette." SOURCE:<commit>. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportWidgetConfigModal/ReportWidgetConfig/RenderReportWidget/app.css +3 resx . status done|failed . blockers . verified: object-store
```
