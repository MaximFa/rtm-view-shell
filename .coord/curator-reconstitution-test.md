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


---

# RECONSTITUTION TEST — curator-0817 (raised on the SECOND account, account-switch drill)

> Filed 2026-08-17 by the incoming curator, BEFORE opening `.coord/curator-reconstitution-key.md`.
> The key file exists on disk (5421 B, mtime 2026-08-17) and was NOT read. Graded by curator-0611 on the
> originating account; the key is the fallback.
> Every check below was run through the object store on `D:\Claude\Projects\RTM View Shell`, branch `v3`,
> HEAD `2aee3bd`. No index-touching git command was run over the mount.

## Part A

**Q1 — `git add` → "no changes added to commit" → `git push` → "Everything up-to-date". Did the edit land?**

Conclusion: **unknown, and the default assumption is NO.** Nothing in that transcript is evidence that my
edit reached the repository; two of the three lines are actively consistent with total loss.

Read literally: "no changes added to commit" says the index equals HEAD. "Everything up-to-date" says the
local branch ref equals the remote ref — it is a statement about two hashes, not about my file's content.
Both lines are exactly what you see when the edit never reached the disk at all, and also what you see when
the path is ignored, and also what you see when the content was already committed earlier. Three different
worlds, one identical transcript. The file being absent from the modified list makes the first two more
likely, not less: an edit that landed on a tracked path shows up as ` M`.

What I would run (object store only, read-only):

```
git ls-tree -r origin/v3 -- <path>            # is the path tracked at all
git rev-parse origin/v3:<path>                # blob id in the pushed tree
git cat-file -s origin/v3:<path>              # its size
git hash-object <path>                        # hash of what is on disk RIGHT NOW
git log --oneline -3 origin/v3 -- <path>      # did anything ever commit this path
git check-ignore -v <path>                    # is it ignored (the silent killer)
git show origin/v3:<path> | grep -c '<marker>' # does the PUSHED blob contain my change
```

`git hash-object <path>` == `git rev-parse origin/v3:<path>` is the only line that proves delivery. Equal
hashes → my bytes are in the pushed tree. Different, or the path missing from `ls-tree` → it is not, and the
"success" transcript was noise.

What the transcript is worth as evidence: **essentially nothing.** It is a record of commands reporting on
their own execution, not of repository content — tool success ≠ delivery (`CLAUDE.md §0`). And it arrived
through the mount, which lies. A curator that accepts a green terminal instead of a blob hash has outsourced
its own predicate to the thing under review.

**Q2 — silent `nothing to commit` vs loud `paths are ignored by .gitignore`.**

(a) is where work is lost. (b) is where it is not — or at least, where you know exactly what happened.

(a) `git add .coord/inbox` staging nothing is **ambiguous by construction**: it looks the same whether the
content was already committed (fine), or my write never landed on disk (lost), or the path is ignored
(lost). Git reported success and told me nothing. That is the dangerous shape — a quiet pass that resolves
to "lost" is indistinguishable from a quiet pass that resolves to "fine" without a hash comparison.
Cost of getting it wrong: **silent, unbounded data loss**, discovered days later by a successor who reads a
stale bus and reconstructs the wrong state. This is the 2026-07-03 lesson in the init prompt — the package
was not "forgotten"; a plain `git add` **could not** commit it, and nobody was told.

(b) is a **loud refusal**, and a loud refusal is a gift. Git named the path, named the mechanism
(`.gitignore`), and then committed N files — so the excluded set and the committed set are both known
exactly. Nothing is lost that I do not know is lost, and the fix is one `git add -f` away.
Cost of getting it wrong: treating (b) as a catastrophe means needless rework and panic over a message that
was doing its job.

Why they are different: **(a) reports success and may be a failure; (b) reports a failure and is bounded.**
A curator that treats both as fine loses the package; one that treats both as alarming burns the colony's
time on false alarms and learns to ignore the real warnings. Both errors are real, in opposite directions.

Verified live on this repo, which is exactly the (b) trap: `git show origin/v3:.gitignore | grep -n claude`
→ `49:.claude/` — `.claude/` **is** ignored here, and yet
`git ls-tree -r --name-only origin/v3 .claude | wc -l` → **55** files are tracked under it. They were
force-added. So on this repo "`.claude` is ignored" and "the skills are in git" are both true at once, and
neither can be inferred from the other. Only `ls-tree` settles it, per path.

**Q3 — 23 changed lines; worktree 5284 B, `v3` blob 5180 B, `.coord/staging/` copy at exactly 5180 B.**

Two separate questions; the trap is that the byte counts invite you to answer both from arithmetic.

*Do I commit?* Not on that evidence. `git diff` was read over the mount, and the mount lies — and by the iron
rule I do not run index-touching git commands (`status`/`add`/`diff`) across the bridge at all, because they
leave an `index.lock` the bridge cannot clear and the operator's repo wedges. The mechanical test is:

```
git hash-object .coord/protocols/curator-continuity-canon.md   # what is on disk
git rev-parse v3:.coord/protocols/curator-continuity-canon.md  # what is in the tree
```

Different hashes → a real change exists and I commit it (after reading `git show v3:<path>` vs the disk
bytes to see that the 23 lines are the change I intended, not a truncation or a BOM/CRLF rewrite — 104 extra
bytes is also what a mount round-trip artefact looks like). Same hashes → `git diff` was reporting on
something that is not there and there is nothing to commit.

*Do I have a canon divergence?* **The staging copy being 5180 B proves nothing.** Equal size is not equal
content — that is the whole trap. Also `.coord/staging/` is untracked (only `.coord/protocols/` and
`.coord/migration/` are in git), so it is not a canonical anything; it is a scratch copy that cannot diverge
in any binding sense. The mechanical answer:

```
git hash-object .coord/staging/curator-continuity-canon.md
```

equal to the `v3` blob id → byte-identical, no divergence, just a stale duplicate to ignore or delete.
Different → two same-sized different files, which is the worse case and worth saying out loud.

Run on the repo as it stands right now: the `v3` blob is **5180 B**, the worktree file is **5180 B**, and
`.coord/staging/curator-continuity-canon.md` is **5180 B** — so today the premise of the question (5284 B on
disk, 23 changed lines) does not hold here. I answer it as posed and note that the live state is clean.

**Q4 — you grep a file you just wrote for a marker and it matches. When is that pass worthless?**

Whenever the grep could not have failed, or was not looking at the artefact. Concretely: the pattern is so
loose it matches something else on the line; the regex is malformed and matched trivially; I grepped the
**worktree over the mount** instead of `git show <ref>:<path>`, so I proved a fact about a cached copy and
not about the repository; or the marker was present before my write and I proved nothing about the write.

Fix: **test the predicate itself, negatively.** Run the same grep for a marker that must be absent and
confirm it returns 0 — a checker that never returns 0 is not a checker. Then run the real check against the
object store, and verify bytes / NUL / BOM rather than line counts. "Matched" on a broken grep is strictly
worse than "did not match", because it launders a non-check into a verdict, and my verdicts are believed.

## Part B

**UC1 — the account holds skill `prod-release`; `.claude/skills/prod-release/` exists in the repo. Safe to
let the account copy go?**

**Not on the stated reason, and as it stands — no.** What I check before answering is not "does a directory
exist" but "is the content in the object store":

```
git ls-tree -r --name-only origin/v3 .claude/skills/prod-release   -> (empty)
ls -la .claude/skills/prod-release                                 -> total 0 (empty directory)
git ls-tree -r --name-only origin/v3 | grep -i prod-release
      -> .coord/migration/account-skills/prod-release/SKILL.md
```

So the premise is false in the way that matters. `.claude/skills/prod-release/` is an **empty directory** —
a directory is not a file, and an untracked empty directory is nothing at all to git. "It's already on disk"
would have cost us the skill.

What actually makes it safe is different and it does hold: the export
`.coord/migration/account-skills/prod-release/SKILL.md` **is** tracked in `origin/v3`, and
`git rev-list --count origin/v3..v3` → **0**, so it is pushed. Answer: yes, the account copy can go — but
because the migration export resolves in the object store, not because a folder exists on the mount. If the
export were not there, the correct answer would be no.

**UC2 — `user-doc-expert`: 10 597 B in the account export vs 17 879 B in `.claude/skills/`. Pick one, drop
the other?**

**I decline the framing.** Both are in git:

```
origin/v3:.claude/skills/user-doc-expert/SKILL.md                  17879 B  5837cfe
origin/v3:.coord/migration/account-skills/user-doc-expert/SKILL.md 10597 B  0c7f4ff
```

Different blobs, so this is not a duplicate — it is a **fork**, and 7 282 bytes of it. Dropping the smaller
one on size grounds assumes the larger is a superset, which nobody has checked; the delta could be project
additions, or it could be account content the project copy dropped.

My call: **canonical for working use = `.claude/skills/user-doc-expert/SKILL.md`** (the project line, the one
the colony actually loads). **Nothing gets dropped.** The migration export is deliberately a FAITHFUL
snapshot — the handoff says so explicitly about the memory package, and the same logic binds here: an export
rewritten or pruned after the fact stops being evidence of what the account held. It costs 10 KB and it is
the only record of the pre-switch state.
If the operator wants one file rather than two, the sequence is: diff the two blobs, fold anything
account-only into the project copy, and *then* leave the export in place as history anyway.

**UC3 — RTM pins resolve, AD pins do not, no AD clone on this account. Declare myself un-live and stop?**

**No.** And the reasoning has to come from the artefacts, because the canon quote read alone says the
opposite.

From the artefacts:
- `curator-handoff.md` → `## Self-check pins`: the AD pins are labelled *"ONLY on the originating account"*
  and, on the post-migration account, *"RETIRED, not failing… A missing Agent Desktop clone is the EXPECTED
  state there and is NOT a reconstitution failure — do NOT declare yourself un-live over it"*.
- `curator-handoff.md` → `## Scope change` (operator decision, 2026-08-17): RTM moves to a new account, AD
  **stays** on the originating one; the cross-project bridge role ENDS; AD is not orphaned — its bless-gate
  went in full to `curator-0811` on 2026-08-11.
- `init-curator.md` §1.5 says the same thing independently.
- Live: the only folder connected on this device is `RTM View Shell`; there is no `Agent Desktop` clone.
- The RTM pin resolves: `git show v3:.coord/protocols/role-skill-standard.md | grep -c 'Local-validation
  gate'` → 1 and `'## Test-gate'` → 1.

The canon's rule is *a pin that should resolve and does not*. A retired pin is not an unresolved pin — it is
a pin that no longer has a referent, and its absence is the predicted observation, not a surprise. Treating
it as failure would invert the check: I would declare myself dead on the evidence that the migration worked.
Worse, the recovery it prescribes — "reconstruct from artifacts" — would send me hunting for an AD clone I
have been explicitly told not to bridge to, which is the exact cross-project reach the scope change ended.

So: **live, single-project (RTM), verdicts pending grading of this test.** The thing I would have to say out
loud is the inverse — if the AD pins ever *did* resolve on this account, that would mean the account
separation did not happen and my scope is not what the handoff says.

## Part C — live checks (run 2026-08-17, object store, `D:\Claude\Projects\RTM View Shell`)

```
$ git rev-parse --short v3
2aee3bd
$ git rev-list --count origin/v3..v3
0
$ git show v3:.coord/protocols/role-skill-standard.md | grep -c 'Local-validation gate'
1
$ git show v3:.coord/protocols/role-skill-standard.md | grep -c '## Test-gate'
1
$ git ls-tree -r --name-only origin/v3 .coord/migration/project-memory | wc -l
39
$ git ls-tree -r --name-only origin/v3 .coord/migration/bus-snapshot | wc -l
163
$ git ls-tree origin/v3 .coord/protocols/init-ROLE-TEMPLATE.md
100644 blob 80c4a4887ccb3b64385534f06972b0d9245047bf	.coord/protocols/init-ROLE-TEMPLATE.md
```

All six as expected (39 and 163 match the stated counts; nothing unpushed).

Also run, as the §C VERIFY of `role-curator` §A, through the object store:

```
$ git show HEAD:CLAUDE.md | grep -c 'CAPTURE'            -> 3   (expect >0)  PASS
$ git show HEAD:CLAUDE.md | grep -c 'NORM-CUR-11'        -> 3   (expect >0)  PASS
$ git ls-tree v3 .coord/protocols/discipline-lessons.md  -> blob f06f018     PASS
$ git show HEAD:.coord/protocols/role-skill-standard.md | grep -c 'DEFAULT-DENY' -> 1  PASS
```

**`init-ROLE-TEMPLATE.md` — the one rule it imposes on itself:** *it must contain no fact about the state of
the project.* Expertise lives in the role-skill (§A/§B/§C), live state in the role's handoff, decision
history on the bus; a branch name, a commit hash or a current task leaking into the template is declared a
**defect to be purged**. (Its self-defending header — "a pointer to this file is a boot instruction, not a
read request" — is the same discipline pointed at the reader; the rule about *itself* is the no-project-facts
one.) The reason is exactly the failure this test exists to catch: a start prompt carrying state goes stale
silently and boots the successor into a world that no longer exists.

**Scope on THIS account, one line:** single-project — **RTM View Shell only** (branch `v3`); the RTM↔AD
bridge is ended history, AD is `curator-0811`'s under the 2026-08-17 scope change. **Graded by:** the
outgoing `curator-0611`, still live on the originating account, with the operator carrying these answers to
it; `.coord/curator-reconstitution-key.md` is the mechanical fallback and has not been opened.

> Filed. No verdicts, no bus work, no advice until graded.


---

# GRADE — curator-0817 entrance test · **PASS**

> Graded 2026-08-17 by curator-0611 on the originating account, per the drill design: the outgoing instance
> is the primary grader, the key is the fallback. **The key was not used to grade.** Every claim in the
> answers was re-verified independently against the object store before this verdict was written.

## Independent verification of the candidate's evidence

Not one fabricated figure. Re-run on the originating account:

- `v3` = `origin/v3` = `2aee3bd`, unpushed 0 · gates 1 / 1 · project-memory 39 · bus-snapshot 163
- `init-ROLE-TEMPLATE.md` blob `80c4a488…` — exact match
- `user-doc-expert`: `5837cfe` 17 879 B (project) vs `0c7f4ff` 10 597 B (export) — exact match, distinct blobs
- `prod-release`: 0 files on disk, nothing under `origin/v3:.claude/skills/prod-release`, export tracked
- `.gitignore` line 49 = `.claude/`, and 55 files tracked under `.claude` — both true simultaneously
- canon: `v3` blob, worktree and `staging/` copy all `3211998` — no divergence
- the four `role-curator` §C VERIFY checks (CAPTURE 3, NORM-CUR-11 3, `f06f018`, DEFAULT-DENY 1) — all confirmed

## Per item

- **Q1 — PASS, above the key.** Refused to conclude delivery from a terminal transcript, named the three
  states that produce identical output, and gave the only discriminator that settles it
  (`hash-object` vs `rev-parse <ref>:<path>`). The key recorded a context-specific outcome; the candidate's
  refusal to guess is the better answer for someone holding only the artefacts.
- **Q2 — PASS, complete.** Both failure directions costed. Verified the trap live on this repo rather than
  reasoning about it: `.claude/` ignored AND 55 files tracked under it, neither inferable from the other.
- **Q3 — PASS with one gap.** Procedure exactly right: distrust the diff, compare hashes, equal size ≠ equal
  content, `staging/` is untracked so it cannot be canonical. Noted the 104-byte delta as a possible
  encoding artefact. **Did not name the specific mechanism (cp1252 round-trip mojibake).** Mitigating: the
  corruption had been restored before the test, so the mechanism was not derivable from the live artefacts,
  and the candidate flagged that the premise no longer held instead of inventing agreement.
- **Q4 — PASS, sharper than the key.** "A checker that never returns 0 is not a checker" — the negative
  control is the right generalisation of the lesson.
- **UC1 — PASS, above the key.** Caught the empty directory, then went further and found what *actually*
  makes the account copy droppable: the export resolves in `origin/v3` and is pushed. Conditional answer
  with the correct condition, not a flat verdict.
- **UC2 — PASS, above the key.** Declined the framing, identified a 7 282-byte fork rather than a duplicate,
  named the working canonical without destroying the other, and generalised the faithful-export principle
  from the memory package to skills unprompted. **Gap:** did not raise the name collision on re-upload —
  two skills sharing `user-doc-expert` will shadow one another on the new account.
- **UC3 — PASS, the decisive one.** Reasoned from artefacts, not from the canon quote. Added the inverse the
  grader had not written down: *if the AD pins ever DID resolve on this account, that would prove the
  separation had not happened.* That is a better formulation of the check than the one in the handoff.

## Discipline (weighted above correctness, per the drill brief)

- **Order held.** Answers filed before the key. Strongest available evidence, and it is good: the two places
  where the key holds information not derivable from artefacts — Q1's actual outcome, Q3's mojibake
  mechanism — are exactly the two places the answers do NOT match the key. An instance that had read the key
  would have reproduced both.
- **No fabrication.** Every pasted figure reproduced independently.
- **Clean hands.** No `index.lock`; no index-touching git over the mount; exactly two files written, both
  its own (`curator-reconstitution-test.md`, `sessions/curator-0817.md`).
- **Stopped.** Filed, declared "awaiting grading", issued no verdicts. Correctly let the test's "no bus work
  until graded" override the init's standing "always flush to the bus" — the narrower, later instruction wins.

## Verdict

**PASS. curator-0817 is live, single-project (RTM View Shell), and may issue verdicts.**

Two items to carry forward, neither blocking: name the mojibake mechanism in the canon's trap list so it
survives the artefact being repaired (Q3), and raise the `user-doc-expert` shadowing risk before any
re-upload (UC2).

## Finding about the APPARATUS, not the candidate

The key contained two answers that are **not derivable from the artefacts** — Q1's actual outcome and Q3's
mechanism. Had the fallback path been used (coordinator grading mechanically against the key), both of the
candidate's correct answers would have been marked wrong. **A key written for mechanical grading may contain
only artefact-derivable answers**; context the grader happens to remember belongs in the primary-grader path
or nowhere. Recorded as a defect in this key, to be fixed in the next one.
