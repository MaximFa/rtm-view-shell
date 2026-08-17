
## 2026-06-13T10:17:42Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_reconcile_ngc_overloads.md | status: open
### DIRECTIVE (spec->CC): reconcile db/functions/01_ngc_functions.sql + 02_rtsdata_functions.sql to authoritative source (schema.sql) for NGC_Create*/GetOrCreate + RTSData_get* arity-2. Claims: db/functions/01_ngc_functions.sql, db/functions/02_rtsdata_functions.sql. 45 release-blocker fix (42883 arity + 42809 re-apply + 42703 CreatedDatetime).
### RESULT (reconciled by spec from git object-store — CC's RESULT block dropped, L-SC-04): status: done
- Commit: **3db705d** "db: reconcile NGC_Create*/GetOrCreate + RTSData_get* arity-2 (45 42883/42703/42809 fix)" (2 files, +452/-426).
- Object-store VERIFY (HEAD): GetOrCreateQueue/AgentGroup INSERT (Id,ExternalId,Name,IsActive,TenantId) gen_random_uuid()+true, NO CreatedDatetime [42703+E-004]; 14 kind-agnostic pg_proc DROP guards; NGC_CreateSupergroupAgentgroupMapping FUNCTION(int,text,uuid)+PROCEDURE(arity-4); RTSData_getInteractions/getUsersStatuses BOTH arity-1 + arity-2 FUNCTION [42883]. All 6 failing routines covered. CORRECT & COMPLETE.
- ⚠ PD-007: working tree of BOTH files is TRUNCATED (01 667L vs HEAD 835L; 02 470L vs HEAD 496L; mid-word tails) — Cowork cache write-back after commit. HEAD = truth & correct. Needs CC/native §0.2 re-sync (`git show HEAD:<f> > <f>`) before any working-tree repackage; devops should repackage from committed tree.
> consumed 2026-06-13T10:29:14Z by dba — relayed digest to coordinator; PD-007 flagged.

## 2026-06-13T12:20:15Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_45_table_drift_migration.md | status: done (reconciled by spec from git object-store — CC binding/RESULT dropped, L-SC-04)
### RESULT (object-store verified):
- Commit **4c9c762** "fix/db: 45 table-drift migration — ADD RTSData_Interaction CustomCallData1..20" (1 file, +46).
- db/migrations/20260613_011_45_table_drift_addcolumns.sql: 20x `ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData<N>" text` (1..20, nullable, AT END) + §38a self-record (ON CONFLICT DO NOTHING). BOM-less. Working tree CLEAN (45L==HEAD). Functions 01/02 UNTOUCHED (3db705d intact).
- ⚠ COMPLETENESS GAP: no STEP-1 scan artifact was written -> cannot confirm the systematic scan covered the OTHER tables the 01+02 bodies touch (RTSData_UserStatus, RTSData_UserStatusLog, RTSData_ChatMessage, NGC_*). _011 fixes ONLY the known RTSData_Interaction drift. Residual-drift risk on re-apply.
> consumed 2026-06-13T12:20:15Z by dba — relayed digest + completeness flag to coordinator.

## 2026-06-13T12:59:52Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_extend_011.md | status: done (reconciled by spec from git object-store — CC RESULT dropped, L-SC-04)
### RESULT (object-store verified):
- Commit **d18c79d** "fix/db: extend _011 — add MaxDuraction (42703) + CreatedDatetime (parity)".
- db/migrations/20260613_011 final = 23 ALTER ADD COLUMN IF NOT EXISTS: 20x RTSData_Interaction CustomCallData1..20 text + RTSData_UserStatus."MaxDuraction" integer + NGC_Queues/NGC_AgentGroups."CreatedDatetime" timestamptz DEFAULT now(). §38a self-record present (db_patch_history grep=1). BOM-less. Functions 01/02 UNTOUCHED.
- GATE (by construction): _011 adds EXACTLY the 23 columns the 45 cross-check flagged missing -> post-_011 the cross-check VALUES query on 45 = ZERO rows = COMPLETE. (devops re-run on 45 post-apply = final confirmation.)
- ⚠ PD-007: working tree truncated (43L vs HEAD 54L) — HEAD correct; next CC §0.2 restores; devops repackage from COMMITTED tree (HEAD).
> consumed 2026-06-13T12:59:52Z by dba — relayed digest to coordinator.

## 2026-06-13T15:11:01Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_45_hotfix_bundle.md | status: done (reconciled by spec from git object-store — CC RESULT dropped, L-SC-04)
### RESULT (object-store verified):
- Commit **4685c44** "fix/db: 45 hotfix bundle — 42883 PROCEDURE fix + 23505 IDENTITY resync" (3 files: 01 -56, _012 +80, staging +135).
- PART A staging/45_hotfix_20260613.sql: A1 = 3x [kind-agnostic pg_proc DROP loop -> CREATE PROCEDURE canonical N-param] -> PROCEDURE-only, 42883 clears; A2 = 12 setval IDENTITY resyncs -> 23505 clears. BOM-less, idempotent.
- PART B1 db/functions/01: 3 dead 3-param mapping FUNCTIONs REMOVED (grep=0); 3 canonical PROCEDUREs kept. B2 db/migrations/20260613_012: 3 DROP FUNCTION + ensure PROCEDURE + §38a self-record (db_patch_history=1), BOM-less.
- VERIFIED: hotfix DROP mechanism present + effective (pg_proc loop drops FUNCTION). Caller-check: Shell=0, RTM=CALL/PROCEDURE -> FUNCTION removal safe (backend co-sign pending).
- ⚠ PD-007: 01 working tree truncated (664L vs HEAD 788L); _012+staging CLEAN. HEAD correct -> devops repackage from COMMITTED tree (HEAD).
> consumed 2026-06-13T15:11:01Z by dba — relayed digest to coordinator.
). fix/db: prefix.
## 2026-06-13T15:05:20Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_45_hotfix_bundle.md | status: done
### RESULT:
- commit: 4685c44f03cfc233f0fccf7e9e7eb30f6aeec93a
- files:
  - db/functions/01_ngc_functions.sql (781L -> 737L after FUNCTION removal)
  - db/migrations/20260613_012_drop_legacy_mapping_functions.sql (79L) NEW
  - staging/45_hotfix_20260613.sql (134L) NEW
- build/test: skipped (verify on dev DB separately)
- blockers: **backend co-sign required** for caller-finding before B1 removal deployed
- object-store verify: yes (commit exists in git log)

### PART A (staging/45_hotfix_20260613.sql) — operator applies on 45 NOW:
- A1: kind-agnostic DROP + CREATE PROCEDURE for:
  - NGC_CreateBusinessUnitQueueClassificationMapping (5-param)
  - NGC_CreateBusinessUnitSupergroupMapping (4-param)
  - NGC_CreateSupergroupAgentgroupMapping (4-param)
- A2: setval IDENTITY resync for RTSGrid_*/RTSUserGrid_*/NGC_* tables

### PART B (durable):
- B1: Removed 3 dead FUNCTION blocks from 01 (PROCEDURE-only now); updated comments
- B2: Migration _012 with §38a self-record

### PART B3 — IDENTITY resync block for devops (wire into Create-FreshDb/Restore-All SEED phase):
`sql
-- Resync IDENTITY sequences after seed data INSERT
SELECT setval(pg_get_serial_sequence('"RTSGrid_Grid"','GridId'), GREATEST((SELECT COALESCE(MAX("GridId"),0) FROM "RTSGrid_Grid"),1));
SELECT setval(pg_get_serial_sequence('"RTSGrid_Row"','RowId'), GREATEST((SELECT COALESCE(MAX("RowId"),0) FROM "RTSGrid_Row"),1));
SELECT setval(pg_get_serial_sequence('"RTSGrid_Column"','ColumnId'), GREATEST((SELECT COALESCE(MAX("ColumnId"),0) FROM "RTSGrid_Column"),1));
SELECT setval(pg_get_serial_sequence('"RTSGrid_Cell"','CellId'), GREATEST((SELECT COALESCE(MAX("CellId"),0) FROM "RTSGrid_Cell"),1));
SELECT setval(pg_get_serial_sequence('"RTSGrid_Statistic"','StatisticId'), GREATEST((SELECT COALESCE(MAX("StatisticId"),0) FROM "RTSGrid_Statistic"),1));
SELECT setval(pg_get_serial_sequence('"RTSUserGrid_Grid"','GridId'), GREATEST((SELECT COALESCE(MAX("GridId"),0) FROM "RTSUserGrid_Grid"),1));
SELECT setval(pg_get_serial_sequence('"RTSUserGrid_Column"','ColumnId'), GREATEST((SELECT COALESCE(MAX("ColumnId"),0) FROM "RTSUserGrid_Column"),1));
SELECT setval(pg_get_serial_sequence('"RTSUserGrid_ColumnsSet"','ColumnsSetId'), GREATEST((SELECT COALESCE(MAX("ColumnsSetId"),0) FROM "RTSUserGrid_ColumnsSet"),1));
`

### PART C — [D]/[A] findings: DEFERRED (operator runs reads on 45; report in follow-up)

### CALLER FINDING (backend MUST sign):
- Shell (src/): grep = ZERO callers of NGC_Create*Mapping 3-param FUNCTION
- RTM (BusinessUnitData.cs:459/510/559): calls via ExecuteNonQuery = CALL => PROCEDURE
- Conclusion: 3-param FUNCTIONs are DEAD CODE, removal is SAFE
##
## 2026-06-13T17:56:45Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_45_sgag_constraint.md | status: done (reconciled by spec from git object-store — L-SC-04)
### RESULT (object-store verified):
- Commit **aac018c** "fix/db: 45 sgag unique constraint (42P10) — table drift fix + durable migration" (2 files: _013 +58, staging +59). schema.sql NOT touched (direction correction honored).
- _013 + staging: dedup-guard (keep MIN(Id)) -> guarded `ADD CONSTRAINT uq_supergroup_agentgroup UNIQUE ("SupergroupId","AgentgroupId")` (pg_constraint check, canonical name = Compare-clean) -> _013 also §38a self-record (db_patch_history). BOM-less both.
- Integrity: DRIFT db/migrations/20260613_013_sgag_unique_constraint.sql ; DRIFT staging/45_hotfix_sgag_20260613.sql.
- GATE (by construction): adds the EXACT canon constraint 45 lacked -> after apply, body's ON CONFLICT (SG,AG) resolves -> 42P10 clears.
- Cosmetic nit (non-blocking): staging RAISE NOTICE 'removed % rows' uses COUNT(... WHERE FALSE) = always 0; the DELETE itself is correct; dedup likely finds zero anyway.
> consumed 2026-06-13T17:56:45Z by dba — relayed digest to coordinator.

## 2026-06-13T19:36:48Z | binding: dba <-> CC | directive: reconcile (_014) + Dim B (_015) | status: done (reconciled by spec from object-store — L-SC-04 both dropped)
### RESULT (object-store verified):
- **b7d6461** reconcile: staging/45_schema_reconcile +257, _014 +238. staging = 3 ADD CONSTRAINT UNIQUE + 37 CREATE [UNIQUE] INDEX IF NOT EXISTS + pg_constraint guards + 0 destructive DROP (ADDITIVE-only). _014 §38a (db_patch_history). BOM-less both. schema.sql/01 NOT touched.
- **9020836** Dim B: staging/45_hotfix_dimb +110, _015 +80. staging = DROP-all loop + 2 CREATE FUNCTION + 1 CREATE PROCEDURE NGC_CreateSupergroup + pg_proc before/after verify (expect 2 'f' + 1 'p'). _015 §38a. BOM-less. schema.sql/01 NOT touched.
- Integrity: all 4 files WT 1 line < HEAD ending with proper final statement = BENIGN EOF-newline (NOT truncation); staging SAFE to apply as-is. HEAD canonical.
- GATE (by construction): reconcile adds all canon UNIQUE constraints+indexes 45 lacked (42P10 class) + Dim B ensures all 3 supergroup overloads (42883 CALL + GetScalar) -> 45 structurally == canon.
> consumed 2026-06-13T19:36:48Z by dba — relayed digest to coordinator.

## 2026-06-13T20:26:50Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_guard_014.md | status: done (reconciled by spec from object-store — L-SC-04)
### RESULT (object-store verified, HEAD 609ba7a):
- Commit **609ba7a** "fix/db: guard _014+staging with to_regclass() — apply-safe on any server (8 phantom tables skip)".
- _014: 38 CREATE INDEX, **48 to_regclass guards** (all indexes + constraint blocks wrapped), §38a intact (db_patch_history=2), 0 destructive DROP (additive), BOM-less. staging: 38 idx / 45 to_regclass. HEAD complete (final line `ON CONFLICT (migration_name) DO NOTHING;`).
- ⚠ PD-007 (REAL truncation, not EOF): WT _014=249L vs HEAD 323L (tail mid-statement `EXECUTE 'CREATE UNIQUE INDEX IF N`); staging WT=156L vs HEAD 190L (tail `ALTER TABLE`). HEAD = TRUTH & complete. Push ships HEAD objects (unaffected). Push executor MUST NOT `git add` these from WT; next CC §0.2 restores WT.
> consumed 2026-06-13T20:26:50Z by dba — relayed + READY ack written.
included for completeness) |
| (TenantId, UserId, AgentgroupId) | IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId | EXISTS |
| (InteractionId, Segment, ServerId) | IX_RTSData_Interaction_UpsertKey | EXISTS |
| (UserId, StatusId, ServerId, OnDate) | PK_RTSData_UserStatus | PK (EF-managed) |
| (MessageId, ServerId) | IX_RTSData_ChatMessage_MessageId_ServerId | EXISTS |

STRUCTURAL INVENTORY:
- 3 UNIQUE constraints (dedup-guarded + pg_constraint guarded)
- 3 critical UNIQUE indexes (ON CONFLICT targets)
- 21 regular indexes (public schema)
- 12 other UNIQUE indexes (public schema)
- 23 columns (_011 set: CustomCallData1..20, MaxDuraction, CreatedDatetime x2)

EF-ROOT-CAUSE (route to Shell/backend, E4): EF model must declare all constraints/indexes so Web.exe migrate reproduces schema.sql structure. Until then, this reconcile + Compare-ToBaseline is the safety net.
## 2026-06-13T19:31:48Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_45_schema_reconcile.md | status: done

## 2026-06-13T19:32:18Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_45_dimb_createsupergroup.md | status: open
### DIRECTIVE (spec->CC): Dim B — ensure ALL NGC_CreateSupergroup overloads on 45 (42883). 3 overloads: 2 FUNCTION + 1 PROCEDURE. Claims: staging/45_hotfix_dimb_createsupergroup_20260613.sql + db/migrations/20260613_015_ngc_createsupergroup_overloads.sql. commit.lock.

### RESULT (CC->spec):
- commit: 9020836 fix/db: 45 Dim B — NGC_CreateSupergroup all 3 overloads (2 FUNCTION + 1 PROCEDURE)
- files:
  - staging/45_hotfix_dimb_createsupergroup_20260613.sql (110L) NEW — operator applies on 45 via psql
  - db/migrations/20260613_015_ngc_createsupergroup_overloads.sql (80L) NEW — durable for deployed servers
- build/test: dev verify - all 3 overloads exist (2 'f' + 1 'p'); ownership errors on dev (functions owned by postgres) don't affect 45
- blockers: none
- object-store verify: yes (git log HEAD shows 9020836)

pg_proc AFTER (verified on dev):
| proname | prokind | args |
|---|---|---|
| NGC_CreateSupergroup | f | text,text,uuid (arity-3) |
| NGC_CreateSupergroup | f | text,text,text,uuid (arity-4) |
| NGC_CreateSupergroup | p | integer,text,text,text,uuid (arity-5) |

Caller backing:
- GetScalar:360 -> FUNCTION(text,text,uuid) ✓
- GetScalar:288 -> FUNCTION(text,text,text,uuid) ✓
- ExecuteNonQuery:384 -> PROCEDURE(integer,...) ✓
## 2026-06-13T19:33:51Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_45_dimb_createsupergroup.md | status: done

## 2026-06-13T20:19:51Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_guard_014.md | status: open
### DIRECTIVE (spec->CC): Guard _014 + staging reconcile against phantom tables. Wrap ALL CREATE INDEX with to_regclass() guards. Claims: db/migrations/20260613_014_schema_reconcile.sql + staging/45_schema_reconcile_20260613.sql. commit.lock. BARRIER EXCEPTION (coordinator 20:00 authorized).

### RESULT (CC->spec):
- commit: 609ba7a fix/db: guard _014+staging with to_regclass() — apply-safe on any server (8 phantom tables skip)
- files:
  - db/migrations/20260613_014_schema_reconcile.sql (323L) — ALL 37 CREATE INDEX wrapped with to_regclass() guards
  - staging/45_schema_reconcile_20260613.sql (190L) — same guards applied
- build/test: dev apply - ownership errors (dev DB permissions) but guards WORK (phantom tables would skip cleanly); §38a self-record intact (grep=1)
- blockers: none
- object-store verify: yes (git log HEAD shows 609ba7a)

GUARDED COUNTS:
- 3 UNIQUE constraints: extended with to_regclass() table-exists check at block start
- 3 critical UNIQUE indexes: wrapped in DO  IF to_regclass(...) EXECUTE 'CREATE...' 
- 21 regular indexes: all wrapped
- 12 other UNIQUE indexes: all wrapped
- 4 column-add blocks: wrapped for RTSData_Interaction, RTSData_UserStatus, NGC_Queues, NGC_AgentGroups

8 PHANTOM TABLES (skip cleanly on real EF servers):
AuditEvents, Users, PermissionGroups, Screens, ScreenPermissions, ResourcePermissions, UserGroups, WidgetSlots
## 2026-06-13T20:23:54Z | binding: dba <-> CC | directive: tools/cc_prompt_dba_guard_014.md | status: done

## 2026-06-14T05:09:54Z | binding: dba <-> CC | directive: tools/cc_prompt_mf2_log_statement_ff.md | status: open
### DIRECTIVE: MF-2 suppress statement logging during catowner provisioning (FF). Claim: db/setup/02_catowner_role.sql. Prefix: db:.

### RESULT (by CC): commit b618a14 ; 2-line SET block (log_statement='none' + log_min_duration_statement=-1) inserted above set_config ; diff shows only the insert ; NO push ; verified: object-store (git show HEAD:db/setup/02_catowner_role.sql | head -15).
## 2026-06-14T05:11:34Z | binding: dba <-> CC | directive: tools/cc_prompt_mf2_log_statement_ff.md | status: done

## 2026-06-14T07:31:39Z | binding: dba <-> CC | directive: tools/cc_prompt_b5_regen_schema.md | status: open
### DIRECTIVE: regen db/schema.sql from EF+RTM sources via new db/tools/Regen-Schema.ps1; drop 9 phantoms; provenance header; verify [A]~0. Claims: db/schema.sql + db/tools/Regen-Schema.ps1. db:. NO push.

### RESULT (by CC): commit 01d4db6; schema.sql regen lines 3518 (was 4159); phantoms=0 (verified 9 absent); identity=11/audit=2/rtm=24; RTSData_UserStatus=MaxDuraction only; Compare [A]=0 missing lines (was ~454); Regen-Schema.ps1 added (205 lines). NO push. verified: object-store + Compare proof.
## 2026-06-14T07:38:09Z | binding: dba <-> CC | directive: tools/cc_prompt_b5_regen_schema.md | status: done

## 2026-06-14T11:35:34Z | binding: dba <-> CC | directive: tools/cc_prompt_e2_compare_semantic.md | status: open
### DIRECTIVE: Compare Dim A semantic object-enumeration + Dim B multi-overload (name->set-of-kinds). Claim: db/tools/Compare-ToBaseline.ps1. db:. NO push.

### RESULT (by CC): commit af8d89a; Dim A enumerated (tables/indexes/constraints/routines/sequences + detail count); Dim B set-of-kinds, NGC_CreateSupergroup NO LONGER flagged (expected {f,p} server has {f,p} -> empty set-diff); verify: regen Dim A still 0/2 + B clean; dev-rtmviewdb 392 enumerated = 9 phantom tables (AuditEvents,PermissionGroups,RTSGrid_TemplateCell,etc.) + 9 old indexes + stale PKs/constraints + RTSData_SetChatMessage still needs PROCEDURE. NO push. verified: object-store + Compare reruns.
## 2026-06-14T11:39:20Z | binding: dba <-> CC | directive: tools/cc_prompt_e2_compare_semantic.md | status: done

## 2026-06-14T12:10:05Z | binding: dba <-> CC | directive: tools/cc_prompt_e4_ef_model_dimension.md | status: open
### DIRECTIVE: E4 — has-pending-model-changes pre-check in Regen-Schema.ps1 (mandatory abort) + optional Dimension E in Compare (-CheckEfModel). Claims: Regen-Schema.ps1 + Compare-ToBaseline.ps1. db:. NO push.

### RESULT (by CC): commit 33a842e; has-pending exit-semantics = exit 0 = NO pending (model captured); Regen E4 pre-check added (aborts on pending); Compare Dimension E behind -CheckEfModel; at HEAD all 3 contexts NO pending (invariant holds); default Compare unchanged (no Dim E printed). NO push. verified: object-store + reruns.
## 2026-06-14T12:15:26Z | binding: dba <-> CC | directive: tools/cc_prompt_e4_ef_model_dimension.md | status: done

## 2026-06-14T13:09:42Z | binding: dba <-> CC | directive: tools/cc_prompt_e3_sequence_sync.md | status: open
### DIRECTIVE: E3 — Compare Dimension F sequence-sync (detect lagging owned sequences + emit setval to align.sql) + Restore-All setval resync step. Claims: Compare-ToBaseline.ps1 + Restore-All.ps1. db:. NO push.

### RESULT (by CC): commit af9caeb; Compare Dimension F added (owned-seq last_value vs MAX, setval emitted to align); Restore-All setval resync DO-block added (step 5/5, last step before grants); regen run = 0 lagging (no 23505 risk, expected on empty); dev-rtmviewdb = 0 lagging (sequences ahead); parse clean. NO push. verified: object-store + reruns.
## 2026-06-14T13:13:57Z | binding: dba <-> CC | directive: tools/cc_prompt_e3_sequence_sync.md | status: done

## 2026-06-14T13:45:07Z | binding: dba+devops <-> CC | directive: tools/cc_prompt_e1_predeploy_gate.md | status: open
### DIRECTIVE: E1 — Compare drift-based exit code (db) + Update-RTMView pre-migration Compare gate w/ -ForceDeploy (deploy). Claims: Compare-ToBaseline.ps1 + deploy/Update-RTMView.ps1. db:+deploy:. NO push.

### RESULT (by CC): commits 6d3754c+7ae098a; Compare exit 0=clean/2=real-drift (cosmetic+C+D warn-only); regen EXIT=0 (GATE: CLEAN), dev-rtmviewdb EXIT=2 (GATE: REAL DRIFT, A=56 phantoms); Update-RTMView gate after backup before deploy + -ForceDeploy/-SkipDriftGate override; parse clean. NO push. verified: object-store + exit-code reruns.
## 2026-06-14T13:52:39Z | binding: dba+devops <-> CC | directive: tools/cc_prompt_e1_predeploy_gate.md | status: done

## 2026-06-15T05:53:44Z | binding: dba <-> CC | directive: tools/cc_prompt_tfn_functions_consistency.md | status: open
### DIRECTIVE: T-FN — diagnose functions vs clean build; remove confirmed-dead FUNCTION overloads from db/functions/01; Regen determinism. Claims: 01_ngc_functions.sql + Regen-Schema.ps1 (+schema.sql if re-regen changes). db:. NO push.

### RESULT (by CC): commit bc66f0f; STEP1 diagnosis: dead NGC_Create*Mapping FUNCTION overloads NOT in db/functions/01 (already clean); REAL issue = apply-order bug (functions before migrations -> columns missing -> functions fail); FIXED: migrations BEFORE functions + superuser for both; schema.sql regenerated (clean build end-state, 110 lines smaller = dead overloads correctly not present). RTSData_GetUsersStatuses resolved (now created successfully). NO push. verified: object-store + regen reruns.
## 2026-06-15T06:04:09Z | binding: dba <-> CC | directive: tools/cc_prompt_tfn_functions_consistency.md | status: done

## 2026-06-15T12:44:45Z | binding: dba <-> CC | directive: tools/cc_prompt_specialist_protocol.md | status: open
### DIRECTIVE: Codify Specialist Protocol (NORM-CUR-11) — add vertical-axis section to CLAUDE.md, CAPTURE step to §0.6b, INIT ritual to session-coord + per-role protocols. docs:. NO push.

### RESULT (by CC): commit fddfbe7; CLAUDE.md §45 added (Specialist Protocol vertical axis); §0.6b CAPTURE step added; session-coord §1 VERTICAL INIT + L-SC-30; per-role protocols updated (dba/techwriter/backend/coordinator); role-skill-standard + TEMPLATE added. NO push. verified: object-store + files re-synced.
## 2026-06-15T12:48:34Z | binding: dba <-> CC | directive: tools/cc_prompt_specialist_protocol.md | status: done

## 2026-06-16T06:50:28Z | binding: dba <-> CC | directive: tools/cc_prompt_rolewide_coldstart.md (role: backend) | status: open
### DIRECTIVE: Cold-start role-backend from ARTIFACTS — git log RTM/ + journal + memory. Create .claude/skills/role-backend/role-backend.md. NO push.

### RESULT (by CC): commit 5636cc6; created .claude/skills/role-backend/role-backend.md — 7 cardinal truths (RTM-SEC-002 PROCEDURE, TenantId-last, single-tenant, SignalR relay, init+refreshCells, JsonElement, LoadData STARTUP-only), 5 lessons (42809, StatusGroup, align.sql, sig-agnostic DROP, TryGetValue guards), all source-pinned from git log/journal/memory. NO push. verified: object-store + re-synced.
## 2026-06-16T06:53:55Z | binding: dba <-> CC | directive: tools/cc_prompt_rolewide_coldstart.md (role: backend) | status: done

## 2026-06-16T07:20:36Z | binding: dba <-> CC | directive: tools/cc_prompt_rolewide_coldstart.md (role: shell) | status: open
### DIRECTIVE: Cold-start role-shell from ARTIFACTS — git log src/CcDashboard.Web/ + journal + memory. Create .claude/skills/role-shell/role-shell.md. Each §C VERIFY must pass BEFORE inclusion. NO push.
> consumed 2026-06-18T14:25Z by coordinator-0612 — 234 STEP-1 -MigrationList §4-PASS: 10 ordered migs (604_001,605_004,606_005,606_008,613_001,613_011-015); _004 only-deleting VERIFIED safe (re-point-before-delete, idempotent, generic RTSGrid_Cell.Value); Dim A cosmetic, C=6 (4 dedup-removed by _004 + 2 local typos harmless), F clean. Reasoning sound. DECISION pending operator: FULL-10 (dba rec, ledger-clean) vs LEAN (_001/004/005/012 + fns + backfill). backend NGC verdict still pending (STEP-4 gate). -> STEP 2 routing on operator FULL/LEAN.
## BINDING 2026-06-21T06:10:00Z | spec: dba | directive: tools/cc_prompt_r0b_carve.md | status: open
### DIRECTIVE (spec->CC): R0b schema.sql carve (refined-C, 38 carve/26 keep) + Export-All whitelist + REBUILD_RUNBOOK.md + NGC_GetCellsByDataGrid TemplateCell JOIN fix (42P01 on rebuild)
Claims: db/**
Acceptance: schema.sql 26 CREATE TABLE remain, zero carved; Export-All whitelist; REBUILD_RUNBOOK.md created; NGC_GetCellsByDataGrid no 42P01


### RESULT (CC->spec): 
- commit: 84f087c
- files: db/schema.sql (1900 lines, 26 CREATE TABLE), db/REBUILD_RUNBOOK.md (86 lines), db/functions/04_misc_functions.sql (137 lines), db/tools/Export-All.ps1 (184 lines)
- build/test: N/A (schema-only change, no build)
- status: done
- blockers: none
- verified: object-store (git show HEAD:db/schema.sql | grep -c "CREATE TABLE" = 26)
- acceptance:
  - schema.sql: 26 CREATE TABLE remain (24 RTM + 2 DB-module) - PASS
  - schema.sql: zero carved tables - PASS (38 removed)
  - schema.sql: zero REFERENCES to carved - PASS
  - schema.sql: CREATE SCHEMA audit/identity removed - PASS (only public remains)
  - Export-All.ps1: whitelist approach - PASS
  - REBUILD_RUNBOOK.md: created - PASS
  - NGC_GetCellsByDataGrid: TemplateCell JOIN removed - PASS
  - FRESH REBUILD: NOT TESTED (CC env limitation - operator/coordinator must verify)
---

> consumed 2026-06-21T07:11:19Z by dba-0620 — R0b RESULT independently OBJECT-STORE verified (HEAD:db/schema.sql, db/functions, db/tools):
>  - 26 CREATE TABLE = exactly keep-set (9 NGC + 4 RTSData + 8 RTSGrid + 3 RTSUserGrid + db_patch_history + metric_deploy_log); 0 of 38 carved remain. PASS
>  - CREATE SCHEMA = only public (audit/identity removed). Extensions never in schema.sql (live in db/setup/01_init_db.sql) -> "keep extensions" was a no-op, NOT a defect. PASS
>  - FK: 5 remain, all RTM-internal (NGC_BusinessUnit x2, NGC_Site, NGC_Supergroup x2); 0 dangling REFERENCES to carved. PASS
>  - (D) NGC_GetCellsByDataGrid: TemplateCell JOIN removed, returns ''::text for Tooltip/OnClick (col index preserved). PASS
>  - (B) Export-All.ps1: explicit -t whitelist of all 24 RTM tables (fail-safe durability). PASS
>  - (C) REBUILD_RUNBOOK.md: order migrate(App+Audit) -> schema.sql -> functions -> seed; extensions created in step 1. PASS
>  STATIC verify = GREEN. FUNCTIONAL fresh-rebuild proof (Compare B:0) NOT run here (Web.exe migrate = Windows .NET) -> operator on Windows. ⚠ AND now BLOCKED by CC-HIST-001 db_patch_history defect (see cc/bi.md / coordinator) — rebuild proof must wait for that fix. R0b status: static-verified, NOT Delivered until functional proof.

> 2026-06-21T08:09:44Z by dba-0620 — R0b FUNCTIONAL rebuild-proof (dev throwaway DB) = FAILED. Static verify was GREEN but functional rebuild surfaces carve INCOMPLETENESS. R0b NOT Delivered. Root causes (object-store pinned):
>  1. [carve gap, MINE] db/data still seeds CARVED app tables: 01_system.sql COPYs tenants/tenant_settings/identity.*/__*MigrationsHistory; 04_catalog.sql COPYs widget_catalog (+ NGC_Site keep). Post-carve these tables are EF/DatabaseInitializer-seeded, not psql -> "relation does not exist". db/data must be carved to RTM-only.
>  2. [R0b defect, MINE] schema.sql:35 `CREATE SCHEMA public;` (no IF NOT EXISTS) -> "schema public already exists".
>  3. [RTM drift, co-own backend] schema.sql RTSData_Interaction has CustomCallData1..18; fn 02_rtsdata_functions.sql:335 needs CustomCallData19(/20) -> column does not exist. schema.sql stale vs canonical 20.
>  4. [tooling, pre-existing] Restore-All writes temp .sql with BOM -> 'syntax error at "ï»¿DO"' (ownership/E3/grants); psql client WIN1252 -> UTF-8 seed chars fail (need PGCLIENTENCODING=UTF8); Restore-All has no Web.exe migrate step (app tables absent).
> NEXT: author R0c follow-up CC (db: + co-own) — carve db/data to RTM-only; CREATE SCHEMA IF NOT EXISTS public; add CustomCallData19/20 to schema.sql (backend canon-confirm); fix Restore-All BOM + add migrate or document migrate-first; PGCLIENTENCODING. Then re-run proof.

> consumed 2026-06-21T09:55:00Z by dba-0620 — R0c (b8631bd) independently OBJECT-STORE verified, ALL 4 parts GREEN:
>  (a) db/data RTM-only: 01_system.sql REMOVED; db/data={02_metrics,03_rtsgrid,04_catalog,05_translations}; ZERO app-table COPY; 04_catalog = NGC_Site only. PASS
>  (b) schema.sql:35 = CREATE SCHEMA IF NOT EXISTS public. PASS
>  (c) RTSData_Interaction table def = CustomCallData1..20 (19+20 added, text). PASS
>  (d) Restore-All: no Set-Content -Encoding UTF8 (3x WriteAllText no-BOM), PGCLIENTENCODING=UTF8 @22; Rebuild-Proof.ps1 created (RUNBOOK order: createdb->init->migrate->schema->functions->data->Compare->drop, ShellExe mandatory, migrate-fail throws). PASS
> STATIC verify = GREEN. FUNCTIONAL combined proof (Rebuild-Proof.ps1 -> Compare B:0) = Windows/.NET, operator runs. R0c NOT Delivered until B:0.

> 2026-06-21T10:10:00Z by dba-0620 — R0c FUNCTIONAL proof BLOCKED by tool-encoding defect (not a content/logic error): db/tools/Rebuild-Proof.ps1 committed WITHOUT UTF-8 BOM (head=23 52 65 '#Re'); 13 non-ASCII lines (box-draw/em-dash); PS 5.1 reads no-BOM as WIN1252 -> parser desync -> bogus 'reserved <' @85 +cascade. Sibling tools all have BOM (efbb bf). FIX: re-encode to UTF-8 BOM (tools/cc_prompt_r0c_fix_bom.md authored). R0c static parts (a-d) still GREEN; only the new tool's encoding is wrong. NOT Delivered until proof B:0.

> 2026-06-21T10:30:00Z by dba-0620 — Rebuild-Proof.ps1 2nd PS5.1 bug: 3-arg Join-Path (49/50, PS7-only) -> runtime 'positional parameter'. Expanded tools/cc_prompt_r0c_fix_bom.md to BOM + 2-arg Join-Path. R0c (a-d) static GREEN; proof tool only. NOT Delivered until B:0.

> consumed 2026-06-21T15:55:00Z by dba-0620 — R0d (d50f1f1) OBJECT-STORE verified, ALL 4 parts GREEN:
>  (i) fn_daytrendinteractions MOVED to db/functions/02 (token-hash 6aa33778 == canonical schema HEAD source -> body intact, no NUL); fn_daytrendagentstatus kept (2 daytrend in 02). PASS
>  (ii) schema.sql: 0 CREATE FUNCTION/PROCEDURE (41 stripped), 26 CREATE TABLE intact, 0 NUL bytes. PASS
>  (iii) Export-All: R0d comment (functions single-source §39.1, -t tables-only, no fn dump path). PASS
>  (iv) Compare-ToBaseline [A] baseline = schema.sql + db/functions/01..04 concatenated (carve-aware, L197-209). PASS
> STATIC verify = GREEN. FUNCTIONAL re-proof (Rebuild-Proof.ps1 -> A:0/B:0/C:0/F:0) pending — needs Rebuild-Proof.ps1 PS5.1 fix (tools/cc_prompt_r0c_fix_bom.md: BOM+Join-Path+grant) committed first. R0d NOT Delivered until A:0.

> consumed 2026-06-21T18:45:00Z by dba-0620 — R0e (39270ad) OBJECT-STORE verify: Compare-ToBaseline redesign CORRECT (R0d concat removed, baseline=schema.sql tables-only, @rtmTables -t dump L209, routine presence pg_get_function_identity_arguments L328); Rebuild-Proof BOM=efbb bf ✓ + full grant ✓. BUT (4)(b) MISSED: 3-arg Join-Path still at L49/50 -> committed tool parses but RUNTIME-fails on PS5.1 ('positional parameter'). R0e INCOMPLETE; authored tools/cc_prompt_r0e_fix_joinpath.md (2-line nest). NOT Delivered until A:0.

> consumed 2026-06-21T19:10:00Z by dba-0620 — R0e-fix (8bbee78) OBJECT-STORE verified: Rebuild-Proof.ps1 L49/50 now nested 2-arg `Join-Path (Join-Path $DbDir ...) ...`; BOM efbb bf; 0 NUL. Committed tool now FULLY correct (BOM+Join-Path+grant) + Compare carve-aware (R0e). Tool ready, no local patch needed. FUNCTIONAL A:0 proof = operator one-command Windows run pending.

> 2026-06-21T21:55:00Z by dba-0620 — R0e+R0e-fix RAN end-to-end (tool now executes: BOM+JoinPath+grant ✓, no perm-denied). But Compare STILL non-zero = TWO R0e implementation bugs (delta 213648, NOT real drift): [A] ALL 24 RTM tables 'missing on server' + extra=0 -> the -t @rtmTables pg_dump returned EMPTY (PS splat/quoting), so schema.sql all shows missing (impossible as real drift — rebuild created them). [A-R] 46 missing/46 extra with DIFFERENT fn names per side -> source-parse sig-format vs pg_get_function_identity_arguments mismatch (no entry matches). Substantive PROVEN: rebuild 0 errors, B=0 C=0 F=0. Recommending re-frame gate (rebuild-zero-error), STOP Compare iteration. NOT Delivered pending coordinator decision.
nc
> 2026-06-21T23:19:34Z by dba-0620 — step-0 CORRECTIVE commit 63045d8 (on 0cc1d0d) OBJECT-STORE verified (CC RESULT binding absent -> reconciled from object store, L-SC-28). All 3 dba-flagged defects RESOLVED:
>  (1) ChatMessage CARVED: ArchRtsDataChatMessage.cs REMOVED (-34); migration 20260622090000 -35 (arch_rtsdata_chatmessage table + partition loop gone, header '3 partitioned tables'); ArchiverService chatmessage refs=0; tests chatmessage refs=0. matches SF-ARC-001/002/003. PASS
>  (2) OnDate: archiver 7x 'DD/MM/YYYY', 0x 'YYYY-MM-DD' (matches source dd/MM/yyyy; correct PartTime/partition/idempotency). PASS
>  (3) backend 2 ops flags in contour sql: F1 ALTER TABLE "RTSData_Interaction" SET (autovacuum_vacuum_scale_factor=0.05); F2 indisvalid post-apply verify comment. PASS
>  REGRESSION-GUARD: contour sql kept CONCURRENTLY+IF NOT EXISTS+operator-approved header+§38a self-record; EF migration 0x db_patch_history INSERT (no 42P01); 3 arch tables (interaction/userstatuslog/userstatus). PASS
>  STATIC/STRUCTURAL object-store verify = GREEN. ⚠ T3 build+>=6 tests pass = Windows/.NET -> operator/CC must report (dotnet build CcDashboard.sln + dotnet test tests/CcDashboard.Tests.Unit). NOT Delivered until T3 green. On T3 PASS -> security post-commit re-review -> v3 push barrier.

> 2026-06-21T23:23:09Z by dba-0620 — step-0 63045d8 T3 RESULT (operator native run): `dotnet build CcDashboard.sln` = Build succeeded, 0 Error(s), 21 Warning(s) (all pre-existing nullable/async/EF1002 in Web+Tests.Security; ZERO in arch/archiver code). `dotnet test tests/CcDashboard.Tests.Unit` = Passed! Failed: 0, Passed: 132, Total: 132 (incl ArchiverServiceTests >=6 new). => step-0 (corrective 63045d8 over 0cc1d0d) = DELIVERED: all 3 defects fixed (object-store) + build green + 132/132 unit tests pass. Archiver uses ExecuteSqlInterpolated (CODE-01, no EF1002 on archiver). READY for security post-commit re-review + v3 push barrier. NO push.
nds int?)
  - src/CcDashboard.Domain/Domain/Archive/ArchRtsDataInteraction.cs (T2.1: 69L)
  - src/CcDashboard.Domain/Domain/Archive/ArchRtsDataUserStatusLog.cs (T2.1: 33L)
  - src/CcDashboard.Domain/Domain/Archive/ArchRtsDataChatMessage.cs (T2.1: 35L)
  - src/CcDashboard.Domain/Domain/Archive/ArchRtsDataUserStatus.cs (T2.1: 34L)
  - src/CcDashboard.Domain/Domain/Archive/ArchWatermark.cs (T2.2: 13L)
  - src/CcDashboard.Infrastructure/Migrations/App/20260622090000_AddArchiveTables.cs (T1+T2.1+T2.2: 208L)
  - src/CcDashboard.Infrastructure/BackgroundServices/ArchiverService.cs (T2.3: 270L raw SQL)
  - src/CcDashboard.Infrastructure/BackgroundServices/HistoricalAggregationService.cs (T1: per-tenant SL)
  - src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs (+ArchiverService DI)
  - db/migrations/20260622_001_arch_contour_indexes.sql (T2.4: operator-approved contour index)
  - tests/CcDashboard.Tests.Unit/HistoricalReports/ArchiverServiceTests.cs (T3: 17 tests)
- design decisions:
  - ArchiverService uses raw SQL (EF entities lack CustomCallData1-20)
  - ChatMessage archive skipped (source has no TenantId column)
  - archive-FIRST -> purge-SECOND invariant per Reports_v1_DataArch.md
- object-store verify: yes (git log -1 = 0cc1d0d)
- branch: v3. NO push (§37)


> 2026-06-23T19:46:02Z by dba-0620 — F-QA-6 commit 351ec3d (v3) OBJECT-STORE verified (CC wrote no fresh binding RESULT -> reconciled from object store, L-SC-28). STRUCTURAL = GREEN:
>  migration 20260623192718_AddRtsInteractionCustomCallData1to20: Up()=raw migrationBuilder.Sql, 20x ALTER TABLE "RTSData_Interaction" ADD COLUMN IF NOT EXISTS "CustomCallData{1..20}" text (idempotent, nullable, matches schema.sql); Down()=20x DROP COLUMN IF EXISTS. PASS
>  RtsDataEntities.cs +20 props CustomCallData1..20 (base CustomCallData kept); BackendEmulationDbContextModelSnapshot.cs +60 (model consistent). PASS
>  HYGIENE: commit = 4 files (entity + new migration .cs/.Designer + snapshot) ONLY; stray untracked 20260606100233_AddCatalogueFieldsToRtsGridMetric NOT swept (0); PROD path untouched (schema.sql/ArchiverService/arch migration absent; the 'schema.sql' stat hit = commit-message text). PASS
>  ⚠ FUNCTIONAL acceptance (QA floor) pending Windows/.NET run: fresh dev DB -> RTSData_Interaction has CustomCallData1..20 -> ArchiverService interaction-copy NO 42703 -> arch_rtsdata_interaction populates + arch_watermark sets; dotnet build 0. operator/test (Soma) runs. NOT Delivered until that GREEN.

> consumed 2026-06-23T19:51:10Z by coordinator-0623 — 351ec3d object-store VERIFIED (independent): migration Up()=raw Sql 20x ALTER ADD COLUMN IF NOT EXISTS "CustomCallDataN" text (read actual body; earlier grep-0 was C# doubled-quote artifact, NOT a discrepancy), Down()=20x DROP IF EXISTS; scope 4 files (RtsDataEntities +20 props, new mig +65/.Designer +1211, snapshot +60); prod path clean; stray 20260606100233 NOT swept. STRUCTURAL PASS. Functional (fresh dev migrate -> archiver no 42703) = QA floor, pending Shell-up retest.



## BINDING 2026-06-25T20:48:04Z | spec: dba | directive: tools/cc_prompt_prodmirror_seed.md | status: open
### DIRECTIVE (spec->CC): create db/tools/Seed-ProdMirror.ps1 per spec below. claim: db/tools/ (db module, file-mode: db/tools/Seed-ProdMirror.ps1). gate: build N/A (PS script); object-store verify + PS5.1 lint. NO push.

### RESULT (CC->spec): commit b7aa686 . files db/tools/Seed-ProdMirror.ps1 (635 lines) . parse PS5.1 OK . status done . blockers none . verified: object-store

> consumed 2026-06-25T21:30:00Z by dba-0625 — fix commit 4123bd3 RECONCILED from object store (no fresh CC RESULT, L-SC-28). VERIFIED GREEN: 2 files (Seed-ProdMirror.ps1 +108/-18, role-dba.md +3); Invoke-Native helper L120 routes pgDump(269)/dropdb(280 SoftFail)/createdb(284)/pgRestore(293 SoftFail); Join-String real calls=0, -join L628/L643; Phase-3 [min,max] InQueueDateTime/Answered/Update col-guarded (408-441)+UserStatus range; role-dba §B 2 lessons. Mount WT!=HEAD = L-SC-04 view-drift (HEAD truth).

> consumed 2026-06-25T23:34:00Z by dba-0625 — 2.4a LOAD commit a785231 RECONCILED from object store (L-SC-28). VERIFIED GREEN: 2 files (Seed-ProdMirror.ps1 +14/-35, role-dba.md +2); $targetTenant=$srcTenant (508, no re-stamp); tenant_settings INSERT +MaxConcurrentConnections+PurchasedLicences (514); ON CONFLICT Id(513)/TenantId(516); pg_agent_supergroups=0, pg_supergroups arrays 190/212; §B 2.4a lesson. Ready for Mode=Load.

> consumed 2026-06-25T23:56:00Z by dba-0625 — TRUNCATE-clear commit 3fe0a75 RECONCILED from object store (L-SC-28). VERIFIED GREEN: 2 files (Seed-ProdMirror.ps1 +18/-3, role-dba.md +2); $truncateSet=12 global-PK CC tables (579-584); ONE `TRUNCATE TABLE`+join (589) @()-guarded, NO CASCADE; DELETE-by-tenant kept for pg_*/permission_groups (594-595); exclusions untouched; §B lesson. Ready for re-run Mode=Load.

> consumed 2026-06-26T00:29:00Z by dba-0625 — Phase-5 fix commit 5954a76 RECONCILED from object store (L-SC-28). VERIFIED GREEN: 2 files; AgentGroupId/AgentGroupName/q.QueueId=0; queue join q.ExternalId=bqc.QueueId + ClassificationId='ALL' tenant-scoped (754-755); agent join ag.ExternalId=sag.AgentgroupId (774); §B lesson. Seed-ProdMirror tool now complete + self-verifying. prod-mirror milestone DONE.

> consumed 2026-06-26T01:22:00Z by dba-0625 — add-UserStatusLog commit a4dcddd RECONCILED from object store (L-SC-28). VERIFIED GREEN: 2 files (Seed-ProdMirror.ps1 +6/-2, role-dba.md +2); RTSData_UserStatusLog present 3x (ChainTables+TenantIdTables+truncateSet); §B lesson. Ready for re-run Mode=Load.
d (§B). gate: parse PS5.1. NO push.

### RESULT (CC->spec): commit a785231 . files Seed-ProdMirror.ps1 (798L) + role-dba.md (74L) . 2.4a target==source + pg_supergroups . parse PS5.1 OK . status done . blockers none . verified: object-store

## BINDING 2026-06-25T23:53:05Z | spec: dba | directive: tools/cc_prompt_prodmirror_load_truncate.md | status: open
### DIRECTIVE (spec->CC): LOAD clear = TRUNCATE global-PK CC tables (operator A); keep DELETE-by-tenant for permission_groups/pg_*. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1. NO push.

### RESULT (CC->spec): commit 3fe0a75 . files Seed-ProdMirror.ps1 (811L) + role-dba.md (76L) . TRUNCATE clear (no CASCADE) + DELETE pg_* . parse PS5.1 OK . status done . blockers none . verified: object-store

## BINDING 2026-06-26T00:25:22Z | spec: dba | directive: tools/cc_prompt_prodmirror_fix_phase5.md | status: open
### DIRECTIVE (spec->CC): Phase-5 chain-proof query real column names. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1. NO push.

### RESULT (CC->spec): commit 5954a76 . files Seed-ProdMirror.ps1 (811L) + role-dba.md (78L) . Phase-5 ExternalId joins . parse PS5.1 OK . status done . blockers none . verified: object-store

## BINDING 2026-06-26T01:21:22Z | spec: dba | directive: tools/cc_prompt_prodmirror_add_userstatuslog.md | status: open
### DIRECTIVE (spec->CC): add RTSData_UserStatusLog to ChainTables+TenantIdTables+truncateSet in Seed-ProdMirror.ps1. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1. NO push.

### RESULT (CC->spec): commit a4dcddd . files Seed-ProdMirror.ps1 (813L) + role-dba.md (80L) . RTSData_UserStatusLog in 3 arrays . parse PS5.1 OK . status done . blockers none . verified: object-store

## BINDING 2026-07-02T10:00:00Z | spec: dba | directive: tools/cc_prompt_prodmirror_reconcile_efmig.md | status: open
### DIRECTIVE (spec->CC): create staging/reconcile_efmig_prodmirror.sql (insert ALL 26 MigrationIds ON CONFLICT DO NOTHING), apply to rtmviewdb, run migrate (no-op), verify. claim: staging/reconcile_efmig_prodmirror.sql. gate: report_screens present + count=26 + app starts. NO push.

### RESULT (CC->spec): commit f7a24af . staging/reconcile_efmig_prodmirror.sql . EFMigrationsHistory=26 . report_* present . migrate no-op . app starts . status done . verified: object-store+live
## BINDING 2026-07-03T11:52Z | spec: dba | directive: tools/cc_prompt_reconcile_efmig_234.md | status: done (RECONCILED from object store by coordinator-0703 — CC RESULT write dropped, L-SC-04/NORM-CUR-07b)
### RESULT (reconciled): commit 6945fc0 . staging/reconcile_efmig_234.sql (40L, 22 ids '8.0.16', verify tail) + role-dba.md §B (+2) . narrow add OK . WT==HEAD . verified: object-store
> consumed 2026-07-03T13:50Z by coordinator-0703

> consumed 2026-07-04T09:23:00Z by dba-0625 — reconcile-plan commit 26d6d9e RECONCILED object store. VERIFIED GREEN: 3 files (staging/234_ledger_mark.sql +10 [2 INSERT + ON CONFLICT + verify], staging/234_reconcile_runbook.md +135 [STEP-0 HARD FAIL-STOP pg_dump + STEP-4 re-Compare against JUST-REGENERATED -BaselineDir], role-dba.md §B +1). Operator cleared for the 234 runbook.

> consumed 2026-07-04T17:03:00Z by dba-0625 — schema-dump fix commit b81ccb5 RECONCILED object store. VERIFIED GREEN: 4 files (RtmSchemaDump.ps1 +121 [24 single-source names, Export-RtmSchema full --schema-only -n public + full-quoted Contains + UTF8-no-BOM + --no-owner --no-acl], Export-All -40, Compare -18, role-dba §B +2). BOTH Export-All + Compare call Export-RtmSchema, 0 residual -t whitelist -> SYMMETRIC. Export-All/Compare WT!=HEAD = L-SC-04 mount drift (HEAD truth). Operator cleared for 234 re-regen + re-Compare.

## BINDING 2026-07-16T17:40Z | spec: dba | directive: tools/cc_prompt_tzguard_textform_patch.md | status: done (RECONCILED from object store — CC RESULT write dropped, L-SC-04/NORM-CUR-07b)
### RESULT (reconciled): commit 0329bf0 . files 02_rtsdata_functions.sql (4 +/-2) + role-dba.md §B (+1) . diff = ONLY the 4-line arity-2 GetInteractions WHERE ::interval->text-form; arity-1/aliases/RETURNS/LANGUAGE untouched; 0 `::interval))::date` remain . §B line 76 present . status done . verified: object-store (git diff 0b07651..0329bf0)
