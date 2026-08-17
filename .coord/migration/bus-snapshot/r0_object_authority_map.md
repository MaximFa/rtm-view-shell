# CC-HARDEN-R0a — OBJECT->AUTHORITY MAP  (dba-0620, %s)
> Source of truth for the carve. Ground-truthed (NOT assumed):
>   EF-app authority = present in Migrations/App/AppDbContextModelSnapshot.cs .ToTable() list.
>   RTM-canonical = present in BackendEmulationDbContextModelSnapshot (dev) AND/OR DB-module only; KEEP in schema.sql.
> Branch v2-backend. 64 tables in db/schema.sql enumerated. STATUS: awaiting shell+backend confirm + coordinator §4.

## KEY ARCHITECTURAL CONFIRMATIONS (verified this pass)
- App EF context snapshot models ZERO RTM tables (NGC_/RTSData_/RTSGrid_/RTSUserGrid_) -> `Web.exe migrate` (App) does NOT create RTM tables on a fresh DB. The historical App migration 20260509092003_NgcQueueAgentGroupTables was superseded (tables now in BackendEmulation). => CARVE IS CONFLICT-FREE: after carve, RTM tables have exactly ONE creator on prod rebuild = psql schema.sql.
- BackendEmulation context models ALL 24 RTM tables = DEV emulation only; NOT run in prod rebuild. Prod authority for RTM = schema.sql. Consistent with refined-C.
- audit.audit_logs = Audit EF context (separate). Carve-set. Rebuild MUST run Audit-context migrate too (confirm Web.exe migrate covers App+Audit).

## A. CARVE OUT of schema.sql  (EF-app authority — 38)
### A1. App context (AppDbContextModelSnapshot) — 23 public:
dashboard_categories, dashboard_permissions, dashboard_widgets, dashboards, history_metrics,
info_slot_messages, info_slot_permissions, info_slots, menu_permissions, permission_groups,
pg_business_units, pg_queues, pg_skills, pg_supergroups, sso_configurations,
tenant_agent_state_definitions, tenant_agent_state_groups, tenant_agent_states, tenant_settings,
tenants, user_widget_settings, widget_catalog, widget_templates
   - history_metrics: CONFIRMED App-authority (in App snapshot) -> carve. (Also has a db/migration 20260606_005 + schema.sql copy = the exact drift this carve kills.)
### A2. identity.* (App context) — 11:
identity.refresh_tokens, identity.role_claims, identity.roles, identity.two_factor_codes,
identity.user_claims, identity.user_logins, identity.user_password_history, identity.user_roles,
identity.user_sessions, identity.user_tokens, identity.users
### A3. Audit context — 1:
audit.audit_logs
### A4. EF migration-history infra (auto-created by EF per context — must NOT be in schema.sql) — 3:
audit.__ef_migrations_history, public.__ef_migrations_history, public.__BackendEmulationMigrationsHistory
### A5. PROSPECTIVE (CC-HIST-001, EF-app — never let Export-All introduce into schema.sql):
hist_queue_intervals, hist_agent_intervals, user_reports

## B. KEEP in schema.sql  (RTM-canonical authority — 26)
### NGC_ (9): NGC_AgentGroups, NGC_BusinessUnit, NGC_BusinessUnitQueueClassification,
NGC_BusinessUnitSupergroup, NGC_Queues, NGC_Site, NGC_Supergroup, NGC_SupergroupAgentgroup, NGC_UserAgentgroup
### RTSData_ (4): RTSData_ChatMessage, RTSData_Interaction, RTSData_UserStatus, RTSData_UserStatusLog
### RTSGrid_ (8): RTSGrid_Cell, RTSGrid_Column, RTSGrid_Grid, RTSGrid_Metric, RTSGrid_MetricTranslation,
RTSGrid_Row, RTSGrid_Statistic, RTSGrid_UserStatus
### RTSUserGrid_ (3): RTSUserGrid_Column, RTSUserGrid_ColumnsSet, RTSUserGrid_Grid
### DB-module (2): db_patch_history, metric_deploy_log
   - metric_deploy_log: CONFIRMED NOT EF-modeled (absent from App + BackendEmulation snapshots); managed by db/migrations + db/data + Export-All -> KEEP (DB-module authority).
   - RTSGrid_MetricTranslation: BackendEmulation-modeled, RTSGrid family -> KEEP.

## TALLY: 38 carve + 26 keep = 64 (matches schema.sql CREATE TABLE count). 

## CONFIRM REQUESTS
- role-shell: confirm A1+A2 (+A3 Audit, +A5 prospective) is the COMPLETE & correct EF-app set (you own the App/Audit EF model). Flag any app table I keep, or any keep-table you think App creates.
- role-backend: confirm B (RTM-canonical) is complete & correct (you own RTM tables). Confirm metric_deploy_log + db_patch_history stay DB-module/schema.sql.
- coordinator §4: ratify the map. R0b CARVE HELD until both confirms + §4 PASS + push-freeze lifts.
