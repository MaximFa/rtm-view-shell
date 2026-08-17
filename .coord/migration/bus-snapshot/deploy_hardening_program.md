# Deploy-Hardening Program (PD-008 P1-P6 + E1-E4) — scope
> coordinator-0612 · 2026-06-20T10:12:56Z · operator-directed #1. ROOT decided: EF⊇schema via refined-C (object-authority boundary).
> EXECUTION starts AFTER the #2 push barrier (FREEZE active). This is the scope/sequence.

## DECISION (operator) — refined-C: authority BY OBJECT
- **app/identity/dashboard tables -> EF model = source of truth** (EF migrate creates them).
- **RTM/NGC/RTSData/RTSGrid tables (+ functions) -> schema.sql = source of truth** (canonical DDL).
- **CARVE schema.sql**: remove ALL app tables from it -> schema.sql holds ONLY RTM-side objects.
- **Rebuild applies BOTH without conflict**: Web.exe migrate (EF app) + psql schema.sql (RTM) + psql db/functions -> full DB.
- Net: no object owned by both -> rebuild-drift class GONE; and Compare Dim-A app-table noise (PascalCase phantoms) DISAPPEARS (those are now EF-domain, not in schema.sql).

## TASKS / SEQUENCE
### R0 — schema.sql CARVE (ROOT, highest leverage)  [dba authors · Shell+backend confirm boundary · §4]
- Produce the OBJECT->AUTHORITY MAP: enumerate every table; tag EF-app vs RTM-canonical. Shell confirms app/identity/dashboard set; backend confirms RTM/NGC/RTSData/RTSGrid set.
- dba: regenerate schema.sql with app tables REMOVED (RTM-only). Update Export-All/Regen so the carve is reproducible.
- Acceptance: clean rebuild (Web.exe migrate + psql schema.sql + functions) reproduces the live RTM DB; Compare on a fresh rebuild = no REAL drift.

### E1 — per-authority drift GATE (mandatory, highest-leverage E)  [devops+dba · §4]
- Compare-ToBaseline compares each object vs its authority: RTM objects vs schema.sql (Dims A/B/C/D/F as today), app objects vs EF model (E4 dimension, already built). After carve, Dim-A becomes meaningful (no app noise).
- Wire MANDATORY: pre-deploy (done in Update-RTMView) + rebuild runbook + CI (fail on REAL drift). 

### Rebuild runbook  [devops]
- Canonical one-button rebuild: Web.exe migrate -> psql schema.sql -> psql db/functions -> seed. Clean-rebuild = truth-test (L-DEPLOY-01/03).

### P1-P6 / E2-E4 backlog (sequenced AFTER R0+E1; many shrink once carve+gate land)
- TO ENUMERATE from the PD-008 record: latent unique-index drift bombs (RTSData_Interaction UpsertKey 3-col + ChatMessage MessageId-ServerId 2-col -> declare HasIndex().IsUnique() in EF if app-domain, or schema.sql if RTM-domain), SupergroupAgentgroup uq, _011 columns parity, sequence-sync (E3), ledger backfill (pre-ledger D=4), migration self-record (§38a) coverage. Coordinator authors the full sequenced list as the program doc post-barrier.

## ROLES
dba = schema.sql carve + Compare/E1 + migrations. Shell = EF app-table authority/boundary. backend = RTM-table authority + any RTM-contract declarations. devops = rebuild runbook + E1 wiring + CI. coordinator = §4 + sequence + program doc.

## TIMING
- EXECUTION gated behind #2 push barrier (no new commits during FREEZE). R0 carve is the first executable task post-push.
- BI/CC-HIST-001 deploys soon -> the carve+E1 should land before BI's first deploy so the new hist_* (EF-app) + any RTM touch go through the clean rebuild + gate.
