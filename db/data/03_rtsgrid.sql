-- 03_rtsgrid.sql: RTSGrid and RTSUserGrid widget definitions
SET session_replication_role = replica;

-- RTSGrid_Grid
TRUNCATE TABLE "RTSGrid_Grid" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Grid" FROM stdin;
1	-1	1	Queue Grid	\N
\.

-- RTSGrid_Row
TRUNCATE TABLE "RTSGrid_Row" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Row" FROM stdin;
1	1	1	-1	1	\N	\N
\.

-- RTSGrid_Column
TRUNCATE TABLE "RTSGrid_Column" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Column" FROM stdin;
1	1	1	1
2	1	2	2
3	1	3	3
4	1	4	4
5	1	5	5
\.

-- RTSGrid_Cell
TRUNCATE TABLE "RTSGrid_Cell" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Cell" FROM stdin;
1	1	1	1	-1	3	Text	QM - Messages Avg First Response Time	\N	\N	0	\N	\N
2	1	2	2	-1	3	Text	QM - Messages Avg Response Time	\N	\N	0	\N	\N
3	1	3	3	-1	3	Text	QM - Messages Max First Response Time	\N	\N	0	\N	\N
4	1	4	4	-1	3	Text	Agent Group - Number of Dialer Calls	\N	\N	0	\N	\N
5	1	5	5	-1	3	Text	Agent Group - Number of Answered Incoming Calls and Callbacks	\N	\N	0	\N	\N
\.

-- RTSUserGrid_ColumnsSet
TRUNCATE TABLE "RTSUserGrid_ColumnsSet" RESTART IDENTITY CASCADE;
COPY "RTSUserGrid_ColumnsSet" FROM stdin;
1	Agent Grid	Agent Grid	\N
\.

-- RTSUserGrid_Grid
TRUNCATE TABLE "RTSUserGrid_Grid" RESTART IDENTITY CASCADE;
COPY "RTSUserGrid_Grid" FROM stdin;
1	\N	1	Agent Grid	\N	40	1	\N	\N	\N	\N	\N	\N
\.

-- RTSUserGrid_Column
TRUNCATE TABLE "RTSUserGrid_Column" RESTART IDENTITY CASCADE;
COPY "RTSUserGrid_Column" FROM stdin;
1	1	Agent	AgentName	\N	0
2	1	State	AgentState	\N	1
3	1	Duration	AgentStateDuration	\N	2
4	1	OCC%	AgentOccupancy	\N	3
5	1	ADH%	AgentAdherence	\N	4
\.

SET session_replication_role = DEFAULT;