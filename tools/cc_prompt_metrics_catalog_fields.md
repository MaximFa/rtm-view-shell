# CC Task D3a: RtsGridMetric catalogue fields — entity + EF migration + backfill from JSON

> Stage-2 metrics catalogue, foundation layer (data model only; UI page = follow-up D3b).
> Design locked with operator 2026-06-06: ALL-IN-DB catalogue. Adds 12 nullable catalogue columns
> to RtsGridMetric, backfilled ONCE from docs/metrics-catalog.json (198 cards). metrics-catalog.json
> stays only as a backfill source / derived export.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (§8 catalog.json schema, §2 engine truths)
Read file: .claude/skills/widget-creator/widget-creator.md  (§24.4 UnitOfWork multi-context; EF migration notes)

## Git push
Do NOT run `git push`. Commit only (§37).

## Claims (file-mode, metrics-0605)
- web: `src/CcDashboard.Domain/Domain/RtsGridMetric.cs`,
       `src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs`,
       new migration under `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/`
- tools: `tools/gen_catalog_backfill.py`, `tools/lint_metrics.py`
- db: `db/data/02_metrics.sql`, `db/schema.sql`
> Do NOT touch MetricsPage.razor, DTOs, queries (that is D3b). Do NOT touch any daytrend-claimed
> file (RtmRelay*, DayTrend*, Engine.cs, DBMng.cs, RealtimeData.cs, UserStatusData.cs, db/functions/*).

## Step 0 — §0.6a integrity block
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l); W=$(wc -l < "$f" 2>/dev/null)
    if [ $((H-W)) -gt 0 ]; then echo "TRUNCATED $f"; git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f ($W)"; fi
done
sync
# Known recurring truncation on this mount: tools/lint_metrics.py, db/data/02_metrics.sql, db/schema.sql.
# Verify hash before "restoring": git hash-object <f> vs git rev-parse HEAD:<f>.
```
Then the coord sync block from `tools/cc_prompt_sync_block.md` (running slug + claims above).

## Key facts (verified, do not re-derive)
- `RtsGridMetric` is mapped in **`BackendEmulationDbContext`** (DbSet `RtsGridMetrics`, `mb.Entity<RtsGridMetric>` at ~line 149, table `"RTSGrid_Metric"`, PK `MetricId`). The EF migration MUST target this context, NOT AppDbContext.
- Migration command:
  `dotnet ef migrations add AddCatalogueFieldsToRtsGridMetric --context BackendEmulationDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web`
  → lands in `src/CcDashboard.Infrastructure/Migrations/BackendEmulation/`.
- The table physically lives in `rtmviewdb`; `db/data/02_metrics.sql` is exported from there.

## Deliverable 1 — Entity (RtsGridMetric.cs)
Add 12 nullable properties (all nullable so existing rows & seed are unaffected):
```csharp
// Catalogue — editorial
public string? DisplayName { get; set; }
public string? ShortDescription { get; set; }
public string? LongDescription { get; set; }
public string? Comparison { get; set; }
public string? StandardKpi { get; set; }
public string? StandardRef { get; set; }
// Catalogue — taxonomy (stored, not derived)
public string? CatalogCategory { get; set; }   // Queue | AgentGroup | Agent
public string? Family { get; set; }             // e.g. queue.pct.answered_threshold_inc
public string? Channel { get; set; }            // calls | callbacks | calls_callbacks | chats | digital
public int? ThresholdSec { get; set; }          // 30 | 60 | 120 | 360
// Catalogue — lifecycle
public string? CatalogStatus { get; set; }      // active | duplicate | deprecated | defect-candidate
public string? CatalogNotes { get; set; }       // Superadmin-only (display gated in D3b)
```

## Deliverable 2 — Mapping (BackendEmulationDbContext.cs)
Inside the existing `mb.Entity<RtsGridMetric>(e => { ... })` block add column config:
```csharp
e.Property(x => x.DisplayName).HasMaxLength(200);
e.Property(x => x.ShortDescription).HasMaxLength(500);
e.Property(x => x.LongDescription).HasColumnType("text");
e.Property(x => x.Comparison).HasColumnType("text");
e.Property(x => x.StandardKpi).HasMaxLength(100);
e.Property(x => x.StandardRef).HasMaxLength(200);
e.Property(x => x.CatalogCategory).HasMaxLength(20);
e.Property(x => x.Family).HasMaxLength(100);
e.Property(x => x.Channel).HasMaxLength(20);
// ThresholdSec int? — default mapping
e.Property(x => x.CatalogStatus).HasMaxLength(20);
e.Property(x => x.CatalogNotes).HasColumnType("text");
```
Write via Python+fsync (§0.3 — Edit BANNED).

## Deliverable 3 — EF migration
Generate it with the command above. Review the generated Up()/Down(): Up adds 12 columns, Down drops them.
Do NOT hand-edit schema; let EF generate (MAINT-04).

## Deliverable 4 — Backfill generator `tools/gen_catalog_backfill.py`
Python script: read `docs/metrics-catalog.json`, emit idempotent `UPDATE "RTSGrid_Metric" SET ... WHERE "MetricId"='...';`
for every entry, mapping JSON→column:
`displayName→DisplayName, shortDescription→ShortDescription, longDescription→LongDescription,
comparison→Comparison, standardKpi→StandardKpi, standardRef→StandardRef, category→CatalogCategory,
family→Family, channel→Channel, thresholdSec→ThresholdSec, status→CatalogStatus, notes→CatalogNotes`.
- Proper SQL escaping (single quotes doubled); NULL for missing/empty; ThresholdSec numeric or NULL.
- Output to stdout or `--out db/migrations/20260606_003_catalog_backfill.sql` with a header comment.
- Only UPDATE existing rows (never INSERT) — legacy metric rows already exist.
Run it → produce `db/migrations/20260606_003_catalog_backfill.sql`.

## Deliverable 5 — Linter update `tools/lint_metrics.py`
The JSON↔catalogue coverage gate is now MOOT (card lives in the same row). Instead:
- Remove/skip any coverage-vs-json check if present (there is none committed yet — fine).
- Add column-presence checks against `db/data/02_metrics.sql` AFTER it is re-exported with the new
  columns: every live (non duplicate/deprecated) metric SHOULD have non-empty DisplayName +
  ShortDescription → WARNING if missing (authoring backlog, not a hard fail). CatalogStatus, if present,
  must be in {active,duplicate,deprecated,defect-candidate} → ERROR otherwise.
- Keep ALL existing checks (function exists, calc refs, string-literal, duplicates, no-dash/no-dot).
- NOTE: 02_metrics.sql COPY column order changes after the migration — update the parser to read the
  new column count/order from the actual COPY header, not a hardcoded 9.

## Execution order
1. Entity + mapping + `dotnet ef migrations add ...` (BackendEmulationDbContext).
2. `dotnet build CcDashboard.sln` clean (stop dotnet first, widget-creator §28).
3. Apply migration to dev DB: `dotnet ef database update --context BackendEmulationDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web` (or psql the generated migration SQL).
4. Generate + apply backfill: `python3 tools/gen_catalog_backfill.py --out db/migrations/20260606_003_catalog_backfill.sql` → `psql -U ccdashboard_user -d rtmviewdb -f db/migrations/20260606_003_catalog_backfill.sql`.
5. Verify: `SELECT count(*) FROM "RTSGrid_Metric" WHERE "DisplayName" IS NOT NULL;` → 198 (all backfilled).
6. `db/tools/Export-All.ps1 -Password ... -CommitMessage "db: RtsGridMetric catalogue columns + backfill"` → regenerates 02_metrics.sql + schema.sql.
7. Update + run linter against the new export → must pass (only the known CurLoginTimeStamp ERROR; `--ignore-known` → 0).

## Commit plan (lock per §42.4; per-module §39.3)
- `web:` RtsGridMetric.cs + BackendEmulationDbContext.cs + EF migration files
- `db:` db/data/02_metrics.sql + db/schema.sql + db/migrations/20260606_003_catalog_backfill.sql
- `docs:` tools/gen_catalog_backfill.py + tools/lint_metrics.py
Each: pre-commit-check → §0.6 verify → journal → release lock → PD-007 re-sync. No push.

## Acceptance criteria
1. `dotnet build CcDashboard.sln` clean; migration targets BackendEmulationDbContext.
2. All 198 metric rows have DisplayName/ShortDescription/Family/etc backfilled (spot-check 5 incl. a matrix
   metric like QueuePctAnsweredCalls60secInc and an agent metric).
3. 02_metrics.sql re-exported WITH the new columns; linter parses the new COPY header and passes
   (only known CurLoginTimeStamp error; --ignore-known → 0).
4. Down() migration drops the 12 columns cleanly.
5. Commits per module; tree clean (ignore known false-M); journal lines; lock released; no push.
6. MetricsPage.razor / DTOs / queries UNCHANGED (D3b scope).
