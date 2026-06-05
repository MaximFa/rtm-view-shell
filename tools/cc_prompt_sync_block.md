# CC Prompt — Multi-session sync block (MANDATORY)

> Cowork agent: copy this entire block into EVERY CC task prompt, immediately after
> the §0.6a integrity block. Fill in `<slug>` and `<claims>`. Spec: CLAUDE.md §42.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS

Session slug: `<slug>`
Claims for this task: `<claims>`   (modules and/or explicit file list)

### S1. Push barrier check — before ANY work

```bash
if [ -f ".coord/push/request.md" ]; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."
    exit 1
fi
```

### S2. Claim discipline

Modify ONLY files inside the claims listed above (plus throwaway scripts in `/tmp`).
If the task requires touching a file outside the claims — STOP and report; do not improvise.

### S3. Commit lock — around EVERY git add/commit

Acquire (atomic create; retry 5 times x 60 s if busy):

```python
# /tmp/acquire_lock.py
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
for attempt in range(5):
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: <slug>\nacquired: "
                    + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        print("BUSY: " + open(lock).read().strip()); time.sleep(60)
print("FAILED to acquire commit lock after 5 attempts"); sys.exit(1)
```

- If FAILED: abort the commit, report lock owner to operator. Do NOT delete the lock.
- A lock older than 15 minutes is stale: report its contents and WAIT for operator
  decision — never auto-delete (the owning CC may be mid-commit).

While holding the lock: `bash tools/pre-commit-check.sh` -> `git add` (claimed files
only) -> `git commit` (module prefix per §39.3) -> §0.6 post-commit verification.

The lock also covers the §0.4 plumbing path (`commit-tree` + direct ref write) —
that path has NO git-level locking, so bypassing commit.lock there can silently
destroy another session's commit.

New files: check `git status --short | grep "^??"` within the claims and add them
explicitly; anything under `.claude/` needs `git add -f` (blocked by `.gitignore`).

### S4. Journal + release — after EVERY commit

```python
# /tmp/journal_release.py
import os, datetime, subprocess
h = subprocess.check_output(["git", "log", "-1", "--format=%h %s"]).decode().strip()
line = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ") + " | <slug> | " + h + "\n"
with open(".coord/journal.md", "a", encoding="utf-8") as f:
    f.write(line); f.flush(); os.fsync(f.fileno())
os.remove(".coord/locks/commit.lock")
print("journal appended, lock released")
```

Then `sync`. If the commit is aborted for any reason, still release the lock.

### S5. Git push

Do NOT run `git push` (§37). Push happens only via `tools/cc_prompt_push.md`
after the push barrier completes (§42.7).
