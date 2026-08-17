---
name: project-coordinator-checkpoint-0609
description: "Resume checkpoint — coordinator (Cowork-A). 2026-06-10 EOD: Security gate CLOSED for 234 iter-1, barrier #3 pushed 60fc6aa, team of 8"
metadata:
  node_type: memory
  type: project
  originSessionId: 45746494-489a-4c11-87f5-20ba5631c64d
---

**LIVE RESUME ARTIFACT = `.coord/coordinator_handoff.md`** (read FIRST; richer than this). Then the bus:
`.coord/` sessions/*.md, journal.md, inbox/*.md, push/ (tombstone=clear), backlog.md.

**Checkpoint 2026-06-10 EOD — coordinator-0609 (Cowork-A Backend, branch v2-backend).**

**STATE:** origin/v2-backend = **60fc6aa** (unpushed=0). Barrier #3 pushed 14 commits = 234 iter-1 (hot-reload infra
+ security remediation F-1..F-6 + RV-1/RV-1b + integration tests + catowner + docs). FREEZE clear. Security gate
**CLOSED** (ACK 2026-06-10T09:45Z, scope=this changeset only). Zombie Tests.Unit files kept OUT of the push (would
undo F-1/RV-1b).

**NEXT ACTION:** devops-2 rebuilds build_234 on 60fc6aa → **234 iteration-1 = INFRA-ONLY** deploy-steps → coordinator
§4 → operator runs on 234 + captures **DG-1** (Get-NetTCPConnection 8088 = 127.0.0.1 only) + **DG-2** (ApplyService
starts only on real env secret MetricsApply__Token; placeholder → F-2 guard refuses). Iteration-2 (later) = metric
fixture create+deploy via hot-reload (metrics-3 on HOLD).

**TEAM = 8 standing + lab + QA:** backend-0609 (RTM Server: Engine/Union/fn01), shell-0609 (Shell+UX/UI),
metrics-3-0609 (Metrics), devops-2-0607 (Devops: owns 234 rebuild/deploy), daytrend-3-0609 (Widget), dba-0610 (DB),
**security-0609 (GATE — now a PERMANENT mandatory specialist)**, coordinator-0609. lab-0609 (branch `lab`, method
harvest). test-5-0607 → RTM QA (on-hold; awaits 234 URL).

**KEY DECISIONS TODAY (operator):**
1. **Security = standing mandatory gate for ANY change/feature** — mandatory ACK before any prod release. Triggered
   because we'd skipped it and the OPERATOR (human) caught the omission.
2. **Metrics = vendor product-constants.** Client MetricsPage FULLY read-only (b7b20e4). Add/change/delete ONLY via
   vendor deploy. Delete REQUIRES mandatory replacement mapping (deletedId→replacementId) + re-point usage. This is
   how F-1 (RCE via compiled metric templates) was closed ARCHITECTURALLY, not by a patchable validator.
3. Metric lifecycle (vendor-constants, deploy-only) added to rtm-metrics-expert skill.

**PROTOCOL FIXES (don't regress):** handled-marker written ONLY by recipient (coordinator marking its OWN sent
directives silently hid messages — fixed); skill session-coord §10 is NORMATIVE for commands, never guess unknown
verb; mount `.git`/status unreliable → verify by object store (cat-file/show/hash-object), never line-count (PD-007
byte-drift); push target = `origin v2-backend` NOT v2, narrow explicit-glob staging only.

**FF BACKLOG:** FF-1 grammar/AST validator (DiD on F-1) · FF-3 RTMHub bearer-token · B'+RV-2 (seeding→privileged +
REVOKE ccdashboard_user + dead-code) · ApplyService LocalSystem→low-priv · deploy-delete+replacement epic.

**METHOD EVIDENCE (for lab):** E-024 first cross-TEAM (4-specialist) feature shipped through the bus — POSITIVE.
**E-025 (primary lesson): the most critical safety gate was NOT system-enforced — a human caught its absence.**
Remediated by making Security a standing mandatory gate. Coordinator itself is a failure mode (handled-marker bug
was mine, silently broke comms). Verification discipline held: every "done" object-store-verified; the push that
could have silently undone F-1 was prevented by folding session flags into the prompt.

See [[project_shell_checkpoint_0609]], [[feedback_git_mount_distrust]], [[project_rtm_metrics_session]], [[project_rtm_prod_tests]].
