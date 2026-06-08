# CC Task — RTSData_UserStatusLog write regression test

> Issued by Cowork session **RTM Test4** (slug `test4-0606`).
> Guards daytrend's fix 434e4c7: `RTSData_SetUserStatus` must APPEND a history row to
> `RTSData_UserStatusLog` (the INSERT dropped in the MSSQL->PG port; DayTrend agent
> history reads ONLY from this table). No test currently covers it.

---

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a) — run FIRST

```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin v2 -q
# §42.7.6 post-push: confirm local HEAD == origin/v2 (or fast-forwardable)
git rev-parse HEAD; git rev-parse origin/v2
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== Integrity check complete ==="
```

---

## Multi-session sync — MANDATORY (§42, skill v1.4)

Session slug: `test4-0606`
Claims (touch ONLY these, plus /tmp/test4-0606_*.py throwaway — L-SC-16):
- `tests/CcDashboard.Tests.Security/Widgets/RtsDataUserStatusLogTests.cs`  (new file)
- `tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs`            (ADDITIVE modify)

### S1. Push barrier check — before ANY work (content-based, L-SC-10)
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."; exit 1
fi
```

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py test4-0606 \
  tests/CcDashboard.Tests.Security/Widgets/RtsDataUserStatusLogTests.cs \
  tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs
# exit 1 -> STOP: conflict goes to the queue (.coord/queue.md, skill §9).
```
Modify ONLY the two claimed files. Anything else -> STOP and report.

### S3. Commit lock — phantom-aware acquire (L-SC-14)
```python
# /tmp/test4-0606_acquire_lock.py
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
for attempt in range(5):
    # phantom-aware: a lock that exists but is empty/unreadable is a ghost (L-SC-14)
    if os.path.exists(lock):
        try:
            body = open(lock).read()
        except Exception:
            body = ""
        if body.strip() == "":
            try: os.remove(lock)
            except Exception: pass
        else:
            print("BUSY: " + body.strip()); time.sleep(60); continue
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: test4-0606\nacquired: " + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        print("RACE, retry"); time.sleep(5)
print("FAILED to acquire commit lock"); sys.exit(1)
```
While holding: `bash tools/pre-commit-check.sh` -> `git add` (claimed files only)
-> `git commit -m "web: RTSData_UserStatusLog write regression test"` -> §0.6 post-commit verify.
Stale NON-empty lock >15 min: report contents, WAIT for operator — never auto-delete.

### S4. Journal + release — after the commit
```python
# /tmp/test4-0606_journal_release.py
import os, datetime, subprocess
h = subprocess.check_output(["git","log","-1","--format=%h %s"]).decode().strip()
line = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ") + " | test4-0606 | " + h + "\n"
with open(".coord/journal.md","a",encoding="utf-8") as f:
    f.write(line); f.flush(); os.fsync(f.fileno())
os.remove(".coord/locks/commit.lock")
print("journal appended, lock released")
```
Then `sync`.

### S4b. POST-COMMIT FLUSH to coordinator (skill v1.4) — after release
```python
# /tmp/test4-0606_postcommit_flush.py
import os, datetime, subprocess
h = subprocess.check_output(["git","log","-1","--format=%h"]).decode().strip()
now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
block = ("## " + now + " | from: test4-0606 | to: coordinator\n"
         "COMMITTED " + h + " web: RTSData_UserStatusLog write regression test (RDUL-01..03).\n"
         "Claims releasable: RtsDataUserStatusLogTests.cs, PostgresFixture.cs (additive change).\n"
         "Blocker: none. Next: idle / await push barrier. Tests: report dotnet result below.\n---\n")
with open(".coord/inbox/coordinator.md","a",encoding="utf-8") as f:
    f.write(block); f.flush(); os.fsync(f.fileno())
print("post-commit flush sent")
```
Then `sync`.

### S5. Git push — DO NOT (§37). Push only via tools/cc_prompt_push.md.

### S6. PD-007 re-sync (final) — re-write committed files from HEAD
```bash
for f in tests/CcDashboard.Tests.Security/Widgets/RtsDataUserStatusLogTests.cs \
         tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs; do
    git show HEAD:"$f" > "$f"; echo "re-synced $f ($(wc -l < "$f") lines)"
done
sync
```

---

## Mandatory — read before starting (§40)
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

## File writes — Python + os.fsync ONLY (§0.3). Edit tool BANNED.
After each write: `sync && tail -3 <file> && wc -l <file>`.

---

## TASK

`RTSData_SetUserStatus` is now a **PROCEDURE** (15 params) in
`db/functions/02_rtsdata_functions.sql`. Exact signature (order matters):
```
CALL "RTSData_SetUserStatus"(
  p_user_id text, p_status_id text, p_server_id text, p_on_date text,
  p_status_name text, p_status_group text,
  p_total_duration double precision, p_max_duration double precision,
  p_total_count integer, p_display_name text,
  p_start_time timestamptz, p_end_time timestamptz,
  p_time_zone text, p_update_time timestamptz, p_tenant_id uuid)
```
Behaviour: (a) IF p_start_time AND p_end_time NOT NULL AND p_end_time > p_start_time ->
INSERT a row into `RTSData_UserStatusLog`
(cols: TenantId, UserId, StatusId, ServerId, OnDate, StartTime, EndTime,
Duration = (end-start) in **ms** as integer, UpdateTime, TimeZone, StatusGroup);
(b) UPSERT current state into `RTSData_UserStatus` (4-col PK).

Tables `RTSData_UserStatusLog` and `RTSData_UserStatus` already exist via
BackendEmulation migrations (fixture runs `beDb.Database.MigrateAsync()`), entity
`RtsDataUserStatusLog` in `RtsDataEntities.cs`, DbSet `RtsDataUserStatusLogs`.

### Part A — PostgresFixture: ADDITIVE helper to load the RTSData functions
ADDITIVE-ONLY — `PostgresFixture` is the SHARED Security fixture. Append a new method
ONLY; do NOT modify/reorder/remove any existing line (mirror the existing
`EnsureRtsGridFunctionsAsync`, just a different file):
```
public async Task EnsureRtsDataFunctionsAsync()  // loads db/functions/02_rtsdata_functions.sql
```
- Resolve repo-root path the SAME way `EnsureRtsGridFunctionsAsync` does (walk up from
  AppContext.BaseDirectory for db/functions/02_rtsdata_functions.sql; same dev-path
  fallback; throw if not found).
- `await beDb.Database.ExecuteSqlRawAsync(sql)` (whole file; it contains DROP + CREATE
  PROCEDURE blocks with $$).
- Verify the diff shows ONLY additions:
  `git diff HEAD -- tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs`
  must contain no `-` lines except trailing context.

### Part B — New test file RtsDataUserStatusLogTests.cs
`[Collection("Postgres")] public class RtsDataUserStatusLogTests(PostgresFixture postgres)`

Helper: a private method that issues the CALL with typed `NpgsqlParameter`s (NpgsqlDbType:
text/Double/Integer/TimestampTz/Uuid; pass DBNull.Value for null timestamps). Use
`CALL "RTSData_SetUserStatus"(@p1,...,@p15)` via `ExecuteSqlRawAsync` — NEVER string concat (CODE-01).
Call `await postgres.EnsureRtsDataFunctionsAsync();` at the start of each test.

Tests (`[Trait("Req","RDUL-NN")]`), each with fresh `Uuid.NewSequential()` user id and
`postgres.TenantAId`, unique values to avoid collisions:

1. **RDUL-01 — writes a history row when start < end.**
   CALL with p_start_time = T0, p_end_time = T0+30s (both non-null), p_total_count etc. set.
   Assert (read via `BeDb`/`RtsDataUserStatusLogs`, `IgnoreQueryFilters`, filter by the
   test UserId + TenantAId): exactly ONE log row exists; `Duration == 30000` (ms);
   `StatusGroup` and `TenantId` match the passed values. (Guards the dropped INSERT.)

2. **RDUL-02 — guard: NO history row when times null or end <= start.**
   Two sub-cases (or two facts): (i) p_start_time = NULL; (ii) p_end_time = p_start_time.
   Assert: ZERO rows in RTSData_UserStatusLog for that UserId — BUT a current-state row
   WAS written to `RTSData_UserStatus` (upsert path still runs). Confirms the IF guard.

3. **RDUL-03 — log row is tenant-scoped.**
   CALL once for TenantAId and once (different user) for TenantBId, both with valid times.
   Assert: querying RTSData_UserStatusLog filtered by TenantAId returns the A row and NOT
   the B row; each row's `TenantId` equals the tenant it was written under.

Notes: exact double-quoted PascalCase identifiers; OnDate is text (e.g. "2026-06-06");
timestamps as `DateTime` (UTC) via TimestampTz params.

### Part C — Build + run (report, do not push)
```bash
dotnet test tests/CcDashboard.Tests.Security --filter "Req~RDUL" 2>&1 | tail -30
```
If a test fails on a column name / proc signature / param type, FIX THE TEST (production
fix 434e4c7 is verified correct — do NOT touch production or any file outside the 2 claims).

---

## Commit — after green
Run S3 (phantom-aware lock) -> pre-commit-check -> `git add` claimed files ->
`git commit -m "web: RTSData_UserStatusLog write regression test"` -> §0.6 verify ->
S4 (journal+release) -> S4b (post-commit flush to coordinator) -> S6 (PD-007 re-sync).
DO NOT `git push`.
