# CC Task: Add 4 missing RTSGrid_Metric rows — migration file + dev INSERT + db/data update

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push` automatically. Commit only.

---

## Context

Four metrics are missing from `RTSGrid_Metric`:
1. `QueueNumAbandonedCalls` — fixes broken Calc ref in `QueuePctAbandonedCallsTotal`
2. `QueueNumAbandonedCallbacks` — fixes broken Calc ref in `QueuePctAbandonedCallbacksTotal`
3. `QueueNumOutboundCalls` — needed for DayTrend outbound_calls alignment
4. `QueueNumTransferredCalls` — needed for DayTrend transferred_calls alignment

---

## Step 1 — Integrity check (§0.2)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
```
For every `M` file: `tail -3 <path>`. Restore if truncated: `git show HEAD:<path> > <path>`

---

## Step 2 — Create migration file

Create file `db/migrations/20260605_001_add_missing_metrics.sql` using Python + fsync.

Pattern: copy from `db/migrations/20260604_001_add_agent_state_pct_metrics.sql`.

Content:

```sql
-- Migration: 20260605_001_add_missing_metrics
-- Adds QueueNumAbandonedCalls, QueueNumAbandonedCallbacks, QueueNumOutboundCalls,
-- QueueNumTransferredCalls to RTSGrid_Metric.
-- QueueNumAbandonedCalls/Callbacks fix broken [MetricId] refs in Calc metrics.
-- Idempotent: ON CONFLICT DO NOTHING.

INSERT INTO "RTSGrid_Metric"
    ("MetricId", "Description", "DataType", "MetricFunction", "MetricParameter",
     "MetricFormat", "DefaultValue", "ValueType", "MetricType")
VALUES
    ('QueueNumAbandonedCalls',
     'QM - Number of Abandoned Calls',
     'Interactions Summary', 'InteractionsCount',
     '(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest',
     NULL, NULL, 'number', 'Data'),

    ('QueueNumAbandonedCallbacks',
     'QM - Number of Abandoned Callbacks',
     'Interactions Summary', 'InteractionsCount',
     '(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest',
     NULL, NULL, 'number', 'Data'),

    ('QueueNumOutboundCalls',
     'QM - Number of Outbound Calls',
     'Interactions Summary', 'InteractionsCount',
     '(InteractionType=="Call") && (CallType=="External")  && Direction == "Outgoing"',
     NULL, NULL, 'number', 'Data'),

    ('QueueNumTransferredCalls',
     'QM - Number of Transferred Calls',
     'Interactions Summary', 'InteractionsCount',
     '(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsTransferred',
     NULL, NULL, 'number', 'Data')

ON CONFLICT ("MetricId") DO NOTHING;

-- Verify: should return 4 rows after first run, 0 on repeat
SELECT "MetricId", "MetricFunction", "MetricParameter"
FROM   "RTSGrid_Metric"
WHERE  "MetricId" IN (
    'QueueNumAbandonedCalls',
    'QueueNumAbandonedCallbacks',
    'QueueNumOutboundCalls',
    'QueueNumTransferredCalls'
)
ORDER BY "MetricId";
```

After writing, verify:
```bash
sync
tail -5 "db/migrations/20260605_001_add_missing_metrics.sql"
wc -l "db/migrations/20260605_001_add_missing_metrics.sql"
```

---

## Step 3 — Run migration on dev server

```bash
psql -U ccdashboard_user -d rtmviewdb -f "db/migrations/20260605_001_add_missing_metrics.sql"
```

Expected output: `INSERT 0 4` on first run (or `INSERT 0 0` if already exists — idempotent).
The SELECT at end of file must return 4 rows.

If psql connection fails, check `appsettings.Development.json` or User Secrets for
the connection string and adjust the psql command accordingly.

---

## Step 4 — Add 4 rows to db/data/02_metrics.sql

File: `db/data/02_metrics.sql` uses `COPY "RTSGrid_Metric" FROM stdin;` with tab-separated rows.
Find the `\.` terminator of the RTSGrid_Metric COPY block and insert 4 new rows BEFORE it.

Use Python atomic write + os.fsync:

```python
import os

path = r"D:\Claude\Projects\RTM View Shell\db\data\02_metrics.sql"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

new_rows = "\n".join([
    "QueueNumAbandonedCalls\tQM - Number of Abandoned Calls\tInteractions Summary\tInteractionsCount\t(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest\t\\N\t\\N\tnumber\tData",
    "QueueNumAbandonedCallbacks\tQM - Number of Abandoned Callbacks\tInteractions Summary\tInteractionsCount\t(InteractionType==\"Callback\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsAbandoned && !IsCallbackRequest\t\\N\t\\N\tnumber\tData",
    "QueueNumOutboundCalls\tQM - Number of Outbound Calls\tInteractions Summary\tInteractionsCount\t(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Outgoing\"\t\\N\t\\N\tnumber\tData",
    "QueueNumTransferredCalls\tQM - Number of Transferred Calls\tInteractions Summary\tInteractionsCount\t(InteractionType==\"Call\") && (CallType==\"External\")  && Direction == \"Incoming\" && IsTransferred\t\\N\t\\N\tnumber\tData",
]) + "\n"

# Insert before the \. terminator of RTSGrid_Metric COPY block
# Find the first \. that terminates the COPY block
marker = "\n\\.\n"
idx = text.find(marker)
if idx == -1:
    raise ValueError("Could not find COPY terminator")

text = text[:idx + 1] + new_rows + text[idx + 1:]

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print("Done")
```

Verify:
```bash
sync
grep -c "QueueNumAbandoned\|QueueNumOutbound\|QueueNumTransferred" "db/data/02_metrics.sql"
# Must return 4
tail -3 "db/data/02_metrics.sql"
```

---

## Step 5 — Pre-commit check (§0.5)

```bash
bash tools/pre-commit-check.sh db/migrations/20260605_001_add_missing_metrics.sql db/data/02_metrics.sql
```
Exit code must be 0.

---

## Step 6 — Commit

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  db/migrations/20260605_001_add_missing_metrics.sql \
  db/data/02_metrics.sql
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "db: add QueueNumAbandonedCalls/Callbacks, OutboundCalls, TransferredCalls metrics"
cp /tmp/cc-idx .git/index
git log --oneline -3
git status --short
```

---

## Step 7 — Re-sync from HEAD (§0.6 PD-007)

```bash
for f in "db/migrations/20260605_001_add_missing_metrics.sql" "db/data/02_metrics.sql"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

---

## Final report

Print:
1. Commit hash
2. psql output from Step 3 (INSERT row count + SELECT results)
3. Line count of both committed files
4. Path to migration file for external server deployment:
   `db/migrations/20260605_001_add_missing_metrics.sql`
   (run with: `psql -U ccdashboard_user -d rtmviewdb -f <path>`)
