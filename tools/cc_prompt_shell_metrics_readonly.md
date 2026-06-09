# CC Task (Shell specialist, slug shell-0609) — F-1 fix: MetricsPage FULLY READ-ONLY (metrics = vendor constants)

> DRAFT for coordinator §4. Security fix (F-1): metrics are VENDOR PRODUCT-CONSTANTS. The client must NOT be able
> to create / edit / delete / translate a metric in ANY way. This removes the arbitrary-input RCE surface
> (MetricFunction/Parameter/Format are Roslyn-compiled by RTM → user-entered expression = code-exec risk).
> Operator decision 2026-06-10 (03:10 supersedes 03:00): FULL read-only for EVERYONE, incl. localization.
> The ONLY way a metric changes on a client = vendor package-deploy (the Deploy tab from a6f5572 / apply-service).

## Git push — DO NOT (§37). Commit only; push requested separately via tools/cc_prompt_push.md.

---

## Step 0 — §0.6a MANDATORY INTEGRITY CHECK (first, no exceptions)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF)"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== integrity check complete ==="
```
NOTE: mount `.git` reads can be unreliable (git rev-parse HEAD may fail / show `A ./`). Verify each claimed file by
EXPLICIT hash `git hash-object <f>` vs `git rev-parse <HEADHASH>:<f>`. Do not escalate corruption from mount git status.

## Step 0b — §40 mandatory skill reads (before any work)
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
```
Then the Shell specialist skill for THIS task (security):
```
Read: .claude/skills/app-cyber-security-expert/...  (F-1 RCE surface, least-privilege, no client-driven metric mutation)
Read: .claude/skills/blazor-frontend-design/...     (clean removal of buttons/modals without breaking the page)
```

## Multi-session sync (§42.6) — slug shell-0609
> Apply the machinery from `tools/cc_prompt_sync_block.md` (READ it first): phantom-aware `/tmp/acquire_lock.py` + S1/S3/S4.

CLAIMS (all in `web` file-mode; coordinator ratifies in §4. EXPANSION FLAG: coordinator named MetricsPage +
ConfigurationCommands; the clean removal ALSO needs the validator + the orphan request DTOs, else build breaks.
coord_check_claims = exit 0 for all four, none held by active sessions [verified at draft: backend=RTM, daytrend=DayTrend,
devops=ApplyService/db, metrics-3=catalogue data]):
  - src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor            (mine — remove all mutation UI)
  - src/CcDashboard.Application/Commands/Configuration/ConfigurationCommands.cs      (remove 4 metric-mutation commands+handlers)
  - src/CcDashboard.Application/Validators/CommandValidators.cs                      (remove validators for the removed commands)
  - src/CcDashboard.Contracts/DTOs/Configuration/ConfigurationDtos.cs               (remove orphan request DTOs)
- **S1 push-barrier:** `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> if match STOP & report.
- **S2 claims:** `python3 tools/coord_check_claims.py shell-0609 <each path above>` -> exit 1 = STOP. Touch ONLY claimed paths (+ /tmp scratch).
- **S3 commit.lock** around every git add/commit; create+use `/tmp/acquire_lock.py` per sync_block (owner shell-0609; 15-min stale=report+wait). Covers §0.4 plumbing path.
- **S4 post-commit:** `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then `sync`.
- **S5:** no git push.

## §0.3 — Edit tool BANNED. ALL writes via Python read->modify->write + os.fsync, then `sync && tail -3 && wc -l`. Applies to .cs, .razor — everything.

---

## THE WORK — make the metrics screen read-only; remove every metric-mutation path

> The coordinator's line numbers (03:00/03:10) are PRE-deploy-tab and now stale (MetricsPage grew in a6f5572).
> Locate elements BY NAME/role, not by line.

### 1. MetricsPage.razor — remove ALL mutation UI + handlers
REMOVE:
- "New" / add-metric button.
- per-row "Edit" and "Delete" buttons (and the actions column if it now only held those).
- the create/edit metric MODAL (the one with MetricParameter / MetricFormat / MetricFunction / DataType / ValueType
  fields) + its "Save" button + the delete-confirm dialog.
- the TRANSLATIONS modal + the "Translations" button + `OpenTranslationModal` / `ClearTranslation` / save-translation
  handlers (localization editing — operator: removed too).
- ALL `@code` state + methods that exist ONLY for the above (OpenModal, Save, Saving, IsNew, Edit* fields,
  DeleteTarget, translation modal state, the `Mediator.Send` calls for Save/Delete/translation commands).
KEEP (do NOT touch):
- the read-only metrics LIST/table (columns, search SearchId/SearchDesc, filters, pagination) — display only.
- the "Deploy new metrics" tab and everything it added in a6f5572 (delta read, Deploy, Recompile, IMetricApplyClient,
  IMetricDeployLedgerReader, IRtmRelayService) — that is the SANCTIONED change path.
- DISPLAY of DisplayName/Description/localized strings (read is fine; only EDITING is removed).
- `GetRtsGridMetricsQuery` read load (LoadAsync).
RESULT: the page has ZERO metric-mutation controls. Only: read-only list + Deploy tab.

### 2. ConfigurationCommands.cs — remove the 4 metric-mutation commands + handlers
Delete entirely (command record + handler class + any AuditEventType):
- `SaveRtsGridMetricCommand` + `SaveRtsGridMetricCommandHandler`
- `DeleteRtsGridMetricCommand` + `DeleteRtsGridMetricCommandHandler`
- `SaveMetricTranslationCommand` + `SaveMetricTranslationCommandHandler`
- `DeleteMetricTranslationCommand` + `DeleteMetricTranslationCommandHandler`
Do NOT touch non-metric commands in this file, and do NOT touch read queries (GetRtsGridMetricsQuery lives in
ConfigurationQueries.cs — leave it).

### 3. CommandValidators.cs — remove validators for the removed commands
Delete `SaveRtsGridMetricCommandValidator` (and any validator class for Delete/translation metric commands if present).
Leave all other validators intact.

### 4. ConfigurationDtos.cs — remove the now-orphan request DTOs
Delete `SaveRtsGridMetricRequest` and `SaveMetricTranslationRequest` (after step 2/3 they have no remaining source
references — verified at draft: only ConfigurationCommands.cs + MetricsPage.razor used them, both being cleaned).
Leave every other DTO in the file untouched.

### Security verification (mandatory — this is the point of the task)
- `grep -rnE "SaveRtsGridMetric|DeleteRtsGridMetric|SaveMetricTranslation|DeleteMetricTranslation" src --include=*.cs --include=*.razor | grep -vE "bin/|obj/"`
  => MUST return NOTHING (no command, no handler, no validator, no caller, no DTO).
- Confirm MetricsPage has no `Mediator.Send` of any metric-write command and no edit/delete/translation buttons.
- Confirm the apply-service / Deploy path (a6f5572) is the ONLY route that changes a metric, and it is unchanged.
- No NEW input field that feeds MetricFunction/Parameter/Format from the client remains anywhere.

### Build verify
- `dotnet build src/CcDashboard.Web -c Debug` -> 0 errors (a green build proves all references to the removed
  types are gone — the whole point of removing validators + DTOs in the same task).
- Re-read MetricsPage: page still renders (read-only list + Deploy tab), no dangling @code refs.

## Commit (fix:)  — security hardening
```bash
bash tools/pre-commit-check.sh   # exit 1 -> restore truncated, retry Python write, re-check
# acquire commit.lock (S3), then add ONLY the 4 claimed files actually changed:
GIT_INDEX_FILE=/tmp/cc-idx git add <the 4 claimed files>
# commit -m "fix: F-1 metrics read-only — remove client create/edit/delete/translate; vendor-deploy only [shell-0609]"
```
Then §0.6 post-commit verify (git status clean, diff HEAD empty, line counts match) -> S4 `bash tools/cc_post_commit.sh shell-0609 <hash>`
-> §0.6/PD-007 re-sync each committed file from HEAD (`git show HEAD:<f> > <f>`) -> `sync`.

## Report back
Files changed (4) ; the security-grep result (must be empty) ; build 0 errors ; confirm Deploy tab + read-only list
intact ; commit hash ; git status clean. NO push.
