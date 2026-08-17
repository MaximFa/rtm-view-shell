-- 04_catalog.sql: NGC site definitions (RTM-only)
SET session_replication_role = replica;

-- NGC_Site
TRUNCATE TABLE "NGC_Site" RESTART IDENTITY CASCADE;
COPY "NGC_Site" FROM stdin;
IL	019e03e9-60dd-72da-bd01-648ffdb2b433	Israel	Israel	+02:00	00:00
SITE001	019e03e9-60dd-72da-bd01-648ffdb2b433	Main Office	Primary contact center	+03:00	00:00
SITE002	019e03e9-60dd-72da-bd01-648ffdb2b433	Remote Office	Secondary location	+02:00	00:00
\.

SET session_replication_role = DEFAULT;