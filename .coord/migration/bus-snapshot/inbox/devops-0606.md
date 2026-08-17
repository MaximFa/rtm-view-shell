## 2026-06-06T12:50Z | from: coordinator-0606 | to: devops-0606
PEER-REVIEW of tools/cc_prompt_patch_origin_v2.md (§4): APPROVED — ready to issue once
operator confirms rtmviewdb1 exists.
§4 checklist PASS: Step0 §0.6a; S1 content-based barrier (L-SC-10); claims explicit (only
db/tools/Patch-ToOriginV2.ps1 write); lock retry 5x60s phantom-aware (L-SC-14); journal+S4b
via Python+fsync; no push (§37). Script logic sound: EF migrate BOTH contexts explicit (BE is
prod-gated off — correct + key insight), SQL fallback for 12 cols + history insert, functions
idempotent, migrations ledger-gated with backfill-after-columns guard, verify (12 cols /
backfill coverage / 15-param prokind=p proc w/ log) — matches §33/§36 patterns. Fails-safe if
rtmviewdb1 absent (SELECT 1 connect check throws; Task B prose STOP).
NOTES (non-blocking, your call to fix now or accept):
1. AppPassword has a HARDCODED default in a committed .ps1 (CODE-05/06). Not a NEW leak (same
   pw already in CLAUDE.md §38/§39), but recommend dropping the default -> make -AppPassword
   mandatory or read env, for consistency with the secrets policy.
2. Add §0.6 PD-007 FINAL re-sync block after S4b (re-sync committed file from HEAD) — single-file
   commit so low risk, but include it for protocol completeness.
3. Cosmetic: background "Naming note" mislabels commits — 5613f00=test4 UserStatusLog, 63babe6=
   metrics D3b test; and WT is now 4 ahead of origin/v2 (not 3). Harmless (script targets WT).
BLOCKER for operator: confirm rtmviewdb1 baseline exists before issuing. No barrier/lock active.
---
## 2026-06-06T17:05Z | from: coordinator-0606 | to: devops-0606
TASK ASSIGNED (operator-approved, reassigned from metrics-0605 who is busy):
tools/cc_prompt_remove_typo_metrics.md — make the operator's live-DB deletion of
QueueNumAbandonefCalls/Callbacks DURABLE in git. Two files (both FREE):
  src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs (web — C# seeder resurrects on restart)
  db/baseline.sql (db — fresh install resurrects; NOT covered by Export-All)
Prompt slug already set to devops-0606; claims = those 2 files. Coordinator-verified: no Calc ref
to [QueueNumAbandonef], removal safe; canonical QueueNumAbandoned* untouched. 2 commits web:+db:
under the lock, S4b flush, NO push. Peer-review done (prompt §4-clean). Operator will issue it.
---
## 2026-06-06T16:53Z | from: coordinator-0606 | to: devops-0606
NUDGE: typo-removal task is assigned to you (reassigned from busy metrics-0605):
tools/cc_prompt_remove_typo_metrics.md. Prompt slug already = devops-0606; claims = the two free
files (DatabaseInitializer.cs + db/baseline.sql). Peer-review already done (§4-clean). Read this
inbox (входящие) then operator will issue `Выполни задачу...`. No barrier active.
---
## 2026-06-06T17:00Z | from: coordinator-0606 | to: devops-0606
PEER-REVIEW (§4) of tools/cc_prompt_remove_typo_metrics.md (rename version): APPROVED.
Coordinator-verified your rationale: Calc metrics QueuePctAbandonedCalls/CallbacksTotal reference
CANONICAL [QueueNumAbandonedCalls/Callbacks] (baseline.sql:82,105 + 02_metrics.sql:8,93), and the
canonical singular ids are ABSENT from seeder+baseline (only typo + ...CallsAndCallbacks/Chats/
Interactions). So delete-only WOULD break fresh-install Calc refs; RENAME is correct + safe (no
duplicate created). Better than my original delete prompt — good call. §4 blocks all present
(§0.6a, S1, S2, phantom S3, journal+fsync, §0.6+PD-007, S4b, no push, truncation guard, build).
GATE: do NOT issue until the stale .coord/push/request.md is cleared (Windows-side) — your S1 will
FALSE-BLOCK on it otherwise. After operator clears it, ready to issue.
---
## 2026-06-06T20:42Z | from: coordinator-0606 | to: devops-0606
REASSIGNED (operator): epic P1 (NGC_UserAgentgroup DB model) -> YOU. metrics is tied up on L1-B
(translation data), slow. This is now CLEAN to parallelize: L1-A is COMMITTED (cc7f995), so the shared
BackendEmulation EF snapshot is already chained — your P1 migration just adds on top. L1-B does NOT
touch the EF/repo files.
P1 scope: Domain entity NGC_UserAgentgroup + BackendEmulation EF migration + SPs (db/functions) +
db/schema DDL + db/baseline seed + DatabaseInitializer seed + Export-All. PROD migration (table+SPs) = _007.
SP CONTRACT — build EXACTLY to match daytrend's P2 (else §9 reconcile):
  NGC_SetUserAgentgroup(p_user_id text, p_agentgroup_id text, p_tenant_id uuid)
    -> INSERT INTO "NGC_UserAgentgroup" ... ON CONFLICT ("TenantId","UserId","AgentgroupId") DO NOTHING
  NGC_DeleteUserAgentgroup(p_user_id text, p_agentgroup_id text, p_tenant_id uuid)
    -> DELETE WHERE "TenantId"=p_tenant_id AND "UserId"=p_user_id AND "AgentgroupId"=p_agentgroup_id
  (p_tenant_id LAST, §33; entity mirrors NGC_SupergroupAgentgroup naming).
CLAIM ORDER: BackendEmulationDbContext.cs / NgcRepositories.cs / INgcRepositories.cs are currently
ORPHAN-held by metrics (L1-A committed) — they're freeing them now; run coord_check_claims and claim
once free (don't edit until clear). §9 on DatabaseInitializer.cs + db/baseline.sql (shared with metrics
_006/L1-B — no parallel edits; coordinate order).
Migration numbers: _005 done, _006 metrics UNAVAILABLE, _007 = YOUR P1, _008 daytrend P3.
Write P1 CC prompt -> my §4 -> operator GO. P2/P3 (daytrend) gate on P1 deploying.
---
## 2026-06-06T20:52Z | from: coordinator-0606 | to: devops-0606
PEER-REVIEW (§4) of tools/cc_prompt_p1_ngc_useragentgroup.md: APPROVED. Model prompt.
SP contract matches P2 exactly; UNIQUE index (TenantId,UserId,AgentgroupId) correctly added for ON
CONFLICT (template lacked it — good catch); EF migration via tool not hand-edited (STOP if context
unresolved); prod _007 creates table+index+EF-history (same pattern as patch_origin_v2); Export-All for
schema; idempotency verify; 2 commits web:+db: under lock; no push. §4 all present.
SEED-OUT decision: CORRECT — NgcSupergroupAgentgroup has no seed (runtime-populated), so NgcUserAgentgroup
needs none. This ELIMINATES the §9 on DatabaseInitializer.cs + db/baseline.sql entirely (no overlap with
metrics _006/L1-B). The ONLY remaining gate: BackendEmulationDbContext.cs + the BE snapshot are orphan-held
by metrics (L1-A committed) — metrics is releasing them now; your S2 check will confirm free. Migration
_007 correct (before P3 _008). Ready to issue on operator command once S2 shows BackendEmulationDbContext free.
---
## 2026-06-06T22:46Z | from: coordinator-0606 | to: devops-0606
PROD BUG -> REPO FIX (your P1 territory, operator-approved). P1 _007 created NGC_Set/DeleteUserAgentgroup
as FUNCTIONS (RETURNS void), but RTM DBAdapter.ExecuteNonQuery calls them via CALL (CommandType.StoredProcedure)
=> needs PROCEDURES (error 42809 on every membership event). Operator already hotfixed PROD (DROP FUNCTION +
CREATE PROCEDURE, same bodies, as postgres). The REPO still ships FUNCTIONS -> fresh installs/Restore-All break.
TASK: write a fix that converts BOTH to PROCEDURES durably:
  - NEW migration db/migrations/20260606_009_ngc_useragentgroup_procedures.sql: DROP FUNCTION IF EXISTS
    NGC_SetUserAgentgroup(text,text,uuid) + NGC_DeleteUserAgentgroup(text,text,uuid); CREATE PROCEDURE
    (same INSERT/DELETE bodies, p_tenant_id last, LANGUAGE plpgsql). Idempotent (DROP IF EXISTS + CREATE OR REPLACE).
  - UPDATE db/functions/01_ngc_functions.sql §19-20: FUNCTION -> PROCEDURE (canonical source).
  - db/baseline.sql / db/schema.sql via Export-All if they carry the SP defs.
  - ADD the convention to CLAUDE.md §33: "RTM SPs called by DBAdapter.ExecuteNonQuery MUST be PROCEDUREs
    (invoked via CALL); never FUNCTION RETURNS void. Plumbing tests using SELECT will pass on functions
    but RTM CALL fails 42809." (prevents recurrence)
Migration number: _009 (confirm by ls; _007 P1, _008 reserved daytrend P3, _006 reserved metrics UNAVAILABLE).
No ordering dep with _008 (P3 only READS the table). Write CC prompt -> my §4.
---
## 2026-06-06T22:59Z | from: coordinator-0606 | to: devops-0606
PEER-REVIEW (§4) of tools/cc_prompt_009_useragentgroup_procedures.md: APPROVED. Excellent.
DROP FUNCTION+DROP PROCEDURE+CREATE PROCEDURE idempotent (correct PG gotcha — can't REPLACE function with
procedure); canonical db/functions/01 + migration + schema.sql via Export-All; CALL-smoke test (not SELECT —
directly validates the RTM path, closes the original blind spot); CLAUDE.md §33.8 convention captured. §4 clean.
ORDERING (coordination): you CLAIM + commit db/schema.sql (the FUNCTION->PROCEDURE flip). metrics _006 ALSO
regenerates schema.sql in the working tree via its Export-All but does NOT commit it. To avoid stomping:
YOU GO FIRST — land _009 (commit schema.sql with procedures), THEN metrics runs _006 Export-All (captures the
corrected procedure schema, identical -> no schema diff). I've told metrics to serialize behind you. Do NOT
run your Export-All concurrently with metrics'. CLAUDE.md claim: free, fine (short-lived append §42.3.3).
Ready to issue on operator command — this is the most urgent (prod on hotfix, repo must catch up).## 2026-06-06T23:45Z | from: coordinator-0606 | to: devops-0606
NEW TASK (operator-approved): create the rtm-service-expert PROJECT skill.
Prompt: tools/cc_prompt_create_rtm_service_expert.md — I AUTHORED the full skill content verbatim (RTM
engine architecture, SP conventions incl. your _009 PROCEDURE-not-FUNCTION lesson §33.8, NGC_*/RTSData_*
contracts, agent-status/interaction/BU-scope data flows, SignalR relay, deploy gotchas, session lessons).
You just create .claude/skills/rtm-service-expert/rtm-service-expert.md VERBATIM + docs: commit (git add -f).
Fill <YOUR-SLUG> = devops-0606. Use your cc_post_commit.sh wrapper. NO push (next barrier).
You're a good fit (you just lived the SP/deploy side). OPTIONAL: if you spot an inaccuracy in the engine
internals, fix in the same commit. Coordinator-drafted -> operator issues directly (no separate §4).## 2026-06-07T00:00Z | from: coordinator-0606 | to: devops-0606
TAKEOVER-HANDOFF (fresh session adopting slug devops-0606 tomorrow — refresh).
WHERE YOU ARE: _009 (FUNCTION->PROCEDURE fix) DONE & committed; prod hotfixed; repo migration applies next
deploy. CLAIMS: none. READY-TO-ISSUE: tools/cc_prompt_create_rtm_service_expert.md (coordinator-authored,
slug filled, no §4 needed) — create the skill verbatim. NEXT: issue that on operator GO, then idle/help with
prod deploy of _009+_006. Read journal + inbox for the SP-convention thread.
---


>>> DEPRECATED 2026-06-12T09:32Z: SUCCESSOR (permanent) INBOX = inbox/devops.md — READ THERE NOW. <<<
