# CC Task — barrier push #2 (2026-06-09): 6 hot-reload commits + EXPLICIT-PATH design-doc git-home

> ONLY task while .coord/push/request.md has FREEZE ACTIVE. Push IS allowed here. Branch: v2-backend.
> Quorum verified 5/5 (backend/shell/devops/metrics-3/daytrend). NEVER `git add -A` / `git add tools/` /
> `git add docs/` — a STRAY junk file "tools\lint_metrics.py" (literal backslash, mount artifact) is present
> and MUST NOT be committed (metrics-3 flag). Add ONLY the explicit paths below.

## Step A — verify freeze + quorum + frozen set
```bash
cd "D:\Claude\Projects\RTM View Shell"
grep -q "FREEZE ACTIVE" .coord/push/request.md || { echo "no freeze — STOP"; exit 1; }
ls .coord/push/acks/*.md | wc -l            # expect 5
git fetch origin
git log --oneline origin/v2-backend..HEAD     # MUST be 6: f098cb7 cfa2925 b5e6fdf a6f5572 9cc8a66 160259a
test "$(git rev-list --count origin/v2-backend..HEAD)" = "6" || { echo "set drift (!=6) — STOP"; exit 1; }
```
If count != 6 or acks < 5 — STOP, report.

## Step B — phantom commit.lock guard
```bash
if [ -s .coord/locks/commit.lock ] && grep -q owner .coord/locks/commit.lock 2>/dev/null; then
  echo "REAL LOCK — STOP"; cat .coord/locks/commit.lock; exit 1; fi
```

## Step C — git-home untracked design docs BY EXPLICIT PATH ONLY (docs: commit)
DO NOT add anything else. Especially NOT "tools\lint_metrics.py" (junk), node_modules, __pycache__,
Evidence-Log.md / Method-Charter*.md / Method-Discussion-Log.md (lab strays), *.skill, .sync*.
```bash
cp .git/index /tmp/cc-idx
for f in \
  docs/metrics-apply-endpoint-contract.md \
  docs/Multi-Session_Operator_Guide_RU_v5.docx \
  tools/cc_prompt_build_234_rebuild.md \
  tools/cc_prompt_apply_service_impl.md \
  tools/cc_prompt_hotreload_compile.md \
  tools/cc_prompt_shell_deploy_tab.md \
  tools/cc_prompt_drop_typo_metrics.md \
  tools/cc_prompt_catalog_dedup_cleanup.md \
  tools/cc_prompt_session_coord_commands.md \
  tools/cc_prompt_push_0609.md \
  tools/cc_prompt_lab_docx_gitignore.md \
  ; do
    [ -e "$f" ] && GIT_INDEX_FILE=/tmp/cc-idx git add -- "$f" 2>/dev/null || true
done
GIT_INDEX_FILE=/tmp/cc-idx git diff --cached --name-only    # REVIEW: exactly the 11 above, NO junk
```
If the staged list contains ANY path outside the 11 above (esp. a backslash-name) — STOP, report, do NOT commit.
Then tail-check the new text files for truncation (PD-007; new files have no HEAD to restore):
```bash
for f in docs/metrics-apply-endpoint-contract.md tools/cc_prompt_*.md; do
  case "$f" in *cc_prompt_build_234_rebuild*|*apply_service_impl*|*hotreload_compile*|*shell_deploy_tab*|*drop_typo_metrics*|*catalog_dedup_cleanup*|*session_coord_commands*|*push_0609*|*lab_docx_gitignore*|*metrics-apply-endpoint*) tail -1 "$f" | grep -qE '.' && echo "OK $f" || echo "EMPTY-END $f — CHECK";; esac
done
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs: hot-reload apply-endpoint contract + operator guide v5 + CC prompts (build/apply/compile/deploy-tab/metrics-cleanup/coord-cmds)"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Step D — push (6 commits + the docs commit = 7)
```bash
git push origin v2-backend
git rev-parse --short origin/v2-backend HEAD     # MUST match
```

## Step E — barrier cleanup + journal (mount can't unlink -> tombstone overwrite)
```bash
python3 - <<'PY'
import os, subprocess
def tomb(p,msg):
    t=p+".t"; f=open(t,"w"); f.write(msg); f.flush(); os.fsync(f.fileno()); f.close(); os.replace(t,p)
tip=subprocess.check_output(["git","rev-parse","--short","HEAD"]).decode().strip()
tomb(".coord/push/request.md","# BARRIER CLEARED 2026-06-09 #2 — pushed daaa7c3..%s (v2-backend). FREEZE LIFTED. tombstone.\n"%tip)
j=".coord/journal.md"; s=open(j).read()
if not s.endswith("\n"): s+="\n"
s+="2026-06-09T__:__Z | coordinator-0609 | PUSHED #2 daaa7c3..%s (v2-backend): 6 hot-reload commits (NGC fix 160259a, compile 9cc8a66, deploy-tab a6f5572, skill-§14 b5e6fdf, ledger cfa2925, apply-service f098cb7) + docs(11 explicit). barrier cleared.\n"%tip
t=j+".t"; f=open(t,"w"); f.write(s); f.flush(); os.fsync(f.fileno()); f.close(); os.replace(t,j)
print("barrier cleaned + journaled, tip="+tip)
PY
sync
```
Also clear stale per-session acks (overwrite each with a one-line tombstone — do NOT rely on rm, mount can't unlink):
```bash
for a in .coord/push/acks/*.md; do printf '# barrier #2 cleared, tombstone\n' > "$a"; done; sync
```

## Step F — report
origin/v2-backend tip (==HEAD); docs commit hash + its file list (confirm exactly 11, NO junk); confirm
"tools\lint_metrics.py" was NOT committed; remaining ?? (filtered) for the follow-up gitignore task. No further push.
