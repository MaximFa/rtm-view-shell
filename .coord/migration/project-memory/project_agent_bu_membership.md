---
name: project-agent-bu-membership
description: Epic — persist agent↔agentgroup membership (NGC_UserAgentgroup) for BU-scoped agent metrics
metadata: 
  node_type: memory
  type: project
  originSessionId: daa8b771-e75d-4a7d-9e7e-75cf6df6aab3
---

Decision 2026-06-06 (Max): DayTrend agent metrics must be scoped to the screen's Business Unit, NOT to who took calls. Today there is NO agent→agentgroup link in the DB — only agentgroup→supergroup→BU (NGC_SupergroupAgentgroup, NGC_BusinessUnitSupergroup). Agent↔workgroup membership lives ONLY in RTM Service memory (`UserManager._workgroups`), never persisted.

**New table `NGC_UserAgentgroup`** (junction, mirrors NGC_SupergroupAgentgroup naming/casing — lowercase "group"):
Id int PK identity · UserId varchar(100) (= RTSData_UserStatusLog.UserId / agent login) · AgentgroupId varchar(100) (= workgroup external id, → NGC_AgentGroups.ExternalId) · TenantId uuid (§33) · CreatedDatetime timestamptz · CreatedBy varchar(100); UNIQUE(TenantId, UserId, AgentgroupId). Many-to-many (agent can be in >1 group).

**Populate from RTM Service** at the membership hooks (found in code 2026-06-06):
- `Engine.userWorkgroupActivation(workgroup, activeUsersList, deactiveUsersList, …)` (Engine.cs:1544) — handles BOTH init (platform sends current membership as activation events on connect) AND runtime add/remove. add=activeUsersList, remove=deactiveUsersList.
- per-agent `UserManager.workgroupActivation(workgroup, isActive)` (UserManager.cs:606) maintains `_workgroups`.
- **Design choice:** persist in `Engine.userWorkgroupActivation` (Engine.cs, free territory) NOT in UserManager.cs (metrics-0605 quarantine → would need §9). add→upsert SP, remove→delete SP, via DBMng (+_tenantId, §33).
- In this codebase **workgroup ≡ agentgroup** (Engine does `Agentgroups.TryAdd(workgroup, true)`).

**Consume:** `fn_daytrendagentstatus` joins agent pool → NGC_UserAgentgroup → NGC_SupergroupAgentgroup → NGC_BusinessUnitSupergroup → BU, scoping to the screen's BU.

**Membership semantics (operator-confirmed 2026-06-06, CRITICAL):**
- **SG → AgentGroup = AND (intersection):** an agent belongs to a Supergroup ONLY IF it is a member of ALL of that SG's agent groups. E.g. SG{US, Support} → only agents in BOTH US AND Support. SQL: `GROUP BY UserId, SupergroupId HAVING COUNT(DISTINCT AgentgroupId) = (total AGs of that SG)`.
- **BU → Supergroup = OR (union):** an agent is in the BU if it belongs to ANY of the BU's supergroups.
- A naive single OR-join (agent in any AG of any SG) is WRONG. The P3 fn (_008) uses the AND/OR CTE structure.

DEPLOY lesson (2026-06-07): Shell and RTM Service MUST be deployed together (or version/contract-checked). Deploying RTM-only with `Update-RTMView.ps1 -SkipShell` left an OLD prod Shell that sent agent-grid union = RTSUserGrid_Grid.GridId (8 → "u8"), while the NEW RTM assembles unions by BusinessUnitId (56/70) → union 8 gone → Engine.AddGridConnection/getUsers/refreshCells did `UnionList[8]` (throwing indexer) → KeyNotFoundException → empty Agent Grid. DB + config were correct (GridId 8→UnionId 56, businessUnit="56"). Fix established by commit 1f314e3 (AgentGrid uses BusinessUnit.Id as UnionId); old Shell predates it. Also recommended: engine guard — `UnionList` TryGetValue not indexer, so a stale grid id yields empty, not a crash.

RTM gotcha: NGC_Set/DeleteUserAgentgroup must be **PROCEDUREs**, not FUNCTIONs — RTM DBAdapter.ExecuteNonQuery calls SPs via CALL (42809 'is not a procedure' if function). devops _007 shipped them as functions; hotfixed to procedures on prod 2026-06-06. Relates to [[project-rtm-view-shell]] and the DayTrend agent-history fix (RTSData_UserStatusLog StatusGroup, migration _004 / c398c0d).

Sequencing: Phase 1 DB (table+SP+EF migration) → Phase 2 RTM persist (run to populate) → Phase 3 fn redesign + BU scope. UNAVAILABLE history+RT metric work (with metrics-0605) is independent and can run in parallel.
