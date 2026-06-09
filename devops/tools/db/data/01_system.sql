-- 01_system.sql: Platform tenant + Superadmin + EF migration history
SET session_replication_role = replica;

-- tenants
TRUNCATE TABLE "tenants" RESTART IDENTITY CASCADE;
COPY "tenants" FROM stdin;
019e03e9-60dd-72da-bd01-648ffdb2b433	platform	Platform	Active	2026-05-07 22:28:06.878546+03	2026-06-07 00:53:26.852804+03
\.

-- tenant_settings
TRUNCATE TABLE "tenant_settings" RESTART IDENTITY CASCADE;
COPY "tenant_settings" FROM stdin;
019e03e9-60dd-72da-bd01-648ffdb2b433	12	90	f	365	ru-RU	t	90	\N	\N	0	0	http://localhost:8088	["#FFFFFF","#F5F5F5","#E8F5E9","#FFF3E0","#FF0000","#11A90F","#333333","#8DE10E","#FFF700","#0998F1","#E202F2","#12EDDF","#F1EAEA"]	["#000000","#333333","#666666","#1976D2","#388E3C","#D32F2F","#7B1FA2","#5D4037","#FFFFFF"]	["10","11","12","13","14","16","18","20","24","28","32","64"]
\.

-- identity.roles
TRUNCATE TABLE identity."roles" RESTART IDENTITY CASCADE;
COPY identity."roles" FROM stdin;
ec0fcb3b-d7c1-464b-9b09-d7368d0ca05f	Superadmin	SUPERADMIN	\N
350a2e07-a8f6-41d7-b29d-5a75a693773a	Administrator	ADMINISTRATOR	\N
d07f6e69-7072-47c8-8d9a-a43899e6007e	Editor	EDITOR	\N
447f8e05-762d-4812-ac94-f5a60cf96d34	Viewer	VIEWER	\N
\.

-- identity.users
TRUNCATE TABLE identity."users" RESTART IDENTITY CASCADE;
COPY identity."users" FROM stdin;
019e03e9-614f-7761-936d-2518e4163950	019e03e9-60dd-72da-bd01-648ffdb2b433	System	Administrator	\N	t	f	2026-06-07 00:53:32.308462+03	en-US	\N	admin	ADMIN	admin@platform.local	ADMIN@PLATFORM.LOCAL	t	AQAAAAIAAYagAAAAEIlVs7ok5KeJTPNJE18pzriGq1M7QH7f7Gs2Qjdz8NxAo+auQ4i0ya/zL2xEHcRj4w==	BW6OLLJKUD3IA5BEWZ5MO4KEOYQD7MWZ	8a0c3e20-79fe-4272-8625-323e7d2ad2fb	\N	f	f	\N	t	0
\.

-- identity.user_roles
TRUNCATE TABLE identity."user_roles" RESTART IDENTITY CASCADE;
COPY identity."user_roles" FROM stdin;
019e03e9-614f-7761-936d-2518e4163950	ec0fcb3b-d7c1-464b-9b09-d7368d0ca05f
\.

-- __EFMigrationsHistory
TRUNCATE TABLE "__EFMigrationsHistory" RESTART IDENTITY CASCADE;
COPY "__EFMigrationsHistory" FROM stdin;
20260507105829_InitialCreate	8.0.11
20260507135314_InitialCreate	8.0.16
\.

-- __BackendEmulationMigrationsHistory
TRUNCATE TABLE "__BackendEmulationMigrationsHistory" RESTART IDENTITY CASCADE;
COPY "__BackendEmulationMigrationsHistory" FROM stdin;
20260525190044_InitialBackendSchema	8.0.16
20260525200130_AddQueueGridTables	8.0.16
20260526203609_AddRtsDataEntitiesAndStatusGroup	8.0.16
20260526214442_AddDayTrendFunctions	8.0.16
20260527170830_FixRtsGridMetricData	8.0.16
20260528100000_AddTrainingRtsGridMetric	8.0.16
20260528200000_AddUsersInStatusCountStateMetrics	8.0.16
20260530185653_AddMissingRtmTables	8.0.16
20260603113300_RemoveRtsGridTemplateCell	8.0.0
20260603143239_FixNgcQueueClassificationId	8.0.16
20260606100233_AddCatalogueFieldsToRtsGridMetric	8.0.10
20260606202749_AddRtsGridMetricTranslation	8.0.16
20260606205958_AddNgcUserAgentgroup	8.0.16
\.

-- __ef_migrations_history
TRUNCATE TABLE "__ef_migrations_history" RESTART IDENTITY CASCADE;
COPY "__ef_migrations_history" FROM stdin;
20260507135247_InitialCreate	8.0.16
20260507191205_NgcConfiguration	8.0.16
20260508070300_RtsGridMetricCrossTenant	8.0.16
20260509063517_LicensingAndUserSessions	8.0.16
20260509092003_NgcQueueAgentGroupTables	8.0.16
20260510110123_AddDashboardCategory	8.0.16
20260510182755_AddSignalRConnectionUrlToTenantSettings	8.0.16
20260511130954_AddDashboardIsDarkMode	8.0.16
20260513084402_AddGridIdToDashboardWidget	8.0.16
20260513094211_AddRtsUserGridTables	8.0.16
20260513105023_ChangeGridIdToIdentityByDefault	8.0.16
20260513120913_AddTenantSettingsAppearance	8.0.16
20260513194331_AddValueTypeToRtsGridMetric	8.0.16
20260513195301_AddMetricValueAndMetricType	8.0.16
20260514080241_AddWidgetTemplates	8.0.16
20260515231936_RenameRtsGridMetricToPascalCase	8.0.16
20260515232925_RenameNgcTablesToPascalCase	8.0.16
20260525215453_SeparateBackendTablesToBeDb	8.0.16
20260525223134_SeparateBackendTablesToBeDb	8.0.16
20260527150112_AddHistoryMetricTable	8.0.16
20260528043639_AddAgentStateRegistry	8.0.16
20260529054939_AddInfoSlotTables	8.0.16
20260605145919_AddUserWidgetSettings	8.0.16
\.

SET session_replication_role = DEFAULT;