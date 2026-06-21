-- ============================================================================
-- operator-approved contour index 2026-06-22 - read-perf for reporting archiver watermark scan
-- NO column/behaviour change to RTSData_*. Index-only.
--
-- NOTE: CREATE INDEX CONCURRENTLY cannot run inside a transaction. If using psql:
--       Run this file with autocommit (psql -f ..., not in a BEGIN block).
-- ============================================================================

-- RTSData_Interaction: watermark scan index for archiver
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_rtsdata_interaction_tenant_updatetime
    ON "RTSData_Interaction" ("TenantId", "UpdateTime");

-- RTSData_UserStatusLog: watermark scan index for archiver
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_rtsdata_userstatuslog_tenant_updatetime
    ON "RTSData_UserStatusLog" ("TenantId", "UpdateTime");

-- §38a self-record
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260622_001_arch_contour_indexes') ON CONFLICT (migration_name) DO NOTHING;
