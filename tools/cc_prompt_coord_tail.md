# CC Task — coord-tail: commit protocol tail files (§42, second live run)

Session: RTM Session Sync | slug: `session-sync-0605` | claims: docs (explicit file list below)
Date: 2026-06-05. Second live run of the §42 protocol — follow it exactly.

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Only after reading both files: proceed with the task below.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short

for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF lines)"
        git show HEAD:"$f" > "$f"
        echo "RESTORED: $f"
    else
        echo "OK: $f ($WT_LINES lines)"
    fi
done
sync
echo "=== Integrity check complete ==="
```

EXCEPTIONS — do NOT restore these from HEAD, they contain legitimate uncommitted changes:
- `tools/cc_prompt_coord_init.md` (155 lines — patched to 6 files, HEAD has 154)
- `tools/cc_prompt_push.md` (contains new Step 1b — untracked-files pickup)

NOTE: `db/data/02_metrics.sql` and `db/schema.sql` may show `M` while content == HEAD
(mount quirk). Verify with `git hash-object <f>` vs `git rev-parse HEAD:<f>`;
if hashes match — leave them alone and do NOT stage them.

## Multi-session sync — MANDATORY (§42)

Session slug: `session-sync-0605`
Claims for this task — ONLY these files (plus throwaway scripts in /tmp):

- `docs/Multi-Session_Coordination_TasksAPI_vs_Coord.docx` (untracked, binary, 12058 bytes)
- `tools/cc_prompt_coord_init.md` (modified, 155 lines)
- `tools/cc_prompt_push.md` (modified — Step 1b added by session RTM Prod Test3)
- `tools/cc_prompt_coord_tail.md` (untracked — this prompt itself)

### S1. Push barrier check — before ANY work

```bash
if [ -f ".coord/push/request.md" ]; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."
    exit 1
fi
```

### S2. Claim discipline
Modify ONLY the four files above. If anything else needs touching — STOP and report.
(In this task you should not need to modify anything at all — verify and commit only.)

### S3. Acquire commit lock (before git add/commit)

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
print("FAILED to acquire commit lock after 5 attempts"); sys.exit(1)
```

If FAILED — abort, report lock owner. Never delete a lock you do not own.

## Task — verify the four files, then ONE commit

1. Verify:

```bash
wc -l tools/cc_prompt_coord_init.md tools/cc_prompt_push.md tools/cc_prompt_coord_tail.md
# coord_init = 155; push prompt must contain Step 1b:
grep -c "Step 1b" tools/cc_prompt_push.md   # >= 1
tail -2 tools/cc_prompt_coord_init.md; tail -2 tools/cc_prompt_push.md
ls -la "docs/Multi-Session_Coordination_TasksAPI_vs_Coord.docx"   # 12058 bytes
```

If `tools/cc_prompt_push.md` ends mid-sentence/mid-token (truncation) — STOP and report
(do NOT restore from HEAD: HEAD does not have Step 1b).

2. Pre-commit check (mandatory, §0.5):

```bash
bash tools/pre-commit-check.sh tools/cc_prompt_coord_init.md tools/cc_prompt_push.md
# exit 1 → STOP, report
```

3. Stage and commit (you hold commit.lock):

```bash
git add "docs/Multi-Session_Coordination_TasksAPI_vs_Coord.docx" tools/cc_prompt_coord_init.md tools/cc_prompt_push.md tools/cc_prompt_coord_tail.md
git commit -m "docs: coord-tail — TasksAPI-vs-coord doc, coord-init 6-file patch, push prompt Step 1b (by RTM Prod Test3 session)"
```

If `index.lock`/`HEAD.lock` blocks: use §0.4 workarounds — allowed, you hold commit.lock.

4. Post-commit verification (§0.6):

```bash
git status --short        # four claimed files must be clean
git show HEAD:tools/cc_prompt_coord_init.md | wc -l ; wc -l tools/cc_prompt_coord_init.md   # both 155
git log --oneline -1
```

### S4. Journal + release lock (after the commit)

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

5. PD-007 re-sync — FINAL step, no exceptions:

```bash
for f in tools/cc_prompt_coord_init.md tools/cc_prompt_push.md tools/cc_prompt_coord_tail.md "docs/Multi-Session_Coordination_TasksAPI_vs_Coord.docx"; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f"
done
sync
```

## Git push
Do NOT run `git push` (§37). Push will be requested separately via the §42.7 barrier.

## Report
Output: commit hash; `tail -2 .coord/journal.md`; `ls .coord/locks/` (must be empty);
`git status --short` summary.
