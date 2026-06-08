# CC Task: dark-mode coverage gap — configurator modal + MetricWizard input/select/textarea fields

> Operator (server45 deploy, screenshots): in dark mode the configurator modal WRAPPER is dark, but many
> input/select fields render WHITE — General (Widget ID/Grid ID/Widget Name), Day Trend Call/Agent Metrics rows,
> partially Rows; while Queue Grid -> Columns fields ARE dark. Inconsistent => a MISSED selector in the dark-mode
> commit (536415b), NOT a cache issue. Fix generically. CSS/styles ONLY — no logic. Post-release fast-follow.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md  (phantom-aware S3, S4b wrapper, S1 hard-stop)
Read file: .claude/skills/anthropic-skills/frontend-design/SKILL.md  (Blazor styling, dark tokens, RTL — if path differs, the frontend-design skill)
Only after reading all: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP (deploy mini-barrier may be active).

## Claims (file-mode, metrics-2-0607)
- web: src/CcDashboard.Web/wwwroot/app.css                         (configurator modal dark rules)
- web: src/CcDashboard.Web/Components/App.razor                    (bump app.css?v)
- web: src/CcDashboard.Web/Components/Shared/MetricWizard.razor.css (wizard input dark rules)
> coord_check_claims on all 3 FIRST (S2). All currently FREE (test-5 released ScreenEditorPage/MetricWizard/app.css).
> Touch ONLY CSS + the version string. Do NOT touch ScreenEditorPage.razor logic / MetricWizard.razor markup.

## Step 0 — §0.6a integrity + git fetch (§42.7.6) + coord sync block (slug + claims).

## Diagnosis (confirmed, app.css ~2850-2873)
The existing dark rules cover ONLY `.form-control` / `.form-select` AND only via the ANCESTOR selector
`.editor-fullscreen.dark-mode .editor-modal ...`. Gaps:
 - inputs/selects/textarea WITHOUT `.form-control` (or where the ancestor chain doesn't resolve) stay white;
 - the modal ALSO carries its OWN class `editor-modal dark-mode` (ScreenEditorPage.razor:248) which the current
   rules do NOT key on.
First REPRODUCE in dark mode (open a widget configurator, check General/Rows/Call+Agent Metrics tabs) and confirm
the exact white elements before/after.

## Deliverable 1 — generic dark coverage for ALL config-modal form fields (app.css)
Add (near the existing block ~2868) a GENERIC rule covering text-like inputs, selects, textareas under BOTH
dark selector forms (ancestor AND the modal's own class), reusing the EXISTING dark palette values for consistency
(modal content #1E1E1E, field bg #2D2D2D, text #E4E4E7, border rgba(255,255,255,0.15), focus #3D3D3D + var(--clr-primary)):

```css
/* Dark mode — generic config-modal field coverage (fixes white inputs missed by the .form-control-only rule) */
.editor-fullscreen.dark-mode .editor-modal input:not([type=checkbox]):not([type=radio]):not([type=color]):not([type=range]),
.editor-fullscreen.dark-mode .editor-modal select,
.editor-fullscreen.dark-mode .editor-modal textarea,
.editor-modal.dark-mode input:not([type=checkbox]):not([type=radio]):not([type=color]):not([type=range]),
.editor-modal.dark-mode select,
.editor-modal.dark-mode textarea {
    background-color: #2D2D2D;
    border-color: rgba(255, 255, 255, 0.15);
    color: #E4E4E7;
}
.editor-fullscreen.dark-mode .editor-modal input:focus,
.editor-fullscreen.dark-mode .editor-modal select:focus,
.editor-fullscreen.dark-mode .editor-modal textarea:focus,
.editor-modal.dark-mode input:focus,
.editor-modal.dark-mode select:focus,
.editor-modal.dark-mode textarea:focus {
    background-color: #3D3D3D;
    border-color: var(--clr-primary);
}
/* readonly fields (e.g. Grid ID) — keep dark, slightly muted */
.editor-fullscreen.dark-mode .editor-modal input[readonly],
.editor-modal.dark-mode input[readonly] { color: #B4B4B8; }
::placeholder colour under dark: ensure legible (e.g. rgba(228,228,231,0.5)) if currently too dark.
```
EXCLUSIONS are mandatory: do NOT restyle checkbox/radio/color/range inputs (color swatches, toggles, palettes must
keep their look). Verify the colour-palette swatches + checkboxes/toggles still render correctly after the change.
Cover ALL tabs of ALL configurators (Queue Grid, Agent Grid, Day Trend: General / Rows / Columns / Call Metrics /
Agent Metrics) and DataSlot — the generic selector should reach them all; spot-check each tab.

## Deliverable 2 — MetricWizard inputs (MetricWizard.razor.css)
The wizard (`.metric-wizard-overlay.dark`) has dark rules for dialog/header/list/item/detail but NOT for its
input fields (search box etc.). Add:
```css
.metric-wizard-overlay.dark input,
.metric-wizard-overlay.dark select,
.metric-wizard-overlay.dark textarea {
    background-color: #2D2D2D; border-color: rgba(255,255,255,0.15); color: #E4E4E7;
}
.metric-wizard-overlay.dark input:focus { background-color:#3D3D3D; border-color: var(--clr-primary); }
```
(match the palette; exclude checkbox/radio if any.)

## Deliverable 3 — cache bust (§29.1)
App.razor: bump `app.css?v=14` -> `app.css?v=15`.

## Verify
- `dotnet build CcDashboard.sln` clean (CSS-only + version string; should not affect build but confirm).
- Manual (report): dark mode ON — open each configurator (Queue/Agent/DayTrend) and every tab; ALL input/select/
  textarea dark with light text; checkboxes/color-swatches/toggles UNCHANGED; readonly Grid ID dark; placeholders
  legible. Light mode UNCHANGED. MetricWizard search box dark. (test-5 will Chrome-verify dark + RTL he-IL.)

## Commit
`web: dark-mode coverage for all configurator + MetricWizard input fields (generic selector) + app.css?v bump`
(app.css + MetricWizard.razor.css + App.razor)
S3 lock -> pre-commit-check -> git add (claimed only) -> commit -> §0.6 verify ->
`bash tools/cc_post_commit.sh metrics-2-0607 $(git log -1 --format=%h)` -> sync. No push.

## Acceptance criteria
1. Generic dark rule covers input/select/textarea in BOTH `.editor-fullscreen.dark-mode .editor-modal` and
   `.editor-modal.dark-mode`, all configurator tabs; checkbox/radio/color/range EXCLUDED and visually unchanged.
2. MetricWizard dark inputs covered.
3. app.css?v bumped (14->15).
4. dotnet build clean; light mode unchanged; CSS-only (no .razor logic/markup touched).
5. One web: commit; tree clean (ignore false-M); journal + S4b via wrapper; lock released; no push.
