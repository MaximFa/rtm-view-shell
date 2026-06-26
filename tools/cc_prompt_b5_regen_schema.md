# CC task — B-5: regenerate db/schema.sql from EF+RTM sources (generated-only) + db/tools/Regen-Schema.ps1
> §4-DRAFTED by coordinator-0612 2026-06-14T07:30Z. Owner: dba-0610. Executor: native CC, Windows, PG18 (C:\Program Files\PostgreSQL\18), dotnet ef available.
> Claims: db/schema.sql + db/tools/Regen-Schema.ps1 (new). Commit prefix `db:`. **NO push** (rides next barrier).
> Decision: A+E4 hybrid — schema.sql becomes GENERATED-ONLY, regenerated from sources, never hand-edited. Blocker R1 DONE (c1f66af: EF maps MaxDuraction).

## Why
Current db/schema.sql is a STALE pg_dump: it carries 9 dead tables (8 PascalCase app-model: Users, PermissionGroups, Screens,
AuditEvents, ResourcePermissions, ScreenPermissions, UserGroups, WidgetSlots — superseded by EF identity.*/snake_case; + RTSGrid_TemplateCell
dropped by EF). This inflates Compare Dimension [A] by ~237-454 false lines and caused the 45 drift saga (PD-008). Fix: rebuild a clean
reference DB purely from the CURRENT sources (EF migrations @HEAD incl R1 + SQL functions + db/migrations), pg_dump it, and commit that as
db/schema.sql with a provenance header. A clean rebuild then reproduces the full schema; [A] collapses to ~0; the drift-class can't recur.

## Mandatory — read before starting (§40)
Read: .claude/skills/widget-planner/widget-planner.md ; .claude/skills/widget-creator/widget-creator.md ; .claude/skills/session-coord/session-coord.md
Only after reading all: proceed.

## §0.6a integrity + binding PREAMBLE
- §0.2: git status; branch==v2-backend; hash-verify db/schema.sql vs HEAD (object-store, not mount line-count); HEAD should be c1f66af or later.
- Binding PREAMBLE -> append .coord/cc/dba.md (Python+os.fsync):
```
## 2026-06-14T07:30Z | binding: dba <-> CC | directive: tools/cc_prompt_b5_regen_schema.md | status: open
### DIRECTIVE: regen db/schema.sql from EF+RTM sources via new db/tools/Regen-Schema.ps1; drop 9 phantoms; provenance header; verify [A]~0. Claims: db/schema.sql + db/tools/Regen-Schema.ps1. db:. NO push.
```

## S1. Push barrier check
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo "BARRIER ACTIVE"; cat .coord/push/request.md; exit 1; fi
```
## S2. Claim check
```bash
python3 tools/coord_check_claims.py dba-0610 db/schema.sql db/tools/Regen-Schema.ps1
```
Touch ONLY the two claimed paths (+ a scratch DB `rtmviewdb_regen`, dropped at end).

## 1. Author db/tools/Regen-Schema.ps1 — the generated-only regen procedure
Params: -DBHost localhost -DBPort 5432 -SuperUser postgres -SuperPassword <req> -AppUser ccdashboard_user -AppPassword <req> -ScratchDb rtmviewdb_regen -KeepScratch(switch).
The script MUST, in order (use the Find-PGTool helper pattern from db/tools/Create-FreshDb.ps1):

  1.1 Drop+create scratch DB (super): dropdb --if-exists rtmviewdb_regen ; createdb -E UTF8 rtmviewdb_regen
  1.2 Apply db/setup/01_init_db.sql as $SuperUser (extensions, ccdashboard_user, grants).
  1.3 EF migrate each context FROM SOURCE @HEAD via explicit --connection (picks up R1; do NOT use a prebuilt ShellExe). cwd-independent:
      $conn = "Host=localhost;Port=5432;Database=rtmviewdb_regen;Username=ccdashboard_user;Password=$AppPassword;SSL Mode=Prefer"
      dotnet ef database update --context AppDbContext            --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web --connection "$conn"
      dotnet ef database update --context AuditDbContext          --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web --connection "$conn"
      dotnet ef database update --context BackendEmulationDbContext --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web --connection "$conn"
      (BackendEmulation has no design-time factory -> resolved via --startup-project DI; --connection overrides at runtime.)
      ABORT the script if any ef update exits non-zero.
  1.4 Apply SQL functions as $AppUser, in order: db/functions/01_ngc_functions.sql, 02_rtsdata_functions.sql, 03_rtsgrid_read.sql, 04_misc_functions.sql
      (schema.sql is a FULL --schema-only dump and DOES include CREATE FUNCTION — they must be present).
  1.5 Apply ALL db/migrations/*.sql as $AppUser in ASCENDING filename order (all are idempotent: IF NOT EXISTS / to_regclass guards / ON CONFLICT).
      This reaches the canonical post-deploy state (columns from _011, constraint _013, indexes/reconcile _014, function overloads _015, etc.).
  1.6 pg_dump (match Compare exactly):
      pg_dump -h $DBHost -p $DBPort -U $AppUser -d rtmviewdb_regen --schema-only --no-owner --no-acl --schema=public --schema=identity --schema=audit  -> raw dump (UTF-8).
  1.7 Post-process the dump text:
      - REMOVE the two non-deterministic lines that start with `\restrict ` and `\unrestrict ` (PG18 emits a random token each dump; they survive Compare's Normalize -> would be perpetual false [A]).
      - PREPEND a provenance header (every line starts with `--` so Compare Normalize drops them -> zero [A] impact):
        ```
        -- ============================================================================
        -- GENERATED — do not hand-edit. Regenerate via db/tools/Regen-Schema.ps1
        -- Sources: EF AppDbContext + AuditDbContext + BackendEmulationDbContext @ <git short-sha>
        --          + db/functions/*.sql + db/migrations/*.sql (all applied)
        -- Generated: <yyyy-MM-ddTHH:mmZ> | git: <full-sha>
        -- ============================================================================
        ```
      - Write db/schema.sql as CRLF + UTF-8 NO BOM (match current file + Export-All.ps1:44-48 idiom: [System.IO.File]::WriteAllText(path, ($lines -join "`r`n"), [System.Text.UTF8Encoding]::new($false)) ).
  1.8 Unless -KeepScratch: dropdb rtmviewdb_regen at the end.

## 2. Run it
```
powershell -ExecutionPolicy Bypass -File db\tools\Regen-Schema.ps1 -SuperPassword "<pg>" -AppPassword "!@#qweASDzxc" -KeepScratch
```
(Keep the scratch DB for the Step-4 Compare proof; drop it after.)

## 3. Verification GATES — if ANY fails, DO NOT COMMIT (report)
Against rtmviewdb_regen:
```sql
SELECT 'identity' k,count(*) FROM information_schema.tables WHERE table_schema='identity'      -- expect 11
UNION ALL SELECT 'audit', count(*) FROM information_schema.tables WHERE table_schema='audit'    -- expect 1
UNION ALL SELECT 'rtm',   count(*) FROM information_schema.tables WHERE table_schema='public'
   AND (table_name LIKE 'NGC\_%' OR table_name LIKE 'RTSGrid\_%' OR table_name LIKE 'RTSData\_%' OR table_name LIKE 'RTSUserGrid\_%')  -- expect 24
UNION ALL SELECT 'phantoms',count(*) FROM information_schema.tables WHERE table_schema='public'
   AND table_name IN ('Users','PermissionGroups','Screens','AuditEvents','ResourcePermissions','ScreenPermissions','UserGroups','WidgetSlots','RTSGrid_TemplateCell');  -- MUST be 0
```
Grep guards on the produced db/schema.sql:
- `grep -c 'CREATE TABLE public\."RTSGrid_TemplateCell"' db/schema.sql`  == 0
- `grep -c '"Users"\|"PermissionGroups"\|"Screens"\|"AuditEvents"' db/schema.sql` == 0 (no phantom CREATE TABLE)
- RTSData_UserStatus carries "MaxDuraction" and NOT a separate "MaxDuration" column (R1 proof): inspect the CREATE TABLE block.
- `grep -c 'CustomCallData20' db/schema.sql` >= 1 (the _011 columns landed).
- identity.* CREATE TABLE present; `\restrict` lines absent; provenance header present.

## 4. Compare proof — Dimension [A] must collapse
```
powershell -ExecutionPolicy Bypass -File db\tools\Compare-ToBaseline.ps1 -Password "!@#qweASDzxc" -DBName rtmviewdb_regen   # (use the script's real param names)
```
Expect Dimension A ~0 (a handful of cosmetic lines max). Report the A/B/C/D summary. If [A] is still large -> the regen is wrong: DO NOT COMMIT, report the residual objects. Then dropdb rtmviewdb_regen.

## 5. Commit (db:, NO push) under commit.lock
Acquire .coord/locks/commit.lock (owner dba-0610). While holding:
```
bash tools/pre-commit-check.sh
git add db/schema.sql db/tools/Regen-Schema.ps1
git commit -m "db: regen schema.sql generated-only from EF@HEAD+functions+migrations (drop 9 phantom tables; provenance; PD-008 P4/E4); add Regen-Schema.ps1"
git rev-parse HEAD
```
§0.6 post-commit verify (working tree == HEAD) -> bash tools/cc_post_commit.sh dba-0610 $(git log -1 --format=%h) -> sync -> §0.7 re-sync db/schema.sql + db/tools/Regen-Schema.ps1 from HEAD.

## Binding RESULT -> .coord/cc/dba.md (status: done)
```
### RESULT (by CC): commit <hash>; schema.sql regen lines <n> (was 4159); phantoms=0 (verified 9 absent); identity=11/audit=1/rtm=24; RTSData_UserStatus=MaxDuraction only; Compare [A]=<n> (was ~454); Regen-Schema.ps1 added. NO push. verified: object-store + Compare.
```

## Report (chat) — NO push
new schema.sql line count; phantom-table count (must be 0); Compare A/B/C/D summary ([A] before ~454 -> after); Regen-Schema.ps1 created; commit hash. NO push.

## Residual-risk note for dba (adjust if needed before running)
- If `dotnet ef ... --connection` does NOT override appsettings, set $env:ConnectionStrings__Default instead, or pass via the design-time factory.
- If applying ALL db/migrations causes an error on the empty scratch DB (a data/function migration with an unexpected dependency), narrow to the schema-affecting set (_011, _013, _014) + report which migration failed.
- Confirm the 24/11 target counts against the live 45 DB if in doubt (45 is GREEN/canonical).
