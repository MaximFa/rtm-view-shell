# CC Task — PUSH: 45-green barrier -> origin/v2-backend (22 commits + curator protocols/ + barrier prompts)

> Authored by coordinator-0612. Push barrier quorum COMPLETE 8/8 (Security CLEAN, techwriter doc-sync, dba+curator+devops+shell+test-5+coord READY).
> This SUPERSEDES the stale tools/cc_prompt_push.md (which targets the WRONG branch `v2`, does broad `git add docs/ db/` that would commit
> PD-007-truncated WT over HEAD + sweep HELD techwriter drafts, and runs an unwanted Export-All). DO NOT use that one.
> Push IS allowed in THIS prompt (the only one, §37). Native CC only (Cowork mount cannot push, L-SC-20).

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md (§42.7 barrier, §0.2 integrity, §0.4 git workarounds)

## BINDING PREAMBLE (NORM-CUR-07c)
Append to .coord/cc/coordinator.md:
`## BINDING <UTC> | spec: coordinator-0612 | directive: tools/cc_prompt_push_45green.md | status: open`
`### DIRECTIVE: push 45-green barrier (22 commits) + docs-sweep (protocols/+barrier prompts) -> origin/v2-backend. NO Export-All. explicit adds only.`

## STEP 0 — integrity restore (dba PD-007 flag — CRITICAL)
db/migrations/_014/_015/_011/_013 + staging/45_*.sql working trees are PD-007 TRUNCATED; HEAD is CORRECT & already committed (609ba7a et al).
RESTORE them from HEAD so nothing truncated can be staged. Do NOT re-commit them (already at HEAD).
```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in db/migrations/20260613_011_45_table_drift_addcolumns.sql \
         db/migrations/20260613_013_sgag_unique_constraint.sql \
         db/migrations/20260613_014_schema_reconcile.sql \
         db/migrations/20260613_015_ngc_createsupergroup_overloads.sql \
         staging/45_hotfix_sgag_20260613.sql \
         staging/45_schema_reconcile_20260613.sql \
         db/functions/01_ngc_functions.sql; do
    [ -f "$f" ] && git show HEAD:"$f" > "$f"
done
sync
echo "_014 HEAD lines: $(git show HEAD:db/migrations/20260613_014_schema_reconcile.sql | wc -l) (expect ~323)"
git rev-parse --abbrev-ref HEAD   # MUST be v2-backend
```

## STEP 1 — docs-sweep commit (commit.lock; EXPLICIT adds ONLY — NO broad add)
Acquire commit.lock; stage ONLY these (curator §42.7 protocols/ + barrier CC prompts). NEVER `git add db/`, `git add staging/`,
`git add docs/`, `git add -A`, or `git add .` — those would commit PD-007-truncated WT over HEAD, HELD techwriter drafts, or root junk.
```bash
python3 -c "import os;f=open('.coord/locks/commit.lock','x');f.write('push-45green');f.flush();os.fsync(f.fileno());f.close()" || { echo "LOCK HELD - abort"; exit 1; }
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add .coord/.gitignore .coord/protocols/ 2>/dev/null
GIT_INDEX_FILE=/tmp/cc-idx git add tools/*.md tools/*.py tools/*.sh tools/*.ps1 2>/dev/null
GIT_INDEX_FILE=/tmp/cc-idx git diff --cached --name-only   # REVIEW: must be ONLY .coord/.gitignore, .coord/protocols/*, tools/* — NO db/ staging/ docs/ root-junk
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs(coord): track protocols/ norm-source (§42.7 curator flag) + barrier CC prompts — 45-green push (RTM-REL-2026.06)"
cp /tmp/cc-idx .git/index
rm -f .coord/locks/commit.lock 2>/dev/null
git log --oneline -1
```
If the `git diff --cached --name-only` shows ANYTHING under db/ , staging/ , docs/ , or repo-root — UNSTAGE it (`git reset <f>`) before committing. Only .coord/.gitignore + .coord/protocols/ + tools/ are intended.

## STEP 2 — pre-push verify
```bash
git log --oneline origin/v2-backend..HEAD | wc -l     # expect 23 (22 + the docs-sweep)
git show HEAD~0 --stat | head -20                      # the docs-sweep: protocols/ + tools/ only
# confirm the 4 db migrations in the push set are HEAD-correct (not truncated):
for c in 20260613_014_schema_reconcile 20260613_015_ngc_createsupergroup_overloads; do
  echo "$c committed lines: $(git show HEAD:db/migrations/${c}.sql 2>/dev/null | wc -l)"
done
git status --short | grep -E "^A|^D" || echo "(no stray staged adds/deletes)"
```

## STEP 3 — PUSH (origin/v2-backend — NOT v2)
```bash
git push origin v2-backend
```
If rejected (remote moved): `git fetch origin` then check `git merge-base --is-ancestor origin/v2-backend HEAD && echo FF-OK || echo DIVERGED-STOP`.
If FF-OK retry push. If DIVERGED -> STOP, report to coordinator (do NOT blind rebase). Do NOT push any other branch.

## STEP 4 — re-sync (PD-007) + report
```bash
for f in .coord/.gitignore $(git show --name-only --pretty="" HEAD); do [ -f "$f" ] && git show HEAD:"$f" > "$f"; done
sync
git log --oneline -3 ; git status --short | head
```

## BINDING POSTAMBLE (NORM-CUR-07c) -> RESULT into .coord/cc/coordinator.md
`### RESULT: pushed <oldtip>..<newtip> (N commits) to origin/v2-backend; docs-sweep commit <hash> (protocols/+tools/ only, verified no db/staging/docs broad-add); status done|failed; verified: git push output + git log origin/v2-backend`
Also append a journal PUSHED line: `<UTC> | <slug> | PUSHED origin/v2-backend <range> (N commits) — 45-green + protocols/`.

## DO NOT
- NO Export-All (schema.sql regen is a separate durable task, not this push).
- NO broad `git add`. NO secrets/passwords in any command. NO push to `v2`.
- Do NOT commit db/ , staging/ , docs/ , skills/ , tests/ WT (PD-007 drift / other sessions / HELD).
