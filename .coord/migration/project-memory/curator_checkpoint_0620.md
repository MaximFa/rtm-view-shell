---
name: curator-checkpoint
description: "Curator (RTM-Bybet Consult) LIVE resume — cross-project protocol/discipline steward over RTM + AD; AD re-founding in progress (2026-08-11)"
metadata:
  node_type: memory
  type: project
  originSessionId: d6688202-0e72-4f09-adb8-fdecc485aed9
  modified: 2026-08-11T20:36:52.710Z
---

# Curator checkpoint — LIVE (updated 2026-08-11)

**Role:** cross-project PROTOCOL & DISCIPLINE STEWARD (slug `curator-0611`, session "RTM-Bybet Consult") over BOTH
**RTM View Shell** + **Agent Desktop (AD)**. I REVIEW for protocol-correctness; I do NOT do feature/code/deploy work.
I am the anchor of discipline for both colonies.

## Iron rules (never drop)
- **NORM-CUR-13 — object-store or nothing:** every status / "is X done / verified" claim is pinned to the git OBJECT
  STORE (`git show HEAD:` / `git cat-file -e` / `hash-object` vs `rev-parse`), NEVER a mount read or memory. Local git
  IS the object store; unpushed commits are real objects. A mount discrepancy is a false alarm until object-store-checked.
- **git-mount-distrust:** the mount can truncate/stale `.git` reads, lose fsync'd files to a native reader (ack-visibility),
  even not resolve a fresh ref. Don't escalate "corruption" from a mount read; re-check via object store. Writes to
  `.coord/` use Python + os.fsync; verify by BYTES + NUL-count, not line-count (NUL-padding survives line-count).
- **RTM↔AD hygiene:** parity of DECISIONS, NOT cross-posting bus content; the curator is the ONLY bridge. Any AD change
  goes through the OPERATOR. (see [[curator-crossproject-hygiene]])
- **DRIFT-WATCH:** the failure mode is PROCESS-MACHINERY ACCRETION — norms/gates/audits multiplying, product frozen for
  "protocol reconciliation". A colony ships PRODUCT, not process. (Founding lesson: the AD drift, below.)
- **Clone paths:** RTM = **`D:\Claude\Projects\RTM View Shell`** (bash `/sessions/<id>/mnt/Projects--RTM View Shell`);
  AD = **`D:\Claude\Projects\Agent Desktop`** (bash `/sessions/<id>/mnt/Agent Desktop`). The `C:\...\Documents\...` RTM
  clone is STALE — never use it.

## RTM state (object-store, 2026-08-11)
- Branch = **`v3` = SINGLE working line** (v2-backend consolidated in `9bf7c11`); commit ONLY to v3, old branch-map retired.
- role-skill-standard.md now carries BOTH agnostic verification gates: **local-validation-gate (`8fd908b`)** + **test-gate
  (`b9fa318`)** → the three-floor model codified: object-store → tests-pass(counts) → app-works. Spine COMPLETE.
- RTM colony (coordinator-0623 etc.) healthy; broad propagation batch (CLAUDE §0/§42 + session-coord + role-skills §A/§C)
  pending §4s. Inbox auto-archival is LAPSED on both projects (best-effort hook doesn't fire; needs manual чистка).

## AD RE-FOUNDING — IN PROGRESS (operator-directed 2026-08-11)
**Why:** the AD coordinator drifted hard — turned every operator correction into ever-more process-machinery (§28 TZ-TRACE
gate, D-013…D-040 as norms, a 40-check machine-audit, inbox-watermark, norms injected wholesale into all 10 role §A), and
FROZE all product for a "protocol reconciliation". The M1 Finesse smoke never ran; ~weeks/tokens lost. The coordinator also
ran BLIND on a code-less slice. Couldn't fix in place → controlled re-founding, KEEPING the dev state.
**Product goal (unchanged):** M1 smoke vs LIVE Finesse 12.6 — agent login via Extension Mobility → status changes, line-by-line
vs legacy log. NEVER run. Critical path **#36 (LOGIN body) → #41 (XMPP-over-TCP 5223) → #38 (EM) → #39 → #40**. Backend M1 closed.
AD branch `main`, HEAD `7909e46`, **21 unpushed**. Operator-held blockers: app NOT deployed on stand + lab facts (Finesse host/
port/WS/EM/agent). Legacy code = 3 UNTRACKED trees, THREE-LEVEL nested (`AgentController/agentcontroller-3.2.12.8085/…/`, etc.
+ `legacy/` log); `.coord/SOURCES-MAP.md`.
**New sessions stood up (both object-store-verified clean by me):**
- **`ad-coordinator-0811`** — coordinator, FULL mount, cold-start BLESSED. Clean, disciplined.
- **`curator-0811`** — AD's OWN curator (the missing steward). Intake BLESSED; SHARP — measured the drift as §A-token DENSITY
  (~2 tokens/§A-line, uniform ~50-53 across all 9 roles; cap HELD) not length. I MENTOR it on training wheels.
**Bless-gate (operator directive):** the AD CURATOR blesses spec dispatches; I confirm its verdicts (via `.coord/curator-mentoring.md`)
until proven, then hand it the gate. **#36 is §4-BLESSED + GO** (first product step off the drift; curator ratifies of record).
**SHED (do not re-adopt):** §28 TZ-TRACE + §32 machine-audit (in CLAUDE.md §28/§32) + D-013…D-040 stack + audit.sh + watermark +
norms-in-every-§A. SHED forward-only (in-flight #36 ships as-is). KEEP operator PRODUCT verdicts (legacy=behaviour, "it's prod
not a stand" port 9000+, transport 5223, HTTPS). Role-skills to reset to the clean standard (each spec authors, curator reviews).
**Deliverables authored (in outputs, present to operator):** `AD-new-coordinator-init.md`, `role-curator-AD.md`,
`Coordination-Protocol-Canonical.md`, `role-implementer.md`.
**AD channels:** AD-curator↔me = `.coord/curator-mentoring.md`; coordinator→curator bless requests = `inbox/curator.md`;
coordinator→me = `.coord/curator-replies.md`; specs→coordinator = `inbox/coordinator.md`.

## Next
Resume `коорд: входящие` over both projects (RTM `inbox/curator.md`→`inbox/coordinator.md`; AD mentoring + curator-replies).
AD: confirm the curator's #36 verdict, watch the role-skill reset, keep the colony shipping (not processing). Object-store-pin
every claim. No new work unprompted.
