# CC task — Reports editor FIX-C4 (shell): report config modal dark COLORS must match the dashboard EXACTLY — AWAITING §4-BLESS
> Live (operator): with FIX-C3 the report config modal now goes dark, but the COLORS are wrong — it uses a slate/navy palette, not the dashboard's neutral grays. Operator: "take exactly as in dashboards."
> ROOT CAUSE (object-store): the report modal's `.report-config-modal.dark-mode` rules (app.css ~:3512-3548) use SLATE values (#1e293b / #334155 / #94a3b8 / #e2e8f0 / #f1f5f9 / rgba(255,255,255,0.1)), while the dashboard modal `.editor-modal.dark-mode` (app.css ~:2911-3070) uses NEUTRAL GRAYS (#1E1E1E / #2D2D2D / #3D3D3D / #A1A1AA / #E4E4E7 / rgba(255,255,255,0.08) & 0.15). They diverge. The report modal also LACKS several dark rules the dashboard has (form-label, control:focus, nav-link hover, form-check/switch, placeholder, readonly, color-mode-label).
> Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> Parity-guard: edit ONLY `.report-config-modal.dark-mode …` rules in app.css (report-scoped). Do NOT edit the dashboard `.editor-modal` rules / ScreenEditorPage / shared selectors. Copy the dashboard's VALUES into report-scoped rules (do NOT add `.report-config-modal` as a co-selector onto dashboard rules).

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
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_reports_fixc4_modal_dark_palette.md | status: open
### DIRECTIVE (spec->CC): FIX-C4 report modal dark colors = dashboard exact palette. Claim: app.css (.report-config-modal.dark-mode only). fix:, NO push, §4 + LIVE side-by-side gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/wwwroot/app.css — MODIFY (`.report-config-modal.dark-mode` rules ONLY)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — n/a
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## GROUNDING — dashboard EXACT dark values (object-store, app.css ~:2911-3070) to copy
Reference rule bodies (copy these VALUES verbatim):
- modal-content: `background-color:#1E1E1E; border-color:rgba(255,255,255,0.08); color:#E4E4E7;`
- modal-header / modal-footer: `border-color:rgba(255,255,255,0.08);`
- form-label: `color:#E4E4E7;`
- form-control / form-select: `background-color:#2D2D2D; border-color:rgba(255,255,255,0.15); color:#E4E4E7;`
- form-control:focus / form-select:focus: `background-color:#3D3D3D; border-color:var(--clr-primary);`
- generic inputs/select/textarea (non checkbox/radio/color/range): same as form-control; `:focus` same; `input[readonly]{color:#B4B4B8;}`; `::placeholder{color:rgba(228,228,231,0.5);}`
- nav-tabs .nav-link: `color:#A1A1AA; background-color:transparent; border-color:transparent;`
- nav-tabs .nav-link:hover: `color:#E4E4E7; border-color:rgba(255,255,255,0.15);`
- nav-tabs .nav-link.active: `background-color:#2D2D2D; color:#E4E4E7; border-color:rgba(255,255,255,0.15); border-bottom-color:#2D2D2D;`
- form-check-input[type=checkbox]:not(:checked): `background-color:#3D3D3D; border-color:rgba(255,255,255,0.2);`
- form-check-input[type=checkbox]:checked: `background-color:var(--clr-primary); border-color:var(--clr-primary);`
- form-check-input:focus: `border-color:var(--clr-primary); box-shadow:0 0 0 0.2rem rgba(0,102,204,0.25);`

## THE WORK (app.css — `.report-config-modal.dark-mode` rules ONLY)
1. REPLACE the VALUES of the existing report dark rules (~:3512-3548) with the dashboard's exact values above:
   - `.report-config-modal.dark-mode .modal-content` → `background-color:#1E1E1E; color:#E4E4E7; border-color:rgba(255,255,255,0.08);`
   - `.report-config-modal.dark-mode .modal-header` / `.modal-footer` → `border-color:rgba(255,255,255,0.08);`
   - `.report-config-modal.dark-mode .nav-tabs .nav-link` → `color:#A1A1AA; background-color:transparent; border-color:transparent;`
   - `.report-config-modal.dark-mode .nav-tabs .nav-link.active` → `background-color:#2D2D2D; color:#E4E4E7; border-color:rgba(255,255,255,0.15); border-bottom-color:#2D2D2D;`
   - `.report-config-modal.dark-mode .form-select, .report-config-modal.dark-mode .form-control` → `background-color:#2D2D2D; border-color:rgba(255,255,255,0.15); color:#E4E4E7;`
   - `.report-config-modal.dark-mode .section-label` → `color:#A1A1AA;`
   - `.report-config-modal.dark-mode .color-setting-label` → `color:#E4E4E7;`
2. ADD the missing report-scoped dark rules (dashboard parity), all `.report-config-modal.dark-mode …`:
   - `.form-label { color:#E4E4E7; }`
   - `.nav-tabs .nav-link:hover { color:#E4E4E7; border-color:rgba(255,255,255,0.15); }`
   - `.form-control:focus, .form-select:focus { background-color:#3D3D3D; border-color:var(--clr-primary); }`
   - generic inputs: `input:not([type=checkbox]):not([type=radio]):not([type=color]):not([type=range]), select, textarea { background-color:#2D2D2D; border-color:rgba(255,255,255,0.15); color:#E4E4E7; }` + matching `:focus { background-color:#3D3D3D; border-color:var(--clr-primary); }` + `input[readonly]{color:#B4B4B8;}` + `input::placeholder, textarea::placeholder { color:rgba(228,228,231,0.5); }`
   - `.form-check-input[type=checkbox]:not(:checked) { background-color:#3D3D3D; border-color:rgba(255,255,255,0.2); }`
   - `.form-check-input[type=checkbox]:checked { background-color:var(--clr-primary); border-color:var(--clr-primary); }`
   - `.form-check-input:focus { border-color:var(--clr-primary); box-shadow:0 0 0 0.2rem rgba(0,102,204,0.25); }`
   - `.color-mode-label { color:#A1A1AA; }`  (LIGHT MODE / DARK MODE headers in the Appearance COLORS section)
3. Do NOT touch ReportWidgetConfigModal.razor markup (FIX-C3 already wired DarkMode). Do NOT touch the dashboard `.editor-modal` rules. Keep all edits inside `.report-config-modal.dark-mode`.

## VERIFY / DoD (role-shell §A — ЧП: the gate is LIVE side-by-side, NOT object-store)
- **Object-store:** every `.report-config-modal.dark-mode` colour now uses the dashboard neutral-gray values (#1E1E1E/#2D2D2D/#3D3D3D/#A1A1AA/#E4E4E7/rgba .08/.15/.2); zero slate values (#1e293b/#334155/#94a3b8/#e2e8f0/#f1f5f9) remain in `.report-config-modal.dark-mode`; the added rules present; dashboard `.editor-modal` rules UNTOUCHED; no shared-selector edits.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE VISUAL GATE — MANDATORY (operator/coordinator):** open the report widget config in DARK mode next to the dashboard widget config in DARK mode — modal background, header/footer, tabs (active+inactive+hover), inputs/selects, checkboxes, labels, Appearance LIGHT/DARK headers must be the SAME shades as the dashboard. Side-by-side identical. Do NOT report from object-store — only the live side-by-side seals it.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0.
- commit.lock acquire (retry 5×60s); stage ONLY app.css (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): reports — config modal dark colors match dashboard exactly (neutral-gray palette) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 post-commit verify. **NO push** (§37). §0.7 re-sync committed files from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed live): "Dark-mode parity is the exact COLOUR VALUES, not just 'is dark': the report modal applied dark but used a slate palette vs the dashboard's neutral grays. When the brief says 'exactly as <component>', copy the reference's exact dark values (and all its dark element rules) into the report-scoped selectors; verify zero divergent values remain + live side-by-side." SOURCE:<commit> + operator 2026-06-26. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err>/unit <n/0> . files app.css . status done|failed . blockers . verified: object-store (LIVE side-by-side = operator gate, pending)
```
