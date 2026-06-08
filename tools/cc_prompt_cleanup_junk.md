# CC Task — cleanup: delete stray junk files from repo root (manual-clean request)

Session: RTM Session Sync | slug: `session-sync-0605`
Purpose: remove zero-byte / garbage files that the Cowork mount cannot unlink.
No commits in this task — files are untracked; commit.lock NOT needed.

## S1. Push barrier check
```bash
cd "D:\Claude\Projects\RTM View Shell"
if [ -f ".coord/push/request.md" ]; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md; exit 1
fi
```

## Step 1 — Inspect candidates BEFORE deleting

Exact whitelist (stray words from a botched shell redirect + the stray `.sync`):

```bash
for f in .sync The bash directory endings file have in its line original will working your; do
    if [ -e "$f" ]; then
        if [ -d "$f" ]; then echo "SKIP (directory!): $f"; continue; fi
        SIZE=$(stat -c %s "$f" 2>/dev/null || wc -c < "$f")
        echo "--- $f (size: $SIZE)"; head -c 120 "$f"; echo
    fi
done
```

## Step 2 — Delete, with safety rules

Rules:
- Delete ONLY names from the whitelist above. No wildcards, no other files.
- Each must be a regular FILE and <= 200 bytes. Anything larger or a directory —
  SKIP and report (do not delete).
- `git ls-files --error-unmatch <f>` must FAIL for each (i.e. untracked) — if any
  is tracked, SKIP and report.

```bash
for f in .sync The bash directory endings file have in its line original will working your; do
    if [ -f "$f" ] && ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
        SIZE=$(stat -c %s "$f" 2>/dev/null || wc -c < "$f")
        if [ "$SIZE" -le 200 ]; then
            rm "$f" && echo "DELETED: $f ($SIZE bytes)"
        else
            echo "SKIPPED (too big, review manually): $f ($SIZE bytes)"
        fi
    fi
done
sync
```

## Step 3 — Do NOT touch (report presence only)

These root-level untracked items are user artefacts, NOT junk — leave them:
`RTM_Migration_Plan_MSSQL_to_PostgreSQL.docx`, `RTM_View_Shell_Test_Report_v1.docx`,
`build_migration_plan.js`, `doc-sync-agent.skill`, `user-doc-expert.skill`,
`widget-planner/` (root copy — list its contents in the report for the operator to
decide; the canonical skill lives in `.claude/skills/widget-planner/`).

```bash
ls -la RTM_Migration_Plan_MSSQL_to_PostgreSQL.docx RTM_View_Shell_Test_Report_v1.docx \
   build_migration_plan.js doc-sync-agent.skill user-doc-expert.skill 2>/dev/null
ls -la widget-planner/ 2>/dev/null
```

## Git push / commit
None. This task performs no git operations.

## Report
Deleted list (name + size), skipped list with reasons, contents of `widget-planner/`,
and final `git status --short | grep "^??" | head -20`.
