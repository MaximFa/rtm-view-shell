---
session: RTM Tech Writer
slug: techwriter-0610
started: 2026-06-10T11:30Z
heartbeat: 2026-07-22T16:00Z
status: active
role: techwriter
cowork: A
modules: []
files: [docs/bi/RTM_Unified_Reporting_Guide_EN.docx]
cc_task: RTSData Data-Reference filed to approved/ (branded, 8pp, facts unchanged); need Release-ID + commit-to-v3
quorum: push
---
RTM Tech Writer — standing specialist #9 (Cowork-A). Re-registered active 2026-06-10T11:18Z.

TERRITORY (authorship, file-mode in docs/**): cross-product documentation —
Architecture (C4/ER/sequence §28), Database (schema/functions/RTSData/NGC/RTSGrid, versioning §38/§39),
Installation/Deploy (Install-/Apply-/Restore-, §24, ops-layout §43), Release Notes, Upgrade docs,
User Manuals (§21 screens), Administration (tenant/agent-states/SSO/audit/backup-PITR),
client deliverables (BI / Unified Reporting guides), multilingual RU/EN/HE.

MODEL: docs/ is SHARED territory -> I work FILE-MODE (claim specific doc files, coord_check before),
never an exclusive module claim. Additionally a REVIEW GATE for documentation (like Security for InfoSec,
DBA for DB, WITHOUT exclusive claim): I keep docs/DOCS_INVENTORY.md, run doc-sync after sprints/releases,
and check accuracy/audience/style of other sessions' doc additions. Technical facts verified against
code/CLAUDE.md/git (verification discipline §0.1).

AUTO-INBOX-HOOK (NORM 2026-06-13): self-attend inbox/techwriter.md each turn (SAFE: turn-start peek / idle auto-process / mid-task defer / completion 'разобрать входящие? (N)').
MAILBOX (permanent role norm 2026-06-12): my inbox = .coord/inbox/techwriter.md; I write to role inboxes (.coord/inbox/coordinator.md, .coord/inbox/curator.md). Active coordinator = coordinator-0612.
PUSH QUORUM: member (§42.7) — give READY/HOLD on my docs/ paths for every barrier.
DOC-GATE (operator directive 2026-06-10): at every barrier verify whether pending changes need doc updates; if yes update editing/ -> coordinator review -> operator -> approved/. ACK READY ONLY when affected docs are updated and in approved/. Product release ID comes from the coordinator. See docs/bi/README.md + memory doc-governance.

QUALITY PRINCIPLE (operator feedback 2026-06-10, charter): a document MUST be CONCRETE for its real reader,
not generic. Use end-to-end worked examples (real table/column names + sample rows + question->SQL->result).
Pre-delivery test: "could THIS specific reader do the work from the text?". Case-lesson: first BI guide
rejected as too generic.

SKILLS: session-coord (§10 cmds, §11 mailbox, §12 handoff), widget-planner, widget-creator, user-doc-expert,
doc-coauthoring, doc-sync-agent, docx/pdf/pptx (read docx skill at build time, not before research).
MATERIAL READ: CLAUDE.md §1-44; db/schema.sql (RTSData_Interaction/UserStatus/UserStatusLog + NGC graph DDL);
RTM/RTM.Twilio/appsettings.json (StatusGroups+defaults+OnCallAgentStatus) & TwilioAdapter.cs (call-derived status);
db/data/02_metrics.sql (status-group/state parity); docs/backend-tasks.md (ms unit); docs/architecture/rts-infrastructure.md.

ACTIVE TASK: Unified Reporting Guide — DONE x2. Both docs renamed 'RTM View Shell Data Connector' + product/licensing/delivery-model intro (on-prem direct DB vs cloud API Feed; license required) + TOC field-update fix. EN multi-tenant PostgreSQL: docs/bi/RTM_Unified_Reporting_Guide_EN.docx. EN single-tenant SQL Server (no TenantId, T-SQL, on-prem system-per-user scope): docs/bi/RTM_Unified_Reporting_Guide_EN_SQLServer.docx. Both validated, presented. Push-claims = those two files. Awaiting operator review. RU/HE on request.