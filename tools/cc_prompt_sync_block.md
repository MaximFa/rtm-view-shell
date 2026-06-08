# CC Prompt — Multi-session sync block (MANDATORY)

> Cowork agent: copy this entire block into EVERY CC task prompt, immediately after
> the §0.6a integrity block. Fill in `<slug>` and `<claims>`. Spec: CLAUDE.md §42.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS

Session slug: `<slug>`
Claims for this task: `<claims>`   (modules and/or explicit file list)

### S1. Push barrier check — before ANY work

```bash
# Marker-based check (L-SC-10 + tombstone-safe): block ONLY if request.md content
# contains "FREEZE ACTIVE". A phantom dirent (cat fails -> empty) and a CLEARED
# tombstone (content has "FREEZE LIFTED", not "FREEZE ACTIVE") both correctly DO NOT block.
# Never use `[ -f ]`/`[ -s ]` alone — the mount keeps stale dirents after Windows unlink (L-SC-10).
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
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

### S4 + S4b. Post-commit — run the MANDATORY wrapper (NON-SKIPPABLE)

After `git commit` + §0.6 verification, run as the LAST step:

    bash tools/cc_post_commit.sh <slug> $(git log -1 --format=%h)

It appends the journal line, writes the coordinator flush block (both Python+fsync, verified),
releases commit.lock, and prints the claims to release. If it exits non-zero, the journal/flush
was not verified (L-SC-04 mount drop) — reconcile .coord/journal.md vs `git log` and re-run
before continuing. Do NOT hand-write journal/flush inline anymore; the wrapper is the only path.
Then `sync`.

### S5. Git push

Do NOT run `git push` (§37). Push happens only via `tools/cc_prompt_push.md`
after the push barrier completes (§42.7).
