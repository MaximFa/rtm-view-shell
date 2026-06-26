# CC task — R0e: Compare-ToBaseline [A] carve-aware redesign (tables-only + routine presence) + fold Rebuild-Proof.ps1 fix

> Owner: dba (slug dba-0620). §4-APPROVED scope: coordinator-0612 2026-06-21T17:57:18Z (OPT-1). db: commit. NO push (§37).
> §4-PASS by coordinator-0612 (2026-06-21T18:03:18Z) — pins verified object-store: (1) Compare:195 full-schema dump + L197 R0d-concat (revert); (2) Export-All:82/:117 $rtmTables -t (reuse); (4) Rebuild-Proof no-BOM(#Re)+3-arg Join-Path L49/50; grant currently 1 partial line -> ensure FULL USAGE+ALL TABLES+ALL SEQUENCES. TOOL-ONLY (db/tools), no schema/fn/data. EXECUTE authorized: native CC, db: commit, commit.lock, NO push.
> TOOL-ONLY fix (the LAST R0 brick). Substantive carve is PROVEN: R0b+R0c+R0d -> fresh rebuild zero-error;
> Compare tables/indexes/constraints/sequences/metrics/prokind/sequence-sync ALL 0 drift. The residual A=106 is a
> MEASUREMENT artifact of the current [A] line-diff (raw db/functions text vs pg_dump-canonicalized output double-counts
> every routine). This task makes the E1 Compare gate TRUTHFUL. SCOPE = db/tools ONLY; NO schema/function/data change.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/role-dba/role-dba.md (§A core + §C VERIFY)
Read: db/tools/Compare-ToBaseline.ps1 (Dimension A ~190-240; the R0d concat block L197-209)
Read: db/tools/Export-All.ps1 (the $rtmTables -t whitelist — reuse it)

## INIT / discipline
- §0.2 integrity; branch v2-backend; §0.5 object-store verify (git cat-file/show), NOT mount git status.
- §0.3 writes: Python + os.fsync ONLY (Edit BANNED); after write: sync + tail -3 + wc -l; STEP-0.5 NUL-check (tr -cd '\000' | wc -c == 0) on EVERY file you write on this mount.
- §42.6 sync block: slug dba-0620; claims = ["db/tools/Compare-ToBaseline.ps1","db/tools/Rebuild-Proof.ps1"].
  Check .coord/push/request.md absent. commit.lock around commit. §0.6b binding -> .coord/cc/dba.md. NO push.

## THE WORK (one db: commit) — db/tools ONLY

### (1) REVERT the R0d (iv) raw-concat [A] baseline (db/tools/Compare-ToBaseline.ps1)
The R0d block (~L197-209) builds the [A] baseline as schema.sql + raw db/functions/01..04 text, then line-diffs vs the
full server pg_dump. pg_dump CANONICALIZES routine text (CREATE OR REPLACE->CREATE, strips comments/DROP, reflows) so raw
source vs pg_dump double-counts EVERY routine (12 -> 106). REMOVE that concat; [A] baseline returns to db/schema.sql.

### (2) [A] SCHEMA = TABLES-ONLY, both sides (db/tools/Compare-ToBaseline.ps1)
schema.sql is now tables-only (R0d). Make the SERVER side tables-only too so it is apples-to-apples:
- Change the [A] server pg_dump from `--schema=public --schema=identity --schema=audit` (full) to a TABLES-ONLY dump
  restricted to the RTM whitelist — reuse the SAME `-t` list as Export-All.ps1 ($rtmTables: 24 RTM tables + db_patch_history
  + metric_deploy_log). i.e. `pg_dump ... --schema-only --no-owner --no-acl @rtmTables -f $ServerSchemaFile`.
- Baseline = db/schema.sql (tables-only). Line-diff server-tables vs schema.sql -> A reflects REAL table/index/constraint
  drift only. Expected A:0 on a clean rebuild. (Drop the identity/audit schema scope — those are EF's domain, not the DB
  module baseline.)

### (3) ROUTINES validated by NAME+SIGNATURE presence, NOT line-diff (new [A]-routines sub-check)
Replace routine line-diff with a set comparison:
- SERVER routines: `SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) FROM pg_proc p JOIN pg_namespace n
  ON n.oid=p.pronamespace WHERE n.nspname='public' ORDER BY 1,2,3;` -> set of name(argtypes).
- BASELINE routines: parse db/functions/01..04 for every `CREATE [OR REPLACE] (FUNCTION|PROCEDURE) [public.]"?name"?(argspec)`
  -> name + normalized arg-type list. (Handle overloads: same name, different argspec = distinct entries. Handle the DROP
  lines — ignore them; only CREATE defines presence.)
- Report: routines MISSING-on-server (in db/functions, absent on server) + EXTRA-on-server (on server, not in db/functions).
  On a fresh rebuild this MUST be 0 (server built straight from db/functions/*). Keep existing [B] prokind check unchanged.
- If full signature parsing of the source is too brittle, fall back to NAME-level set comparison as the floor (still catches
  missing/extra routines); note the limitation in a comment. Name+identity-args preferred.

### (4) FOLD the Rebuild-Proof.ps1 PS-5.1 fix (db/tools/Rebuild-Proof.ps1) — supersedes tools/cc_prompt_r0c_fix_bom.md
The committed Rebuild-Proof.ps1 is broken (no-BOM + 3-arg Join-Path + missing grant); operator's local patch keeps reverting
via PD-007. Commit the durable fix:
- (a) UTF-8 **WITH BOM** (file has non-ASCII box-draw/em-dash; PS 5.1 reads no-BOM as WIN1252 -> parser desync). Write the
  whole file `b"\xef\xbb\xbf" + content.encode("utf-8")`.
- (b) 2-arg Join-Path (PS 5.1): `Join-Path $DbDir "setup" "01_init_db.sql"` -> `Join-Path (Join-Path $DbDir "setup") "01_init_db.sql"`;
  same for `Join-Path $DbDir "tools" "Compare-ToBaseline.ps1"`.
- (c) GRANT step after step 6 (data), before step 7 (Compare), run as SuperUser:
  `GRANT USAGE ON SCHEMA public TO <AppUser>; GRANT ALL ON ALL TABLES IN SCHEMA public TO <AppUser>; GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO <AppUser>;`
  (RTM tables are owned by postgres after psql schema.sql; without grant the internal Compare's pg_dump as app-user hits
  `permission denied for table NGC_AgentGroups`).
- re-scan for other PS7-isms (`??`, `?:` ternary, `-Parallel`) — none expected; confirm.

## ACCEPTANCE (object-store + functional)
- Compare-ToBaseline.ps1: R0d concat removed; [A] server dump = tables-only RTM `-t` whitelist; routine check = name/signature
  presence vs db/functions/* (+ [B] prokind kept). No raw-text routine line-diff remains.
- Rebuild-Proof.ps1: `head -c3 | xxd` = `efbb bf`; no 3-arg Join-Path; grant step present before Compare; 0 NUL bytes.
- RE-RUN db/tools/Rebuild-Proof.ps1 on a scratch DB (ONE command, no local patch, no manual Compare) ->
  **Compare A:0 / B:0 / C:0 / F:0**, zero rebuild errors, no permission-denied at Compare.
  (Windows/.NET -> operator runs; do NOT claim Delivered without the A:0 result.)

## COMMIT (db:, commit.lock, NO push)
`db: R0e Compare [A] carve-aware (tables-only -t whitelist + routine name/sig presence, revert R0d raw-concat) + Rebuild-Proof.ps1 PS5.1 fix (BOM+2-arg Join-Path+grant) -> truthful E1 gate, A:0`
then §0.6 verify + §0.7 re-sync.

## CAPTURE (NORM-CUR-11 — MANDATORY): append to .claude/skills/role-dba/role-dba.md §B:
`2026-06-21 · Compare [A] for a tables+functions split repo: dump the SERVER tables-only via the SAME -t whitelist as schema.sql and line-diff tables vs schema.sql; validate ROUTINES by name+identity-args presence (pg_get_function_identity_arguments) vs db/functions/* CREATE set + prokind ([B]) — NEVER line-diff raw db/functions source vs pg_dump output (pg_dump canonicalizes -> every routine double-counts as missing+extra; my R0d concat blew A 12->106). On a fresh rebuild function drift is impossible by construction; presence/prokind is the meaningful routine check. · SOURCE: R0d (iv) wrong, R0e fix, proof delta 20260621-204906 · status: active`

## NOTE: this supersedes tools/cc_prompt_r0c_fix_bom.md (its Rebuild-Proof.ps1 fix is folded into (4) here). Do not run both.

## REPORT -> binding cc/dba.md RESULT + inbox/coordinator.md. NO push.
