---
role: backend
project: RTM View Shell
version: 0.2
last_verified: 2026-08-31T07:55:00Z
owner: backend
reviewer: curator
---
# role-backend — RTM Server / Shell Backend role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (git log RTM/ + .coord/journal.md backend lines + .claude/memory/rtm-*), NOT session
> narrative. Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
### ⛔ ЧП / EMERGENCY MODE — ACTIVE (declared 2026-06-25 coordinator-0624; REMOVE on operator lift)
Release is bug-ridden (dashboards) + the reports version blocking its fixes is in catastrophic state → emergency until the operator lifts ЧП.
1. NO corner-cutting; ANY detail (ESPECIALLY visual) = critically RED — every defect is a blocker, no "minor".
2. NO decision around the coordinator; every fork → coordinator → operator (ONE at a time, by importance, plain language).
3. NO unsanctioned runs: do NOT hand the operator a chat CC run-prompt code-box UNTIL the coordinator's §4 bless.
4. Coordinator PERSONALLY visual-verifies EVERY closed gap (not object-store/report alone).
5. Verify on REAL prod-mirror data (234 backup, RTSData_*); our env = a FROZEN data-mirror of prod; our migration package = our migrated DB. One-time seed from the backup.
6. Protocol shorthand: `.` = `коорд: входящие`; `..` = "check the result" (specs know it).
7. Coordinator + operator steer the recovery out of the dive.

Role: RTM Windows Service engine (RTM/RTM/*.cs) + SQL routines (db/functions/*.sql) + Shell<->RTM SignalR relay.
Claim: RTM/, db/functions/ (routine logic; DBA reviews DB-consistency).

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **RTM-SEC-002: RTM write routines MUST be PROCEDURE, not FUNCTION.**
   `CALL` on a FUNCTION raises 42809 (wrong object type) at RTM runtime on EVERY event.
   · SOURCE: fb118ff (12 NGC_* FUNCTION->PROCEDURE), aae7efa (RTSData_* FUNCTION->PROCEDURE), journal 2026-06-07T15:07Z

2. **`@TenantId`/`p_tenant_id` is the LAST parameter in all multi-tenant routines.**
   Minimises positional breaks in existing C# call sites.
   · SOURCE: CLAUDE.md §33.3, b4fe8ac (TenantId support commit)

3. **One RTM Service instance = one Tenant.** TenantId from `RTM:TenantId` in appsettings.json.
   · SOURCE: CLAUDE.md §33.1, AppConfig.cs:TenantId

4. **Shell connects to RTM via SignalR CLIENT (single-port relay).** Browser never contacts RTM directly.
   RTM hub URL from `TenantSettings.SignalRConnectionUrl`.
   · SOURCE: CLAUDE.md §34, RtmRelayService.cs, 0c3c902 (CC-003 relay commit)

5. **DataGrid requires BOTH `init` AND `refreshCells` to receive initial data push.**
   `init` alone does not trigger a push.
   · SOURCE: .claude/memory/rtm-relay-implementation.md, RTMHub.cs:init

6. **All hub params use `JsonElement`.** Typed params cause silent message drops.
   · SOURCE: CLAUDE.md §34.5, RTM-PROTO-01

7. **Engine.LoadData runs at STARTUP ONLY.** No hot-reload of grid/union/cell config.
   · SOURCE: Engine.cs:LoadData, rtm-service-expert §2

8. **[WIRE-01..05] Adapter↔RTM Service wire is a byte-compat CONTRACT — MANDATORY validate on ANY wire change.**
   Adapter code (RTM.Adapter.Common, adapters branch) is decoupled from RTM-core, but the pipe JSON dict shape
   (`"method"`+field names), DateFormatString, Agent DTO PascalCase, NamedPipe framing (Unicode+Message+name), and
   serializer settings MUST match RTM Service. Contract round-trip test gates BOTH branches' push barriers (QA).
   · SOURCE: CLAUDE.md §48, .coord/wire_contract.md

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-06 · NGC_Set/DeleteUserAgentgroup shipped as FUNCTION; plumbing test (SELECT) passed but prod CALL -> 42809 · ALWAYS test via CALL, verify prokind='p' · SOURCE:_009 hotfix, journal 2026-06-07 · status: active
- 2026-06-06 · StatusGroup column missing from RTSData_UserStatusLog (pgloader gap) -> empty DayTrend agent metrics · migration _004 · SOURCE:_004, rtm-service-expert §10 · status: active
- 2026-06-07 · Compare baseline had 13 routines as FUNCTION while prod (correct) had PROCEDURE; align.sql would have reverted prod -> 42809 storm · NEVER run align.sql blindly; verify which side is right · SOURCE:rtm-service-expert §10, journal 2026-06-07T15:14Z · status: active
- 2026-06-07 · sig-specific DROP FUNCTION fails if server has different arity; use sig-agnostic DROP · SOURCE:55eb049, journal 2026-06-08T01:36Z · status: active
- 2026-06-09 · Engine TryGetValue guards needed on UnionList/_gridList (whole-list-killed bug) · SOURCE:803832a, 160259a · status: active
- 2026-06-25 · ref: visual-check prep runbook = **docs/Visual-Test-Preflight.md** (profiles A=rebuild / B=running; shared gate Chrome→Soma /health:5199→Shell /ops/health.up→restart×3→start). Use when running or awaiting a visual check. · SOURCE: docs/Visual-Test-Preflight.md · status: active
- 2026-07-11 · Adapter uses only 9 files of RTM.Tools/RTM.Types, ZERO RTM-core coupling → minimal RTM.Adapter.Common (NOT a full-lib fork). But serializer + NamedPipe transport + Agent DTO are a WIRE CONTRACT with RTM Service: code may diverge, FORMAT may NOT. [WIRE-01..05] + a mandatory round-trip contract test = push-barrier gate on BOTH v3 (RTM pipe/Agent/serializer change) AND adapters (adapter change); whoever changes one side flags the counterpart to re-validate together. · SOURCE: CLAUDE.md §48, .coord/wire_contract.md · status: active
- 2026-07-15 · Runtime defect NOT deducible from code + not resolvable at the current log level (AgentGrid empty on 140: 3 contradictory field facts, root oscillated adapter↔RTM-1:many↔delivery) · FIRST expand LOGS in the problem area (log-only, no logic change) BEFORE hypothesising a fix — log-only deploys are fast + prod-safe (scope to OUR binary; legacy is a separate binary → untouched). Add the DECISIVE discriminator line at the exact fork (e.g. refreshUnions MISS need=[wgArr] have=[_workgroups] — arrives-but-token-mismatch vs never-arrives) · SOURCE:tools/cc_prompt_rtm_diaglog.md, operator directive 2026-07-15 · status: active
- 2026-07-15 · AgentGrid rows present but ALL per-agent cells blank (name/state/duration/OCC/ADH) · ROOT = user-grid METRICS not defined in RTSGrid_Metric → union.UserGridMetrics empty → UserManager.UserData stays roster-only (AgentLoginName+USERID) → updateUserGrid ships no cells (CollectData LongestAction=0). NOT widget, NOT assembly (Union.getUnionUserData ships userMng.UserData fine). Diagnostic ladder: Shell `RECV updateUserGrid union N` fields=[..] (DiagPushLogging) → RTSUserGrid_Grid/Column config → RTSGrid_Metric has the 5 agent metrics (AgentName/AgentState/AgentStateDuration/AgentOccupancy/AgentAdherence). Fix = seed the metrics; MUST export to git db baseline (Export-All → db/data/02_metrics.sql) or it regresses on fresh install. · SOURCE: Engine.cs Union_UserGridEvent/getUnionUserData, UserManager.cs:43 UserData, 140 fix 2026-07-15 · status: active
- 2026-07-16 · Postgres `AT TIME ZONE '<numeric-offset-text>'` (e.g. '+02:00') INVERTS the sign (POSIX) → a +02:00 timestamptz maps to the PREVIOUS local day; broke the RTSData_GetInteractions TZ-guard (undercount) · For a TimeZone column holding OFFSET strings use `AT TIME ZONE ((tz)::interval)` (interval does NOT invert); reserve bare `AT TIME ZONE 'name'` for NAMED zones ('Israel'/'UTC'). Mixed column → CASE on `^[+-]\d{2}:\d{2}$` · SOURCE: 0b07651 bug + fix tools/cc_prompt_tzguard_signfix.md, 140 data 2026-07-16 · status: active

- 2026-08-31 · My own §C VERIFY failed 2 of 5 items and BOTH failures were defective PREDICATES, not code drift: #1 grepped the literal `CREATE PROCEDURE` while 13 of 15 procedures read `CREATE OR REPLACE PROCEDURE` (2 vs 15); #2 grepped lines `p_tenant_id uuid` not ending in `)` while signatures are written multi-line (25 false "violations"; a signature parse gives 42 routines, 0 not-last) · RULE: **a failing check must first prove ITSELF sound** (negative control + read the predicate against how the file is actually written) before it is allowed to accuse the code. "Reality wins — update me" hands authority to the CODE, never to a grep: marking §A#1/#2 superseded here would have deleted two live norms (RTM-SEC-002 and tenant-last) because of a broken regex. Also: a COUNT of procedures cannot prove RTM-SEC-002 — the routine files keep an authoritative overload set per name (Shell FUNCTION arities + the RTM PROCEDURE arity); check the arity RTM CALLs. · SOURCE: role-backend §C rewrite 2026-08-31, curator brief `.coord/protocols/backend-handoff.md`, answers in `.coord/backend-reconstitution-test.md` · status: active
- 2026-08-31 · Asserted a MECHANISM from memory and got it backwards: claimed a `git add` warning "paths are ignored by .gitignore" on `.claude/` means the work is LOST. It does not — ignore rules apply only to UNTRACKED paths; a tracked file under an ignored directory commits with a plain `add`, and `-f` is needed only to INTRODUCE a new path. Pins: `.gitignore:49 = .claude/` while `git ls-tree -r --name-only v3 .claude | wc -l` = 58, `check-ignore -v` on the tracked skill prints nothing (rc=1), `ls-files --error-unmatch` rc=0. The refutation was a pin I had taken MYSELF an hour earlier (`v3:.claude/skills/role-backend/role-backend.md` = `5981015` == disk) and walked past · RULE: **a claim about a MECHANISM needs a pin exactly as much as a claim about STATE** — "I know how git behaves" is a memory, subject to the same test as any other memory (did I run it in THIS awakening?); and when a pin already taken contradicts what you are about to say, reconciling it is the speaker's job, not the reader's. Corollary: a defective ANALYSIS costs more than a defective fact — it makes a routine commit read as data loss and invites "restoring" a file over someone's newer edit. · SOURCE: curator verdict + resit in `.coord/backend-reconstitution-test.md` 2026-08-31, `CLAUDE.md:3043` read in full · status: active

## §C VERIFY  (run at init — OBJECT STORE ONLY, NORM-CUR-13; mismatch -> superseded, don't act)
> Rewritten 2026-08-31 (backend-0831, condition of attestation): the previous form was `grep` over the
> WORKING TREE — the surface §0.3 says lies (buffer cache shows a whole file while the mount holds a
> truncated one), and the surface that cannot tell "committed" from "edited but never staged".
> Two of its five predicates were also DEFECTIVE, and the defect read as code drift (see §B 2026-08-31).
> Rules for this section: every item names its REF, states its EXPECTED count BEFORE the run, and item 0
> proves the harness can return 0. A differing count is a FAILURE to investigate, not a judgement call —
> and the first suspect is the PREDICATE, not the code.
> `<ref>` = the branch from the handoff (today `v3`) — never a bare path, never `HEAD` by assumption.

0. **Negative control** (proves the predicate can fail):
   `git show v3:db/functions/01_ngc_functions.sql | grep -c 'ThisMarkerMustNotExist'` — MUST be `0`.
   Anything else (or an error instead of `0`) = the harness is broken; fix it before trusting 1-8.
1. **RTM-SEC-002, count** (§A#1): `git show v3:db/functions/01_ngc_functions.sql | grep -cE 'CREATE (OR REPLACE )?PROCEDURE'` — expect **15**;
   same on `02_rtsdata_functions.sql` — expect **3**.
   ⚠ The old predicate searched the literal `CREATE PROCEDURE` and returned **2**, because 13 of the 15 are
   written `CREATE OR REPLACE PROCEDURE`. Count changed and the delta is explained by new routines -> re-pin
   the number and the date here; unexplained -> investigate before acting.
2. **RTM-SEC-002, the part that actually matters** — the RTM-CALLed write routines are PROCEDURE:
   `git show v3:db/functions/01_ngc_functions.sql | grep -cE 'CREATE (OR REPLACE )?FUNCTION "NGC_(Set|Delete)[A-Za-z]*"'` — expect **1**,
   and that one is KNOWN and intentional: `NGC_DeleteBusinessUnitQueueClassificationMapping` **arity-3**
   (`RETURNS void`, Shell-called); the arity-4 RTM overload IS a PROCEDURE (file comment: "Arity-4 … PROCEDURE — RTM").
   `git show v3:db/functions/02_rtsdata_functions.sql | grep -cE 'CREATE (OR REPLACE )?FUNCTION "RTSData_Set'` — expect **0**.
   A COUNT of procedures can never prove RTM-SEC-002 on its own: the file deliberately keeps an
   authoritative OVERLOAD SET per name (Shell FUNCTION arities + the RTM PROCEDURE arity). What must hold is
   that the arity RTM `CALL`s is PROCEDURE — check the arity, not the name.
3. **Kind-agnostic DROP guard** (§B 2026-06-07: a signature-specific DROP fails when the server has a
   different arity, and a re-created FUNCTION then shadows the PROCEDURE):
   `git show v3:db/functions/01_ngc_functions.sql | grep -c 'FROM pg_proc WHERE proname='` — expect **14**.
4. **`p_tenant_id` LAST** (§A#2) — parse SIGNATURES, never grep lines. A line-wise grep cannot see a
   multi-line signature, and a non-greedy regex silently EATS the next declaration (§B 2026-08-31):
   ```
   for f in $(git ls-tree --name-only v3 db/functions/); do git show v3:$f; done | python3 -c '
   import sys,re
   t=sys.stdin.read(); tot=bad=0
   for m in re.finditer(r"CREATE\s+(?:OR\s+REPLACE\s+)?(?:FUNCTION|PROCEDURE)\s+\"?[\w.]+\"?\s*\(",t,re.I):
       i=m.end()-1; d=0
       for j in range(i,len(t)):
           if t[j]=="(": d+=1
           elif t[j]==")":
               d-=1
               if d==0: break
       a=t[i+1:j]
       if "p_tenant_id" not in a: continue
       tot+=1; out=[]; dd=0; cur=""
       for ch in a:
           if ch=="(": dd+=1
           elif ch==")": dd-=1
           if ch=="," and dd==0: out.append(cur); cur=""
           else: cur+=ch
       out.append(cur)
       if "p_tenant_id" not in out[-1]: bad+=1
   print("routines:",tot," not-last:",bad)'
   ```
   expect **`routines: 42  not-last: 0`**. The old predicate reported 25 "violations" — all false, it
   assumed a one-line signature.
5. `git show v3:RTM/RTM/appsettings.json | grep -c '"TenantId"'` — expect **1** (§A#3, one instance = one tenant).
6. `git show v3:src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | grep -cE 'SubscribeUnionAsync|SubscribeGridAsync'` — expect **2** (§A#4 relay).
7. `git show v3:src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | grep -c 'JsonElement'` — expect **3** (§A#6, typed hub params drop silently).
8. **Store vs mount — the reason this whole section was rewritten:**
   `git rev-parse v3:.claude/skills/role-backend/role-backend.md` == `git hash-object .claude/skills/role-backend/role-backend.md`.
   Differ -> this skill on disk is NOT the one in the branch: say so and pin which is which before acting.
   Same check for any `db/functions/*.sql` or `RTM/*.cs` you are about to reason about.

**If an item fails, the order of suspicion is fixed:** (1) is the PREDICATE right — can it return 0, does it
match how the file is actually written, does it read signatures rather than lines? (2) is the REF right?
(3) only then the code. "Reality wins — update me" transfers authority from §A to the CODE, never to a
grep: marking a §A truth superseded because a defective predicate failed deletes a live norm.

## §D REFERENCE  (optional · NOT loaded each init)
Full reference: `.claude/skills/rtm-service-expert/rtm-service-expert.md` (engine architecture, SQL routine catalogue, data flows).
Shell relay: `.claude/memory/rtm-relay-implementation.md`.

2026-07-20 · MAXWAIT F5-reset: live UI repro (queue unchanged 12/11/1, F5 dropped 01:06->00:23) beat a static-code read that had (wrongly) concluded 'no rebase'. Operator lead: reset = per-service-instance CONSTANT (8s/48s) = startup-anchored base, not now-enqueue/now-resubscribe. Relay ruled out (CellSnapshot refreshed per-push + wiped on dispose). · RULE: for a timing/state bug, a controlled live before/after with an UNCHANGED input beats a static read AND an incomplete log window; and a per-instance CONSTANT reset => a startup-anchored base, look at where enqueue-time is stamped at service start. · SOURCE:RtmRelayService.cs:687 + Engine.cs:3054/IDInteraction.cs:298 + live 140 repro · status: active

2026-07-20 · MAXWAIT F5-reset ROOT = SHELL widget local-tick anchor, NOT RTM enqueue re-stamp (I chased RTM for 3 rounds; operator's 'RTM sends start, Shell ticks on visual' model was right). QueueGridWidget.ApplyMetricValue anchors on (received-elapsed, receipt-walltime) + PeriodicTimer(1s) climbs client-side; RTM freezes the pushed elapsed; F5 loses local accumulation -> re-anchors to stale frozen base. · RULE: when a value CLIMBS smoothly 1s/s but RESETS on client refresh, suspect CLIENT-SIDE ticking/anchoring FIRST, not the server — check the widget's timer/anchor before instrumenting the server. Fix = anchor on the ABSOLUTE start instant the server already provides (Value2 datetime), not received-elapsed+receipt-time. · SOURCE:QueueGridWidget.razor:1300-1320,1375 + RtmRelayService.cs:683 + live 140 repro · status: active
