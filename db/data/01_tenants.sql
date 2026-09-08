-- 01_tenants.sql: the default platform tenant, shipped WITH the database.
--
-- Why this file exists: DatabaseInitializer.SeedPlatformTenantAsync creates the tenant at first
-- startup with Id = Uuid.NewSequential() when none is found. That makes the Id different on every
-- clean install, while RTM:TenantId and db/data/04_catalog.sql (NGC_Site) carry a FIXED id.
-- Measured 2026-09-08 on server 234: the three disagreed, and nothing could be displayed.
-- Shipping the tenant here makes the startup branch find it instead of inventing one.
--
-- The id is not chosen here - it is the one already hard-coded in 04_catalog.sql.
-- Idempotent: re-running the seed must not duplicate or overwrite a live tenant.
--
-- THE CONFLICT TARGET IS "Slug", NOT "Id" - and that is deliberate.
-- Migration 20260507135247_InitialCreate.cs:639-643 creates
--     CreateIndex(name: "IX_tenants_Slug", table: "tenants", column: "Slug", unique: true)
-- so Slug is UNIQUE. On a machine that already carries a tenant with Slug='platform' but a
-- DIFFERENT Id (that is exactly the state this defect produces), an ON CONFLICT ("Id") clause
-- would never be reached: the insert would fail on the Slug uniqueness violation and, with
-- ON_ERROR_STOP, take the whole seed run down with it. Targeting Slug leaves the live tenant
-- untouched - which is what we want - and still places the row on an empty database.
-- Do not "fix" this back to ("Id").

INSERT INTO public.tenants ("Id", "Slug", "Name", "Status", "CreatedAt", "UpdatedAt")
VALUES (
    '019e03e9-60dd-72da-bd01-648ffdb2b433',
    'platform',
    'Platform',
    'Active',
    now(),
    now()
)
ON CONFLICT ("Slug") DO NOTHING;
