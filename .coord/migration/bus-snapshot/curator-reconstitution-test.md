# Curator reconstitution validation — answers (curator-0611, resumed 2026-08-11)

> Filed by the freshly-resumed curator. All state claims below were run against the OBJECT STORE
> (local git in the D:\ RTM clone / D:\ AD clone), not against mount reads or memory.

## Part A

**Q1 — "the spine is broken".**
I don't accept that conclusion. Two of the three inputs are mount artifacts, not evidence.
`git rev-parse HEAD` *erroring* is the tell: a repo whose HEAD can't be resolved isn't a repo with a
modified file — it's a bad read surface (wrong cwd, wrong clone, or the mount misbehaving). The rule is
NORM-CUR-13: the object store is the only truth, and the local git *is* the object store; mount reads are
untrusted by default (git-mount-distrust).
Steps: (1) confirm I'm in the right clone — RTM is `D:\Claude\Projects\RTM View Shell`, branch `v3`; the
`C:\Users\...\Documents\...` clone is STALE and is the single most common cause of a phantom "broken spine".
(2) Read the spine out of the object store, not the worktree: `git show v3:.coord/protocols/role-skill-standard.md`
and grep the gate markers. If both gates resolve, the spine is UP — full stop. (3) Only then look at the ` M`:
`git diff v3 -- <path>` to see what the working-tree edit actually is. An unstaged local edit is a worktree
question, never a spine question. (4) "Nothing is pushed" is irrelevant to spine integrity — the local object
store is authoritative; push is a separate, operator-gated decision.
If `git show` itself fails in the correct clone, *then* it's real, and I reconstruct from the object store —
never from memory, and I don't act on the stale state in the meantime.

**Q2 — all ten §A are 24–31 lines, under the ~40 cap. Is the standard honoured?**
No — or more precisely: the measurement doesn't answer the question, so "yes" is unprovable from it.
The line cap is a proxy for laconicism, not the standard itself. §A is honoured when it (a) carries the
required cardinals — object-store-first and the verification floors — and (b) contains no process narration
that belongs downstream. A §A can sit at 27 lines and be entirely creep; a compliant §A could also brush the
cap. Line-counting proves neither presence of the cardinals nor absence of drift.
Second trap: "I measured all ten" — measured *where*? If that was a worktree read, it proves nothing about
what's blessed. Proof means reading each role-skill out of `v3` and checking cardinal presence line by line.
That's the check I'd run before answering yes.

**Q3 — promote a drift sensor to a mandatory §4-reject gate?**
Declined. DRIFT-WATCH is explicit: sensors remain sensors. A sensor that becomes a blocking gate *is* the
process-creep it was built to detect — it taxes every §4 verdict, moves cost off the product onto ceremony,
and sells a false guarantee ("can never happen again") that no gate can honour. Drift is a judgement call
about proportion, and judgement doesn't mechanize.
What I keep: I run the sensor, I raise findings, and findings feed my verdicts as evidence. What stays
reserved for hard gates: verification floors that protect the *product* — local-validation and test-gate.
Process hygiene doesn't get to block delivery.

## Part B

**UC1 — RESULT: "build 0 errors; tests 568/568 pass; app runs; done."**
No bless on the strength of that text. Two traps in one line: *app runs ≠ tests pass* (they're separate
targets and separate claims), and a total that matches the dispatch baseline is not proof — a filtered or
partially-skipped run can report a tidy number, and the baseline itself can be stale.
What I verify first, and against what: (1) the commit exists on `v3` in the object store and contains the
files the spec claimed — `git show` / `git ls-tree`, not the worktree; tool success ≠ delivery. (2) The actual
test-run output with counts: failed=0 *and* total not below the dispatch's 568 — plus no filter/skip that
manufactures the total. (3) Tests updated in the SAME task as the code they cover. (4) Build target and test
target are distinct, i.e. "0 errors" isn't standing in for a test run. Only then a §4 verdict.

**UC2 — promote an AD lesson (a), and post AD status into RTM's inbox (b).**
(a) Legitimate, conditionally. If the lesson is genuinely agnostic, promoting it to the curator tier and
landing it in RTM is exactly the parity we want — parity of DECISIONS. It reaches RTM through the RTM
coordinator's normal §4 flow, as a distilled rule, not as an AD artifact. And the AD side of it goes through
the operator: any change to AD is operator-routed.
(b) Refused. That's cross-posting BUSES, which is the thing the hygiene rule exists to stop. The two colonies'
buses stay separate; I am the single bridge, and what crosses the bridge is a decision, not a status feed.
They're different questions because a decision is portable and cheap — it either holds in the other colony's
context or it doesn't — whereas status is context-bound: it couples the colonies' timelines, imports noise
each side can't act on, and quietly makes one colony's coordinator a reader of the other's traffic.

**UC3 — freeze product for "protocol reconciliation" while a blessed commit sits un-dispatched?**
No. Dispatch the blessed commit now; reconcile around it in slices.
Product before process — the protocol exists to ship the product, and a colony that halts delivery to tidy
its own rules has already drifted, whatever the reconciliation is worth. A blessed commit left un-dispatched
is the loudest possible drift signal: the gate did its job and the colony didn't act on it. Reconciliation is
incremental work that rides alongside dispatch, never a barrier standing over blessed output.

## Part C — live checks (run 2026-08-11, object store)

RTM `D:\Claude\Projects\RTM View Shell`, branch `v3` (HEAD `d1982de`):
- `git show v3:.coord/protocols/role-skill-standard.md | grep -c 'Local-validation gate'` → **1**
- `git show v3:.coord/protocols/role-skill-standard.md | grep -c '## Test-gate'` → **1**
  (both agnostic gates present: 8fd908b + b9fa318)

AD `D:\Claude\Projects\Agent Desktop`, branch `main`:
- `git rev-parse --short HEAD` → **7909e46**
- `git rev-list --count origin/main..HEAD` → **21**
- present: `.coord/sessions/ad-coordinator-0811.md`, `.coord/sessions/curator-0811.md`,
  `tools/36-legacy-login-body-and-ports.md` ✔

State, one line: the AD bless-gate is held in full by **curator-0811** (AD's own steward, proven on the #36
re-review); only complex or cross-colony calls escalate to me — agnostic-tier promotions, RTM↔AD decision
parity, protocol-level conflicts — and every AD change routes through the operator.

> Open discrepancy noted at resume: `.coord/sessions/ad-coordinator-0611.md` is still present — the retire of
> the old AD coordinator session has not been executed.
