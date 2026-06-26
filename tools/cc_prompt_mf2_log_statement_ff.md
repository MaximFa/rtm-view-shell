# CC task — MF-2: suppress statement logging during catowner provisioning (FF, LOW)
> Spec: security-0609 (security FF). §4-DRAFTED by coordinator-0612 2026-06-14T04:01Z. Executor: native CC, RTM View Shell repo.
> Claim: db/setup/02_catowner_role.sql (db module). Owner/execute: dba-0610 (db/setup territory). Commit prefix `db:`. **NO push**.
> Writes Python+os.fsync (§0.3); verify by object store (§0.5). Self-contained 2-line SQL guard — no schema/grant change.

## Why (MF-2)
db/setup/02_catowner_role.sql L4 runs `SELECT set_config('ccdashboard.catowner_pw', :'catowner_pw', false);` — a top-level
statement carrying the catowner password LITERAL. Provisioned via `psql -U <super> -v catowner_pw=... -f` (deploy L595). If PG
`log_statement='all'` (or `log_min_duration_statement>=0`) is set on the server, that statement (and CREATE/ALTER ROLE ... PASSWORD)
lands in the server log in cleartext. Same leak class as `-v` on the command line. LOW/FF (deploy-time, super-only), but cheap to close.

## 0. Pre (coord discipline)
§0.6a integrity (git status; hash-verify db/setup/02_catowner_role.sql vs HEAD — mount false-M). §40 mandatory skill read.
Binding PREAMBLE -> .coord/cc/dba.md (status: open, directive ref). commit.lock around commit; cc_post_commit.sh after; §0.7 re-sync.

## 1. Edit db/setup/02_catowner_role.sql — add session-local logging suppression at the VERY TOP (before L4 set_config)
Insert immediately after the header comment block, BEFORE the `SELECT set_config(...catowner_pw...)` line:
```sql
-- MF-2 (security FF): suppress statement logging for this provisioning session so the catowner
-- password (set_config below + CREATE/ALTER ROLE ... PASSWORD) is never written to the server log.
-- Session-local; superuser-settable (script runs as the PG superuser); auto-reset when the psql -f session ends.
SET log_statement = 'none';
SET log_min_duration_statement = -1;
```
Do NOT change anything else (set_config, the DO $$ role block, or the GRANTs). Keep idempotency. Keep file encoding (no BOM for .sql per psql -f; match the file's current encoding).

## 2. Self-tests
- File still starts with the header comment; the two SET lines precede `set_config('ccdashboard.catowner_pw'`.
- No other line changed: `git diff HEAD -- db/setup/02_catowner_role.sql` shows ONLY the inserted SET block.
- (Optional, if a PG is handy) `psql -f` the script as super against a scratch DB -> succeeds, role provisioned, no error.

## 3. Commit (db:, NO push) under commit.lock
git add db/setup/02_catowner_role.sql
git commit -m "db: MF-2 suppress statement logging during catowner provisioning (FF — avoid password in server log)"
§0.6 post-commit verify -> cc_post_commit.sh dba-0610 <hash> -> sync.

## Acceptance (object-store verified)
- db/setup/02_catowner_role.sql carries the SET log_statement='none' + SET log_min_duration_statement=-1 block ABOVE the catowner set_config; only that block added.
- Commit `db:`; binding RESULT to .coord/cc/dba.md; journal appended; NO push.

## Binding RESULT postamble -> .coord/cc/dba.md (status: done): commit <hash>; 2-line SET block inserted above set_config (diff = only insert); NO push; verified: object-store.
