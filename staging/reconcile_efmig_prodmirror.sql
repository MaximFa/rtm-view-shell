-- Prod-mirror DB: baseline __EFMigrationsHistory to the full v3 (HEAD) migration set.
-- ALL 26 migrations' objects already exist (restored 234 b58e2c2 backup + new-migration objects present);
-- history was empty -> MigrateAsync crashed on InitialCreate. Record all as applied so migrate no-ops.
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
('20260605145919_AddUserWidgetSettings','8.0.16'),
('20260621080000_AddHistoricalReportsTables','8.0.16'),
('20260622090000_AddArchiveTables','8.0.16'),
('20260622100000_UserReportSoftDelete','8.0.16'),
('20260624093015_AddReportEntities','8.0.16')
ON CONFLICT ("MigrationId") DO NOTHING;