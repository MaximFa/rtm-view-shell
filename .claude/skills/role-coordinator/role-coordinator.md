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
Role: Multi-session router/planner. Owns .coord/, CLAUDE.md, session-coord skill, task DISPATCH + §4-review. Does NOT write production code (§0.7); does NOT author non-push prompts (IRON #9 — the SPEC authors; coordinator authors ONLY push prompts).
**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.
Cardinal truths (source-pinned; detail in §D):
1. commit.lock acquire/release = CC-ONLY (Cowork mount can't unlink → orphan). · L-SC-02/§42.4
2. journal.md = convenience view; git log / object-store = truth (reconcile). · L-SC-04/§42.5
3. push-prompt preflight MANDATORY (branch-agnostic; 5 checks → §D). · L-SC-29
4. CC↔spec binding MANDATORY every CC prompt (PREAMBLE + RESULT → .coord/cc/<role>.md). · NORM-CUR-07c/§0.6b
5. Barrier: request.md FIRST (freeze) → acks AFTER. · L-SC-01/§42.7
6. .coord/ presence checks content-based (-s + cat), never -f (mount phantom dirents). · L-SC-10/14
7. Verify by object-store, not chat memory; tool-success ≠ delivery. · §0.1/NORM-CUR-13
8. MANDATORY Compare-ToBaseline before ANY deploy; never reuse a migration-list/memory. · 234+45 2026-06-19
9. IRON dispatch (operator, PERMANENT): coordinator DISPATCHES + §4-approves; SPEC authors prompt; operator runs from spec session; spec processes + reports. EXCEPTION: push = coordinator. · operator 2026-06-22

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-05 · run-1 push barrier: acks collected before freeze -> 3 re-acks · freeze first, acks after · SOURCE:a8ac25b · status: active
- 2026-06-06 · 4 unpushed commits invisible to mount journal view -> L-SC-04 reconcile · journal=convenience,git=truth · SOURCE:7cf83cb · status: active
- 2026-06-08 · L-SC-19 per-session ack files failed under phantom load -> append-only ACKS.md · SOURCE:81ec6c2 · status: active
- 2026-06-09 · L-SC-21 inbox migration missed -> lost directives; now permanent role mailboxes · SOURCE:1799534 · status: active
- 2026-06-14 · mount false-M on db/*.sql (hash==HEAD) -> verify by git hash-object, not git status · SOURCE:coordinator_handoff.md · status: active
- 2026-06-15 · L-SC-29 push-prompt without preflight shipped stale artefacts -> bake preflight into standing prompt · SOURCE:b618a14 · status: active
- 2026-06-17 · status-review T1-T6: git-committed != product. T1 (9734252) object-store verified BUT BROKEN in prod — #1 .widget!=.dashboard-widget (no widget-to-widget guides), #2 onMouseUp missing hideGuides (stuck lines); T4 grid bg absent · RULE: status has TWO floors — object-store AND product; mark product-divergence per-item, committed!=works · SOURCE: 9734252, ScreenEditorPage.razor:190, widget-resize.js:onMouseUp · status: active
- 2026-06-19 · Anti-saga deploy discipline (worked on 234): stepwise via inbox; mandatory Compare gate BEFORE apply; pg_dump backup FIRST (FAIL-STOP); on ANY tool error mid-deploy -> STOP, do NOT improvise, rollback from pg_dump backup; config clobber -> restore from deploy binary-backup; verify EVERY specialist binding RESULT natively by object-store before greenlight. Zero data loss across 4 caught defects. · SOURCE: 234+45 full deploys 2026-06-19 · status: active
- 2026-06-22 · Surfaced a multi-tenant/PII decision (ChatMessage archive TenantId: source table has NO TenantId -> JOIN-inference + orphan policy) to the OPERATOR as an 'operator decision'; operator flagged security would HOLD it at the push quorum. RULE: decisions touching MULTI-TENANT ISOLATION (ARCH-01/GQF), PII/customer-content, or RETENTION/compliance are SECURITY's domain -> route to security for a PRE-DECISION ruling BEFORE implementation; never finalize as an operator/coordinator call (else quorum HOLD). · SOURCE: ChatMessage-archive 2026-06-22, operator flag · status: active
- 2026-06-22 · Lesson-capture ROUTING (operator directive): EVERY lesson -> §B (append-only, nothing too small); CRITICAL AMPLIFIERS (load-bearing invariants that change init-time behaviour / high recurrence / blast-radius) elevated to §A as source-pinned cardinal truths, within the ~40-line cap. Default §B; §A reserved for amplifiers. · SOURCE: operator 2026-06-22; codified in .coord/protocols/role-skill-standard.md Capture-discipline · status: active
- 2026-06-22 · Ended dispatch turns by handing the OPERATOR the literal CC-trigger command (`Выполни задачу из файла tools/...`). Operator corrected: the coordinator does NOT issue/hand CC prompts to the operator. RULE: coordinator output to the operator = DIRECTIVES to specialists (written to their inboxes) + the trigger-list (which `коорд: входящие`/poke to send to which spec) ONLY — NEVER the `Выполни задачу...` CC command itself. The specialist owns running its own CC prompt; I route + tell the operator whom to poke. · SOURCE: operator directive 2026-06-22 · status: active
- 2026-06-22 · A spec reported 'CC commits not landing' (dba corrective step-0). ROOT was a stuck PHANTOM `.git/index.lock` (test -e EXISTS / cat='No such file' / 0B / mount `rm`='Operation not permitted') -> every `git add` aborts 'Unable to create index.lock: File exists'. RULE: on 'commits won't land', FIRST probe `.git/index.lock` + `.coord/locks/commit.lock` (git add -n + test -e/-s/cat); a phantom blocks ALL commits, is NOT a CC error, and the mount cannot rm it -> operator Windows-side `del` (clean) OR §0.4 GIT_INDEX_FILE temp-index bypass (proven). · SOURCE: index.lock probe 2026-06-22, CLAUDE.md §0.4, L-SC-02/14/17 · status: active
- 2026-06-22 · ALL standing push prompts (cc_prompt_push.md, cc_prompt_push_barrier.md + dated one-offs) HARDCODE `git push origin v2` + `git log origin/v2..HEAD` -> wrong-branch-push footgun: when the active line changes (v2->v2-backend->v3->next) the prompt silently targets the WRONG branch. Caught at the v3 barrier ONLY via the L-SC-29 branch preflight; had to author a one-off cc_prompt_push_v3.md. FIX (apply post-push): make the canonical push prompt BRANCH-AGNOSTIC — `BRANCH=$(git rev-parse --abbrev-ref HEAD)`; push `origin $BRANCH`; cross-check against the branch declared in .coord/push/request.md; preflight asserts HEAD==frozen branch. NEVER hardcode a branch; source-pin it to request.md. Retire dated one-off push prompts after use. · SOURCE: v3 barrier 2026-06-22, tools/cc_prompt_push*.md hardcoded `origin v2`, L-SC-29 · status: active
- 2026-06-22 · Operator directive: when dispatching EACH task to a spec, the directive MUST EXPLICITLY require a REPORT BACK to the coordinator containing: (1) result/outcome; (2) any arising QUESTIONS; (3) FORKS / decision-points hit; AND (4) an IDLE/INACTION flag if the spec goes idle after completing (so the coordinator re-tasks it, never leaves it silently parked). Make this a STANDING clause of every directive + CC-prompt template (alongside the §0.6b binding RESULT). · SOURCE: operator directive 2026-06-22 · status: active
- 2026-06-22 · IRON RULE (operator, PERMANENT) — dispatch workflow shape: (1) coordinator DISPATCHES task to a spec; (2) the SPEC authors the CC prompt; (3) coordinator §4-APPROVES; (4) operator runs CC with that prompt FROM THE SPEC'S SESSION; (5) on CC completion the SPEC processes the RESULT + reports back to coordinator. ONLY EXCEPTION: PUSH prompt = coordinator authors. I wrongly authored reconcile/spine/fold-fix/push-v3 prompts myself this session — STOP doing that; dispatch to the owning spec. Enforce this exact shape in EVERY dispatch. · SOURCE: operator directive 2026-06-22 · status: active

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

### §A cardinal details (relocated for cap)
- (1) commit.lock: a Cowork-acquired lock orphans forever (mount can't unlink). SOURCE 7cf83cb.
- (2) journal: CC-appended journal lines may vanish from the mount; reconcile against object-store. SOURCE 7cf83cb.
- (3) push preflight 5 checks: branch==declared(request.md); narrow explicit adds only; §0.2-restore truncated; no Export-All; no secrets. SOURCE b618a14.
- (8) Compare-ToBaseline: never apply migrations/binaries without FIRST running Compare against THAT server; each server's applied-set differs. SOURCE 234+45 2026-06-19.
- (9) IRON dispatch shape: (1) coordinator dispatches; (2) spec authors prompt; (3) coordinator §4-approves; (4) operator runs CC from the spec's session; (5) spec processes RESULT + reports. EXCEPTION push=coordinator. SOURCE operator 2026-06-22.
