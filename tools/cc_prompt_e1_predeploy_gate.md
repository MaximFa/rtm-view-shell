# CC task — E1: mandatory pre-deploy Compare gate (Compare drift exit-code + Update-RTMView gate)
> §4-DRAFTED by coordinator-0612 2026-06-14T13:06Z. Owner: dba-0610 (Part 1) + devops-2-0607 (Part 2). Executor: native CC, Windows.
> ISSUE ONLY AFTER E3 has committed (gate relies on Dimensions A/B/E/F being trustworthy: E2+E4+E3 done).
> Claims: db/tools/Compare-ToBaseline.ps1 + deploy/Update-RTMView.ps1. TWO commits (`db:` then `deploy:`). **NO push**.
> Final piece of A+E4: makes drift FAIL a deploy instead of silently corrupting a server (the PD-008 / 45-saga prevention).

## Why
Compare can now distinguish real vs false drift (E2 semantic A + Dim-B overload; E4 EF-model; E3 sequence-sync). E1 turns that
into a GATE: an upgrade refuses to proceed onto a drifted DB until a human reviews, unless explicitly forced. This is the durable
stop that would have caught the 45 cascade before deploy.

## Mandatory read (§40) + integrity + binding PREAMBLE
- Read: widget-planner / widget-creator / session-coord skills.
- §0.2: git status; branch v2-backend; hash-verify both claimed files vs HEAD (E3 must be in HEAD).
- Binding PREAMBLE -> .coord/cc/dba.md:
```
## 2026-06-14T13:06Z | binding: dba+devops <-> CC | directive: tools/cc_prompt_e1_predeploy_gate.md | status: open
### DIRECTIVE: E1 — Compare drift-based exit code (db) + Update-RTMView pre-migration Compare gate w/ -ForceDeploy (deploy). Claims: Compare-ToBaseline.ps1 + deploy/Update-RTMView.ps1. db:+deploy:. NO push.
```
## S1 barrier + S2 claim
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo BARRIER; exit 1; fi
python3 tools/coord_check_claims.py dba-0610 db/tools/Compare-ToBaseline.ps1 deploy/Update-RTMView.ps1
```

## PART 1 (db:) — Compare-ToBaseline.ps1: drift-based EXIT CODE
At the very END of the script (after the SUMMARY is written), set a machine-readable exit code based on REAL drift:
- Define REAL drift = ANY of:
  * Dimension A ENUMERATED objects (tables/indexes/constraints/routines/sequences) missing OR extra > 0  (the E2 object lists; IGNORE the cosmetic "detail/column lines" count — those alone do NOT block);
  * Dimension B real kind-mismatches > 0 (post-E2 multi-overload logic — i.e. a baseline kind missing on server);
  * Dimension F lagging sequences > 0 (E3);
  * Dimension E pending > 0 (only when -CheckEfModel was passed).
  (Dimensions C data + D migration-ledger = WARN only, do NOT block — they are deploy-applied separately.)
- `exit 0` if no real drift; `exit 2` if real drift (keep 1 reserved for script/tool errors). Always still write the delta + align files first.
- Print a final line: "GATE: <CLEAN|REAL DRIFT> — <delta file path>".
- IMPORTANT: keep all existing console/report output identical; only ADD the final classification + exit. A plain run that found
  only cosmetic/data/ledger items must exit 0 (so it does not spuriously block deploys).

## PART 2 (deploy:) — Update-RTMView.ps1: pre-migration Compare GATE
First READ deploy/Update-RTMView.ps1 to find the point BEFORE schema/migrations are applied (after backup, before apply).
Insert a gate there:
- Add a `[switch]$ForceDeploy` param (default off) and a `[switch]$SkipDriftGate` (alias) if a param block exists; else thread it through.
- Gate logic (before applying migrations):
```powershell
if (-not $ForceDeploy) {
    Write-Host "[E1] Pre-deploy drift gate: running Compare-ToBaseline..." -ForegroundColor Cyan
    & (Join-Path $RepoRoot "db\tools\Compare-ToBaseline.ps1") -DBHost $DBHost -DBPort $DBPort -Database $Database -User $AppUser -Password $AppPassword
    $driftExit = $LASTEXITCODE
    if ($driftExit -eq 2) {
        throw "[E1] REAL schema drift detected vs baseline — review the baseline_delta report before deploying. Re-run with -ForceDeploy to override (only if the drift is understood/intended)."
    } elseif ($driftExit -ne 0) {
        throw "[E1] Compare-ToBaseline failed to run (exit $driftExit) — cannot verify drift. Fix tooling or pass -ForceDeploy."
    }
    Write-Host "[E1] Drift gate PASSED (no real drift)." -ForegroundColor Green
} else {
    Write-Host "[E1] Drift gate SKIPPED (-ForceDeploy)." -ForegroundColor Yellow
}
```
Match the script's real variable names ($DBHost/$Database/$AppUser/$AppPassword/$RepoRoot — adapt to what Update-RTMView actually uses). Place the gate AFTER the pre-change backup (so a forced deploy still has a backup) and BEFORE migrations.

## Verification GATES (report)
1. Both files PowerShell-parse clean.
2. Compare exit code: `Compare-ToBaseline.ps1 -Database rtmviewdb_regen -Password <pw>; echo EXIT=$LASTEXITCODE` -> EXIT=0 (clean build, only cosmetic/data). 
3. Compare against a KNOWN-drifted DB (local dev rtmviewdb, which has the 9 phantoms) -> EXIT=2 + "GATE: REAL DRIFT". Paste both.
4. Update-RTMView gate: dry/echo path shows the gate runs before migrations; `-ForceDeploy` prints SKIPPED. (Do NOT run a real deploy.)

## Commit — TWO commits, NO push, under commit.lock
Hold the lock across both (or acquire/release per commit). 
```
# commit 1 (db)
bash tools/pre-commit-check.sh db/tools/Compare-ToBaseline.ps1
git add db/tools/Compare-ToBaseline.ps1
git commit -m "db: Compare E1 — drift-based exit code (2=real drift) for pre-deploy gate; cosmetic/data/ledger = warn-only"
# commit 2 (deploy)
bash tools/pre-commit-check.sh deploy/Update-RTMView.ps1
git add deploy/Update-RTMView.ps1
git commit -m "deploy: E1 pre-deploy Compare drift gate in Update-RTMView (-ForceDeploy override; runs after backup, before migrations)"
git rev-parse HEAD
```
§0.6 post-commit -> `bash tools/cc_post_commit.sh dba-0610 $(git log -1 --format=%h)` -> sync -> §0.7 re-sync both files from HEAD.

## Binding RESULT -> .coord/cc/dba.md (status: done)
```
### RESULT (by CC): commits <db-hash>+<deploy-hash>; Compare exit 0=clean/2=real-drift (cosmetic+C+D warn-only); regen EXIT=0, dev-rtmviewdb EXIT=2 (phantoms); Update-RTMView gate before migrations + -ForceDeploy; parse clean. NO push. verified: object-store + exit-code reruns.
```

## Report (chat) — NO push
two commit hashes; Compare EXIT on regen (0) vs drifted dev (2); gate placement confirmed (after backup, before migrations) + -ForceDeploy override; parse OK. NO push.
