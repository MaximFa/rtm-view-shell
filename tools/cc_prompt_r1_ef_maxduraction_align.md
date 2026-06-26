# CC task — R1: align EF RtsDataUserStatus.MaxDuration -> real column "MaxDuraction" (B-5 blocker, option 1)
> §4-DRAFTED by coordinator-0612 2026-06-14T07:02Z. Owner: backend-0609. Executor: native CC, RTM View Shell repo (Windows, PG18, dotnet ef available).
> Claims: src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs + src/CcDashboard.Infrastructure/Migrations/BackendEmulation/** (new migration only).
> Commit prefix `web:`. **NO push** (rides next barrier).

## Why (decision: option 1)
RTSData_UserStatus real column is "MaxDuraction" (typo) EVERYWHERE canonical: db/schema.sql:2029, all 8 RTSData_* SQL functions
(db/functions/02_rtsdata_functions.sql), migration _011, and live servers 45 & 234. The ONLY divergence is the EF dev-emulation entity
RtsDataUserStatus.MaxDuration (src/CcDashboard.Domain/Domain/RtsDataEntities.cs:56), correct spelling -> a clean BackendEmulation build
creates "MaxDuration", mismatching reality and yielding a DOUBLE column once _011 adds "MaxDuraction".
FIX = EF maps the C# property MaxDuration to the real column "MaxDuraction" (keep readable C# name; match the DB). This is the B-5
schema.sql-regen blocker: after this, a clean EF build yields RTSData_UserStatus with ONLY "MaxDuraction" = matches canon.
DO NOT touch RtsGridUserStatus.MaxDuraction (RtsEntities.cs:131, table RTSGrid_UserStatus) — already the typo, matches reality.
Option 3 (rename to MaxDuration) REJECTED (8 fn rewrites + live 45/234 data migration = prod risk). Keep the typo.

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## §0.6a integrity + binding PREAMBLE
- §0.2 integrity: git status; branch == v2-backend; hash-verify the two claimed paths vs HEAD before editing (object-store, not mount line-count).
- Binding PREAMBLE -> append to .coord/cc/backend.md (Python+os.fsync):
```
## 2026-06-14T07:02Z | binding: backend <-> CC | directive: tools/cc_prompt_r1_ef_maxduraction_align.md | status: open
### DIRECTIVE: EF map RtsDataUserStatus.MaxDuration -> column "MaxDuraction" + BackendEmulation rename migration. Claims: BackendEmulationDbContext.cs + Migrations/BackendEmulation/**. web:. NO push.
```

## S1. Push barrier check (bash)
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo "BARRIER ACTIVE"; cat .coord/push/request.md; exit 1; fi
```
## S2. Claim check (bash)
```bash
python3 tools/coord_check_claims.py backend-0609 src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs
```
Touch ONLY the claimed paths.

## 1. Edit BackendEmulationDbContext.cs — add HasColumnName mapping
In the `mb.Entity<RtsDataUserStatus>(e => { ... })` block (currently lines ~302-314, ends after `e.Property(x => x.TimeZone).HasMaxLength(10);`),
add ONE line before the closing `});`:
```csharp
            e.Property(x => x.MaxDuration).HasColumnName("MaxDuraction"); // real DB column mis-spelled (matches RTSData_* fns, schema.sql, RTSGrid_UserStatus); C# keeps readable name
```
(Mirror the existing idiom in this file: RtsDataChatMessage uses `e.Property(x => x.MsgTimeStamp).HasColumnName("TimeStamp");`.)
Do NOT change RtsDataEntities.cs (C# property stays MaxDuration). Do NOT touch RtsGridUserStatus / RTSGrid_UserStatus.

## 2. Add BackendEmulation migration (generates RenameColumn MaxDuration -> MaxDuraction)
```
dotnet ef migrations add AlignRtsDataUserStatusMaxDuractionColumn ^
  --context BackendEmulationDbContext ^
  --project src/CcDashboard.Infrastructure ^
  --startup-project src/CcDashboard.Web
```
(BackendEmulation has no design-time factory -> resolved via --startup-project DI; host build only, no seeding.)

## 3. Verify the migration + model
- Open the new migration: Up() MUST contain `migrationBuilder.RenameColumn(name: "MaxDuration", ... table: "RTSData_UserStatus", newName: "MaxDuraction");` and Down() the reverse. If it DROPs/ADDs a column or is empty — STOP and report (model not picked up).
- Model-sync (E4-style) check, MUST be clean:
```
dotnet ef migrations has-pending-model-changes --context BackendEmulationDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web
```
Expect: no pending changes. If pending remain -> STOP and report.
- Build: `dotnet build CcDashboard.sln -c Debug` -> 0 errors.

## 4. Commit (web:, NO push) under commit.lock
Acquire .coord/locks/commit.lock (phantom-aware, owner backend-0609 — see sync_block S3). While holding:
```
bash tools/pre-commit-check.sh
git add src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs src/CcDashboard.Infrastructure/Migrations/BackendEmulation/
git commit -m "web: align EF RtsDataUserStatus.MaxDuration -> real column MaxDuraction (B-5 regen blocker; option 1, keep typo)"
git rev-parse HEAD
```
§0.6 post-commit verify -> `bash tools/cc_post_commit.sh backend-0609 $(git log -1 --format=%h)` -> sync -> §0.7 re-sync claimed files from HEAD.

## Binding RESULT -> .coord/cc/backend.md (status: done)
```
### RESULT (by CC): commit <hash>; HasColumnName("MaxDuraction") added to RtsDataUserStatus; migration AlignRtsDataUserStatusMaxDuractionColumn = RenameColumn MaxDuration->MaxDuraction; has-pending-model-changes CLEAN; build OK. NO push. verified: object-store.
```

## Report (chat) — NO push
commit hash; migration name + confirms RenameColumn (not drop/add); has-pending-model-changes clean; build 0 errors. NO push.
Next: unblocks B-5 schema.sql regen (a clean EF build now yields RTSData_UserStatus with only "MaxDuraction").
