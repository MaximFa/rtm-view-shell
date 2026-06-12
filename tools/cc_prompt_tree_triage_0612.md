# CC TASK — Working-tree triage & at-risk-artefact rescue (coordinator-0612)

> Issued by coordinator-0612 (RTM Coordinator, Cowork-A, branch v2-backend).
> ROOT FINDING (verified by object store): working tree is pervasive PD-007 mount-drift
> against HEAD=4862269 (the truth). DO NOT trust mount `git status`/line-counts.
> Verify EVERY decision by object store: `git hash-object <f>` vs `git rev-parse HEAD:<f>`,
> `git cat-file -e HEAD:<f>` for tracked-state. Restore drift ONLY with
> `git show HEAD:<f> > <f>` (NEVER `git checkout HEAD -- <f>` — fails on this mount).

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

## §0.6a Integrity block — Step 0 (run first, per CLAUDE.md §0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
# Do NOT auto-restore by line-count here — this task IS the triage. Just observe.
sync
echo "=== integrity observed ==="
```

## Multi-session sync — MANDATORY (apply tools/cc_prompt_sync_block.md)
Session slug: `coordinator-0612`
Claims for this task (explicit, recovery/triage scope — coordinator-driven, other sessions dormant):
`.claude/skills/**, .coord/coordinator-commands.md, PROJECT_STATUS.md, deploy/Apply-Server45Upgrade.ps1,
docs/**, src/CcDashboard.ApplyService/**, src/CcDashboard.Domain/Domain/RtsGridMetric.cs,
src/CcDashboard.Infrastructure/**, db/**, testing/234_acceptance_verify.md, tools/**, tests/**`
- S1: if `.coord/push/request.md` contains "FREEZE ACTIVE" -> STOP (no open barrier expected).
- S2: run `python3 tools/coord_check_claims.py coordinator-0612 <paths>`; if exit 1 -> STOP, report.
- S3: commit.lock around EVERY git add/commit (acquire script in sync_block, owner=coordinator-0612,
  retry 5x60s, phantom-aware). Lock covers §0.4 plumbing path too.
- S4: after each commit run `bash tools/cc_post_commit.sh coordinator-0612 $(git log -1 --format=%h)`.
- S5: NO `git push`.

---

## STEP 1 — Clear stale .git/index.lock (§0.4)
```bash
ls -la .git/index.lock 2>/dev/null
rm .git/index.lock 2>/dev/null && echo "removed" || echo "cannot rm (Operation not permitted) -> use GIT_INDEX_FILE temp-index for all git add/commit below (§0.4):  cp .git/index /tmp/cc-idx ; GIT_INDEX_FILE=/tmp/cc-idx git add ... ; ... ; cp /tmp/cc-idx .git/index"
```

## STEP 2 — RESTORE drift from HEAD (negative-delta / truncated tracked files)
These are verified mount-truncations. Restore each, then confirm the tail is a PROPER closing token
(`}`, `` ``` ``, `</Project>`, full sentence) — NOT mid-line.
```bash
for f in \
  ".claude/skills/rtm-metrics-expert/rtm-metrics-expert.md" \
  ".claude/skills/session-coord/session-coord.md" \
  "deploy/Apply-Server45Upgrade.ps1" \
  "src/CcDashboard.ApplyService/Program.cs" \
  "src/CcDashboard.ApplyService/CcDashboard.ApplyService.csproj" \
  "tools/Build-ProdRelease.ps1" \
; do
  git show HEAD:"$f" > "$f" && echo "RESTORED: $f ($(wc -l < "$f") lines)" ; tail -1 "$f"
done
sync
```

## STEP 3 — Ambiguous tracked files: VERIFY then act (report, do not guess)
For each below: `git diff HEAD -- <f>`. If the diff is ONLY removals/truncation -> RESTORE from HEAD.
If it contains genuine additions -> LEAVE as-is and list it in the report (coordinator will classify).
```bash
for f in ".coord/coordinator-commands.md" "testing/234_acceptance_verify.md"; do
  echo "===== $f ====="; git diff HEAD -- "$f"
done
```
Action rule: `.coord/coordinator-commands.md` should be a SHORT pointer to skill §10 (defers). If the diff
shows it being TRIMMED toward a pointer -> that is genuine (KEEP). If it shows truncation of real content
without the pointer intent -> RESTORE. Report your decision for both files; commit decision deferred to STEP 6.

## STEP 4 — Phantom-tracked "??" files (mount lies: tracked at HEAD)
These appear untracked but ARE tracked at HEAD. Verify + restore if drifted:
```bash
for f in \
  "src/CcDashboard.Domain/Domain/RtsGridMetric.cs" \
  "src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs" \
  "src/CcDashboard.Infrastructure/Migrations/BackendEmulation/BackendEmulationDbContextModelSnapshot.cs" \
  "src/CcDashboard.Infrastructure/Migrations/BackendEmulation/20260606100233_AddCatalogueFieldsToRtsGridMetric.cs" \
  "src/CcDashboard.Infrastructure/Migrations/BackendEmulation/20260606100233_AddCatalogueFieldsToRtsGridMetric.Designer.cs" \
  "db/schema.sql" "db/data/02_metrics.sql" "db/migrations/20260606_003_catalog_backfill.sql" \
; do
  if git cat-file -e HEAD:"$f" 2>/dev/null; then
     wt=$(git hash-object "$f"); hd=$(git rev-parse HEAD:"$f")
     if [ "$wt" != "$hd" ]; then git show HEAD:"$f" > "$f"; echo "RESTORED (phantom-tracked drift): $f"; else echo "OK==HEAD: $f"; fi
  else
     echo "GENUINELY-UNTRACKED (report for STEP 6): $f"
  fi
done
sync
```

## STEP 5 — JUNK: gitignore + remove (do NOT commit)
```bash
# Append ignore patterns (Python+fsync; idempotent — skip lines already present)
python3 - <<'PY'
import os
adds = ["docs/**/node_modules/","**/node_modules/","~$*.docx","*.tmp0612",".sync_marker","tools/__pycache__/","**/__pycache__/"]
p=".gitignore"
cur=open(p,encoding="utf-8").read() if os.path.exists(p) else ""
new=cur if cur.endswith("\n") or cur=="" else cur+"\n"
for a in adds:
    if a not in cur: new+=a+"\n"
if new!=cur:
    with open(p,"w",encoding="utf-8") as f: f.write(new); f.flush(); os.fsync(f.fileno())
    print("updated .gitignore")
else: print(".gitignore already covers")
PY
# Remove zero-byte placeholder pngs + stray node_modules dirs (safe; not deliverables)
find docs/bi -name '*.png' -size 0 -delete 2>/dev/null && echo "removed zero-byte bi pngs"
rm -rf docs/user-documentation/admin/node_modules docs/user-documentation/user/screenshots/node_modules tools/__pycache__ 2>/dev/null
echo "junk cleanup done"
```
Leave (do NOT commit, do NOT delete) these scratch/continuity files — they are NOT project deliverables:
Evidence-Log.md, Method-Charter-v0.1.md, Method-Discussion-Log.md, ProductRoles.txt, SessionCoord.txt,
build_migration_plan.js, RTM_Migration_Plan_MSSQL_to_PostgreSQL.docx, RTM_View_Shell_Test_Report_v1.docx,
*.skill (doc-sync-agent.skill, user-doc-expert.skill), widget-planner/, skills-lock.json,
docs/Multi-Session_Operator_Guide_RU_v2.docx (superseded by v4),
tools/f1_readonly_patch.py, tools/rv1_absence_test.py, tools/rv1b_fix.py, tools/write_*.py.

## STEP 6 — COMMIT genuine work (verified), module-grouped, narrow globs, commit.lock per commit
Commit ONLY these verified-genuine items. For each untracked path: confirm `git cat-file -e HEAD:<f>`
FAILS (truly new) before adding. Use `git add <explicit paths>` — NEVER `git add -A`.
`.claude/**` needs `git add -f` (gitignored).

(a) `docs:` — genuine doc edits + new techwriter deliverables:
    PROJECT_STATUS.md, docs/metrics-hot-reload-contract.md, docs/user-documentation/DOC-REGISTRY.md,
    docs/DOCS_INVENTORY.md, docs/methodology/ (real .md/.docx only), docs/bi/ (real .md/.docx only,
    after STEP 5 png cleanup), docs/assets/ (brand assets), docs/security-review-hotreload-0609.md,
    docs/Multi-Session_Operator_Guide_RU_v4.docx
    + `git add -f .claude/skills/app-cyber-security-expert/SKILL.md`
    Commit msg: `docs: rescue uncommitted techwriter/status/spec edits + brand assets (PD-007 triage)`
(b) `db:` — genuinely-new catalog DB artefacts (only those STEP 4 marked GENUINELY-UNTRACKED):
    db/migrations/20260606_003_catalog_backfill.sql (+ any STEP4 db/ marked new)
    Commit msg: `db: add catalog backfill migration (PD-007 triage rescue)`
(c) `deploy:`/`docs:` — new CC prompts genuinely untracked:
    tools/cc_prompt_applysvc_winservice.md, tools/cc_prompt_build_234_iter1.md, tools/cc_prompt_build_45.md,
    tools/cc_prompt_deploy_backport_234fixes.md, tools/cc_prompt_unify_command_registry.md,
    tools/gen_catalog_backfill.py, tools/lint_metrics.py
    Commit msg: `deploy: archive CC prompts + catalog tooling (PD-007 triage)`
Skip any of the above that STEP 4/verification shows is actually tracked==HEAD or non-existent.
After EACH commit: §0.6 post-commit verify (git status, hash-check committed files) +
`bash tools/cc_post_commit.sh coordinator-0612 $(git log -1 --format=%h)` + PD-007 re-sync of committed files.

## STEP 7 — REPORT to coordinator (NO push)
Append a block to `.coord/inbox/coordinator-0612.md` (Python+fsync):
- index.lock outcome; files RESTORED (count + list); STEP 3 decisions (coordinator-commands, 234_acceptance);
  STEP 4 phantom results; what was COMMITTED (hashes + globs) vs LEFT untracked; final `git status --short`.
- Confirm: NO push performed. unpushed commit count (origin/v2-backend..HEAD).
Do NOT push. Barrier/push handled separately by coordinator.
