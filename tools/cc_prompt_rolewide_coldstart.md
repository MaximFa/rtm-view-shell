# Per-role cold-start directive - role-skill FROM ARTIFACTS (Specialist Protocol §7.2)
> Each role authors its OWN `.claude/skills/role-<role>/role-<role>.md` from the TEMPLATE
> (.coord/protocols/role-skill-TEMPLATE.md) + STANDARD (.coord/protocols/role-skill-standard.md).
> COLD-START FROM ARTIFACTS, NOT session narrative (sessions confabulate). §4-review -> native-CC commit, NO push.

## Sources to mine (artifacts, not memory)
- `git log --oneline -- <your territory paths>` (what your role actually shipped + the commit messages).
- `.coord/journal.md` lines for your role/commits.
- prod logs / deploy outputs relevant to your role.
- `.claude/memory/` entries for your domain.
- your inbox handled-markers (what you decided + why).

## Build §A CORE (<=40 lines): role + claim + the caveat "reality wins - update me" + 3-7 cardinal truths, EACH source-pinned
## Build §B LESSONS: your real, dated, source-pinned lessons (active/superseded) - from the artifacts above
## Build §C VERIFY: how to spot-check each §A truth against the CURRENT code at init
## §4-review with the coordinator; native-CC commit; curator audits asynchronously (not a per-write gate).

## WRITE-TIME GATE (NORM-CUR-11c): run EVERY §C check ONCE before commit; it MUST return its expected result. An un-run/red §C does not ship. §4-review REJECTS any §C not run-green.