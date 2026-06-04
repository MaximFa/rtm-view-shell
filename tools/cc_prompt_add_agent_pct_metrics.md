# CC Task: Apply agent state percent metrics migration + export to git

## Goal
Apply migration `db/migrations/20260604_001_add_agent_state_pct_metrics.sql` to the
live PostgreSQL database, then re-export the DB state to git so the metrics are
captured in `db/data/02_metrics.sql`.

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Environment rules
- CLAUDE.md §0.3 — no Edit tool; use Python for file writes
- CLAUDE.md §0.5 — pre-commit-check.sh before every commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT run `git push` automatically

---

## Step 1 — Apply migration via psql

```powershell
$env:PGPASSWORD = "!@#qweASDzxc"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" `
    -h localhost -p 5432 -U ccdashboard_user -d rtmviewdb `
    -f "db\migrations\20260604_001_add_agent_state_pct_metrics.sql"
```

Expected output: the SELECT at the end of the migration must return exactly 4 rows:
```
MonAgentAvailableDurationPct | AVAILABLE
MonAgentBreakDurationPct     | BREAK
MonAgentPaperworkDurationPct | PAPERWORK
MonAgentTrainingDurationPct  | TRAINING
```

If 0 rows returned — metrics already existed (ON CONFLICT DO NOTHING fired). Still OK.
If psql error — stop, do not proceed.

---

## Step 2 — Export DB state to git

```powershell
powershell -ExecutionPolicy Bypass -File db\tools\Export-All.ps1 `
    -Password "!@#qweASDzxc" `
    -CommitMessage "db: add AgentStateGroup percent metrics (AVAILABLE/BREAK/PAPERWORK/TRAINING)"
```

Export-All.ps1 will:
- Regenerate `db/schema.sql`
- Regenerate `db/data/02_metrics.sql` (now containing the 4 new metrics)
- Commit automatically with the provided message

---

## Step 3 — Verify commit

```bash
git log --oneline -3
git show HEAD:db/data/02_metrics.sql | grep "AgentStatePct\|DurationPct" | sort
```

Expected: 5 lines total (ONPHONE already existed + 4 new):
```
MonAgentAvailableDurationPct
MonAgentBreakDurationPct
MonAgentPaperworkDurationPct
MonAgentTalkDurationPct
MonAgentTrainingDurationPct
```

---

## Step 4 — Also commit the migration file itself

The migration file `db/migrations/20260604_001_add_agent_state_pct_metrics.sql` and
this prompt file `tools/cc_prompt_add_agent_pct_metrics.md` should be committed
(Export-All.ps1 may not pick them up automatically).

```bash
# Pre-commit check first (§0.5)
bash tools/pre-commit-check.sh db/migrations/20260604_001_add_agent_state_pct_metrics.sql

# Then add and commit
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add db/migrations/20260604_001_add_agent_state_pct_metrics.sql
GIT_INDEX_FILE=/tmp/cc-idx git add tools/cc_prompt_add_agent_pct_metrics.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "db: add migration file for agent state percent metrics"
cp /tmp/cc-idx .git/index
```

Post-commit check (§0.6):
```bash
git status --short
git log --oneline -3
```

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.

---

## Re-sync committed files from HEAD (§0.6 PD-007, mandatory last step)

```bash
for f in db/migrations/20260604_001_add_agent_state_pct_metrics.sql \
          tools/cc_prompt_add_agent_pct_metrics.md \
          db/data/02_metrics.sql; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
