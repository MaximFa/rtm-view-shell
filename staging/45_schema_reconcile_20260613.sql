-- 45 Schema Reconcile to Canon — ONE-PASS holistic structural patch
-- Purpose: Bring 45's STRUCTURE up to schema.sql canon (all missing UNIQUE constraints + indexes + columns)
-- ROOT CAUSE: Clean rebuild = EF migrate + db/functions/; does NOT apply schema.sql -> structural drift
-- This reconcile = full-coverage immediate patch for the 42883/42703/23505/42P10 class
-- ADDITIVE ONLY — no drops; guarded for idempotency; safe to re-run on dev/234/45
--
-- NOTE: SUPERSEDES the subset hotfixes _011/_012/_013 (but they are KEPT per coordinator 18:19 —
-- committed/applied/in-packages; guards make the overlap a no-op on already-patched servers)
--
-- GUARDED: All CREATE INDEX wrapped with to_regclass() table-exists check (PD-008: schema.sql
-- carries 8 phantom PascalCase tables that don't exist on real EF servers; guards skip cleanly)

-- =============================================================================
-- SECTION 1: UNIQUE CONSTRAINTS (3 total — the ON CONFLICT backing constraints)
-- Each has a dedup guard + table-exists check
-- =============================================================================

-- 1a. uq_ngc_queues_external_tenant (ExternalId, TenantId) — backs GetOrCreateQueue ON CONFLICT
DO $uq_queues$
DECLARE dup_count integer;
BEGIN
    IF to_regclass('public."NGC_Queues"') IS NULL THEN
        RAISE NOTICE 'SKIP: table NGC_Queues does not exist';
        RETURN;
    END IF;
    SELECT COUNT(*) INTO dup_count FROM (
        SELECT "ExternalId", "TenantId" FROM "NGC_Queues"
        GROUP BY "ExternalId", "TenantId" HAVING COUNT(*) > 1
    ) dups;
    IF dup_count > 0 THEN
        RAISE NOTICE 'DEDUP NGC_Queues: Found % duplicate pairs', dup_count;
        DELETE FROM "NGC_Queues" a USING (
            SELECT "ExternalId", "TenantId", MIN("Id") AS keep_id
            FROM "NGC_Queues" GROUP BY "ExternalId", "TenantId" HAVING COUNT(*) > 1
        ) dups WHERE a."ExternalId" = dups."ExternalId" AND a."TenantId" = dups."TenantId" AND a."Id" <> dups.keep_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_ngc_queues_external_tenant'
                   AND conrelid = '"NGC_Queues"'::regclass) THEN
        ALTER TABLE "NGC_Queues" ADD CONSTRAINT uq_ngc_queues_external_tenant UNIQUE ("ExternalId", "TenantId");
        RAISE NOTICE 'ADDED constraint uq_ngc_queues_external_tenant';
    ELSE
        RAISE NOTICE 'SKIP: uq_ngc_queues_external_tenant already exists';
    END IF;
END $uq_queues$;

-- 1b. uq_ngc_agentgroups_external_tenant
DO $uq_agentgroups$
DECLARE dup_count integer;
BEGIN
    IF to_regclass('public."NGC_AgentGroups"') IS NULL THEN RAISE NOTICE 'SKIP: NGC_AgentGroups'; RETURN; END IF;
    SELECT COUNT(*) INTO dup_count FROM (
        SELECT "ExternalId", "TenantId" FROM "NGC_AgentGroups"
        GROUP BY "ExternalId", "TenantId" HAVING COUNT(*) > 1
    ) dups;
    IF dup_count > 0 THEN
        DELETE FROM "NGC_AgentGroups" a USING (
            SELECT "ExternalId", "TenantId", MIN("Id") AS keep_id
            FROM "NGC_AgentGroups" GROUP BY "ExternalId", "TenantId" HAVING COUNT(*) > 1
        ) dups WHERE a."ExternalId" = dups."ExternalId" AND a."TenantId" = dups."TenantId" AND a."Id" <> dups.keep_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_ngc_agentgroups_external_tenant'
                   AND conrelid = '"NGC_AgentGroups"'::regclass) THEN
        ALTER TABLE "NGC_AgentGroups" ADD CONSTRAINT uq_ngc_agentgroups_external_tenant UNIQUE ("ExternalId", "TenantId");
    END IF;
END $uq_agentgroups$;

-- 1c. uq_supergroup_agentgroup
DO $uq_sgag$
DECLARE dup_count integer;
BEGIN
    IF to_regclass('public."NGC_SupergroupAgentgroup"') IS NULL THEN RAISE NOTICE 'SKIP: NGC_SupergroupAgentgroup'; RETURN; END IF;
    SELECT COUNT(*) INTO dup_count FROM (
        SELECT "SupergroupId", "AgentgroupId" FROM "NGC_SupergroupAgentgroup"
        GROUP BY "SupergroupId", "AgentgroupId" HAVING COUNT(*) > 1
    ) dups;
    IF dup_count > 0 THEN
        DELETE FROM "NGC_SupergroupAgentgroup" a USING (
            SELECT "SupergroupId", "AgentgroupId", MIN("Id") AS keep_id
            FROM "NGC_SupergroupAgentgroup" GROUP BY "SupergroupId", "AgentgroupId" HAVING COUNT(*) > 1
        ) dups WHERE a."SupergroupId" = dups."SupergroupId" AND a."AgentgroupId" = dups."AgentgroupId" AND a."Id" <> dups.keep_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_supergroup_agentgroup'
                   AND conrelid = '"NGC_SupergroupAgentgroup"'::regclass) THEN
        ALTER TABLE "NGC_SupergroupAgentgroup" ADD CONSTRAINT uq_supergroup_agentgroup UNIQUE ("SupergroupId", "AgentgroupId");
    END IF;
END $uq_sgag$;

-- =============================================================================
-- SECTION 2: UNIQUE INDEXES (critical for ON CONFLICT targets) — guarded
-- =============================================================================
DO $$ BEGIN IF to_regclass('public."NGC_UserAgentgroup"') IS NOT NULL THEN
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId" ON public."NGC_UserAgentgroup" ("TenantId", "UserId", "AgentgroupId")';
END IF; END $$;

DO $$ BEGIN IF to_regclass('public."RTSData_Interaction"') IS NOT NULL THEN
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_RTSData_Interaction_UpsertKey" ON public."RTSData_Interaction" ("InteractionId", "Segment", "ServerId")';
END IF; END $$;

DO $$ BEGIN IF to_regclass('public."RTSData_ChatMessage"') IS NOT NULL THEN
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_RTSData_ChatMessage_MessageId_ServerId" ON public."RTSData_ChatMessage" ("MessageId", "ServerId")';
END IF; END $$;

-- =============================================================================
-- SECTION 3: REGULAR INDEXES — guarded
-- =============================================================================
DO $$ BEGIN IF to_regclass('public."AuditEvents"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_AuditEvents_OccurredAt" ON public."AuditEvents" ("OccurredAt")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."AuditEvents"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_AuditEvents_UserId" ON public."AuditEvents" ("UserId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."NGC_BusinessUnitSupergroup"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_NGC_BusinessUnitSupergroup_SupergroupId" ON public."NGC_BusinessUnitSupergroup" ("SupergroupId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."NGC_BusinessUnit"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_NGC_BusinessUnit_SiteId" ON public."NGC_BusinessUnit" ("SiteId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."NGC_SupergroupAgentgroup"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_NGC_SupergroupAgentgroup_SupergroupId" ON public."NGC_SupergroupAgentgroup" ("SupergroupId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."RTSData_UserStatusLog"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time" ON public."RTSData_UserStatusLog" ("TenantId", "StatusGroup", "StartTime", "EndTime")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."ResourcePermissions"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_ResourcePermissions_GroupId_ResourceType" ON public."ResourcePermissions" ("GroupId", "ResourceType")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."ScreenPermissions"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_ScreenPermissions_GroupId" ON public."ScreenPermissions" ("GroupId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."Screens"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_Screens_OwnerId" ON public."Screens" ("OwnerId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."UserGroups"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_UserGroups_GroupId" ON public."UserGroups" ("GroupId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."WidgetSlots"') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_WidgetSlots_ScreenId" ON public."WidgetSlots" ("ScreenId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.dashboard_permissions') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_dashboard_permissions_DashboardId" ON public.dashboard_permissions ("DashboardId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.dashboard_widgets') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_dashboard_widgets_DashboardId" ON public.dashboard_widgets ("DashboardId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.dashboard_widgets') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_dashboard_widgets_WidgetCatalogItemId" ON public.dashboard_widgets ("WidgetCatalogItemId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.dashboards') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_dashboards_CategoryId" ON public.dashboards ("CategoryId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.dashboards') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_dashboards_TenantId_Name" ON public.dashboards ("TenantId", "Name")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.info_slot_messages') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_info_slot_messages_InfoSlotId_IsActive_ExpiresAt" ON public.info_slot_messages ("InfoSlotId", "IsActive", "ExpiresAt")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.info_slot_messages') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_info_slot_messages_TenantId_CreatedAt" ON public.info_slot_messages ("TenantId", "CreatedAt")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.info_slot_permissions') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_info_slot_permissions_PermissionGroupId" ON public.info_slot_permissions ("PermissionGroupId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.sso_configurations') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_sso_configurations_TenantId" ON public.sso_configurations ("TenantId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.tenant_agent_state_definitions') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_tenant_agent_state_definitions_AgentStateGroupId" ON public.tenant_agent_state_definitions ("AgentStateGroupId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.widget_templates') IS NOT NULL THEN EXECUTE 'CREATE INDEX IF NOT EXISTS "IX_widget_templates_WidgetCatalogItemId" ON public.widget_templates ("WidgetCatalogItemId")'; END IF; END $$;

-- =============================================================================
-- SECTION 4: UNIQUE INDEXES (other canon) — guarded
-- =============================================================================
DO $$ BEGIN IF to_regclass('public."PermissionGroups"') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_PermissionGroups_Name" ON public."PermissionGroups" ("Name")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public."Users"') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_Users_Email" ON public."Users" ("Email")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.dashboard_categories') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_dashboard_categories_TenantId_Name" ON public.dashboard_categories ("TenantId", "Name")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.info_slots') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_info_slots_TenantId_Name" ON public.info_slots ("TenantId", "Name")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.permission_groups') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_permission_groups_TenantId_Name" ON public.permission_groups ("TenantId", "Name")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.tenant_agent_state_definitions') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenant_agent_state_definitions_AgentStateId" ON public.tenant_agent_state_definitions ("AgentStateId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.tenant_agent_state_definitions') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenant_agent_state_definitions_TenantId_AgentStateId" ON public.tenant_agent_state_definitions ("TenantId", "AgentStateId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.tenant_agent_state_groups') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenant_agent_state_groups_TenantId_GroupName" ON public.tenant_agent_state_groups ("TenantId", "GroupName")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.tenant_agent_states') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenant_agent_states_TenantId_AgentState" ON public.tenant_agent_states ("TenantId", "AgentState")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.tenants') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenants_Slug" ON public.tenants ("Slug")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.user_widget_settings') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_user_widget_settings_TenantId_UserId_WidgetId" ON public.user_widget_settings ("TenantId", "UserId", "WidgetId")'; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.widget_templates') IS NOT NULL THEN EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "IX_widget_templates_TenantId_Name" ON public.widget_templates ("TenantId", "Name")'; END IF; END $$;

-- =============================================================================
-- SECTION 5: MISSING COLUMNS (_011 set) — guarded
-- =============================================================================
DO $$ BEGIN IF to_regclass('public."RTSData_Interaction"') IS NOT NULL THEN
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData1" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData2" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData3" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData4" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData5" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData6" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData7" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData8" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData9" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData10" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData11" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData12" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData13" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData14" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData15" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData16" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData17" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData18" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData19" text;
    ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData20" text;
END IF; END $$;

DO $$ BEGIN IF to_regclass('public."RTSData_UserStatus"') IS NOT NULL THEN
    ALTER TABLE "RTSData_UserStatus" ADD COLUMN IF NOT EXISTS "MaxDuraction" integer;
END IF; END $$;

DO $$ BEGIN IF to_regclass('public."NGC_Queues"') IS NOT NULL THEN
    ALTER TABLE "NGC_Queues" ADD COLUMN IF NOT EXISTS "CreatedDatetime" timestamptz DEFAULT now();
END IF; END $$;

DO $$ BEGIN IF to_regclass('public."NGC_AgentGroups"') IS NOT NULL THEN
    ALTER TABLE "NGC_AgentGroups" ADD COLUMN IF NOT EXISTS "CreatedDatetime" timestamptz DEFAULT now();
END IF; END $$;

-- =============================================================================
-- SECTION 6: VERIFY
-- =============================================================================
SELECT 'UNIQUE CONSTRAINTS' AS section, conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid IN ('"NGC_Queues"'::regclass, '"NGC_AgentGroups"'::regclass, '"NGC_SupergroupAgentgroup"'::regclass)
  AND contype = 'u'
ORDER BY conname;
