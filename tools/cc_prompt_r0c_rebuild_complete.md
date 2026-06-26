# CC task — R0c: complete the carve (db/data + schema fixes + rebuild tooling) so fresh rebuild is clean

> Owner: dba (slug dba-0620). §4-APPROVED scope: coordinator-0612 2026-06-21T08:43:04Z. db: commit. NO push (§37).
> §4-PASS by coordinator-0612 (2026-06-21T09:25:25Z) — all 4 parts pin-verified object-store: (a) 01_system=8 app-COPY (delete) + 04_catalog widget_catalog(carve)/NGC_Site(keep); (b) schema.sql:35 bare CREATE SCHEMA public; (c) CONFIRMED — RTSData_Interaction table def has CustomCallData1..18 (line 1369 last) while fn refs 19/20 -> 42703 (the '20' at schema.sql:560/619-620 are FUNCTION-body refs, NOT table cols); add 19/20 text nullable at table end; (d) Restore-All 53/109/151 Set-Content -Encoding UTF8 + no PGCLIENTENCODING/migrate, Rebuild-Proof.ps1 absent. EXECUTE authorized: native CC, db: commit, commit.lock, NO push.
> Follow-up to R0b (84f087c): static schema.sql carve was GREEN but the FUNCTIONAL rebuild proof FAILED —
> the carve was schema-only and did not mirror to the SEED side or the tooling. Barrier #3 stays HELD until
> this lands + the rebuild proof is re-run to Compare B:0.
> SCOPE = data layer + tooling ONLY. READ-ONLY on the RTM external contour at runtime (no RTSData_*/NGC_* data mutation).

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/role-dba/role-dba.md (§A core + §C VERIFY)
Read: .coord/r0_object_authority_map.md (the carve/keep partition — 38 carve / 26 keep)
Read: db/REBUILD_RUNBOOK.md (the authoritative post-carve rebuild order)

## INIT / discipline
- §0.2 integrity; branch v2-backend; §0.5 verify ONLY via object-store (git cat-file/show/hash-object), NOT mount git status.
- §0.3 writes: Python + os.fsync ONLY (Edit BANNED); after write: sync + tail -3 + wc -l.
- §42.6 sync block: slug dba-0620; claims = ["db/data/**", "db/schema.sql", "db/tools/Restore-All.ps1", "db/tools/Rebuild-Proof.ps1"].
  Check .coord/push/request.md before any commit. commit.lock around the commit. NO push.
- §0.6b binding PREAMBLE -> .coord/cc/dba.md (status open).

---

## THE WORK (one db: commit) — 4 ratified parts

### (a) Carve db/data to RTM-ONLY  [root cause #1 of the proof failure]
The proof failed because db/data still seeds CARVED app tables (relation does not exist when psql'd; post-carve
those tables are created+seeded by EF / DatabaseInitializer during `Web.exe migrate`, NOT by psql).
Object-store confirmed COPY targets:
- `db/data/01_system.sql` = 100% app (8 COPY blocks: tenants, tenant_settings, identity."roles", identity."users",
  identity."user_roles", "__EFMigrationsHistory", "__BackendEmulationMigrationsHistory", "__ef_migrations_history").
  => **DELETE db/data/01_system.sql entirely.** All of it is EF/DatabaseInitializer-seeded on migrate (platform tenant +
  superadmin + roles per CLAUDE.md §26 DATA-07; EF migration-history is EF-managed).
- `db/data/04_catalog.sql` = `COPY "widget_catalog"` (CARVE — DatabaseInitializer seeds the widget catalogue, §26 DATA-07
  item 5 / SeedSampleCcEntitiesAsync §29.8) + `COPY "NGC_Site"` (KEEP — RTM).
  => **Remove the entire `COPY "widget_catalog" FROM stdin; ... \.` block; KEEP the `COPY "NGC_Site"` block.**
- KEEP unchanged: db/data/02_metrics.sql (RTSGrid_Metric), 03_rtsgrid.sql (RTSGrid_*/RTSUserGrid_*), 05_metric_translations.sql.
- Verify no tool hard-references `01_system.sql` by name. Restore-All / Create-FreshDb iterate db/data/*.sql by glob
  (sorted) so file removal is safe — but grep the repo to confirm no hardcoded `01_system.sql` path; if any, fix it.

### (b) schema.sql — CREATE SCHEMA IF NOT EXISTS  [root cause #2]
schema.sql line ~35 has bare `CREATE SCHEMA public;` -> errors "schema public already exists" on every DB.
=> change to `CREATE SCHEMA IF NOT EXISTS public;`. (Do NOT touch CREATE EXTENSION — none present, correct.)

### (c) schema.sql RTSData_Interaction — add CustomCallData19/20  [root cause #3 — backend CANON-CONFIRMED]
BACKEND-0620 CANON-CONFIRM (2026-06-21T09:18, object-store pinned): canonical = **CustomCallData1..20, type text, NULLABLE**.
SOURCE: db/migrations/20260613_011_45_table_drift_addcolumns.sql (commit 4c9c762, ADD CustomCallData1..20 text); fn
02_rtsdata_functions.sql refs 1..20 (RTSData_SetInteraction writes all 20, RTSData_GetInteractions selects all 20);
RTM C# IDInteraction.cs = 20 props, reads/writes POSITIONALLY -> all 20 MUST exist (stripping is NOT an option, _011 saga).
DRIFT: schema.sql RTSData_Interaction currently carries only CustomCallData1..18 -> fn:335 (CustomCallData19) = 42703 on rebuild.
=> ADD `"CustomCallData19" text,` `"CustomCallData20" text` (both nullable) AT THE TABLE END (positional-safe for RTM's
explicit SELECT/INSERT readers), mirroring the existing 15..18 `text` columns.
NOTE: schema.sql BASELINE alignment only (PD-008: _011 patched deployed servers, schema.sql never caught up) — servers that
ran _011 need NO new migration; this is a schema.sql edit. NO LONGER HELD — backend canon-confirmed, execute as part of R0c.

### (d) Rebuild tooling — make the proof one-command  [root cause #4]
db/tools/Restore-All.ps1 defects (object-store pinned):
- Lines 53, 109, 151: `Set-Content -Path $TmpSql -Value ... -Encoding UTF8` — Windows PowerShell 5.1 `-Encoding UTF8`
  writes a **BOM**, causing psql `syntax error at or near "<BOM>DO"` (ownership-transfer, E3 setval, grants all failed).
  => replace all 3 with a BOM-less UTF-8 write:
  `[System.IO.File]::WriteAllText($TmpSql, $sql, (New-Object System.Text.UTF8Encoding($false)))`  (PS 5.1-safe).
- No client encoding set: WIN1252 console -> UTF-8 db/data seeds fail ("byte sequence 0x9d/0x90 has no equivalent").
  => set `$env:PGCLIENTENCODING = "UTF8"` near the top of Restore-All.ps1 (and any rebuild/proof script).
- Restore-All has NO `Web.exe migrate` step -> app/identity/audit/hist_* tables never created.
  => Provide a one-command combined rebuild that follows db/REBUILD_RUNBOOK.md order. PREFERRED: create
  **db/tools/Rebuild-Proof.ps1** (params: DBHost/Port/Database/SuperUser/SuperPassword/AppUser/AppPassword/ShellExe/
  -KeepDb): dropdb+createdb throwaway DB -> 01_init_db (ext+user+grants) -> `Web.exe migrate` (App+Audit, via
  `$env:ConnectionStrings__Default` override) -> psql schema.sql -> psql functions/01..04 -> psql db/data/*.sql
  (RTM-only after (a)) -> Compare-ToBaseline -> drop unless -KeepDb. Set PGCLIENTENCODING=UTF8; UTF-8 no-BOM temp files.
  (Acceptable alternative: add a `-WithMigrate -ShellExe` switch to Restore-All; RTM-then-migrate order is safe post-fix
  — disjoint sets, db_patch_history INSERT already removed in 11622f0. But a dedicated Rebuild-Proof.ps1 matching the
  RUNBOOK migrate-first order is cleaner.)

---

## ACCEPTANCE (object-store + functional)
- db/data: grep shows NO app-table COPY anywhere (no tenants / tenant_settings / identity. / widget_catalog /
  *MigrationsHistory); 01_system.sql removed; 04_catalog.sql has NGC_Site only; 02/03/05 intact.
- schema.sql: `CREATE SCHEMA IF NOT EXISTS public;` (no bare form); after (c)+backend-sign, CustomCallData1..20 present
  and fn 02 resolves (no 42703).
- Restore-All.ps1: all temp .sql written UTF-8 NO-BOM; PGCLIENTENCODING=UTF8 set; no `Set-Content -Encoding UTF8`.
- One-command combined proof (Rebuild-Proof.ps1) runs end-to-end on a SCRATCH DB with ZERO errors
  (no 42P01 db_patch_history, no 42P01/42703 in functions, no encoding/BOM errors) + **Compare-ToBaseline = B:0**.
  (Windows/.NET step -> operator runs; if not runnable in CC env, state so, hand the operator the exact command,
  do NOT claim Delivered without the B:0 result.)

## COMMIT (db:, under commit.lock, NO push)
`db: R0c complete the carve — db/data RTM-only (drop 01_system + widget_catalog), CREATE SCHEMA IF NOT EXISTS, +CustomCallData19/20 (backend-confirmed), Restore-All BOM/encoding fix + Rebuild-Proof.ps1`
then §0.6 post-commit verify + §0.7 re-sync + sync.

## CAPTURE (NORM-CUR-11 — MANDATORY before close): append to .claude/skills/role-dba/role-dba.md §B:
`2026-06-21 · A schema.sql carve is INCOMPLETE unless mirrored across db/data seeds AND rebuild tooling — static schema verify (table count, FK) passed GREEN while the FUNCTIONAL rebuild FAILED because db/data still seeded carved tables (tenants/identity/widget_catalog) + Restore-All wrote BOM temp files + WIN1252 client. Rule: a carve = schema + seed + tooling; always run the functional rebuild proof, never trust static verify alone. · SOURCE: R0b proof FAIL 2026-06-21, R0c fix · status: active`

## REPORT -> binding cc/dba.md RESULT + inbox/coordinator.md (parts done, (c) backend-sign status, proof result, object-store verified). NO push.
