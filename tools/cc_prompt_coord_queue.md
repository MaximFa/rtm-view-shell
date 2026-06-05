# CC Task — coord-queue: commit skill v1.2 (§9 queue, §10 operator commands) + checker + S2 enforcement

Session: RTM Session Sync | slug: `session-sync-0605` | role: coordinator
Claims — ONLY these files:
- `.claude/skills/session-coord/session-coord.md` (modified, 200 lines — needs `git add -f`)
- `.coord/README.md` (modified — operator command cheat-sheet)
- `tools/cc_prompt_sync_block.md` (modified, 86 lines)
- `tools/coord_check_claims.py` (untracked, new)
- `tools/cc_prompt_coord_queue.md` (untracked — this prompt)
- `docs/Multi-Session_Operator_Guide.docx` (untracked, binary, 13293 bytes)
- `docs/Multi-Session_Operator_Guide_RU.docx` (untracked, binary, 14160 bytes)

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## Step 0 — §0.6a integrity check
Standard block (CLAUDE.md §0.6a). EXCEPTIONS — do NOT restore from HEAD (legitimate
uncommitted changes): `.claude/skills/session-coord/session-coord.md` (200 lines,
HEAD has 140), `.coord/README.md` (42 lines, HEAD has 34), `tools/cc_prompt_sync_block.md` (86 lines, HEAD has 80).
Known false-M: `db/data/02_metrics.sql`, `db/schema.sql` (hash==HEAD — do not stage).

## S1. Push barrier check
```bash
cd "D:\Claude\Projects\RTM View Shell"
if [ -f ".coord/push/request.md" ]; then echo "BARRIER ACTIVE"; cat .coord/push/request.md; exit 1; fi
```

## S2. Claim check — ENFORCED (first live use of the checker)
```bash
python3 tools/coord_check_claims.py session-sync-0605   ".claude/skills/session-coord/session-coord.md" tools/cc_prompt_sync_block.md   tools/coord_check_claims.py tools/cc_prompt_coord_queue.md
# exit 1 -> STOP and report
```

## S3. Acquire commit.lock (standard block from tools/cc_prompt_sync_block.md, owner session-sync-0605, retry 5x60s)

## Commit
```bash
python3 tools/coord_check_claims.py --help >/dev/null 2>&1 || true
wc -l ".claude/skills/session-coord/session-coord.md"   # 200
wc -l .coord/README.md                                   # 42
wc -l tools/cc_prompt_sync_block.md                      # 86
python3 tools/coord_check_claims.py session-sync-0605 tools/coord_check_claims.py  # self-test, expect OK
bash tools/pre-commit-check.sh tools/cc_prompt_sync_block.md
git add -f ".claude/skills/session-coord/session-coord.md"
git add .coord/README.md tools/cc_prompt_sync_block.md tools/coord_check_claims.py tools/cc_prompt_coord_queue.md "docs/Multi-Session_Operator_Guide.docx" "docs/Multi-Session_Operator_Guide_RU.docx"
git commit -m "docs: session-coord v1.2 — §9 queue + checker + S2 enforcement, §10 operator commands + Operator Guide"
```
§0.6 post-commit verification. Then S4 journal append + lock release (standard blocks),
PD-007 re-sync of the seven files, `sync`.

## Git push
Do NOT run `git push` (§37).

## Report
commit hash; journal tail; locks empty; status summary.
