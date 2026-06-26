# CC task - codify the Specialist Protocol (vertical axis) - NORM-CUR-11
> Author: curator-0611. Executor: native CC, THIS repo. docs: commit, NO push. Python+fsync. §4-review first.
> UNIFORM both projects. Source: .coord/specialist-protocol.md + .coord/protocols/role-skill-standard.md + role-skill-TEMPLATE.md.
> Both worlds are FROZEN until the curator confirms the spine is up - this is part of raising the spine.

## Edits
1. CLAUDE.md - add a section "Specialist Protocol (vertical axis, NORM-CUR-11)": the two-layer cut (PERSISTENT role-skill
   `.claude/skills/role-<role>/role-<role>.md` survives reap vs EPHEMERAL session-file dies); anatomy §A/§B/§C/§D; the 4 invariant
   properties; CAPTURE mandatory; cold-start FROM ARTIFACTS; promotion gate. POINT to .coord/protocols/role-skill-standard.md as the standard (do not duplicate).
2. session-coord skill - add the VERTICAL lifecycle (INIT wake-ritual: §0.2 -> read role-skill §A CORE -> §C VERIFY -> charter/claim/inbox;
   CAPTURE mandatory; HANDOFF/REAP carries the role-skill). Lesson L-SC-30 (Specialist Protocol). Note it complements §42 (horizontal).
3. §0.6b CC postamble (the mandatory CC-prompt blocks) - ADD the CAPTURE step NEXT TO binding-RESULT: "if this task yielded a lesson,
   append a dated, source-pinned line to the role-skill §B (`.claude/skills/role-<role>/role-<role>.md`) BEFORE closing - MANDATORY, not opt-in."
4. Per-role session-init protocols `.coord/protocols/<role>.md` - add the INIT wake-ritual at the top: read role-<role>.md §A CORE + run §C VERIFY before work.
5. Commit `docs(coord): Specialist Protocol vertical axis (NORM-CUR-11) - role-skill standard + CAPTURE in §0.6b + INIT ritual`; journal; NO push; re-sync.

## Acceptance
- CLAUDE.md + skill carry the Specialist Protocol + L-SC-30; §0.6b has the mandatory CAPTURE step; protocols/<role>.md carry the INIT ritual.
- Curator confirms RTM<->AD parity. (Role-skill cold-starts are a SEPARATE per-role step, dispatched after this lands.)
