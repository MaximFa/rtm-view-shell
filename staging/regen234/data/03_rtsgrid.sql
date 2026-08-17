-- 03_rtsgrid.sql: RTSGrid and RTSUserGrid widget definitions
SET session_replication_role = replica;

-- RTSGrid_Grid
TRUNCATE TABLE "RTSGrid_Grid" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Grid" FROM stdin;
49	-1	1		\N
47	-1	1		\N
51	-1	1	╫í╫ö"╫¢ ╫⌐╫Ö╫ù╫ò╫¬ ╫É╫ò╫á╫£╫Ö╫Ö╫ƒ - ╫æ╫ò╫ÿ ╫º╫ò╫£╫Ö	\N
50	-1	1	╫í╫ö"╫¢ ╫⌐╫Ö╫ù╫ò╫¬ ╫á╫¢╫á╫í╫ò - ╫æ╫ò╫ÿ	\N
52	-1	1		\N
53	-1	1	╫í╫ö"╫¢ ╫⌐╫Ö╫ù╫ò╫¬ ╫⌐╫á╫¢╫á╫í╫ò ╫£╫æ╫ò╫ÿ	\N
54	-1	1		\N
55	-1	1	Queue Grid	\N
29	-1	1	Queue Grid	\N
31	-1	1		\N
32	-1	1		\N
39	-1	1	╫ö╫ò╫ó╫æ╫¿ ╫£╫á╫ª╫Ö╫Æ	\N
38	-1	1	╫í╫ö"╫¢ ╫⌐╫Ö╫ù╫ò╫¬ ╫á╫¢╫á╫í╫ò ╫£╫æ╫ò╫ÿ	\N
37	-1	1	╫í╫ö"╫¢ ╫⌐╫Ö╫ù╫ò╫¬ ╫É╫ò╫ƒ ╫£╫Ö╫Ö╫ƒ ╫æ╫ò╫ÿ ╫º╫ò╫£╫Ö	\N
40	-1	1	╫á╫⌐╫£╫ù ╫£╫Ö╫á╫º	\N
41	-1	1	╫ö╫í╫¬╫Ö╫Ö╫₧╫ò ╫æ╫æ╫ò╫ÿ	\N
42	-1	1	╫á╫á╫ÿ╫⌐ ╫æ╫æ╫ò╫ÿ	\N
43	-1	1	123	\N
58	-1	1		\N
44	-1	1	Queue Grid	\N
45	-1	1	Queue Grid	\N
46	-1	1	Queue Grid	\N
48	-1	1		\N
60	-1	1		\N
61	-1	1		\N
62	-1	1		\N
63	-1	1		\N
64	-1	1		\N
\.

-- RTSGrid_Row
TRUNCATE TABLE "RTSGrid_Row" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Row" FROM stdin;
190	29	1	-1	1	\N	\N
191	29	2	78	1	\N	\N
192	29	3	74	1	\N	\N
193	29	4	76	1	\N	\N
194	29	5	58	1	\N	\N
195	29	6	77	1	\N	\N
197	31	1	78	1	\N	\N
198	32	1	78	1	\N	\N
272	58	1	78	1	\N	\N
215	39	1	\N	1	\N	\N
274	60	1	78	1	\N	\N
275	61	1	78	1	\N	\N
276	62	1	78	1	\N	\N
277	63	1	78	1	\N	\N
214	38	1	\N	1	\N	\N
213	37	1	\N	1	\N	\N
216	40	1	\N	1	\N	\N
217	41	1	\N	1	\N	\N
218	42	1	\N	1	\N	\N
219	43	1	\N	1	\N	\N
278	64	1	78	1	\N	\N
220	44	1	-1	1	\N	\N
221	44	2	\N	1	\N	\N
222	44	3	\N	1	\N	\N
223	45	1	-1	1	\N	\N
224	45	2	\N	1	\N	\N
225	45	3	\N	1	\N	\N
226	45	4	\N	1	\N	\N
227	45	5	\N	1	\N	\N
228	45	6	\N	1	\N	\N
229	45	7	\N	1	\N	\N
230	45	8	\N	1	\N	\N
231	45	9	\N	1	\N	\N
232	45	10	\N	1	\N	\N
233	45	11	\N	1	\N	\N
234	46	1	-1	1	\N	\N
235	46	2	78	1	\N	\N
236	46	3	74	1	\N	\N
237	46	4	76	1	\N	\N
238	46	5	58	1	\N	\N
239	46	6	77	1	\N	\N
241	48	1	78	1	\N	\N
242	49	1	78	1	\N	\N
240	47	1	78	1	\N	\N
244	51	1	78	1	\N	\N
243	50	1	78	1	\N	\N
245	52	1	78	1	\N	\N
246	53	1	78	1	\N	\N
247	54	1	78	1	\N	\N
248	55	1	-1	1	\N	\N
249	55	2	60	1	\N	\N
250	55	3	61	1	\N	\N
251	55	4	63	1	\N	\N
252	55	5	\N	1	\N	\N
\.

-- RTSGrid_Column
TRUNCATE TABLE "RTSGrid_Column" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Column" FROM stdin;
568	51	1	568
500	31	1	500
567	50	1	567
569	52	1	569
536	39	1	536
501	32	1	501
570	53	1	570
535	38	1	535
534	37	1	534
537	40	1	537
538	41	1	538
539	42	1	539
540	43	1	540
571	54	1	571
572	55	1	572
573	55	2	573
492	29	1	492
493	29	2	493
494	29	3	494
495	29	4	495
496	29	5	496
497	29	6	497
574	55	3	574
575	55	4	575
576	55	5	576
541	44	1	541
542	44	2	542
543	44	3	543
544	44	4	544
545	44	5	545
546	45	1	546
547	45	2	547
548	45	3	548
549	45	4	549
550	45	5	550
551	45	6	551
552	45	7	552
553	45	8	553
554	45	9	554
555	45	10	555
556	45	11	556
557	45	12	557
558	46	1	558
559	46	2	559
560	46	3	560
561	46	4	561
562	46	5	562
563	46	6	563
577	55	6	577
565	48	1	565
566	49	1	566
564	47	1	564
615	58	1	615
617	60	1	617
618	61	1	618
619	62	1	619
620	63	1	620
621	64	1	621
\.

-- RTSGrid_Cell
TRUNCATE TABLE "RTSGrid_Cell" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Cell" FROM stdin;
1097	216	537	1	-1	3	Data	QueueNumActiveInteractions	\N	\N	0	\N	\N
1100	219	540	1	-1	3	Data	QueueNumAbandonedCalls	\N	\N	0	\N	\N
1116	223	546	1	-1	3	Text	QM - Messages Avg First Response Time	\N	\N	0	\N	\N
1117	223	547	2	-1	3	Text	QM - Messages Avg Response Time	\N	\N	0	\N	\N
1118	223	548	3	-1	3	Text	QM - Messages Max First Response Time	\N	\N	0	\N	\N
1119	223	549	4	-1	3	Text	Agent Group - Number of Dialer Calls	\N	\N	0	\N	\N
1120	223	550	5	-1	3	Text	Agent Group - Number of Answered Incoming Calls and Callbacks	\N	\N	0	\N	\N
857	171	471	1	-1	3	Data	QueueNumIncomingOnlineCalls	\N	\N	0	\N	\N
879	171	478	7	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
859	171	473	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
860	171	474	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
861	171	475	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
862	171	476	6	-1	3	Data	QueueNumIcomingOnlineInteractions	\N	\N	0	\N	\N
880	171	479	8	-1	3	Data		\N	\N	0	\N	\N
863	172	471	1	-1	3	Data	QueueNumIncomingOnlineCalls	\N	\N	0	\N	\N
882	172	478	7	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
865	172	473	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
866	172	474	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
867	172	475	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
868	172	476	6	-1	3	Data	QueueNumIcomingOnlineInteractions	\N	\N	0	\N	\N
883	172	479	8	-1	3	Data		\N	\N	0	\N	\N
869	173	471	1	-1	3	Data	QueueNumIncomingOnlineCalls	\N	\N	0	\N	\N
885	173	478	7	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
871	173	473	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
872	173	474	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
873	173	475	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
874	173	476	6	-1	3	Data	QueueNumIcomingOnlineInteractions	\N	\N	0	\N	\N
886	173	479	8	-1	3	Data		\N	\N	0	\N	\N
1121	223	551	6	-1	3	Text		\N	\N	0	\N	\N
1122	223	552	7	-1	3	Text		\N	\N	0	\N	\N
1123	223	553	8	-1	3	Text		\N	\N	0	\N	\N
1124	223	554	9	-1	3	Text		\N	\N	0	\N	\N
1125	223	555	10	-1	3	Text		\N	\N	0	\N	\N
1126	223	556	11	-1	3	Text		\N	\N	0	\N	\N
1023	195	492	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1024	195	493	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1025	195	494	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
991	190	492	1	-1	3	Text	Waiting	\N	\N	0	\N	\N
1127	223	557	12	-1	3	Text		\N	\N	0	\N	\N
1026	195	495	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1009	192	496	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1010	192	497	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1011	193	492	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1012	193	493	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1013	193	494	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1128	224	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1027	195	496	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1129	224	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1028	195	497	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
992	190	493	2	-1	3	Text	Wait Time	\N	\N	0	\N	\N
993	190	494	3	-1	3	Text	Answered	\N	\N	0	\N	\N
994	190	495	4	-1	3	Text	logged In	\N	\N	0	\N	\N
995	190	496	5	-1	3	Text	Available	\N	\N	0	\N	\N
996	190	497	6	-1	3	Text	Incoming	\N	\N	0	\N	\N
997	191	492	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
998	191	493	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
999	191	494	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1000	191	495	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1001	191	496	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1002	191	497	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1005	192	492	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1006	192	493	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1014	193	495	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1015	193	496	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1016	193	497	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1017	194	492	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1018	194	493	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1019	194	494	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1020	194	495	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1021	194	496	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1022	194	497	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1130	224	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1131	224	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1132	224	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1133	224	551	6	-1	3	Data		\N	\N	0	\N	\N
1134	224	552	7	-1	3	Data		\N	\N	0	\N	\N
1031	198	501	1	-1	3	Data	QueueNumIcomingOnlineInteractions	\N	\N	0	\N	\N
1007	192	494	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1008	192	495	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1094	213	534	1	-1	3	Data	QueueNumActiveInteractions	\N	\N	0	\N	\N
1098	217	538	1	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1099	218	539	1	-1	3	Data	QueueNumAbandonedInteractions	\N	\N	0	\N	\N
1421	274	617	1	-1	3	Data	QueuePctAnsweredCalls30secInc	\N	\N	0	\N	\N
1096	215	536	1	-1	3	Data	QueueNumIncomingCompletedInteractions	\N	\N	0	\N	\N
1095	214	535	1	-1	3	Data	QueueNumAnsweredInteractions	\N	\N	0	\N	\N
1101	220	541	1	-1	3	Text	First Response Time	\N	\N	0	\N	\N
1102	220	542	2	-1	3	Text	 Avg Response Time	\N	\N	0	\N	\N
1103	220	543	3	-1	3	Text	 Max First Response Time	\N	\N	0	\N	\N
1104	220	544	4	-1	3	Text	 Number of Dialer Calls	\N	\N	0	\N	\N
1105	220	545	5	-1	3	Text	Number of Answered Incoming Calls and Callbacks	\N	\N	0	\N	\N
1106	221	541	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1107	221	542	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1108	221	543	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1109	221	544	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1110	221	545	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1111	222	541	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1112	222	542	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1113	222	543	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1114	222	544	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1115	222	545	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1135	224	553	8	-1	3	Data		\N	\N	0	\N	\N
1136	224	554	9	-1	3	Data		\N	\N	0	\N	\N
1137	224	555	10	-1	3	Data		\N	\N	0	\N	\N
1138	224	556	11	-1	3	Data		\N	\N	0	\N	\N
1139	224	557	12	-1	3	Data		\N	\N	0	\N	\N
1140	225	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1141	225	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1142	225	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1143	225	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1144	225	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1145	225	551	6	-1	3	Data		\N	\N	0	\N	\N
1146	225	552	7	-1	3	Data		\N	\N	0	\N	\N
1147	225	553	8	-1	3	Data		\N	\N	0	\N	\N
1148	225	554	9	-1	3	Data		\N	\N	0	\N	\N
1149	225	555	10	-1	3	Data		\N	\N	0	\N	\N
1150	225	556	11	-1	3	Data		\N	\N	0	\N	\N
1151	225	557	12	-1	3	Data		\N	\N	0	\N	\N
1152	226	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1153	226	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1154	226	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1155	226	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1156	226	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1157	226	551	6	-1	3	Data		\N	\N	0	\N	\N
1158	226	552	7	-1	3	Data		\N	\N	0	\N	\N
1159	226	553	8	-1	3	Data		\N	\N	0	\N	\N
1160	226	554	9	-1	3	Data		\N	\N	0	\N	\N
1161	226	555	10	-1	3	Data		\N	\N	0	\N	\N
1162	226	556	11	-1	3	Data		\N	\N	0	\N	\N
1163	226	557	12	-1	3	Data		\N	\N	0	\N	\N
1164	227	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1165	227	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1166	227	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1167	227	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1168	227	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1169	227	551	6	-1	3	Data		\N	\N	0	\N	\N
1170	227	552	7	-1	3	Data		\N	\N	0	\N	\N
1171	227	553	8	-1	3	Data		\N	\N	0	\N	\N
1172	227	554	9	-1	3	Data		\N	\N	0	\N	\N
1173	227	555	10	-1	3	Data		\N	\N	0	\N	\N
1174	227	556	11	-1	3	Data		\N	\N	0	\N	\N
1175	227	557	12	-1	3	Data		\N	\N	0	\N	\N
1176	228	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1177	228	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1178	228	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1179	228	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1180	228	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1181	228	551	6	-1	3	Data		\N	\N	0	\N	\N
1182	228	552	7	-1	3	Data		\N	\N	0	\N	\N
1183	228	553	8	-1	3	Data		\N	\N	0	\N	\N
1184	228	554	9	-1	3	Data		\N	\N	0	\N	\N
1185	228	555	10	-1	3	Data		\N	\N	0	\N	\N
1186	228	556	11	-1	3	Data		\N	\N	0	\N	\N
1187	228	557	12	-1	3	Data		\N	\N	0	\N	\N
1188	229	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1189	229	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1190	229	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1191	229	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1192	229	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1193	229	551	6	-1	3	Data		\N	\N	0	\N	\N
1194	229	552	7	-1	3	Data		\N	\N	0	\N	\N
1195	229	553	8	-1	3	Data		\N	\N	0	\N	\N
1196	229	554	9	-1	3	Data		\N	\N	0	\N	\N
1197	229	555	10	-1	3	Data		\N	\N	0	\N	\N
1198	229	556	11	-1	3	Data		\N	\N	0	\N	\N
1199	229	557	12	-1	3	Data		\N	\N	0	\N	\N
1200	230	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1201	230	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1202	230	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1203	230	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1204	230	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1205	230	551	6	-1	3	Data		\N	\N	0	\N	\N
1206	230	552	7	-1	3	Data		\N	\N	0	\N	\N
1207	230	553	8	-1	3	Data		\N	\N	0	\N	\N
1208	230	554	9	-1	3	Data		\N	\N	0	\N	\N
1209	230	555	10	-1	3	Data		\N	\N	0	\N	\N
1210	230	556	11	-1	3	Data		\N	\N	0	\N	\N
1211	230	557	12	-1	3	Data		\N	\N	0	\N	\N
1212	231	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1213	231	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1214	231	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1215	231	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1216	231	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1217	231	551	6	-1	3	Data		\N	\N	0	\N	\N
1218	231	552	7	-1	3	Data		\N	\N	0	\N	\N
1219	231	553	8	-1	3	Data		\N	\N	0	\N	\N
1220	231	554	9	-1	3	Data		\N	\N	0	\N	\N
1221	231	555	10	-1	3	Data		\N	\N	0	\N	\N
1222	231	556	11	-1	3	Data		\N	\N	0	\N	\N
1223	231	557	12	-1	3	Data		\N	\N	0	\N	\N
1224	232	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1225	232	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1226	232	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1227	232	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1228	232	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1229	232	551	6	-1	3	Data		\N	\N	0	\N	\N
1230	232	552	7	-1	3	Data		\N	\N	0	\N	\N
1231	232	553	8	-1	3	Data		\N	\N	0	\N	\N
1232	232	554	9	-1	3	Data		\N	\N	0	\N	\N
1233	232	555	10	-1	3	Data		\N	\N	0	\N	\N
1234	232	556	11	-1	3	Data		\N	\N	0	\N	\N
1235	232	557	12	-1	3	Data		\N	\N	0	\N	\N
1236	233	546	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1237	233	547	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1238	233	548	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1239	233	549	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1240	233	550	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1241	233	551	6	-1	3	Data		\N	\N	0	\N	\N
1242	233	552	7	-1	3	Data		\N	\N	0	\N	\N
1243	233	553	8	-1	3	Data		\N	\N	0	\N	\N
1244	233	554	9	-1	3	Data		\N	\N	0	\N	\N
1245	233	555	10	-1	3	Data		\N	\N	0	\N	\N
1246	233	556	11	-1	3	Data		\N	\N	0	\N	\N
1247	233	557	12	-1	3	Data		\N	\N	0	\N	\N
1248	234	558	1	-1	3	Text	Waiting	\N	\N	0	\N	\N
1249	234	559	2	-1	3	Text	Wait Time	\N	\N	0	\N	\N
1250	234	560	3	-1	3	Text	Answered	\N	\N	0	\N	\N
1251	234	561	4	-1	3	Text	logged In	\N	\N	0	\N	\N
1252	234	562	5	-1	3	Text	Available	\N	\N	0	\N	\N
1253	234	563	6	-1	3	Text	Incoming	\N	\N	0	\N	\N
1254	235	558	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1255	235	559	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1256	235	560	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1257	235	561	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1258	235	562	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1259	235	563	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1260	236	558	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1261	236	559	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1262	236	560	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1263	236	561	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1264	236	562	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1265	236	563	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1266	237	558	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1267	237	559	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1268	237	560	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1269	237	561	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1270	237	562	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1271	237	563	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1272	238	558	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1273	238	559	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1274	238	560	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1275	238	561	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1276	238	562	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1277	238	563	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1278	239	558	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1279	239	559	2	-1	3	Data	QueueCurMaxWaitTimeCalls	\N	\N	0	\N	\N
1280	239	560	3	-1	3	Data	QueueNumAnsweredCallsAndCallbacks	\N	\N	0	\N	\N
1281	239	561	4	-1	3	Data	QueueLoginDataNumLoggedUsers	\N	\N	0	\N	\N
1282	239	562	5	-1	3	Data	QueueLoginDataNumAvailableUsers	\N	\N	0	\N	\N
1283	239	563	6	-1	3	Data	QueueNumIncomingOnlineCallsAndCallbacks	\N	\N	0	\N	\N
1285	241	565	1	-1	3	Data	QueuePctAbandonedCallsTotal	\N	\N	0	\N	\N
1286	242	566	1	-1	3	Data	QueuePctAbandonedCallsTotal	\N	\N	0	\N	\N
1284	240	564	1	-1	3	Data	QueueNumIcomingOnlineInteractions	\N	\N	0	\N	\N
1288	244	568	1	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1422	275	618	1	-1	3	Data	QueueAvgTalkingDurationCalls	\N	\N	0	\N	\N
1287	243	567	1	-1	3	Data	QueueNumIncomingOnlineCalls	\N	\N	0	\N	\N
1289	245	569	1	-1	3	Data	QueuePctAbandonedCallsTotal	\N	\N	0	\N	\N
1290	246	570	1	-1	3	Data	QueueNumActiveCalls	\N	\N	0	\N	\N
1291	247	571	1	-1	3	Data	QueueNumWaitingCalls	\N	\N	0	\N	\N
1292	248	572	1	-1	3	Text	QM - Messages Avg First Response Time	\N	\N	0	\N	\N
1293	248	573	2	-1	3	Text	QM - Messages Avg Response Time	\N	\N	0	\N	\N
1294	248	574	3	-1	3	Text	QM - Messages Max First Response Time	\N	\N	0	\N	\N
1295	248	575	4	-1	3	Text	Agent Group - Number of Dialer Calls	\N	\N	0	\N	\N
1296	248	576	5	-1	3	Text	Agent Group - Number of Answered Incoming Calls and Callbacks	\N	\N	0	\N	\N
1297	248	577	6	-1	3	Text		\N	\N	0	\N	\N
1298	249	572	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1299	249	573	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1300	249	574	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1301	249	575	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1302	249	576	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1303	249	577	6	-1	3	Data		\N	\N	0	\N	\N
1304	250	572	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1305	250	573	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1306	250	574	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1307	250	575	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1308	250	576	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1309	250	577	6	-1	3	Data		\N	\N	0	\N	\N
1310	251	572	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1311	251	573	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1312	251	574	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1313	251	575	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1315	251	577	6	-1	3	Data		\N	\N	0	\N	\N
1314	251	576	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1316	252	572	1	-1	3	Data	MessagesAvgFirstResponseTime	\N	\N	0	\N	\N
1319	252	575	4	-1	3	Data	MonAgentNumberOfInboundCallsDialer	\N	\N	0	\N	\N
1423	276	619	1	-1	3	Data	MonSumAgentsAverageCallDuration	\N	\N	0	\N	\N
1317	252	573	2	-1	3	Data	MessagesAvgResponseTime	\N	\N	0	\N	\N
1320	252	576	5	-1	3	Data	MonSumAgentsAnsweredCalls	\N	\N	0	\N	\N
1424	277	620	1	-1	3	Data	QueuePctAnsweredCalls60secInc	\N	\N	0	\N	\N
1318	252	574	3	-1	3	Data	MessagesMaxFirstResponseTime	\N	\N	0	\N	\N
1321	252	577	6	-1	3	Data		\N	\N	0	\N	\N
1425	278	621	1	-1	3	Data	QueueAvgTalkingDurationCalls	\N	\N	0	\N	\N
1030	197	500	1	-1	3	Data	QueuePctAbandonedCallsTotal	\N	\N	0	\N	\N
1419	272	615	1	-1	3	Data	QueuePctAbandonedCallsTotal	\N	\N	0	\N	\N
\.

-- RTSUserGrid_ColumnsSet
TRUNCATE TABLE "RTSUserGrid_ColumnsSet" RESTART IDENTITY CASCADE;
COPY "RTSUserGrid_ColumnsSet" FROM stdin;
7	Agent Grid Support	Agent Grid Support	\N
9	Agent Grid Support	Agent Grid Support	\N
\.

-- RTSUserGrid_Grid
TRUNCATE TABLE "RTSUserGrid_Grid" RESTART IDENTITY CASCADE;
COPY "RTSUserGrid_Grid" FROM stdin;
7	78	1	Agent Grid Support	[MonAgentState] != "SIGNOFF"	40	7	\N	[MonAgentState] != "SIGNOFF"	\N	\N	\N	\N
9	78	1	Agent Grid Support	[MonAgentState] != "Logged Out"	40	9	\N	[MonAgentState] != "Logged Out"	\N	\N	\N	\N
\.

-- RTSUserGrid_Column
TRUNCATE TABLE "RTSUserGrid_Column" RESTART IDENTITY CASCADE;
COPY "RTSUserGrid_Column" FROM stdin;
66	7	Incoming	MonAgentNumMakeCallsInCompleted	\N	5
87	7	Incoming	MonAgentNumberOfInboundCallsWithIntercom	\N	7
47	7	Agent	AgentLoginName	\N	0
48	7	State	MonAgentState	\N	1
55	7	Phone Number	RemotePhoneNumber	\N	2
49	7	Duration	MonAgentStateDuration	\N	3
50	7	TALK %	MonAgentTalkDurationPct	\N	4
52	7	Avg Talk	MonAgentAverageInboundCallDuration	\N	6
75	9	Agent	AgentLoginName	\N	0
76	9	State	MonAgentState	\N	1
77	9	Duration	MonAgentStateDuration	\N	2
78	9	TALK %	MonAgentTalkDurationPct	\N	3
79	9	Incoming	MonAgentNumMakeCallsInCompleted	\N	4
80	9	Avg Talk	MonAgentAverageInboundCallDuration	\N	5
\.

SET session_replication_role = DEFAULT;