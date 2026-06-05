# CC Task — coord-skill: commit session-coord skill + CLAUDE.md registration

Session: RTM Session Sync | slug: `session-sync-0605` | claims: explicit file list below
Date: 2026-06-06. Third protocol commit of this session.

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed with the task below.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else
        echo "OK: $f ($WT_LINES lines)"
    fi
done
sync; echo "=== Integrity check complete ==="
```

EXCEPTION — do NOT restore from HEAD: `CLAUDE.md` (2929 lines — contains legitimate
uncommitted §30.3/§40 registration; HEAD has 2926). False-M as usual:
`db/data/02_metrics.sql`, `db/schema.sql` (hash==HEAD — do not stage).

## Multi-session sync — MANDATORY (§42)

Session slug: `session-sync-0605`
Claims — ONLY these files (plus /tmp scripts):

- `.claude/skills/session-coord/session-coord.md` (untracked, 140 lines — needs `git add -f`!)
- `CLAUDE.md` (modified, 2929 lines)
- `tools/cc_prompt_push_barrier.md` (untracked, 54 lines)
- `tools/cc_prompt_coord_skill.md` (untracked — this prompt)

### S1. Push barrier check
```bash
if [ -f ".coord/push/request.md" ]; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md; exit 1
fi
```

### S2. Claim discipline
Modify nothing; verify and commit only the four files above.

### S3. Acquire commit lock
```python
# /tmp/acquire_lock.py
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
for attempt in range(5):
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: session-sync-0605\nacquired: "
                    + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        print("BUSY: " + open(lock).read().strip()); time.sleep(60)
print("FAILED after 5 attempts"); sys.exit(1)
```

## Task — verify, then ONE commit

1. Verify:
```bash
wc -l .claude/skills/session-coord/session-coord.md   # 140
tail -2 .claude/skills/session-coord/session-coord.md  # ends with L-SC-08 table row
wc -l CLAUDE.md                                        # 2929
tail -2 CLAUDE.md   # footer: TZ version 2.5 ... 2026-06-06
grep -c "session-coord" CLAUDE.md                      # >= 4
wc -l tools/cc_prompt_push_barrier.md                  # 54
```
Truncation in skill/CLAUDE.md → STOP and report (do not restore CLAUDE.md from HEAD).

2. `bash tools/pre-commit-check.sh CLAUDE.md` — exit 1 → STOP.

3. Commit (lock held; note the -f for .claude/):
```bash
git add -f .claude/skills/session-coord/session-coord.md
git add CLAUDE.md tools/cc_prompt_push_barrier.md tools/cc_prompt_coord_skill.md
git commit -m "docs: session-coord skill (§42 runbooks + run-1 lessons L-SC-01..08), registered in CLAUDE.md §30.3/§40"
```
index.lock/HEAD.lock → §0.4 workarounds allowed (you hold commit.lock).

4. §0.6 verification:
```bash
git status --short
git show HEAD:CLAUDE.md | wc -l ; wc -l CLAUDE.md     # both 2929
git log --oneline -1
```

### S4. Journal + release
```python
# /tmp/journal_release.py
import os, datetime, subprocess
h = subprocess.check_output(["git", "log", "-1", "--format=%h %s"]).decode().strip()
line = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ") + " | session-sync-0605 | " + h + "\n"
with open(".coord/journal.md", "a", encoding="utf-8") as f:
    f.write(line); f.flush(); os.fsync(f.fileno())
os.remove(".coord/locks/commit.lock")
print("journal appended, lock released")
```
Then `sync`.

5. PD-007 re-sync — FINAL step:
```bash
for f in CLAUDE.md ".claude/skills/session-coord/session-coord.md" tools/cc_prompt_push_barrier.md tools/cc_prompt_coord_skill.md; do
    git show HEAD:"$f" > "$f"; echo "Re-synced: $f"
done
sync
```

## Git push
Do NOT run `git push` (§37).

## Report
commit hash; `tail -1 .coord/journal.md`; `ls .coord/locks/` (empty); status summary.
