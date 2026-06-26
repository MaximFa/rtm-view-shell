# CC TASK — commit INC-001 RCA ledger (docs:, native CC, commit.lock, NO push)

Issued by: incident-0620 (Cowork) · authorised by coordinator-0612 (07:53:40Z, rides push barrier #3).
Branch MUST be `v2-backend`. Single file: `docs/incidents/incidents.md`. NO push (§37).

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

## Step 0 — INTEGRITY (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD   # must print: v2-backend  (abort if not)
git status --short
# hash-verify the target vs HEAD (mount gives false-M). We EXPECT a real diff here (RCA edits):
echo "WT:  $(git hash-object docs/incidents/incidents.md)"
echo "HEAD:$(git rev-parse HEAD:docs/incidents/incidents.md)"
# Do NOT restore docs/incidents/incidents.md — the working-tree version is the intended RCA content.
tail -3 docs/incidents/incidents.md   # must end with a complete line (no truncation)
wc -l docs/incidents/incidents.md     # expect ~164 lines
```
If `tail -3` shows a truncated/mid-sentence ending, STOP and report — do not commit a truncated ledger.

## Step 0.6b — BINDING PREAMBLE (Python+fsync, append to .coord/cc/incident.md)
```
## BINDING <UTC> | spec: incident | directive: tools/cc_prompt_incident_ledger_commit.md | status: open
### DIRECTIVE: commit docs/incidents/incidents.md as `docs:` (INC-001 RCA). claim: docs/incidents/**. gate: commit.lock, no push.
```

## Sync / claims
Slug: incident-0620. Claim: docs/incidents/** (only). Touch ONLY docs/incidents/incidents.md.
Barrier note: if `.coord/push/request.md` exists, this commit is the COORDINATOR-AUTHORISED barrier-rider
(coordinator-0612 07:53:40Z) — proceed; it must land before/with barrier #3. Otherwise proceed normally.

## Step 1 — acquire commit.lock (atomic, retry 5×60s)
```bash
python3 - <<'PY'
import os,time,datetime
lock=".coord/locks/commit.lock"; os.makedirs(os.path.dirname(lock),exist_ok=True)
for i in range(5):
    try:
        fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
        os.write(fd,f"incident-0620 {datetime.datetime.utcnow().isoformat()}Z".encode()); os.fsync(fd); os.close(fd)
        print("LOCK ACQUIRED"); break
    except FileExistsError:
        try: print("busy, owner:",open(lock).read())
        except: print("busy (unreadable lock)")
        time.sleep(60)
else:
    raise SystemExit("commit.lock busy after 5x60s — ABORT, report owner")
PY
```

## Step 2 — pre-commit check + stage (narrow) + commit
```bash
bash tools/pre-commit-check.sh docs/incidents/incidents.md
# If exit code 1: release lock, restore from HEAD ONLY IF truncated, report. Do NOT commit.

cp .git/index /tmp/inc-idx
GIT_INDEX_FILE=/tmp/inc-idx git add docs/incidents/incidents.md   # ONLY this file — no git add -A
TREE=$(GIT_INDEX_FILE=/tmp/inc-idx git write-tree)
COMMIT=$(GIT_INDEX_FILE=/tmp/inc-idx git commit-tree "$TREE" -p HEAD -m "docs: INC-2026.06.20-001 RCA — Memurai Developer 10-day auto-shutdown root + durable reframe (d)>(a)>(b)")
python3 - <<PY
import os,subprocess
gd=subprocess.check_output(['git','rev-parse','--git-dir']).decode().strip()
head=open(os.path.join(gd,'HEAD')).read().strip()
ref=head[5:] if head.startswith('ref: ') else None
assert ref, "detached HEAD"
open(os.path.join(gd,ref),'w').write("$COMMIT\n")
print("HEAD updated ->","$COMMIT")
PY
cp /tmp/inc-idx .git/index
```

## Step 3 — post-commit verify (§0.6)
```bash
git log --oneline -1
git status --short                      # docs/incidents/incidents.md must NOT appear as M
git diff HEAD -- docs/incidents/incidents.md   # must be empty
git show HEAD:docs/incidents/incidents.md | wc -l ; wc -l docs/incidents/incidents.md  # must match
```
If working tree != HEAD for this file — commit incomplete; re-stage/redo. Never leave WT != HEAD.

## Step 4 — journal + lock release + re-sync (§0.7)
```bash
bash tools/cc_post_commit.sh incident-0620 <HASH_FROM_STEP3>   # journal + flush + lock-release (atomic)
# if cc_post_commit.sh unavailable, manually: append journal line (Python+fsync), then remove commit.lock
git show HEAD:docs/incidents/incidents.md > docs/incidents/incidents.md   # PD-007 re-sync
sync
```

## Step 0.6b — BINDING POSTAMBLE (Python+fsync, append to .coord/cc/incident.md)
```
### RESULT: commit <hash> . files docs/incidents/incidents.md (<lines>) . build/test n/a (docs) . status done . blockers none . verified: object-store (git show HEAD == WT)
```

## DO NOT push (§37). Report the commit hash back to incident-0620 / coordinator.
