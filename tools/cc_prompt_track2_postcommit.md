# CC Task — Track 2: durable post-commit wrapper (tools/cc_post_commit.sh)

> Issued by Cowork session **RTM Test4** (slug `test4-0606`).
> Problem: this session CC dropped the S4 journal line, the S4b coordinator flush, and
> claim-release ~10x — each needed manual Cowork reconciliation. Fix: one MANDATORY,
> exit-gated script run as the LAST step of every commit, so the steps cannot be skipped.

---

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin v2 -q
git rev-parse HEAD; git rev-parse origin/v2
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HL=$(git show HEAD:"$f" 2>/dev/null | wc -l); WL=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HL-WL))" -gt 0 ]; then echo "TRUNCATED $f"; git show HEAD:"$f" > "$f"; echo "RESTORED $f";
    else echo "OK $f ($WL)"; fi
done
sync; echo "=== integrity complete ==="
```

## Multi-session sync — MANDATORY (§42, skill v1.4+)
Session slug: `test4-0606`
Claims (touch ONLY these + /tmp/test4-0606_*.py):
- `tools/cc_post_commit.sh`                           (new)
- `tools/cc_prompt_sync_block.md`                     (edit S4/S4b)
- `.claude/skills/session-coord/session-coord.md`     (edit §3)

S1 push-barrier check (content-based, L-SC-10):
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
  echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo STOP; exit 1; fi
```
S2 claim-check:
```bash
python3 tools/coord_check_claims.py test4-0606 \
  tools/cc_post_commit.sh tools/cc_prompt_sync_block.md .claude/skills/session-coord/session-coord.md
```
S3 commit lock — phantom-aware acquire (L-SC-14):
```python
# /tmp/test4-0606_acquire_lock.py
import os, sys, time, datetime
lock=".coord/locks/commit.lock"
for _ in range(5):
    if os.path.exists(lock):
        try: body=open(lock).read()
        except Exception: body=""
        if body.strip()=="":
            try: os.remove(lock)
            except Exception: pass
        else: print("BUSY:",body.strip()); time.sleep(60); continue
    try:
        with open(lock,"x",encoding="utf-8") as f:
            f.write("owner: test4-0606\nacquired: "+datetime.datetime.utcnow().isoformat()+"Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError: time.sleep(5)
print("FAILED lock"); sys.exit(1)
```

## Mandatory skills (§40)
Read: .claude/skills/widget-planner/widget-planner.md , widget-creator/widget-creator.md , session-coord/session-coord.md

## File writes — Python + os.fsync ONLY (§0.3). Edit tool BANNED. After each write: `sync && tail -3 <f> && wc -l <f>`.

---

## TASK

### Part A — CREATE `tools/cc_post_commit.sh` with EXACTLY this content
(Write verbatim. Make it executable: `chmod +x tools/cc_post_commit.sh`.)

```bash
#!/usr/bin/env bash
# tools/cc_post_commit.sh — MANDATORY last step of EVERY CC commit (session-coord §3 / Track 2).
# Consolidates old S4 (journal + lock release) and S4b (coordinator flush) into ONE
# exit-gated command so CC cannot skip or forget them.
#
# Usage:  bash tools/cc_post_commit.sh <slug> [commit-hash]
#   <slug>        required — session slug (e.g. test4-0606)
#   [commit-hash] optional — defaults to current HEAD short hash
#
# Exit 0 only if BOTH the journal line and the coordinator flush block were written AND
# verified present. Non-zero if either cannot be verified (mount drop, L-SC-04) — the
# caller MUST reconcile before proceeding.
set -uo pipefail

SLUG="${1:?usage: cc_post_commit.sh <slug> [commit-hash]}"
HASH="${2:-$(git log -1 --format=%h)}"
SUBJ="$(git log -1 --format=%s)"
TS="$(date -u +%Y-%m-%dT%H:%MZ)"

python3 - "$SLUG" "$HASH" "$SUBJ" "$TS" <<'PY'
import os, sys, time
slug, h, subj, ts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
rc = 0
def append_fsync(path, text):
    with open(path, "a", encoding="utf-8") as f:
        f.write(text); f.flush(); os.fsync(f.fileno())
def present(path, needle):
    try: return needle in open(path, encoding="utf-8").read()
    except FileNotFoundError: return False

# 1) journal line
jline = ts + " | " + slug + " | " + h + " " + subj + "\n"
try: append_fsync(".coord/journal.md", jline)
except Exception as e: print("[cc_post_commit] JOURNAL WRITE ERROR:", e); rc = 1
for _ in range(3):
    if present(".coord/journal.md", h): break
    time.sleep(1)
else:
    if not present(".coord/journal.md", h):
        print("[cc_post_commit] JOURNAL LINE NOT VERIFIED (L-SC-04). Coordinator must reconcile journal<->git."); rc = 1

# 2) coordinator flush (S4b) — include the explicit claimed-files list
claims = []
try:
    insec = False
    for ln in open(".coord/sessions/" + slug + ".md", encoding="utf-8"):
        if ln.startswith("files:"):
            insec = True
            inline = ln.split("files:",1)[1].strip()
            if inline and inline != "[]":
                claims.append(inline)
            continue
        if insec:
            s = ln.rstrip("\n")
            if s.startswith("  - "):
                claims.append(s[4:].strip())
            elif s[:1] not in (" ", "\t"):
                break
except Exception:
    pass
claims_str = "; ".join(claims) if claims else "none (see session file)"
block = ("## " + ts + " | from: " + slug + " | to: coordinator\n"
         "COMMIT " + h + " " + subj + "\n"
         "claims-releasable: " + claims_str + " (release any whose work is committed+pushed)\n"
         "blocker/question: none\n"
         "next: awaiting operator\n---\n")
try: append_fsync(".coord/inbox/coordinator.md", block)
except Exception as e: print("[cc_post_commit] FLUSH WRITE ERROR:", e); rc = 1
for _ in range(3):
    if present(".coord/inbox/coordinator.md", h): break
    time.sleep(1)
else:
    if not present(".coord/inbox/coordinator.md", h):
        print("[cc_post_commit] FLUSH NOT VERIFIED."); rc = 1
sys.exit(rc)
PY
RC=$?

# 3) release commit.lock (phantom-aware; CC can unlink on real FS — L-SC-02/14)
if [ -e ".coord/locks/commit.lock" ]; then
    rm -f ".coord/locks/commit.lock" 2>/dev/null && echo "[cc_post_commit] commit.lock released" \
        || echo "[cc_post_commit] WARNING: could not remove commit.lock (phantom? check CC-side)"
fi
sync

# 4) print claims to release
echo "[cc_post_commit] --- claims for $SLUG (release any whose work is pushed) ---"
awk '/^files:/{p=1} p{print} /^cc_task:/{p=0}' ".coord/sessions/$SLUG.md" 2>/dev/null || echo "  (session file not found)"

[ "$RC" -ne 0 ] && echo "[cc_post_commit] EXIT $RC — journal/flush NOT fully verified. Reconcile before continuing."
exit "$RC"
```

### Part B — UPDATE `tools/cc_prompt_sync_block.md`
Replace the entire **S4** and **S4b** sections (the two inline Python snippets) with a single
section that calls the wrapper. New text:

```
### S4 + S4b. Post-commit — run the MANDATORY wrapper (NON-SKIPPABLE)

After `git commit` + §0.6 verification, run as the LAST step:

    bash tools/cc_post_commit.sh <slug> $(git log -1 --format=%h)

It appends the journal line, writes the coordinator flush block (both Python+fsync, verified),
releases commit.lock, and prints the claims to release. If it exits non-zero, the journal/flush
was not verified (L-SC-04 mount drop) — reconcile .coord/journal.md vs `git log` and re-run
before continuing. Do NOT hand-write journal/flush inline anymore; the wrapper is the only path.
Then `sync`.
```
Keep S1, S2, S3, S5, S6 unchanged. Fill `<slug>` literally where the prompt is specialised.

### Part C — UPDATE `.claude/skills/session-coord/session-coord.md` §3 (Commit discipline)
Add a line documenting the wrapper as non-skippable, e.g. under §3:
"After every commit the LAST step is `bash tools/cc_post_commit.sh <slug> <hash>` — it performs
journal(S4)+flush(S4b)+lock-release atomically and is exit-gated; inline journal/flush is removed.
Skipping it is a protocol violation (Track 2, L-SC-17)." Bump the version note line if you keep one.
NOTE: `.claude/` is gitignored — stage with `git add -f` (L-SC-05).

### Part D — Dogfood + commit (docs module, §39.3)
Use the NEW wrapper for THIS commit:
```bash
bash tools/pre-commit-check.sh
GIT_INDEX_FILE=... # per §0.4 if needed
git add tools/cc_post_commit.sh tools/cc_prompt_sync_block.md
git add -f .claude/skills/session-coord/session-coord.md
git commit -m "docs: mandatory cc_post_commit.sh wrapper (journal+flush+lock), sync_block S4/S4b + skill §3"
# §0.6 post-commit verify, then the wrapper itself:
bash tools/cc_post_commit.sh test4-0606 $(git log -1 --format=%h)
```
Then S6 PD-007 re-sync the three files from HEAD. DO NOT `git push` (§37).

---
## Peer review
This prompt goes to coordinator §4 review BEFORE the operator issues it. Do not run until approved.
