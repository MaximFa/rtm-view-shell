# CC Prompt — Multi-session sync block (MANDATORY)

> Cowork agent: copy this entire block into EVERY CC task prompt, immediately after
> the §0.6a integrity block. Fill in `<slug>` and `<claims>`. Spec: CLAUDE.md §42.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS

Session slug: `<slug>`
Claims for this task: `<claims>`   (modules and/or explicit file list)

### S1. Push barrier check — before ANY work

```bash
# Content-based check (NOT -f): the mount can keep a phantom dirent that fails
# `-f` true but has no content — `-f` alone would falsely block all tasks (L-SC-10).
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."
    exit 1
fi
```

### S2. Claim discipline — ENFORCED

```bash
python3 tools/coord_check_claims.py <slug> <each claimed path...>
# exit 1 -> STOP: another active session holds a path. Do not improvise -
# the conflict goes to the queue (.coord/queue.md, skill section 9).
```

Modify ONLY files inside the claims listed above (plus throwaway scripts in `/tmp`).
If the task requires touching a file outside the claims — STOP and report.

### S3. Commit lock — around EVERY git add/commit

Acquire (atomic create; retry 5 times x 60 s if busy):

```python
# /tmp/acquire_lock.py  — phantom-aware (L-SC-10: a stale dirent blocks open("x") though it has no content)
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
def real_lock():
    try:
        with open(lock) as f:
            return f.read().strip() != ""   # real lock = non-empty readable content
    except OSError:
        return False
for attempt in range(5):
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: <slug>\nacquired: "
                    + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        if not real_lock():
            print("PHANTOM lock (empty/unreadable dirent) — clearing")
            try: os.remove(lock)
            except OSError: print("  cannot unlink from this side — needs CC/Windows rm")
            time.sleep(2); continue
        print("BUSY (real): " + open(lock).read().strip()); time.sleep(60)
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

### S4b. Post-commit flush — short structured report to the coordinator (REQUIRED)

After the journal line, append ONE block to `.coord/inbox/coordinator.md` (Python+fsync).
The journal records WHAT committed; this records what the coordinator must ACT on:

```python
# /tmp/<slug>_flush.py   (name per-session — L-SC-16)
import os, datetime, subprocess
h = subprocess.check_output(["git","log","-1","--format=%h %s"]).decode().strip()
block = (
    "## " + datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ")
    + " | from: <slug> | to: coordinator\n"
    "COMMIT " + h + "\n"
    "claims-releasable: <list paths now free, or 'none'>\n"
    "blocker/question: <one line, or 'none'>\n"
    "next: <intended next step, or 'awaiting operator'>\n---\n"
)
with open(".coord/inbox/coordinator.md","a",encoding="utf-8") as f:
    f.write(block); f.flush(); os.fsync(f.fileno())
print("post-commit flush written")
```

Then `sync`. Keep it to these 4 fields — richer detail goes in the commit message, not here.
If claims are releasable, ALSO remove them from your `files:` in the session file (frees them
for waiters per §9).

### S5. Git push

Do NOT run `git push` (§37). Push happens only via `tools/cc_prompt_push.md`
after the push barrier completes (§42.7).
