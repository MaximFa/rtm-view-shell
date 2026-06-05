# CC Task — coord-init: commit the multi-session coordination protocol (§42)

Session: RTM Session Sync | slug: `session-sync-0605` | claims: docs (explicit file list below)
Date: 2026-06-05. This is the FIRST live run of the §42 protocol — follow it exactly.

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

NOTE: `db/data/02_metrics.sql` and `db/schema.sql` may show `M` while content == HEAD
(mount quirk). Verify with `git hash-object <f>` vs `git rev-parse HEAD:<f>`;
if hashes match — leave them alone and do NOT stage them. EXCEPTION: CLAUDE.md will
legitimately show `M` — it contains the new §42 written by Cowork; do not restore it.

## Multi-session sync — MANDATORY (§42)

Session slug: `session-sync-0605`
Claims for this task — ONLY these files (plus throwaway scripts in /tmp):

- `CLAUDE.md`
- `.coord/README.md`
- `.coord/.gitignore`
- `tools/cc_prompt_sync_block.md`
- `tools/cc_prompt_coord_init.md`

### S1. Push barrier check — before ANY work

```bash
if [ -f ".coord/push/request.md" ]; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."
    exit 1
fi
```

### S2. Claim discipline
Modify ONLY the five files above. If anything else needs touching — STOP and report.

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

## Task — verify the five files, then ONE commit

All content is already written by Cowork. Your job: verify integrity + commit.

1. Verify each claimed file ends properly:

```bash
for f in CLAUDE.md .coord/README.md .coord/.gitignore tools/cc_prompt_sync_block.md tools/cc_prompt_coord_init.md; do
    echo "== $f"; tail -2 "$f"; wc -l "$f"
done
```

Expected: CLAUDE.md = 2926 lines, last line `*TZ version: 2.4 | CLAUDE.md last updated: 2026-06-05 (§42 multi-session coordination protocol)*`;
cc_prompt_sync_block.md = 80 lines ending with §42.7 reference; .coord/README.md = 34 lines;
.coord/.gitignore = 4 lines. If CLAUDE.md is truncated: DO NOT restore from HEAD
(HEAD does not have §42) — STOP and report to operator.

2. Pre-commit check (mandatory, §0.5):

```bash
bash tools/pre-commit-check.sh CLAUDE.md
# exit 1 → STOP, report
```

3. Stage and commit (you hold commit.lock):

```bash
git add CLAUDE.md .coord/README.md .coord/.gitignore tools/cc_prompt_sync_block.md tools/cc_prompt_coord_init.md
git commit -m "docs: §42 multi-session coordination protocol (.coord/, commit lock, push barrier)"
```

`.coord/sessions/`, `locks/`, `push/` are runtime state — gitignored, must NOT be staged.
If `index.lock`/`HEAD.lock` blocks: use §0.4 workarounds — allowed, you hold commit.lock.

4. Post-commit verification (§0.6):

```bash
git status --short          # five claimed files must be clean
git show HEAD:CLAUDE.md | wc -l ; wc -l CLAUDE.md   # both 2926
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
for f in CLAUDE.md .coord/README.md .coord/.gitignore tools/cc_prompt_sync_block.md tools/cc_prompt_coord_init.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Git push
Do NOT run `git push` (§37). Push will be requested separately via the §42.7 barrier.

## Report
Output: commit hash; `tail -1 .coord/journal.md`; `ls .coord/locks/` (must be empty);
`git status --short` summary.
