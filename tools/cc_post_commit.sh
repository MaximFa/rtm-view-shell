#!/usr/bin/env bash
# tools/cc_post_commit.sh — MANDATORY last step of EVERY CC commit (session-coord §3 / Track 2).
# Consolidates old S4 (journal + lock release) and S4b (coordinator flush) into ONE exit-gated
# command. Robust against BOTH failure modes:
#   - L-SC-04 mount write-back drop (append succeeds in WSL2, vanishes from shared mount view)
#   - interpreter absence (python3/python not on PATH in the calling shell)
# Usage: bash tools/cc_post_commit.sh <slug> [commit-hash]
# Exit 0 only if journal line AND coordinator flush are written AND verified present.
set -uo pipefail

SLUG="${1:?usage: cc_post_commit.sh <slug> [commit-hash]}"
HASH="${2:-$(git log -1 --format=%h)}"
SUBJ="$(git log -1 --format=%s)"
TS="$(date -u +%Y-%m-%dT%H:%MZ)"

# Robust interpreter pick (NOT `PY=$(command -v python3 || command -v python)` — that returned
# empty in the env probe). Explicit if/elif/else:
if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python  >/dev/null 2>&1; then PY=python
else PY=""; fi

RC=0
if [ -n "$PY" ]; then
    "$PY" - "$SLUG" "$HASH" "$SUBJ" "$TS" <<'PYBODY'
import os, sys, time
slug, h, subj, ts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
rc = 0
def append_fsync(path, text):
    with open(path, "a", encoding="utf-8") as f:
        f.write(text); f.flush(); os.fsync(f.fileno())
def present(path, needle):
    try: return needle in open(path, encoding="utf-8").read()
    except FileNotFoundError: return False
claims = []
try:
    insec = False
    for ln in open(".coord/sessions/" + slug + ".md", encoding="utf-8"):
        if ln.startswith("files:"):
            insec = True
            inline = ln.split("files:", 1)[1].strip()
            if inline and inline != "[]": claims.append(inline)
            continue
        if insec:
            s = ln.rstrip("\n")
            if s.startswith("  - "): claims.append(s[4:].strip())
            elif s[:1] not in (" ", "\t"): break
except Exception: pass
claims_str = "; ".join(claims) if claims else "none (see session file)"
jline = ts + " | " + slug + " | " + h + " " + subj + "\n"
try: append_fsync(".coord/journal.md", jline)
except Exception as e: print("[cc_post_commit] JOURNAL WRITE ERROR:", e); rc = 1
for _ in range(3):
    if present(".coord/journal.md", h): break
    time.sleep(1)
else:
    if not present(".coord/journal.md", h):
        print("[cc_post_commit] JOURNAL NOT VERIFIED (L-SC-04). Reconcile journal<->git."); rc = 1
block = ("## " + ts + " | from: " + slug + " | to: coordinator\n"
         "COMMIT " + h + " " + subj + "\n"
         "claims-releasable: " + claims_str + " (release any committed+pushed)\n"
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
PYBODY
    RC=$?
else
    # pure-bash fallback (no python on PATH) — defense only; no fsync, mitigated by sync
    echo "[cc_post_commit] no python3/python — pure-bash fallback"
    printf '%s | %s | %s %s\n' "$TS" "$SLUG" "$HASH" "$SUBJ" >> .coord/journal.md
    {
        printf '## %s | from: %s | to: coordinator\n' "$TS" "$SLUG"
        printf 'COMMIT %s %s\n' "$HASH" "$SUBJ"
        printf 'claims-releasable: see .coord/sessions/%s.md files: (release any committed+pushed)\n' "$SLUG"
        printf 'blocker/question: none\n'
        printf 'next: awaiting operator\n---\n'
    } >> .coord/inbox/coordinator.md
    sync
    grep -qF "$HASH" .coord/journal.md            || { echo "[cc_post_commit] JOURNAL NOT VERIFIED"; RC=1; }
    grep -qF "$HASH" .coord/inbox/coordinator.md  || { echo "[cc_post_commit] FLUSH NOT VERIFIED"; RC=1; }
fi

# release commit.lock (phantom-aware; CC unlinks on real FS — L-SC-02/14)
if [ -e ".coord/locks/commit.lock" ]; then
    rm -f ".coord/locks/commit.lock" 2>/dev/null && echo "[cc_post_commit] commit.lock released" \
        || echo "[cc_post_commit] WARNING: could not remove commit.lock (phantom?)"
fi
sync

echo "[cc_post_commit] --- claims for $SLUG (release any whose work is pushed) ---"
awk '/^files:/{p=1} p{print} /^cc_task:/{p=0}' ".coord/sessions/$SLUG.md" 2>/dev/null || echo "  (session file not found)"

[ "$RC" -ne 0 ] && echo "[cc_post_commit] EXIT $RC — journal/flush NOT verified. Reconcile before continuing."
exit "$RC"
