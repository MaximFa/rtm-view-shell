-- ============================================================================
-- Migration: 20260613_011_45_table_drift_addcolumns
-- Purpose: Add missing canonical columns to RTSData_Interaction on Server 45
--          (and any other server missing them)
-- 
-- Background: Server 45 has an older table schema missing CustomCallData1..20.
-- The RTSData_SetInteraction procedure (3db705d) references these columns,
-- causing 42703 (undefined column) on INSERT. The function bodies are CORRECT;
-- the FIX is to bring the table schema up to canonical.
--
-- ADD COLUMN IF NOT EXISTS: idempotent (no-op on dev/234 which already have them)
-- Columns added AT TABLE END: does not affect explicit SELECT column ordering
-- ============================================================================

-- RTSData_Interaction: Add CustomCallData1..CustomCallData20 (all text, nullable)
-- These match canonical schema.sql DDL exactly

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

-- [45 cross-check 2026-06-13] additional canonical columns missing on 45:

-- RTSData_UserStatus.MaxDuraction — BODY-REFERENCED by RTSData_getUsersStatuses (RETURNS+SELECT) => 42703 on re-apply if absent
ALTER TABLE "RTSData_UserStatus" ADD COLUMN IF NOT EXISTS "MaxDuraction" integer;

-- NGC_Queues/NGC_AgentGroups.CreatedDatetime — canonical PARITY (no function references after 3db705d fix; added for canonical end-state)
ALTER TABLE "NGC_Queues"      ADD COLUMN IF NOT EXISTS "CreatedDatetime" timestamptz DEFAULT now();
ALTER TABLE "NGC_AgentGroups" ADD COLUMN IF NOT EXISTS "CreatedDatetime" timestamptz DEFAULT now();

-- §38a self-record (MANDATORY for db/migrations/ files)
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260613_011_45_table_drift_addcolumns')
ON CONFLICT (migration_name) DO NOTHING;

-- ============================================================================
-- End of migration 20260613_011
-- ============================================================================