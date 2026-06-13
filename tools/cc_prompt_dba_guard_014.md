# CC Task — DBA: guard _014 + staging reconcile against phantom tables (apply-safe on any server) — PRE-PUSH, the ONE in-flight task under FREEZE

> Authored by dba-0610. Coordinator 20:00: PUSH BARRIER is UP; THIS is the ONE permitted in-flight task. NORM-CUR-07 binding.
> Finding (confirmed): schema.sql carries a DEAD old app-model (8 PascalCase tables: AuditEvents, Users, PermissionGroups, Screens,
> ScreenPermissions, ResourcePermissions, UserGroups, WidgetSlots) that EF-migrate replaced with snake_case + identity./audit. schemas.
> Those 8 tables DO NOT EXIST on a real EF DB -> the _014/staging CREATE INDEX on them ERRORS on every apply. Fix: guard EVERY structural
> statement with a to_regclass table-exists check so it SKIPS objects whose table is absent (covers the 8 phantoms + any future EF-vs-schema drift).

## Git push
Do NOT run `git push`. Commit only (fix/db:). Push happens via the barrier prompt (§37).

## Mandatory — read: widget-planner, widget-creator, session-coord, rtm-service-expert skills.

## STEP 0 — integrity + sync + binding (BARRIER EXCEPTION)
0a. §0.6a integrity.
0b. ⚠ `.coord/push/request.md` EXISTS (barrier active). Normally S1 = STOP — but coordinator 20:00 AUTHORIZED this as the ONE permitted
    pre-push in-flight task. Proceed. Slug dba-0610. CLAIM: db/migrations/20260613_014_schema_reconcile.sql + staging/45_schema_reconcile_20260613.sql. commit.lock. NO schema.sql / db/functions/01 edit.
0c. NORM-CUR-07 binding: OPEN in .coord/cc/dba.md; RESULT on commit. RTM DB ops = PowerShell + psql.exe on Windows host.

## STEP 1 — guard every structural statement in BOTH files (idempotent, BOM-less, ADDITIVE-only)
For EACH `CREATE [UNIQUE] INDEX IF NOT EXISTS "<ix>" ON public."<T>" (...);` wrap in a table-exists guard:
```sql
DO $$ BEGIN
  IF to_regclass('public."<T>"') IS NOT NULL THEN
    EXECUTE 'CREATE [UNIQUE] INDEX IF NOT EXISTS "<ix>" ON public."<T>" (...)';
  END IF;
END $$;
```
(escape inner single-quotes by doubling). Apply to ALL 37 CREATE INDEX — not just the 8 phantom — so _014 is apply-safe on ANY server regardless of which tables exist (PD-008: schema.sql is not reliable canon for app tables).
For each `ADD CONSTRAINT ... UNIQUE` block: EXTEND the existing pg_constraint guard with a to_regclass(table) IS NOT NULL check (skip if the table is absent), keep the dedup-guard.
Result: a server missing the 8 dead PascalCase tables (every real EF server) SKIPS those indexes cleanly; real tables get their indexes; NO "relation does not exist" error.
KEEP: the 3 UNIQUE constraints, the _011 columns (already applied — guarded ADD COLUMN IF NOT EXISTS stays), §38a self-record in _014 (db_patch_history INSERT, migration_name unchanged 20260613_014_schema_reconcile). ADDITIVE-only, no drops.

## STEP 2 — VERIFY (dev) + COMMIT
- Apply _014 on a dev clone that LACKS the 8 PascalCase tables -> ZERO errors (phantom indexes skipped), real indexes created. Apply TWICE -> clean (idempotent).
- §38a self-record still present (`grep -c db_patch_history` == 1 in _014).
- pre-commit-check both files exit 0.
- §0.6 post-commit; PD-007 re-sync both; RESULT (guarded-count + dev zero-error proof) -> .coord/cc/dba.md. NO push (commit joins the barrier push set).

## Acceptance criteria
- [ ] ALL 37 CREATE INDEX in _014 + staging wrapped in to_regclass(table) guards; ADD CONSTRAINT blocks gain a to_regclass check; idempotent; BOM-less.
- [ ] dev apply on a DB lacking the 8 phantom tables = ZERO errors; real-table indexes created; double-apply clean.
- [ ] §38a self-record intact in _014; NO schema.sql/db/functions/01 edit; ADDITIVE-only.
- [ ] pre-commit-check exit 0; no push.

## NOTES for coordinator (re-§4, small)
- Confirms the durable: schema.sql must be REGENERATED from the real DB (PD-008 P4/E4) — its app-layer (8 PascalCase tables) is dead/superseded by the EF snake_case model. Guarding _014 is the immediate apply-safety fix; the regen + EF-model⊇schema.sql decision (Shell/backend) is the root durable.
- After this commit lands (joins the 21-commit push set -> 22) I write the barrier READY ack.
