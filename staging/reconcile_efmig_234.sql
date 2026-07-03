-- ============================================================================
-- 234 CONVERGE-DEPLOY: EF-history reconcile (baseline to b58e2c2 state)
-- Run as POSTGRES on 234, BEFORE the new Shell's first start (MigrateAsync).
-- (Update-RTMView does NOT call EF migrate - coordinator-verified 2026-07-03;
--  the new Shell's startup MigrateAsync is the migrate trigger.)
-- 234 has all 24 CC tables + baseline objects; the 4 reports-v1 objects are ABSENT.
-- __EFMigrationsHistory holds 2 non-matching junk InitialCreate rows -> without this
-- baseline, MigrateAsync retries InitialCreate -> 'relation already exists' -> crash (SS38.6).
-- Insert the 22 b58e2c2 App MigrationIds so migrate applies ONLY the 4 reports-v1.
-- The 2 junk rows are LEFT as-is (unknown IDs; EF ignores them).
-- Idempotent: ON CONFLICT DO NOTHING.
-- ============================================================================
INSERT INTO "__EFMigrationsHistory" ("MigrationId","ProductVersion") VALUES
('20260507135247_InitialCreate','8.0.16'),
('20260507191205_NgcConfiguration','8.0.16'),
('20260508070300_RtsGridMetricCrossTenant','8.0.16'),
('20260509063517_LicensingAndUserSessions','8.0.16'),
('20260509092003_NgcQueueAgentGroupTables','8.0.16'),
('20260510110123_AddDashboardCategory','8.0.16'),
('20260510182755_AddSignalRConnectionUrlToTenantSettings','8.0.16'),
('20260511130954_AddDashboardIsDarkMode','8.0.16'),
('20260513084402_AddGridIdToDashboardWidget','8.0.16'),
('20260513094211_AddRtsUserGridTables','8.0.16'),
('20260513105023_ChangeGridIdToIdentityByDefault','8.0.16'),
('20260513120913_AddTenantSettingsAppearance','8.0.16'),
('20260513194331_AddValueTypeToRtsGridMetric','8.0.16'),
('20260513195301_AddMetricValueAndMetricType','8.0.16'),
('20260514080241_AddWidgetTemplates','8.0.16'),
('20260515231936_RenameRtsGridMetricToPascalCase','8.0.16'),
('20260515232925_RenameNgcTablesToPascalCase','8.0.16'),
('20260525223134_SeparateBackendTablesToBeDb','8.0.16'),
('20260527150112_AddHistoryMetricTable','8.0.16'),
('20260528043639_AddAgentStateRegistry','8.0.16'),
('20260529054939_AddInfoSlotTables','8.0.16'),
('20260605145919_AddUserWidgetSettings','8.0.16')
ON CONFLICT ("MigrationId") DO NOTHING;

-- verify (expect >= 24 = 2 junk + 22 baseline; report_screens still NULL pre-migrate)
SELECT count(*) AS efmig_count FROM "__EFMigrationsHistory";
SELECT to_regclass('public.report_screens') AS report_screens_should_be_null;
