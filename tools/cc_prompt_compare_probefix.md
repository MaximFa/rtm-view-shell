# CC Task — Compare-ToBaseline dimension-D probe accuracy (db/tools/Compare-ToBaseline.ps1)

> Session devops-2-0607. The comparator's migration-ledger (dimension D) leaves migrations as
> [???] UNKNOWN when there's no per-migration probe, and can mis-report [MISSING]. On the Server 234
> snapshot, _004_metrics_dedup / _008_daytrend_fn_bu_scope / _002_db_patch_history /
> _003_fix_curlogintimestamp came back UNKNOWN (no ledger present). Improve D so each migration is
> classified by a real signal. NON-blocking for 234 (we cross-check by hand) but it makes the VERIFY
> phase trustworthy for future servers.

## 0. §0.6a integrity check FIRST; 0b §40 skill reads — standard preamble.

## Multi-session sync (§42.6) — slug devops-2-0607
Claims (file-mode): `db/tools/Compare-ToBaseline.ps1` ONLY.
- S1 push-barrier check; S2 `coord_check_claims.py devops-2-0607 db/tools/Compare-ToBaseline.ps1`;
  S3/S4 commit.lock + `cc_post_commit.sh`. Modify ONLY that file.
## Git push — DO NOT (§37). §0.3 — Edit BANNED, Python+fsync, `tail -3`+`wc -l`. §35 BOM if PS1 — keep BOM/CRLF.

---

## Changes — dimension D (and a small dimension A improvement)

**D1. Ledger-first, probe-fallback, with an explicit per-migration probe map.**
- When `public.db_patch_history` exists, read applied names from it directly (EXACT) for any
  migration whose file self-records (the §38a convention). Keep this as the authoritative source.
- For migrations with NO ledger row, fall back to a **per-migration presence probe** from an explicit
  map (file name → SQL boolean). Add probes for the four currently-UNKNOWN migrations:
  - `20260605_004_metrics_dedup` → applied if the typo'd duplicate metrics are GONE, e.g.
    `SELECT NOT EXISTS(SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId" LIKE '%Abandonef%');`
  - `20260606_008_daytrend_fn_bu_scope` → applied if fn has the NEW signature:
    `SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='fn_daytrendagentstatus' AND pg_get_function_identity_arguments(oid) LIKE '%p_businessunitid integer%');`
  - `20260607_002_db_patch_history` → `SELECT to_regclass('public.db_patch_history') IS NOT NULL;`
  - `20260607_003_fix_curlogintimestamp` → `SELECT EXISTS(SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId"='MonAgentCurrentLoginTimeStamp' AND "MetricFunction"='CurLoginTimestamp');`
- Any migration still without a ledger row AND without a probe → label `[?] NO-SIGNAL` (not the bare
  `[???]`), and list those names under an explicit "verify manually" note so the operator knows the
  exact gap rather than guessing.

**D2. Eliminate false-MISSING.** Re-check the existing MISSING probes for
`20260604_001_add_agent_state_pct_metrics` and `20260606_005_history_unavailable_metrics` against
what those migrations actually create (e.g. `20260604_001` → presence of metric ids like
`MonAgentAvailableDurationPct`; `_005` → its history_unavailable rows/columns). A migration must be
MISSING only when its concrete object/data is genuinely absent. Fix any probe that keys on the wrong object.

**D3. Summary line.** Report D as `applied(ledger)/applied(probe)/missing/no-signal` counts so the
operator sees confidence at a glance.

**A1 (small).** In dimension A, in addition to the missing/extra line counts, emit a best-effort
itemised breakdown of TABLES present in baseline-but-not-server and server-but-not-baseline (parse
`CREATE TABLE` names from both normalised dumps). Keep it best-effort; never emit guessed ALTERs.
The advisory align.sql + its WARNING header (do-not-run-on-prod, §38.5) stays unchanged.

Keep the script **READ-ONLY** on the target (SELECT / pg_dump only). Preserve all existing params,
`-BaselineDir`, output file names, and BOM-less UTF-8 for the align.sql.

## Self-test
Run against any reachable DB (or the prod/server snapshot if available) and confirm:
- the four formerly-UNKNOWN migrations now resolve to a definite OK/MISSING (not [???]);
- D summary line prints the four counts;
- script still exits 0 on a no-drift DB and writes both output files;
- `tail -3` proper close; `wc -l` sane; BOM intact (PS1 §35).
If no DB reachable in CC env: run `[Parser]::ParseFile` syntax check + grep-verify the probe map
contains all four new entries; report that a live run was not performed.

## Commit
`pre-commit-check.sh` → 0; commit.lock → `git add db/tools/Compare-ToBaseline.ps1`
→ `git commit -m "db: Compare-ToBaseline dim-D per-migration probes + dim-A table itemisation"`
→ §0.6 post-commit + `cc_post_commit.sh` + journal + lock release + HEAD re-sync. NO push.

## Report
The four probe results, D summary counts, syntax/live status, commit hash.
