---
session: RTM Backend
slug: backend-0609
started: 2026-06-09T09:00Z
heartbeat: 2026-06-18T14:40Z
status: done
role: specialist
domain: RTM Server (backend) / Cowork-A
cowork: A
skills: [rtm-service-expert, rtm-metrics-expert, program-architector, signalr-expert]
modules: []
files: []   # IDLE/standby — claims released; re-claim per next task (F-3 contingency only if bind in RTM Program.cs)
cc_task: none  # answered 45-cascade functions-authority query (analysis, no code)
---
>>> MANDATORY FIRST READ EVERY TURN: .coord/protocols/comms-backend-0609.md (твой персональный жёсткий
>>> comms-протокол). Читать ДО всего. ВСЕ результаты И вопросы — ВСЕГДА в .coord/inbox/coordinator.md, не в чат.
>>> INBOX RULE (pinned 2026-06-10 — read-hygiene fix): MY inbox = `.coord/inbox/backend-0609.md` (file named
>>> after MY slug = messages TO me). On `коорд: входящие` -> read THIS file IN FULL (it's small), act on each
>>> unhandled block, append `> handled <UTC> by backend-0609`. I WRITE/flush to `.coord/inbox/coordinator.md`
>>> (file named after the RECIPIENT) — that is my OUTBOX, NEVER my read-source. Rule: READ the file named after
>>> YOU; WRITE to the file named after the RECIPIENT. Do NOT reconstruct my directives from coordinator.md tail.

SPECIALIST — RTM Backend (Engine, DBMng, DBAdapter, metrics, SQL routines, BU/queue data flows).
Role #1 «RTM Server» from specialization.md. Branch v2-backend. Cowork-A.

CLAIM NOTE: Engine.cs + Union.cs GRANTED to this session 2026-06-09T10:45Z via operator-confirmed §42.2
takeover from daytrend-2-0607 (Engine.cs) — Union.cs was unheld. file-mode. daytrend-2 keeps its 5 DayTrend files.

CONTEXT (resumed from earlier session — previous SQL fixes):
- NGC_GetOrCreateQueue / NGC_GetOrCreateAgentGroup procedures fixed (gen_random_uuid() for Id, IsActive=true).
  SQL given to operator for DBeaver apply. Awaiting RTM restart confirmation.

CURRENT TASK: IDLE / standby (re-init 2026-06-10T05:45Z). Committed work 9cc8a66 (hot-reload compile) + 160259a (NGC E-004 INSERT fix + Engine guards) DONE, unpushed on 24122c2, rides next push-barrier after Security ACK. F-1 closed architecturally (Shell b7b20e4 read-only). F-3 loopback-rebind = devops (bind is in RTM appsettings, not Program.cs). Awaiting coordinator signal: F-3 Program.cs contingency OR fast-follow (FF-1 grammar validator / FF-3 RTMHub bearer-token). Read & accept INBOX RULE + comms-protocol.

> REAPED 2026-06-12T11:02Z by curator-0611 (operator-confirmed, L-SC-14): heartbeat stale >19h-3d, cc_task=none, work committed. Claims released. Fresh incarnation re-registers when the role is next spun up.

<!-- HANDOFF 2026-06-20T09:43:22Z: superseded by backend-0620 (operator-directed, pre-launch). claims released. Fresh incarnation re-registers via INIT + role-skill + permanent inbox. -->
