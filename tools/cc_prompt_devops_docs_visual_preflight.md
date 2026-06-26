# CC Task — docs: persist Visual-Test-Preflight runbook + 9 role-skill §B refs

> Branch: **v3** · Role: **devops** · Commit prefix: **docs:** · NO push (§37)
> **§4-REVIEW: PASS** (coordinator-0624 2026-06-25T15:40Z). Persist-only, 10 files (docs/Visual-Test-Preflight.md + 9 role-skill §B refs I authored). Truncation-guard verified (all 9 role-skills GREW vs HEAD, none truncated; STOPs if any WT<HEAD with RE-APPLY not restore-from-HEAD — correct, preserves the §B edits); excludes the unrelated Installations/ deletions (narrow-add by name, post-commit Installations grep=0); docs:, NO push. CLEARED TO RUN.
> Author: devops-0624 · Status: awaiting §4 (`коорд: ревью`) bless before run
> Scope authorization: cross-claim (docs/ + .claude/ = docs-claim) DIRECTED by coordinator-0624
> (journal 2026-06-25T12:10Z: "docs-persist CC commit must cover all 9 role-skills"). Coordinator
> authored the role-skill §B edits; this task only STAGES + COMMITS them alongside the new doc.

---

## STEP 0 — MANDATORY

### 0a. Mandatory reads (§40 / §0.8)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-devops/role-devops.md` (§A + §C)

### 0b. Branch + integrity (object-store, NOT mount git status)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git checkout v3
cat .git/refs/heads/v3
```

**Truncation guard (PD-007) — these files legitimately DIFFER from HEAD; do NOT restore from HEAD.**
The 9 role-skills GREW (a §B ref was appended); the doc is NEW. Verify each is INTACT, not truncated:
```bash
# (1) new doc must exist + end properly
tail -2 docs/Visual-Test-Preflight.md          # must end with the revision-history row, not mid-line
# (2) each role-skill working-tree line count must be >= its HEAD count (refs were ADDED, never removed)
for f in .claude/skills/role-backend/role-backend.md .claude/skills/role-bi/role-bi.md \
         .claude/skills/role-coordinator/role-coordinator.md .claude/skills/role-curator/role-curator.md \
         .claude/skills/role-dba/role-dba.md .claude/skills/role-devops/role-devops.md \
         .claude/skills/role-incident/role-incident.md .claude/skills/role-shell/role-shell.md \
         .claude/skills/role-test/role-test.md; do
    head=$(git cat-file -p HEAD:"$f" | wc -l); wt=$(wc -l < "$f")
    if [ "$wt" -lt "$head" ]; then echo "TRUNCATED (WT<HEAD): $f ($wt<$head) — STOP, flag coordinator (do NOT restore from HEAD, it loses the §B edit)"; fi
    tail -1 "$f"   # must be a proper closing line, not mid-word/mid-table
done
# Expected HEAD->WT: backend 62->63, bi 50->51, coordinator 80->91, curator 42->43, dba 53->54,
#                    devops 49->50, incident 40->41, shell 75->88, test 39->48.
```
If ANY role-skill is shorter than HEAD or ends mid-line → **STOP**, do not commit, flag coordinator
(the §B edit must be re-applied by coordinator; restoring from HEAD would erase it).

### 0c. Freeze check
```bash
[ -s .coord/push/request.md ] && { echo "PUSH BARRIER ACTIVE — STOP"; exit 1; } || echo "no freeze, proceed"
```

### 0d. Binding PREAMBLE → `.coord/cc/devops.md` (Python + os.fsync)
```
## <UTC> | binding: devops <-> CC | directive: tools/cc_prompt_devops_docs_visual_preflight.md | status: open
### DIRECTIVE: docs-persist Visual-Test-Preflight.md (new) + 9 role-skill §B refs (coordinator-authored). Claims: docs/Visual-Test-Preflight.md + 9 .claude/skills/role-*/role-*.md. Prefix: docs:. Cross-claim authorized by coordinator.
```

---

## TASK — stage + commit (NO content edits)

This is a **persist-only** commit. Do NOT edit any file content. Stage exactly these **10** files
by name (NARROW-ADD — NO `git add -A`, NO `git add .`; the working tree also contains UNRELATED
`D Installations/03062026/...` deletions that MUST NOT be included):

```
docs/Visual-Test-Preflight.md
.claude/skills/role-backend/role-backend.md
.claude/skills/role-bi/role-bi.md
.claude/skills/role-coordinator/role-coordinator.md
.claude/skills/role-curator/role-curator.md
.claude/skills/role-dba/role-dba.md
.claude/skills/role-devops/role-devops.md
.claude/skills/role-incident/role-incident.md
.claude/skills/role-shell/role-shell.md
.claude/skills/role-test/role-test.md
```

(role-skills are tracked — they show as ` M`, so a plain `git add` works; no `-f` needed.)

## COMMIT (native CC, commit.lock serialized)
```bash
# 1. acquire commit.lock (Python open(path,"x"); retry 5×60s; never auto-delete a stale lock)
# 2. pre-commit truncation check on all 10 files
bash tools/pre-commit-check.sh docs/Visual-Test-Preflight.md \
  .claude/skills/role-backend/role-backend.md .claude/skills/role-bi/role-bi.md \
  .claude/skills/role-coordinator/role-coordinator.md .claude/skills/role-curator/role-curator.md \
  .claude/skills/role-dba/role-dba.md .claude/skills/role-devops/role-devops.md \
  .claude/skills/role-incident/role-incident.md .claude/skills/role-shell/role-shell.md \
  .claude/skills/role-test/role-test.md
# If exit 1 -> STOP (truncation), flag coordinator.
# 3. NARROW-ADD by name (the 10 files above), then commit
git add docs/Visual-Test-Preflight.md \
  .claude/skills/role-backend/role-backend.md .claude/skills/role-bi/role-bi.md \
  .claude/skills/role-coordinator/role-coordinator.md .claude/skills/role-curator/role-curator.md \
  .claude/skills/role-dba/role-dba.md .claude/skills/role-devops/role-devops.md \
  .claude/skills/role-incident/role-incident.md .claude/skills/role-shell/role-shell.md \
  .claude/skills/role-test/role-test.md
git commit -m "docs: Visual-Test-Preflight canonical runbook + 9 role-skill §B refs [devops]"
# 4. post-commit verify (object-store)
git show --stat HEAD            # EXACTLY 10 files; 1 new (doc) + 9 modified; ZERO Installations/ entries
git show --stat HEAD | grep -c "Installations/"   # MUST be 0
# 5. journal append + release commit.lock (Python+fsync)
```
**NO `git push` (§37).**

## §0.6b Binding POSTAMBLE → `.coord/cc/devops.md`
```
### RESULT:
- commit: <hash> docs: Visual-Test-Preflight ...
- files: 10 (docs/Visual-Test-Preflight.md new + 9 role-skills §B); ZERO Installations/ included
- object-store verify: yes — <hash> in git log HEAD; git show --stat = 10 files, Installations grep=0
- status: done
- NO push
```

## §0.7 re-sync (LAST action — all 10 from HEAD)
```bash
for f in docs/Visual-Test-Preflight.md \
  .claude/skills/role-backend/role-backend.md .claude/skills/role-bi/role-bi.md \
  .claude/skills/role-coordinator/role-coordinator.md .claude/skills/role-curator/role-curator.md \
  .claude/skills/role-dba/role-dba.md .claude/skills/role-devops/role-devops.md \
  .claude/skills/role-incident/role-incident.md .claude/skills/role-shell/role-shell.md \
  .claude/skills/role-test/role-test.md; do git show HEAD:"$f" > "$f"; done
sync
```

---

## Acceptance criteria
- [ ] STEP-0 reads + branch v3 + truncation guard (no role-skill WT < HEAD; doc ends properly)
- [ ] NO file content edited (persist-only)
- [ ] EXACTLY 10 files staged by name; ZERO `Installations/` (or any other) paths included
- [ ] commit `docs: Visual-Test-Preflight canonical runbook + 9 role-skill §B refs [devops]` on v3
- [ ] `git show --stat HEAD` = 10 files (1 new + 9 modified); `Installations/` grep = 0
- [ ] binding RESULT written; journal appended; commit.lock released; §0.7 re-sync done
- [ ] NO push
