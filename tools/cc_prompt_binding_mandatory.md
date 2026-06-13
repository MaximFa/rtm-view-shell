# CC task - make the CC<->spec BINDING mandatory in the §0.6a template (NORM-CUR-07c)
> Author: curator-0611. Executor: native CC in THIS repo. docs: commit, NO push. Python+fsync (§0.3). §4-review first.
> UNIFORM (NORM-CUR-01): the OTHER project applies the identical change. Wording/template change, no mechanism change.

## Why
The binding is documented (NORM-CUR-07) but binding-open is OPT-IN per prompt today (only prompts the coordinator hand-included
it in create a binding). Make it MANDATORY in the CC-prompt template so EVERY CC prompt opens a binding + writes a RESULT.

## Edits
1. CLAUDE.md §0.6a (the mandatory CC-prompt blocks): add a MANDATORY BINDING block, placed RIGHT AFTER the integrity block:
   PREAMBLE - OPEN BINDING: append a BINDING block to .coord/cc/<role>.md (status: open, directive ref).
   POSTAMBLE - WRITE RESULT into the binding at the end (commits/build-test/files/status/blockers/object-store verify); status done|failed.
   Note: the binding is an INDEX to git (same-mount L-SC-04 read-loss possible), NOT a source of truth; if the RESULT write is
   dropped, the spec reconciles from the object store / the build artifact (NORM-CUR-07b git-fallback). For no-repo/server contexts
   (bash blind to .coord/): emit a result-artifact + operator-relay backstop.
2. skill §10 - коорд: промпт: drafted prompts MUST include the binding preamble/postamble (no longer optional).
3. Lesson L-SC-28 / note NORM-CUR-07c.
4. Commit docs(coord): binding mandatory in §0.6a template (NORM-CUR-07c); journal; NO push; re-sync.

## Acceptance
- §0.6a carries the mandatory binding preamble/postamble (after the integrity block); skill коорд: промпт requires it.
- Curator confirms RTM<->AD parity after both apply.
