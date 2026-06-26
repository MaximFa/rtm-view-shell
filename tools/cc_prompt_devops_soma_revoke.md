# CC task — DEVOPS: SF-SOMA-001 — revoke soma_ro base secret tables (v3 push BLOCKER)
> §4-PASS coordinator-0623 2026-06-23T22:15:57Z — GREENLIT. Owner devops-0619.
> Branch **v3**. Claim (file-mode): `db/soma_readonly_role.sql` ONLY. Prefix `fix:`/`db:`. commit.lock. NO push (§37).
> Security HOLD on v3 push until this lands + security re-acks READY.

## SF-SOMA-001 [MEDIUM] — what's wrong (object-store confirmed)
`db/soma_readonly_role.sql` grants soma_ro schema-wide SELECT, then creates `*_safe` redacting views, but NEVER revokes the
BASE secret-bearing tables — so soma_ro can read secrets directly, bypassing the _safe views (§47 intent = "*_safe views; secrets redacted"):
- L47 `GRANT SELECT ON ALL TABLES IN SCHEMA identity` -> `SELECT * FROM identity.users` exposes PasswordHash, SecurityStamp, ConcurrencyStamp. (L51-53 revoke refresh_tokens/two_factor_codes/user_password_history but NOT users; L71-72 comment admits it.)
- L33 `GRANT SELECT ON ALL TABLES IN SCHEMA public` -> base `public.sso_configurations` (ClientSecret) + `public.tenant_settings` (EmailProviderConfig) readable; only the *_safe views (L75-93) were meant to be exposed.

## THE FIX (db/soma_readonly_role.sql ONLY)
1. AFTER all three `*_safe` views are created + granted (i.e. after the `tenant_settings_safe` GRANT, ~L93), append:
```sql
-- ============================================================
-- SF-SOMA-001: revoke BASE secret-bearing tables so soma_ro uses ONLY the *_safe views
-- (PostgreSQL views run with the view OWNER's privileges, so revoking soma_ro's base-table
--  SELECT does NOT break users_safe / sso_configurations_safe / tenant_settings_safe.)
-- Idempotent: REVOKE of a non-existent grant is a harmless no-op.
-- ============================================================
REVOKE SELECT ON identity.users           FROM soma_ro;
REVOKE SELECT ON public.sso_configurations FROM soma_ro;
REVOKE SELECT ON public.tenant_settings   FROM soma_ro;
```
2. Fix the now-stale comment at L71-72 ("soma_ro still has SELECT on users ... queries should use users_safe") to state the base table is now REVOKED and soma_ro MUST use users_safe.
3. Keep every `GRANT SELECT ON <x>_safe TO soma_ro` (L70/L81/L93) intact. Do NOT touch the audit-schema grants. Logic otherwise unchanged.

## ORDERING note
The REVOKEs must come AFTER the view CREATEs (the views read the base tables at definition time; revoking soma_ro afterward is
fine — the role never owned the views). The whole script stays idempotent + re-runnable.

## RE-APPLY on the running dev DB (so the live soma_ro is corrected now)
```
psql -U postgres -d rtmviewdb -f db/soma_readonly_role.sql
```
(or just the 3 REVOKEs against the live DB). Operator runs this; it is part of acceptance.

## VERIFY
- object-store `git show HEAD:db/soma_readonly_role.sql`: the 3 REVOKEs appear AFTER the *_safe view creates; the 3 `*_safe` GRANTs still present; comment L71-72 corrected.
- On the running DB, as soma_ro: `SELECT "PasswordHash" FROM identity.users;` -> **permission denied**; `SELECT * FROM identity.users_safe;` -> OK. Same for sso_configurations(_safe) + tenant_settings(_safe). (security/QA verify via Soma.)

## DISCIPLINE
§0.2/§0.5 integrity (mount-git flaky: HEAD-ref may read 'v3-...'/truncated, index may read corrupt — verify by-hash/object-store, native git is source of truth). §0.6a/§0.6b binding pre/postamble -> .coord/cc/devops.md. commit.lock around the commit. NO push.

## ACCEPTANCE
3 REVOKEs committed after the view creates (object-store); soma_ro `SELECT PasswordHash FROM identity.users` -> permission denied on the running DB; *_safe reads still work; security re-acks READY -> v3 barrier proceeds.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: commit hash, the 3 REVOKEs confirmed object-store, running-DB re-apply done, NO push.
