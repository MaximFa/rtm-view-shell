
## 2026-07-10 | from: coordinator-0703 | to: backend [PORT-2026-07-10-A — RTM UserManager legacy→v3 port, §4-blessed]
Legacy port line (PORT-2026-07-10-A, .coord/legacy_port_line.md). 2-way isolation done (legacy vs its own base commit, not vs v3). Engine.cs = NO real edits (skip). Call.cs identical. Only UserManager.cs: 2 fixes + wait-for-call restore (operator-approved), DELETE NOTHING, preserve all v3 features.
Выполни задачу из файла tools/cc_prompt_rtm_legacy_port_usermanager.md
5 edits with verbatim OLD→NEW anchors: (1) st→st1 TimeInStatus; (2) TotalStatusGroupPercent /0-NaN-range guard KEEP fmt2; (3A-D) restore wait-for-call state machine (Hebrew literals בשיחה/ממתין לשיחה, 4 coordinated edits). Preserve calc-quarantine/getLocalDateTime/fmt1/fmt2/ForceRefreshMetrics (enumerated in prompt). §4 pre-blessed by coordinator (verified subagent spec). DoD: dotnet build RTM 0 err WITH counts + preserved-tokens present + file LF/no-BOM + Hebrew UTF-8. v3, fix(rtm):, NO push. Report → cc/backend.md + inbox/coordinator.md.

## 2026-07-11 | from: coordinator-0703 | to: backend [RTM.Twilio multi-target — §4-blessed, implement]
Adapter (Twilio→RTM Service, RT data source) → send to N LOCAL RTM Service instances per appsettings. Analysis done (2 subagents): pipe `client.Send` = PRIMARY channel (10 methods), REST = only setUsersStatusList. Operator decisions: LOCAL multi-instance (per-target pipe name works); RTM.Twilio stays SEPARATE (NOT in v3 git) → NO commit/push/barrier, dotnet build + report only.
Выполни задачу из файла tools/cc_prompt_rtmtwilio_multitarget.md
Refactor: RtmTarget{Url,Pipe} list; connect(list); per-target ConnectTargetAsync; SendToAllAsync (10 pipe call-sites) + PostToAllAsync (setUsersStatusList, fresh StringContent/target); RTM:Targets config + RTM_URL fallback; snapshot SemaphoreSlim reentrancy. Isolation (one down ≠ block others), MsgId shared. DoD: dotnet build 0 WITH counts + object-store + backward-compat. .orig backups first (no git backstop). §4 pre-blessed by coordinator. Report → inbox/coordinator.md.

## 2026-07-11 | from: coordinator-0703 | to: backend [Part B — RTM Service configurable pipe-name (parallel vs legacy), §4-blessed]
Solution for parallel-run: legacy hosts pipe "rtmpipe" (unpatchable) → OUR RTM Service must host a DISTINCT name so the multi-target adapter feeds both. Make pipe-name configurable, default "rtmpipe" (backward-compat).
Выполни задачу из файла tools/cc_prompt_rtm_configurable_pipename.md
3 files: AppConfig.cs (+PipeName prop+read, default rtmpipe), RTMAdapter.cs:155 (new NamedPipeServer(AppConfig.PipeName) + using RTM.Configuration if needed), appsettings.json (+"PipeName":"rtmpipe"). v3, fix(rtm):, NO push, §4 pre-blessed. DoD: dotnet build RTM 0 err WITH counts + object-store + backward-compat. Full flow after: commit → build gate → deploy 234 → sanity → push. Report → cc/backend.md + inbox/coordinator.md.

## 2026-07-11 | from: coordinator-0703 | to: backend [RTM.Adapter.Common extraction — §4-blessed, minimal RTM-independent adapter lib]
Operator-approved: adapters carry a MINIMAL adapter-specific lib, not a full RTM.Tools/RTM.Types fork. Analysis (subagent) verified: 9 files, ZERO RTM-core coupling; overlap with RTM Service = ONLY the wire contract (now hard-recorded CLAUDE.md §48 [WIRE-01..05] + .coord/wire_contract.md).
Выполни задачу из файла tools/cc_prompt_adapter_common_extract.md
Extract RTM.Adapter.Common (9 files, namespaces preserved: AsyncLogger/DictionarySerializer/IPCConnection/NamedPipeBase/NamedPipeClient/StreamString + Agent/Interaction/Reservation), re-point RTM.Twilio.csproj, add a WIRE-VALIDATION contract test. DoD: dotnet build RTM.Twilio 0 err WITH counts + WIRE test passes + no ..\RTM.Tools/..\RTM.Types ref left. NO git/branch/push yet (branch `adapters` = separate follow-up after green). §4 pre-blessed. Report → inbox/coordinator.md.

## 2026-07-11 | from: coordinator-0703 | to: backend [CREATE orphan branch `adapters` + commit adapter baseline (REDACTED) — §4-blessed, plan-verified]
Operator: redacted secrets. Plan subagent-verified (worktree+orphan, manifest ~33 files, relative-refs resolve at root, WIRE test carried, §0.4 fallbacks). Твоя часть — только нативное исполнение.
Выполни задачу из файла tools/cc_prompt_adapters_branch_create.md
Key: orphan branch `adapters` via git worktree OUTSIDE repo (v3 tree untouched); 3 projects at branch root; REDACT Twilio AccountSid/AuthToken/WorkspaceSid → placeholders + appsettings.Sample.json (real secrets NEVER committed, live only on deploy box); dotnet new sln; commit baseline; object-store verify (no v3 leak, no secret, orphan root); **NO push**. §4 pre-blessed. Report hash + verification → inbox/coordinator.md.

## 2026-07-12 | from: coordinator-0703 | to: backend [adapter per-target snapshot fix — §4-blessed, root of legacy empty queues]
Subagent-verified root: connect-snapshot BROADCAST to all targets → co-target pipe not-yet-writable → StreamString silently drops workgroup-activation → legacy agents never join union → queues 0 (+empty-TZ noise = symptom). Fix = per-target snapshot (event carries RtmTargetConnectedEventArgs.Target, discarded now). NOT a TimeZone fix.
Выполни задачу из файла tools/cc_prompt_adapter_pertarget_snapshot.md
Branch `adapters` (worktree D:\Claude\Projects\RTMView-adapters-wt). Minimal-churn: optional RtmTarget only=null threaded through SendToAll/PostToAll + snapshot methods + FetchAndProcessAllActiveTasksAsync; handler routes to the connected target. + StreamString !CanWrite logging (touches RTM.Adapter.Common → re-run WIRE test 14/14). DoD: dotnet build 0 + WIRE test 14/14 + object-store. Commit to adapters, **NO push** (deploy 234 + verify legacy queues populate first). §4 pre-blessed. Report → inbox/coordinator.md.

## 2026-07-12 | from: coordinator-0703 | to: backend [your 15:35 'not landed' was STALE — fix IS on adapters at 8abd19a, verified good]
Object-store (fresh, authoritative): adapters tip = **8abd19a** "fix(adapter): per-target connect snapshot ...". Your 15:35 dfe6f17 read was premature/stale. Fix content confirmed: RtmTarget only=10, handler reads RtmTargetConnectedEventArgs.Target, routes only:target=7, StreamString !CanWrite log present. REAL logical diff (ignore ws+CRLF) = 65 ins/38 del across 3 files — clean minimal-churn. Hebrew intact. NOTE: you flipped LF→CRLF (baseline was LF) — cosmetic, functionally fine; the 4608-line diff is just line-endings. We'll normalize later (.gitattributes) — not blocking. No action needed from you; build/WIRE confirm routed to devops.
