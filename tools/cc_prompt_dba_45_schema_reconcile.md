# CC Task — DBA(+backend): ONE-PASS holistic 45 schema reconcile to canon (ends the whack-a-mole)

> Authored by dba-0610. §4-BOUND (coordinator §4 bless BEFORE apply, §26.8). NORM-CUR-07 binding.
> Operator directive (18:11): STOP per-symptom patching. ONE idempotent ADDITIVE script brings 45's STRUCTURE up to schema.sql canon.
> ROOT CAUSE (dba, confirmed): the clean rebuild = `CcDashboard.Web.exe migrate` (EF) + db/functions/; it does NOT apply schema.sql.
> So every schema.sql-only structural object (constraints/indexes/columns) is absent on 45 unless the EF model carries it -> the whole
> 42883/42703/23505/42P10 class. This reconcile is the immediate FULL-COVERAGE patch; the true durable = EF-model⊇schema.sql (Shell/backend, E4).
> _014 is the SUPERSET of the subset hotfixes _011/_012/_013 — but per coordinator 18:19 KEEP _011/_012/_013 (committed, applied on 45, in packages; do NOT retire — would risk the ledger/re-apply). _014 COEXISTS as the full reconcile; their objects re-appear here but IF NOT EXISTS / pg_constraint guards make the overlap a no-op. Add a supersedes-NOTE comment only.

## Git push
Do NOT run `git push`. Commit only (fix/db:). Push requested separately (§37).

## Mandatory — read: widget-planner, widget-creator, session-coord, rtm-service-expert (§5/§6) skills.

## STEP 0 — integrity + sync + binding
0a. §0.6a integrity (db/functions/01 may be PD-007-truncated; NOT edited here — keep out of claim).
0b. Barrier check. Slug dba-0610. CLAIM: staging/45_schema_reconcile_20260613.sql + db/migrations/20260613_014_schema_reconcile.sql. commit.lock around commit. NO schema.sql edit (canon is the SOURCE, already correct).
0c. NORM-CUR-07 binding: OPEN in .coord/cc/dba.md; RESULT on commit. RTM DB ops = PowerShell + psql.exe on Windows host.

## STEP 1 — derive the EXACT 45-missing set (ground truth, not guess)
Combine TWO sources:
(a) **Live Compare [A] delta on 45** (baseline_delta_rtmviewdb_20260613-212532): ⚠ the align.sql does NOT auto-enumerate Dimension A — it reports only LINE-COUNTS (336 missing / 120 extra) + "manual review" (Compare's known limitation; this is exactly what enhancement E2 will automate). So we CANNOT build from align's A-enumeration. -> DERIVE the full canon structural set from (b) and apply it ADDITIVELY/guarded (complete-by-construction: after apply 45 has every canon structural object). Use the 336-missing line-count only as a post-apply sanity check (objects added should roughly account for it). NOTE: columns are ALREADY done — Dim D shows _011 APPLIED (CustomCallData1..20 + MaxDuraction + CreatedDatetime present).
(b) **Canon runtime-critical dependency map (dba-verified, MUST all resolve on 45)** — every db/functions/01+02 `ON CONFLICT` target -> its backing canon object:
   | ON CONFLICT target | canon backing object (must exist on 45) |
   |---|---|
   | (ExternalId, TenantId)            | uq_ngc_queues_external_tenant / uq_ngc_agentgroups_external_tenant (UNIQUE constraints) ← the latest 42P10 |
   | (SupergroupId, AgentgroupId)      | uq_supergroup_agentgroup (UNIQUE constraint) ← _013 |
   | (TenantId, UserId, AgentgroupId)  | IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId (UNIQUE INDEX) |
   | (InteractionId, Segment, ServerId)| IX_RTSData_Interaction_UpsertKey (UNIQUE INDEX) |
   | (MessageId, ServerId)             | IX_RTSData_ChatMessage_MessageId_ServerId (UNIQUE INDEX) |
   | (UserId, StatusId, ServerId, OnDate) | PK_RTSData_UserStatus (PRIMARY KEY) |
   | (SupergroupId)                    | PK_NGC_Supergroup (PRIMARY KEY) |
   | (BusinessUnitId, QueueId)         | PK_NGC_BusinessUnitQueueClassification (PRIMARY KEY) |
   | (BusinessUnitId, SupergroupId)    | PK_NGC_BusinessUnitSupergroup (PRIMARY KEY) |
   Plus getter SELECT col-lists + INSERT/UPDATE targets -> the column set (CustomCallData1..20, MaxDuraction, CreatedDatetime, etc. — _011 set).
The reconcile must ensure ALL of (b) exist on 45, and add anything in (a) that is additive/structural.

## STEP 2 — author staging/45_schema_reconcile_20260613.sql (IDEMPOTENT, ADDITIVE-ONLY, BOM-less)
Bring 45 to canon. NEVER drop/alter "extra" objects (EF may create objects not in schema.sql; line-diff misreads — additive only).
SOURCE = the FULL canon structural inventory of schema.sql (public schema): 3 UNIQUE constraints (uq_ngc_queues_external_tenant, uq_ngc_agentgroups_external_tenant, uq_supergroup_agentgroup) + ALL CREATE [UNIQUE] INDEX (extract verbatim from schema.sql for public.* tables) + the _011 columns. Emit each guarded; skip identity.* (EF-managed, present). The 9-row ON CONFLICT dep-map above is the MUST subset.
1. **UNIQUE constraints** (canonical names -> Compare-clean) — guarded via pg_constraint check; dedup-guard FIRST (keep MIN(id) per key, report) where a UNIQUE could fail on dup data:
   uq_ngc_queues_external_tenant (ExternalId,TenantId), uq_ngc_agentgroups_external_tenant (ExternalId,TenantId), uq_supergroup_agentgroup (SupergroupId,AgentgroupId).
2. **UNIQUE + regular INDEXes**: `CREATE [UNIQUE] INDEX IF NOT EXISTS "<canonical name>" ...` for the public.* objects the bodies need + any from the [A] delta (RTSData_Interaction_UpsertKey, RTSData_ChatMessage_MessageId_ServerId, NGC_UserAgentgroup, + others in delta).
3. **Missing COLUMNs**: `ALTER TABLE ... ADD COLUMN IF NOT EXISTS "<col>" <canonical type>` — the _011 set (RTSData_Interaction CustomCallData1..20 text; RTSData_UserStatus MaxDuraction integer; NGC_Queues/AgentGroups CreatedDatetime timestamptz DEFAULT now()) + any column in the [A] delta. Types EXACT from schema.sql.
4. **Composite PKs** (if the [A] delta shows any missing): guarded; dedup-first; if data would violate -> REPORT + DEFER, do not force.
5. **FKs**: include ONLY guarded/safe; any FK that could fail on existing orphan data -> SKIP + report as a deferral (don't block the reconcile).
Each object guarded for idempotency; safe to re-run on dev/234 (no-op) and on 45 (adds the gap).

## STEP 3 — db/migrations/20260613_014_schema_reconcile.sql (durable mirror) + §38a
Same additive guarded set as STEP 2 (for already-deployed servers via the migration path) + `INSERT INTO public.db_patch_history (migration_name) VALUES ('20260613_014_schema_reconcile') ON CONFLICT (migration_name) DO NOTHING;`. BOM-less. (Fold the _011/_012/_013 objects in — guards prevent double-add; add a comment noting _014 is the full-set superset and _011/_012/_013 are KEPT, not retired — coordinator 18:19.)

## STEP 4 — VERIFY (dev clone dry-run)
- Apply on a dev clone -> every ON CONFLICT target (STEP 1b map) + every getter col-list + INSERT/UPDATE target resolves (invoke each 01+02 routine in ROLLBACK -> no 42P10/42703/42883).
- Idempotent double-apply -> clean.
- (Operator) re-run Compare-ToBaseline on 45 post-apply -> [A] STRUCTURAL drift ~0 (only cosmetic pg_dump ordering remains), [B]=0, no 23505 on QueueGrid save.
- pre-commit-check both files exit 0.

## STEP 5 — COMMIT (commit.lock; §0.6; PD-007 re-sync; NO push)
commit `fix/db: 45 schema reconcile to canon — all UNIQUE constraints+indexes+columns (additive, supersedes _011/_012/_013); ends drift class`. RESULT (full object list + STEP-1b resolution + any deferred FK/PK) -> .coord/cc/dba.md.

## Acceptance criteria
- [ ] Single idempotent ADDITIVE staging script: all canon UNIQUE constraints + unique/regular indexes + missing columns 45 lacks, guarded, canonical names, dedup-guarded where needed; FK/PK risky-cases DEFERRED+reported, never forced; NO drops.
- [ ] _014 durable mirror + §38a; NO schema.sql edit.
- [ ] STEP-1b map: ALL 9 ON CONFLICT backing objects verified present-or-added on 45; getter columns covered.
- [ ] dev dry-run: no 42P10/42703/42883/23505; idempotent; pre-commit-check exit 0; no push.
- [ ] backend SIGNED that the reconcile covers ALL function-body structural deps.

## NOTES for coordinator (§4)
- dba VERIFIED: all 9 ON CONFLICT targets have a matching canon PK/UNIQUE (none is a canon gap — table above). Every 45 failure (42883/42703/23505/42P10 x2) = the SAME 45-DRIFT class (EF-migrate rebuild doesn't reproduce schema.sql structure). This reconcile = full-coverage immediate patch.
- Need the operator's latest baseline_delta_*.txt + align_*.sql for the EXACT 45 missing-set (STEP 1a) — request via operator.
- E4 TRUE DURABLE: EF-model⊇schema.sql (Shell/backend A/B/C decision, post-45). Once done, a clean rebuild + Compare = near-zero [A] and this reconcile is no longer needed for new installs. Reaffirmed.
- DECISION (coordinator 18:19): KEEP _011/_012/_013 (do NOT retire — committed/applied/in-packages; retiring risks ledger/re-apply). _014 coexists as the superset; supersedes-NOTE comment only; guards make the overlap a no-op.
