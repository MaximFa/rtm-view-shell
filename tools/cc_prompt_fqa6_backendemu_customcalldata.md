# CC task — F-QA-6: dev BackendEmulation RTSData_Interaction drift — add CustomCallData1..20

> Owner: dba (slug dba-0620). Branch **v3**. Prefix fix: (or db:). NO push (§37). Submit to coordinator §4 BEFORE operator runs.
> ROOT (object-store, conclusive): PROD canonical db/schema.sql has RTSData_Interaction.CustomCallData + CustomCallData1..20 (21 cols);
> the DEV DB's RTSData_Interaction is built by the BackendEmulation EF migration 20260526203609_AddRtsDataEntitiesAndStatusGroup.cs
> via raw `migrationBuilder.Sql("CREATE TABLE IF NOT EXISTS ""RTSData_Interaction"" (... ""CustomCallData"" text ...)")` — it has
> ONLY `CustomCallData` (1 col), NOT 1..20. ArchiverService.cs:112-118 raw INSERT..SELECT lists CustomCallData1..20 -> on the dev DB
> -> 42703 'column "CustomCallData1" does not exist' (Position 1431) -> caught+logged -> 0 rows archived, arch_watermark stays empty.
> => v3 PROD code is CORRECT; this is a DEV-ONLY BackendEmulation schema drift vs canonical schema.sql. arch_rtsdata_interaction
> (step-0) already mirrors 21 cols; only the dev SOURCE table is short. Fix = bring the dev source up to canonical.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md ; .claude/skills/role-dba/role-dba.md (§A + §C)
Read (object-store, v3): db/schema.sql RTSData_Interaction block (canonical CustomCallData1..20, all `text` nullable);
  src/CcDashboard.Infrastructure/Migrations/BackendEmulation/20260526203609_AddRtsDataEntitiesAndStatusGroup.cs (how the dev table is built — raw Sql, IF NOT EXISTS);
  src/CcDashboard.Infrastructure/BackgroundServices/ArchiverService.cs:108-135 (the raw SELECT column list the source must satisfy);
  src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs + BackendEmulationDbContextModelSnapshot.cs (is RTSData_Interaction EF-modeled or raw-SQL-only?).

## INIT / discipline
- §0.2 integrity; **branch v3** (git checkout v3; verify object-store, NOT mount status §0.5).
- §0.3 writes Python+os.fsync ONLY (Edit BANNED); after each source write: sync + tail -3 + wc -l + NUL-check (0 NUL).
- §0.4 if `.git/index.lock` phantom blocks commit: temp-index path (cp .git/index /tmp/idx; GIT_INDEX_FILE=/tmp/idx git add/commit; cp back).
- §42.6 sync block: slug dba-0620; claims = ["src/CcDashboard.Infrastructure/Migrations/BackendEmulation/**","src/CcDashboard.Domain/Domain/RtsEntities.cs","src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs"]. commit.lock around commit. §0.6b binding -> .coord/cc/dba.md. NO push.
- Check .coord/push/request.md — if a FREEZE is active for v3, HOLD (this fix is the thing the push is HELD on; coordinator will sequence).

## THE WORK (one fix: commit) — DEV BackendEmulation ONLY

### Determine the table-management style first (object-store)
20260526203609 builds RTSData_Interaction with raw `migrationBuilder.Sql(CREATE TABLE IF NOT EXISTS ...)`. Confirm whether the
BackendEmulation MODEL/snapshot maps RTSData_Interaction as an EF entity with explicit columns (it likely maps only a SUBSET read
by HistoricalAggregationService; the 1..20 are NOT read via EF — the archiver reads them via RAW SQL). This decides snapshot scope.

### A. NEW BackendEmulation migration (raw Sql, forward-only, idempotent) — PRIMARY
Add a new BackendEmulation EF migration (e.g. `dotnet ef migrations add AddRtsInteractionCustomCallData1to20 --context BackendEmulationDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web`).
Up() = ONE raw `migrationBuilder.Sql(@"...")` adding all 20, idempotent + matching schema.sql (text, nullable), e.g. for N=1..20:
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData1" text;
    ... (CustomCallData2 .. CustomCallData20) ...
(Use IF NOT EXISTS on every column so re-apply / partially-migrated dev DBs are safe.) Down() = DROP COLUMN IF EXISTS for the 20.
Match schema.sql EXACTLY: type `text`, nullable, no defaults.

### B. Snapshot + entity consistency (only as the model actually requires)
- If RTSData_Interaction is RAW-SQL-managed in BackendEmulation (no EF column mapping for it) — which the existing CREATE-via-Sql
  pattern implies — then the ModelSnapshot has NO column entries for it; the `ef migrations add` will produce an EMPTY model-diff and
  you keep the raw Sql in Up() (the migration is hand-written Sql, snapshot unchanged). Do NOT invent entity props that aren't modeled.
- If (and only if) RTSData_Interaction IS EF-modeled with explicit columns, add the 20 string? props (RtsEntities.cs) + HasColumnName
  mappings so `ef migrations add` regenerates a consistent snapshot; keep names CustomCallData1..20, all nullable text.
- Net: the committed migration + snapshot must be internally consistent (a follow-up `ef migrations add` would yield NO further diff).

## ACCEPTANCE (functional — QA floor)
- Fresh dev DB (Create-FreshDb / Web.exe migrate, BackendEmulation context): RTSData_Interaction has CustomCallData + CustomCallData1..20 (22 total CustomCallData* incl base).
- ArchiverService interaction-copy completes with NO 42703; arch_rtsdata_interaction populates; arch_watermark for interaction sets.
- `dotnet build CcDashboard.sln` = 0 errors. A re-run `ef migrations add` (probe) shows NO pending model diff (snapshot consistent).
- ZERO change to PROD path (db/schema.sql, ArchiverService, arch_* migration all already correct — do NOT touch them).

## ⚠ COMMIT HYGIENE (coordinator §4 NOTE 19:20 — MANDATORY)
- NARROW, EXPLICIT `git add` of ONLY your new files (the new BackendEmulation migration .cs + .Designer.cs, and the snapshot
  BackendEmulationDbContextModelSnapshot.cs ONLY IF a real model-diff occurred; RtsEntities.cs only if you added modeled props).
  NEVER `git add -A` and NEVER dir-wide `git add src/.../Migrations/BackendEmulation/`.
- There is an UNRELATED untracked working-tree migration `20260606100233_AddCatalogueFieldsToRtsGridMetric` that is NOT on v3 —
  it MUST NOT be swept into this commit. Before commit: `git status --short` and confirm your staged set excludes it.
- Object-store verify post-stage: `git show v3:<each new file>` (or `git diff --cached --name-only`) shows ONLY your F-QA-6 files,
  single copy, no path-casing dupes. The mount may report §0.5 false-`??` on existing BackendEmulation files — verify by object-store,
  do NOT re-add files already tracked on v3.

## COMMIT (fix: , commit.lock, NO push)
`fix: F-QA-6 dev BackendEmulation RTSData_Interaction — add CustomCallData1..20 (ALTER ADD COLUMN IF NOT EXISTS, match schema.sql) -> archiver 42703 resolved`
then §0.6 verify + §0.7 re-sync. §0.6b binding RESULT -> .coord/cc/dba.md ; CAPTURE lesson -> role-dba §B if any.

## REPORT -> binding cc/dba.md RESULT + inbox/coordinator.md + ping test (QA re-verify). NO push.
