# CC Task — barrier push 2026-06-09: 2 commits + EXPLICIT-PATH artefact git-home (NO blanket sweep)

> ONLY task allowed while .coord/push/request.md has FREEZE ACTIVE. Push IS allowed in THIS prompt.
> Branch: v2-backend. Mount git-status is UNRELIABLE (feedback_git_mount_distrust) — but YOU run native
> on Windows, so your git is reliable. Still: add ONLY the explicit paths below. NEVER `git add -A`,
> NEVER `git add docs/` or `git add tools/` (directory blanket pulls node_modules/__pycache__/junk).

## Step A — verify freeze + quorum + frozen set
```bash
cd "D:\Claude\Projects\RTM View Shell"
grep -q "FREEZE ACTIVE" .coord/push/request.md || { echo "no active freeze — STOP"; exit 1; }
grep -c "READY" .coord/push/ACKS.md            # expect >=4 (backend/shell/metrics/devops)
git fetch origin
git log --oneline origin/v2-backend..HEAD       # MUST be exactly: d6b1672, 5acf274
test "$(git rev-list --count origin/v2-backend..HEAD)" = "2" || { echo "set drifted (!=2) — STOP"; exit 1; }
```
If count != 2 or quorum < 4 — STOP, report.

## Step B — phantom commit.lock guard
```bash
if [ -s .coord/locks/commit.lock ] && grep -q owner .coord/locks/commit.lock 2>/dev/null; then
  echo "REAL LOCK — STOP"; cat .coord/locks/commit.lock; exit 1; fi
```

## Step C — git-home NEW artefacts BY EXPLICIT PATH ONLY (docs: commit)
Add EXACTLY these paths (each guarded; a missing/again-absent path is skipped, never errors).
DO NOT add anything else. DO NOT add: Evidence-Log.md, Method-Charter-v0.1.md, Method-Discussion-Log.md
(stray lab dupes — belong on `lab` branch, NOT here), node_modules, __pycache__, *.skill, .sync_marker.
```bash
cp .git/index /tmp/cc-idx
for f in \
  docs/metrics-hot-reload-contract.md \
  tools/cc_prompt_ngc_insert_fix.md \
  tools/cc_prompt_orchestrator_patch_0609.md \
  tools/cc_prompt_lab_worktree_repair.md \
  tools/cc_prompt_lab_v05_commit.md \
  tools/cc_prompt_shell_darkmode.md \
  tools/darkmode_config_gaps_0609.md \
  testing/234_acceptance_verify.md \
  devops/ \
  staging/baseline_delta_20260608-205617.txt \
  staging/fix_setchatmessage_server45.sql \
  staging/patch_abandoned_metrics.sql \
  staging/run_migration_004.ps1 \
  staging/server45_dependency_probe.sql \
  ; do
    [ -e "$f" ] && GIT_INDEX_FILE=/tmp/cc-idx git add -- "$f" 2>/dev/null || true
done
GIT_INDEX_FILE=/tmp/cc-idx git diff --cached --name-only    # REVIEW: only the intended files, NO junk
```
If the staged list shows ANYTHING outside the explicit set above — STOP, report (do not commit).
Also `tail -3` each staged NEW text artefact (contract md + cc_prompt md) — if any ends mid-line/truncated, STOP (mount cache write-back, PD-007). New files have no HEAD to restore from — re-fetch from the owning session.
```bash
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs: hot-reload contract + CC prompts (darkmode/orchestrator/lab/ngc) + 234 acceptance"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Step D — push (frozen 2 commits + the docs commit)
```bash
git push origin v2-backend
git rev-parse --short origin/v2-backend HEAD     # MUST match
```

## Step E — barrier cleanup + journal (mount can't unlink -> overwrite with tombstone)
```bash
python3 - <<'PY'
import os
def tomb(p, msg):
    t=p+".tmp"; open(t,"w").write(msg); 
    import os as o
    f=open(t,"a"); f.flush(); o.fsync(f.fileno()); f.close(); os.replace(t,p)
tomb(".coord/push/request.md", "# BARRIER CLEARED 2026-06-09 — pushed 1807b44..origin tip (v2-backend). FREEZE LIFTED. tombstone.\n")
tomb(".coord/push/ACKS.md", "# BARRIER CLEARED 2026-06-09. tombstone.\n")
# journal append
j=".coord/journal.md"; s=open(j).read()
if not s.endswith("\n"): s+="\n"
import subprocess
tip=subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
s+="2026-06-09T__:__Z | coordinator-0609 | PUSHED 1807b44.."+tip+" (v2-backend): 5acf274 dark-mode + d6b1672 orchestrator + docs(contract/prompts/234). barrier cleared.\n"
open(j+".t","w").write(s); import os as o2; f=open(j+".t","a"); f.flush(); o2.fsync(f.fileno()); f.close(); os.replace(j+".t",j)
print("barrier cleaned + journaled")
PY
sync
```

## Step F — report
- origin/v2-backend tip hash (== HEAD).
- the docs: commit hash + its file list (confirm NO junk).
- remaining `git status --short | grep '^??'` filtered (exclude node_modules/__pycache__/.skill/.sync/Evidence-Log/
  Method-Charter-v0.1/Method-Discussion-Log/*.docx) — for a SEPARATE follow-up junk-gitignore task. Do NOT act on them now.
NO further commits. NO push beyond origin/v2-backend.
