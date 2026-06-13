# CC task — codify CC<->Spec binding protocol (NORM-CUR-07)
> Author: curator-0611. Executor: native CC in THIS repo. docs: commit, NO push (sec 0.6). Python+fsync (sec 0.3). sec4-review first.
> UNIFORM (NORM-CUR-01): the OTHER project applies the identical change to its skill copy + CLAUDE.md (curator owns parity).

## What the binding is
Each CC-session-open creates a BINDING linking the spec-role <-> this CC run <-> the directive (tools/<name>.md). Channel:
.coord/cc/<role>.md (rolling, one BINDING block per CC-open, append-only, auto-archived NORM-CUR-06). CC writes the RESULT
into the binding ONLY; the spec relays a digest to inbox/coordinator.md. This is the EXECUTION leg of the dispatch loop. [coord §4: CC's binding write is NATIVE (reliable); the residual L-SC-04 risk is the Cowork spec's CROSS-VIEW READ. So the binding is an INDEX to git, NOT a new source of truth — the RESULT carries commit hashes/counts that the spec verifies against the OBJECT STORE.]

## BINDING block format (insert this template into the docs)
    ## BINDING <cc-open-UTC> | spec: <role> | directive: tools/<name>.md | status: open
    ### DIRECTIVE (spec->CC): ref tools/<name>.md . acceptance . claim . gate
    ### RESULT (CC->spec): commits <hashes> . build/test <counts> . files <changed> . status done|failed . blockers . verified: object-store
    > consumed <UTC> by <role>

## Edits
1. Bus layout (skill sec1/sec11 + CLAUDE.md sec26.1/sec42.1): add .coord/cc/<role>.md = the CC<->spec binding channel; auto-archived.
2. CC-prompt TEMPLATE - new mandatory blocks (CLAUDE.md sec0.6a mandatory-blocks + sec22 CC-prompt rules; skill sec4):
   - PREAMBLE (after the integrity/sync block): OPEN BINDING - append a BINDING block to .coord/cc/<role>.md (status: open, directive ref).
   - POSTAMBLE (after execution): WRITE RESULT into the binding (commits/build-test/files/status/blockers/object-store verify),
     status: done|failed. Do NOT write results to inbox/coordinator.md - that is the spec digest job.
3. Spec consume step (auto-inbox-hook, skill sec10 + CLAUDE sec42.8/sec26.9): on your turn also read .coord/cc/<role>.md; CONSUME
   the latest RESULT (mark > consumed), relay a short digest to inbox/coordinator.md.
   [coord §4 REQUIRED — git fallback]: if the binding RESULT is ABSENT/dropped but `git log origin/<branch>..HEAD` shows new commits, RECONCILE from the object store (L-SC-04/L-SC-18) — do NOT report 'CC didn't finish' on a dropped binding. The binding accelerates the happy path; git remains the truth.
4. Coordinator koord: prompt (skill sec10): drafted prompts MUST include the binding preamble/postamble.
5. Lesson L-SC-26 + note NORM-CUR-07.
6. Commit docs(coord): CC<->spec binding protocol (.coord/cc/, NORM-CUR-07); journal; NO push; re-sync.

## Acceptance
- skill + CLAUDE carry the binding channel + the CC-prompt preamble/postamble + the spec consume step + L-SC-26.
- .coord/cc/ in bus layout, auto-archived. Curator confirms RTM<->AD skill parity after both apply.

## WRITE-ROUTING (NORM-CUR-07 refinement, coordinator-0612 confirmed 2026-06-13)
- Large/persistence-critical writes (skill, CLAUDE.md, source, migrations, commits) + CC RESULTS -> native CC. CC RESULTS go
  INTO the binding (.coord/cc/<role>.md), NOT operator-relayed. "Передай координатору" retires for LOCAL CC work.
- Operator-relay = BACKSTOP ONLY for executing contexts with NO repo .coord/ (e.g. server-side deploy). Such runs emit a small
  RESULT-ARTIFACT (status file on the server/output); a LOCAL session ingests it into the binding next turn.
- Small bus chatter (inbox lines, journal, heartbeat) STAYS Cowork Python+fsync (small append-only = reliable).

## SPEC-CONSUME git-fallback (coordinator amendment — REQUIRED)
The binding lives on the same mount; its cross-view READ is L-SC-04-exposed, so the binding is an INDEX to git, NOT a new source
of truth. On consume: if the RESULT block is absent/empty BUT `git log origin..HEAD` shows the CC commits, RECONCILE from the
object store (verify hashes) — do NOT false-report "CC did not finish".
