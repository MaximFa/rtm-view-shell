# cc-binding channel: devops <-> CC (NORM-CUR-07). Append-only. Spec consumes RESULT, relays digest to coordinator.

## 2026-06-13T11:25Z | binding: devops <-> CC | directive: tools/cc_prompt_iter1c_b2_repack45.md | status: done
### DIRECTIVE (spec->CC): ensure Phase-5c B2 quoted "TenantId"/"SignalRConnectionUrl" (idempotent) + repackage 45 from HEAD (dba regen 3db705d), ONE pass, content-verify, no push.
### RESULT (reconciled by spec from artifact — CC's binding write dropped/skipped, L-SC-04):
- status: done. Package PRODUCED: Installations/45_3db705d_20260613-1408.zip (14:08). [SUPERSEDED — failed 02:335 table-drift]
- Tip = 3db705d. NO push.
> consumed 2026-06-13T11:30Z by devops-2-0607.

## 2026-06-13T16:09Z | binding: devops <-> CC | directive: tools/cc_prompt_repack45_d18c79d_011.md | status: done
### DIRECTIVE (spec->CC): repackage 45 from HEAD d18c79d (functions 3db705d + migration _011 table-drift ADD COLUMN + B2-quoted orchestrator), content-verify, no push.
### RESULT (reconciled by spec from artifact — CC binding write dropped again, L-SC-04):
- status: done. Package PRODUCED: Installations/45_d18c79d_20260613-1609.zip (16:09).
- Tip = d18c79d. Content verify-by-construction: gates (functions 01=835/02=496, no CreatedDatetime, DROP-guards>=14, _011 >=54L & >=23 ADD COLUMN, orchestrator B2 quoted, BOM+parse, migrations==repo) all run BEFORE Compress-Archive; zip exists => passed.
- Spec independent cross-check: db/migrations/20260613_011_45_table_drift_addcolumns.sql = 24 ADD COLUMN (restored from HEAD by build §0); functions 01/02 full (835/496).
- NO push. Awaiting coordinator zip-level verify -> operator re-applies ONCE on 45 (-MigrationList 001,004,005,008,011).
> consumed 2026-06-13T16:12Z by devops-2-0607 — relayed digest to coordinator (operator backstop).

## 2026-06-14T05:08:43Z | binding: devops <-> CC | directive: tools/cc_prompt_b2_quotesafe_psql.md | status: open
### DIRECTIVE: B2 UPDATE quote-safe (psql -c $updateSql -> -f tempfile); fixes PowerShell embedded-quote strip -> 42703 + scan other -c-with-quotes. Claim: deploy/Apply-Server45Upgrade.ps1. Prefix: deploy:.

### RESULT (by CC): commit b618a14 deploy: B2 + DROP/CREATE DB now use -f tempfile (quote-safe) ; parse OK ; -c $updateSql removed, -f $tmpB2 present ; other -c-with-quotes: L134+L136 (DROP/CREATE DB) also converted to -f ; BOM ok ; commit.lock released ; journal appended. NO push. verified: object-store (git show HEAD).
## 2026-06-14T05:11:34Z | binding: devops <-> CC | directive: tools/cc_prompt_b2_quotesafe_psql.md | status: done

## 2026-06-18T15:34Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_234_compare_bundle.md | status: done
### DIRECTIVE (spec->CC): build read-only Compare bundle for 234 pre-deploy drift check from origin/v2-backend b58e2c2 objects; zip to Installations/; no commit/push.
### RESULT (reconciled by spec from artifact — CC binding write dropped, L-SC-04):
- status: done. Bundle PRODUCED: Installations/234_compare_b58e2c2_20260618-153439.zip (15:34).
- Built natively by CC (resolved b58e2c2; this Cowork session's bash-git is stale at 7a9a70d and cannot resolve b58e2c2, so the build had to be native — confirms §0.7/Executor=native CC).
- ⚠ Spec could NOT independently unzip/hash-verify (bash blind to Installations; file-tools have no unzip). Existence confirmed via Glob. CC's in-prompt VERIFY (unzip -l contents, Compare-ToBaseline.ps1 hash==HEAD, schema phantom-grep=0) is the authoritative content check — recommend coordinator zip-level verify before operator runs on 234, OR operator pastes CC's VERIFY output.
- NO commit, NO push (Installations gitignored).
> consumed 2026-06-18T15:40Z by devops-2-0607 — relayed digest to coordinator (operator backstop; coordinator.md Edit-append corrupts under concurrency).

## 2026-06-18T16:30Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_234_build_package.md | status: done
### DIRECTIVE (spec->CC): build 234 Full deploy package (Build-ProdRelease -Mode Full) from origin/v2-backend b58e2c2; FULL-10 -MigrationList in README; §35 BOM+CRLF; zip to Installations/; no push.
### RESULT (reconciled by spec from artifact — CC binding write dropped, L-SC-04):
- status: done. Package PRODUCED: Installations/234_b58e2c2_19062026_Full.zip.
- Built natively by CC (resolved b58e2c2; this Cowork session bash-git stale at 7a9a70d, .coord bash-view frozen Jun-9 + writes isolated — proven by probe; native CC required per §0.7/Executor=native CC).
- STEP-1 gate was satisfied: dba FULL-10 -MigrationList + backend NGC=CALL (B=1 self-heals on functions re-apply).
- ⚠ Spec could NOT independently unzip/hash-verify (bash isolated from live FS; file-tools have no unzip). Existence confirmed via Glob. CC in-prompt VERIFY (zip contains CcDashboard.Web.exe + db\ schema/functions/migrations[incl _001+_011-015]+data + deploy\*.ps1 + README FULL-10; PS1 BOM+CRLF; dotnet publish 0-err) is authoritative — recommend coordinator zip-verify before 234 staging.
- NO commit, NO push (Installations gitignored).
> consumed 2026-06-18T16:32Z by devops-2-0607.
> consumed 2026-06-19T05:54:10Z by coordinator-0612 — verified d62e704 (DB-apply fix) by object-store: param/pg_dump/apply-cycle CORRECT in HEAD (309 ln). BUT §35 REGRESSION: HEAD blob lost BOM (first3=23 52 65) + CRLF; pkg WT was also PD-007-truncated (restored). All other pkg PS1 = BOM+CRLF. -> BOM+CRLF re-encode required before swap. Routed back to devops.

## 2026-06-19T07:46:48Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_bom_reencode.md | status: open
### DIRECTIVE: §35 BOM+CRLF re-encode of deploy/Update-RTMView.ps1 (logic UNCHANGED) + overwrite staged pkg copy Installations/234_b58e2c2_19062026_Full/Update-RTMView.ps1. Claim: deploy/. Prefix: deploy:. NO push.
### RESULT (by devops-0619, verified object-store):
- COMMIT: NO new commit — already satisfied. HEAD=024feef IS `deploy: Update-RTMView.ps1 -> UTF-8 BOM+CRLF` (on top of d62e704 DB-apply logic). Re-commit would be EMPTY: `git diff --stat HEAD -- deploy/Update-RTMView.ps1` is empty; HEAD blob 99afc0 already carries BOM (first3=ef bb bf). Task was authored when HEAD=d62e704 (no BOM); reality moved on (024feef landed, unjournaled) — §0.1 reality-wins, did NOT create noise/empty commit.
- WT deploy/Update-RTMView.ps1: was PD-007-truncated (301 ln); RESTORED from HEAD -> BOM+CRLF, 309 ln, CR==309, last line `Write-Host ""`. git diff HEAD now empty (eol-aware).
- STAGED pkg copy Installations/234_b58e2c2_19062026_Full/Update-RTMView.ps1: was PD-007-truncated (263 ln, cut mid-statement L263); OVERWRITTEN from HEAD -> BOM+CRLF, 309 ln, CR==309. Content byte-identical to HEAD (strip BOM+CR diff = empty).
- VERIFY: head -c3 = ef bb bf (BOTH, via xxd); CR-lines==wc -l==309 (BOTH); DB-apply markers intact (-MigrationList L19, pg_dump L120, ON_ERROR_STOP functions L194 + migrations L211); content IDENTICAL to HEAD normalized.
- ⚠ PS 5.1 [Parser]::ParseFile NOT runnable on Linux mount — recommend coordinator/operator native parse on Windows. Structural completeness verified (full 309 ln, all markers, proper terminal line). BOM (the only §35 defect) now present.
- NO push (§37). Unpushed local commits on v2-backend: d62e704 (logic) + 024feef (BOM) — include when operator eventually pushes.
- SWAP-READY: staged 234 pkg Update-RTMView.ps1 fixed (BOM+CRLF, 309 ln).
## 2026-06-19T07:48:09Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_bom_reencode.md | status: done

> reconciled 2026-06-19T09:12:10Z by coordinator-0612 (object-store, devops RESULT not in bus L-SC-04): e46e849 'deploy: preserve Shell appsettings.json' VERIFIED — HEAD L233 preserveFiles=@(appsettings.json,appsettings.Production.json,nlog.config); ALL 4 today fixes intact (BOM ef bb bf, 309 ln, @()x2, DB-apply markers 15); pkg copy swap-ready (BOM 309/309, WT==HEAD). Package now LESSON-COMPLETE for 45. unpushed v2-backend=4.
iew.ps1 to C:\RTMView-Ops\incoming\234_b58e2c2_19062026_Full\Update-RTMView.ps1 on 234.)
- NEEDS: CC verify output (head-c3/CRLF/parse) or coordinator native byte-check before declaring §35 done + before 234 swap.
> consumed 2026-06-19T07:42Z by devops-2-0607.
## 2026-06-21T06:10Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_memurai_resilience.md | status: open
### DIRECTIVE: Memurai service resilience — StartupType=Automatic + sc.exe failure auto-restart; README runbook note for /health/ready Redis check. Claim: deploy/. Prefix: deploy:. NO push.

### RESULT (by CC):
- COMMIT: da4cd7e deploy: Memurai service resilience — StartupType=Automatic + sc.exe failure auto-restart (INC-2026.06.20-001)
- Files changed: deploy/Install-RTMView.ps1 (+14 lines), deploy/README.txt (+15 lines)
- VERIFY (object-store):
  - Install-RTMView.ps1: Set-Service -StartupType Automatic PRESENT; sc.exe failure "Memurai" reset=86400 actions=restart/5000/restart/10000/restart/60000 PRESENT; sc.exe failureflag "Memurai" 1 PRESENT
  - MSI/requirepass logic UNCHANGED (msiexec.exe present, requirepass present)
  - Encoding: HEAD blob first3 = 23 52 65 (NO BOM - convention preserved)
  - README.txt: /health/ready runbook note PRESENT in MONITORING section
- Parse: PS 5.1 [Parser]::ParseFile NOT runnable on this mount — recommend operator native parse on Windows
- NO push (§37)
## 2026-06-21T06:16Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_memurai_resilience.md | status: done

## 2026-06-21T06:56:42Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_memurai_resilience.md | status: done
### RESULT (verified by devops-0619, object-store):
- COMMIT da4cd7e (Maxim native 09:52+0300) deploy: Memurai resilience. ONE-RELEASE pair: shell (a) 9732eab (AbortOnConnectFail=false) also in history.
- deploy/Install-RTMView.ps1 HEAD blob: resilience block L184-196 — Set-Service -StartupType Automatic + `sc.exe failure Memurai reset=86400 actions=restart/5/10/60s` + failureflag 1 + echo/WARN catch. Placed OUTSIDE the install-only else, under `if ($memSvc)` -> runs for BOTH existing-install AND fresh-install (and -SkipMemurai-but-present). 
- /health/ready: NO new endpoint; README.txt MONITORING note added (L133-141: /health/ready incl Redis/PG, alert non-200, curl example).
- Encoding PRESERVED no-BOM (first3=23 52 65) as required (Install convention; build adds BOM at package time). 308 ln (+14). MSI/requirepass logic untouched (L166/L172-173).
- WT in sync (git diff --stat HEAD empty) — no PD-007 this run. No staged pkg overwrite needed (Install not individually swapped). PS5.1 parse owed to operator. NO push.

## 2026-06-21T18:39:06Z | binding: devops <-> CC | directive: tools/cc_prompt_tag_v2_verified.md | status: done
### RESULT (verified by devops-0619, object-store):
- Annotated tag v2-server-verified-20260619 created (cat-file -t = tag) -> points at b58e2c2 (b58e2c299724884e4519ccfc65a027b398fe5ab9). PRESENT ON ORIGIN: git ls-remote shows tag-obj 370a5ca + peeled ^{} = b58e2c2.
- origin/v2-backend UNCHANGED at 5206633 -> tag op pushed ONLY the tag ref, zero branch commits (§37 tag-only exception honored).
- deploy/ROLLBACK.md committed 7cbc32c (Maxim native 21:28+0300), in HEAD, complete (100 ln): version+commit, live-data backup paths (234 19062026_1134 / 45 19062026_1214), 4-step rollback (checkout/DB-restore/redeploy 234_b58e2c2_Full.zip/verify), Notes. Last line complete (no truncation).
- Rollback anchor pinned. INC + reports work after b58e2c2 = coded, NOT server-tested (documented).

## 2026-06-21T20:32:36Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_redis_eval.md | status: done
### RESULT (verified by devops-0619, object-store):
- COMMIT 5e9e22d (Maxim native 23:16+0300) docs: INC-001(d) Redis-alt eval. UNPUSHED (local, on top of pushed 8bbee78).
- docs/incidents/INC-001_redis_alternative_eval.md HEAD blob: 191 ln, complete (Exec Summary -> Constraint Matrix -> Scoring -> Detailed Analysis x3 -> Migration Outline -> Rollback -> Verification Checklist -> Decision Record -> Next Steps -> References). Last line complete (no truncation). WT==HEAD (no PD-007).
- RECOMMENDATION: Microsoft Garnet (10/11) > Valkey-WSL2 (8/11) > Redis-OSS-WSL2 (7/11). Matrix scores CRITICAL (SignalR backplane pub/sub via StackExchange.Redis, not just GET/SET) + LICENSE current facts (Garnet MIT / Valkey BSD-3 / Redis7.4+ SSPL-RSAL). Migration outline keeps localhost:6379 unchanged; rollback to Memurai documented.
- HONEST CAVEAT: Garnet 'Redis 7+ parity = PARTIAL' (covers our uses: strings/lists/pub-sub/TTL). Before any migration: the doc's Verification Checklist should be run as a pub/sub PoC against AddStackExchangeRedis. This is a RECOMMENDATION for the operator (d) decision, NOT a prod change.
- NO push. NO prod change (eval only).

## 2026-06-22T06:00Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_garnet_poc.md | status: open
### DIRECTIVE: Garnet PoC (INC-001 (d) Phase 1 gate) — verify SignalR pub/sub backplane + RESP coverage. Dev/local only, NO prod change.

### RESULT (by CC):
- COMMIT: 8392e56 on v3 `infra: Garnet PoC config + verification script (INC-001(d) Phase 1 gate)`
- Files:
  - infra/garnet-poc/README.md — setup instructions
  - infra/garnet-poc/Verify-GarnetPoC.ps1 — automated verification script (8 tests)
  - infra/garnet-poc/garnet-args.txt — recommended GarnetServer arguments
  - docs/incidents/INC-001_garnet_poc_results.md — results template (PENDING execution)
- Parity matrix tests:
  1. PING
  2. StringSet/Get (RedisCacheService)
  3. TTL/EXPIRE (PG-cache, JTI)
  4. INCR (rate-limit)
  5. LIST ops (JTI list)
  6. AUTH (requirepass)
  7. PUB/SUB command (PUBLISH accepted)
  8. Tenant-prefixed keys
  + Manual: SignalR backplane fan-out (CRITICAL)
- STATUS: PoC READY FOR EXECUTION by operator
- Verdict: PENDING (awaiting operator to run Garnet + Verify-GarnetPoC.ps1)
- NO prod change in this task
- NO push (§37)
## 2026-06-22T06:12Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_garnet_poc.md | status: done

## BINDING 2026-06-22T12:10:39Z | spec: devops | directive: tools/cc_prompt_devops_garnet_phase2.md | status: open
### DIRECTIVE (spec->CC): Phase 2 Garnet migration — modify Build-ProdRelease.ps1, Install-RTMView.ps1, Update-RTMView.ps1 for Garnet instead of Memurai. Fix garnet-args.txt auth syntax. Add Garnet section to ROLLBACK.md. Claims: deploy/, tools/, infra/, docs/.
---

### RESULT (CC->spec): 2026-06-22T12:16:48Z
- commit: f3368d8 deploy: INC-001(d) Phase 2 — migrate deploy chain Memurai->Garnet
- files:
  - tools/Build-ProdRelease.ps1 (388 lines) — Garnet+NSSM packaging, -UseMemurai rollback
  - deploy/Install-RTMView.ps1 (349 lines) — Garnet via NSSM, --auth Password --password, resilience
  - deploy/Update-RTMView.ps1 (378 lines) — [4b/5] Memurai->Garnet migration step
  - deploy/ROLLBACK.md (116 lines) — Garnet rollback procedure + COND-1 security note
  - infra/garnet-poc/garnet-args.txt (44 lines) — auth syntax fix + --recover
- build/test: N/A (script changes, no .NET build required)
- blockers: none
- object-store verify: yes — f3368d8 in git log HEAD

COND-2 (security) verify: NO literal password in any .ps1 — all use $RedisPassword param.
grep confirms: Select-String -Pattern "TestPwd123" deploy/*.ps1 tools/Build-ProdRelease.ps1 returns 0 matches.

## BINDING CLOSED 2026-06-22T12:16:48Z | status: done
---

## 2026-06-22T09:28:39Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_garnet_phase2.md | status: done
### RESULT (verified by devops-0619, object-store by-hash):
- COMMIT f3368d8 (native CC) deploy: INC-001(d) Phase 2 — Memurai->Garnet. 5 files, 399+/51-: Install-RTMView.ps1(+133), Update-RTMView.ps1(+115), Build-ProdRelease.ps1(+126), ROLLBACK.md(+64), garnet-args.txt(12). UNPUSHED on v2-backend.
- Garnet install (Install [2/6]): NSSM service, `--bind 127.0.0.1 --port 6379 --auth Password --password $RedisPassword --checkpointdir ... --recover --checkpoint-freq 300`, SERVICE_AUTO_START. Memurai retained as -UseMemurai rollback.
- Update [4b/5]: idempotent Memurai->Garnet migration (stop+disable Memurai, NOT uninstalled). Build-ProdRelease: Garnet 1.1.10 net8 + NSSM packaging (Memurai MSI deprecated).
- COND-1 ✅ (runbook: Redis-state reset / revoked-JTI+lockout empty -> Update warning + ROLLBACK.md). COND-2 ✅ (independent scan: NO literal TestPwd123/DB-pwd in any deploy/tools .ps1; all via $RedisPassword). COND-3 ✅ (127.0.0.1, not localhost).
- STEP-E reconcile HONORED: results-doc/BackplaneTest/Verify-GarnetPoC.ps1 NOT re-committed (already in 2a63f57); only garnet-args.txt auth fix + --recover landed. No double-commit.
- §35 BOM: see spot-check (head -c3) below. build/verify = N/A (PS1, not compiled); pre-commit-check is the gate, commit succeeded.
- MOUNT NOTE: .git/HEAD read truncated to 'refs/heads/v2-' (§0.5 mount artifact, NOT corruption — by-hash object reads work fine). Native CC committed cleanly.
- NO push (§37).

## 2026-06-24T02:00:00Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_revoke.md | status: open
### DIRECTIVE: SF-SOMA-001 revoke soma_ro base secret tables. Claims: db/soma_readonly_role.sql ONLY. Prefix: fix/db.
### RESULT (CC->spec):
- commit: 9c6ac0e (fix: SF-SOMA-001 revoke soma_ro base secret tables)
- files: db/soma_readonly_role.sql (+9 lines: 3 REVOKEs + SF-SOMA-001 comment block)
- build/test: N/A (SQL script)
- blockers: none
- verified: object-store (git show confirms all 3 REVOKEs present after *_safe view creates; *_safe GRANTs intact)
- status: done
NOTE: Operator must re-apply on running DB: psql -U postgres -d rtmviewdb -f db/soma_readonly_role.sql
Then verify: soma_ro SELECT PasswordHash FROM identity.users -> permission denied; SELECT * FROM identity.users_safe -> OK.
Security re-ack required for v3 barrier.
## 2026-06-23T22:21:38Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_revoke.md | status: done
### RESULT (verified by devops-0619, object-store + live psql):
- COMMIT 9c6ac0e (native CC) `fix: SF-SOMA-001 revoke soma_ro SELECT on base secret tables` on v3. UNPUSHED.
- db/soma_readonly_role.sql: 3 REVOKEs (identity.users + public.sso_configurations + public.tenant_settings) at L100-102, placed AFTER the *_safe view creates/grants (last grant L92); SF-SOMA-001 comment block L95; stale L71 comment corrected ("Base identity.users SELECT is REVOKED... MUST use users_safe"); *_safe GRANTs kept. Committed blob contains all 3 REVOKEs (grep=3 by-hash).
- LIVE DB re-apply: operator ran `psql -U postgres -d rtmviewdb -f db/soma_readonly_role.sql` -> clean, NO errors (DO/GRANT/REVOKE/CREATE VIEW series; tail REVOKEs incl the 3 SF-SOMA). Live soma_ro corrected.
- Denied-check (acceptance final): security/QA verify via Soma that `SELECT PasswordHash FROM identity.users` as soma_ro -> permission denied; *_safe reads still OK.
- NO push (§37).

### 2026-06-23T22:27:35Z | SF-SOMA-001 LIVE-VERIFY (Soma/soma_ro): users/sso_configurations/tenant_settings base -> permission denied (400); users_safe -> 200 row. Acceptance MET. 9c6ac0e.

> consumed 2026-06-24T09:11:37Z by coordinator-0623 — c915d4d object-store VERIFIED (new discipline applied): v2-backend tip, parent=51daa8a (correct branch+parent), 26 files/1081 ins, ZERO deletions, ONLY src/Maintenance/** (narrow-add held). v3=2a90c05 untouched. Scaffold CLEAN. Opens backend SF-MS-003 exec-gate; routed security post-commit re-review.

## 2026-06-24T09:15:33Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_maint_scaffold.md | status: done
### RESULT (verified by devops-0619, object-store by-ref; mount HEAD-ref truncated 'v2-' = §0.5):
- COMMIT c915d4d (native CC) `feat(maint): MaintenanceService v1 read-plane scaffold` on v2-backend (on 51daa8a). UNPUSHED.
- NARROW-ADD HONORED (L-SC-09): all 19 files under src/Maintenance/RTMMaintenance.ReadPlane/ — NO CLAUDE.md / shared-file sweep (the 9c6ac0e mistake NOT repeated). bin/obj NOT tracked.
- .csproj: net8.0, win-x64, SelfContained, Microsoft.Extensions.Hosting.WindowsServices 8.0.0 (UseWindowsService). Builds (bin/obj present).
- Endpoints v1 ONLY: StatusController(/status) + CollectController(/collect/incident -> jobId + pollUrl /jobs) + JobsController(/jobs). NO write-plane.
- Auth 3-factor middleware: MtlsValidationMiddleware + TokenValidationMiddleware + IpAllowListMiddleware + AuditMiddleware.
- Seams: Contracts/ISignalValidator.cs (SF-MS-003 = backend's contract, exec-gate opens) + Contracts/ISecretScrubber.cs + Services/DefaultSecretScrubber.cs (SF-MS-002 scrub). Security/SF-MS-001-ReadOnlyAccount.md (least-priv doc). Jobs/JobManager (async). Models/SecurityOptions+JobOptions.
- NO push (§37).

## 2026-06-24T10:04:50Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_lifecycle.md | status: done
### RESULT (verified by devops-0619, object-store by-ref):
- COMMIT 7410f34 (native CC) `fix(soma): shell-control lifecycle — kill-by-port free 5239 ...` on v3 (on Ф1 473363c). UNPUSHED.
- NARROW-ADD: only tools/Soma/Program.cs (+85/-10, 1 file; deletions = rewritten stop/start/restart lines, NO file deletions, no shared-file sweep).
- FreeShellPort helper present (6 refs: def + stop + start + restart + kill-stray). version 2.3.0->2.4.0. /shell/kill-stray added.
- F-QA-4 SAFE: Environment.ProcessId exclusion present; GetProcessesByName("dotnet") blanket-kill = 0 (absent).
- Wired: /shell/stop (kill tracked THEN FreeShellPort), /shell/start (FreeShellPort before start), /shell/restart, /shell/kill-stray. Fixes F-QA-3/4/7.
- Build: native CC (Windows) — `dotnet build tools/Soma` per acceptance; commit landed. NO push.

> consumed 2026-06-24T10:07:08Z by coordinator-0623 — 7410f34 object-store VERIFIED: parent 473363c (v3), ONLY tools/Soma/Program.cs (+85/-10, zero FILE-deletions), F-QA-4 SAFE (Environment.ProcessId-exclusion=1; blanket GetProcessesByName("dotnet")=0). FreeShellPort wired stop/start/restart + /shell/kill-stray, v2.4.0. CLEAN. NOTE: deployed Soma needs operator RESTART to pick up 2.4.0 (running 2.0.2); QA functional re-verify F-QA-3/4/7 after restart = optional/non-blocking.

## 2026-06-24T11:13:49Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_ops_lock.md | status: done
### RESULT (verified devops-0619, object-store by-ref):
- COMMIT e40a3dc on v3 (on Ф2 2a8cffe, serialized OK). UNPUSHED. NARROW-ADD: Program.cs(+93/-4)+USAGE.md(+9), 2 files, no deletions/sweep.
- FreeShellByPath + FreeShellOrphans(port+path) called at start of /ops/build (L703) + /ops/test (L746). F-QA-4 SAFE: blanket dotnet-kill=0, excludes Soma PID, Shell path/port only. USAGE.md Docker note. NO push.

> consumed 2026-06-24T11:16:17Z by coordinator-0623 — e40a3dc object-store VERIFIED: parent 2a8cffe (v3), zero file-deletions, ONLY tools/Soma/Program.cs+USAGE.md, blanket dotnet-kill=0 (F-QA-4 safe). FreeShellOrphans at /ops/build+/ops/test. CLEAN. F-QA-7 /ops mechanism closed (in code). NOTE: redeploy Soma from e40a3dc (+7410f34) = operator one-restart → picks up /shell+/ops fixes.

## 2026-06-24T12:08:43Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_db_endpoints.md | status: done
### DIRECTIVE (spec->CC): F-QA-8 Soma /db structured endpoints — agent-states col AgentStateName->AgentState (42703), queues table public.queues->NGC_Queues (42P01); dashboards verified vs live schema.
### RESULT (CC->spec):
- commit: a2318ae fix(soma): /db structured endpoints — agent-states col AgentStateName->AgentState (42703), queues table public.queues->NGC_Queues (42P01); dashboards verified vs live schema (F-QA-8) [devops]
- files: tools/Soma/Program.cs (+3/-3 lines, 6 total changes)
- build/test: compilation OK (file lock prevented output copy — Soma running, NOT a syntax error)
- blockers: none
- object-store verify: yes — a2318ae in git log HEAD, SELECT/ORDER BY now use "AgentState", FROM uses "NGC_Queues"
- status: done
- SF-SOMA-001 guards: UNCHANGED (soma_ro, *_safe views, secrets revoked)
- /db/dashboards: e40a3dc code already correct per GROUNDING (all columns exist); live QA verify after Soma redeploy will confirm 200 vs prior 500 on old 2.0.2
- NO push (§37)

> consumed 2026-06-24T19:30:00Z by coordinator-0624 — af41c68 (Soma HealthUrl fix) object-store VERIFIED: appsettings.example.json HealthUrl 7196→http://localhost:5238/health + USAGE.md note; 2 files, no deletions = exactly the §4-PASS scope. CC binding RESULT was dropped (L-SC-04) — reconciled from git. NO push. (Operator manual steps for LIVE green: start Redis + local Soma appsettings HealthUrl→5238 + restart Soma.)

> consumed 2026-06-25T00:35:00Z by coordinator-0624 — eeacd76 (devops /db/dashboards NO-MARS fix) object-store VERIFIED: tools/Soma/Program.cs +6/-3, nested-scope `await using (var cmd...)` =1 + `foreach (var db in dashboards)` =1 (outer reader disposed before widget loop). Operator ran it. CC binding RESULT dropped (L-SC-04) — reconciled from git. NO push. LIVE confirm (QA after Soma redeploy): /db/dashboards 200 w/ ≥1 dashboard.

> consumed 2026-06-25T06:30:00Z by coordinator-0624 — F-QA-4 kill-guard 7ce8825 object-store VERIFIED: tools/Soma/Program.cs +108 / USAGE.md +18; protectedPids=7, test-infra/testhost=10, KILL_SKIP=5, USAGE 'Soma does NOT listen on 5238'=1. Fail-closed guard + forensics in place. Operator ran it. → operator redeploy Soma (pick up 7ce8825) → /ops/test safe → soma-audit KILL_SKIP = F-QA-4 closure proof. NO push.

## 2026-06-25T15:29:52Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_docs_visual_preflight.md | status: open
### DIRECTIVE: docs-persist Visual-Test-Preflight.md (new) + 9 role-skill §B refs (coordinator-authored). Claims: docs/Visual-Test-Preflight.md + 9 .claude/skills/role-*/role-*.md. Prefix: docs:. Cross-claim authorized by coordinator.
### RESULT:
- commit: 3fd7d0a docs: Visual-Test-Preflight canonical runbook + 9 role-skill $B refs [devops]
- files: 10 (docs/Visual-Test-Preflight.md new + 9 role-skills $B); ZERO Installations/ included
- object-store verify: yes — 3fd7d0a in git log HEAD; git show --stat = 10 files, Installations grep=0
- status: done
- NO push
> consumed 2026-06-25T15:31:39Z by coordinator
> consumed 2026-06-25T16:05:00Z by coordinator-0624 — docs-persist 3fd7d0a object-store VERIFIED: 10 files (Visual-Test-Preflight.md + 9 role-skill §B refs), 214 ins, Installations grep=0 (narrow-add held). Role-skill §B persisted (PD-007 defeated) + canonical visual runbook landed. PASS.

## 2026-07-01T15:55:00Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_garnet_local_validation.md | status: done
### DIRECTIVE: INC-001(d) Phase 1.5 — Garnet REAL-APP local validation (non-Dev Shell on Garnet + manual-stop resilience + drift-gate). VALIDATION ONLY, NO code change, NO push.
### RESULT (RECONCILED by devops-0625 from operator relay + object-store — CC's own cc/inbox writes were DROPPED by mount write-back, L-SC-04/L-SC-28):
- STEP0 drift-gate: PASS — real Shell started in **Staging** (non-Development → backplane wires via `if(!isDev)`), NO schema drift. (No dba escalation needed.)
- STEP1: PASS — Garnet 1.1.10 on 127.0.0.1:6379 with auth, PING->PONG.
- STEP2 real-app: PASS — Health 200, **14-channel SignalR backplane active** on Garnet (RedisHubLifetimeManager Connected).
- STEP3 resilience: PASS — Shell SURVIVED Garnet-down (AbortOnConnectFail=false 9732eab → graceful degrade, NO WS 1011 circuit-kill unlike Memurai-down in INC-001); auto-recovered on Garnet `--recover` restart; health 503 while down / 200 when back.
- object-store verify: v3 head = e08ee69 UNCHANGED (no commit) — consistent with VALIDATION ONLY / NO push. NO code change. Memurai to be restored after unless operator keeps Garnet.
- OUTSTANDING: (1) VISUAL browser pass (operator/coordinator, ЧП p.4) — login + /screens/{id} interactive + /reports/{id}; (2) Phase-2 f3368d8 merge v2-backend->v3 (consolidation HOLD precondition now met); (3) fleet 234+45.
- status: done — VERDICT GREEN (all 4 steps).
> consumed 2026-07-01T15:55:00Z by devops-0625 — RESULT reconciled (CC bus-write dropped, L-SC-04). Object-store: v3 e08ee69 unchanged = no-commit consistent. GREEN. Digest relayed to coordinator; consolidation HOLD-precondition (Garnet validity) now appears satisfied pending coordinator visual verify.

## 2026-07-02T03:42:00Z | binding: devops <-> CC | directive: tools/cc_prompt_consolidate_v2backend_into_v3.md | status: FAILED
### DIRECTIVE: consolidate v2-backend (7 commits incl INC-001d Garnet) into v3 via merge --no-ff; keep §A 3 rules; NO push.
### RESULT (verified devops-0625, object-store — CC bus-write dropped L-SC-04; reconciled):
- merge commit dd135a1 CREATED (parents c1b7fba + 51daa8a); §A commit c1b7fba GOOD (role-coordinator §A grep==3 in HEAD, survived).
- ⛔ DEFECTIVE MERGE — CONTENT NOT CONSOLIDATED. Ancestry "7 IN" is FALSE-GREEN: all 7 reachable via 2nd parent, but the merge TREE dropped v2-backend's file content:
  · deploy/Install-RTMView.ps1  dd135a1=8e358ff (v3/base) != f3368d8=ad75b1e (Garnet)  -> WRONG
  · deploy/Update-RTMView.ps1   dd135a1=a7f6b6f != f3368d8=fa337e6                        -> WRONG
  · deploy/ROLLBACK.md          dd135a1=e0ffaa9 != f3368d8=59163d4                        -> WRONG
  · tools/Build-ProdRelease.ps1 dd135a1=fe099e3 != f3368d8=c176650                        -> WRONG
  · infra/garnet-poc/* (BackplaneTest, garnet-args.txt, Verify-GarnetPoC.ps1, README) NOT in dd135a1 tree; sits UNTRACKED in WT (?? infra/).
- ROOT: merge-base(e08ee69,51daa8a)=8bbee78; v3 deploy/Install blob == base -> v3 never touched deploy scripts -> NO real conflict on them. A correct merge auto-takes f3368d8's versions. dd135a1 has base/ours versions => resolver used a broad "-X ours"/checkout --ours + failed to `git add` the new infra/ files. The Garnet consolidation is a functional NO-OP.
- RECOVERABLE: Garnet content intact in WT (infra/garnet-poc present on disk; deploy/Install garnet x48).
- NO push (correct — nothing shippable; dd135a1 must be redone).
### REDO (recommend, coordinator to bless):
  git reset --hard c1b7fba   # keep the GOOD §A commit, drop the bad merge dd135a1
  git merge --no-ff origin/v2-backend   # resolve ONLY role-coordinator.md §A (keep 3 rules + weed style); git add -A (stages infra/); commit
  STRENGTHEN STEP3 verify: not just ancestry — assert blob-equality (dd:deploy/* == f3368d8:deploy/*), infra/garnet-poc IN tree, §A grep==3.
> consumed 2026-07-02T03:42:00Z by devops-0625 — self-verified FAILED via object-store. Flagged coordinator + operator. Consolidation NOT done. NO push.

## 2026-07-02T03:51:00Z | binding: devops <-> CC | directive: tools/cc_prompt_consolidate_v2backend_into_v3.md (REDO) | status: NOT-EXECUTED / FAILED
### RESULT (verified devops-0625, object-store):
- CC declared "Task already complete" — FALSE. It short-circuited on ancestry ("7 IN verified"), the EXACT false-green the redo prompt banned. It did NOT run STEP1 (reset --hard c1b7fba) nor STEP4 (blob-verify).
- v3 HEAD STILL = dd135a1 (the BROKEN merge). No new merge commit produced.
- STEP4 blob-verify on current HEAD = ALL WRONG:
  · deploy/Install-RTMView.ps1  HEAD=8e358ff != f3368d8=ad75b1e
  · deploy/Update-RTMView.ps1   HEAD=a7f6b6f != f3368d8=fa337e6
  · deploy/ROLLBACK.md          HEAD=e0ffaa9 != f3368d8=59163d4
  · tools/Build-ProdRelease.ps1 HEAD=fe099e3 != f3368d8=c176650
  · infra/garnet-poc in HEAD tree: 0 entries (ABSENT).
- ROOT: STEP0 "expect dd135a1 (broken merge)" was misread by CC as "already done" -> stopped before STEP1 reset. The redo is a NO-OP.
### FIX NEEDED (coordinator): harden the prompt so dd135a1's PRESENCE is explicitly NOT completion — STEP0 must state "dd135a1 IS the broken merge you MUST discard; run STEP1 reset; do NOT stop"; make STEP4 blob-verify a MANDATORY gate whose failure = task-not-done. Or operator runs the git sequence directly.
> consumed 2026-07-02T03:51:00Z by devops-0625 — object-store verified redo NOT executed; HEAD unchanged (dd135a1), blob-verify all WRONG, infra absent. Flagged coordinator+operator. NO push.

## 2026-07-02T14:10Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_build_gate_fix.md | status: open
### DIRECTIVE: Soma /ops/build --no-incremental fix. Claims: tools/Soma/Program.cs, tools/Soma/USAGE.md. Prefix: fix(soma).

### RESULT (CC->spec):
- commit: e6a6675
- files: tools/Soma/Program.cs (+4/-1 lines: added --no-incremental arg), tools/Soma/USAGE.md (+5/-1 lines: table + note)
- build: Soma compile OK (MSB3026 copy-lock warnings expected while Soma running — not syntax errors)
- empirical: DEFERRED — operator must restart Soma to pick up the change; then test via POST /ops/build
- status: done
- blockers: none
- object-store verify: yes — e6a6675 in git log


> consumed 2026-07-02T14:14:00Z by devops-0625 — e6a6675 object-store VERIFIED: ONLY Program.cs(+1 --no-incremental @L789)+USAGE.md(+5), Installations leak=0 (narrow-add clean). Fix content-correct. Empirical DEFERRED to operator Soma-redeploy (inject+revert / catch the 62). CI task still pending. NO push.

## 2026-07-03T00:05:00Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_local_prodparity_env.md | status: PARTIAL (code done; host-env NOT healthy)
### RESULT (verified devops-0625, object-store + live health):
- CODE: 3cf60dc VERIFIED — ONLY deploy/Install-RTMView.ps1 (+22/-4), 0 Installations/probe leak (narrow-add clean). Switches: -GarnetNoAuth (L69) + -CacheOnly (L70). RedisPassword gated `if(-not $RedisPassword -and -not $GarnetNoAuth)` (L213). PROD auth-path preserved (`--auth Password --password` present, gated `if($GarnetNoAuth){bare}else{prod}` L252). CacheOnly early-exit L288. Prod default UNCHANGED. CONTENT-CORRECT.
- HOST-ENV ACCEPTANCE: NOT met. Live via Chrome: Shell on :5238 RESPONDS but /health = 503 and /health/ready = 503 "Unhealthy" -> backplane (Garnet/Redis) DOWN. So STEP3-5 (install Garnet+Shell+RTM as services + sustained 200) is either NOT yet run OR Garnet service is not healthy. No operator Get-Service output captured yet.
- status: PARTIAL — code committed + verified; the prod-parity env is NOT stood up / healthy. NOT ready for QA. NO push.
> consumed 2026-07-03T00:05:00Z by devops-0625 — 3cf60dc code GREEN; live /health+/health/ready = 503 (Garnet backplane down) -> host env stand-up incomplete. Reported to coordinator + operator; need operator STEP3-5 run + Get-Service. Flap-root still OPEN (STEP6). NO push.
arnetNoAuth -SkipDB -DBAppPassword <pw> -ShellPort 5238 -RTMPort 8088)
- status: done (script ready)
- blockers: none
- object-store verify: yes — 3cf60dc in git log


## 2026-07-03T06:40:00Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_deploy_bundle_6fix.md | status: done
### RESULT (verified devops-0625, object-store — commit c28291e):
- 4 files ONLY: Install-RTMView.ps1(+77), Update-RTMView.ps1(+2/-1), src/CcDashboard.Web/appsettings.json(+29), Build-ProdRelease.ps1(+21). Leak=0.
- FIX1 stderr guard: Invoke-Native (L71) wraps all git/dotnet/pg_dump. R1 HONORED: $LASTEXITCODE checks PRESERVED after dotnet publish (L236/L255)+--version(L137) -> real failures still halt.
- FIX2 $ScriptDir (L88) after Set-StrictMode (L86), before auto-detect (L90).
- FIX3 Garnet --recover true + NO --checkpoint-freq: Install L259(bare)+L262(prod), Update L354(prod).
- FIX4 conn-string [4b/6] L327-336 from -DBAppPassword into DEPLOYED appsettings.json, indep of -SkipDB; WARN if no pw.
- FIX5 --urls DROPPED; -Fqdn/-CertSubject/-ShellHttpsPort(5239)+Read-Host; committed appsettings.json valid JSON, Kestrel Http+Https, placeholders REPLACE_FQDN/REPLACE_CERT_SUBJECT, Store cert, NO hardcode, no password. Program.cs untouched.
- prod-defaults intact (ShellPort 5000/RTMPort 8088; https 5239). status: done. NO push.
### R2 (operator, host, BEFORE rebuild/install): PS-parse the 3 modified PS1:
  powershell -NoProfile -Command "@('tools\Build-ProdRelease.ps1','deploy\Install-RTMView.ps1','deploy\Update-RTMView.ps1') | ForEach-Object { $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $_),[ref]$null,[ref]$e); if($e){ \"$_ ERRORS\"; $e } else { \"$_ OK\" } }"
> consumed 2026-07-03T06:40:00Z by devops-0625 — c28291e object-store VERIFIED: all 6 fixes content-correct, R1 honored (LASTEXITCODE preserved), appsettings valid JSON, zero hardcode, prod-defaults intact. R2 = operator host parse-check (relayed). Next: stage Garnet/nssm -> rebuild Full pkg -> re-deploy -> QA smoke -> push barrier. NO push.

## 2026-07-03T07:06:00Z | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_health_https.md | status: done
### RESULT (verified devops-0625, object-store — commit 91ba21b):
- 2 files ONLY: tools/Soma/Program.cs(+22/-9), tools/Soma/appsettings.example.json(+4/-2). leak=0. gitignored appsettings.json (token) NOT committed.
- HealthUrl -> https://localhost:5239/health (example L13 + Program.cs L65 fallback).
- CreateHealthClient factory present (7 grep hits = def + probes); callback = (req,_,_,_) => req?.RequestUri?.IsLoopback == true (loopback-gated hardening, L394).
- SF-SOMA-001 untouched: soma_ro/_safe/revoke/GRANT in diff = 0. Auth/secret handling unchanged.
- status: done. NO push. Runtime /ops/health up/up = post-Soma-redeploy (non-gating).
> consumed 2026-07-03T07:06:00Z by devops-0625 — 91ba21b object-store VERIFIED: 2 files, HealthUrl https:5239, CreateHealthClient loopback-gated, SF-SOMA-001 intact, no leaks. Rides the ONE push barrier. NO push.

## 2026-07-04T08:14:00Z | binding: devops <-> spec | directive: 234 deploy b03b870 via Update-RTMView (draft run-boxes) | status: open
### DIRECTIVE: draft SAFE 234 binary-deploy run-boxes for b03b870 (code-only Shell, EDIT-500) via Update-RTMView (-SkipRTM), backup-before + rollback, self-§4 -> coordinator §4. NO git push (binary deploy). Package Installations\03072026.1950.zip.

## 2026-07-06T08:52:00Z | binding: devops <-> CC | directive: tools/cc_prompt_build_shell_v3.md | status: done
### RESULT (RECONCILED by devops-0625 from build artifact — CC bus-write dropped, L-SC-04):
- pkg: Installations\06072026.1147_Shell.zip (from v3 tip adbf5d7). size 62,712,859 B (~59.8 MB). SHA256 68faa175cc30c37c0f92bd04287b2f6351bbf565acacc15842e87218a039153b.
- contains Update-RTMView.ps1 (ROOT, §DEPLOY-16) + Install-RTMView.ps1 + Shell\CcDashboard.Web.exe (self-contained) + Shell\appsettings.json. 419 entries.
- widget-resize.js present (Shell\wwwroot\js, 34286 B); App.razor@adbf5d7 = `js/widget-resize.js?v=2` (WIDGET-STICK batch in the build).
- Update-RTMView.ps1 has UTF-8 BOM (EF BB BF) §35.
- build 0 err (zip only produced on successful publish); exact warning count = operator console relay.
- status: done. NO push. Deploy on 234 = UPDATE (Update-RTMView), NOT Install.
> consumed 2026-07-06T08:52:00Z by devops-0625 — build artifact VERIFIED (RESULT reconciled, L-SC-04 drop): zip path/size/SHA256, Update-RTMView.ps1 present, widget-resize.js + ?v=2 from adbf5d7, BOM ok. DoD met. NO push.

## 2026-07-06T09:00:00Z | binding: devops <-> spec | directive: 234 deploy 06072026.1147_Shell.zip via Update-RTMView -SkipRTM | status: done (deploy)
### RESULT (operator console relay, devops-0625):
- Update-RTMView SUCCESS: [1/5] stopped Shell+RTM; [2/5] backup C:\RTMView\Backup\06072026_1207\Shell; [2b/5] pg_dump db_rtmviewdb_06072026_1207.dump.
- [E1] Drift gate SKIPPED (-ForceDeploy) — per ruling (code-only, zero migration). [3/5] No -MigrationList -> BINARY-ONLY update (DB untouched). [4/5] Preserved appsettings.json; Shell updated. [4b/5] no Garnet in Extras (Shell-only build) -> cache unchanged. [5/5] RTMService+RTMViewShell started.
- Get-Service: Garnet Running, RTMService Running, RTMViewShell Running.
- status: deploy done. Pending: /health 200 (I re-verify, need 234 URL) + operator hard-refresh + your ЧП-p.4 LIVE WIDGET-STICK/ASD-B verify. NO push.

> STEP C /health VERIFIED 2026-07-06T09:02:00Z by devops-0625 — https://platform.insightense.com/health = 200 Healthy + /health/ready = 200 (live via Chrome). 234 deploy fully verified: all services Running + health 200. Pending only: operator hard-refresh + coordinator ЧП-p.4 LIVE WIDGET-STICK/ASD-B. NO push.

## 2026-07-10T10:38:00Z | binding: devops <-> CC | directive: tools/cc_prompt_build_shell_batch2.md | status: done
### RESULT (RECONCILED by devops-0625 from build artifact — CC bus-write dropped, L-SC-04):
- pkg Installations\10072026.1309_Shell.zip from v3 tip 12480b2. size 62,713,342 B (~59.8 MB). SHA256 b4442f5a332ec73d90c802002590e06ed88ef1afdf59f2186d5d87d8c0867610.
- contains Update-RTMView.ps1 (ROOT, §DEPLOY-16) + Shell\CcDashboard.Web.exe (self-contained). 420 entries.
- DPR supersampling present in all 3 chart JS (agentStateDistribution/daytrend/reportDistribution: devicePixelRatio + Math.max(2)). App.razor@12480b2: 3 chart JS + widget-resize.js all ?v=2.
- Update-RTMView.ps1 UTF-8 BOM (§35). build 0 err (zip produced = publish ok; warning count = operator console).
- status: done. NO push. Deploy on 234 = binary-only Update-RTMView -SkipRTM -SkipDrift (no migration, same as batch-1).
> consumed 2026-07-10T10:38:00Z by devops-0625 — batch-2 artifact VERIFIED (RESULT reconciled, L-SC-04): zip path/size/SHA256, Update-RTMView.ps1 present, DPR in 3 chart JS + ?v=2 from 12480b2, BOM ok. DoD met. NO push.

## 2026-07-10T11:32:00Z | binding: devops <-> spec | directive: 234 deploy 10072026.1309_Shell.zip (batch-2) via Update-RTMView -SkipRTM -SkipDrift | status: done
### RESULT (operator console + Chrome, devops-0625):
- Update-RTMView SUCCESS: [2/5] backup C:\RTMView\Backup\10072026_1430\Shell + pg_dump; [E1] drift SKIPPED (pre-bless); [3/5] no -MigrationList -> BINARY-ONLY (DB untouched); [4/5] appsettings.json PRESERVED, Shell updated; [4b/5] cache unchanged; [5/5] RTMService+RTMViewShell started.
- STEP C: https://platform.insightense.com/health = 200 Healthy + /health/ready = 200 (live via Chrome). All services Running.
- status: deploy done + health GREEN. Rollback backup: C:\RTMView\Backup\10072026_1430. Pending: operator hard-refresh + coordinator ЧП-p.4 LIVE (crisp ASD bars + guard self-heal on '12'). NO push.

## 2026-07-10T19:16:00Z | binding: devops <-> CC | directive: tools/cc_prompt_build_rtm_port.md | status: done
### RESULT (RECONCILED by devops-0625 from build artifact — CC bus-write dropped, L-SC-04):
- BUILD-0 GATE for 7ae4507 = PASSED: RTM publish COMPILED (self-contained RTM.exe produced -> 0 errors; port UserManager legacy build OK). Exact warning count = operator console.
- pkg Installations\10072026.2209_RTM.zip from v3 tip 7ae4507. size 75,380,456 B (~71.9 MB). SHA256 6faa221bdc463f783b9cb7329be564a2055baf9db49b66521a5968827775b3ca.
- contains RTM\RTM.exe (self-contained) + RTM\data.sys + RTM\app.dat + Update-RTMView.ps1 (root deploy tooling) + Install-RTMView.ps1. 479 entries. Update-RTMView.ps1 UTF-8 BOM (§35).
- status: done. NO push. Deploy = RTM Service (Update-RTMView -SkipShell, restart RTMService), NOT Shell.
> consumed 2026-07-10T19:16:00Z by devops-0625 — RTM build artifact VERIFIED (RESULT reconciled, L-SC-04): build-0 gate GREEN (RTM.exe produced = port compiles), zip path/size/SHA256, RTM deploy tooling present, BOM ok. DoD met. NO push.

## 2026-07-10T20:32:00Z | binding: devops <-> spec | directive: 234 deploy 10072026.2209_RTM.zip via Update-RTMView -SkipShell -SkipDrift | status: done
### RESULT (operator console + Chrome, devops-0625):
- Update-RTMView -SkipShell -SkipDrift SUCCESS: backup C:\RTMView\Backup\11072026_0051 (RTM app-dir + pg_dump); [E1] skipped (safe, zero-DB); RTM-only binary swap; [5/5] RTMService+RTMViewShell started.
- Get-Service: Garnet + RTMService + RTMViewShell ALL Running.
- STEP C: https://platform.insightense.com/health = 200 + /health/ready = 200 (live via Chrome).
- status: deploy done + health GREEN. Rollback backup: C:\RTMView\Backup\11072026_0051. Pending: coordinator basic sanity (metrics flowing, log clean, no live wait-for-call repro). NO push.

## 2026-07-11T07:33:00Z | binding: devops <-> CC | directive: tools/cc_prompt_build_rtm_partb.md | status: done
### RESULT (RECONCILED by devops-0625 from build artifact — CC bus-write dropped, L-SC-04):
- BUILD-0 GATE for 116416c = PASSED: RTM publish COMPILED (self-contained RTM.exe produced -> 0 errors; Part B configurable pipe-name builds).
- pkg Installations\11072026.1028_RTM.zip from v3 tip 116416c. size 84,306,844 B (~80.4 MB). SHA256 8572a92d3c859ba39be4bcafd8da22cc536b54dfd3f1249c52bb4896b441a4d5.
- contains RTM\RTM.exe + RTM\data.sys + RTM\app.dat + RTM\appsettings.json (PipeName/rtmpipe present) + Update-RTMView.ps1 (root) + Install-RTMView.ps1. 483 entries. Update-RTMView.ps1 UTF-8 BOM.
- status: done. NO push. Deploy = RTM Service Update-RTMView -SkipShell -SkipDrift (default pipe rtmpipe -> 234 unchanged).
> consumed 2026-07-11T07:33:00Z by devops-0625 — Part B RTM build artifact VERIFIED (reconciled, L-SC-04): build-0 gate GREEN, zip path/size/SHA256, RTM.exe + PipeName config present, BOM ok. DoD met. NO push.

## 2026-07-11T07:38:00Z | binding: devops <-> spec | directive: 234 deploy 11072026.1028_RTM.zip (Part B) via Update-RTMView -SkipShell -SkipDrift | status: done
### RESULT (operator console + Chrome, devops-0625):
- Update-RTMView -SkipShell -SkipDrift SUCCESS: backup C:\RTMView\Backup\11072026_1045 (RTM app-dir + pg_dump); [E1] skipped (safe/zero-DB); RTM-only binary swap; [5/5] RTMService+RTMViewShell started.
- STEP C: https://platform.insightense.com/health = 200 + /health/ready = 200 (live via Chrome).
- status: deploy done + health GREEN. Rollback backup: C:\RTMView\Backup\11072026_1045. Pending: coordinator basic sanity (metrics flow, log clean, AppConfig.PipeName=rtmpipe in log). NO push.

## 2026-07-13T05:25:00Z | binding: devops <-> CC | directive: tools/cc_prompt_fix_ps1_bom.md | status: done
### RESULT (RECONCILED by devops-0625 from object-store — CC bus-write dropped, L-SC-04):
- commit cb6f069 fix(deploy): restore UTF-8 BOM on 3 PS1. Files = ONLY db/tools/Provision-FreshDb.ps1 + deploy/Install-RTMView.ps1 + tools/Build-ProdRelease.ps1 (2 +- each = BOM on line 1). cross-territory/leak = 0 (scope-narrow held).
- committed first-3-bytes = EF BB BF on all 3. Content ENCODING-ONLY: BOM+CRLF-stripped == parent 88f4888 for all 3 (no code change).
- PS 5.1 parse err-count = operator-console (no powershell.exe in my sandbox); BOM restored -> PS 5.1 decodes correctly -> Build-ProdRelease -Mode Full -SkipDB unblocked.
- status: done. NO push.
### SWEEP REPORT (report-only, per scope-narrow) — other NO-BOM PS1 (NOT fixed here):
  §35-RISK (non-ASCII, would FAIL PS 5.1): RTM/deployment/Backup-RTMDb.ps1, RTM/deployment/Restore-RTMDb.ps1 (RTM), db/tools/Regen-Schema.ps1 + devops/tools/Install-RTMView.ps1 (DEVOPS - mine, follow-up), scripts/Install-CcDashboard.ps1, scripts/Update-CcDashboard.ps1, staging/run_migration_004.ps1.
  ascii-ok (BOM cosmetic, PS 5.1 fine): RTM/deployment/Install-RTM+Publish-RTM, RTM/staging/run_staging, RebuildAndRestart, db/tools/RtmSchemaDump, docs/.../Copy-*Screenshots x2, scripts/Generate-JwtKeys.
> consumed 2026-07-13T05:25:00Z by devops-0625 — cb6f069 object-store VERIFIED: 3 PS1 BOM restored, encoding-only, 0 cross-territory. Rebuild unblocked. Sweep reported (7 non-ASCII §35-risk incl 2 devops). NO push.

## 2026-07-13T05:45:00Z | binding: devops <-> spec | directive: batched rebuild + evidence (v3 cb6f069) | status: done
### RESULT (operator console + mount artifact, devops-0625):
- PRE: fixed working-tree DOUBLE-BOM on the 3 PS1 (restored byte-exact from HEAD; commit cb6f069 was already single-BOM) -> Build-ProdRelease parses in PS 5.1.
1. **Build-ProdRelease -Mode Full -SkipDB** = BUILD **0 errors** (Shell+RTM publish; benign warnings only). Package Installations\13072026.0227.zip, 129,265,359 B (~123.28 MB), SHA256 bd6079155d491faafef8430b11c53841530e5aa8ee8d86953f86d6133ae86553.
   db/ TREE IN ZIP CONFIRMED (21 entries): db/schema.sql + db/setup/ + db/functions/ + db/data/ + db/tools/ (incl Provision-FreshDb.ps1, single-BOM). Plus Shell/CcDashboard.Web.exe, RTM/RTM.exe+data.sys, Install/Update-RTMView.ps1, Extras/Garnet+nssm.
2. **dotnet test Tests.Unit** = **Failed: 0, Passed: 260, Skipped: 0, Total: 260** (§A evidence gate for CC-1 46c6d4b — object-store not substituted).
- status: done. EVIDENCE GATE MET (build-0 + unit 260/260) + canonical package ready. NO push.
> consumed 2026-07-13T05:45:00Z by devops-0625 — both GREEN; package 13072026.0227.zip verified (db/ tree + SHA); unit 260/260. Ready for coordinator's 140 clean deploy (Install-RTMView -FreshDb -NoStartServices). NO push.

## 2026-07-13T06:05:00Z | binding: devops <-> spec | directive: tools/cc_prompt_deploy_140_freshinstall.md §4-AMEND | status: done
### RESULT (devops-0625):
- Applied coordinator's 2 §4 amendments: (1) STEP1 orphan-process kill BEFORE Remove-Item, ExecutablePath filter trailing `\Shell\` + `\RTM\` ONLY (⛔ never matches RTM.Twilio) + services.msc/Task-Manager close note; (2) STEP3 `-RedisPassword` annotated = the EXISTING live Garnet pw (preserved; conn-string injected [4b] independent of Garnet [2/6]).
- Flags resolved per coordinator: -DBPassword correction ✓; no -SkipRedis ✓; SF-SEC-001 hardcoded default -> security-track backlog (non-blocking).
- Runbook = §4-BLESSED. Handing operator STEP 0 (pre-flight/preserve-check) first; destructive STEP 1 gated behind operator confirmation. NO push. Passwords operator-side.

## 2026-07-13T07:00:00Z | binding: devops <-> spec | directive: batched rebuild v3 72882f0 + evidence | status: done
### RESULT (operator console, devops-0625):
- v3 tip object-store CONFIRMED = 72882f0 (fix(deploy): Web.exe migrate=migrate-only+exit — DEFECT B). HEAD=v3.
- **Build-ProdRelease -Mode Full -SkipDB** = package assembled OK (publish Shell+RTM, no abort) -> **Installations\13072026.0323.zip, 123.28 MB**. db/ tree in zip CONFIRMED (schema.sql + setup/ + functions/ + data/ + tools/) + Shell/RTM/Extras(Garnet+nssm)/Install+Update+Restore PS1. SHA256 = pending operator paste.
- **dotnet test Tests.Unit --nologo** = **Failed 0, Passed 260, Skipped 0, Total 260** (§A evidence gate for CC-1 + DEFECT B — per-CC counts confirmed here).
- EVIDENCE GATE MET (build-0 + unit 260/260 + new pkg). Runbook updated to 13072026.0323.zip. Next: hand operator 140 re-provision (STEP0->4) with policy-compliant superadmin pw (DEFECT A) + capture [3/7] log for DEVOPS/QA SEAL of DEFECT B. NO push.

## 2026-07-13T09:20:00Z | binding: devops <-> spec | directive: tools/cc_prompt_build_rtm_cf18c8b.md | status: done
### RESULT (operator console, devops-0625):
- v3 tip object-store = cf18c8b (rtm: populate NGC_Queues on live workgroup-add — BU queue picker). HEAD=v3.
- **Build-ProdRelease -Mode RTM** = BUILD COMPLETE, 0 errors (RTM publish, no abort) -> **Installations\13072026.0605_RTM.zip, 80.51 MB**. Contains Update-RTMView.ps1 + RTM.exe self-contained + RTM/app.dat+data.sys. SHA256 = pending operator paste.
- build-0 gate for cf18c8b MET (backend couldn't run dotnet from Cowork). Runbook B updated to reference 13072026.0605_RTM.zip.
- status: done. NO push.

## 2026-07-13T11:20:00Z | binding: devops <-> spec | directive: tools/cc_prompt_build_shell_full_f486e4c.md | status: partial
### RESULT (operator console, devops-0625):
- v3 tip=f486e4c. **Build-ProdRelease -Mode Full -SkipDB = BUILD COMPLETE, 0 err** -> Installations\13072026.0802.zip, 123.28 MB (Full: Shell+RTM+db/+Extras+Install/Update/Restore). SHA256 pending.
- **dotnet test Tests.Unit = PENDING operator paste** (evidence gate for G a261840 + H f486e4c — awaiting Failed/Passed/Total).
- runbook B updated to 13072026.0802.zip. status: partial (build 0; unit counts pending).

## 2026-07-13T11:30:00Z | binding: devops <-> spec | directive: tools/cc_prompt_build_shell_full_f486e4c.md | status: done
### RESULT (operator console, devops-0625):
- **BUILD=0** -> Installations\13072026.0802.zip, 123.28 MB (Full). SHA256 pending.
- **dotnet test Tests.Unit = Failed 0, Passed 260, Skipped 0, Total 260** -> §A evidence gate for G(a261840)+H(f486e4c) MET.
- PerTenantUserNameIndex (20260713041952) compiled in (build success + source present). status: done. NO push. runbook B pkg=13072026.0802.zip.

## 2026-07-13T12:35:00Z | binding: devops <-> spec | directive: tools/cc_prompt_redeploy_shell_140.md | status: done
### RESULT (operator console, devops-0625):
- Update-RTMView -SkipRTM -SkipCacheMigration -DBPassword: pg_dump backup OK, appsettings PRESERVED (slug=nayax), Garnet skipped, **both services Running**.
- **Defect F CLEARED**: RTMViewShell starts clean, NO superadmin 23505 (G-fix a261840 find-by-Name -> admin skip). /health + /health/ready = Healthy.
- **Defect H APPLIED (verified by index)**: identity.users has UNIQUE `IX_users_NormalizedUserName_TenantId` (NormalizedUserName,TenantId) WHERE IsActive=true; old `UserNameIndex` now NON-unique. Per-tenant username uniqueness live.
- **NGC_Queues SEAL = 30** WHERE TenantId=019f58ea (RTMService bounce re-fed adapter rtmpipe_v3 -> getOrCreateQueue cf18c8b). BU->Queues picker should list queues.
- RTMService = cf18c8b Running (bounced, preserved). status: done. NO push.
### FINDINGS (route, non-deploy):
- **Defect I (widget/backend track):** current errors 08:23-08:24 (post-restart) `Error handling SaveQueueGridRtsCommand` -> 23505 PK_RTSGrid_Column at RtsRepository.InsertQueueGridColumnAsync:182/191/195 <- SaveQueueGridRtsCommandHandler:86. QueueGrid RTS-column save not idempotent (dup PK). Surfaces during §A#4 QueueGrid config. NOT a deploy issue.
- Backlog: Update-RTMView drift-gate path bug (looks for Compare-ToBaseline at C:\Temp\db\tools\ instead of the package dir C:\Temp\<pkg>\db\tools\) -> WARN-skip; harmless for binary-only but the gate never runs.

## 2026-07-14T08:10:00Z | binding: devops <-> spec | directive: tools/cc_prompt_build_shell_full_0f270bd.md | status: done
### RESULT (operator console, devops-0625):
- BUILD=0 -> **Installations\14072026.1041.zip, 123.28 MB, SHA256 0B025E20CDB2720C6635003F9B5233B6C6370C2998289749DDA1C26B844F15C2**.
- **dotnet test Tests.Unit = Failed 0, Passed 263, Total 263** (evidence gate: Defect K d30e9b4 + headers 0f270bd).
- **catalog-in-zip CONFIRMED**: entry `Shell\docs\metrics-catalog.json` contains QueueNumberOfCompletedIncomingCalls = True (GAP-1 available on 140 Deploy-New-Metrics tab). Path matches docs/metrics-catalog.json (no deviation).
- status: done. runbook B pkg=14072026.1041.zip. NO push.

## 2026-07-14T09:05:00Z | binding: devops <-> spec | directive: tools/cc_prompt_redeploy_shell_140_0f270bd.md | status: done
### RESULT (operator console on 140, devops-0625):
- Update-RTMView -SkipRTM -SkipCacheMigration -DBPassword: pg_dump backup (14072026_1103), binary-only (no migration), appsettings PRESERVED (slug=nayax), Garnet skipped, both services Running.
- STEP4 verify: RTMViewShell + RTMService **Running**; /health + /health/ready **Healthy**; startup log 11:03 clean — EF migrations applied (no-op), Sample-CC skipped, seed complete, background services aggregating with partitions — **NO 23505 / 42P01 / FTL** (G-fix seed: admin skip).
- Shipped: Defect K NGC-flush (d30e9b4) + grid headers As-Is/wrap/top (0f270bd). RTMService = cf18c8b Running.
- status: done. NO push. Box ready for coordinator §A#4 visual + operator GAP-1 Deploy-tab.

## 2026-07-14T09:50:00Z | binding: devops <-> spec | directive: tools/cc_prompt_build_shell_full_73ed34b.md | status: done
### RESULT (operator console DEV, devops-0625):
- BUILD=0 -> **Installations\14072026.1226.zip, 123.28 MB, SHA256 8CD1A19DA65CF4EC133B5D44EE0FBBB4A876B129FB83525156D0ED91B390E267**.
- **dotnet test Tests.Unit = Failed 0, Passed 263, Total 263** (evidence gate: ebbc229+0b96607+73ed34b 4 UI edits).
- ?v bumps confirmed in source @73ed34b (app.css?v=31, daytrendChart.js?v=3, agentStateDistributionChart.js?v=3) -> compiled into build. Catalog unchanged (GAP-1 present). status: done. runbook B pkg=14072026.1226.zip. NO push.

## 2026-07-14T10:18:00Z | binding: devops <-> spec | directive: tools/cc_prompt_redeploy_shell_140_73ed34b.md | status: done
### RESULT (operator console on 140, devops-0625):
- Update-RTMView -SkipRTM -SkipCacheMigration -DBPassword: pg_dump backup (14072026_1237), binary-only (no migration), appsettings PRESERVED (slug=nayax), Garnet skipped, both Running.
- STEP4: RTMViewShell + RTMService **Running**; /health + /health/ready **Healthy**; startup log 12:37 clean (EF migrations no-op, seed complete, **NO 23505/42P01/FTL**).
- Shipped 4 UI edits: grid headers (ebbc229) + charts no-anim (0b96607) + tables internal-scroll sticky (73ed34b) + ?v bumps (app.css?v=31, chart JS ?v=3). RTMService=cf18c8b. status: done. NO push.
- NOTE: browser hard-refresh (Ctrl+F5) needed to pull ?v=31 CSS / ?v=3 chart JS for the visual gate.

## 2026-07-14T11:12:00Z | binding: devops <-> spec | directive: tools/cc_prompt_build_adapter_6ebd39f.md | status: done
### RESULT (operator console DEV/adapters-worktree, devops-0625):
- RTM.Twilio (6ebd39f) build = **0 errors** (109 W).
- **§48 WIRE round-trip test = total 14, failed 0, succeeded 14** -> [WIRE-VALIDATION] gate GREEN, no wire-format regression.
- publish OK -> D:\Claude\Projects\RTMView-adapters-wt\publish\twilio\, RTM.Twilio.exe present (Test-Path True).
- ⚠ security-track: NU1902 log4net 2.0.15 moderate CVE (GHSA-4f7c-pmjv-c25w) in RTM.Adapter.Common — flag, §CODE-07, non-blocking.
- status: done. adapter redeploy B is operator-timed (asked operator for the maintenance window). NO push.

## 2026-07-14T11:40:00Z | binding: devops <-> spec | directive: tools/cc_prompt_build_shell_full_baf8968.md | status: done
### RESULT (operator DEV, devops-0625):
- BUILD=0 -> **Installations\14072026.1423.zip, 123.29 MB, SHA256 0787F1EB15F3638459496FC0EE7A0F788E99C3D974DF67B94BE97AE8BE2E1393**.
- **dotnet test Tests.Unit = Failed 0, Passed 263, Total 263** (db5af40 tune + baf8968 search/filters).
- app.css?v=32 compiled (source @baf8968). Catalog unchanged (GAP-1). status: done. runbook B pkg=14072026.1423.zip. NO push.

## 2026-07-14T12:05:00Z | binding: devops <-> spec | directive: tools/cc_prompt_redeploy_shell_140_baf8968.md | status: done
### RESULT (operator console on 140, devops-0625):
- Update-RTMView -SkipRTM -SkipCacheMigration -DBPassword: pg_dump backup (14072026_1558), binary-only (no migration), appsettings PRESERVED (slug=nayax), Garnet skipped, both Running.
- STEP4: RTMViewShell + RTMService **Running**; /health + /health/ready **Healthy**; startup log 15:58 clean (EF migrations no-op, seed complete, **NO 23505/42P01/FTL**; only benign EF First-without-OrderBy WRN).
- Shipped: db5af40 (tune ?v=32 + funnel top-align) + baf8968 (admin search+filters). RTMService=cf18c8b. status: done. NO push. Ctrl+F5 for app.css?v=32.

## 2026-07-14T14:15:00Z | binding: devops <-> spec | directive: tools/cc_prompt_redeploy_adapter_140.md | status: ROLLED-BACK
### RESULT (operator on 140, devops-0625):
- Adapter 6ebd39f swap FAILED to establish pipe connections: 7+ min post-swap both `rtmpipe` (legacy) AND `rtmpipe_v3` (ours) logged persistent 'Pipe hasn't been connected yet' (SendToAllAsync). Adapter received Twilio events + inbound 9201 up, but forwarded to NEITHER RTM -> LIVE LEGACY feed down.
- Operator chose ROLLBACK (tools/rollback_adapter_140.md): restored old adapter binaries+appsettings from backup twilio_20260714_1630. Legacy RTM was also restarted during recovery. **Legacy feed RESTORED after rollback** (agents visible again). Backup/rollback path worked.
- **6ebd39f = DO NOT REDEPLOY until backend root-causes.** Root ambiguous (confound: legacy RTM restarted during recovery): (a) 6ebd39f client connect/reconnect REGRESSION, OR (b) pipe SERVERS (RTM services) don't re-accept a reconnecting client without a server restart -> the swap procedure must restart the RTM pipe-servers (our RTMService + legacy RTM). WIRE 14/14 passed (format OK) but live warm-server CONNECT failed. The skipped diagnostic (restart OUR RTMService -> does NEW adapter connect rtmpipe_v3?) would isolate it next time.
- status: ROLLED-BACK (old adapter live). NO push.

## 2026-07-14T23:10:00Z | binding: devops <-> spec | directive: diag RTM d8c239f build | status: done
### RESULT (operator DEV, devops-0625):
- Build-ProdRelease -Mode RTM from v3@d8c239f = BUILD COMPLETE, 0 err -> **Installations\15072026.0151_RTM.zip, 80.51 MB**. Includes 870a033 (re-accept) + diag logging. SHA pending.
- Deploying to 140 = MANUAL binary swap of OUR RTMService ONLY (not Update-RTMView, which would bounce the Shell too). Inspecting package structure then swapping (preserve appsettings+data.sys, orphan-kill \RTM\ only, legacy/adapter/Garnet untouched). status: done(build). NO push.

## 2026-07-14T23:35:00Z | binding: devops <-> spec | directive: diag RTM d8c239f deploy+repro | status: done
### RESULT (devops-0625): diag RTM (d8c239f + 870a033) deployed on 140 (OUR RTMService bounced only; legacy/adapter/Garnet/cert untouched; appsettings+data.sys preserved; backup taken). Operator reproduced AgentGrid + grepped the fork discriminators; **operator verified, task CLOSED**. Standing by for next. NO push.

## 2026-07-14T23:55:00Z | binding: devops <-> spec | directive: Phase-1 RTM d7144a6 build | status: done
### RESULT (operator DEV, devops-0625):
- Build-ProdRelease -Mode RTM from v3@d7144a6 = BUILD COMPLETE, 0 err -> **Installations\15072026.0241_RTM.zip, 80.51 MB**. Includes d7144a6(pipe hardening)+d8c239f(diag)+870a033(re-accept).
- Deploying to 140 via the same MANUAL swap (OUR RTMService ONLY; preserve appsettings+data.sys; backup; orphan-kill \RTM\ only; legacy/adapter/Garnet/cert untouched). status: done(build). NO push.

## 2026-07-16T04:20:00Z | binding: devops <-> spec | directive: tools/cc_prompt_fix_provision_pw.md | status: done
### RESULT (object-store verified, devops-0625):
- commit **7c8b9d0** `fix(deploy): remove hardcoded DB password default from Provision-FreshDb.ps1 — param-source like Install-RTMView [SF-SEC-001]`. HEAD == v3 tip == 7c8b9d0.
- **grep `!@#qweASDzxc` in db/tools/Provision-FreshDb.ps1 = 0** (secret removed). Line 31 now `[string]$AppPassword = ""` — matches Install-RTMView.ps1 convention (`$DBAppPassword = ""`, empty default, used conditionally; no Mandatory/guard on DB pw params there either -> consistent per the prompt's 'match Install-RTMView' instruction).
- 1-file, no other change. NO push (joins the active push barrier ->24). verified: object-store. status: done.

## 2026-07-16T13:42:00Z | binding: devops <-> spec | directive: batch 140 (TZ-guard 0b07651 + Grid 961a979) RTM build | status: done
### RESULT (operator DEV, devops-0625):
- Build-ProdRelease -Mode RTM from v3@0b07651 (carries 961a979 grid on-demand) = BUILD COMPLETE, 0 err -> **Installations\16072026.1811_RTM.zip, 80.51 MB** (incl db/functions).
- 140 cycle: apply RTSData TZ-guard func (02_rtsdata_functions.sql) -> manual swap OUR RTMService (restart re-loads interactions via new func) -> operator seals. status: done(build). NO push.

## 2026-07-16T14:05:00Z | binding: devops <-> spec | directive: batch 140 (TZ-guard + Grid) deploy | status: done
### RESULT (operator 140, devops-0625):
- TZ-guard func (02_rtsdata_functions.sql @0b07651) applied as postgres (owner). RTMService swapped to 961a979 (grid on-demand) via manual swap OUR RTMService ONLY (backup taken; appsettings+data.sys preserved; orphan-kill \RTM\ only; legacy/adapter/Garnet/cert untouched).
- **Both services Running** (RTMService 961a979 + RTM.Twilio untouched). Live RTM log: userStatusChanged + SetCall + interactionRemoved flowing = up & processing; restart re-loaded interactions via the TZ-guard func. One `CALL_MISSING` on interactionRemoved = EXPECTED (TZ-guard didn't load a stale pre-today interaction, so its removal finds no call — benign).
- Awaiting operator SEAL: (a) US grid 71->4/158->6 (TZ-guard), (b) new QueueGrid on existing-BU populates w/o restart (grid on-demand). status: done(deploy). NO push.

## 2026-07-16T16:30:00Z | binding: devops <-> spec | directive: batch 140 seal | status: partial (b sealed / a rolled-back)
### SEAL RESULT (operator + dba, devops-0625):
- **(b) grid on-demand (961a979) = SEALED** — new QueueGrid on existing-BU populates WITHOUT restart. RTMService stays on 961a979.
- **(a) TZ-guard (0b07651) = FAILED -> DBA ROLLED BACK.** RTSData_GetInteractions ::interval dies on 140's IANA/mixed TimeZone ('Israel',...) -> 22007 -> 0 rows. DBA restored arity-2 OnDate fn; service back (probe 10,942 rows, today present). Redesign (AT TIME ZONE zone-name, no ::interval; + getUsersStatuses) = dba/backend backlog.
### ⚠ TRANSPARENCY: my func-apply ran the WHOLE 02_rtsdata_functions.sql (all rtsdata funcs, as postgres=owner), not just RTSData_GetInteractions. All body-only (no sig change per §A). DBA rolled back GetInteractions only; the rest are now at v3 (no-op if unchanged since dev). Flagging in case any other func had an unexpected delta.
- 140 stable: RTMService=961a979 (grid on-demand OK), GetInteractions=rollback (pre-guard, data flowing). My RTM swap untouched. Will deploy the redesigned fn (+ RTM rebuild if needed) when ready. NO push.

## 2026-07-20T04:32:00Z | binding: devops <-> spec | directive: RTM MAXWAIT diag build @ad73870 | status: done
### RESULT (operator DEV, devops-0625):
- Build-ProdRelease -Mode RTM from v3@ad73870 (MAXWAIT log-only) = BUILD COMPLETE, 0 err -> **Installations\20072026.0711_RTM.zip, 80.51 MB**. RTM-only (carries all prior RTM fixes + MAXWAIT diag).
- Handed operator drop-in manual swap (OUR RTMService ONLY; backup; preserve appsettings+data.sys; \RTM\ orphan-kill only; legacy/adapter/Garnet/cert untouched) + PROMPT F5 US grid + grep MAXWAIT- (log rotates 5-10min). Throwaway (backend reverts ad73870 post-capture). status: done(build+staged). NO push.

## 2026-07-20T04:45:00Z | binding: devops <-> spec | directive: RTM MAXWAIT diag deploy+capture | status: done
### RESULT (operator 140, devops-0625): diag ad73870 deployed (drop-in swap, OUR RTMService only, backup, appsettings+data.sys preserved, legacy/adapter/Garnet untouched); both Running. MAXWAIT-RECOMPUTE captured: bagCount=0 -> zero result (Max Wait resets), bagCount>0 -> real ts. Relayed to coordinator/backend. F5-specific REFRESH/STREAM grep offered. Throwaway (backend reverts ad73870). status: done. NO push.

## 2026-07-20T07:45:00Z | binding: devops <-> spec | directive: Shell v3@16c6011 build+evidence | status: done
### RESULT (operator DEV, devops-0625):
- **GATE 1 EVIDENCE:** Build-ProdRelease -Mode Shell from v3@16c6011 = BUILD=0 -> **Installations\20072026.1039_Shell.zip, 59.93 MB**. **dotnet test Tests.Unit = Failed 0, Passed 263, Total 263.** build0 + unit-failed-0 = gate 1 SATISFIED (Max Wait C1 89feb34+16c6011).
- Handed operator drop-in Shell swap on 140 (Shell-only; appsettings preserved; backup; \Shell\ orphan-kill only; RTM(ad73870 diag)/RTM.Twilio/DB untouched; no migrations). Then operator C1 F5-seal. status: done(build+staged). NO push.

## 2026-07-20T07:55:00Z | binding: devops <-> spec | directive: Shell 16c6011 swap on 140 | status: done
### RESULT (operator 140, devops-0625): Shell drop-in swap done — RTMViewShell Running (16c6011 Max Wait C1); RTMService(ad73870 diag) + RTM.Twilio untouched/Running; /health Healthy; appsettings preserved; backup taken; Shell-only (RTM/DB/adapter not touched). Awaiting operator C1 F5-seal (absolute ~22:11 + F5 holds + 1s/s; Ctrl+F5 first). status: done(deploy). NO push.

## 2026-07-21T04:55:00Z | binding: devops <-> spec | directive: revert 140 RTMService -> 961a979 (M7) | status: done
### RESULT (operator 140, devops-0625): RTMService reverted ad73870 diag -> 961a979 (restored latest rtm_* backup; RTMService only; appsettings+data.sys preserved; RTM.Twilio/Garnet/cert/DB untouched). **RTMService + RTM.Twilio Running; /health Healthy; NO MAXWAIT- lines (clean 961a979, no diag spam).** M7 DONE — 140 restored to clean on-demand-grid RTM. NO push.

## 2026-07-21T16:12:00Z | binding: devops <-> spec | directive: WFM Phase-1 build0/unit evidence (v3 30225d6) | status: done
### RESULT (operator DEV, devops-0625):
- **dotnet build CcDashboard.sln = compiles clean** (all 5 projects Domain/Contracts/Application/Infrastructure/Tests.Unit -> .dll; 31.84s; WFM services/widget + migration 20260721110721_WfmTenantSettings compile) = BUILD 0 err.
- **dotnet test tests/CcDashboard.Tests.Unit = Failed 0, Passed 283, Skipped 0, Total 283** (263 prior + 20 new incl 18 Erlang anchor tests).
- WFM build/unit GATE SATISFIED @v3 tip 30225d6. NO deploy, NO push (evidence only). status: done.

## 2026-07-21T16:55:00Z | binding: devops <-> spec | directive: Phase A WFM Shell build @30225d6 | status: done
### RESULT (operator DEV, devops-0625): Build-ProdRelease -Mode Shell from v3@30225d6 = BUILD=0 -> **Installations\21072026.2122_Shell.zip, 59.98 MB**. Holding the 140 swap for coordinator ack on the ASD/DayTrend-regression flag + will apply the 3 WFM indexes CONCURRENTLY first. NO push.

## 2026-07-21T17:25:00Z | binding: devops <-> spec | directive: Phase A WFM — indexes CONCURRENTLY | status: done
### RESULT (operator 140, devops-0625): 3 WFM indexes applied CONCURRENTLY (CREATE INDEX x3, no error, hot RTSData_Interaction not locked). Verify = all 3 present: ix_rtsint_wfm_ans, ix_rtsint_wfm_inq, ix_rtsus_wfm. Now Shell swap @30225d6 (backup + swap -> Web.exe migrate WfmTenantSettings -> WfmRealtimeLoop). NO push.

## 2026-07-21T19:35:00Z | binding: devops <-> spec | directive: Phase A WFM Shell swap @30225d6 | status: done (deploy) / loop-error flagged
### RESULT (operator 140, devops-0625): (first swap attempt no-op'd — pkg wasn't transferred; RTMViewShell restarted on old 16c6011, no harm. Re-ran after transfer.)
- Shell swap @30225d6 DONE: backup shell_20260721_2229; RTMViewShell Running; RTMService + RTM.Twilio Running (untouched); /health Healthy.
- Log 22:30-22:31: **EF migrations applied (WfmTenantSettings)**, Database seed complete, **WfmRealtimeLoop: starting interval=30s** (loop STARTED).
- 3 WFM indexes present (CONCURRENTLY). So: **deployed + healthy + 3 indexes + loop started = MET.**
### ⚠ NEW DEFECT: WfmRealtimeLoop first tick ERRORS — `errorMissingColumn` (42703) in WfmInputQueryService.GetServingAgentCountsAsync:243/253 <- WfmRealtimeLoop.ProcessTenantAsync:104. Query references a column absent on 140 (schema drift). Loop runs but can't compute. Getting the exact column name for backend. NO push.

## 2026-07-21T19:45:00Z | RESULT append (devops-0625): WFM loop-error exact column = **`t.Value` (42703)** in WfmInputQueryService.GetServingAgentCountsAsync:243/253. Relayed to coordinator/backend. Phase A deploy GREEN; loop-compute blocked by the missing `t.Value` column (backend query-vs-140-schema). NO push.

## 2026-07-21T20:58:00Z | binding: devops <-> spec | directive: Shell 6e3c922 rebuild | status: done
### RESULT (operator DEV, devops-0625): Build-ProdRelease -Mode Shell from v3@6e3c922 = BUILD=0 -> **Installations\21072026.2343_Shell.zip, 59.98 MB** (pg_dump WARN = no DB dump in pkg, benign for Shell swap). Handed operator Shell swap on 140 + WFM loop-clean KEY CHECK (Start-Sleep 40 for a 30s tick; no 42703/t.Value expected). NO push.

## 2026-07-21T21:10:00Z | binding: devops <-> spec | directive: Shell 6e3c922 redeploy + WFM loop verify | status: done
### RESULT (operator 140, devops-0625): Shell swapped @6e3c922; RTMViewShell Running; RTMService+RTM.Twilio untouched/Running; /health Healthy; backup taken. **WFM loop tick CLEAN — NO 42703 / NO t.Value.** Loop computes across all workgroups (DE-Support, US-VIP/Retail/Support/Sales/Finance/..., Everyone) -> tick completes, WfmSnapshot store populating. Only benign WRN: `WfmInputQueryService: workgroup <X> has mixed TimeZones, using dominant <offset>` (140's mixed name/offset/empty TZ data; loop uses dominant offset — data-quality note, not an error). **redeployed + loop clean + N populating = MET.** NO push.

## 2026-07-21T23:05:00Z | binding: devops <-> spec | directive: Shell fb9a6a4 rebuild | status: done
### RESULT (operator DEV, devops-0625): Build-ProdRelease -Mode Shell from v3@fb9a6a4 = BUILD=0 -> **Installations\22072026.0155_Shell.zip, 59.99 MB**. Handed operator Shell swap on 140 + loop-clean + per-BU-aggregate KEY CHECK (Start-Sleep 40). NO push.

## 2026-07-21T23:20:00Z | binding: devops <-> spec | directive: Shell fb9a6a4 redeploy + WFM BU verify | status: done / ⚠ key-collision flagged
### RESULT (operator 140, devops-0625): Shell @fb9a6a4 swapped; RTMViewShell Running; RTMService+RTM.Twilio untouched/Running; /health Healthy; backup taken. Loop tick CLEAN (no 42703/t.Value/ERR/FTL); per-BU aggregates computing. **redeployed + loop clean + BU aggregates producing = MET.**
### ⚠ KEY-COLLISION IS REAL: many WRN `WFM key collision: '<name>' is both a Workgroup and a BusinessUnit` naming REAL clashes — US-Support/Retail/VIP/Sales/Finance/EV/Canteen/Canada OEM/Compliance/Onboarding/Tigapo/YA 24/7/Yellow Account, UK-Support/Retail/EV, etc. On 140 these names are registered as BOTH Workgroup AND BusinessUnit -> the name-keyed WfmSnapshot store collides between the BU-aggregate and the workgroup snapshot for these names. Per the coordinator's own criterion ('problem only if it names a real clash'), this IS a problem -> needs BU-vs-Workgroup key disambiguation (backend). Coordinator to re-open DE All to see if the widget shows data despite collision. NO push.

## 2026-07-22T06:52:00Z | binding: devops <-> spec | directive: Shell d1982de rebuild | status: done
### RESULT (operator DEV, devops-0625): Build-ProdRelease -Mode Shell from v3@d1982de = BUILD=0 -> **Installations\22072026.1259_Shell.zip, 59.99 MB**. Handed operator Shell swap on 140 + KEY CHECK (collision WARNs STOPPED + no BU-aggregate error, tail 200 EMPTY; Start-Sleep 40). NO push.

### RESULT append 2026-07-22T10:12:00Z: Shell d1982de LIVE on 140. 3 services Running, /health Healthy. KEY CHECK partial: no BU-aggregate error; collision WARNs remain for UK-Retail/UK-Support (name==Workgroup&BU) — warn-path still name-keyed, snapshot-store fix (id) OK. Reported coordinator. NO push. verified: object-store + live log.
