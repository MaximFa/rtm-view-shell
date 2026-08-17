---
session: RTM Metrcs
slug: metrics-3-0609
started: 2026-06-09T10:13:19Z
heartbeat: 2026-07-21T10:12Z
status: done            # active | pushing | done
modules: []
files:
  - tools/lint_metrics.py
  - docs/metrics-hot-reload-contract.md
cc_task: none
---
>>> INBOX RULE (pinned 2026-06-10 — read-hygiene): MY inbox = `.coord/inbox/metrics-3-0609.md` (file named after MY slug =
>>> messages TO me). On `коорд: входящие` -> read THIS file IN FULL, act on each unhandled block, append
>>> `> handled <UTC> by metrics-3-0609`. I WRITE/flush to `.coord/inbox/coordinator.md` (named after the RECIPIENT) — that is
>>> my OUTBOX, NEVER my read-source. RULE: READ the file named after YOU; WRITE to the file named after the RECIPIENT.

Takeover of metrics-2-0607, 2026-06-09 (context-clean restart, NEW_SLUG=metrics-3-0609, PRIOR=metrics-2-0607).
ROLE: METRICS SPECIALIST — data/domain + опросник->migration (RTSGrid_Metric + history mirror) + CONTRACT only.
NOT UI (=Shell) / NOT apply (=devops) / NOT compile (=Backend RTM). Branch v2-backend (Backend Cowork, §44).

MOUNT RULE: never trust .git reads via mount ('v2-backend' truncates to 'v2-'). Verify HEAD/refs via
`git rev-parse refs/heads/v2-backend` + origin only. PD-007: committed files truncate in WT post-commit ->
restore from refs/heads/v2-backend:<f> (NOT HEAD). cc_post_commit.sh frequently drops journal+S4b (L-SC-04) ->
restore journal line + coordinator flush manually after EVERY CC commit.

CLAIMS: tools/lint_metrics.py + docs/metrics-hot-reload-contract.md (copied verbatim from metrics-2-0607).
Metric data/docs are mine as edited: db/data/02_metrics.sql, db/baseline.sql, metric migrations,
docs/metrics-catalog.json(+ru/he), docs/RTM_Shell_Metrics_Overview.md, docs/rtsgrid-metric-reference.md,
gen/export tools, .claude/skills/rtm-metrics-expert. RELEASED MetricsPage.razor + all .razor/.css -> Shell.

HOT-RELOAD FEATURE (active, multi-session): canon = .coord/meeting_hotreload_0609.md. My deliverable =
docs/metrics-hot-reload-contract.md (kept canonical). Option A ratified (Shell triggers compile post-apply).
SignalR compileMetrics(string[] RT-MetricId only) ack'd.
*** CONTRACT R1/R2 FOLDED 2026-06-09T10:24Z (GATE-DOC GO, coordinator 14:55Z) — working-tree edit done,
    docs: commit DEFERRED to next barrier (E-023), not in 234 path, no push. Details of what was folded:
    R1 = §6 explicit "Shell sends appliedRtMetricIds from apply-endpoint response, NOT whole manifest;
         RTM internal history-skip = defense-in-depth (not primary)".
    R2 = new "deployed != compiled" section: v1 best-effort fire-and-forget + Shell Recompile affordance;
         compile idempotent (TryAdd); v2 = compile-status signal.
    Also §8 still says "manifest-diff delta per §3" — should read ledger-based per §3. Needs a docs: commit (CC) on GO.

BARRIER: cleared (1807b44..daaa7c3 pushed 14:20, tombstone). Contract landed in daaa7c3 (docs, 69 files) but
WITHOUT R1/R2. unpushed: 160259a (backend NGC INSERT fix, not mine) post-daaa7c3.

PENDING BACKLOG (mine, post-release, NOT started, NOT in 234 to-apply path):
 (a) typo-drop migration: DELETE QueueNumAbandonefCalls/QueueNumAbandonefCallbacks (typos; canonical
     QueueNumAbandoned* in repo+prod). NEW migration >=20260607_004+ -> MUST §38a self-record. Defensive
     RTSGrid_Cell.Value remap (none expected) then DELETE.
 (b) catalog json cleanup: remove 4 dedup metricIds (QueueNumAcceptedCallbacks, QueueNumOnCallAgents,
     QueueNumberOfLoggedAgents, QueuePctAnsweredCalls60secIncLast30min) — still in docs/metrics-catalog.json
     though deduped from 02_metrics + removed by _004 (782a857). lint must stay green.

CC-tasks (migrations/data edits) NOT to be issued until coordinator/operator GO. Coordinator = coordinator-0609.

BACKLOG PROMPTS DRAFTED 2026-06-09T13:21Z (for §4, NOT issued): tools/cc_prompt_drop_typo_metrics.md (a, new migration 20260609_001) + tools/cc_prompt_catalog_dedup_cleanup.md (b, B1/B2 open Q). cc_task=none.

CONTRACT v1.2 2026-06-09T18:48Z: §3.2 manifest SHA-256 (F-4 fail-closed) added (untracked-delta over 24122c2; v1.1 already pushed). Manifest-generator emit = build/devops (routing Q at §4). Fixture = iteration 2 ON HOLD.

> REAPED 2026-06-12T11:02Z by curator-0611 (operator-confirmed, L-SC-14): heartbeat stale >19h-3d, cc_task=none, work committed. Claims released. Fresh incarnation re-registers when the role is next spun up.

BOT-CHANNEL design 2026-06-13 (operator GO): docs/bot-channel-metrics-design.md + tools/cc_prompt_bot_channel_metrics.md (10 RT metrics, InteractionType==Bot) -> §4. cc_task=none until issue.

BACKFILL DONE 2026-06-17 9686c7e (db:, unpushed). cc_task=none.

ADDED QueueNumberOfCompletedIncomingCalls 0364a71 (db:, v3, unpushed). cc_task=none.
