# CC Task: Fix DayTrend — answered_calls filter must match incoming_calls direction

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push` automatically. Commit only.

---

## Problem

`fn_daytrendinteractions` counts `answered_calls` without filtering by `Direction`,
so answered callbacks and outbound calls inflate the number above `incoming_calls`.

```sql
-- WRONG: counts ALL answered (incl. outbound, callbacks)
answered_calls = COUNT(*) FILTER (WHERE "IsAnswered" = true)

-- CORRECT: only answered incoming interactions
answered_calls = COUNT(*) FILTER (WHERE "IsAnswered" = true AND "Direction" = 'Incoming')
```

---

## Files to change

### 1. `db/functions/02_rtsdata_functions.sql`

Find the line (inside `fn_daytrendinteractions`):
```sql
COUNT(*) FILTER (WHERE "IsAnswered" = true)                                       AS answered_calls,
```
Replace with:
```sql
COUNT(*) FILTER (WHERE "IsAnswered" = true AND "Direction" = 'Incoming')          AS answered_calls,
```

### 2. `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/20260526214442_AddDayTrendFunctions.cs`

Same fix — find both occurrences (Up and Down migration have the function text).
In the `Up()` method, find the same line and apply the same change.

**Do NOT touch the Down() method** — it only drops the functions.

---

## Verification

```bash
grep -n "answered_calls" db/functions/02_rtsdata_functions.sql
# Must show: WHERE "IsAnswered" = true AND "Direction" = 'Incoming'

grep -n "answered_calls" src/CcDashboard.Infrastructure/Migrations/BackendEmulation/20260526214442_AddDayTrendFunctions.cs
# Same
```

---

## Deploy on server

After commit, apply the fix directly on the server (no app restart needed):
```sql
-- Run on server DB:
\i db/functions/02_rtsdata_functions.sql
-- or apply the specific CREATE OR REPLACE FUNCTION fn_daytrendinteractions block only
```

---

## Implementation steps

1. Read skill files
2. `git status --short` + integrity check
3. Fix both files via Python atomic write + fsync (Edit tool BANNED)
4. `dotnet build CcDashboard.sln` — 0 errors
5. `bash tools/pre-commit-check.sh`
6. Commit: `fix: fn_daytrendinteractions answered_calls filter by Direction=Incoming`
7. Re-sync from HEAD (§0.6 PD-007)

---

## Re-sync block

```bash
for f in \
  "db/functions/02_rtsdata_functions.sql" \
  "src/CcDashboard.Infrastructure/Migrations/BackendEmulation/20260526214442_AddDayTrendFunctions.cs"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
