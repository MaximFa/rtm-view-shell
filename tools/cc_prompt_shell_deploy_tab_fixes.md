# CC Task (Shell specialist, slug shell-0609) — Deploy-tab iter-1 fixes: button overflow + i18n status strings + clearer fallback

> DRAFT for coordinator §4 (coordinator-0612). Folds three iter-1 defects on the 234 'Deploy New Metrics' tab
> (coordinator-0609 directives 2026-06-11 12:55 + 13:20). Defects CONFIRMED still present in MetricsPage.razor at draft.
> Pure Shell/UI: MetricsPage.razor + app.css + 3 resx. Do NOT touch the metric data model or the deployed/undeployed
> (190-undeployed) ledger-vs-RTSGrid_Metric logic — that is metrics-3's call; here we only REWORD the message.

## Git push — DO NOT (§37). Commit only.

---

## Step 0 — §0.6a MANDATORY INTEGRITY CHECK (first, no exceptions)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"; else echo "OK: $f ($WT_LINES)"; fi
done
sync; echo "=== integrity check complete ==="
```
NOTE: verify changed files by EXPLICIT hash (`git hash-object` vs `git rev-parse <HEADHASH>:<f>`) — incl. BYTE-LEVEL
drift at IDENTICAL line counts (observed repeatedly on this mount). Don't trust mount git status / line-count alone.

## Step 0b — §40 mandatory skill reads
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/ux-ui-expert/...            (WHAT: keep the Deploy action reachable; non-alarming status copy)
Read: .claude/skills/frontend-design/...          (HOW: tokens; existing MetricsPage table patterns)
Read: .claude/skills/blazor-frontend-design/...   (HOW: Bootstrap table-responsive, RTL logical props, IStringLocalizer)
```

## Multi-session sync (§42.6) — slug shell-0609
> Apply the machinery from `tools/cc_prompt_sync_block.md` (READ it first): phantom-aware `/tmp/acquire_lock.py` + S1/S3/S4.

CLAIMS (all Shell-owned; coord_check_claims shell-0609 = exit 0 expected — verify; if any held, STOP+coordinate):
  - src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor
  - src/CcDashboard.Web/wwwroot/app.css
  - src/CcDashboard.Web/Resources/SharedResources.en-US.resx
  - src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
  - src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
- **S1 push-barrier:** `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> if match STOP & report.
- **S2 claims:** `python3 tools/coord_check_claims.py shell-0609 <each path>` -> exit 1 = STOP. Touch ONLY these (+ /tmp scratch).
- **S3 commit.lock** around git add/commit (acquire_lock per sync_block, owner shell-0609; 15-min stale=report+wait). Covers §0.4 plumbing path.
- **S4 post-commit:** `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then `sync`.
- **S5:** no git push.

## §0.3 — Edit tool BANNED. ALL writes via Python read->modify->write + os.fsync, then `sync && tail -3 && wc -l` (per file).

---

## THE WORK — 3 folded fixes

### FIX 1 — Deploy button off-screen at 1280-wide (table overflow)
On the Deploy tab, the undeployed-metrics table (`<table class="table table-sm table-hover align-middle">` ~L164,
inside `.table-responsive` ~L163) pushes the green Deploy action column off the right edge at 1280px. The MAIN
metrics table (~L72) already uses `style="table-layout:fixed; width:100%;"` and does not overflow — the deploy
tables lack it. FIX so the action column stays visible/reachable at 1280-wide:
- Give the deploy-tab tables a constrained layout (e.g. a class `metrics-deploy-table` with `table-layout:fixed;
  width:100%;` + sensible column widths; let the long text columns (DisplayName/Description) truncate with
  ellipsis, and pin the action column a fixed width so the Deploy button always renders).
- Keep `.table-responsive` so a narrow viewport gets horizontal scroll rather than a clipped button.
- New CSS goes in app.css under a deploy-tab class; dark-mode + RTL parity (logical props, no left/right hardcode).
- Apply the same to the "Deployed" table (~L206) for consistency.
- Bump `app.css?v=` ONLY if App.razor is added to claims — App.razor is NOT in this task's claims; if a bump is
  needed, FLAG to coordinator rather than editing App.razor unclaimed (a new class usually needs a bump to bust
  cache — raise it; coordinator will add App.razor to the claim or confirm not needed).

### FIX 2 — Reword the cryptic fallback message (+ move to resx, FIX 3)
`DeployError = "Metrics catalog not found. Using database metrics as fallback."` (~L350) is alarming + cryptic.
Reword to explain plainly and non-alarmingly, e.g. (final EN wording your call, keep it calm + informative):
"The metrics catalog file isn't deployed on this server yet — showing metrics from the database instead."
This is informational, not an error — consider rendering it as an info/warning note rather than a red error if the
page distinguishes; minimally, reword. (Do NOT change the fallback LOGIC — metrics-3 owns the 190-undeployed root
cause.) The string itself moves to resx per FIX 3.

### FIX 3 — i18n: move ALL hardcoded runtime status strings to resx (I18N-03)
These are hardcoded English in MetricsPage.razor — move EACH to a resx key via `@L[...]` / injected IStringLocalizer
(use parameterised keys for the ones with values), and add the key to ALL THREE resx (en-US, ru-RU, he-IL):
- ~L350 "Metrics catalog not found. Using database metrics as fallback."  (use the FIX-2 reworded text)
- ~L359 "Deploy ledger not available. Showing all catalog metrics as undeployed."
- ~L369 "Failed to load deploy data: {message}"            (param)
- ~L390 "Deploy requires Superadmin role."
- ~L404 "Deployed: {name}"                                 (param)
- ~L408 "Deploy error: {message}"                          (param)
- ~L425 "Recompile sent: {name}"                           (param)
- ~L428 "Recompile error: {message}"                       (param)
Naming: follow the existing `Metrics_*` convention (e.g. `Metrics_Status_CatalogMissing`, `Metrics_Status_DeployedFmt`).
For params use the project's localizer-with-args pattern (IStringLocalizer indexer with arguments / string.Format on
the localized template) — match how other parameterised strings are done in the codebase.
ALSO (13:20 ask): verify ALL @L["Metrics_*"] keys USED in MetricsPage.razor (~23) RESOLVE in all 3 resx — add any
missing key to all three. Provide ru-RU and he-IL translations (not English placeholders) for every new/missing key;
EN starts capitalised (29.1 resource convention). RTL (he) — text only, no layout change here.

### Verify (mandatory)
- `dotnet build src/CcDashboard.Web -c Debug` -> 0 errors. (Whole-sln not required — no public-type removal here.)
- `grep -nE '= \"[A-Z][a-z].*\"' MetricsPage.razor` around the deploy handlers -> NO hardcoded user-facing status
  strings remain (all via @L / localizer). Logger messages may stay English (not user-facing).
- Confirm every @L key used in MetricsPage resolves in en-US AND ru-RU AND he-IL (list any you added).
- Confirm at 1280-wide the Deploy button is visible/reachable (describe the layout fix; screenshot if a runner is up).
- Light + dark mode + RTL: deploy tables render, action column visible, no clipped button.

## Commit (fix:)
```bash
bash tools/pre-commit-check.sh
# acquire commit.lock (S3), then add ONLY the claimed files changed:
GIT_INDEX_FILE=/tmp/cc-idx git add <changed claimed files>
# commit -m "fix: deploy-tab iter-1 — action-column overflow @1280 + i18n status strings (en/ru/he) + clearer catalog-fallback msg [shell-0609]"
```
Then §0.6 post-commit verify -> S4 cc_post_commit.sh -> PD-007 re-sync each committed file from HEAD (hash-verify, NOT line-count) -> `sync`.

## Report back
files changed ; build 0 errors ; the no-hardcoded-status grep result ; list of resx keys added (en/ru/he) + confirmation
all @L keys resolve in 3 locales ; 1280-wide Deploy-button-visible confirmation ; whether an app.css?v bump was needed
(and that it was FLAGGED not done) ; commit hash ; git status clean. NO push.
