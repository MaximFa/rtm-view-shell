---
name: project-shell-checkpoint-0609
description: "Resume checkpoint — RTM Shell+UI/UX specialist (shell-0609): dark-mode+deploy-tab SHIPPED, F-1 read-only DONE awaiting Security re-review"
metadata:
  node_type: memory
  type: project
  originSessionId: ff9bc7f0-a921-4dac-9627-fa3ed47e06e2
---

# RTM "Shell" session (slug shell-0609) — checkpoint 2026-06-09 (refreshed)

Standing **Shell + UI/UX specialist**, Cowork-A (Backend), coordinator = coordinator-0609, branch v2-backend.
Specialist does NOT write code directly — issues CC prompts (operator runs), reviews, flushes to `.coord/`.
All `.coord/**` writes via Python+fsync (§0.7 exception; Edit BANNED §0.3).

## Resume entry point
Read `.coord/sessions/shell-0609.md` (role+claims+STATE) + inbox `.coord/inbox/shell-0609.md`.
Bus: `.coord/sessions/*.md`, `tail .coord/journal.md`, `.coord/push/request.md` (tombstone "BARRIER CLEARED" = no FREEZE).
Canon for active feature: `.coord/meeting_hotreload_0609.md`.

## My claims (file-mode in web; never whole module — Widget/DayTrend also live in web)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor  (EXCLUSIVE, standing)
- src/CcDashboard.Web/wwwroot/app.css
- src/CcDashboard.Web/Components/App.razor  (css cache-bump)
- src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor  (xfer from on-hold metrics-2, for hot-reload tab)

## DONE — configurator dark-mode parity (9 gaps)
Commit **5acf274** "web: dark-mode parity for configurator modal (9 gaps) [shell-0609]", parent 1807b44.
2 files: app.css (+102), App.razor (v=15->16). ScreenEditorPage.razor NOT edited (gaps were CSS-only — container/
card borders, not inputs). All 9 selectors scoped under `.dark-mode`, no light-mode leak; gap-7 switch explicit,
generic-input exclusion kept. Build 0 errors. Coordinator verified by object-store + reconciled journal
(S4/cc_post_commit had NOT appended — coordinator fixed truncated 782a857 line + journaled 5acf274).

## PUSHED — 5acf274 shipped (barrier closed)
Push barrier 2026-06-09T13:45Z completed: journal 14:20Z "PUSHED 1807b44..daaa7c3 (v2-backend): 5acf274
dark-mode + d6b1672 orchestrator + daaa7c3 docs(69 files incl hot-reload contract)". origin/v2-backend=daaa7c3,
unpushed=0, FREEZE LIFTED (tombstone). My dark-mode 9-gap work is shipped. Operator-verified GREEN (journal 07:30Z).
At my READY-ack time I CAUGHT+FIXED PD-007: app.css (2929->3159) + App.razor (40->44) were truncated in WORKING
TREE by cache write-back AFTER 5acf274; HEAD/object-store correct; restored via `git show d6b1672:<f> > <f>`,
all 4 claimed files re-verified SAME by hash.
Lesson reinforced: mount `.git` reads unreliable (git rev-parse HEAD fails, status shows `A ./`) — verify by
explicit hash (`git show <hash>` / `git rev-parse <hash>:<f>`), do NOT escalate corruption from mount git status
(feedback_git_mount_distrust). §42.7 ack: ALWAYS hash-verify claimed files vs HEAD before READY (PD-007 drift).

## SHIPPED — hot-reload "Deploy new metrics" tab (Shell side)
Commit **a6f5572** pushed in barrier #2 (daaa7c3..24122c2, FREEZE lifted). 12 files: new interfaces+DTOs
(IMetricDeployLedgerReader, IMetricApplyClient, Contracts/DTOs/Metrics/ApplyMetricsDtos), IRtmRelayService
.InvokeCompileMetricsAsync + RtmRelayService impl (fire-and-forget SendAsync "compileMetrics" to tenant RTM hub),
MetricDeployLedgerReader (SELECT-only, 42P01->empty), MetricApplyHttpClient (POST 127.0.0.1, MetricsApply config),
Program.cs DI, MetricsPage Deploy tab, +3 SharedResources.*.resx (I18N keys — were outside original claims, flagged
+ coordinator-accepted). Contract-verified: no web-DML; R1 (sends response.AppliedRtMetricIds only); Superadmin gate;
no hardcoded secret. PENDING (devops/Backend, behind config): metric_deploy_log DDL, apply-endpoint port/token,
RTM compileMetrics handler. (devops shipped apply-service + ledger table in same barrier: f098cb7/cfa2925.)

Locked contract decisions (canon .coord/meeting_hotreload_0609.md + docs/metrics-{hot-reload,apply-endpoint}-contract.md):
Deploy TRIGGERS devops apply-endpoint (HTTP 127.0.0.1, NOT SignalR-to-RTM); devops applies+ledger+audit (no web-DML);
on success Shell fires compileMetrics(appliedRtMetricIds from response) via RtmRelay (Option A, idempotent);
tab reads §38a ledger for delta; Recompile re-fires compile without re-apply (R2); compile-status badge = v2.

## DONE — F-1 security fix: MetricsPage FULLY read-only (metrics = vendor constants)
Commit **b7b20e4** "fix: F-1 metrics read-only — remove client create/edit/delete/translate; vendor-deploy only".
Operator arch decision 2026-06-10: metrics are vendor product-constants; client cannot create/edit/delete/translate.
4 files, +10/-701: MetricsPage (removed New/Edit/Delete/Translations buttons + create/edit + translation modals +
all mutation @code), ConfigurationCommands (removed 4 commands+handlers: Save/Delete RtsGridMetric, Save/Delete
MetricTranslation), CommandValidators (removed SaveRtsGridMetricCommandValidator), ConfigurationDtos (removed 2
orphan request DTOs). KEPT: read-only list + Deploy tab + read query. Security-grep across src = EMPTY (no command/
handler/validator/caller/DTO) — CODE-03 "UI-only hiding never sufficient" satisfied. Build 0 errors.
Awaiting: Security re-review (УРОВЕНЬ-2 + ccdashboard_user grants) + next barrier. NOT pushed (234 HALT).

## LESSON — PD-007 byte-level drift (2026-06-10)
After b7b20e4 commit, all 4 working-tree files drifted from HEAD by HASH while LINE COUNTS were IDENTICAL
(byte/line-ending drift from cache write-back, NOT truncation). A line-count check would pass it as clean;
§42.7 hash-verify caught it. Restored via `git show <hash>:<f> > <f>`. RULE: hash-verify (git hash-object vs
git rev-parse <hash>:<f>), NEVER line-count — even when counts match. (mount `.git` status also unreliable:
git rev-parse HEAD may fail / show `A ./` — verify by explicit commit hash, don't escalate. feedback_git_mount_distrust.)

## STATE NOW
No active CC task. No FREEZE. b7b20e4 (F-1) committed, unpushed, awaiting Security re-review + barrier (234 HALT).
Standing claims: ScreenEditorPage.razor, app.css, App.razor, MetricsPage.razor (+ deploy-tab & F-1 footprint files,
all committed). Next: respond to Security re-review of b7b20e4, or next UI/Shell task from coordinator.

## Skills (read in §40 block per task)
ux-ui-expert (WHAT) + frontend-design / blazor-frontend-design (HOW) + blazor-server-expert (render-mode/circuit)
+ app-cyber-security-expert (no token/PII in localStorage §41, XSS/MarkupString CODE-02, no web-DML/secrets).

## Other active sessions (snapshot)
coordinator-0609 (active), devops-2-0607 (active, apply-service/ledger + server234 deploy), daytrend-2-0607
(active, P3 _008 pending GO), metrics-2-0607 (on-hold, data/domain only), test-5-0607 (on-hold, QA).

Peer-to-peer rule (2026-06-09): direct session<->session via `.coord/inbox/<peer>.md` allowed, BUT any
design/contract decision born there MUST be harvested back to canon (coordinator.md / brief / contract doc).

See [[project_session_sync_checkpoint]], [[feedback_git_mount_distrust]], [[project_rtm_metrics_session]].
