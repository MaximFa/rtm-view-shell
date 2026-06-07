# CC Task — P3 DEV HARNESS: validate BU-scoped fn_daytrendagentstatus (NO COMMIT)

Session: daytrend-2-0607
Purpose: validate the corrected P3 membership CTE (BU-scope AND/OR + UNAVAILABLE) on DEV,
BEFORE issuing the P3 prompt that touches prod. This task makes **NO repo writes and NO commit** —
the harness is transactional and ROLLS BACK; the only artefacts are throwaway /tmp files.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF lines)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else
        echo "OK: $f ($WT_LINES lines)"
    fi
done
sync; echo "=== Integrity check complete ==="
```
Note: db/data/02_metrics.sql and db/schema.sql are known false-M (hash==HEAD) — verify with
`git hash-object` vs `git rev-parse HEAD:<f>` before "restoring"; do NOT touch the
docs/RTMViewShell_SecurityOverview.docx working-tree (binary, intentionally M).

## Multi-session sync — MANDATORY
Session slug: `daytrend-2-0607`
Claims for this task: **none** (read/validate only; harness rolls back; no repo writes).

### S1. Push barrier check — before ANY work
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."; exit 1
fi
```
S2–S5 (claims/lock/commit/push): **N/A** — this task commits nothing. Do NOT git add / commit / push.
Throwaway scripts only under /tmp, named `/tmp/daytrend-2-0607_*` (L-SC-16).

## Task

### A. Pre-flight — ensure DEV schema prerequisites exist
DEV DB: `rtmviewdb` on localhost:5432. DDL as **postgres**; checks as postgres are fine.
The harness needs (1) table `NGC_UserAgentgroup` (P1, migration _007) and (2) column
`RTSData_UserStatusLog.StatusGroup` (migration _004). Both are committed. Apply only if missing:

```bash
cd "D:\Claude\Projects\RTM View Shell"
PGHOST=localhost; export PGPASSWORD=<postgres-password-from-operator>

# (1) StatusGroup column (_004)
HAS_SG=$(psql -U postgres -d rtmviewdb -tAc "SELECT 1 FROM information_schema.columns WHERE table_name='RTSData_UserStatusLog' AND column_name='StatusGroup';")
if [ "$HAS_SG" != "1" ]; then
  echo "Applying _004 (StatusGroup column) ..."
  psql -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f db/migrations/20260606_004_userstatuslog_statusgroup.sql
else echo "OK: RTSData_UserStatusLog.StatusGroup exists"; fi

# (2) NGC_UserAgentgroup table (_007)
HAS_UAG=$(psql -U postgres -d rtmviewdb -tAc "SELECT to_regclass('public.\"NGC_UserAgentgroup\"') IS NOT NULL;")
if [ "$HAS_UAG" != "t" ]; then
  echo "Applying _007 (NGC_UserAgentgroup table+SPs) ..."
  psql -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f db/migrations/20260606_007_ngc_useragentgroup.sql
else echo "OK: NGC_UserAgentgroup table exists"; fi
```
Report exactly which (if any) migration was applied.

### B. Run the existing harness (transactional, self-rolling-back)
```bash
psql -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f staging/verify_p3_daytrend_fn.sql 2>&1 | tee /tmp/daytrend-2-0607_harness_out.txt
```
Capture the full output. Confirm the final line `ROLLBACK done — dev untouched`.

### C. Per-interval assertion (decisive leak check)
The summed view can hide a per-interval leak. Create a throwaway copy of the harness with the
final SELECT replaced by a per-interval breakdown, run it, and assert:

```bash
cd "D:\Claude\Projects\RTM View Shell"
# Build /tmp copy: same fixtures+fn, but tail emits per-interval rows for the decisive metrics.
python3 - <<'PY'
import io
src = open(r"staging/verify_p3_daytrend_fn.sql", encoding="utf-8").read()
# cut everything from the "-- 2. call fn" section onward and replace the call+echos
marker = "-- 2. call fn for BU 990001"
head = src.split(marker)[0]
tail = """-- 2b. PER-INTERVAL decisive check
\\echo ''
\\echo '=== per-interval counts (decisive) ==='
SELECT interval_start, metric_id, value
FROM fn_daytrendagentstatus(:'tid'::uuid, to_char(current_date,'DD/MM/YYYY'), 990001, 30)
WHERE metric_id IN ('statuslog.total_agents','statuslog.available_agents',
                    'statuslog.onphone_agents','statuslog.unavailable_agents')
ORDER BY 1,2;

\\echo ''
\\echo '=== ASSERTIONS ==='
SELECT
  bool_and(total_le_2)          AS pass_no_leak_total_le_2,
  bool_or(unavail_ge_1)         AS pass_unavailable_present,
  bool_or(onphone_ge_1)         AS pass_onphone_present,
  bool_or(avail_ge_1)           AS pass_available_present
FROM (
  SELECT interval_start,
    max(value) FILTER (WHERE metric_id='statuslog.total_agents')       <= 2 AS total_le_2,
    coalesce(max(value) FILTER (WHERE metric_id='statuslog.unavailable_agents'),0) >= 1 AS unavail_ge_1,
    coalesce(max(value) FILTER (WHERE metric_id='statuslog.onphone_agents'),0)     >= 1 AS onphone_ge_1,
    coalesce(max(value) FILTER (WHERE metric_id='statuslog.available_agents'),0)   >= 1 AS avail_ge_1
  FROM fn_daytrendagentstatus(:'tid'::uuid, to_char(current_date,'DD/MM/YYYY'), 990001, 30)
  GROUP BY interval_start
) x;
ROLLBACK;
\\echo 'ROLLBACK done.'
"""
open(r"/tmp/daytrend-2-0607_p3_perinterval.sql","w",encoding="utf-8").write(head+tail)
print("wrote /tmp/daytrend-2-0607_p3_perinterval.sql")
PY
psql -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f /tmp/daytrend-2-0607_p3_perinterval.sql 2>&1 | tee /tmp/daytrend-2-0607_assert_out.txt
```

### D. Evaluate & report (NO commit)
PASS criteria (all four must be `t`):
- `pass_no_leak_total_le_2 = t`  → agentPartial (AND-fail) and agentOutside excluded; never 3 agents.
- `pass_unavailable_present = t`  → agentAND UNAVAILABLE surfaces (UNAVAILABLE output works).
- `pass_onphone_present = t`      → agentB (OR membership via SG-B) is scoped in.
- `pass_available_present = t`    → agentAND AVAILABLE surfaces.

Report to the operator in the CC final message:
1. Which prerequisite migrations were applied (if any).
2. The four assertion booleans (PASS/FAIL each) + the per-interval table.
3. Overall verdict: HARNESS PASS (P3 logic validated on dev → safe to issue P3) or
   HARNESS FAIL (paste the offending rows; do NOT issue P3).
4. Confirm `ROLLBACK done` (dev untouched).

Do NOT git add/commit/push. Do NOT modify any repo file. End.
