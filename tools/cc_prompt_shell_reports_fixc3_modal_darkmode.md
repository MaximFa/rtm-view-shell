# CC task — Reports editor FIX-C3 (shell): dark mode does NOT apply to the report widget config modal — AWAITING §4-BLESS
> Live visual gate (operator): toggling dark mode has NO effect on the report widget **config modal** — it stays light while the rest of the editor is dark.
> ROOT CAUSE (object-store):
> 1. `ReportWidgetConfigModal.razor` has **no DarkMode parameter**; its root `<div class="modal show d-block report-config-modal" …>` (line ~13) has **no dark-mode class**.
> 2. `ReportEditorPage.razor` renders `<ReportWidgetConfigModal … />` (~:196-201) WITHOUT passing dark state, and the modal sits OUTSIDE the editor's `.editor-fullscreen.dark-mode` wrapper.
> 3. All 9 modal dark rules in app.css are **ancestor-based** (`.dark-mode .report-config-modal …`, lines ~3512-3547) → they require a `.dark-mode` ANCESTOR, which the modal does not have → none match → modal never goes dark.
> The WORKING dashboard modal (ScreenEditorPage.razor:254) puts the class **on the modal element itself**: `<div class="editor-modal @(_darkMode ? "dark-mode" : "")" …>` → its dark rules are SELF-class (`.editor-modal.dark-mode …`) and match regardless of DOM position.
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> Parity-guard: report-scoped only — ZERO edits to ScreenEditorPage/ScreenFullscreen/widget-resize/shared selectors (the `.report-config-modal …` rules are report-specific, editing them is in-scope).

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
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_fixc3_modal_darkmode.md | status: open
### DIRECTIVE (spec->CC): FIX-C3 wire DarkMode into report config modal (self-class) + convert 9 ancestor dark rules to self-class. Claims: ReportWidgetConfigModal.razor, ReportEditorPage.razor, app.css. fix:, NO push, §4 + LIVE visual gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor — MODIFY (DarkMode param + root class)
- src/CcDashboard.Web/Components/Reports/ReportEditorPage.razor — MODIFY (pass DarkMode to the modal)
- src/CcDashboard.Web/wwwroot/app.css — MODIFY (9 modal dark selectors → self-class)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — READ-ONLY reference (:254 self-class pattern)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## THE WORK
1. `ReportWidgetConfigModal.razor`:
   - Add `[Parameter] public bool DarkMode { get; set; }` (in @code with the other params).
   - On the modal root `<div class="modal show d-block report-config-modal …">` add the dark class: `class="modal show d-block report-config-modal @(DarkMode ? "dark-mode" : "")"`. (Keep the existing inline style/z-index.)
2. `ReportEditorPage.razor` (~:196-201): pass the editor's dark state to the modal — add `DarkMode="_darkMode"` to the `<ReportWidgetConfigModal … />` attributes.
3. `app.css`: convert the 9 modal dark selectors from ancestor to SELF-class so they match the modal-as-own-dark-root (lines ~3512-3547):
   - `.dark-mode .report-config-modal .modal-content`   → `.report-config-modal.dark-mode .modal-content`
   - `.dark-mode .report-config-modal .modal-header`    → `.report-config-modal.dark-mode .modal-header`
   - `.dark-mode .report-config-modal .modal-footer`    → `.report-config-modal.dark-mode .modal-footer`
   - `.dark-mode .report-config-modal .nav-tabs .nav-link`        → `.report-config-modal.dark-mode .nav-tabs .nav-link`
   - `.dark-mode .report-config-modal .nav-tabs .nav-link.active` → `.report-config-modal.dark-mode .nav-tabs .nav-link.active`
   - `.dark-mode .report-config-modal .form-select, .dark-mode .report-config-modal .form-control` → `.report-config-modal.dark-mode .form-select, .report-config-modal.dark-mode .form-control`
   - `.dark-mode .report-config-modal .section-label`        → `.report-config-modal.dark-mode .section-label`
   - `.dark-mode .report-config-modal .color-setting-label`  → `.report-config-modal.dark-mode .color-setting-label`
   (Convert ALL 9 occurrences; leave the rule BODIES unchanged. Do NOT touch any non-`report-config-modal` selector.)
4. Coverage check (add report-scoped dark rules ONLY if a visible element in the modal is still light in dark mode — keep additive, self-class): the `.color-mode-label` LIGHT/DARK headers and the COLORS swatch borders should read correctly on the dark modal-content; if they're hard to see, add `.report-config-modal.dark-mode .color-mode-label { color:#94a3b8; }` (mirror the dashboard). Only add what the live check shows is needed — do not over-add.

## VERIFY / DoD (role-shell §A — ЧП: the gate is LIVE VISUAL, NOT object-store)
- **Object-store (necessary, NOT sufficient):** ReportWidgetConfigModal has `[Parameter] public bool DarkMode` + root class includes `@(DarkMode ? "dark-mode" : "")`; ReportEditorPage passes `DarkMode="_darkMode"`; app.css has 0 `.dark-mode .report-config-modal` ancestor selectors and 9 `.report-config-modal.dark-mode` self-class selectors; dashboard/shared untouched.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE VISUAL GATE — MANDATORY (operator/coordinator):** editor in DARK mode → open a report widget config → the WHOLE modal is dark (content, header, footer, tabs, inputs, Appearance section, labels) — consistent with the dashboard widget-config modal in dark mode; toggle back to light → modal is light. Side-by-side with the dashboard modal. Do NOT report fixed from object-store — only the live dark render seals it.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY the 3 claimed files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports — apply dark mode to widget config modal (DarkMode param + self-class dark rules) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (MANDATORY): "A modal/overlay rendered OUTSIDE the page's .dark-mode wrapper must carry the dark class ON ITSELF (self-class via a DarkMode param), like the dashboard's `.editor-modal @(_darkMode?…)`. Ancestor-based `.dark-mode .X` dark rules silently never match for fixed/overlay elements outside the wrapper. Pass DarkMode into every overlay component + use self-class selectors." SOURCE:<commit> + operator 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files ReportWidgetConfigModal.razor + ReportEditorPage.razor + app.css . status done|failed . blockers . verified: object-store (LIVE dark visual = operator gate, pending)
```
