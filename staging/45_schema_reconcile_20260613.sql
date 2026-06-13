-- 45 Schema Reconcile to Canon — ONE-PASS holistic structural patch
-- Purpose: Bring 45's STRUCTURE up to schema.sql canon (all missing UNIQUE constraints + indexes + columns)
-- ROOT CAUSE: Clean rebuild = EF migrate + db/functions/; does NOT apply schema.sql -> structural drift
-- This reconcile = full-coverage immediate patch for the 42883/42703/23505/42P10 class
-- ADDITIVE ONLY — no drops; guarded for idempotency; safe to re-run on dev/234/45
--
-- NOTE: SUPERSEDES the subset hotfixes _011/_012/_013 (but they are KEPT per coordinator 18:19 —
-- committed/applied/in-packages; guards make the overlap a no-op on already-patched servers)

-- =============================================================================
-- SECTION 1: UNIQUE CONSTRAINTS (3 total — the ON CONFLICT backing constraints)
-- Each has a dedup guard first (remove dup rows keeping MIN(Id) per key)
-- =============================================================================

-- 1a. uq_ngc_queues_external_tenant (ExternalId, TenantId) — backs GetOrCreateQueue ON CONFLICT
DO $dedup_queues$
DECLARE dup_count integer;
BEGIN
    SELECT COUNT(*) INTO dup_count FROM (
        SELECT "ExternalId", "TenantId"
        FROM "NGC_Queues"
        GROUP BY "ExternalId", "TenantId"
        HAVING COUNT(*) > 1
    ) dups;
    IF dup_count > 0 THEN
        RAISE NOTICE 'DEDUP NGC_Queues: Found % duplicate (ExternalId, TenantId) pairs', dup_count;
        DELETE FROM "NGC_Queues" a USING (
            SELECT "ExternalId", "TenantId", MIN("Id") AS keep_id
            FROM "NGC_Queues" GROUP BY "ExternalId", "TenantId" HAVING COUNT(*) > 1
        ) dups WHERE a."ExternalId" = dups."ExternalId" AND a."TenantId" = dups."TenantId" AND a."Id" <> dups.keep_id;
    ELSE
        RAISE NOTICE 'DEDUP NGC_Queues: No duplicates found - OK';
    END IF;
END $dedup_queues$;

DO $add_uq_queues$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_ngc_queues_external_tenant'
                   AND conrelid = '"NGC_Queues"'::regclass) THEN
        ALTER TABLE "NGC_Queues" ADD CONSTRAINT uq_ngc_queues_external_tenant UNIQUE ("ExternalId", "TenantId");
        RAISE NOTICE 'ADDED constraint uq_ngc_queues_external_tenant';
    ELSE
        RAISE NOTICE 'SKIP: uq_ngc_queues_external_tenant already exists';
    END IF;
END $add_uq_queues$;

-- 1b. uq_ngc_agentgroups_external_tenant (ExternalId, TenantId) — backs GetOrCreateAgentGroup ON CONFLICT
DO $dedup_agentgroups$
DECLARE dup_count integer;
BEGIN
    SELECT COUNT(*) INTO dup_count FROM (
        SELECT "ExternalId", "TenantId"
        FROM "NGC_AgentGroups"
        GROUP BY "ExternalId", "TenantId"
        HAVING COUNT(*) > 1
    ) dups;
    IF dup_count > 0 THEN
        RAISE NOTICE 'DEDUP NGC_AgentGroups: Found % duplicate (ExternalId, TenantId) pairs', dup_count;
        DELETE FROM "NGC_AgentGroups" a USING (
            SELECT "ExternalId", "TenantId", MIN("Id") AS keep_id
            FROM "NGC_AgentGroups" GROUP BY "ExternalId", "TenantId" HAVING COUNT(*) > 1
        ) dups WHERE a."ExternalId" = dups."ExternalId" AND a."TenantId" = dups."TenantId" AND a."Id" <> dups.keep_id;
    ELSE
        RAISE NOTICE 'DEDUP NGC_AgentGroups: No duplicates found - OK';
    END IF;
END $dedup_agentgroups$;

DO $add_uq_agentgroups$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_ngc_agentgroups_external_tenant'
                   AND conrelid = '"NGC_AgentGroups"'::regclass) THEN
        ALTER TABLE "NGC_AgentGroups" ADD CONSTRAINT uq_ngc_agentgroups_external_tenant UNIQUE ("ExternalId", "TenantId");
        RAISE NOTICE 'ADDED constraint uq_ngc_agentgroups_external_tenant';
    ELSE
        RAISE NOTICE 'SKIP: uq_ngc_agentgroups_external_tenant already exists';
    END IF;
END $add_uq_agentgroups$;

-- 1c. uq_supergroup_agentgroup (SupergroupId, AgentgroupId) — backs CreateSupergroupAgentgroupMapping ON CONFLICT
-- (_013 applied this, but we include it for completeness; guard makes it no-op)
DO $dedup_sgag$
DECLARE dup_count integer;
BEGIN
    SELECT COUNT(*) INTO dup_count FROM (
        SELECT "SupergroupId", "AgentgroupId"
        FROM "NGC_SupergroupAgentgroup"
        GROUP BY "SupergroupId", "AgentgroupId"
        HAVING COUNT(*) > 1
    ) dups;
    IF dup_count > 0 THEN
        RAISE NOTICE 'DEDUP NGC_SupergroupAgentgroup: Found % duplicate (SupergroupId, AgentgroupId) pairs', dup_count;
        DELETE FROM "NGC_SupergroupAgentgroup" a USING (
            SELECT "SupergroupId", "AgentgroupId", MIN("Id") AS keep_id
            FROM "NGC_SupergroupAgentgroup" GROUP BY "SupergroupId", "AgentgroupId" HAVING COUNT(*) > 1
        ) dups WHERE a."SupergroupId" = dups."SupergroupId" AND a."AgentgroupId" = dups."AgentgroupId" AND a."Id" <> dups.keep_id;
    ELSE
        RAISE NOTICE 'DEDUP NGC_SupergroupAgentgroup: No duplicates found - OK';
    END IF;
END $dedup_sgag$;

DO $add_uq_sgag$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_supergroup_agentgroup'
                   AND conrelid = '"NGC_SupergroupAgentgroup"'::regclass) THEN
        ALTER TABLE "NGC_SupergroupAgentgroup" ADD CONSTRAINT uq_supergroup_agentgroup UNIQUE ("SupergroupId", "AgentgroupId");
        RAISE NOTICE 'ADDED constraint uq_supergroup_agentgroup';
    ELSE
        RAISE NOTICE 'SKIP: uq_supergroup_agentgroup already exists';
    END IF;
END $add_uq_sgag$;

-- =============================================================================
-- SECTION 2: UNIQUE INDEXES (critical for ON CONFLICT targets)
-- =============================================================================

-- 2a. IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId — backs NGC_SetUserAgentgroup ON CONFLICT
CREATE UNIQUE INDEX IF NOT EXISTS "IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId"
    ON public."NGC_UserAgentgroup" USING btree ("TenantId", "UserId", "AgentgroupId");

-- 2b. IX_RTSData_Interaction_UpsertKey — backs RTSData_SetInteraction ON CONFLICT
CREATE UNIQUE INDEX IF NOT EXISTS "IX_RTSData_Interaction_UpsertKey"
    ON public."RTSData_Interaction" USING btree ("InteractionId", "Segment", "ServerId");

-- 2c. IX_RTSData_ChatMessage_MessageId_ServerId — backs RTSData_SetChatMessage ON CONFLICT
CREATE UNIQUE INDEX IF NOT EXISTS "IX_RTSData_ChatMessage_MessageId_ServerId"
    ON public."RTSData_ChatMessage" USING btree ("MessageId", "ServerId");

-- =============================================================================
-- SECTION 3: REGULAR INDEXES (public schema, from schema.sql)
-- =============================================================================

CREATE INDEX IF NOT EXISTS "IX_AuditEvents_OccurredAt"
    ON public."AuditEvents" USING btree ("OccurredAt");
CREATE INDEX IF NOT EXISTS "IX_AuditEvents_UserId"
    ON public."AuditEvents" USING btree ("UserId");
CREATE INDEX IF NOT EXISTS "IX_NGC_BusinessUnitSupergroup_SupergroupId"
    ON public."NGC_BusinessUnitSupergroup" USING btree ("SupergroupId");
CREATE INDEX IF NOT EXISTS "IX_NGC_BusinessUnit_SiteId"
    ON public."NGC_BusinessUnit" USING btree ("SiteId");
CREATE INDEX IF NOT EXISTS "IX_NGC_SupergroupAgentgroup_SupergroupId"
    ON public."NGC_SupergroupAgentgroup" USING btree ("SupergroupId");
CREATE INDEX IF NOT EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time"
    ON public."RTSData_UserStatusLog" USING btree ("TenantId", "StatusGroup", "StartTime", "EndTime");
CREATE INDEX IF NOT EXISTS "IX_ResourcePermissions_GroupId_ResourceType"
    ON public."ResourcePermissions" USING btree ("GroupId", "ResourceType");
CREATE INDEX IF NOT EXISTS "IX_ScreenPermissions_GroupId"
    ON public."ScreenPermissions" USING btree ("GroupId");
CREATE INDEX IF NOT EXISTS "IX_Screens_OwnerId"
    ON public."Screens" USING btree ("OwnerId");
CREATE INDEX IF NOT EXISTS "IX_UserGroups_GroupId"
    ON public."UserGroups" USING btree ("GroupId");
CREATE INDEX IF NOT EXISTS "IX_WidgetSlots_ScreenId"
    ON public."WidgetSlots" USING btree ("ScreenId");
CREATE INDEX IF NOT EXISTS "IX_dashboard_permissions_DashboardId"
    ON public.dashboard_permissions USING btree ("DashboardId");
CREATE INDEX IF NOT EXISTS "IX_dashboard_widgets_DashboardId"
    ON public.dashboard_widgets USING btree ("DashboardId");
CREATE INDEX IF NOT EXISTS "IX_dashboard_widgets_WidgetCatalogItemId"
    ON public.dashboard_widgets USING btree ("WidgetCatalogItemId");
CREATE INDEX IF NOT EXISTS "IX_dashboards_CategoryId"
    ON public.dashboards USING btree ("CategoryId");
CREATE INDEX IF NOT EXISTS "IX_dashboards_TenantId_Name"
    ON public.dashboards USING btree ("TenantId", "Name");
CREATE INDEX IF NOT EXISTS "IX_info_slot_messages_InfoSlotId_IsActive_ExpiresAt"
    ON public.info_slot_messages USING btree ("InfoSlotId", "IsActive", "ExpiresAt");
CREATE INDEX IF NOT EXISTS "IX_info_slot_messages_TenantId_CreatedAt"
    ON public.info_slot_messages USING btree ("TenantId", "CreatedAt");
CREATE INDEX IF NOT EXISTS "IX_info_slot_permissions_PermissionGroupId"
    ON public.info_slot_permissions USING btree ("PermissionGroupId");
CREATE INDEX IF NOT EXISTS "IX_sso_configurations_TenantId"
    ON public.sso_configurations USING btree ("TenantId");
CREATE INDEX IF NOT EXISTS "IX_tenant_agent_state_definitions_AgentStateGroupId"
    ON public.tenant_agent_state_definitions USING btree ("AgentStateGroupId");
CREATE INDEX IF NOT EXISTS "IX_widget_templates_WidgetCatalogItemId"
    ON public.widget_templates USING btree ("WidgetCatalogItemId");

-- =============================================================================
-- SECTION 4: UNIQUE INDEXES (other canon, not ON CONFLICT critical)
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS "IX_PermissionGroups_Name"
    ON public."PermissionGroups" USING btree ("Name");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Users_Email"
    ON public."Users" USING btree ("Email");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_dashboard_categories_TenantId_Name"
    ON public.dashboard_categories USING btree ("TenantId", "Name");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_info_slots_TenantId_Name"
    ON public.info_slots USING btree ("TenantId", "Name");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_permission_groups_TenantId_Name"
    ON public.permission_groups USING btree ("TenantId", "Name");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenant_agent_state_definitions_AgentStateId"
    ON public.tenant_agent_state_definitions USING btree ("AgentStateId");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenant_agent_state_definitions_TenantId_AgentStateId"
    ON public.tenant_agent_state_definitions USING btree ("TenantId", "AgentStateId");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenant_agent_state_groups_TenantId_GroupName"
    ON public.tenant_agent_state_groups USING btree ("TenantId", "GroupName");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenant_agent_states_TenantId_AgentState"
    ON public.tenant_agent_states USING btree ("TenantId", "AgentState");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_tenants_Slug"
    ON public.tenants USING btree ("Slug");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_user_widget_settings_TenantId_UserId_WidgetId"
    ON public.user_widget_settings USING btree ("TenantId", "UserId", "WidgetId");
CREATE UNIQUE INDEX IF NOT EXISTS "IX_widget_templates_TenantId_Name"
    ON public.widget_templates USING btree ("TenantId", "Name");

-- =============================================================================
-- SECTION 5: MISSING COLUMNS (_011 set — already applied on 45, guards make it no-op)
-- =============================================================================

-- RTSData_Interaction CustomCallData1..20
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

-- RTSData_UserStatus MaxDuraction
ALTER TABLE "RTSData_UserStatus" ADD COLUMN IF NOT EXISTS "MaxDuraction" integer;

-- NGC_Queues / NGC_AgentGroups CreatedDatetime
ALTER TABLE "NGC_Queues" ADD COLUMN IF NOT EXISTS "CreatedDatetime" timestamptz DEFAULT now();
ALTER TABLE "NGC_AgentGroups" ADD COLUMN IF NOT EXISTS "CreatedDatetime" timestamptz DEFAULT now();

-- =============================================================================
-- SECTION 6: VERIFY — summary of what was added
-- =============================================================================

SELECT 'UNIQUE CONSTRAINTS' AS section, conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid IN ('"NGC_Queues"'::regclass, '"NGC_AgentGroups"'::regclass, '"NGC_SupergroupAgentgroup"'::regclass)
  AND contype = 'u'
ORDER BY conname;

SELECT 'CRITICAL UNIQUE INDEXES' AS section, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId',
    'IX_RTSData_Interaction_UpsertKey',
    'IX_RTSData_ChatMessage_MessageId_ServerId'
  )
ORDER BY indexname;
