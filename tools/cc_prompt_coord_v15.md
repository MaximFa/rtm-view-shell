# CC Task — coord-v1.5: handoff (§12) + operator guide section 6 + push-barrier rewrite

Session: RTM Session Sync | slug: `session-sync-0605` | role: coordinator
Claims — ONLY these files:
- `.claude/skills/session-coord/session-coord.md` (modified -> v1.5, 285 lines; `git add -f`)
- `tools/cc_prompt_push_barrier.md` (modified — clean push, no sweep)
- `docs/Multi-Session_Operator_Guide_RU_v3.docx` (untracked, current RU guide w/ section 6)
- `tools/cc_prompt_coord_v15.md` (untracked — this prompt)

NOTE: docs/Multi-Session_Operator_Guide_RU_v2.docx is a superseded intermediate — do NOT
commit it (operator deletes it manually from Windows when convenient).

## Mandatory — read before starting (§40)
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Then proceed.

## Step 0 — §0.6a integrity + post-push sync (§42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin 2>&1 | tail -1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/v2)" && echo "HEAD==origin/v2 OK" || echo "DIVERGED — note, still ok to commit ahead"
git status --short
```
EXCEPTIONS — do NOT restore from HEAD (legit uncommitted): the modified files above.
Known false-M: db/data/02_metrics.sql, db/schema.sql (hash==HEAD). Other sessions' M files: leave them.

## S1. Push barrier (content-based)
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "BARRIER ACTIVE"; cat .coord/push/request.md; exit 1
fi
```

## S2. Claim check
```bash
python3 tools/coord_check_claims.py session-sync-0605   ".claude/skills/session-coord/session-coord.md" tools/cc_prompt_push_barrier.md   "docs/Multi-Session_Operator_Guide_RU_v3.docx" tools/cc_prompt_coord_v15.md
```

## S3. Acquire commit.lock — PHANTOM-AWARE block from tools/cc_prompt_sync_block.md (owner session-sync-0605)

## Commit
```bash
grep -c "## 12. Coordinator handoff" ".claude/skills/session-coord/session-coord.md"   # 1
grep -c "L-SC-17" ".claude/skills/session-coord/session-coord.md"                       # 1
bash tools/pre-commit-check.sh tools/cc_prompt_push_barrier.md
git add -f ".claude/skills/session-coord/session-coord.md"
git add tools/cc_prompt_push_barrier.md "docs/Multi-Session_Operator_Guide_RU_v3.docx" tools/cc_prompt_coord_v15.md
git commit -m "docs: session-coord v1.5 — §12 coordinator handoff, operator guide section 6, clean push-barrier, L-SC-17"
```
§0.6 verification.

## S4 + S4b + release
- Journal line (Python+fsync).
- S4b post-commit flush to .coord/inbox/coordinator.md (COMMIT <hash> / claims-releasable: none /
  blocker: none / next: coordinator handoff practice).
- Remove commit.lock, `sync`.

## S5. PD-007 re-sync of the committed files, `sync`.

## Git push
Do NOT run `git push` (§37).

## Report
commit hash; journal tail; coordinator.md flush; locks empty; status summary.
