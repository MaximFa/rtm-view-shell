# CC task — R0b: schema.sql carve (refined-C) + Export-All exclusion + rebuild runbook + TemplateCell fix
> Owner: dba (slug dba-0620). §4-PASS coordinator-0612 2026-06-21T05:40:48Z. db: commit. NO push (§37).
> Foundation of deploy-hardening (stream #1). Map ratified: .coord/r0_object_authority_map.md (38 carve / 26 keep).
> All gates met: backend B-confirm GREEN, shell EF-app confirm GREEN (Web.exe migrate covers App+Audit), §4 PASS, no freeze.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/role-dba/role-dba.md  (if present)
Read: .coord/r0_object_authority_map.md  (the carve/keep partition — source of truth)

## INIT / discipline
- §0.2 integrity; branch v2-backend; §0.5 verify ONLY via object-store (git cat-file/show/hash-object), NOT mount git status.
- §0.3 writes: Python + os.fsync ONLY (Edit BANNED); after write: sync + tail -3 + wc -l.
- §42.6 sync block: slug dba-0620; claims = ["db/**"]. Check .coord/push/request.md ABSENT before any commit (no freeze).
- §0.6b binding PREAMBLE -> .coord/cc/dba.md (status open). commit.lock around the commit. NO push.

## THE WORK (one db: commit)

### (A) Carve 38 app-tables OUT of db/schema.sql
Remove from schema.sql the CREATE TABLE + their indexes + their FK ALTER TABLEs for the 38 CARVE objects in the map:
- 23 public app tables (dashboard_categories, dashboard_permissions, dashboard_widgets, dashboards, history_metrics,
  info_slot_messages, info_slot_permissions, info_slots, menu_permissions, permission_groups, pg_business_units,
  pg_queues, pg_skills, pg_supergroups, sso_configurations, tenant_agent_state_definitions, tenant_agent_state_groups,
  tenant_agent_states, tenant_settings, tenants, user_widget_settings, widget_catalog, widget_templates)
- 11 identity.* tables  - 1 audit.audit_logs  - 3 EF-history (__ef_migrations_history x2 + __BackendEmulationMigrationsHistory)
KEEP (26): 24 RTM-family (NGC_*/RTSData_*/RTSGrid_*/RTSUserGrid_*) + db_patch_history + metric_deploy_log,
their indexes, and RTM->RTM FKs.
- **CREATE SCHEMA:** REMOVE `CREATE SCHEMA audit;` + `CREATE SCHEMA identity;` (EF owns them via EnsureSchema; Web.exe
  migrate runs FIRST in the runbook -> they exist before schema.sql). KEEP `CREATE SCHEMA public;` (or IF NOT EXISTS) +
  KEEP all CREATE EXTENSION (pgcrypto/pg_trgm/pg_stat_statements — DB-wide, needed by RTM).
- **FK SAFETY (verified, do not re-break):** there are ZERO cross-authority FKs — app FKs reference only app, RTM FKs
  reference only RTM (RTM-side FK referencing app = 0/35). So removing app tables + their FKs leaves NO dangling
  reference in the kept set. After carve, grep schema.sql: zero REFERENCES to any carved table.

### (B) Export-All.ps1 exclusion (db/tools/Export-All.ps1) — make the carve DURABLE
The pg_dump step (currently `--schema-only --no-owner --no-acl`, no filter) would RE-INTRODUCE app tables on next export.
Switch to a WHITELIST: dump only RTM authority -> `-t 'public."NGC_*"' -t 'public."RTSData_*"' -t 'public."RTSGrid_*"'
-t 'public."RTSUserGrid_*"' -t 'public.db_patch_history' -t 'public.metric_deploy_log'` (verify quoting works on the
target pg_dump). Equivalent acceptable: `-N identity -N audit` + `-T` each public app table + `-T '*MigrationsHistory*'`.
Whitelist (-t) preferred (fail-safe: new app tables never leak in). Apply same exclusion to Regen-Schema if present.

### (C) Rebuild runbook -> db/REBUILD_RUNBOOK.md (new)
Document fresh-rebuild order + ownership split:
1. Web.exe migrate -> App + Audit + identity EF contexts create app/identity/audit tables + audit/identity schemas +
   public.__ef_migrations_history + audit.__ef_migrations_history. (DatabaseInitializer L34 db.MigrateAsync + L35 auditDb.MigrateAsync — shell-confirmed.)
2. psql db/schema.sql -> RTM tables only (public) + extensions.
3. psql db/functions/01..04 -> functions.
4. seed (db/data/01..05).
BackendEmulation context is dev/test ONLY (ADR-007) -> NOT run on prod rebuild; its 24 RTM DbSets must stay subset of schema.sql (PD-008).
3 distinct __EFMigrationsHistory (audit. / public. / __BackendEmulation) — EF auto-creates per context, never in schema.sql.

### (D) FOLDED fix — NGC_GetCellsByDataGrid dead JOIN (db/functions/04_misc_functions.sql:115)
Drop the `LEFT JOIN "RTSGrid_TemplateCell" t ON o."CellTemplateId" = t."CellTemplateId"` (table dropped per §36.2,
not in schema.sql -> 42P01 on fresh rebuild when RTM calls the DataGrid path). Remove the JOIN + any t.* column refs
(per the header comment rows 9/10 map to TemplateCell.Tooltip/OnClick -> return NULL::text for those positions to keep
column index stable, OR confirm unused and drop fn). Keep function signature + return shape; keep PROCEDURE/FUNCTION kind as-is.

## ACCEPTANCE (object-store + functional)
- schema.sql: 26 CREATE TABLE remain (24 RTM + 2 DB-module); zero CREATE TABLE for any of the 38 carved; zero REFERENCES to carved tables; CREATE SCHEMA audit/identity removed, public kept; extensions kept.
- Export-All whitelist verified (dry inspection of the pg_dump arg line).
- FRESH REBUILD on a scratch DB (Create-FreshDb or Restore-All) completes end-to-end with ZERO errors (incl. NGC_GetCellsByDataGrid no 42P01).
- Compare-ToBaseline = B:0 (no schema delta) after rebuild.
  (If scratch-DB rebuild not runnable in this CC env: state so explicitly; coordinator/operator runs the rebuild proof on Windows — do NOT claim Delivered without it.)

## COMMIT (db:, under commit.lock, NO push)
`db: R0b carve app-tables out of schema.sql (refined-C, 38 carve/26 keep) + Export-All whitelist + REBUILD_RUNBOOK + drop dead NGC_GetCellsByDataGrid TemplateCell JOIN (42P01 on rebuild)`
then §0.6 post-commit verify + §0.7 re-sync + sync.

## REPORT -> binding cc/dba.md RESULT + inbox/coordinator.md (carve counts, rebuild-proof status, object-store verified). NO push.
