# Server 234 / PG18 — Release acceptance verification checklist

> Prepared by test-5-0607 (QA) ahead of the Full PG18 build for server 234. Run AFTER install,
> with the app + DB + RTM service running. NO code commits from QA — findings -> coordinator ->
> fix window routed to the owning session. Acceptance gates per coordinator-0608: B=0, RTM log clean
> (no 42809/42883/42703), DayTrend renders, ledger updated.

## 0. Pre-flight
- [ ] Package = Full **PG18** build; record zip name + the git HEAD it was cut from (== origin/v2).
- [ ] server 234 is **PG18** (`SELECT version();`), not PG17 (that was server 45 / RELEASE-1).
- [ ] Upgrade orchestrator ran clean (probe gate -> stop -> backup -> migrations -> functions -> start -> verify); no rollback.

## 1. DB integrity
- [ ] **Ledger updated**: `SELECT migration_name FROM public.db_patch_history ORDER BY 1;` == db/migrations/ set (every migration self-recorded, §38a).
- [ ] **All 14 RTM-write routines = PROCEDURE** (prokind='p'), not FUNCTION (RTM-SEC-002): 12 NGC_* (file01) + RTSData_SetInteraction/SetChatMessage/SetUserStatus (file02).
- [ ] Compare-ToBaseline: no unexpected drift; repo == server234 (advisory align.sql reviewed for direction, §38.5).
- [ ] Extensions: pgcrypto, pg_trgm, pg_stat_statements. Seed NGC_Site SiteId='IL' present (RTM default, §29.8).

## 2. RTM service runtime (log clean)
- [ ] RTM starts; startup log shows `AppConfig.TenantId = <uuid>` (§33.6); TenantId not Guid.Empty.
- [ ] RTM log CLEAN — ZERO of: **42809** (wrong object type — CALL on FUNCTION, RTM-SEC-002), **42883** (undefined function — signature/deploy mismatch, RTM-DEPLOY-001), **42703** (undefined column).
- [ ] Live data flowing: RTSData_Interaction / RTSData_UserStatus written for the tenant; NGC_BusinessUnit count > 0 for tenant.
- [ ] MidnightClear is tenant-scoped (no cross-tenant wipe, §33.5).

## 3. Widget / data-flow acceptance
- [ ] **B=0** — Compare-ToBaseline dimension B (routine-kind)=0 mismatches: EVERY RTM-CALLed write routine (NGC_* writes + RTSData_Set*) is PROCEDURE (prokind='p'), ZERO FUNCTION where a CALL occurs (RTM-SEC-002, prevents runtime 42809). Pre-deploy 234 had B=1 (RTSData_SetChatMessage=FUNCTION); functions/02 re-apply in the pkg makes B=0. GATE: post-deploy Compare shows B=0.
- [ ] QueueGrid renders data (RTSGrid_GetDataCells > 0; ClassificationId='ALL'; updateGridData flowing, §36).
- [ ] AgentGrid renders (union u<id> subscribe; agents appear).
- [ ] **DayTrend RENDERS** — BU-scoped via NGC_UserAgentgroup (74db217); UNAVAILABLE colours correct; chart-type selector works.

## 4. Frontend / i18n / dark-mode (test-5 domain — verifies 536415b, 3e82ae3, 60c01df)
- [ ] Dark-mode toggle: configurator modal + MetricWizard render charcoal (#1E1E1E/#2D2D2D, text #E4E4E7, primary #0066CC, selected #1A3A5C) — incl. ALL input/select/textarea fields (60c01df). NO slate.
- [ ] Light-mode: fields stay white (rule scoped to .dark-mode only).
- [ ] Star Color / row Colors palette stays COLOURED in dark (not darkened).
- [ ] RTL he-IL: grid + config modal + wizard not broken (CSS logical properties).
- [ ] `Widget_DayTrend_ChartType` renders "Chart type" (not the raw key) in en/ru/he (3e82ae3).
- [ ] Configurator chrome localized ru/he (WidgetCfg_*); metric button shows localized DisplayName.

## 5. Sign-off
- [ ] All PASS -> report GREEN to coordinator. Any FAIL -> list findings (no QA commit); fix routed to owning session in a post-acceptance window.
