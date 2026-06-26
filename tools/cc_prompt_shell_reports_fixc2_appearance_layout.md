# CC task — Reports editor FIX-C2 (shell): Appearance COLORS layout garbled (double-nested grid) — NOT identical to dashboard — AWAITING §4-BLESS
> Live visual gate (operator screenshot) = ⛔RED: the report config-modal **Appearance → COLORS** section is garbled — labels overlap the swatches ("Text olor" sits on top of a swatch), the LIGHT MODE / DARK MODE headers are misaligned, Widget/Table Background crammed onto one visual row. NOT identical to the dashboard Appearance tab (the parity requirement, fork-(a)).
> ROOT CAUSE (object-store): a **double-nested grid**. FIX-C wrapped the whole colours block in an outer `<div class="rw-color-grid">` which is itself a 3-column grid (`grid-template-columns:140px 1fr 1fr`, app.css:3511), and then placed each `<div class="color-setting-row-dual">` INSIDE it — but `.color-setting-row-dual` is ALSO a 3-column grid (app.css:2117). So each row is a SINGLE child of the outer grid, squeezed into its first 140px column, and its label+light+dark collapse/overlap → exactly the screenshot.
> The WORKING dashboard (ScreenEditorPage.razor ~:744-810) uses NO outer wrapper: a single `<div class="color-dual-header">` (3-col grid, app.css:2101) for the blank/LIGHT/DARK header, then each `<div class="color-setting-row-dual">` as a DIRECT SIBLING (independent 3-col grid). They align because both share `140px 1fr 1fr`.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> Parity-guard: REUSE the dashboard's EXISTING global classes (`.color-dual-header`, `.color-mode-label`, `.color-setting-row-dual`) — do NOT edit them, do NOT edit ScreenEditorPage/ScreenFullscreen/widget-resize/shared selectors. Report-scoped only.

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
- Compile via docs/Visual-Test-Preflight.md Profile A.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_fixc2_appearance_layout.md | status: open
### DIRECTIVE (spec->CC): FIX-C2 fix Appearance COLORS double-grid — drop .rw-color-grid wrapper, use dashboard .color-dual-header. Claims: ReportWidgetConfigModal.razor, app.css. fix:, NO push, §4 + LIVE visual gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor — **MODIFY** (Appearance COLORS markup)
- src/CcDashboard.Web/wwwroot/app.css — **MODIFY** (remove the dead report-scoped `.rw-color-grid` / `.rw-color-header` rules)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — **READ-ONLY reference** (:744-810 the correct structure)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## THE WORK
### ReportWidgetConfigModal.razor — Appearance COLORS section (~:194-345)
1. REMOVE the outer wrapper `<div class="rw-color-grid"> ... </div>` (the div opened at ~:196 and its matching close after the last `.color-setting-row-dual`). The `.color-setting-row-dual` rows must become DIRECT children of `.appearance-section` (siblings), exactly like the dashboard.
2. REPLACE the 3 `<div class="rw-color-header">…</div>` cells (blank / LIGHT MODE / DARK MODE) with the dashboard's header markup:
```razor
<div class="color-dual-header">
    <span class="color-setting-label"></span>
    <span class="color-mode-label">@L["WidgetCfg_LightMode"]</span>
    <span class="color-mode-label">@L["WidgetCfg_DarkMode"]</span>
</div>
```
3. KEEP the three `.color-setting-row-dual` rows (Widget Background / Text Color / Table Background) exactly as they are — label + light `.position-relative` swatch cell + dark `.position-relative` swatch cell. They already match `.color-dual-header`'s `140px 1fr 1fr` columns and will align once the outer wrapper is gone.
4. Do NOT change the Typography section, the swatch/palette markup, GetColorStyle/GetColorName/ToggleColorPalette, or the bound fields.

### app.css — remove the dead report-scoped rules (cleanup so the double-grid can't recur)
5. REMOVE the report-scoped `.report-config-modal .rw-color-grid` block (~:3511) and the `.rw-color-header` / `.dark-mode .report-config-modal .rw-color-header` rules (~:3518, :3565) that FIX-C added — they're now unused (verify `rw-color-grid`/`rw-color-header` no longer referenced in any .razor after step 1-2). Leave all OTHER FIX-C report-scoped rules (the `--rw-*` render vars etc.) intact. Touch NO shared/dashboard selector.

## VERIFY / DoD (role-shell §A — ЧП: the gate is LIVE VISUAL, NOT object-store)
- **Object-store (necessary, NOT sufficient):** ReportWidgetConfigModal no longer references `rw-color-grid`/`rw-color-header`; uses `.color-dual-header` + `.color-mode-label`; the 3 `.color-setting-row-dual` rows are direct siblings; app.css `.rw-color-grid`/`.rw-color-header` rules removed; `.color-dual-header`/`.color-mode-label`/`.color-setting-row-dual`/ScreenEditorPage/shared UNTOUCHED.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE VISUAL GATE — MANDATORY (operator/coordinator, real screen):** open the report widget config → Appearance tab → the COLORS section is **visually IDENTICAL to the dashboard Appearance tab**: a label column + aligned LIGHT MODE / DARK MODE columns; Widget Background, Text Color, Table Background each on their OWN row; labels NOT overlapping swatches; swatches render the palette; light AND dark. Compare side-by-side with the dashboard widget-config Appearance. Do NOT report fixed from object-store — the previous FIX-C passed token/brace checks yet rendered garbled; only the live side-by-side visual seals it.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY ReportWidgetConfigModal.razor + app.css (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports — Appearance COLORS dashboard-identical layout (drop double-nested rw-color-grid, use color-dual-header) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (MANDATORY): "Visual parity is NOT proven by object-store: FIX-C had all the Appearance fields/braces present but a double-nested grid (.rw-color-grid wrapping .color-setting-row-dual, both 3-col) collapsed the layout. When the brief says 'identical to <existing component>', mirror its EXACT container structure/classes — do NOT invent a new wrapper grid; and a layout claim is only done after a LIVE side-by-side visual." SOURCE:<commit> + operator screenshot 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportWidgetConfigModal.razor + app.css . status done|failed . blockers . verified: object-store (LIVE visual = operator gate, pending)
```
