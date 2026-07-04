# 234 Drift Reconcile Runbook

> Date: 2026-07-04  
> Context: 234 Compare shows Dim-A (24 CC tables "missing") + [A-R] (46/115 routines "absent") + Dim-C (typo metrics).  
> Root cause: STALE repo baseline, NOT reader-artifact (P2 confirmed owner=ccdashboard_user).  
> Direction: regenerate baseline FROM 234, NEVER drop/alter real 234 objects.

## Prerequisites

- 234 server access as `postgres`
- Repo checkout on 234 (or copy db/tools/* to 234)
- `C:\RTMView-Ops\backup\` writable

---

## STEP 0 — HARD FAIL-STOP BACKUP (MANDATORY before ANY change)

```powershell
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
pg_dump -Fc -h localhost -U postgres -d rtmviewdb -f "C:\RTMView-Ops\backup\rtmviewdb_pre_reconcile_$ts.dump"
```

**IF pg_dump fails OR any later step errors → STOP + restore from THIS backup → escalate; do NOT improvise:**
```powershell
pg_restore -h localhost -U postgres -d postgres --clean --create -f "C:\RTMView-Ops\backup\rtmviewdb_pre_reconcile_$ts.dump"
```

---

## STEP 1 — Regenerate baseline from 234 reality

This fixes Dim-A (tables) + [A-R] (routines) at root — the baseline becomes what 234 actually has.
Also auto-includes the typo metrics (QueueNumAbandonef*) in db/data/02_metrics.sql → Dim-C = 0.

**Dry-run first (inspect output):**
```powershell
cd "D:\Claude\Projects\RTM View Shell"   # or wherever the repo checkout is on 234
powershell -ExecutionPolicy Bypass -File db\tools\Export-All.ps1 `
  -DBHost localhost -DBPort 5432 -DBUser postgres -Password "<pg_password>" -DryRun
```

**Review the output.** Confirm it shows the expected schema/functions/data files.

**Execute (regenerate files):**
```powershell
powershell -ExecutionPolicy Bypass -File db\tools\Export-All.ps1 `
  -DBHost localhost -DBPort 5432 -DBUser postgres -Password "<pg_password>"
```

This writes to: `db/schema.sql`, `db/functions/*.sql`, `db/data/02_metrics.sql`, etc.

Mark the 234 repo directory as **234-BaselineDir** for step 4.

---

## STEP 2 — Apply the 2 genuinely-unapplied migrations

These are the ONLY migrations that Compare flagged as UNKNOWN + probe confirmed objects are ABSENT:

```powershell
psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 `
  -f db\migrations\20260604_001_add_agent_state_pct_metrics.sql

psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 `
  -f db\migrations\20260606_005_history_unavailable_metrics.sql
```

Note: `history_metrics` table exists (confirmed by probe) — the migration inserts into it.

---

## STEP 3 — Ledger-mark the 2 probe-proven-applied migrations

These are migrations whose objects are ALREADY CORRECT on 234 (probe verified), but ledger is missing:

```powershell
psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 `
  -f staging\234_ledger_mark.sql
```

Expected output:
```
         migration_name          
---------------------------------
 20260605_004_metrics_dedup
 20260606_008_daytrend_fn_bu_scope
(2 rows)
```

---

## STEP 4 — Re-Compare against the regenerated baseline

**CRITICAL:** The `-BaselineDir` MUST point at the 234-BaselineDir (from step 1), NOT the stale repo baseline.

```powershell
powershell -ExecutionPolicy Bypass -File db\tools\Compare-ToBaseline.ps1 `
  -DBHost localhost -DBPort 5432 -DBUser postgres -Password "<pg_password>" `
  -BaselineDir "D:\Claude\Projects\RTM View Shell\db"
```

**Expected result:** A = 0, [A-R] = 0, D = 0. If not zero → STOP, do NOT proceed to step 5.

---

## STEP 5 — Return regenerated files to DEV repo

Only after step 4 = clean:

1. Copy the regenerated db/ files from 234 to `staging/regen234/` in the DEV repo
2. Notify coordinator — the follow-up CC prompt will commit the baseline swap

Files to return:
- `db/schema.sql`
- `db/functions/*.sql`
- `db/data/02_metrics.sql` (and other data files if changed)

---

## Post-reconcile verification

After the follow-up commit lands and is deployed:
- Run Compare on 234 → should show 0/0/0 against the new committed baseline
- Confirm the ledger shows all migrations applied

---

## Rollback

If any step fails:
```powershell
pg_restore -h localhost -U postgres -d postgres --clean --create `
  -f "C:\RTMView-Ops\backup\rtmviewdb_pre_reconcile_$ts.dump"
```
Then escalate — do NOT retry without diagnosis.
