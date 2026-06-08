# CC Task — QueueGrid data-flow regression tests (§36 hardening)

> Issued by Cowork session **RTM Test4** (slug `test4-0606`).
> Purpose: add regression tests that lock in the two §36 production fixes
> (TemplateCell removed from `RTSGrid_GetDataCells`; `ClassificationId='ALL'`
> on queue assignments). These fixes are correct in code but currently have
> NO test guarding against their recurrence.

---

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a) — run FIRST, no exceptions

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else
        echo "OK: $f ($WT_LINES lines)"
    fi
done
sync
echo "=== Integrity check complete ==="
```

---

## Multi-session sync — MANDATORY (§42)

Session slug: `test4-0606`
Claims for this task (touch ONLY these, plus /tmp throwaway):
- `tests/CcDashboard.Tests.Security/Widgets/QueueGridDataFlowTests.cs`  (new file)
- `tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs`         (modify: load pgsql functions)

### S1. Push barrier check — before ANY work
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."; exit 1
fi
```

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py test4-0606 \
  tests/CcDashboard.Tests.Security/Widgets/QueueGridDataFlowTests.cs \
  tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs
# exit 1 -> STOP: conflict goes to the queue (.coord/queue.md, skill section 9).
```
Modify ONLY the two claimed files. If the task needs any other file — STOP and report.

### S3. Commit lock — around EVERY git add/commit
```python
# /tmp/acquire_lock.py
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
for attempt in range(5):
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: test4-0606\nacquired: " + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        print("BUSY: " + open(lock).read().strip()); time.sleep(60)
print("FAILED to acquire commit lock after 5 attempts"); sys.exit(1)
```
While holding the lock: `bash tools/pre-commit-check.sh` -> `git add` (claimed files only)
-> `git commit -m "web: QueueGrid data-flow regression tests (§36 hardening)"`
-> §0.6 post-commit verification.
Stale lock (>15 min): report contents and WAIT for operator — never auto-delete.

### S4. Journal + release — after the commit
```python
# /tmp/journal_release.py
import os, datetime, subprocess
h = subprocess.check_output(["git","log","-1","--format=%h %s"]).decode().strip()
line = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ") + " | test4-0606 | " + h + "\n"
with open(".coord/journal.md","a",encoding="utf-8") as f:
    f.write(line); f.flush(); os.fsync(f.fileno())
os.remove(".coord/locks/commit.lock")
print("journal appended, lock released")
```
Then `sync`. If the commit aborts, still release the lock.

### S5. Git push — DO NOT (§37). Push only via tools/cc_prompt_push.md.

---

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

---

## File writes — Python + os.fsync ONLY (§0.3). Edit tool is BANNED.
After each write: `sync && tail -3 <file> && wc -l <file>`.

---

## TASK

Two production bugs were fixed (CLAUDE.md §36) but have no regression test:
- **Bug 1** — `RTSGrid_GetDataCells` once INNER-JOINed the always-empty
  `RTSGrid_TemplateCell`, returning 0 rows -> QueueGrid never received cells.
  Fixed query: clean `Grid->Row->Cell->Column` join, `WHERE CellType='Data'`.
- **Bug 2** — queue assignments saved with `ClassificationId` NULL/'' instead of
  `'ALL'` -> RTM engine never registered the queue (`union.addWorkgroup` only runs
  when `ClassificationId == "ALL"`). Fixed: `SaveBusinessUnitCommandHandler` and
  the seeder set `ClassificationId = "ALL"`.

Add a new xUnit test class in the **Security** suite (collection `"Postgres"`,
real Postgres via existing `PostgresFixture` / Testcontainers).

### Part A — PostgresFixture: load the pgsql read functions
The fixture builds tables via EF migrations + `CreateQueueGridTablesAsync`
(raw `ExecuteSqlRawAsync`), but does NOT load `db/functions/*.sql`. Add a helper
that loads the RTSGrid read functions so tests can call them:

- Add `public async Task EnsureRtsGridFunctionsAsync()` (idempotent; safe to call
  multiple times) that reads `db/functions/03_rtsgrid_read.sql` from the repo root
  and executes it against the test database via `ExecuteSqlRawAsync`.
  - Resolve the repo-root path robustly (walk up from `AppContext.BaseDirectory`
    until a folder containing `db/functions/03_rtsgrid_read.sql` is found). If not
    found, `Assert.Fail` with a clear message (do NOT silently skip).
  - The file uses `CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql` blocks with
    `$$ ... $$`; execute the whole file content in one `ExecuteSqlRawAsync` call
    (Npgsql supports multiple statements per command). If the file also contains
    `DROP FUNCTION IF EXISTS` lines that fail on first run, that is fine.
- Do NOT change existing fixture seeding/behaviour; only ADD the helper (and call
  it from the new tests, not from `InitializeAsync`, to avoid perturbing other suites).

### Part B — New test file QueueGridDataFlowTests.cs

`[Collection("Postgres")] public class QueueGridDataFlowTests(PostgresFixture postgres)`

Tests (each `[Trait("Req","QGDF-NN")]`):

1. **QGDF-01 — GetDataCells returns Data cells, excludes non-Data.**
   - `await postgres.EnsureRtsGridFunctionsAsync();`
   - Seed (via `BeDb` / BackendEmulationDbContext, mirroring `CreateQueueGridTablesAsync`):
     one `RTSGrid_Grid`, one `RTSGrid_Row`, one `RTSGrid_Column`, and two
     `RTSGrid_Cell` rows — one `CellType='Data'`, one `CellType='Statistic'`.
   - Call `SELECT * FROM "RTSGrid_GetDataCells"()` (raw SQL, read into a DTO/list).
   - Assert: the Data cell IS returned; the Statistic cell is NOT; count of returned
     rows for the seeded grid == 1. (This fails if the TemplateCell INNER JOIN ever
     returns — guards Bug 1.)

2. **QGDF-02 — SaveBusinessUnit sets ClassificationId='ALL' on every queue assignment.**
   - Arrange `SaveBusinessUnitCommandHandler` with TenantA context (follow the DI
     wiring used in existing tests; reuse `ICurrentUserAccessor`/repos via NSubstitute
     or the real repos as other ConfigurationCommands tests do — match the established
     pattern in the Security suite; if none exists, construct against `CreateDbContext`).
   - Act: send `SaveBusinessUnitCommand` with `QueueIds = ["1001","1002"]` (string ids
     per `NgcBusinessUnitQueueClassification.QueueId`), a valid `SiteId` (seed an
     `NGC_Site` for TenantA if required by FK).
   - Assert (bypass GQF with `IgnoreQueryFilters()`): every persisted
     `NgcBusinessUnitQueueClassification` for that BU has `ClassificationId == "ALL"`;
     count == 2. (Guards Bug 2.)

3. **QGDF-03 — GetAllUnionQueueClassifications is tenant-scoped and returns 'ALL'.**
   - `await postgres.EnsureRtsGridFunctionsAsync();`
   - Seed for TenantA: `NGC_Site`, `NGC_BusinessUnit`, and a
     `NGC_BusinessUnitQueueClassification` row with `ClassificationId='ALL'`.
     Seed an UNRELATED row for TenantB.
   - Call `SELECT * FROM "RTSGrid_GetAllUnionQueueClassifications"(@tenantA)`.
   - Assert: TenantA's row IS returned with `ClassificationID == "ALL"`; TenantB's row
     is NOT present. (Guards Bug 2 + the multi-tenant WHERE filter.)

Notes:
- Match column casing exactly (double-quoted PascalCase identifiers).
- Use `ExecuteSqlRawAsync` / `FromSqlRaw` with **parameters** for tenant ids
  (`NpgsqlParameter`), never string concat (CODE-01).
- Keep each test independent; use fresh `Uuid.NewSequential()` ids and unique
  grid/BU ids so parallel/other tests do not collide. If integer grid/BU ids are
  identity-generated, capture the generated id from the seed and filter by it.

### Part C — Build + run (report results, do not push)
```bash
dotnet test tests/CcDashboard.Tests.Security --filter "Req~QGDF" 2>&1 | tail -30
```
- If a test fails because the fixture cannot reach the function file or a column name
  is wrong, FIX the test (not the production code — production is verified correct).
- Do NOT modify any production file, any metrics file (`RtsGridMetric.cs`, catalog
  migrations), or anything outside the two claimed files.

---

## Commit (after green) — module prefix `web:` (tests/ ⊂ web, §39.3)
Follow S3/S4 above (commit lock + pre-commit-check + journal + release).
Commit message: `web: QueueGrid data-flow regression tests (§36 hardening)`
Then §0.6 post-commit verification and §0.6a/PD-007 re-sync of the two files.
DO NOT `git push`.
