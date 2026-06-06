# CC Task — coord-mailbox: commit mailbox layer (skill v1.3 §11 + 3 commands)

Session: RTM Session Sync | slug: `session-sync-0605` | role: coordinator
Claims — ONLY these files:
- `.claude/skills/session-coord/session-coord.md` (modified -> v1.3, ~241 lines; needs `git add -f`)
- `.coord/README.md` (modified, tracked top-level)
- `tools/cc_prompt_coord_mailbox.md` (untracked — this prompt)

NOTE: `.coord/inbox/*` are gitignored runtime state (like sessions/, locks/, queue) —
do NOT stage them. Only the skill doc + top-level README carry the mailbox spec.

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## Step 0 — §0.6a integrity check
Standard block. EXCEPTIONS — do NOT restore from HEAD (legitimate uncommitted):
`.claude/skills/session-coord/session-coord.md` (v1.3, HEAD has v1.2 fix-version),
`.coord/README.md`. Known false-M: db/data/02_metrics.sql, db/schema.sql (hash==HEAD).

## S1. Push barrier check (content-based — L-SC-10)
```bash
cd "D:\Claude\Projects\RTM View Shell"
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "BARRIER ACTIVE"; cat .coord/push/request.md; exit 1
fi
```

## S2. Claim check
```bash
python3 tools/coord_check_claims.py session-sync-0605   ".claude/skills/session-coord/session-coord.md" .coord/README.md tools/cc_prompt_coord_mailbox.md
# exit 1 -> STOP
```

## S3. Acquire commit.lock (standard block, owner session-sync-0605, retry 5x60s)

## Commit
```bash
grep -c "коорд: сбрось" ".claude/skills/session-coord/session-coord.md"     # >=1
grep -c "## 11. Mailbox" ".claude/skills/session-coord/session-coord.md"    # 1
grep -c "L-SC-13" ".claude/skills/session-coord/session-coord.md"           # 1
bash tools/pre-commit-check.sh ".claude/skills/session-coord/session-coord.md"
git add -f ".claude/skills/session-coord/session-coord.md"
git add .coord/README.md tools/cc_prompt_coord_mailbox.md
git commit -m "docs: session-coord v1.3 — mailbox (.coord/inbox/, §11), 3 mailbox commands, L-SC-11..13"
```
§0.6 verification. S4 journal append + lock release (standard blocks).
PD-007 re-sync of the three files. `sync`.

## Git push
Do NOT run `git push` (§37).

## Report
commit hash; journal tail; locks empty; status summary.
