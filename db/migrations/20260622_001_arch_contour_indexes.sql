-- ============================================================================
-- operator-approved contour index 2026-06-22 - read-perf for reporting archiver watermark scan
-- NO column/behaviour change to RTSData_*. Index-only.
--
-- NOTE: CREATE INDEX CONCURRENTLY cannot run inside a transaction. If using psql:
--       Run this file with autocommit (psql -f ..., not in a BEGIN block).
--
-- Backend-0620 APPROVE (21:35): shape (TenantId,UpdateTime) optimal for archiver WHERE clause.
-- F1 autovacuum: RTSData_Interaction UPSERTED + UpdateTime MUTATES -> tuple churn; set scale_factor=0.05.
-- F2 invalid-index: CONCURRENTLY interrupted leaves INVALID index; verify indisvalid post-apply.
-- ============================================================================

-- RTSData_Interaction: watermark scan index for archiver
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_rtsdata_interaction_tenant_updatetime
    ON "RTSData_Interaction" ("TenantId", "UpdateTime");

-- RTSData_UserStatusLog: watermark scan index for archiver
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_rtsdata_userstatuslog_tenant_updatetime
    ON "RTSData_UserStatusLog" ("TenantId", "UpdateTime");

-- F1: Aggressive autovacuum for RTSData_Interaction (UPSERT + UpdateTime mutation -> non-HOT churn)
-- MidnightClear is dead (Engine.cs:957) -> table grows unbounded; keep bloat in check.
ALTER TABLE "RTSData_Interaction" SET (autovacuum_vacuum_scale_factor = 0.05);

-- F2: Post-apply VERIFY (run manually or in deploy script):
-- SELECT indexrelid::regclass, indisvalid FROM pg_index
-- WHERE indexrelid IN ('ix_rtsdata_interaction_tenant_updatetime'::regclass,
--                      'ix_rtsdata_userstatuslog_tenant_updatetime'::regclass);
-- If indisvalid = false: DROP INDEX <name>; then rebuild CONCURRENTLY.
-- DO NOT rely on IF NOT EXISTS alone (skips invalid indexes).

-- §38a self-record
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260622_001_arch_contour_indexes') ON CONFLICT (migration_name) DO NOTHING;
