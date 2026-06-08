# CC Task — C1: align.sql WARNING header + baseline-can-be-wrong lesson (guard against self-inflicted 42809)

> Session devops-2-0607. Follow-up to the 01-fix. Compare-ToBaseline's align.sql is currently DANGEROUS if the
> repo baseline is itself stale (the 13-prokind case proved it: running align.sql would have REVERTED prod's
> correct PROCEDUREs to FUNCTIONs -> 42809 storm). Add a prominent WARNING to the generated align.sql header,
> and record the lesson (baseline can be the wrong side) in rtm-service-expert §10 + CLAUDE.md §38.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== Integrity check complete ==="
```
db/tools/Compare-ToBaseline.ps1 + .claude/skills/rtm-service-expert/rtm-service-expert.md + CLAUDE.md may be
PD-007-truncated — the loop restores from HEAD. Confirm each ==HEAD before editing.
Known false-M: db/data/02_metrics.sql, db/schema.sql.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS
Session slug: `devops-2-0607`
Claims: `db/tools/Compare-ToBaseline.ps1`, `.claude/skills/rtm-service-expert/rtm-service-expert.md`, `CLAUDE.md`

### S1. Push barrier check (marker-based)
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md; echo STOP; exit 1
fi
```
### S2. Claim discipline
```bash
python3 tools/coord_check_claims.py devops-2-0607 db/tools/Compare-ToBaseline.ps1 .claude/skills/rtm-service-expert/rtm-service-expert.md CLAUDE.md
```
Modify ONLY those three (plus /tmp throwaways). `.claude/` is gitignored -> stage with `git add -f`.
### S3. Commit lock — `/tmp/acquire_lock.py` (owner devops-2-0607), retry 5×60s, phantom-aware. While holding:
`bash tools/pre-commit-check.sh` -> `git add db/tools/Compare-ToBaseline.ps1 CLAUDE.md` +
`git add -f .claude/skills/rtm-service-expert/rtm-service-expert.md`
-> `git commit -m "docs: align.sql WARNING header + baseline-can-be-wrong lesson (rtm-service-expert §10, CLAUDE.md §38)"`
-> §0.6 post-commit verify.
### S4 + S4b. `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` ; then `sync`.
### S5. NO push (§37).

---

## Change 1 — align.sql WARNING header (db/tools/Compare-ToBaseline.ps1)
In the AlignLines header block (around lines ~160-166, the `-- ALIGNMENT SCRIPT -- Bring server up to baseline`
header, BEFORE `\set ON_ERROR_STOP on`), insert a prominent warning. Add these lines (keep the existing ones):
```
[void]$AlignLines.Add("-- ##############################################################################")
[void]$AlignLines.Add("-- !!! REVIEW BEFORE RUNNING -- DO NOT APPLY BLINDLY !!!")
[void]$AlignLines.Add("-- This script assumes the REPO BASELINE is the source of truth. If the baseline is")
[void]$AlignLines.Add("-- itself stale/wrong, applying it will DAMAGE a correct server. In particular the")
[void]$AlignLines.Add("-- DIMENSION B (routine-kind) section can DROP+recreate routines in the WRONG kind")
[void]$AlignLines.Add("-- (e.g. revert a correct PROCEDURE back to FUNCTION) -> PostgreSQL 42809 on every RTM")
[void]$AlignLines.Add("-- CALL (RTM-SEC-002). Verify the DIRECTION of each change per object against the live")
[void]$AlignLines.Add("-- server before running. When in doubt, fix the BASELINE, not the server.")
[void]$AlignLines.Add("-- ##############################################################################")
```
Place it immediately after the existing `-- =====...=====` top border / `-- Run as:` line and before
`\set ON_ERROR_STOP on`. Do not change any other logic. (If line numbers drifted, locate by the
`-- ALIGNMENT SCRIPT` / `\set ON_ERROR_STOP on` anchors.)

## Change 2 — rtm-service-expert §10 lesson
Append a new lesson bullet under `## 10. Known bugs / lessons` (do not disturb existing entries):
- Title: "Baseline can be the WRONG side (2026-06-07, Compare-ToBaseline)". Content (~6-8 lines):
  Compare-ToBaseline flags repo-vs-server differences, but it TRUSTS the repo baseline as correct. The baseline
  itself can be the defect: db/functions/*.sql shipped 13 RTM-write routines as FUNCTION while prod (correct, per
  §33.8) had them as PROCEDURE. Compare reported "expected FUNCTION, server has PROCEDURE" and its align.sql would
  have reverted prod -> 42809 storm. RULE: never run align.sql blindly; for routine-kind diffs verify which side
  is right (RTM-called writes MUST be PROCEDURE, §33.8); when the baseline is wrong, fix db/functions, do NOT
  touch the server. Also: a routine that is FUNCTION in BOTH repo and prod (e.g. RTSData_SetChatMessage) is NOT
  flagged by the prokind diff at all -> audit ALL RTM-called writes by kind, not just diffs.

## Change 3 — CLAUDE.md §38 note
In §38 (DB versioning), add a short subsection note (~5 lines) titled "align.sql is advisory — verify direction":
the Compare-ToBaseline align.sql is a STARTING POINT, not an auto-apply. It assumes the repo baseline is correct;
if the baseline is stale the routine-kind section can break a correct server (42809, RTM-SEC-002). Always review
direction per object; prefer fixing the baseline over reverting the server. Reference: rtm-service-expert §10.

## Self-test (no live DB)
```bash
powershell -NoProfile -Command "$null = [ScriptBlock]::Create((Get-Content -Raw 'D:\Claude\Projects\RTM View Shell\db\tools\Compare-ToBaseline.ps1')); 'PARSE OK'"
grep -c "REVIEW BEFORE RUNNING" db/tools/Compare-ToBaseline.ps1   # expect >=1
grep -c "Baseline can be the WRONG side" .claude/skills/rtm-service-expert/rtm-service-expert.md  # expect 1
grep -c "align.sql is advisory" CLAUDE.md   # expect 1
```

## Commit
ONE commit, prefix `docs:`, message:
`docs: align.sql WARNING header + baseline-can-be-wrong lesson (rtm-service-expert §10, CLAUDE.md §38)`
Then the S4 wrapper. NO push.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately (§37).
