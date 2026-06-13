# CC Task — DBA(+backend): 45 blocker #3 (42P10) — add EXISTING canonical unique constraint to 45 (drift), NOT a canon change

> Authored by dba-0610. §4-BOUND (coordinator §4 bless BEFORE apply, §26.8). NORM-CUR-07 binding.
> ⚠ DIRECTION CORRECTION (dba review-gate): the canon is NOT missing the unique. schema.sql HEAD line 3487 ALREADY has
> `ADD CONSTRAINT uq_supergroup_agentgroup UNIQUE ("SupergroupId","AgentgroupId")`. The 42P10 on 45 is TABLE DRIFT (the constraint
> never landed on 45's clean rebuild), same class as CustomCallData/CreatedDatetime/MaxDuraction — NOT a schema↔body canon gap.
> ROOT CAUSE (systemic): the rebuild creates tables via `CcDashboard.Web.exe migrate` (EF) + db/functions/; it does NOT apply
> schema.sql (a reference pg_dump). So standalone constraints living only in schema.sql never land on a rebuild unless the EF model
> carries them. => fix 45 now (add the existing-named constraint) + route the EF-model fix to Shell/backend (durable, prevents the class).

## Git push
Do NOT run `git push`. Commit only (fix/db:). Push requested separately (§37).

## Mandatory — read: widget-planner, widget-creator, session-coord, rtm-service-expert (§5/§6) skills.

## STEP 0 — integrity + sync + binding
0a. §0.6a integrity (db/functions/01 PD-007-truncated in WT; this task does NOT edit it — restore-from-HEAD if needed, keep out of claim).
0b. Barrier check. Slug dba-0610. CLAIM: db/migrations/20260613_013_sgag_unique_constraint.sql + staging/45_hotfix_sgag_20260613.sql. (NO schema.sql edit — it already has the constraint.) commit.lock around commit.
0c. NORM-CUR-07 binding: OPEN in .coord/cc/dba.md; RESULT on commit. RTM DB ops = PowerShell + psql.exe on Windows host.

## CALLER/KEY FINDING (backend MUST sign)
- Body: `INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId","AgentgroupId","TenantId") ... ON CONFLICT ("SupergroupId","AgentgroupId") DO NOTHING`.
- Canon constraint = `uq_supergroup_agentgroup UNIQUE (SupergroupId, AgentgroupId)` (matches the ON CONFLICT exactly; NO TenantId — SupergroupId is a global IDENTITY so (SG,AG) is already tenant-unique). Backend: confirm (SG,AG) is the natural key (not (TenantId,SG,AG)).

## STEP 1 — HOTFIX SQL for 45 (staging/45_hotfix_sgag_20260613.sql; operator applies via psql; idempotent, BOM-less)
1. **Dedup guard FIRST** (ON CONFLICT can't be added if dup (SG,AG) rows exist): report dup count; if any, keep MIN("Id") per (SupergroupId,AgentgroupId), delete the rest. (config-sync was failing so likely zero — but guard + report.)
2. **Add the EXISTING canonical constraint** (same name as canon — keeps Compare-ToBaseline clean; do NOT invent a new IX_ name):
   guarded for idempotency (ADD CONSTRAINT has no IF NOT EXISTS):
   ```sql
   DO $add_uq_sgag$ BEGIN
     IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='uq_supergroup_agentgroup'
                    AND conrelid='"NGC_SupergroupAgentgroup"'::regclass) THEN
       ALTER TABLE "NGC_SupergroupAgentgroup" ADD CONSTRAINT uq_supergroup_agentgroup UNIQUE ("SupergroupId","AgentgroupId");
     END IF;
   END $add_uq_sgag$;
   ```
   VERIFY: `CALL "NGC_CreateSupergroupAgentgroupMapping"(12,'vip_support','system','<tenant>')` resolves in a ROLLBACK txn; RTM 42P10 stops.

## STEP 2 — DURABLE (deployed servers + root cause)
- **db/migrations/20260613_013_sgag_unique_constraint.sql** (NEW): the SAME dedup-guard + guarded `ADD CONSTRAINT uq_supergroup_agentgroup` + §38a self-record `INSERT INTO public.db_patch_history (migration_name) VALUES ('20260613_013_sgag_unique_constraint') ON CONFLICT (migration_name) DO NOTHING;`. BOM-less.
- **NO schema.sql change** — it already carries uq_supergroup_agentgroup (HEAD:3487). Adding it again would duplicate.
- **ROOT-CAUSE flag (route Shell/backend, not this file):** the EF BackendEmulation model for NGC_SupergroupAgentgroup must declare this unique (HasIndex(...).IsUnique() / HasAlternateKey) so `Web.exe migrate` creates it on EVERY clean rebuild. Without it, schema.sql-only constraints keep drifting off rebuilds (this whole 45 class). devops/backend own the EF-model + rebuild-runbook hardening (PD-008 P-class). Report this; do not edit src/ here.

## VERIFY + COMMIT
- dev: apply _013 twice -> constraint present once, idempotent; CALL mapping resolves (no 42P10).
- pre-commit-check both files exit 0; §0.6 post-commit; PD-007 re-sync; RESULT (commit + pg_constraint verify + EF-root-cause note) -> .coord/cc/dba.md; NO push.

## Acceptance criteria
- [ ] staging hotfix: dedup-guard + guarded ADD CONSTRAINT uq_supergroup_agentgroup (canonical name), idempotent, BOM-less; CALL resolves.
- [ ] _013 migration mirrors it + §38a self-record; NO schema.sql edit (already canonical).
- [ ] backend signed (SG,AG) key; EF-model root-cause flagged to Shell/backend.
- [ ] dev verify idempotent + 42P10 gone; pre-commit-check exit 0; no push.

## NOTES for coordinator (§4)
- ⚠ Your 17:34 framing "unique MISSING from the canon (schema↔body inconsistency)" is INCORRECT — schema.sql HEAD:3487 HAS `uq_supergroup_agentgroup UNIQUE (SG,AG)`. Your gap-finder read the CREATE TABLE region (PK+non-uniq IX) and missed the separate `ALTER TABLE ADD CONSTRAINT` (pg_dump emits constraints ~600 lines from the table). So: 45-DRIFT, not canon-gap. Corrected the fix: add the EXISTING-named constraint to 45 (Compare-clean), NO schema.sql edit, + flag the EF-model root cause (rebuild=EF migrate, not schema.sql -> standalone constraints don't land).
- This reframes the whole 45 class: CustomCallData1..20 / CreatedDatetime / MaxDuraction / uq_sgag were ALL missing because the EF-migrate rebuild doesn't reproduce schema.sql's full column/constraint set. The migrations (_011/_013) patch deployed servers; the DURABLE class-fix = EF model ⊇ schema.sql (PD-008 P4/P-class, Shell/backend). Recommend a coordinator decision on that.
