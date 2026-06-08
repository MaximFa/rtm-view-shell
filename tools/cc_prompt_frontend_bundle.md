# CC Task — Frontend bundle: configurator i18n (L2) + dark-mode parity + MetricWizard charcoal unification

> ONE ScreenEditorPage pass combining three coordinator-approved parts (operator: Max, 2026-06-07):
> 1. L2 — localize the widget configurator modal UI strings + metric button -> localized DisplayName.
> 2. Dark-mode parity — configurator modal + per-widget config sections render in the app's charcoal dark theme.
> 3. MetricWizard — drop the off-theme slate palette; unify to the charcoal theme via tokens.
>
> ROOT-CAUSE (analysed by Cowork, mockup-approved by Max):
> The app has TWO dark systems: (a) tokens.css swaps `--clr-*` to charcoal ONLY under
> `@media (prefers-color-scheme: dark)` (OS-driven); (b) the dashboard/editor dark theme is an EXPLICIT
> class toggle `.dark-mode` (`Dashboard.IsDarkMode` + button) passed to children as `DarkMode` -> `.dark`.
> Because the explicit class does NOT trigger the @media block, app.css hardcoded charcoal hex with
> `.dark-mode ... !important`, and MetricWizard.razor.css invented `--clr-*-dark` tokens that DO NOT EXIST
> in tokens.css -> it falls back to slate (#1e293b/#334155/#3b82f6), visibly off-theme vs the View page.
> DECISION (Max): add a CLASS-SCOPED dark token block to tokens.css so `var(--clr-*)` resolve to charcoal
> whenever `.dark-mode`/`.dark` is present (independent of OS), then point the wizard + configurator modal
> at plain tokens. Single source of truth; light mode and the OS path untouched.

## Mandatory — read before starting (do NOT skip; §40)
Read file: .claude/skills/session-coord/session-coord.md      (phantom-aware S3, S4b flush wrapper, S1 hard-stop)
Read file: .claude/skills/ux-ui-expert/SKILL.md               (WHAT: dark-mode visual consistency, contrast/a11y, alignment)
Read file: .claude/skills/frontend-design/SKILL.md            (HOW: frontend-design, RTL/he-IL, CSS logical properties)
Read file: .claude/skills/blazor-frontend-design/SKILL.md     (HOW: Blazor @L localization, design tokens, .editor-modal pattern, a11y)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (§5: metric DisplayName vs Description)
Only after reading ALL of the above: proceed.

## Git push: NONE (§37). Commit only. Push happens later via tools/cc_prompt_push.md after the barrier.

---

## Step 0a — §0.6a integrity check (MANDATORY first step)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES wt=$WT_LINES)"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    fi
done
sync; echo "=== integrity check complete ==="
```
Known false-M (hash==HEAD; verify with `git hash-object` vs `git rev-parse HEAD:<f>` before restoring): `db/data/02_metrics.sql`, `db/schema.sql`.
Also: `git fetch origin v2` and verify local HEAD is an ancestor of / equal to origin/v2 (§42.7.6).

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS
Session slug: `test-5-0607`
Claims for this task (file-mode):
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor   (EXCLUSIVE — release right after commit)
- src/CcDashboard.Web/Components/Shared/MetricWizard.razor
- src/CcDashboard.Web/Components/Shared/MetricWizard.razor.css
- src/CcDashboard.Web/Resources/SharedResources.en-US.resx
- src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
- src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
- src/CcDashboard.Web/wwwroot/app.css
- src/CcDashboard.Web/wwwroot/css/tokens.css
- tools/cc_prompt_frontend_bundle.md (this file)

### S1. Push barrier check — before ANY work
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."; exit 1
fi
```

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py test-5-0607 \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  src/CcDashboard.Web/Components/Shared/MetricWizard.razor \
  src/CcDashboard.Web/Components/Shared/MetricWizard.razor.css \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx \
  src/CcDashboard.Web/Resources/SharedResources.he-IL.resx \
  src/CcDashboard.Web/wwwroot/app.css \
  src/CcDashboard.Web/wwwroot/css/tokens.css
# exit 1 -> STOP (conflict -> queue, skill §9). Do not improvise.
```
Modify ONLY files inside the claims above (plus throwaway /tmp scripts named /tmp/test-5-0607_*).
metrics-2-0607 holds MetricsPage.razor + lint_metrics.py + cc_prompt_l2_configurator_i18n.md —
do NOT edit them. You may READ cc_prompt_l2_configurator_i18n.md as the L2 base, nothing more.
All file writes use Python + os.fsync (§0.3); Edit tool is BANNED.

---

## Deliverable 1 — Localize the widget configurator modal (L2)
Source modal = the `ConfiguringWidget` / `.editor-modal` block in ScreenEditorPage.razor (~lines 246-2050).
BASE = tools/cc_prompt_l2_configurator_i18n.md (read it; §4-approved). Apply its full L2 spec:
- Audit the WHOLE modal; wrap EVERY hardcoded user-visible English string in `@L["..."]`.
  Known offenders (NON-exhaustive — do a full pass): tab labels (General, Appearance, Thresholds, Rows,
  Columns, Call Metrics, Agent Metrics); section/column headers (Name, Metric, Column, Colors, Typography,
  Display Options, Score, Filters); labels (Business Unit, Queue Name, Grid ID, Header Text, Text Color,
  Widget Background, Table Background, Light Mode, Dark Mode, Light, Dark); operator text ("No matches",
  "No Business Units available", "AND", "OR", "Select metric..." -> reuse Common_SelectMetric); the
  `Modal: @ConfiguringWidget.Name` debug badge (line ~65) and `Widgets_Configure` are already keyed —
  leave keyed ones.
- Reuse an existing SharedResources key if present (search the .resx FIRST). New keys: `WidgetCfg_<Label>`.
- Do NOT localize metric DATA (DisplayName/Description from DB), MetricId, raw status/state names,
  "QM"/"Agent Group" platform prefixes.
- Add EVERY new key to ALL THREE resx (en-US source; ru-RU + he-IL translated, CC English-in-parentheses
  convention; he is RTL) with EXACT matching names, ADDITIVELY (confirm hash==HEAD/false-M before editing).

## Deliverable 2 — Metric button shows localized DisplayName (not raw Description)
The Queue/Agent/DataSlot metric buttons + col.Name default use GetMetricDescription(col.MetricId) (raw English).
`Metrics` is `List<RtsGridMetricDto>` from the localized GetRtsGridMetricsQuery (DisplayName already localized).
- Add helper: `GetMetricDisplayName(id) => Metrics.FirstOrDefault(m=>m.MetricId==id)?.DisplayName ?? GetMetricDescription(id)`
  (fallback DisplayName -> Description -> id).
- Use it for the 3 metric buttons (DataSlot ~391, Agent ~1606, Queue ~1995) and the col.Name default on selection.
- Keep GetMetricDescription for other genuine callers; do not break them.

## Deliverable 3 — Class-scoped dark TOKENS in tokens.css (the core fix; Max-approved)
In src/CcDashboard.Web/wwwroot/css/tokens.css, the dark values currently live ONLY in
`@media (prefers-color-scheme: dark) { :root { ... } }` (lines ~202-249).
Add a SECOND, class-scoped block with the SAME dark token values, scoped to the explicit dark toggles so
`var(--clr-*)` resolve to charcoal whenever the class is present regardless of OS:
```css
/* Explicit dark toggle (dashboard/editor class) — mirrors the @media dark block */
.dark-mode,
.editor-fullscreen.dark-mode,
.fullscreen-dashboard.dark-mode,
.metric-wizard-overlay.dark {
    --clr-bg: #121212; --clr-surface: #1E1E1E; --clr-overlay: #2D2D2D;
    --clr-text: #E4E4E7; --clr-text-secondary: #A1A1AA; --clr-text-muted: #71717A;
    --clr-text-faint: #52525B; --clr-text-disabled: #3F3F46;
    --clr-border: rgba(255,255,255,0.08); --clr-border-md: rgba(255,255,255,0.12);
    --clr-border-solid: #3F3F46; --clr-border-strong: #52525B;
    --clr-primary-subtle: #1A3A5C; --clr-danger-subtle: #3D1F1F; --clr-success-subtle: #1A3D2A;
    --clr-warning-subtle: #3D3010; --clr-info-subtle: #1A3D5C;
    /* (include the same role/status badge + focus-ring + shadow dark values as the @media block) */
}
```
REQUIREMENTS:
- Values MUST be byte-identical to the existing @media dark block (single source — copy them, do not invent).
  To avoid two drifting copies, define the dark values ONCE (e.g. via a shared selector list that includes
  BOTH `@media :root` and the classes) IF clean; otherwise duplicate but add a comment linking the two so a
  future edit updates both. Keep whichever is simpler to review — but the two MUST stay in sync.
- Scope to the explicit-dark classes ONLY. Do NOT put these on bare `:root` (that would force dark globally).
- Light mode (no class, OS light) MUST be byte-for-byte unchanged.

## Deliverable 4 — MetricWizard: charcoal via tokens (drop slate)
In src/CcDashboard.Web/Components/Shared/MetricWizard.razor.css, replace the non-existent `--clr-*-dark`
token refs + slate hardcodes with the real tokens (now charcoal under `.dark` thanks to D3):
- `var(--clr-surface-dark, #1e293b)`        -> `var(--clr-surface)`
- `var(--clr-text-dark, #f1f5f9)`           -> `var(--clr-text)`
- `var(--clr-border-dark, #334155)`         -> `var(--clr-border)`
- `var(--clr-primary-subtle-dark, #1e3a8a)` and `(..., #334155)` -> `var(--clr-primary-subtle)`
- `var(--clr-surface-alt-dark, #0f172a)`    -> `var(--clr-overlay)`  (raised charcoal #2D2D2D)
- `var(--clr-primary, #3b82f6)` (blue-500 fallback) -> `var(--clr-primary, #0066CC)` (correct brand fallback)
- selected-item border-inline-start uses `var(--clr-primary)` (= #0066CC).
- Status dots: keep green #22c55e / amber #f59e0b (semantic, consistent with app.css info-slot star #f59e0b).
- The base (light) `.metric-wizard-*` rules already use `var(--clr-surface)` etc.; keep them. The point is the
  `.metric-wizard-overlay.dark` overrides now reference tokens that are charcoal under D3.
- AUDIT the whole file for any remaining hardcoded slate hex (#1e293b/#334155/#0f172a/#1e3a8a/#3b82f6/#475569/
  #64748b/#94a3b8/#cbd5e1/#e2e8f0/#f1f5f9/#f8fafc) and replace each with the matching token.

## Deliverable 5 — Configurator modal dark parity (verify + fix)
- The `.editor-modal` block (ScreenEditorPage.razor ~line 248) appears to be rendered OUTSIDE the
  `.editor-fullscreen.dark-mode` wrapper (line 29). VERIFY this. If true, the app.css selectors
  `.editor-fullscreen.dark-mode .editor-modal ...` (lines ~2851-2880) never match -> the modal renders light.
  FIX (pick the lower-risk option, justify in the report):
  (a) Add the dark class to the modal wrapper itself, e.g. `<div class="editor-modal @(_darkMode ? "dark-mode" : "")">`,
      and adjust the app.css selectors to also match `.editor-modal.dark-mode ...`; OR
  (b) Move/wrap the modal inside the `.editor-fullscreen.dark-mode` scope.
  Prefer (a) — minimal structural change. Because D3 scopes tokens to `.dark-mode`, once the modal carries the
  class, its inner surfaces/inputs/labels pick up charcoal tokens automatically.
- Per-widget config sections (thresholds, colors, typography, display options, rows/columns tables) inside the
  modal: ensure each uses the dark tokens / existing `.editor-modal` dark rules and has NO hardcoded light
  background/border/text that survives in dark. Replace any hardcoded light hex with `var(--clr-*)`.
- Do NOT break light mode: every change must be a token swap or a `.dark`-scoped addition.

## Deliverable 6 — RTL (he-IL)
Confirm the modal + wizard render correctly RTL under he-IL (app sets `dir` on <html> per culture, §29.1).
Any config-modal/wizard element hardcoding left/right -> switch to CSS logical properties (margin-inline-*,
padding-inline-*, inset-inline-*, border-inline-*). Do not restyle beyond RTL correctness + the dark-token work.

---

## Verification — MANDATORY before commit
1. L-34 localization completeness:
```bash
grep -hPo '(?<=@L\[")[^"]+' src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | sort -u > /tmp/fb_razor.txt
for loc in en-US ru-RU he-IL; do
  grep -Po '(?<=<data name=")[^"]+' src/CcDashboard.Web/Resources/SharedResources.$loc.resx | sort -u > /tmp/fb_$loc.txt
  echo "== missing in $loc =="; comm -23 /tmp/fb_razor.txt /tmp/fb_$loc.txt   # MUST be empty for all three
done
```
2. No leftover slate in the wizard:
```bash
grep -nE '#1e293b|#334155|#0f172a|#1e3a8a|#3b82f6|#475569|#64748b|#94a3b8|#cbd5e1|#e2e8f0|#f1f5f9|#f8fafc|-dark,' \
  src/CcDashboard.Web/Components/Shared/MetricWizard.razor.css   # MUST be empty
```
3. tokens.css light unchanged: `git diff` shows ONLY ADDED lines (the class-scoped block); the `:root` light
   block and the `@media` block are untouched (or refactored to a shared selector with identical values).
4. Build: stop dotnet (§28) -> `dotnet build CcDashboard.sln` -> clean (0 errors).
5. Manual / Chrome live verify (report with findings):
   - Open a dashboard, toggle dark mode (button) while the OS is in LIGHT mode (this is the case that was
     broken). Configurator modal = charcoal (#1E1E1E surface, #2D2D2D inputs, #E4E4E7 text, #0066CC primary,
     #1A3A5C selection). MetricWizard = same charcoal, NO slate.
   - Switch UI culture ru-RU then he-IL: modal chrome fully localized; metric button shows localized DisplayName;
     he-IL renders RTL without broken layout.
   - Light mode (dark toggle off): visually unchanged from before.

## Commit (single web: commit — one ScreenEditorPage pass)
Message: `web: configurator i18n (L2) + dark-mode parity + MetricWizard charcoal unification (class-scoped tokens)`
Files: ScreenEditorPage.razor, SharedResources.{en-US,ru-RU,he-IL}.resx, tokens.css, app.css,
MetricWizard.razor(.css).
Procedure (sync block S3/S4):
- acquire commit.lock (phantom-aware, retry 5x60s) -> `bash tools/pre-commit-check.sh` -> `git add` (claimed
  files only; new keys are in-file, no new files expected) -> `git commit` -> §0.6 post-commit verification.
- LAST step: `bash tools/cc_post_commit.sh test-5-0607 $(git log -1 --format=%h)` (journal + S4b flush + lock
  release; if non-zero, reconcile journal vs git log and re-run) -> `sync` -> PD-007 re-sync of committed files.
- RELEASE ScreenEditorPage.razor + all other claims immediately after commit (note in the S4b flush).
- NO git push.

## Acceptance criteria
1. dotnet build clean; L-34 comm -23 empty for all THREE resx; no leftover slate hex in MetricWizard.razor.css.
2. Configurator modal chrome fully localized (ru/he); en-US unchanged; metric button = localized DisplayName.
3. Dark toggle (OS in light) -> configurator modal AND MetricWizard render charcoal, matching the View page; no slate.
4. Light mode visually unchanged; tokens.css light/`@media` blocks unchanged (only an additive class-scoped block).
5. he-IL RTL correct.
6. One web: commit; ScreenEditorPage released after commit; tree clean (ignore known false-M); journal + S4b via
   cc_post_commit.sh; lock released; no push.
