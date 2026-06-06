# CC Task — coord-s1fix: harden barrier check S1 (content-based) + L-SC-10

Session: RTM Session Sync | slug: `session-sync-0605` | role: coordinator
Claims — ONLY these files:
- `tools/cc_prompt_sync_block.md` (modified, 88 lines — S1 now content-based)
- `.claude/skills/session-coord/session-coord.md` (modified, 201 lines — L-SC-10; needs `git add -f`)
- `tools/cc_prompt_coord_s1fix.md` (untracked — this prompt)

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## Step 0 — §0.6a integrity check
Standard block. EXCEPTIONS — do NOT restore from HEAD (legitimate uncommitted changes):
`tools/cc_prompt_sync_block.md` (88 lines, HEAD has 86),
`.claude/skills/session-coord/session-coord.md` (201 lines, HEAD has 200).
Known false-M: `db/data/02_metrics.sql`, `db/schema.sql` (hash==HEAD — do not stage).

## S1. Push barrier check — CONTENT-BASED (the very fix this task ships)
```bash
cd "D:\Claude\Projects\RTM View Shell"
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "BARRIER ACTIVE"; cat .coord/push/request.md; exit 1
fi
echo "no real barrier (phantom -f is ignored by content check)"
```

## S2. Claim check (checker)
```bash
python3 tools/coord_check_claims.py session-sync-0605   tools/cc_prompt_sync_block.md   ".claude/skills/session-coord/session-coord.md"   tools/cc_prompt_coord_s1fix.md
# exit 1 -> STOP
```

## S3. Acquire commit.lock (standard block, owner session-sync-0605, retry 5x60s)

## Commit
```bash
wc -l tools/cc_prompt_sync_block.md                       # 88
grep -c "Content-based" tools/cc_prompt_sync_block.md     # 1
grep -c "L-SC-10" ".claude/skills/session-coord/session-coord.md"  # 1
bash tools/pre-commit-check.sh tools/cc_prompt_sync_block.md
git add -f ".claude/skills/session-coord/session-coord.md"
git add tools/cc_prompt_sync_block.md tools/cc_prompt_coord_s1fix.md
git commit -m "fix: content-based barrier check S1 (mount phantom dirent), L-SC-10"
```
§0.6 post-commit verification. Then S4 journal append + lock release (standard blocks),
PD-007 re-sync of the three files, `sync`.

## Git push
Do NOT run `git push` (§37).

## Report
commit hash; journal tail; locks empty; status summary.
