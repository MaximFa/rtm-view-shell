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
