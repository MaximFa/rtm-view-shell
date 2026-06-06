# CC Task — coord-lockfix+mailbox: clear phantom lock, harden S3, commit v1.3

Session: RTM Session Sync | slug: `session-sync-0605` | role: coordinator
Claims — ONLY these files:
- `.claude/skills/session-coord/session-coord.md` (modified -> v1.3, ~242 lines; `git add -f`)
- `.coord/README.md` (modified, tracked)
- `tools/cc_prompt_sync_block.md` (modified — phantom-aware S3, 99 lines)
- `tools/cc_prompt_coord_mailbox.md` (untracked, prior prompt)
- `tools/cc_prompt_coord_lockfix.md` (untracked — this prompt)

## Mandatory — read before starting (§40)
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Then proceed.

## Step 0 — §0.6a integrity check (standard)
EXCEPTIONS — do NOT restore from HEAD (legit uncommitted): the 4 modified files above.
Known false-M: db/data/02_metrics.sql, db/schema.sql.
NOTE: RTM/RTM/Union.cs and RTM/RTM/UserManager.cs may show truncated (PD-007, metrics' files) —
they are NOT in your claims; leave them, metrics will restore via its own integrity check.

## Step P — CLEAR THE PHANTOM commit.lock (L-SC-14)
The bus has a phantom commit.lock: `test -f` true, but no real content. metrics-0605
(its named owner) is alive, cc_task:none, and has already committed past it (5a4324a…2410b5b).
Confirm it is not a real lock, then remove:
```bash
cd "D:\Claude\Projects\RTM View Shell"
if [ -s .coord/locks/commit.lock ] && cat .coord/locks/commit.lock 2>/dev/null | grep -q owner; then
    echo "REAL LOCK present — STOP, do not clear:"; cat .coord/locks/commit.lock; exit 1
fi
rm -f .coord/locks/commit.lock 2>/dev/null
test -f .coord/locks/commit.lock && echo "still phantom after rm — report to operator (needs Windows-side delete)" || echo "phantom cleared"
```
If it could not be cleared and still blocks acquisition below — STOP and report; operator
deletes `.coord/locks/commit.lock` from Windows Explorer.

## S1. Push barrier (content-based)
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "BARRIER ACTIVE"; cat .coord/push/request.md; exit 1
fi
```

## S2. Claim check
```bash
python3 tools/coord_check_claims.py session-sync-0605   ".claude/skills/session-coord/session-coord.md" .coord/README.md   tools/cc_prompt_sync_block.md tools/cc_prompt_coord_mailbox.md tools/cc_prompt_coord_lockfix.md
```

## S3. Acquire commit.lock — use the PHANTOM-AWARE block from tools/cc_prompt_sync_block.md
(owner session-sync-0605; it self-clears a phantom and retries.)

## Commit
```bash
grep -c "## 11. Mailbox" ".claude/skills/session-coord/session-coord.md"   # 1
grep -c "L-SC-15" ".claude/skills/session-coord/session-coord.md"          # 1
grep -c "PHANTOM lock" tools/cc_prompt_sync_block.md                       # 1
bash tools/pre-commit-check.sh tools/cc_prompt_sync_block.md
git add -f ".claude/skills/session-coord/session-coord.md"
git add .coord/README.md tools/cc_prompt_sync_block.md         tools/cc_prompt_coord_mailbox.md tools/cc_prompt_coord_lockfix.md
git commit -m "docs: session-coord v1.3 — mailbox (§11), phantom-aware lock S3 (L-SC-14), L-SC-11..15"
```
§0.6 verification. S4 journal append + lock release (standard). PD-007 re-sync of the
5 claimed files. `sync`.

## Git push
Do NOT run `git push` (§37).

## Report
commit hash; journal tail; `ls .coord/locks/` empty; status summary.
