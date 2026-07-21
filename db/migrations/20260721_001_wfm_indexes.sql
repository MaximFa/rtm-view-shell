-- WFM Phase 1 covering indexes (spec §6). Idempotent.
-- NOTE for DBA/operator apply on 140: RTSData_Interaction is a HOT table. Decide CREATE INDEX CONCURRENTLY
-- (outside a txn, non-blocking) vs plain (brief write lock). This migration uses plain IF NOT EXISTS; the
-- operator MAY run the CONCURRENTLY variant manually on 140 if write-lock is a concern (dba call).

-- λ (arrivals by InQueueDateTime) + covering the λ predicate/columns
CREATE INDEX IF NOT EXISTS ix_rtsint_wfm_inq
  ON public."RTSData_Interaction" ("TenantId","InQueueDateTime")
  INCLUDE ("Workgroup","Direction","InteractionType","CallType","IsCallbackRequest");

-- AHT (completed by AnsweredDateTime) — partial (only answered rows have AnsweredDateTime)
CREATE INDEX IF NOT EXISTS ix_rtsint_wfm_ans
  ON public."RTSData_Interaction" ("TenantId","AnsweredDateTime")
  INCLUDE ("Workgroup","Direction","InteractionType","CallType","IsAnswered","IsInQueue","TalkTime")
  WHERE "AnsweredDateTime" IS NOT NULL;

-- N (serving agents) — RTSData_UserStatus by StatusGroup
CREATE INDEX IF NOT EXISTS ix_rtsus_wfm
  ON public."RTSData_UserStatus" ("TenantId","StatusGroup")
  INCLUDE ("UserId");

-- §38a self-record
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260721_001_wfm_indexes') ON CONFLICT (migration_name) DO NOTHING;
