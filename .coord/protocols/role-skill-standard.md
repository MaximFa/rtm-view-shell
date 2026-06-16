# role-skill standard + promotion gate (Specialist Protocol spine)
> Curator-owned (NORM-CUR-11). The VERTICAL axis: how ONE role keeps + grows its expertise across its own
> re-instantiations. Complements §42 (horizontal coordination). Source spec: .coord/specialist-protocol.md.
> Curator OWNS this standard + audits role-skills ASYNCHRONOUSLY (NOT a per-write gate — that would stall capture).

## Two layers (the cut)
- PERSISTENT (role): `.claude/skills/role-<role>/role-<role>.md` — SURVIVES reap. The worker's notebook.
- EPHEMERAL (incarnation): `.coord/sessions/<slug>.md` — dies at reap (claims/heartbeat/cc_task).
IRON RULE: nothing durable lives ONLY in the ephemeral layer. A lesson is written into the PERSISTENT layer BEFORE
the incarnation ends, or it is lost by design.

## role-skill anatomy
Frontmatter: `role, project, version, last_verified, owner: <role>, reviewer: curator`.
- §A CORE — invariant, HARD CAP ~40 lines, loaded EVERY init. Role rules + the caveat "reality wins — update me" +
  3-7 cardinal truths, EACH source-pinned. If §A can't be read in one breath, weed §B.
- §B LESSONS — append-only, dated, with status. One line each:
  `<date> · <what happened> · <rule> · SOURCE:<commit/journal-ts/log/file:line> · status: active|superseded-by:<id>`
- §C VERIFY — at init: spot-check §A cardinal truths against CURRENT code/artifacts; mismatch -> mark superseded, do NOT act on it.
- §D REFERENCE (optional) — deep material, NOT loaded each init.

## 4 invariant properties (carried from the working anchor)
1. CO-OWNERSHIP with a reality-node (the role + the code/artifacts; reviewer = curator).
2. "REALITY WINS — update me" caveat is explicit in §A.
3. CORE (invariant) vs PERIPHERY (append-able) separation.
4. SOURCE-GROUNDING, not session narrative (sessions confabulate — verified repeatedly). Every fact pins a source.

## Capture discipline (anti-rot)
- CAPTURE is a MANDATORY lifecycle step (not opt-in): any task that yields a lesson -> append the dated, source-pinned
  lesson to §B BEFORE the task closes. Wired into the CC postamble next to binding-RESULT (§0.6b).
- Status active/superseded only; SILENT editing forbidden (like the journal). Reality-wins caveat. VERIFY at init.
- Periodically weed §B so §A stays loadable. Writes are native-CC only (mount truncates), via §4-review.

## Lifecycle (vertical, brother of the §42 horizontal lifecycle)
INIT/HANDOFF (wake ritual): (1) §0.2 integrity-check; (2) read role-<role>.md §A CORE — expert from line 1;
(3) §C VERIFY vs current code, mark stale; (4) read role charter + re-claim territory (§42.2) + read own inbox.
WORK: under coordination discipline (claims, binding .coord/cc/<role>.md, §4-review, native-CC, commit.lock).
CAPTURE: mandatory, as above. HANDOFF/REAP: ephemeral layer may die; the PERSISTENT role-skill carries forward; a
fresh incarnation reads it and is ALREADY expert.

## Scope tiers + PROMOTION GATE (PREVENT-BEFORE / fail-closed — hold the bar hardest here)
- Specialist + coordinator role-skills = PROJECT-scoped. Curator = AGNOSTIC.
- **DEFAULT-DENY** (mirrors AD AUTHZ-03): a lesson stays PROJECT-scoped BY DEFAULT. It does NOT enter the agnostic
  curator skill until the gate is AFFIRMATIVELY satisfied with PINNED evidence. No silent promotion. The agnostic tier
  is **append-ONLY-AFTER-PROOF**, never append-then-audit.
- **TWO-KEY promotion:**
  1. The proposing role marks a CANDIDATE in its project role-skill (`status: promotion-candidate`) — it STAYS
     project-scoped meanwhile.
  2. The CURATOR promotes to the agnostic tier ONLY after confirming, with evidence PINNED in the entry: (a) substrate-
     level proof (mount / git / protocol), OR (b) >=2 INDEPENDENT occurrences, each cited with a commit/journal pin FROM
     EACH project. Unproven -> stays project-scoped. A single-domain pattern is NEVER promoted (that path IS the
     cross-domain contagion vector; over-generalization = contamination).
- The async curator audit is a SECONDARY backstop (catch slips), NOT the primary gate. The gate stops the contagion
  BEFORE it crosses, not after it crossed.

## §C VERIFY — WRITE-TIME GATE (NORM-CUR-11c, peer-review Маяк)
A broken verifier is WORSE than none: a §C check that FAILS against correct code FALSELY marks a TRUE truth superseded —
defeating the anti-rot purpose (real defect: role-backend §C#1 grep `CREATE PROCEDURE`=2 vs `CREATE OR REPLACE PROCEDURE`=15).
- Every §C VERIFY check MUST be EXECUTED ONCE at AUTHORING time and confirmed to return its EXPECTED result BEFORE the role-skill
  is committed. A §C line that does not pass against the CURRENT code at write-time does NOT ship.
- §4-REVIEW REJECT item: any §C check not run-green at authoring -> verdict REVISE, not PASS. (Mirrors cold-start "from artifacts":
  do not ship a self-check you did not run, same as you do not ship a truth you did not pin.)
- When §C later FAILS at init, treat it as a SIGNAL the code drifted (or the check needs updating) — investigate; do NOT blindly
  supersede a truth on a check you never proved correct.
