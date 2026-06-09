# Dark-Mode Configurator Gaps — operator harvest 2026-06-09

> Input spec for the configurator dark-mode parity pass. Collected by operator (Max),
> one screenshot per gap, in the widget Configure modal (route /screens/{id}/edit).
> ALL gaps live in ONE file: `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`
> (per investigation: every widget Configure modal is rendered there, ~lines 246-2108).
> Dark CSS lives in `src/CcDashboard.Web/wwwroot/app.css` under selector prefix
> `.editor-fullscreen.dark-mode .editor-modal ...` (existing block ~lines 2850-2913).
> Toggle mechanism: `.dark-mode` class on `.editor-fullscreen` / `.editor-modal` wrapper.
> Cache-bust: bump `app.css?v=15` in App.razor.

## The 9 gaps

| # | Widget | Tab | Symptom (dark mode) | Likely selector to add/fix |
|---|--------|-----|---------------------|----------------------------|
| 1 | Agent Grid | General (any) | ACTIVE/selected nav-tab has white background | `.nav-tabs .nav-link.active` (dark bg + light text) |
| 2 | Agent Grid | Columns | table HEADER row ("NAME / METRIC") white | `thead`/`.bg-light`/header-row class |
| 3 | Agent Grid | Score | rule-row container BORDERS white + "Preview" card white bg | rule-card border + `.preview`/score-preview card bg |
| 4 | Queue Grid | Rows | row container BORDERS white (Business Unit, Queue Name) | row-card border |
| 5 | Queue Grid | Columns | row container BORDERS white (Name, Metric) | col-card border |
| 6 | ASD (Agent State Distribution) | (segment colors) | Status Group / Agent State LABELS invisible (dark text on dark) | segment/legend label text color -> light |
| 7 | Data Slot | Appearance | toggle SWITCHES white (Show Target Label / Show Delta Arrow / Hide Header) | `.form-check-input` (switch) dark track/knob — currently EXCLUDED by the `:not([type=checkbox])` generic rule |
| 8 | Day Trend | Call Metrics | metric-row input/container BORDERS white | metric-row card border |
| 9 | Day Trend | Agent Metrics | metric-row input/container BORDERS white | same as #8 |

## Notes for implementer
- Plain `.form-control`/`.form-select`/input/select/textarea borders are ALREADY covered
  (app.css ~2869-2901). The white "обводы" the operator sees are CONTAINER/CARD borders
  (rule-row / row-card / metric-row / preview), NOT the inputs — find those container classes.
- Gap 7 is a real exclusion: switches are `:not([type=checkbox])`-excluded on purpose; add an
  explicit dark rule for the switch track/knob.
- Verify each fix against the operator screenshots; rebuild + bump cache version; no hardcoded
  colors outside the dark block — reuse existing tokens (#1E1E1E bg, #2D2D2D field, #E4E4E7 text,
  rgba(255,255,255,0.08/0.15) borders).
- Skills for the pass: frontend-design / blazor-frontend-design (HOW), ux-ui-expert (WHAT).
