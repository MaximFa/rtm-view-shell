-- RTM View Shell - Database Baseline
-- Generated: 2026-06-04 16:25
-- Restore: psql -U ccdashboard_user -d rtmviewdb -f baseline.sql

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
TRUNCATE TABLE "identity.roles" RESTART IDENTITY CASCADE;
COPY "identity.roles" FROM stdin;
ec0fcb3b-d7c1-464b-9b09-d7368d0ca05f	Superadmin	SUPERADMIN	\N
350a2e07-a8f6-41d7-b29d-5a75a693773a	Administrator	ADMINISTRATOR	\N
d07f6e69-7072-47c8-8d9a-a43899e6007e	Editor	EDITOR	\N
447f8e05-762d-4812-ac94-f5a60cf96d34	Viewer	VIEWER	\N
\.

-- identity.users
TRUNCATE TABLE "identity.users" RESTART IDENTITY CASCADE;
COPY "identity.users" FROM stdin;
019e03e9-614f-7761-936d-2518e4163950	019e03e9-60dd-72da-bd01-648ffdb2b433	System	Administrator	\N	t	f	2026-06-03 11:24:59.560813+03	en-US	\N	admin	ADMIN	admin@platform.local	ADMIN@PLATFORM.LOCAL	t	AQAAAAIAAYagAAAAEIlVs7ok5KeJTPNJE18pzriGq1M7QH7f7Gs2Qjdz8NxAo+auQ4i0ya/zL2xEHcRj4w==	BW6OLLJKUD3IA5BEWZ5MO4KEOYQD7MWZ	ecc649b4-8bc4-4efa-86bc-a23ccc4ad533	\N	f	f	\N	t	0
\.

-- identity.user_roles
TRUNCATE TABLE "identity.user_roles" RESTART IDENTITY CASCADE;
COPY "identity.user_roles" FROM stdin;
019e03e9-614f-7761-936d-2518e4163950	ec0fcb3b-d7c1-464b-9b09-d7368d0ca05f
\.

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

-- RTSGrid_Metric
TRUNCATE TABLE "RTSGrid_Metric" RESTART IDENTITY CASCADE;
COPY "RTSGrid_Metric" FROM stdin;
QueueLoginDataNumTrainingUsers	Agent Group - Number of Agents in Training State Group	String	UsersInStatusGroupCount	TRAINING			number	Data
StateCountAvailable	Agent Group - Number of Agents in Available State	UsersSummary	UsersInStatusCount	Available		0	number	Data
StateCountOnPhone	Agent Group - Number of Agents in On Phone State	UsersSummary	UsersInStatusCount	On Phone		0	number	Data
StateCountBreak	Agent Group - Number of Agents in Break State	UsersSummary	UsersInStatusCount	Break		0	number	Data
StateCountPaperwork	Agent Group - Number of Agents in Paperwork State	UsersSummary	UsersInStatusCount	Paperwork		0	number	Data
StateCountTraining	Agent Group - Number of Agents in Training State	UsersSummary	UsersInStatusCount	Training		0	number	Data
MonSumAgentsBreakDurationMax	Agent Group - Max duration of  Break State Group	UsersSummary	UsersInStatusGroupDurationCurMax	BREAK	\N	\N	number	Data
QueueNumCompletedCallbacks	QM - Number of Completed Callbacks 	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Outgoing" && IsAnswered	\N	\N	number	Data
QueueNumAcceptedCallbacks	QM - Number of Accepted Callbacks 	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered	\N	\N	number	Data
QueueNumIncomingOnlineCalls	QM - Number of Incoming Calls including Waiting	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming"	\N	\N	number	Data
QueueNumIncomingOnlineCallbacks	QM - Number of Incoming Callbacks including Waiting	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming"	\N	\N	number	Data
QueueNumIncomingOnlineCallsAndCallbacks	QM - Number of Incoming Calls and Callbacks including Waiting	Interactions Summary	InteractionsCount	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming"	\N	\N	number	Data
QueueNumIncomingOnlineChats	QM - Number of Incoming Chats including Waiting	Interactions Summary	InteractionsCount	(InteractionType=="Chat")  && Direction == "Incoming"	\N	\N	number	Data
QueueNumIcomingOnlineInteractions	QM - Number of Incoming Interactions including Waiting	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueNumAbandonedCalls	QM - Number of Abandoned Calls	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest	\N	\N	number	Data
QueueNumAbandonedCallbacks	QM - Number of Abandoned Callbacks	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest	\N	\N	number	Data
QueueNumAbandonedCallsAndCallbacks	QM - Number of Abandoned Calls and Callbacks	Interactions Summary	InteractionsCount	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest	\N	\N	number	Data
QueueNumAbandonedChats	QM - Number of Abandoned Chats	Interactions Summary	InteractionsCount	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest	\N	\N	number	Data
QueueNumAbandonedInteractions	QM - Number of Abandoned Interactions	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueNumCallbackRequests	QM - Number of Callback Requests	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && IsCallbackRequest	\N	\N	number	Data
QueueNumAnsweredCalls	QM - Number of Answered Calls	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsAnswered	\N	\N	number	Data
QueueNumAnsweredCalls60sec	QM - Number of Answered Calls in 60 sec	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<60	\N	\N	number	Data
QueueBaseAnsweredPct	QM - Base Answered Percent	Interactions Summary	Calc	[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls]/[QueueNumIncomingOnlineCalls])	##0.0%	\N	number	Data
QueueExclCallbackReqAnsweredPct	QM - Excluding Callback Requests Answered Percent	Interactions Summary	Calc	([QueueNumIncomingOnlineCalls]-[QueueNumCallbackRequests])==0 ? 0 : ((double)[QueueNumAnsweredCalls]/([QueueNumIncomingOnlineCalls]-[QueueNumCallbackRequests])	##0.0%	\N	number	Data
QueueInclCallbackReqAnsweredPct	QM - Including Callback Requests Answered Percent	Interactions Summary	Calc	[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)([QueueNumAnsweredCalls]+[QueueNumCallbackRequests])/[QueueNumIncomingOnlineCalls])	##0.0%	\N	number	Data
QueueInclCompCallbacksAnsweredPct	QM - Including Completed Callbacks Answered Percent	Interactions Summary	Calc	[QueueNumIncomingOnlineCalls]==0 ? 0 : ((double)([QueueNumAnsweredCalls]+[QueueNumCompletedCallbacks])/[QueueNumIncomingOnlineCalls])	##0.0%	\N	number	Data
QueuePctAnsweredCalls60secIncLast30min	QM - Percent of Answered Calls in 60 sec Last 30 min from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls60sec]/[QueueNumIncomingCompletedCalls])&&InQueueDateTime>=DateTime.Now.AddHours(-0.5)	##0.0%	\N	number	Data
QueueNumOnlineChats	QM - Number of Chats	Interactions Summary	InteractionsCount	InteractionType=="Chat"	\N	\N	number	Data
QueuePctAbandonedCallbacksTotal	QM - Percent of Abandoned Callbacks	Interactions Summary	Calc	[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAbandonedCallbacks]/[QueueNumIncomingCompletedCallbacks])	##0.0%	\N	number	Data
QueueNumIncomingHandledInteractions	QM - Number of Completed Incoming Interactions	Interactions Summary	InteractionsCount	  (CallType=="External")  && Direction == "Incoming" && !IsTalk && !IsInQueue && !IsAbandoned && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueSLAIn30secFrom80PctInc	QM - Percent of Answered Calls in 30 sec from 80% Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec ]/([QueueNumIncomingCompletedCalls]*0.8))	##0.00%	\N	number	Data
QueueNumWrapUpAgents	QM - Number of Wpap Up Agents in Queue Skill	Interactions Summary	UsersInStatusCount	Wrap Up	\N	\N	number	Data
QueueNumAnsweredCallbacks	QM - Number of Answered Callbacks	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered	\N	\N	number	Data
QueueNumAnsweredCallsAndCallbacks	QM - Number of Answered Calls and Callbacks	Interactions Summary	InteractionsCount	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered	\N	\N	number	Data
QueueNumAnsweredChats	QM - Number of Answered Chats	Interactions Summary	InteractionsCount	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && IsAnswered	\N	\N	number	Data
QueueNumAnsweredInteractions	QM - Number of Answered Interactions	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && IsAnswered && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueNumIncomingCompletedCalls	QM - Number of Incoming Calls exluding Waiting	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && !IsCallbackRequest	\N	\N	number	Data
QueueNumberOfCompletedIncomingCalls	QM - Number of Completed Incoming Calls	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && !IsTalk	\N	\N	number	Data	Queue	\N	active	calls	Differs from QueueNumIncomingCompletedCalls: this counts calls whose interaction finished (not in queue AND not currently talking = disconnected); QueueNumIncomingCompletedCalls excludes callback requests instead of active talk.	Completed Incoming Calls Today	queue.volume.incoming_completed	Counts incoming external voice calls that have completed the interaction today - no longer in queue and not currently talking (i.e. disconnected). Distinct from QueueNumIncomingCompletedCalls, which counts calls that finished queuing (excludes callback requests) rather than fully-disconnected calls.	Number of incoming external voice calls that have completed the interaction today (not in queue and not currently talking = disconnected).	\N	\N	\N
QueueNumIncomingCompletedCallbacks	QM - Number of Incoming Callbacks exluding Waiting	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && !IsCallbackRequest	\N	\N	number	Data
QueueNumIncomingCompletedCallsAndCallbacks	QM - Number of Incoming Calls and Callbacks exluding Waiting	Interactions Summary	InteractionsCount	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && !IsCallbackRequest	\N	\N	number	Data
QueueNumIncomingCompletedChats	QM - Number of Incoming Chats exluding Waiting	Interactions Summary	InteractionsCount	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue  && !IsCallbackRequest	\N	\N	number	Data
QueueNumIncomingCompletedInteractions	QM - Number of Incoming Interactions exluding Waiting	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && !IsInQueue  && !IsCallbackRequest && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueNumWaitingCalls	QM - Number of Waiting Calls	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsInQueue	\N	\N	number	Data
QueueNumWaitingCallbacks	QM - Number of Waiting Callbacks	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsInQueue	\N	\N	number	Data
QueueNumWaitingCallsAndCallbacks	QM - Number of Waiting Calls and Callbacks	Interactions Summary	InteractionsCount	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsInQueue	\N	\N	number	Data
QueueNumWaitingChats	QM - Number of Waiting Chats	Interactions Summary	NumWaitings	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming"	\N	\N	number	Data
QueueNumWaitingInteractions	QM - Number of Waiting Interactions	Interactions Summary	NumWaitings	(CallType=="External")  && Direction == "Incoming" && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueuePctAnsweredCallsTotal	QM - Percent of Answered Calls	Interactions Summary	Calc	[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls]/[QueueNumIncomingCompletedCalls])	##0.0%	\N	number	Data
QueuePctAnsweredCallbacksTotal	QM - Percent of Answered Callbacks	Interactions Summary	Calc	[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks]/[QueueNumIncomingCompletedCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredCallsAndCallbacksTotal	QM - Percent of Answered Calls and Callbacks	Interactions Summary	Calc	[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks]/[QueueNumIncomingCompletedCallsAndCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredChatsTotal	QM - Percent of Answered Chats	Interactions Summary	Calc	[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats]/[QueueNumIncomingCompletedChats])	##0.0%	\N	number	Data
QueuePctAnsweredInteractionsTotal	QM - Percent of Answered Interactions	Interactions Summary	Calc	[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions]/[QueueNumIncomingCompletedInteractions])	##0.0%	\N	number	Data
QueuePctAbandonedCallsTotal	QM - Percent of Abandoned Calls	Interactions Summary	Calc	[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAbandonedCalls]/[QueueNumIncomingCompletedCalls])	##0.0%	\N	number	Data
QueuePctAbandonedCallsAndCallbacksTotal	QM - Percent of Abandoned Calls and Callbacks	Interactions Summary	Calc	[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAbandonedCallsAndCallbacks]/[QueueNumIncomingCompletedCallsAndCallbacks])	##0.0%	\N	number	Data
QueuePctAbandonedInteractionsTotal	QM - Percent of Abandoned Interactions	Interactions Summary	Calc	[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAbandonedInteractions]/[QueueNumIncomingCompletedInteractions])	##0.0%	\N	number	Data
QueuePctAbandonedChatsTotal	QM - Percent of Abandoned Chats	Interactions Summary	Calc	[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAbandonedChats]/[QueueNumIncomingCompletedChats])	##0.0%	\N	number	Data
QueueNumAnsweredCalls30sec	QM - Number of Answered Calls in 30 sec	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<30	\N	\N	number	Data
QueueNumAnsweredCallbacks30sec	QM - Number of Answered Callbacks in 30 sec	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered  && TimeInQueue<30	\N	\N	number	Data
QueueNumAnsweredCallsAndCallbacks30sec	QM - Number of Answered Calls and Callbacks in 30 sec	Interactions Summary	InteractionsCount	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<30	\N	\N	number	Data
QueueNumAnsweredChats30sec	QM - Number of Answered Chats in 30 sec	Interactions Summary	InteractionsCount	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<30	\N	\N	number	Data
QueueNumAnsweredInteractions30sec	QM - Number of Answered Interactions in 30 sec	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<30 && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueNumAnsweredCallbacks60sec	QM - Number of Answered Calls in 60 sec	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered  && TimeInQueue<60	\N	\N	number	Data
QueueNumAnsweredCallsAndCallbacks60sec	QM - Number of Answered Calls and Callbacks in 60 sec	Interactions Summary	InteractionsCount	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<60	\N	\N	number	Data
QueueNumAnsweredChats60sec	QM - Number of Answered Chats in 60 sec	Interactions Summary	InteractionsCount	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<60	\N	\N	number	Data
QueueNumAnsweredInteractions60sec	QM - Number of Answered Interactions in 60 sec	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<60 && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueNumAnsweredCalls120sec	QM - Number of Answered Calls in 120 sec	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<120	\N	\N	number	Data
QueueNumAnsweredCallbacks120sec	QM - Number of Answered Callbacks in 120 sec	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered  && TimeInQueue<120	\N	\N	number	Data
QueueNumAnsweredCallsAndCallbacks120sec	QM - Number of Answered Calls and Callbacks in 120 sec	Interactions Summary	InteractionsCount	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<120	\N	\N	number	Data
QueueNumAnsweredChats120sec	QM - Number of Answered Chats in 120 sec	Interactions Summary	InteractionsCount	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<120	\N	\N	number	Data
QueueNumAnsweredInteractions120sec	QM - Number of Answered Interactions in 120 sec	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<120 && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueNumActiveCalls	QM - Number of Active Calls in Queue	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsTalk	\N	\N	number	Data
QueueNumActiveCallbacks	QM - Number of Active Callbacks in Queue	Interactions Summary	InteractionsCount	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsTalk	\N	\N	number	Data
QueueNumActiveCallsAndCallbacks	QM - Number of Active Calls and Callbacks in Queue	Interactions Summary	InteractionsCount	CallType=="External" && Direction=="Incoming"&& (InteractionType=="Call" || InteractionType=="Callback")&& IsTalk	\N	\N	number	Data
QueueNumActiveChats	QM - Number of Active Chats in Queue	Interactions Summary	InteractionsCount	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && IsTalk	\N	\N	number	Data
QueueNumActiveInteractions	QM - Number of Active Interactions in Queue	Interactions Summary	InteractionsCount	(CallType=="External")  && Direction == "Incoming" && IsTalk && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	number	Data
QueueNumOnCallAgents	QM - Number of On Call Agents in Queue Skill	Interactions Summary	UsersInStatusGroupCount	ONPHONE	\N	\N	number	Data
QueuePctAnsweredCalls30secInc	QM - Percent of Answered Calls in 30 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec]/[QueueNumIncomingCompletedCalls])	##0.0%	\N	number	Data
QueuePctAnsweredCallbacks30secInc	QM - Percent of Answered Callbacks in 30 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks30sec]/[QueueNumIncomingCompletedCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredCallsAndCallbacks30secInc	QM - Percent of Answered Calls and Callbacks in 30 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks30sec]/[QueueNumIncomingCompletedCallsAndCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredChats30secInc	QM - Percent of Answered Chats in 30 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats30sec]/[QueueNumIncomingCompletedChats])	##0.0%	\N	number	Data
QueuePctAnsweredInteractions30secInc	QM - Percent of Answered Interactions in 30 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions30sec]/[QueueNumIncomingCompletedInteractions])	##0.0%	\N	number	Data
QueuePctAnsweredCalls30secAns	QM - Percent of Answered Calls in 30 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec]/[QueueNumAnsweredCalls])	##0.0%	\N	number	Data
QueuePctAnsweredCallbacks30secAns	QM - Percent of Answered Callbacks in 30 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks30sec]/[QueueNumAnsweredCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredCallsAndCallbacks30secAns	QM - Percent of Answered Calls and Callbacks in 30 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks30sec]/[QueueNumAnsweredCallsAndCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredChats30secAns	QM - Percent of Answered Chats in 30 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats30sec]/[QueueNumAnsweredChats])	##0.0%	\N	number	Data
QueuePctAnsweredInteractions30secAns	QM - Percent of Answered Interactions in 30 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions30sec]/[QueueNumAnsweredInteractions])	##0.0%	\N	number	Data
QueuePctAnsweredCalls60secInc	QM - Percent of Answered Calls in 60 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls60sec]/[QueueNumIncomingCompletedCalls])	##0.0%	\N	number	Data
QueuePctAnsweredCallbacks60secInc	QM - Percent of Answered Callbacks in 60 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks60sec]/[QueueNumIncomingCompletedCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredCallsAndCallbacks60secInc	QM - Percent of Answered Calls and Callbacks in 60 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks60sec]/[QueueNumIncomingCompletedCallsAndCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredChats60secInc	QM - Percent of Answered Chats in 60 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats60sec]/[QueueNumIncomingCompletedChats])	##0.0%	\N	number	Data
QueuePctAnsweredInteractions60secInc	QM - Percent of Answered Interactions in 60 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions60sec]/[QueueNumIncomingCompletedInteractions])	##0.0%	\N	number	Data
QueuePctAnsweredCalls60secAns	QM - Percent of Answered Calls in 60 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls60sec]/[QueueNumAnsweredCalls])	##0.0%	\N	number	Data
QueuePctAnsweredCallbacks60secAns	QM - Percent of Answered Callbacks in 60 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks60sec]/[QueueNumAnsweredCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredCallsAndCallbacks60secAns	QM - Percent of Answered Calls and Callbacks in 60 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks60sec]/[QueueNumAnsweredCallsAndCallbacks])	##0.0%	\N	number	Data
UserNumMissedCalls	Agent - Number of Missed Calls	User	TotalStatusCount	Missed Call	\N	\N	number	Agent
QueuePctAnsweredChats60secAns	QM - Percent of Answered Chats in 60 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats60sec]/[QueueNumAnsweredChats])	##0.0%	\N	number	Data
QueuePctAnsweredInteractions60secAns	QM - Percent of Answered Interactions in 60 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions60sec]/[QueueNumAnsweredInteractions])	##0.0%	\N	number	Data
QueuePctAnsweredCalls120secInc	QM - Percent of Answered Calls in 120 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls120sec]/[QueueNumIncomingCompletedCalls])	##0.0%	\N	number	Data
MonSumAgentsInMissedCall	Agent Group - Number of Agents on Missed Call	UsersSummary	UsersInStatusCount	Missed Call	\N	\N	number	Data
QueuePctAnsweredCallbacks120secInc	QM - Percent of Answered Callbacks in 120 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks120sec]/[QueueNumIncomingCompletedCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredCallsAndCallbacks120secInc	QM - Percent of Answered Calls and Callbacks in 120 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks120sec]/[QueueNumIncomingCompletedCallsAndCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredChats120secInc	QM - Percent of Answered Chats in 120 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedChats]==0 ? 0 : ((double)[QueueNumAnsweredChats120sec]/[QueueNumIncomingCompletedChats])	##0.0%	\N	number	Data
QueuePctAnsweredInteractions120secInc	QM - Percent of Answered Interactions in 120 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions120sec]/[QueueNumIncomingCompletedInteractions])	##0.0%	\N	number	Data
QueuePctAnsweredCalls120secAns	QM - Percent of Answered Calls in 120 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls120sec]/[QueueNumAnsweredCalls])	##0.0%	\N	number	Data
QueuePctAnsweredCallbacks120secAns	QM - Percent of Answered Callbacks in 120 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallbacks120sec]/[QueueNumAnsweredCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredCallsAndCallbacks120secAns	QM - Percent of Answered Calls and Callbacks in 120 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredCallsAndCallbacks]==0 ? 0 : ((double)[QueueNumAnsweredCallsAndCallbacks120sec]/[QueueNumAnsweredCallsAndCallbacks])	##0.0%	\N	number	Data
QueuePctAnsweredChats120secAns	QM - Percent of Answered Chats in 120 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredChats]==0 ? 0 : ((double)[QueueNumAnsweredChats120sec]/[QueueNumAnsweredChats])	##0.0%	\N	number	Data
QueuePctAnsweredInteractions120secAns	QM - Percent of Answered Interactions in 120 sec from Answered	Interactions Summary	Calc	[QueueNumAnsweredInteractions]==0 ? 0 : ((double)[QueueNumAnsweredInteractions120sec]/[QueueNumAnsweredInteractions])	##0.0%	\N	number	Data
QueueNumberOfLoggedAgents	QM - Number of Logged In Agents	Interactions Summary	LogedInUsersCount	 	\N	\N	number	Data
MonAgentNumberOfInboundCallsDialer	Agent Group - Number of Dialer Calls	User	InteractionsCount	 InteractionType=="Dialer" && (CallType=="External" || CallType=="Intercom") && Direction=="Incoming"	\N	\N	number	Data
QueueLoginDataNumAvailableUsers	Agent Group - Number of Available Agents	UsersSummary	UsersInStatusGroupCount	AVAILABLE	\N	\N	number	Data
QueueLoginDataNumLoggedUsers	Agent Group - Number of Curently Logged in Users	UsersSummary	LogedInUsersCount		\N	\N	number	Data
QueueLoginDataNumBreakUsers	Agent Group - Number of Agents in Break State Group	UsersSummary	UsersInStatusGroupCount	BREAK	\N	\N	number	Data
QueueLoginDataNumPaperworkUsers	Agent Group - Number of Agents in Paperwork State Group	UsersSummary	UsersInStatusGroupCount	PAPERWORK	\N	\N	number	Data
UsersSumOnCall	Agent Group - Number of On Call Agents	UsersSummary	UsersInStatusGroupCount	ONPHONE	\N	\N	number	Data
MonSumAgentsAnsweredCalls	Agent Group - Number of Answered Incoming Calls and Callbacks	UsersInteraction	InteractionsCount	CallType=="External" && Direction=="Incoming" && !IsTalk && !IsInQueue && (InteractionType == "Call" || InteractionType == "Callback") && IsAnswered	\N	\N	number	Data
MonSumAgentsMakeCalls	Agent Group - Number of Otbound Calls	UsersInteraction	InteractionsCount	CallType=="External" && Direction=="Outgoing"	\N	\N	number	Data
MonSumAgentsBreakDurationPercent	Agent Group - Percent of Agents in Break State Group	UsersInteraction	UsersInStatusGroupDurationPercent	BREAK	##0.00%	\N	number	Data
MonSumAgentsPaperworkDurationPercent	Agent Group - Percent of Agents in Paperwork State Group	UsersInteraction	UsersInStatusGroupDurationPercent	PAPERWORK	##0.00%	\N	number	Data
QueueNumAnsweredCalls360sec	QM - Number of Answered Calls in 360 sec	Interactions Summary	InteractionsCount	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsAnswered && TimeInQueue<360	\N	\N	number	Data
QueuePctAnsweredCalls360secInc	QM - Percent of Answered Calls in 360 sec from Incoming	Interactions Summary	Calc	[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls360sec]/[QueueNumIncomingCompletedCalls])	##0.00%	\N	number	Data
QueueCPH	QM - Calls per Hour	Interactions Summary	CPH	InteractionType=="Call" && Direction == "Incoming"	F2	\N	number	Data
MonAgentTalkDurationPct	Agent - Cumlative Talk Duration Percent	User	TotalStatusGroupPercent	ONPHONE	\N	\N	number	Agent
MonAgentNumChatsCompleted	Agent - Number of Answered Chats	User	InteractionsCount	InteractionType=="Chat" && Direction=="Incoming" && !IsTalk && !IsInQueue && IsAnswered	\N	\N	number	Agent
UserCPH	Agent - Calls per Hour	User	CPH	InteractionType=="Call" && Direction == "Incoming"	F2	\N	number	Agent
MonAgentNumChatsActive	Agent - Number of Active Chats	User	InteractionsCount	InteractionType=="Chat" && IsTalk	\N	\N	number	Agent
UserNumAllIntercom	Agent - Number of Internal Calls	User	InteractionsCount	CallType=="Intercom"	\N	\N	number	Agent
MonAgentNumberOfInboundCalls15sec	Agent - Number of Incoming Calls with Talk Time less than 15 seconds	User	InteractionsCount	CallType=="External" && Direction=="Incoming" &&  TalkTime<15 && (InteractionType=="Call" || InteractionType=="Callback")	\N	\N	number	Agent
MonAgentNumberOfInboundCalls10Min	Agent - Number of Incoming Calls with Talk Time more than 10 minutes	User	InteractionsCount	CallType=="External" && Direction=="Incoming" && TalkTime>600 && (InteractionType=="Call" || InteractionType=="Callback")	\N	\N	number	Agent
MonAgentNumberOfInboundCallsWithIntercom	Agent - Number of Incoming External and Internal Calls	User	InteractionsCount	 (CallType=="External" || CallType=="Intercom") && Direction=="Incoming"  && (InteractionType=="Call" || InteractionType=="Callback")	\N	\N	number	Agent
MonAgentNumberOfInboundCallsOnly	Agent - Number of Incoming External Calls	User	InteractionsCount	 (InteractionType=="Call" ||  InteractionType=="Callback") && (CallType=="External" || CallType=="Intercom") && Direction=="Incoming"	\N	\N	number	Agent
MonAgentNumberOfConsultCalls	Agent - Number of Consultation Calls	User	TotalStatusCount	Consulting Call	\N	\N	number	Agent
MonAgentNumberOfMakeCalls	Agent - Number of Outbound Calls	User	InteractionsCount	InteractionType=="Call" && CallType=="External" && Direction=="Outgoing"	\N	\N	number	Agent
MonAgentNumMakeCallsInCompleted	Agent - Number of Answered Incoming Calls	User	InteractionsCount	 (InteractionType=="Call" ||  InteractionType=="Callback") && Direction=="Incoming" && IsAnswered && !IsTalk	\N	\N	number	Agent
MonAgentOutgoingCallbacksNum	Agent - Number of Outgoing Callbacks	User	InteractionsCount	InteractionType=="Callback" && Direction=="Outgoing" && IsAnswered	\N	\N	number	Agent
MonAgentProxyCallsNum	Agent - Number of Incoming Callbacks	User	InteractionsCount	InteractionType=="Callback" && Direction=="Incoming"  && IsAnswered && !IsCallbackRequest	\N	\N	number	Agent
MessagesMaxFirstResponseTime	QM - Messages Max First Response Time	Interactions Summary	MessagesMaxFirstResponseTime	Direction=="Incoming"	\N	\N	time	Data
MessagesAvgFirstResponseTime	QM - Messages Avg First Response Time	Interactions Summary	MessagesAvgFirstResponseTime	Direction=="Incoming"	\N	\N	time	Data
MessagesAvgResponseTime	QM - Messages Avg Response Time	Interactions Summary	MessagesAvgResponseTime	Direction=="Incoming"	\N	\N	time	Data
QueueCurMaxWaitTimeCalls	QM - Current Max Wait Time of Calls in Queue	Interactions Summary	WaitDurationCurMax	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming"	\N	\N	time	Data
QueueCurMaxWaitTimeCallbacks	QM - Current Max Wait Time of Callbacks in Queue	Interactions Summary	WaitDurationCurMax	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming"	\N	\N	time	Data
QueueCurMaxWaitTimeCallsAndCallbacks	QM - Current Max Wait Time of Calls and Callbacks in Queue	Interactions Summary	WaitDurationCurMax	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming"	\N	\N	time	Data
QueueCurMaxWaitTimeChats	QM - Current Max Wait Time of Chats in Queue	Interactions Summary	WaitDurationCurMax	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming"	\N	\N	time	Data
QueueCurMaxWaitTimeInteractions	QM - Current Max Wait Time of Interactions in Queue	Interactions Summary	WaitDurationCurMax	(CallType=="External")  && Direction == "Incoming" && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	time	Data
QueueAvgWaitTimeCalls	QM - Average Wait Time of Calls in Queue	Interactions Summary	WaitDurationAvg	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue	\N	\N	time	Data
QueueAvgWaitTimeCallbacks	QM - Average Wait Time of Callbacks in Queue	Interactions Summary	WaitDurationAvg	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue	\N	\N	time	Data
QueueAvgWaitTimeCallsAndCallbacks	QM - Average Wait Time of Calls and Callbacks in Queue	Interactions Summary	WaitDurationAvg	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue	\N	\N	time	Data
QueueAvgWaitTimeChats	QM - Average Wait Time of Chats in Queue	Interactions Summary	WaitDurationAvg	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue	\N	\N	time	Data
QueueAvgWaitTimeInteractions	QM - Average Wait Time of Interactions in Queue	Interactions Summary	WaitDurationAvg	(CallType=="External")  && Direction == "Incoming" && !IsInQueue && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	time	Data
QueueAvgTimeToAbandCalls	QM - Average Time to Aband of Calls in Queue	Interactions Summary	WaitDurationAvg	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && IsAbandoned	\N	\N	time	Data
QueueAvgTimeToAbandCallbacks	QM - Average Time to Aband of Callbacks in Queue	Interactions Summary	WaitDurationAvg	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && IsAbandoned	\N	\N	time	Data
QueueAvgTimeToAbandCallsAndCallbacks	QM - Average Time to Aband of Calls and Callbacks in Queue	Interactions Summary	WaitDurationAvg	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && IsAbandoned	\N	\N	time	Data
QueueAvgTimeToAbandChats	QM - Average Time to Aband of Chats in Queue	Interactions Summary	WaitDurationAvg	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && IsAbandoned	\N	\N	time	Data
QueueAvgTimeToAbandInteractions	QM - Average Time to Aband of Interactions in Queue	Interactions Summary	WaitDurationAvg	(CallType=="External")  && Direction == "Incoming" && !IsInQueue && IsAbandoned && (InteractionType=="Chat" || InteractionType=="email")	\N	\N	time	Data
QueueAvgTalkingDurationCalls	QM - Average Talking Duration of Calls	Interactions Summary	TalkDurationAvg	(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && !IsTalk && !IsInQueue	\N	\N	time	Data
QueueAvgTalkingDurationCallbacks	QM - Average Talking Duration of Callbacks	Interactions Summary	TalkDurationAvg	(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && !IsTalk && !IsInQueue	\N	\N	time	Data
QueueAvgTalkingDurationCallsAndCallbacks	QM - Average Talking Duration of Calls and Callbacks	Interactions Summary	TalkDurationAvg	(InteractionType=="Call" || InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && !IsTalk && !IsInQueue	\N	\N	time	Data
QueueAvgTalkingDurationChats	QM - Average Talking Duration of Chats	Interactions Summary	TalkDurationAvg	(InteractionType=="Chat") && (CallType=="External")  && Direction == "Incoming" && !IsTalk && !IsInQueue	\N	\N	time	Data
QueueAvgTalkingDurationInteractions	QM - Average Talking Duration of Interactions	Interactions Summary	TalkDurationAvg	(CallType=="External")  && Direction == "Incoming" && !IsTalk && !IsInQueue	\N	\N	time	Data
MonSumAgentsAverageCallDuration	Agent Group - Average Talk Duration in Incoming Calls and Callbacks	UsersInteraction	TalkDurationAvg	CallType=="External" && Direction=="Incoming" && (InteractionType == "Call" || InteractionType == "Callback") && !IsTalk && !IsInQueue	\N	\N	time	Data
MonSumAgentsAverageChatDuration	Agent Group - Average Talk Duration in Incoming Chats	UsersInteraction	TalkDurationAvg	CallType=="External" && Direction=="Incoming" && (InteractionType == "Chat") && !IsTalk && !IsInQueue	\N	\N	time	Data
MonSumAgentsLongestCurrentCall	Agent Group - Current Max Talk Duration	UsersInteraction	TalkDurationCurMax	CallType=="External" && Direction=="Incoming"	\N	\N	time	Data
MonAgentTalkDuration	Agent - Cumulative Talk Duration	User	TotalStatusGroupDuration	ONPHONE	\N	\N	time	Agent
AgentMessagesAvgResponseTime	Agent - Messages Avg Response Time	User	MessagesAvgResponseTime	Direction=="Incoming"	\N	\N	time	Agent
AgentMessagesAvgFirstResponseTime	Agent - Messages Avg First Response Time	User	MessagesAvgFirstResponseTime	Direction=="Incoming"	\N	\N	time	Agent
MonAgentCurrentLoginDuration	Agent - Current Login Duration	User	CurLoginDuration		\N	\N	time	Agent
MonAgentAvailableDuration	Agent - Available State Duration	User	TotalStatusGroupDuration	AVAILABLE	\N	\N	time	Agent
MonAgentDurationOfCurrentCall	Agent - Current Incoming Ext Call Duration	User	CurStatusDuration	Incoming Ext Call	\N	\N	time	Agent
MonAgentAverageMakeCallDuration	Agent - Average Oubound Call Duration	User	TotalStatusDurationAvg	Out Ext Call	\N	\N	time	Agent
MonAgentAverageAgentDialerDuration	Agent - Average Dialer Calls Duration	User	TotalStatusDurationAvg	Campaign Call	\N	\N	time	Agent
MonAgentDurationOfCalls	Agent - Cumulative  Incoming Ext Call Duration	User	TotalStatusDuration	Incoming Ext Call	\N	\N	time	Agent
MonAgentAverageCallDuration	Agent - Average Handling Duration	User	TotalStatusGroupDurationAvg	ONPHONE	\N	\N	time	Agent
MonAgentStateDuration	Agent - Current Status Duration	User	CurStatusDuration		\N	\N	time	Agent
MonAgentTelStateDuration	Agent - Active Interaction State Duration	User	LongestInteractionStateDuration		\N	\N	time	Agent
MonAgentBreakDuration	Agent - Cumulative Break Group Duration	User	TotalStatusGroupDuration	BREAK	\N	\N	time	Agent
MonAgentWrapUpDuration	Agent - Cumulative Wrap Up Duration	User	TotalStatusDuration	Wrap Up	\N	\N	time	Agent
MonAgentUnavailableStateDuration	Agent - Cumulative Unavailable State Duration	User	TotalStatusDuration	Unavailable	\N	\N	time	Agent
MonAgentAverageInboundCallDuration	Agent - Average Call Duration	User	TalkDurationAvg	CallType=="External" && (InteractionType=="Call" || InteractionType=="Callback")  && Direction=="Incoming" && !IsTalk	\N	\N	time	Agent
MonAgentPaperworkDuration	Agent - Cumulative Paperwork Group Duration	User	TotalStatusGroupDuration	PAPERWORK	\N	\N	time	Agent
MonAgentMaxCallDuration	Agent - Max Call Duration	User	TalkDurationMax	CallType=="External" && (InteractionType=="Call" || InteractionType=="Callback") && Direction=="Incoming"	\N	\N	time	Agent
MonAgentLoginTime	Agent - Cumulative Login Duration	User	TotalLoginDuration		\N	\N	time	Agent
MonAgentStateDescDuration	Agent - Current Status Group Duration	User	CurStatusGroupDuration		\N	\N	time	Agent
MonAgentHeldDuration	Agent - Cumulative Hold Duration	User	TotalStatusDuration	Hold	\N	\N	time	Agent
MonAgentStation	Agent - Station ID	User	Station		\N	\N	text	Agent
MonAgentActiveInteractionId	Agent - Active Interction ID	User	LongestInteractionId	 	\N	\N	text	Agent
MonAgentTelState	Agent - Active Interaction State	User	LongestInteractionState		\N	\N	text	Agent
RemotePhoneNumber	Agent - Active Interaction Customer Phone Number	User	LongestInteractionRemoteAddress	 	\N	\N	text	Agent
MonAgentTodayLogin	Change -ID of a representative who was connected that day	User	IsTodayLogin		\N	\N	text	Agent
MonAgentUserId	Agent - User ID	User	UserID		\N	\N	text	Agent
AgentLoginName	Agent - Login Name	User	DisplayName		\N	\N	text	Agent
MonActiveCampaign	Agent - Active Interaction Queue Name	User	LongestInteractionWorkgroup		\N	\N	text	Agent
MonInteractionType	Agent - Active Interaction Type	User	LongestInteractionType		\N	\N	text	Agent
MonAgentState	Agent - Current Satatus	User	CurStatusTitle		\N	\N	text	Agent
MonAgentExtension	Agent - Extension ID	User	UserExtension		\N	\N	text	Agent
MonAgentStateDesc	Agent - Current Status Group	User	CurStatusGroup		\N	\N	text	Agent
MonAgentFirstLoginTimeStamp	Agent - First Login Time Stamp	User	FirstLoginTimestamp		\N	\N	text	Agent
MonAgentCurrentLoginTimeStamp	Agent - Current Login Time Stamp	User	CurLoginTimestamp		\N	\N	text	Agent
QueueLoginDataNumUnavailableUsers	Agent Group - Number of Agents in Unavailable State Group	UsersSummary	UsersInStatusGroupCount	UNAVAILABLE	\N	0	number	Data
MonAgentUnavailableDuration	Agent - Cumulative Unavailable Group Duration	User	TotalStatusGroupDuration	UNAVAILABLE	\N	\N	time	Agent
MonAgentUnavailableDurationPct	Agent - Cumulative Unavailable Duration Percent	User	TotalStatusGroupPercent	UNAVAILABLE	\N	\N	number	Agent
MonSumAgentsUnavailableDurationPercent	Agent Group - Percent of Agents in Unavailable State Group	UsersInteraction	UsersInStatusGroupDurationPercent	UNAVAILABLE	##0.00%	\N	number	Data
\.

-- NGC_Site
TRUNCATE TABLE "NGC_Site" RESTART IDENTITY CASCADE;
COPY "NGC_Site" FROM stdin;
IL	019e03e9-60dd-72da-bd01-648ffdb2b433	Israel	Israel	+02:00	00:00
\.

SET session_replication_role = DEFAULT;

-- metric_deploy_log baseline seed (ledger completeness, contract 3.0)
INSERT INTO public.metric_deploy_log ("MetricId","DeployedAt","SourceCommit")
SELECT "MetricId", now(), 'baseline' FROM public."RTSGrid_Metric"
ON CONFLICT ("MetricId") DO NOTHING;
