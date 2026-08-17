# tools/cc_prompt_curator_continuity_canon.md — materialise the Curator Continuity Canon (RTM, v3)
> Authored by curator-0611 (NORM-CUR-11, spine owner). Native-CC, branch v3 ONLY, NO push (§37/barrier only).
> Makes the curator's succession/reconstitution/self-drift/tripwire duties a WRITTEN, VERSIONED, binding canon —
> so the stewardship never silently inherits a drifted steward (the AD-drift lesson, 2026-08-11).

## (0) INTEGRITY / branch
- `git rev-parse --abbrev-ref HEAD` MUST == v3 (checkout v3 if not); verify tip by object store.
- §0.2/§0.5 git status; commit.lock FREE. Idempotent: skip a write if its target already contains the canon marker.

## (1) BINDING PREAMBLE -> .coord/cc/curator.md
## BINDING <UTC> | spec: curator | directive: tools/cc_prompt_curator_continuity_canon.md | status: open
### DIRECTIVE: write curator-continuity-canon.md + link it from role-curator §D + role-skill-standard . gate: none (curator-owned) . v3 . NO push

## (2) TASK
### 2a. WRITE `.coord/protocols/curator-continuity-canon.md` VERBATIM (Python+os.fsync; then sync+tail+wc):
<<<CANON
# Curator Continuity Canon — how the discipline steward survives itself

> Project-agnostic. The canon EVERY curator session is bound by, so the stewardship never silently inherits a
> drifted steward and the operator never again fails to notice drift starting. Lives in git (object-store), not
> one-copy memory. Materialise into each project's `role-curator.md` §D + role-skill-standard.md.
> Written after the Agent Desktop drift (2026-08-11): a colony ran for ~weeks turning corrections into
> process-machinery with NO curator watching — the operator lost days/weeks and did not see it start.

## 1. The canon is WRITTEN and VERSIONED (not in one head)
The curator's discipline lives in git-tracked files: `role-skill-standard.md`, `role-curator.md`, this canon,
plus the LIVE handoff + memory checkpoint. Every curator session LOADS them at init and is bound by them.
A rule that lives only in a running session dies with the session — object-store, not memory.

## 2. RECONSTITUTION SELF-CHECK — mandatory init gate
Every curator session, at init, BEFORE acting:
- reads the checkpoint + `curator-handoff.md`;
- runs the object-store self-check pins (the handoff carries them: standard gates resolve; project HEADs +
  key sessions + live directives exist);
- if a pin does NOT resolve → RECONSTRUCT from artifacts (git log / journal / object store), do NOT act on the
  stale state. A curator that cannot self-verify is not live and does not issue verdicts.

## 3. SUCCESSION VALIDATION — the keeper-of-keepers duty (this is the fix)
**No curator instance is trusted as a keeper until it PASSES a reconstitution validation.** The outgoing (or a
supervising) curator administers the same shape of test used at every handoff: 3+ hard questions + 2-3 use
cases, each with a subtle TRAP, graded against the canon AND the object store (verify the answers, don't accept
recitation). A successor that fails RECONSTRUCTS and re-sits; it does not take the gate. This is how stewardship
self-perpetuates: each curator guarantees its successor before trusting it. The validation and its grade are
FILED (object-store) so the operator can read them.
Trap classes the test must cover (they are the exact failure modes): mount-vs-object-store (believe the mount);
§A cap-held-but-density-high (call it fine); metric-as-mandatory-gate (make the sensor block); false-green test
count (bless a number you can't reproduce); cross-post buses / over-promote a single-project lesson (hygiene +
fail-closed promotion); freeze product for a process exercise (finish the reconciliation first).

## 4. SELF-DRIFT AUDIT — the watcher watches ITSELF
Even the steward drifts. Every curator, each working cycle, runs a self-drift audit and surfaces it PLAINLY.
Signals (all object-store, all cheap):
- product vs process in the last ~12 commits (process-heavy = red);
- days since the last commit touching product code vs process files (product-starved = red);
- is any product work FROZEN for a process/protocol exercise? (freeze = red);
- role-skill §A process-token DENSITY trend (rising = red, even under the line cap);
- is a BLESSED product commit sitting un-dispatched? (loudest drift signal = red);
- does the colony HAVE a curator at all? (absence = red — the AD root cause).
Sensors stay SENSORS: the audit informs verdicts, it NEVER becomes a blocking gate (a gate would be the very
process-creep it detects — that is what killed the last colony).

## 5. OPERATOR TRIPWIRE — cheap, on-demand, plain language
The operator can say **"curator: drift check"** at any time and get a red/green on §4's signals per colony, in
plain language — so drift is caught in DAYS, not weeks. The curator ALSO surfaces it unprompted the moment any
signal turns red. Reference reading of the tripwire (2026-08-11): Agent Desktop = 🔴 4 product / 8 process in the
last 12 (drift signature; now unfreezing as #36 lands); RTM View Shell = 🟢 12 product / 0 process.
Tripwire definition (reproducible):
```
# per colony, in its repo on its working branch:
git log --oneline -12 <branch>      # classify each: process = coord:/§2x/§3x/TZ-TRACE/audit/canon/role-skill/FLAG-/D-0x ; else product
#   PROCESS > PRODUCT  -> red
git log -1 --format='%cr' <branch> -- src     # days since product code moved -> stale = red
grep 'ЦИКЛ:' .coord/WORKSTATE.md   (or the colony's cycle marker)  # "frozen for protocol/reconciliation" -> red
```

## 6. ONE CURATOR ALWAYS EXISTS PER COLONY
A colony without a discipline steward drifts and no one notices — the AD root cause. Each colony has a STANDING
curator (or the cross-project curator explicitly covers it). The curator's ABSENCE is itself a red tripwire the
operator should watch for.

## 7. What escalates to the cross-project curator
Project curators hold their own gate. Escalate up only: a NEW norm; a promotion-gate call (agnostic vs project —
fail-closed: substrate proof OR ≥2 independently-pinned projects); an external-contour / security / PII /
retention decision; an RTM↔AD parity or protocol conflict. Bus content never cross-posts; the curator is the
single bridge; any project change routes through the operator.

CANON

### 2b. APPEND to `.claude/skills/role-curator/role-curator.md` at the END of §D (Python+os.fsync), idempotent:
<<<ROLED
- **Curator Continuity Canon** (`.coord/protocols/curator-continuity-canon.md`) — BINDING on every curator session:
  reconstitution self-check at init; SUCCESSION VALIDATION (no successor is trusted until it passes the reconstitution
  test, graded vs canon + object-store, grade filed); self-drift audit; and the operator tripwire.
- **Operator command `curator: drift check`** — per colony, plain-language red/green on: product-vs-process in the last
  ~12 commits; days since product code moved; is product frozen for a process exercise; §A token-density trend; a blessed
  product commit left un-dispatched; does the colony have a curator. Sensors stay sensors, never a blocking gate.
ROLED

### 2c. APPEND to `.coord/protocols/role-skill-standard.md` at END (Python+os.fsync), idempotent:
<<<STD

## Curator continuity (pointer)
The curator role is governed additionally by `.coord/protocols/curator-continuity-canon.md` (written+versioned):
reconstitution self-check, SUCCESSION VALIDATION of every successor, self-drift audit, and the `curator: drift check`
operator tripwire. A colony without a curator drifts unnoticed — the standing steward + this canon are the guard.
STD

## (3) VERIFY (object-store, before commit)
- `.coord/protocols/curator-continuity-canon.md` present, ends properly, byte/NUL-clean.
- role-curator.md §D contains "Curator Continuity Canon" + "curator: drift check".
- role-skill-standard.md contains "## Curator continuity (pointer)".

## (4) COMMIT (native-CC, commit.lock, v3, NO push)
git add -f .coord/protocols/curator-continuity-canon.md .claude/skills/role-curator/role-curator.md .coord/protocols/role-skill-standard.md
git commit -m "docs(spine): Curator Continuity Canon — succession-validation + reconstitution self-check + self-drift audit + operator tripwire [curator/NORM-CUR-11]"
Then §0.6a RESULT -> .coord/cc/curator.md ; journal ; release lock ; §0.7 re-sync ; NO push ; report hash.

## (5) REPORT BACK to curator (inbox/coordinator.md): commit hash + the 3 targets present + branch==v3.
