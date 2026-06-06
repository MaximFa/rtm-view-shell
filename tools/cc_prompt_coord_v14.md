# CC Task — coord-v1.4: входящие auto-flush + post-commit flush (S4b) + L-SC-16

Session: RTM Session Sync | slug: `session-sync-0605` | role: coordinator
Claims — ONLY these files:
- `.claude/skills/session-coord/session-coord.md` (modified -> v1.4, 247 lines; `git add -f`)
- `tools/cc_prompt_sync_block.md` (modified -> 125 lines, S4b added)
- `tools/cc_prompt_coord_v14.md` (untracked — this prompt)

## Mandatory — read before starting (§40)
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Then proceed.

## Step 0 — §0.6a integrity check (standard)
EXCEPTIONS — do NOT restore from HEAD (legit uncommitted): the 2 modified files above.
Known false-M: db/data/02_metrics.sql, db/schema.sql.
NOTE: RTM/RTM/Union.cs, RTM/RTM/UserManager.cs may show truncated (PD-007, metrics' files) —
NOT your claims; leave them, metrics restores via its own integrity check.

## S1. Push barrier (content-based)
```bash
cd "D:\Claude\Projects\RTM View Shell"
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "BARRIER ACTIVE"; cat .coord/push/request.md; exit 1
fi
```

## S2. Claim check
```bash
python3 tools/coord_check_claims.py session-sync-0605   ".claude/skills/session-coord/session-coord.md" tools/cc_prompt_sync_block.md tools/cc_prompt_coord_v14.md
```

## S3. Acquire commit.lock — PHANTOM-AWARE block from tools/cc_prompt_sync_block.md
(owner session-sync-0605; self-clears the lingering phantom dirent and retries.)

## Commit
```bash
grep -c "входящие.*auto-flush\|auto-flush" ".claude/skills/session-coord/session-coord.md"  # >=1
grep -c "S4b" tools/cc_prompt_sync_block.md                # >=1
grep -c "L-SC-16" ".claude/skills/session-coord/session-coord.md"   # 1
bash tools/pre-commit-check.sh tools/cc_prompt_sync_block.md
git add -f ".claude/skills/session-coord/session-coord.md"
git add tools/cc_prompt_sync_block.md tools/cc_prompt_coord_v14.md
git commit -m "docs: session-coord v1.4 — входящие auto-flush + post-commit flush (S4b), L-SC-16"
```
§0.6 verification.

## S4. Journal + post-commit flush (S4b) + release
- Append journal line (Python+fsync).
- Append post-commit flush block to .coord/inbox/coordinator.md (this is the FIRST real use
  of S4b — dogfood it): COMMIT <hash> / claims-releasable: none / blocker: none /
  next: broadcast re-read v1.4 to active sessions.
- Remove commit.lock, `sync`.

## S5. PD-007 re-sync of the 3 claimed files, `sync`.

## Git push
Do NOT run `git push` (§37).

## Report
commit hash; journal tail; coordinator.md flush block; locks empty; status summary.
