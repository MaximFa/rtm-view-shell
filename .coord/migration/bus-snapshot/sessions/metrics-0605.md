---
session: RTM Metrics
slug: metrics-0605
started: 2026-06-05T12:30:00Z
heartbeat: 2026-06-06T23:56:07Z
status: done
modules: []
files:
  - src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
  - src/CcDashboard.Web/Resources/SharedResources.en-US.resx
  - src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
  - src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
  - src/CcDashboard.Web/Components/Shared/MetricWizard.razor
  - src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor
  - tools/lint_metrics.py
  - tools/cc_prompt_l2_configurator_i18n.md
cc_task: none
---
Stage 2 — Metrics Catalog, DESIGN DECIDED 2026-06-06: catalogue model = JSON source of truth
(docs/metrics-catalog.json) + linter coverage gate; metrics are repo-driven (migration→linter→
Export-All→commit→RTM restart); the Metrics admin page becomes READ-ONLY (no runtime CRUD —
RTM engine only reads metrics at startup anyway, LoadData/Engine.cs:145, so runtime edits were
never live for the engine). NO new catalogue columns on RtsGridMetric (entity untouched).
Active deliverables:
  (c) lint_metrics.py — add JSON<->catalogue coverage gate.
  (b) tools/cc_prompt_metric_change.md — reproducible add/edit/delete-metric procedure template.
  (a) MetricsPage.razor → read-only catalogue viewer (card from metrics-catalog.json + DB fallback);
      OPEN design point: how the running app reads metrics-catalog.json (embedded resource vs wwwroot+cache).
Stage-1 done & pushed (catalogue 198, linter+quarantine: 5a4324a/c5ced4e/c28e098/2410b5b).
db/migrations/20260606_001 = CurLoginTimeStamp data-fix via normal migration (no DDL).
superseded by metrics-2-0607 (takeover 2026-06-07); claims migrated.
