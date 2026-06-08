# CC Task — _005: add UNAVAILABLE history metrics (DATA ONLY, no fn change)

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## Git push (§37)
Do NOT run `git push`. Commit only.

## Step 0 — integrity + fetch (§0.6a + §42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git status --short
echo "HEAD=$(git rev-parse --short HEAD)  origin/v2=$(git rev-parse --short origin/v2)"
git merge-base --is-ancestor HEAD origin/v2 && echo "HEAD ancestor/equal origin/v2 (OK)" || echo "WARN HEAD ahead"
# Known false-M (do NOT restore): db/data/02_metrics.sql, db/schema.sql
```

## Multi-session sync (§42) — slug: daytrend-0606
Claim (single new file): db/migrations/20260606_005_history_unavailable_metrics.sql
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
  echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1; fi
python3 tools/coord_check_claims.py daytrend-0606 db/migrations/20260606_005_history_unavailable_metrics.sql
# exit 1 -> STOP (queue). Touch ONLY this file (+ /tmp). Edit tool BANNED (§0.3): Python+fsync writes.
```
- S3 commit lock: phantom-aware acquire (owner daytrend-0606) from tools/cc_prompt_sync_block.md.
- S4 journal + release; S4b post-commit flush to .coord/inbox/coordinator.md (per-slug /tmp script).

---

# TASK (DATA ONLY — no function changes)

## Scope (coordinator directive)
This migration adds ONLY the two UNAVAILABLE history_metric rows for EXISTING prod DBs. Do NOT touch
fn_daytrendagentstatus here — ALL fn changes (UNAVAILABLE outputs + BU-scope) land ONCE in P3.
Fresh-install/restart durability is metrics-0605's job (they add the same rows to
DatabaseInitializer.SeedHistoryMetricsAsync). This migration is the existing-DB counterpart.

## Create file: db/migrations/20260606_005_history_unavailable_metrics.sql
Idempotent, ON_ERROR_STOP-safe. Header comment (purpose + 2026-06-06), then:

```sql
-- Add UNAVAILABLE agent-status history metrics (DayTrend Agent Metrics — 6th group).
-- Mirrors the existing statuslog.* AgentStatusLog family. fn_daytrendagentstatus will EMIT
-- these ids in P3 (BU-scoped rewrite); seeded for fresh installs via DatabaseInitializer (metrics).
INSERT INTO public.history_metrics
  ("MetricId","Description","DataType","MetricFunction","MetricParameter","MetricFormat","DefaultValue","ValueType","MetricType")
VALUES
  ('statuslog.unavailable_agents',  'Unavailable Agents', 'int',    'COUNT_DISTINCT', 'group:UNAVAILABLE', '0',     '0', 'Number', 'AgentStatusLog'),
  ('statuslog.unavailable_time_ms', 'Unavailable Time',   'bigint', 'SUM_OVERLAP_MS', 'group:UNAVAILABLE', 'mm:ss', '0', 'Time',   'AgentStatusLog')
ON CONFLICT ("MetricId") DO NOTHING;
```

## Verify before commit
```bash
bash tools/pre-commit-check.sh db/migrations/20260606_005_history_unavailable_metrics.sql
grep -c "statuslog.unavailable_agents\|statuslog.unavailable_time_ms" db/migrations/20260606_005_history_unavailable_metrics.sql  # 2
grep -c "fn_daytrendagentstatus\|CREATE.*FUNCTION\|CREATE.*PROCEDURE" db/migrations/20260606_005_history_unavailable_metrics.sql  # 0 (data only)
```

## Commit (under commit.lock, prefix db:)
```
db: add UNAVAILABLE history metrics (statuslog.unavailable_*) for existing DBs
```
Then §0.6 post-commit verify + PD-007 re-sync of the file, S4 journal/release, S4b flush.

## Deploy on prod (after commit; operator sets PGPASSWORD) — can run as ccdashboard_user (DML, no DDL)
```powershell
$env:PGPASSWORD = "<password>"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -f "db\migrations\20260606_005_history_unavailable_metrics.sql"
Remove-Item Env:\PGPASSWORD
```
NOTE: these two metrics will APPEAR in the DayTrend Agent Metrics tab immediately but stay EMPTY until
the P3 fn rewrite emits statuslog.unavailable_* — expected per the agreed sequencing.
