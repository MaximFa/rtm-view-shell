# CC-HIST-A3 — Per-call call-id linkage (CONTOUR, operator-gated)  [B3]

> Module: Historical Reports. Owner design: role-bi (bi-0619). Implement: role-backend (RTM Engine) + dba (migration/SP).
> STATUS: §4-review DRAFT — CONTOUR. Do NOT apply ANY step without explicit operator confirmation PER APPLY.
> Purpose (operator B3-IN): the call-id does NOT exist on the agent status feed — CREATE it, so agent status rows
> (Hold/Talk/Wrap-Up) can be attributed to the specific call -> FULL PER-CALL queue AHT (Talk+Hold+ACW), upgrading
> the Talk-only queue AHT of CC-HIST-001. This is the ONLY path to per-call Hold/ACW (CC-HIST-001 gives full AHT only
> at the AGENT-interval grain, not per call).

## Why this is contour (MARK every touch)
RTSData_* + RTM Engine are the external RTM contour (CLAUDE.md §33, ADDENDUM A). Every change below touches it:
- (C1) RTSData_UserStatusLog schema — new column (CONFIRMED target = RTSData_UserStatusLog, the per-occurrence INSERT;
  NOT RTSData_UserStatus, the aggregate snapshot).
- (C2) RTSData_SetUserStatus procedure — new parameter.
- (C3) RTM Engine / DBMng — produce + pass the call-id.
MidnightClear is dead code (Engine.cs:957) — unrelated, do NOT touch. Coordinate deploy as ONE release (Shell+DB+RTM)
to avoid signature-skew (deploy lesson: changing an SP signature requires Shell+DB shipped together).

## FEASIBILITY — RESOLVED by backend-0620 = PARTIAL-YES (stamp at the CALC-STATUS PRODUCER, not userStatusChanged)
DO NOT stamp from Engine.userStatusChanged (it carries no call-id). The calc statuses Hold/Talk/Wrap-Up are EMITTED
inside `Call.SetCall` via `userMng.setStatus(..., isCalcStatus=true)` — at that producer the EXACT IdInteraction.
InteractionId is in hand. Correlation rule (backend-owned):
- UserManager stashes `_currentStatusInteractionId` per OPEN status interval (thread it as the last param through the
  setStatus calc path). It is WRITTEN when the interval CLOSES: UserStatusData.addDur -> DBMng.addUserStatusRequest ->
  RTSData_SetUserStatus @InteractionId (last param).
- Class A (call-bound calc statuses: Talk/Hold/Wrap-Up) = EXACT InteractionId.
- Class B (READY / NOT_READY / LOGOUT) = NULL (no call). 
- Concurrent (consult / conference / blended chat+voice) = stamp the TRIGGERING interaction, or NULL — a per-agent
  single status timeline cannot non-ambiguously hold two calls. NEVER fabricate; NULL where ambiguous (per-call
  attribution simply absent there; agent-interval full AHT from CC-HIST-001 still holds regardless).

## DESIGN (subject to backend feasibility + operator per-apply confirm)
(C1) Migration db/migrations/2026MMDD_0NN_userstatuslog_callid.sql (dba): ALTER TABLE "RTSData_UserStatusLog"
     ADD COLUMN "InteractionId" varchar(50) NULL; index ("TenantId","InteractionId"). Self-record db_patch_history (§38a).
(C2) Recreate "RTSData_SetUserStatus" with a 16th param p_interaction_id text (APPEND last — never mid-list, §33.4);
     set "InteractionId" on the RTSData_UserStatusLog INSERT. Keep PROCEDURE kind (RTM-SEC-002 prokind='p').
(C3) backend RTM/RTM (owns impl): thread InteractionId through the CALC-STATUS PRODUCER path —
     Call.SetCall -> userMng.setStatus(..., isCalcStatus=true, interactionId) ; UserManager stashes
     _currentStatusInteractionId per open interval; on interval close UserStatusData.addDur ->
     DBMng.addUserStatusRequest (UserStatusDBRequest gains InteractionId) -> RTSData_SetUserStatus @InteractionId (last).
     Class A=exact, Class B=NULL, concurrent=triggering-or-NULL. Log NULL. NOT from Engine.userStatusChanged.
(C4) Reporting (role-bi, follow-up to CC-HIST-001, NON-contour): per-call attribution join
     RTSData_UserStatusLog."InteractionId" = RTSData_Interaction."InteractionId" (+ Workgroup/TenantId) to sum Hold/ACW
     per call -> upgrade Q1 queue AHT to full per-call AHT (Talk+Hold+ACW). Add SumHold/SumAcw to hist_queue_intervals
     (new migration) once C1-C3 are live and populating.

## ORDER OF OPERATIONS (each step operator-confirmed)
1. Feasibility = RESOLVED (backend-0620, PARTIAL-YES, producer-stamp above). Agent-grain full AHT from CC-HIST-001
   ships regardless; this adds per-call attribution where Class A applies.
2. dba C1+C2 migration authored -> §4 + dba review -> operator confirm -> ONE-release deploy with C3.
3. backend C3 Engine/DBMng -> §4 -> operator confirm.
4. role-bi C4 reporting upgrade -> §4 -> normal (non-contour) deploy.

## Discipline
- Each implementing prompt carries the standard blocks (§0.6a integrity, §40 skills, §42.6 sync with that role's slug
  + claims [backend = RTM/RTM/*.cs; dba = db/migrations + db/functions], §0.6b binding, pre-commit + §0.7 re-sync).
- NO git push (§37). Commits native-CC under commit.lock.
- This is a DESIGN/coordination prompt — it is NOT executed as-is; it drives the per-role implementing prompts above,
  each gated by operator confirmation and coordinator §4.
