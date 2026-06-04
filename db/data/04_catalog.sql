-- 04_catalog.sql: Widget catalog and NGC site definitions
SET session_replication_role = replica;

-- widget_catalog
TRUNCATE TABLE "widget_catalog" RESTART IDENTITY CASCADE;
COPY "widget_catalog" FROM stdin;
019e12be-deb1-76af-8002-a20588771003	Agents	Agent Grid	Real-time agent table with states, durations, metrics and alerts	\N	t
019e21aa-8f87-714d-944b-f2579ca9cc0d	Queues	Queue Grid	Real-time queue metrics table with customizable rows and columns	\N	t
019e2683-49c1-7566-a0c6-d18df7a26957	General metrics	Data Slot	Single metric display with target comparison	\N	t
019e6655-6b5a-7460-b2fc-9f6c2fa9f6d8	General metrics	Day Trend Chart	Intraday call volume chart showing configured metrics broken down by time interval (15/30/60 min). Supports line, bar, area, and step chart types.	\N	t
a4d1e3f7-2b8c-4e9a-b1d5-6f3c2a7e0d11	Agents	Agent State Distribution	Real-time pie/donut/bar chart showing agent distribution across status groups (Available, On Phone, Break, Paperwork, Training) for a selected Business Unit.	\N	t
019e7271-113a-715a-bb42-c1bc264b85d5	General metrics	Info Slot	Message display widget with ticker or sequential mode. Displays messages from a shell-managed Info Slot.	\N	t
\.

-- NGC_Site
TRUNCATE TABLE "NGC_Site" RESTART IDENTITY CASCADE;
COPY "NGC_Site" FROM stdin;
IL	019e03e9-60dd-72da-bd01-648ffdb2b433	Israel	Israel	+02:00	00:00
\.

SET session_replication_role = DEFAULT;