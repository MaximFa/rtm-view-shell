---
name: sf-sec-001-db-password-in-source
description: "SF-SEC-001 [HIGH] — ccdashboard DB password committed in plaintext across ~27 tracked files (both branches); rotate + purge live tree, accept history"
metadata: 
  node_type: memory
  type: project
  originSessionId: 353c6afb-9b31-468d-8b11-483a44479cf0
---

**SF-SEC-001 [HIGH · secret-in-source]** (triaged 2026-06-22 by security-0620). The ccdashboard
PostgreSQL password is committed in PLAINTEXT across **~27 tracked files in the current tree on
BOTH branches (v3 + v2-backend)** — not just one file. (The actual value is NOT recorded here per
the no-secrets-in-memory rule; it's a `Password=...` in `Username=ccdashboard_user` conn-strings.)

Confirmed REAL connection-string secrets (not comments): `RTM/RTM/appsettings.json`
(RTMConnectionString), `src/CcDashboard.Web/appsettings.Development.json`, `Installations/Tools/Grant.txt`
(`CREATE USER ccdashboard_user WITH PASSWORD '...'`), `Installations/03062026/{RTM,Shell}/appsettings*.json`
(shipped packages), `db/tools/Create-FreshDb.ps1` + `Restore-All.ps1`, `CLAUDE.md` §38.2/§39.1a examples,
~13 `tools/cc_prompt_*.md`, `docs/BACKUP_RESTORE.md`. Violates CODE-05/06 + §25 + PR checklist.

**Triage (routed to coordinator-0612, inbox/coordinator.md 2026-06-22T05:42Z):**
- **(a) Rotate = MANDATORY, assume compromised** — operator/dba rotate `ccdashboard_user` on ALL servers
  (234/45/5239 + dev). Rotation is the only control that neutralizes it; history-scrub does not recall clones.
- **(b) ACCEPT history after rotation; PRIORITIZE live-tree purge** — devops purge the 27 occurrences →
  REPLACE_ME / preserved-config (project already uses REPLACE_ME); source password via `-DBPassword` param /
  Credential Manager. Full BFG history-rewrite = disproportionate on this mount (PD-005/007); re-evaluate
  only if repo ever goes public/external.
- **Non-blocking** for pushes (pre-existing debt; no NEW secret introduced by feature commits). HIGH → needs
  a prompt remediation task. Ties to Garnet COND-2 + MaintenanceService SF-MS-002 (same no-hardcode discipline).
- Verify remediation by grep-zero of the secret in the live tree post-purge.

The discipline rule going forward: appsettings secrets use the REPLACE_ME/preserved-config pattern;
deploy scripts take the password via param, never embed. See [[avoid-paid-components]] sibling-era constraints.
