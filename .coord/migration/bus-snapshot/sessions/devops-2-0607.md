---
session: RTM Devops
slug: devops-2-0607
started: 2026-06-07T04:34:40Z
heartbeat: 2026-06-13T10:55:00Z
status: done
role: work
files: []
cc_task: none. PUSH BARRIER ACTIVE (coordinator-0612 20:00Z, v2-backend, 21 commits, tip 9020836) -> I wrote READY ack (.coord/push/acks/devops-2-0607.md). FREEZE: no new CC tasks until pushed.
45 TIMELINE (corrected): 13:25 re-apply cleared the FUNCTION cascade BUT Phase-7 found 3 more EF-vs-schema drift blockers (42883 missing PROCEDUREs, 23505 IDENTITY seq, 42P10x2 missing UNIQUE). dba holistic staging/45_schema_reconcile.sql (§4-PASS) brought 45 to canon -> 45 NOW GREEN -> barrier raised. My premature "45 GREEN @13:25" was wrong (coordinator 18:28Z).
POST-PUSH DEVOPS TO-DOs (queued, after barrier clears): (1) B2 quote-safe fix tools/cc_prompt_b2_quotesafe_psql.md (-c -> temp .sql + psql -f; root = PowerShell -c strips embedded quotes -> 42703; NON-FATAL, relay-URL via UI) -> coordinator §4. (2) Repackage 45 from HEAD incl migrations _011/_012/_013/_014 (+reconcile) so fresh-install carries full structure. (3) Compare-ToBaseline E1 pre-deploy gate + E3 IDENTITY-seq dimension (co-author dba on E2) -- PD-008 P3+. (4) PD-008 P6 rebuild-runbook IDENTITY-resync step in Create-FreshDb/Restore-All (dba setval block). (5) TRUE durable = EF-model⊇schema.sql (Shell/backend decision).
pickup: 2026-06-13T08:23Z fresh-context resume (SAME slug).
---
=== STATE @ 2026-06-13T10:55Z ===

45 DEPLOY (iter-1b f7fab95) — mechanics DONE; FUNCTIONS CONTENT was broken, now reconciled by dba:
 * iter-1b f7fab95 deployed: DG-1 PASS (8088=127.0.0.1), DG-2 PASS (401 no-token), ApplyService Running, F-3 B1 OK, F-4 ACL OK.
   F-3 B2 BUG: tenant_settings UPDATE used unquoted TenantId -> 42703; operator manual-fixed ("TenantId"/"SignalRConnectionUrl"). Repo fix iter-1c follow-up (deploy: quote Phase 5c B2).
 * RELEASE-BLOCKER found: db/functions/*.sql systematically stale vs schema.sql/C# -> RTM 42703 (NGC_GetOrCreateQueue/AgentGroup CreatedDatetime) + 42883 (NGC_CreateSupergroupAgentgroupMapping arity, RTSData_get* arity, NGC_CreateBusinessUnit 3-vs-5). schema.sql = authoritative. push barrier HELD by coordinator.
 * Coordinator routed regen to DBA (sole owner db/functions/01+02 this round; my E-016 folded). dba regen 3db705d LANDED+verified (cc/dba.md): 6 routines correct, 14 kind-agnostic DROP, GetOrCreate no CreatedDatetime, SAGmapping arity-4 PROC, RTSData_get* arity-1+2 FUNCTION. HEAD 01=835/02=496; working tree TRUNCATED (PD-007) -> repackage from HEAD.

CURRENT: spot-checked cc/dba.md = PASS. Drafted tools/cc_prompt_repackage45_3db705d.md (GO from coordinator 10:37Z):
 from HEAD, hard-gate 01=835/02=496, content-verify (no CreatedDatetime, >=14 DROP guards, CreateBU 5-param, RTSData_get arity-2, both pkg\functions + pkg\db\functions), BOM, ships db/tools (Compare gap fix), NORM-CUR-07 binding, NO push. ISSUED to operator.
 NEXT: package built+verified -> operator re-applies functions on 45 (re-run orchestrator or psql functions/) -> 42883/42703/42809 cascade closes -> RTM log clean, BU/Queue/AgentGroup created -> 45 functions GREEN -> then push barrier can lift.

RE-READS: #1 (1799534) + #2 (21cf075+95196a6, skill 395L) CONFIRMED — NORM-CUR-06 (inbox auto-archival, коорд: чистка, tools/inbox_archive.py at ~40 blocks) + NORM-CUR-07 (CC<->spec binding via .coord/cc/devops.md: open binding + RESULT there, consume + relay digest; git-fallback origin/v2-backend..HEAD if RESULT dropped).

OPEN FOLLOW-UPS:
 - iter-1c: deploy/Apply-Server45Upgrade.ps1 Phase 5c B2 quote "TenantId"/"SignalRConnectionUrl" (+ scan other bare PascalCase in psql -c). -> §4.
 - PD-008 anti-staleness (coordinator 10:35Z, POST-45-GREEN, draft as CC prompts -> §4): P2 deploy pre-flight PG auto-detect + §43 cross-check; P3 Compare-ToBaseline as MANDATORY pre-deploy drift-gate (arity/kind/columns vs C# caller); P1 (w/ dba) Freshness-Audit cadence (regen schema+functions+PG-matrix from known-good dev DB pre-release, maybe scheduled task); P6 rebuild-from-one-fresh-dump rule.
 - build_45: emit INSTALL.txt (-PgVersion 15 + FULL migration filenames + STEP-0 ExecutionPolicy/Unblock-File + DG-1..4 + Compare) + present-assert. orchestrator: normalize migration name prefixes.
 - orchestrator rollback safety-net degrades on re-run (12:49Z).
 - E-016 standalone RETIRED (folded into dba regen).

COMMITS (verify NATIVELY): f7fab95 (deploy iter-1b) + 3db705d (db: dba functions regen) on top of a6fd360/65281a7/87dc034/e17d898/9db8ffd/deb6aa6/60b0cb2/72bd997/3168068/6b82eba/cd576d4. push barrier HELD until 45 functions green. NO push.

COORD MECHANICS: SAME slug devops-2-0607. inbox=.coord/inbox/devops.md; cc-binding=.coord/cc/devops.md (NORM-CUR-07); coordinator=coordinator-0612 (inbox .coord/inbox/coordinator.md). git on mount UNRELIABLE -> verify NATIVELY. bash-mount THIS session cannot see .coord/ NOR repo paths -> .coord small writes via Write tool; inbox handled-markers + coordinator flush on operator-relay backstop (L-SC-19); CC binding RESULT written by CC natively. dba owns db/functions/01+02 this round (do NOT touch). Held: none.

<!-- SESSION ENDED (broken) 2026-06-19T07:40:19Z; superseded by devops-0619; claims released; pending task -> tools/cc_prompt_devops_bom_reencode.md -->
