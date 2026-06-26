# CC task — Ф5b-2 FIX (HIGH): wire the FULL ReportWidgetConfigModal into the report editor (role-shell) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Found in E visual walkthrough (2026-06-25): a widget placed in the report editor immediately errors "Invalid ConfigJson: ReportWidgetConfig was missing required properties including: 'Scope', 'Columns'." The editor's per-widget config modal is a Title-ONLY stub → it cannot set the REQUIRED ConfigJson fields → placed widgets can NEVER be made valid via UI. The core editor feature is non-functional. Owner: role-shell. Executor: native CC. Branch: **v3** (tip 1aa65d1). Commit `fix:`. **NO push** (§37).
> Parity-guard: ZERO edits to ScreenEditorPage.razor / ScreenFullscreenPage.razor / existing shared app.css selectors / widget-resize.js.

## INIT — branch v3 + role-shell §A/§C + §40 + integrity. §0.3 Python+fsync, Edit BANNED. Binding PRE+POST -> cc/shell.md. commit.lock 5x60s. cc_post_commit.sh. §0.6/PD-007. NO push. Compile via /shell/start|restart (+ /ops/test safe).

## §42.6 CLAIM (file-mode, web):
- src/CcDashboard.Web/Components/Reports/ReportEditorPage.razor (MODIFY — replace the inline config modal with the Ф4 component)
- src/CcDashboard.Web/Components/ReportWidgets/ReportWidgetConfigModal.razor (MODIFY ONLY IF it needs a WidgetType param — see step 2; additive param, do not break Ф4 callers — RenderReportWidget/ScreeneditorParity unaffected)
- 3x Resources/SharedResources.{en-US,ru-RU,he-IL}.resx (only if new strings)
- (role-shell.md via git add -f if CAPTURE)

## GROUNDING (object-store v3)
- Ф4 `Components/ReportWidgets/ReportWidgetConfigModal.razor` params: `[Parameter] bool IsOpen`, `EventCallback OnClose`, `EventCallback<ReportWidgetConfig> OnSave`, `ReportWidgetConfig? InitialConfig`. Its body already renders the full ConfigJson §2 fields (Scope BU/Queues, Columns, Metric, Interval, Thresholds, Appearance, Chart — 16 field-refs).
- Editor current (ReportEditorPage.razor): inline `@if (ConfiguringWidget is not null){ .editor-modal ... Title-only ... }` (~L194-230) + `OpenWidgetConfig` (~L400) sets ConfigTitle only + `SaveWidgetConfig` (~L413) rebuilds ReportWidgetConfig preserving existing Scope/Columns but UI never edits them. Toolbar gear `OpenWidgetConfig(widget)` (~L154). `ReportWidgetConfig.Parse(json)` / `.ToJson()` exist.
- Validation (server, RunReportWidgetQuery): ConfigJson REQUIRES Scope + Columns (FluentValidation) — a Title-only config fails.

## THE WORK
1. **Replace the inline Title-only modal** (the whole `@if (ConfiguringWidget is not null){ <div class="editor-modal">…</div> <div class="editor-modal-backdrop"></div> }` block) with the Ф4 component:
   `<ReportWidgetConfigModal IsOpen="ConfiguringWidget is not null" InitialConfig="_configInitial" OnSave="OnWidgetConfigSaved" OnClose="CloseWidgetConfig" />`
   (add `@using CcDashboard.Web.Components.ReportWidgets` if needed).
2. **WidgetType awareness:** the modal must render type-appropriate required fields (Scope+Columns always; Interval for QueueInterval; agentAxis for Agent*; Chart for Distribution). CHECK whether ReportWidgetConfigModal accepts a `WidgetType` parameter; if NOT, ADD `[Parameter] public ReportWidgetType WidgetType { get; set; }` to it (additive — default = first enum; existing callers unaffected) and use it to gate per-type fields. Pass `WidgetType="ConfiguringWidget.WidgetType"` from the editor. (If the modal is already type-aware via InitialConfig, skip the param — confirm by reading it.)
3. **Wire the callbacks in ReportEditorPage @code:**
   - `OpenWidgetConfig(widget)`: `ConfiguringWidget = widget; _configInitial = ReportWidgetConfig.Parse(widget.ConfigJson) ?? new ReportWidgetConfig();` (so a fresh widget opens with an empty editable config).
   - `OnWidgetConfigSaved(ReportWidgetConfig cfg)`: `ConfiguringWidget.ConfigJson = cfg.ToJson(); ConfiguringWidget.DisplayName = string.IsNullOrWhiteSpace(cfg.Title) ? GetWidgetName(ConfiguringWidget.WidgetType) : cfg.Title; CloseWidgetConfig();` (mark dirty if the editor tracks unsaved changes).
   - `CloseWidgetConfig()`: `ConfiguringWidget = null; _configInitial = null;`
   - Remove the now-unused `ConfigTitle` / `ConfigSaving` inline state (or keep if the modal still needs them — prefer remove).
4. **UX (recommended, optional but valuable):** auto-open the config modal immediately after a widget is dropped on the canvas, so the user sets Scope+Columns before it renders the "missing Scope/Columns" error. If low-risk, include; else leave the gear as the entry and the widget shows its (existing graceful) "configure me"/error state until configured.
5. Dark/light parity; @L for any new strings; never bare catch (Logger.LogError).

## VERIFY / DoD (role-shell §A)
- Object-store: ReportEditorPage renders `<ReportWidgetConfigModal>` (not the Title-only inline body); OpenWidgetConfig sets InitialConfig; OnSave writes full ConfigJson; ConfigTitle-only stub removed; ScreenEditorPage/ScreenFullscreenPage/shared/widget-resize UNTOUCHED; @L locales.
- **Soma: /ops/build 0 + /ops/test?suite=unit 0-failed + serilog [ERR]/[FTL] clean + /ops/health.**
- **VISUAL CHROME (light+dark):** open a report editor → drag a widget → open its config (gear) → the FULL modal shows Scope (BU/Queues) + Columns (+ type fields) → set Scope+Columns → Save → the widget NO LONGER shows "missing Scope/Columns" (renders data or a valid empty state). + live-dashboard editor regression (ScreenEditorPage byte-identical).

## §0.6b CAPTURE -> role-shell §B: "report editor shipped a Title-only config stub → placed widgets failed server ConfigJson validation (Scope/Columns required) → core editor non-functional; wire the full Ф4 ReportWidgetConfigModal, never a stub for a server-validated config." Commit fix:, NO push, commit.lock. Binding RESULT -> cc/shell.md (Soma + visual evidence: configured widget no longer errors).
