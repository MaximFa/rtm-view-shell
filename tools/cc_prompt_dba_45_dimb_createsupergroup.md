# CC Task — DBA(+backend): Dim B — ensure ALL NGC_CreateSupergroup overloads on 45 (42883/missing-routine), KEEP both kinds

> Authored by dba-0610. §4-BOUND (coordinator verifies the committed RESULT, §26.8). NORM-CUR-07 binding.
> Compare 212532 Dim B: NGC_CreateSupergroup "expected PROCEDURE, server has FUNCTION"; operator `\df`=0 ROWS (PG15 `\df` hides
> procedures -> NO function present; procedure unknown -> possibly BOTH missing on 45). Same 45-DRIFT class (EF rebuild didn't reproduce
> the routine set). UNLIKE the mapping fix: NGC_CreateSupergroup uses BOTH kinds (GetScalar:360 -> FUNCTION(text,text,uuid);
> GetScalar:288 -> FUNCTION(text,text,text,uuid); ExecuteNonQuery:384 -> PROCEDURE(integer,...)). => KEEP all 3, do NOT drop any kind.
> SEPARATE from the structural reconcile (_014); deliver so the operator applies BOTH staging files in ONE psql pass. Migration # = _015.

## Git push
Do NOT run `git push`. Commit only (fix/db:). Push requested separately (§37).

## Mandatory — read: widget-planner, widget-creator, session-coord, rtm-service-expert (§4 PROCEDURE/CALL, §10) skills.

## STEP 0 — integrity + sync + binding
0a. §0.6a integrity (db/functions/01 may be PD-007-truncated; this task does NOT edit it — db/functions/01 ALREADY has all 3 overloads + the kind-agnostic guard; keep out of claim).
0b. Barrier check. Slug dba-0610. CLAIM: db/migrations/20260613_015_ngc_createsupergroup_overloads.sql + staging/45_hotfix_dimb_createsupergroup_20260613.sql. commit.lock. NO schema.sql / db/functions/01 edit (canon already correct; 45-drift only).
0c. NORM-CUR-07 binding: OPEN in .coord/cc/dba.md; RESULT on commit. RTM DB ops = PowerShell + psql.exe on Windows host.

## AUTHORITATIVE STATE CHECK (embed in the staging SQL, before + after)
```sql
SELECT proname, prokind, pg_get_function_identity_arguments(oid) AS args
FROM pg_proc WHERE proname='NGC_CreateSupergroup' ORDER BY prokind, args;
```
Expected AFTER: 3 rows — prokind='f' (text,text,uuid), prokind='f' (text,text,text,uuid), prokind='p' (integer,text,text,text,uuid).

## STEP 1 — staging/45_hotfix_dimb_createsupergroup_20260613.sql (operator applies on 45 via psql; idempotent, BOM-less)
1. pg_proc verify BEFORE (above) — RAISE NOTICE / SELECT the current overloads/kinds.
2. Kind-agnostic DROP-all guard (clears any partial/stale overload):
   `FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateSupergroup' LOOP IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE '||r.sig::text; ELSE EXECUTE 'DROP FUNCTION '||r.sig::text; END IF; END LOOP;`
3. CREATE all 3 canonical overloads — bodies VERBATIM from db/functions/01 HEAD (schema.sql:153/169/185 are the canonical shapes):
   - `CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(p_supergroup_name text, p_description text, p_tenant_id uuid) RETURNS TABLE("SupergroupId" integer)` — GetScalar:360 (SELECT).
   - `CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(p_supergroup_name text, p_description text, p_created_by text, p_tenant_id uuid) RETURNS TABLE("SupergroupId" integer)` — GetScalar:288 (SELECT).
   - `CREATE OR REPLACE PROCEDURE "NGC_CreateSupergroup"(p_supergroup_id integer, p_supergroup_name text, p_description text, p_created_by text, p_tenant_id uuid)` — ExecuteNonQuery:384 (CALL).
   (FUNCTIONs start with text args, PROCEDURE with integer -> distinct signatures -> all 3 coexist in PG. If any CREATE raises "cannot change routine kind"/same-name conflict -> STOP + report to dba/backend; do NOT leave partial.)
4. pg_proc verify AFTER (above) — assert the 3 expected rows.

## STEP 2 — db/migrations/20260613_015_ngc_createsupergroup_overloads.sql (durable mirror for deployed servers) + §38a
Same DROP-all + CREATE all 3 + `INSERT INTO public.db_patch_history (migration_name) VALUES ('20260613_015_ngc_createsupergroup_overloads') ON CONFLICT (migration_name) DO NOTHING;`. BOM-less.
(NB durable ROOT stays EF-model⊇schema.sql — the EF model must produce these on a clean rebuild; routed Shell/backend. This migration patches already-deployed servers.)

## STEP 3 — VERIFY (dev) + COMMIT
- dev: apply twice -> AFTER verify shows exactly the 3 overloads (2 'f' + 1 'p'); idempotent; GetScalar (SELECT fn(...)) AND CALL both resolve (no 42883/42P10).
- pre-commit-check both files exit 0. §0.6 post-commit; PD-007 re-sync; RESULT (pg_proc before/after + commit) -> .coord/cc/dba.md. NO push.

## Acceptance criteria
- [ ] staging + _015: DROP-all guard + CREATE all 3 canonical overloads (2 FUNCTION + 1 PROCEDURE), bodies from 01, embedded pg_proc before/after verify; idempotent; BOM-less.
- [ ] _015 §38a self-record; NO schema.sql / db/functions/01 edit.
- [ ] dev: AFTER = 3 rows (2 'f' + 1 'p'); both caller kinds resolve; backend signed (all 3 overloads + their callers).
- [ ] pre-commit-check exit 0; no push.

## NOTES for coordinator
- All 3 overloads are caller-backed (GetScalar:288/360 = the 2 FUNCTIONs; ExecuteNonQuery:384 = the PROCEDURE) — ensure-ALL, never drop a kind (contrast the mapping fix where the FUNCTION was dead).
- If the AFTER verify can't reach 3 (PG refuses function+procedure same name) -> escalate: the design needs a rename or a single-kind path; backend decides. (Expected to coexist: distinct first-arg types.)
- Operator applies THIS staging + the reconcile staging in ONE psql pass on 45. Re-test: supergroup config-sync (CALL + GetScalar) + QueueGrid/DayTrend.
