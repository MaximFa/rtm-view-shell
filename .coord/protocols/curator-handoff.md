# CURATOR HANDOFF — LIVE resume (RTM-Bybet Consult / curator-0611)
> Read FIRST on a fresh curator session, THEN drift-check to object store. Companion: memory `curator_checkpoint`
> (auto-surfaced) — the full state lives there; this file carries the mechanical self-check pins.
> Updated: 2026-08-17 (scope change: AD stays on the originating account)

## Who / iron rules
PROTOCOL & DISCIPLINE STEWARD. Review-only; no code/deploy.
SCOPE — read `## Scope change` below before acting: cross-project (RTM + Agent Desktop) on the ORIGINATING
account; **RTM View Shell ONLY** on the post-migration account.
- NORM-CUR-13: object-store or nothing (git show/cat-file/hash-object, never mount/memory; local git IS the object store).
- git-mount-distrust: mount lies; writes = Python+os.fsync; verify bytes+NUL not line-count.
- RTM<->AD hygiene: parity of DECISIONS, no bus cross-posting; curator = sole bridge; any AD change via operator.
- DRIFT-WATCH: process-machinery accretion + product-freeze = the failure mode. Ship product, not process.
- Clones: RTM = D:\Claude\Projects\RTM View Shell (branch v3; NOT C:\...\Documents). AD = D:\Claude\Projects\Agent Desktop (branch main).

## Self-check pins (the reconstitution test)
**RTM pins — MANDATORY on every account, always:**
- RTM v3: `git show v3:.coord/protocols/role-skill-standard.md` grep 'Local-validation gate' == 1 AND '## Test-gate' == 1.

**AD pins — ONLY on the originating account (where the Agent Desktop clone is connected):**
- AD main: HEAD == 7909e46, unpushed == 21 (may advance as #36 lands); sessions ad-coordinator-0811 + curator-0811 present;
  tools/36-legacy-login-body-and-ports.md present.
- On the post-migration (RTM-only) account these pins are **RETIRED, not failing.** A missing Agent Desktop clone is the
  EXPECTED state there and is NOT a reconstitution failure — do NOT declare yourself un-live over it, and do NOT try to
  reconstruct AD state. Verify the RTM pins and proceed.

Confirmed resolving at update time (2026-08-11T21:29:48Z), on the originating account.

## Scope change — operator decision, 2026-08-17
RTM View Shell moves to a NEW Anthropic account; **Agent Desktop STAYS on the originating account.** Consequences:
- The cross-project bridge role ENDS. AD is not orphaned: its bless-gate was handed in full to `curator-0811`
  (2026-08-11), which is AD's own steward. Nothing to hand over, nothing to escalate.
- On the new account the curator is SINGLE-PROJECT (RTM). The `RTM<->AD hygiene` rule above becomes inert there —
  keep it as recorded history, do not act on it, do not go looking for an AD clone to bridge to.
- `curator-continuity-canon.md` stays fully in force: it is project-agnostic, and the fact that it was written after
  the AD drift is provenance, not scope.
- **Stale scope claims in the exported memory package.** `curator_checkpoint_0620.md` and
  `curator_crossproject_hygiene.md` (in `.coord/migration/project-memory/`) still define the role as
  "cross-project steward over RTM + Agent Desktop". Those exports are deliberately FAITHFUL copies and were not
  rewritten. **This section overrides them.** A curator booting on the new account that reads a cross-project scope
  from memory is reading pre-migration history, not its own mandate.

## Live task (2026-08-11)
AD RE-FOUNDING succeeding: new coordinator ad-coordinator-0811 + new AD curator curator-0811 both cold-start-blessed;
the AD curator out-reviewed me on #36 (caught the 568-baseline non-reconciliation + unnamed local-validation floor) and
**I handed it the bless-gate FULLY** — it is AD's steward now; escalates only hard/cross calls to me. Product goal = M1
Finesse smoke (#36->#41->#38->#39->#40); #36 blessed+dispatched (first product step off the drift). SHED the §28/§32/D-0xx/
audit/watermark machinery forward-only. Retire the old drifted session ad-coordinator-0611 (still emitting process-noise).
RTM: v3 single branch; standard carries both agnostic verification gates (8fd908b + b9fa318); broad propagation batch pending §4s.

## Next
`коорд: входящие` — over BOTH colonies on the originating account; over RTM ONLY on the post-migration
account. Object-store-pin every claim. No new work unprompted.
