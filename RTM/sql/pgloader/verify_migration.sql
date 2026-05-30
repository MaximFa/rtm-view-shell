-- ============================================================================
-- Migration Verification Queries for RTM Backend
-- Output of RTM-M7 task
--
-- Run after pgloader completes to verify data integrity.
-- Compare row counts with SQL Server source before signing off.
-- ============================================================================

-- ============================================================================
-- 1. Row counts for all migrated tables
-- ============================================================================
\echo '=== TABLE ROW COUNTS ==='

SELECT 'NGC_Site' AS table_name, COUNT(*) AS row_count FROM "NGC_Site"
UNION ALL SELECT 'NGC_BusinessUnit', COUNT(*) FROM "NGC_BusinessUnit"
UNION ALL SELECT 'NGC_Supergroup', COUNT(*) FROM "NGC_Supergroup"
UNION ALL SELECT 'NGC_BusinessUnitQueueClassification', COUNT(*) FROM "NGC_BusinessUnitQueueClassification"
UNION ALL SELECT 'NGC_BusinessUnitSupergroup', COUNT(*) FROM "NGC_BusinessUnitSupergroup"
UNION ALL SELECT 'NGC_SupergroupAgentgroup', COUNT(*) FROM "NGC_SupergroupAgentgroup"
UNION ALL SELECT 'RTSGrid_Metric', COUNT(*) FROM "RTSGrid_Metric"
UNION ALL SELECT 'RTSGrid_Grid', COUNT(*) FROM "RTSGrid_Grid"
UNION ALL SELECT 'RTSGrid_Column', COUNT(*) FROM "RTSGrid_Column"
UNION ALL SELECT 'RTSGrid_Row', COUNT(*) FROM "RTSGrid_Row"
UNION ALL SELECT 'RTSGrid_Cell', COUNT(*) FROM "RTSGrid_Cell"
UNION ALL SELECT 'RTSGrid_TemplateCell', COUNT(*) FROM "RTSGrid_TemplateCell"
UNION ALL SELECT 'RTSGrid_Statistic', COUNT(*) FROM "RTSGrid_Statistic"
UNION ALL SELECT 'RTSUserGrid_Grid', COUNT(*) FROM "RTSUserGrid_Grid"
UNION ALL SELECT 'RTSUserGrid_ColumnsSet', COUNT(*) FROM "RTSUserGrid_ColumnsSet"
UNION ALL SELECT 'RTSUserGrid_Column', COUNT(*) FROM "RTSUserGrid_Column"
UNION ALL SELECT 'RTSData_Interaction', COUNT(*) FROM "RTSData_Interaction"
UNION ALL SELECT 'RTSData_UserStatus', COUNT(*) FROM "RTSData_UserStatus"
UNION ALL SELECT 'RTSData_UserStatusLog', COUNT(*) FROM "RTSData_UserStatusLog"
UNION ALL SELECT 'RTSData_ChatMessage', COUNT(*) FROM "RTSData_ChatMessage"
ORDER BY table_name;

-- ============================================================================
-- 2. UPSERT test: Re-insert existing RTSData_Interaction row
--    Should UPDATE (not error) due to ON CONFLICT clause
-- ============================================================================
\echo ''
\echo '=== UPSERT TEST: RTSData_Interaction ==='

-- Get a sample row to test with
DO $$
DECLARE
    v_interaction_id text;
    v_segment integer;
    v_server_id text;
    v_count_before integer;
    v_count_after integer;
BEGIN
    -- Get first existing row
    SELECT "InteractionId", "Segment", "ServerId"
    INTO v_interaction_id, v_segment, v_server_id
    FROM "RTSData_Interaction"
    LIMIT 1;

    IF v_interaction_id IS NULL THEN
        RAISE NOTICE 'No RTSData_Interaction rows to test UPSERT';
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_count_before FROM "RTSData_Interaction";

    -- Call UPSERT function with existing key (should update, not insert)
    PERFORM "RTSData_SetInteraction"(
        v_interaction_id, v_segment, '30/05/2026', v_server_id, 'TestWorkgroup', 'TestUser',
        NULL, 'Call', 'Inbound', 'Incoming', NULL,
        false, true, false, true, false,
        60, 120, NOW(), NOW(), NOW(),
        NULL, NULL, false, NULL, false, '+00:00'
    );

    SELECT COUNT(*) INTO v_count_after FROM "RTSData_Interaction";

    IF v_count_before = v_count_after THEN
        RAISE NOTICE 'UPSERT TEST PASSED: Row count unchanged (% rows)', v_count_after;
    ELSE
        RAISE WARNING 'UPSERT TEST FAILED: Row count changed from % to %', v_count_before, v_count_after;
    END IF;
END;
$$;

-- ============================================================================
-- 3. Function smoke tests
-- ============================================================================
\echo ''
\echo '=== FUNCTION SMOKE TESTS ==='

-- NGC functions
SELECT 'NGC_GetSiteTable' AS function_name, COUNT(*) AS result_rows FROM "NGC_GetSiteTable"()
UNION ALL SELECT 'NGC_GetBusinessUnitTable', COUNT(*) FROM "NGC_GetBusinessUnitTable"()
UNION ALL SELECT 'NGC_GetSupergroupTable', COUNT(*) FROM "NGC_GetSupergroupTable"()
UNION ALL SELECT 'NGC_GetBusinessUnitQueueClassificationTable', COUNT(*) FROM "NGC_GetBusinessUnitQueueClassificationTable"()
UNION ALL SELECT 'NGC_GetBusinessUnitSupergroupTable', COUNT(*) FROM "NGC_GetBusinessUnitSupergroupTable"()
UNION ALL SELECT 'NGC_GetSupergroupAgentgroupTable', COUNT(*) FROM "NGC_GetSupergroupAgentgroupTable"();

-- RTSGrid read functions
SELECT 'RTSGrid_GetAllMetrics' AS function_name, COUNT(*) AS result_rows FROM "RTSGrid_GetAllMetrics"()
UNION ALL SELECT 'RTSGrid_GetAllStatistics', COUNT(*) FROM "RTSGrid_GetAllStatistics"()
UNION ALL SELECT 'RTSGrid_GetDataCells', COUNT(*) FROM "RTSGrid_GetDataCells"()
UNION ALL SELECT 'RTSGrid_GetStatisticCells', COUNT(*) FROM "RTSGrid_GetStatisticCells"()
UNION ALL SELECT 'RTSGrid_GetAllUnionQueueClassifications', COUNT(*) FROM "RTSGrid_GetAllUnionQueueClassifications"()
UNION ALL SELECT 'RTSGrid_GetAllUnionUserGroups', COUNT(*) FROM "RTSGrid_GetAllUnionUserGroups"()
UNION ALL SELECT 'RTSGrid_GetUnionUsersMetrics', COUNT(*) FROM "RTSGrid_GetUnionUsersMetrics"()
UNION ALL SELECT 'RTSUserGrid_GetAllGrids', COUNT(*) FROM "RTSUserGrid_GetAllGrids"();

-- RTSData read functions (with lowercase aliases)
SELECT 'RTSData_GetInteractions' AS function_name, COUNT(*) AS result_rows FROM "RTSData_GetInteractions"()
UNION ALL SELECT 'RTSData_getInteractions (alias)', COUNT(*) FROM "RTSData_getInteractions"()
UNION ALL SELECT 'RTSData_GetUsersStatuses', COUNT(*) FROM "RTSData_GetUsersStatuses"()
UNION ALL SELECT 'RTSData_getUsersStatuses (alias)', COUNT(*) FROM "RTSData_getUsersStatuses"();

-- DNN stub (should return 0 rows)
SELECT 'RTSUserView_GetHTMLSettings (stub)', COUNT(*) FROM "RTSUserView_GetHTMLSettings"();

-- ============================================================================
-- 4. RTSData_UserStatusLog Duration check (milliseconds conversion)
-- ============================================================================
\echo ''
\echo '=== DURATION MILLISECONDS CHECK ==='

SELECT
    CASE
        WHEN COUNT(*) = 0 THEN 'NO DATA: RTSData_UserStatusLog is empty'
        WHEN MIN("Duration") >= 1000 OR MIN("Duration") IS NULL THEN 'PASS: All Duration values appear to be in milliseconds'
        ELSE 'WARNING: Some Duration values < 1000 — may still be in seconds'
    END AS duration_check,
    COUNT(*) AS total_rows,
    MIN("Duration") AS min_duration,
    MAX("Duration") AS max_duration,
    AVG("Duration")::bigint AS avg_duration
FROM "RTSData_UserStatusLog"
WHERE "Duration" IS NOT NULL;

-- Sample of Duration values for manual inspection
\echo ''
\echo '=== SAMPLE DURATION VALUES (first 10) ==='
SELECT "UserId", "StatusId", "Duration", "StartTime", "EndTime"
FROM "RTSData_UserStatusLog"
WHERE "Duration" IS NOT NULL
ORDER BY "StartTime" DESC
LIMIT 10;

-- ============================================================================
-- 5. Foreign key integrity checks
-- ============================================================================
\echo ''
\echo '=== FOREIGN KEY INTEGRITY CHECKS ==='

-- Check NGC_BusinessUnit -> NGC_Site
SELECT 'NGC_BusinessUnit.SiteId orphans' AS check_name,
       COUNT(*) AS orphan_count
FROM "NGC_BusinessUnit" bu
LEFT JOIN "NGC_Site" s ON bu."SiteId" = s."SiteId"
WHERE bu."SiteId" IS NOT NULL AND s."SiteId" IS NULL;

-- Check NGC_BusinessUnitSupergroup -> NGC_BusinessUnit
SELECT 'NGC_BusinessUnitSupergroup.BusinessUnitId orphans' AS check_name,
       COUNT(*) AS orphan_count
FROM "NGC_BusinessUnitSupergroup" bus
LEFT JOIN "NGC_BusinessUnit" bu ON bus."BusinessUnitId" = bu."BusinessUnitId"
WHERE bu."BusinessUnitId" IS NULL;

-- Check NGC_BusinessUnitSupergroup -> NGC_Supergroup
SELECT 'NGC_BusinessUnitSupergroup.SupergroupId orphans' AS check_name,
       COUNT(*) AS orphan_count
FROM "NGC_BusinessUnitSupergroup" bus
LEFT JOIN "NGC_Supergroup" sg ON bus."SupergroupId" = sg."SupergroupId"
WHERE sg."SupergroupId" IS NULL;

-- Check RTSGrid_Row -> RTSGrid_Grid
SELECT 'RTSGrid_Row.GridId orphans' AS check_name,
       COUNT(*) AS orphan_count
FROM "RTSGrid_Row" r
LEFT JOIN "RTSGrid_Grid" g ON r."GridId" = g."GridId"
WHERE g."GridId" IS NULL;

-- Check RTSGrid_Cell -> RTSGrid_Row
SELECT 'RTSGrid_Cell.RowId orphans' AS check_name,
       COUNT(*) AS orphan_count
FROM "RTSGrid_Cell" c
LEFT JOIN "RTSGrid_Row" r ON c."RowId" = r."RowId"
WHERE r."RowId" IS NULL;

-- ============================================================================
-- 6. Index verification
-- ============================================================================
\echo ''
\echo '=== UNIQUE INDEX VERIFICATION ==='

-- Check that UPSERT indexes exist
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('RTSData_Interaction', 'RTSData_ChatMessage')
  AND indexdef LIKE '%UNIQUE%'
ORDER BY tablename, indexname;

-- ============================================================================
-- Summary
-- ============================================================================
\echo ''
\echo '=== MIGRATION VERIFICATION COMPLETE ==='
\echo 'Review results above. All orphan counts should be 0.'
\echo 'All function smoke tests should return row counts matching table counts.'
\echo 'Duration values should be >= 1000 (milliseconds).'
