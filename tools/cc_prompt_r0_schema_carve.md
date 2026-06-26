# CC-HARDEN-R0 — schema.sql carve (refined-C: authority by OBJECT)  [#1 deploy-hardening ROOT]
> Owner exec: role-dba (dba-0620). Confirmers: role-shell (app set) + role-backend (RTM set). §4: coordinator.
> Decision (operator, refined-C): app/identity/dashboard tables -> EF model = source of truth; RTM/NGC/RTSData/RTSGrid (+functions) -> schema.sql = source of truth. CARVE app tables OUT of schema.sql. Rebuild = Web.exe migrate (app) + psql schema.sql (RTM) + psql db/functions -> full DB, no conflict. Kills rebuild-drift class + removes Compare Dim-A app-phantom noise.
> STATUS: §4-review DRAFT — the CARVE step waits on the confirmed object->authority MAP (Shell+backend) + coordinator §4.

## STEP 0 — integrity (§0.6a) + §40 skills (session-coord, role-dba §A/§C). Branch v2-backend. §0.5 object-store.
## Sync (§42.6): slug=dba-0620; claims = db/schema.sql, db/tools/Export-All.ps1, db/tools/Regen-Schema.ps1 (+Compare if touched). Binding PREAMBLE -> .coord/cc/dba.md. commit.lock around commit. NO push (§37). §0.3 Python+fsync for .coord.

## R0a — OBJECT->AUTHORITY MAP (first; the carve depends on it)
1. Enumerate EVERY table in db/schema.sql (and the live DB). Tag each: **EF-app** (authority=EF model) vs **RTM-canonical** (authority=schema.sql).
   - EF-app set (carve OUT of schema.sql): app/identity/dashboard tables — tenants, tenant_settings, permission_groups, menu/dashboard/cc-resource permission tables, dashboards, dashboard_widgets, widget_catalog, sso_configurations, tenant_agent_state*, identity.* (users/roles/refresh_tokens/two_factor_codes/user_password_history/user_tokens), audit.audit_logs, AND the NEW **hist_queue_intervals / hist_agent_intervals / user_reports** (BI, EF-created by CC-HIST-001). + the PascalCase phantom app tables (AuditEvents/Users/Screens/PermissionGroups/...) — these are the Dim-A noise.
   - RTM-canonical set (KEEP in schema.sql): RTSData_* (Interaction/UserStatus/UserStatusLog/ChatMessage), RTSGrid_* (Metric/Grid/Row/Cell/Column/Statistic/UserStatus), RTSUserGrid_*, NGC_* (Queues/AgentGroups/BusinessUnit/Supergroup/SupergroupAgentgroup/BusinessUnitQueueClassification/BusinessUnitSupergroup/UserAgentgroup/Site), db_patch_history, + the RTM-side sequences/indexes/constraints.
2. Produce the MAP as a table (object | authority | action keep/carve) -> route to:
   - role-shell (inbox/shell.md): confirm the EF-app set is complete/correct (it owns the EF model).
   - role-backend (inbox/backend.md): confirm the RTM-canonical set is complete/correct (it owns the RTM tables).
   - coordinator §4: ratify the map.
   HOLD the carve until Shell+backend confirm + coordinator §4 PASS.

## R0b — CARVE (after map confirmed)
3. Regenerate db/schema.sql with ALL EF-app tables REMOVED -> schema.sql = RTM-canonical objects + RTM functions ONLY.
4. Update db/tools/Export-All.ps1 + Regen-Schema.ps1: schema.sql export EXCLUDES the EF-app set (so future Export-All never re-introduces app tables; hist_*/user_reports never leak in). Documented exclusion list = the EF-app set.
5. Rebuild runbook (docs or db/tools README): clean rebuild = (a) CcDashboard.Web.exe migrate [EF app+hist_*+user_reports] -> (b) psql db/schema.sql [RTM] -> (c) psql db/functions/* -> (d) seed. No object created twice.
6. Self-record if a migration is involved; otherwise schema.sql regen is a db: commit.

## ACCEPTANCE
- Clean rebuild (migrate + schema.sql + functions) reproduces the live RTM DB with NO conflict (no "already exists" on the app/RTM boundary).
- Compare-ToBaseline on a fresh rebuild: Dim-A app-phantom noise GONE (schema.sql no longer models app tables); remaining A = real RTM drift only (should be ~0 on a clean build).
- schema.sql contains ZERO app/identity/dashboard/hist_*/user_reports tables; contains ALL RTM-canonical tables+functions.
- Object-store verified commit (db: prefix), NO push.

## STEP final — binding POSTAMBLE RESULT -> .coord/cc/dba.md ; CAPTURE lesson if any ; commit-lock release + §0.7 re-sync. NO push.
