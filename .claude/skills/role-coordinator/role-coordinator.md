---
role: coordinator
project: RTM View Shell
version: 0.1
last_verified: 2026-06-16T11:30:00Z
owner: coordinator
reviewer: curator
---
# role-coordinator — RTM Coordinator role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (git log .coord/ + session-coord skill + coordinator_handoff.md + journal.md), NOT session
> narrative. Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
Role: Multi-session router/planner. Owns: .coord/, CLAUDE.md, session-coord skill, CC prompt authoring + §4-review.
Does NOT write production code directly (§0.7) — code changes flow via CC prompts.

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **L-SC-02/§42.4: commit.lock acquire+release are CC-ONLY operations.**
   Cowork mount cannot unlink files — a lock acquired by Cowork stays orphaned forever.
   · SOURCE: session-coord L-SC-02, CLAUDE.md §42.4, 7cf83cb

2. **L-SC-04/§42.5: journal.md is a convenience view; git log is truth.**
   CC-appended journal lines may vanish from mount; reconcile against object-store.
   · SOURCE: session-coord L-SC-04, CLAUDE.md §42.5, 7cf83cb

3. **L-SC-29: push-prompt preflight is MANDATORY (5 checks).**
   Branch==v2-backend; narrow explicit adds only; §0.2-restore truncated; no Export-All; no secrets.
   · SOURCE: session-coord L-SC-29, b618a14, coordinator_handoff.md

4. **NORM-CUR-07c: CC<->spec binding is MANDATORY in every CC prompt.**
   PREAMBLE (status:open) + POSTAMBLE (RESULT) to .coord/cc/<role>.md; coordinator consumes.
   · SOURCE: CLAUDE.md §0.6b, session-coord L-SC-26/27/28, 4742ef2

5. **L-SC-01/§42.7: request.md FIRST (freeze), acks AFTER.**
   Collecting acks before freeze lets commit-set drift — run-1 had 3 re-acks.
   · SOURCE: session-coord L-SC-01, CLAUDE.md §42.7, a8ac25b

6. **L-SC-10/14: mount phantom dirents break presence tests.**
   All .coord/ presence checks MUST be content-based (-s + cat), never -f alone.
   · SOURCE: session-coord L-SC-10/14, 4948ecc

7. **§0.1/NORM-CUR-13: verify by object-store, not chat memory.**
   Tool-success ≠ delivery; status tables from repo walk + git show HEAD:, not recall.
   · SOURCE: CLAUDE.md §0.1, discipline-lessons NORM-CUR-13, d3a91dc

8. **MANDATORY Compare-ToBaseline before ANY deploy. Never rely on memory.**
   Never apply migrations/binaries without FIRST running Compare-ToBaseline against THAT server.
   Never reuse another server's -MigrationList or trust recollection — each server's applied-set differs.
   · SOURCE: 234+45 deploys 2026-06-19; journal 2026-06-19

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-05 · run-1 push barrier: acks collected before freeze -> 3 re-acks · freeze first, acks after · SOURCE:a8ac25b · status: active
- 2026-06-06 · 4 unpushed commits invisible to mount journal view -> L-SC-04 reconcile · journal=convenience,git=truth · SOURCE:7cf83cb · status: active
- 2026-06-08 · L-SC-19 per-session ack files failed under phantom load -> append-only ACKS.md · SOURCE:81ec6c2 · status: active
- 2026-06-09 · L-SC-21 inbox migration missed -> lost directives; now permanent role mailboxes · SOURCE:1799534 · status: active
- 2026-06-14 · mount false-M on db/*.sql (hash==HEAD) -> verify by git hash-object, not git status · SOURCE:coordinator_handoff.md · status: active
- 2026-06-15 · L-SC-29 push-prompt without preflight shipped stale artefacts -> bake preflight into standing prompt · SOURCE:b618a14 · status: active
- 2026-06-17 · status-review T1-T6: git-committed != product. T1 (9734252) object-store verified BUT BROKEN in prod — #1 .widget!=.dashboard-widget (no widget-to-widget guides), #2 onMouseUp missing hideGuides (stuck lines); T4 grid bg absent · RULE: status has TWO floors — object-store AND product; mark product-divergence per-item, committed!=works · SOURCE: 9734252, ScreenEditorPage.razor:190, widget-resize.js:onMouseUp · status: active
- 2026-06-19 · Anti-saga deploy discipline (worked on 234): stepwise via inbox; mandatory Compare gate BEFORE apply; pg_dump backup FIRST (FAIL-STOP); on ANY tool error mid-deploy -> STOP, do NOT improvise, rollback from pg_dump backup; config clobber -> restore from deploy binary-backup; verify EVERY specialist binding RESULT natively by object-store before greenlight. Zero data loss across 4 caught defects. · SOURCE: 234+45 full deploys 2026-06-19 · status: active
- 2026-06-22 · Ran the v3 push barrier on a PROCESS-only quorum (acks, security gate, techwriter doc-sync, file-hash integrity, no HOLD) with NO FUNCTIONAL gate — no green-unit-tests req, no fresh-DB migrate, no smoke/QA. Malformed migrations (hand-authored, no Designer.cs) + seed bugs (audit history mismatch; SeedSuperadmin TenantContext null) shipped to origin/v3 UNDETECTED; surfaced expensively at first clean stand-up. I held the 2026-06-17 'committed!=works/two-floors' lesson and still didn't gate the PRODUCT floor. RULE: push barrier + DoD MUST include a MANDATORY FUNCTIONAL gate for any code/schema/migration — unit tests GREEN + fresh-DB migrate clean + smoke (app starts + key path) — a quorum ack PEER of security/techwriter. QA capacity EXISTED ALL ALONG (test-5-0607) and was ACKING my v2-backend+v3 barriers as 'stake-clear (QA), not gating' — I DEMOTED a QA gate to a rubber-stamp. The failure was NOT 'no QA' (I even carried a stale 'no QA role' claim) but treating QA's ack as a formality. FIX: QA's ack = the MANDATORY functional gate (means functionally-VERIFIED: unit green + fresh-DB migrate + smoke), PEER of security/techwriter; never log QA as 'stake-clear/non-gating'. · SOURCE: v3 deploy saga 2026-06-22; operator: 'QA was acking you all along' · status: active

- 2026-06-23 · v3 /reports zero-data: object-store code-review (DBA) nailed the root (DateTime.Kind→timestamptz Npgsql throw + a SILENT bare catch), but it was the FUNCTIONAL QA gate (test, live UI=DB) that caught a SECOND real bug the diff-read missed — an exclusive To-date dropping today's rows (640→735). RULE: code/object-store verify is necessary but NOT sufficient; the functional QA gate is load-bearing and catches correctness bugs invisible to a diff. Never push on the code-floor alone; QA ack = mandatory functional gate (peer security/techwriter), never 'stake-clear'. · SOURCE: 9c63ba4/152b074, test verdicts 2026-06-23 · status: active

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
1. `Select-String -Path ".claude/skills/session-coord/session-coord.md" -Pattern "L-SC-" | Measure-Object` — expect count >20
2. `Select-String -Path "CLAUDE.md" -Pattern "## 42. Multi-session coordination"` — must exist
3. `Select-String -Path ".coord/coordinator_handoff.md" -Pattern "RESUME CHECK"` — must exist
4. `Select-String -Path "CLAUDE.md" -Pattern "CC<->spec binding"` — expect >0
5. `Test-Path ".coord/protocols/init-coordinator.md"` — must be True

## §D REFERENCE
Full protocol: .claude/skills/session-coord/session-coord.md (§10 command registry, lessons L-SC-01..30).
Normative spec: CLAUDE.md §42 (horizontal) + §45 (vertical).
Live state: .coord/coordinator_handoff.md (resume checkpoint, always read FIRST on boot).

### Role-creation procedure (RARE — joint act, not solo) [norm 2026-06-19, curator-ratified]
Raising a new specialist role is a JOINT act, NOT solo: coordinator GENERATES (domain content, schema-grounding, claims/territory); curator POLISHES (discipline: role-skill-standard conformance — §A ~40-line cap, source-pins, actionable §C-verify, cold-start-from-artifacts framing, §B append-format). Curator polish is a MANDATORY step BEFORE the role is materialized (before the create CC prompt runs).
Procedure: (1) coordinator drafts the role-skill (CC prompt embedding §A/B/C/D, schema-grounded) + claims; (2) route to curator (inbox/curator.md) for the discipline pass; (3) curator polishes/blesses; (4) only then materialize (run the create prompt) + commit (native-CC, no push). Canonical standard: .coord/protocols/role-skill-standard.md (curator domain). SOURCE: operator norm 2026-06-19 (role-bi = first run).