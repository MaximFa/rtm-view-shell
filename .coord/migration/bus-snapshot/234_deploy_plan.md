# 234 DEPLOY — ✅ COMPLETE (2026-06-19T08:51:45Z): DB 10 migs + RTM + Shell Running; Compare B=0, smoke GREEN. Residuals non-blocking (D=4 pre-ledger noise, A cosmetic). Follow-ups: Security DG-7 + optional ledger-backfill.

# 234 DEPLOY — stepwise plan (inbox-mediated) | coordinator-0612 | updated 2026-06-18T13:04Z
Baseline: origin/v2-backend = b58e2c2 (pushed). Anti-saga: every DB step behind the E1 Compare gate; migrations finalized per 234 fact, NOT blind 0613.
Flow: coordinator dispatches step -> role inbox -> operator pokes session -> result -> coordinator inbox -> coordinator advances + gates.

## STEP 0 — Pre-deploy Compare gate (234)  ✅ DONE
devops bundle (read-only) ran on 234. Triage: NO runtime-critical drift. A=305 cosmetic (E4/PK-casing/T-FN-v2); B=1 NGC_DeleteBUQ...Mapping fn-overload; D _001+_005+8 unknown; C=6 info; F clean.

## STEP 1 — Analysis  [dba ✅ DONE §4-PASS | backend NGC ⏳ pending]
# dba FINALIZED 10-mig -MigrationList (604_001,605_004,606_005,606_008,613_001,613_011-015); FULL-vs-LEAN decision -> operator. backend NGC = STEP-4 gate.
- dba: finalize 234 -MigrationList from the Compare delta (Dim-A detail + Dim-D), PG18-aware, NOT blind 0613. NEEDS the 234 out\baseline_delta_*.txt + align_*.sql (operator -> dba). -> tools/cc_prompt_dba_234_migration_list.md
- backend: confirm NGC_DeleteBUQ...Mapping caller=CALL (B=1 benign if CALL/PROCEDURE per RTM-SEC-002). -> .coord/inbox/backend-0609.md
GATE to STEP 2: dba's finalized -MigrationList + backend's NGC verdict in coordinator inbox.

## STEP 2 — Build 234 deploy package  ✅ DONE + coordinator-verified (Glob+Read live FS); README FULL-10 correct.
## STEP 2b — FIX Update-RTMView DB-apply + §35 BOM/CRLF  ✅ DONE+native-verified (024feef on d62e704; BOM ef bb bf, 309 ln, pkg copy swap-ready). devops-0619.
## STEP 3 — replace 1 file on 234 + (re)stage  [operator]  READY
# FULL-10 -MigrationList: 604_001,605_004,606_005,606_008,613_001,613_011,613_012,613_013,613_014,613_015. backend NGC=CALL confirmed. FULL vs LEAN finalized at STEP-4 apply (rec FULL).
prod-release from b58e2c2: Shell binaries (widget pkg) + DB (functions re-apply + the finalized -MigrationList + backfill _001) + Install/Update scripts. §35 BOM/CRLF. -> Installations\ zip.

## STEP 3 — Stage + BACKUP on 234  [operator]  (pending STEP 2)
Drop package in C:\RTMView-Ops\incoming; pg_dump backup of 234 BEFORE any apply (deploy/Restore-SqlDump path / Update-RTMView backup step).

## STEP 4 — Apply DB under E1 gate  [operator on 234]  (pending STEP 3)
Update-RTMView runs E1 pre-deploy Compare gate (after backup, before migrations). If E1 exit=2 real drift -> STOP+review (we already know A=305 is cosmetic; gate may need -ForceDeploy with the reviewed migration list). Apply functions + finalized -MigrationList (explicit, incl _001).

## STEP 5 — Deploy Shell binaries + restart  [operator on 234]  (pending STEP 4)
Kestrel orphan-exe kill-by-path (C:\RTMView\*) + restart services (deploy_kestrel_orphan_exe lesson).

## STEP 6 — Post-apply verify  [devops/operator]  (pending STEP 5)
E1 Compare re-run -> clean (A real-drift ~0). Smoke: login, screens, widgets render, deploy-metrics tab = existing metrics DEPLOYED (backfill), marquee/group/viewer/template features.

## STEP 7 — Security DG re-capture  [inbox: security-0609]  (pending STEP 6)
DG-1..4: F-3 loopback :8088, ApplyService token+401, RTM:TenantId, icacls NT SERVICE + audit-write smoke (as on 45). Security CARRY.

CURRENT: STEP 1 in flight. Operator action: provide 234 out\ delta to dba; poke dba + backend.
