# Inbox — devops-0619 (RTM View Shell devops) — fresh session, supersedes devops-2-0607

## 2026-06-19T07:40:19Z | from: coordinator-0612 | HANDOFF + PENDING TASK
Previous devops session broke; restarted as devops-0619. Claims (infra/**, deploy/**, .github CI, repo hygiene) released by the old session and re-claimable here.

PENDING (one task) — §35 BOM+CRLF re-encode of deploy/Update-RTMView.ps1:
  EXECUTE: tools/cc_prompt_devops_bom_reencode.md
  Context: d62e704 (DB-apply fix: -MigrationList + pg_dump + functions/migrations psql -f) is LOGIC-CORRECT (coordinator object-store-verified, 309 ln) but LOST the UTF-8 BOM + CRLF. All other pkg PS1 are BOM+CRLF. Re-encode from HEAD (logic unchanged), re-commit deploy:, overwrite the staged pkg copy Installations/234_b58e2c2_19062026_Full/Update-RTMView.ps1. NO push.
  After this: coordinator re-verifies BOM/CRLF/integrity natively, then the operator does ONE copy to the 234 server + the deploy command (E1 gate + -ForceDeploy after dba review + -MigrationList FULL-10).

NOTE: if your bash cannot see .coord/ (mount isolation — old session hit this), use file-tools for writes and tell the operator to relay your RESULT to the coordinator.

## 2026-06-19T08:20:07Z | from: coordinator-0612 | to: devops-0619  [URGENT — 234 deploy blocker: StrictMode .Count crash]
234 STEP-4b ran: pg_dump OK, then CRASH 'property Count cannot be found' (PropertyNotFoundStrict) at L138 `$allBackups.Count` (scalar DirectoryInfo under StrictMode). EXECUTE tools/cc_prompt_devops_strictmode_count_fix.md: wrap @() on $allBackups (L137) + $migrations (L217) + audit; preserve §35 BOM+CRLF; re-commit deploy:; overwrite pkg copy. NO push. Operator restarting services to pre-deploy state meanwhile. Report -> coordinator.

> handled 2026-06-19T08:25:57Z by devops-0619 — root-cause verified vs HEAD (L137/L204 scalar -> L138/L139/L218 .Count); prompt §4-ready; routed to native-CC execution.

## 2026-06-24T20:30:26Z | HANDOFF — devops-0619 -> next devops session
SESSION: devops (RTM View Shell). Discipline: object-store/by-hash verify (mount HEAD-ref truncates to 'v2-'/'v3-' = §0.5, NOT corruption; read .git/refs/heads/<b> directly + git show <sha>:); NARROW-ADD only claimed files (L-SC-09 — 9c6ac0e once swept CLAUDE.md); NO push (§37); commits = native CC, relay run cmd to operator; CC prompts = tools/cc_prompt_*.md -> §4 (`коорд: ревью`) before run.

DELIVERED (all UNPUSHED):
- v2-backend: Garnet PoC GREEN (live cross-instance SignalR fan-out) -> docs/incidents/INC-001_garnet_poc_results.md + infra/garnet-poc/ + BackplaneTest; Phase-2 migration f3368d8 (Install/Update/Build-ProdRelease Memurai->Garnet, NSSM, --auth Password, --recover, sc-failure); Maint v1 scaffold c915d4d (src/Maintenance/RTMMaintenance.ReadPlane — /status+/collect/incident+/jobs, mTLS+token+IP, SF-MS-001/002 seams, SF-MS-003=backend seam 43bb430).
- v3: SF-SOMA-001 9c6ac0e (soma_ro REVOKE base secret tables — live-verified via Soma); Soma lifecycle 7410f34 (FreeShellPort kill-by-port, /shell/kill-stray, v2.4.0); Soma /ops orphan-lock e40a3dc (FreeShellOrphans on /ops/build+/ops/test); F-QA-8 a2318ae (/db/agent-states col ->AgentState, /db/queues ->NGC_Queues — 200).

IN FLIGHT (next action):
- **F-QA-8 residual: /db/dashboards 500** — ROOT CAUSE confirmed (QA+coord): Npgsql NO-MARS — the outer dashboards reader is NOT disposed before the per-dashboard widget-reader loop (tools/Soma/Program.cs /db/dashboards handler, the `foreach (var db in dashboards)` widget query runs on the SAME conn while outer `await using var rdr` still in scope). Fails only with >=1 dashboard row (Trash). FIX: dispose the outer dashboards reader BEFORE the widget foreach (wrap the SELECT+while in a nested {} scope so `await using var rdr` disposes after materializing the list), OR a separate NpgsqlConnection per widget query. Narrow-add tools/Soma/Program.cs, branch v3, fix:, §4 then v3 window. NON-URGENT. (Author the prompt: tools/cc_prompt_devops_soma_dashboards_mars.md.)

QUEUED (mine):
- tools/cc_prompt_devops_soma_healthurl.md — §4-PASS, ready, v3 window (template HealthUrl 7196->5238 + USAGE note). [F-QA-11 itself CLOSED by operator: Memurai up + local HealthUrl=5238.]
- **SF-SEC-001** [HIGH] live-tree purge of DB password (~27 files incl tools/Soma/appsettings.json ReadonlyConnectionString Password=!@#qweASDzxc) — I OWN; GATED on operator setting the rotation window.

CLOSED/VERIFIED by QA: F-QA-3/4/7 (7410f34/e40a3dc), F-QA-11 (HealthUrl 5238 + Redis). Soma is ALIVE 2.4.0; /ops/health up:false = Shell-down (probe target), not Soma — QA retracted the false 'Soma died' alarm.

OPERATOR OPEN ITEMS: Garnet Phase-3 fleet rollout (234/45) on GO; SF-SEC-001 rotation window; Soma redeploy already done (2.4.0 running). Soma token in tools/Soma/appsettings.json (gitignored §47) — used transiently for Chrome /db/query verifies; consider rotation (it appeared in this transcript).

ENV: Soma 127.0.0.1:5199 (operator-managed, reach via host Chrome same-origin fetch + Bearer; sandbox bash CANNOT reach host loopback). Shell dev binds https:5239+http:5238. PG18 C:\Program Files\PostgreSQL\18. Dev DB rtmviewdb has schema drift vs some branches (not a Garnet/Soma issue).
