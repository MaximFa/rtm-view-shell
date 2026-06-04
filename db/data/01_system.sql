-- 01_system.sql: Platform tenant + Superadmin
SET session_replication_role = replica;

-- tenants
TRUNCATE TABLE "tenants" RESTART IDENTITY CASCADE;
COPY "tenants" FROM stdin;
019e03e9-60dd-72da-bd01-648ffdb2b433	platform	Platform	Active	2026-05-07 22:28:06.878546+03	2026-05-27 13:34:23.732665+03
\.

-- tenant_settings
TRUNCATE TABLE "tenant_settings" RESTART IDENTITY CASCADE;
COPY "tenant_settings" FROM stdin;
019e03e9-60dd-72da-bd01-648ffdb2b433	12	90	f	365	en-US	t	90	\N	\N	0	0	http://localhost:8088	["#FFFFFF","#F5F5F5","#E8F5E9","#FFF3E0","#FF0000","#11A90F","#333333","#8DE10E","#FFF700","#0998F1","#E202F2","#12EDDF","#F1EAEA"]	["#000000","#333333","#666666","#1976D2","#388E3C","#D32F2F","#7B1FA2","#5D4037","#FFFFFF"]	["10","11","12","13","14","16","18","20","24","28","32","64"]
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
019e03e9-614f-7761-936d-2518e4163950	019e03e9-60dd-72da-bd01-648ffdb2b433	System	Administrator	\N	t	f	2026-06-03 11:24:59.560813+03	en-US	\N	admin	ADMIN	admin@platform.local	ADMIN@PLATFORM.LOCAL	t	AQAAAAIAAYagAAAAEIlVs7ok5KeJTPNJE18pzriGq1M7QH7f7Gs2Qjdz8NxAo+auQ4i0ya/zL2xEHcRj4w==	BW6OLLJKUD3IA5BEWZ5MO4KEOYQD7MWZ	ecc649b4-8bc4-4efa-86bc-a23ccc4ad533	\N	f	f	\N	t	0
\.

-- identity.user_roles
TRUNCATE TABLE identity."user_roles" RESTART IDENTITY CASCADE;
COPY identity."user_roles" FROM stdin;
019e03e9-614f-7761-936d-2518e4163950	ec0fcb3b-d7c1-464b-9b09-d7368d0ca05f
\.

SET session_replication_role = DEFAULT;