-- Migration: 20260605_003_add_user_widget_settings
-- Creates user_widget_settings table for per-user widget view preferences.
-- Replaces browser localStorage — settings are server-side, cross-device.
-- Idempotent: safe to run multiple times.

CREATE TABLE IF NOT EXISTS "user_widget_settings" (
    "Id"           uuid        NOT NULL,
    "TenantId"     uuid        NOT NULL,
    "UserId"       uuid        NOT NULL,
    "WidgetId"     uuid        NOT NULL,
    "SettingsJson" jsonb       NOT NULL DEFAULT '{}',
    "CreatedAt"    timestamptz NOT NULL,
    "UpdatedAt"    timestamptz NOT NULL,
    CONSTRAINT "PK_user_widget_settings" PRIMARY KEY ("Id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "IX_user_widget_settings_TenantId_UserId_WidgetId"
    ON "user_widget_settings" ("TenantId", "UserId", "WidgetId");

-- Verify
SELECT COUNT(*) AS table_exists
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name   = 'user_widget_settings';
