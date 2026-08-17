# Deploy-New-Metrics package — QueueNumberOfCompletedIncomingCalls (2026-07-13)

Package for the Shell **Deploy New Metrics** tab (hot-reload apply-service). Deploys the new metric
`QueueNumberOfCompletedIncomingCalls` to a running server WITHOUT restarting RTM.

## Contents
- `migrations/manual-deploy` — pure SQL, idempotent `INSERT` of the metric into `RTSGrid_Metric`
  (file name MUST be exactly `manual-deploy` — the Shell sends `MigrationRef="manual-deploy"`).
- `manifest.json` — declares the metric (`MetricType: RT`) + the migration file SHA-256 (F-4 integrity).

## Placement on the server (per ApplyService appsettings)
- Copy `migrations/manual-deploy`  ->  `C:\Program Files\CcDashboard\migrations\manual-deploy`
- Copy `manifest.json`             ->  `C:\Program Files\CcDashboard\manifest.json`
- Lock NTFS ACLs on the migrations dir + manifest to admin-write-only (F-4 hardening).
- SHA-256 of `manual-deploy`: `8dbeaf69c832bef45a065ede44404328e9e2d6b6c324271853562f86526ab041`

## Deploy flow (operator, in the UI)
1. Ensure the server's Shell has the UPDATED `docs/metrics-catalog.json` (with this metric) — else the
   Deploy tab will not list it. (Requires Shell redeploy with the new catalog, or catalog refresh on the server.)
2. Open Shell -> Metrics -> **Deploy New Metrics** tab (Superadmin). The metric shows as *undeployed*
   (in catalog, not yet in the `metric_deploy_log` ledger).
3. Click **Deploy** -> Shell calls apply-service -> integrity-verified migration runs -> ledger + audit written ->
   SignalR `compileMetrics` hot-compiles the RT metric. No restart.

## Known gaps to close for full UI end-to-end (flagged, not in this package)
- **Shell**: `MetricsPage.ExecuteDeploy` hard-codes `MigrationRef="manual-deploy"` / `PackageRef="shell-manual"`.
  Works with THIS single-file package, but a real multi-batch flow needs the Shell to send the actual migrationRef.
  (shell-0609)
- **Manifest generator**: no build step emits `manifest.json` (contract v1.2 §3.2). This package's manifest is
  hand-built; a generator should produce it at pack time. (build/devops)
- **Catalog on server**: the metric must be in the server's `metrics-catalog.json` for the tab to list it. (devops/Shell redeploy)
