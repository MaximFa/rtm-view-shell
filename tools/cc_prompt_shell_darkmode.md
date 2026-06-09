# CC Task (Shell specialist, slug shell-0609) — Configurator Dark-Mode Parity

> First task of the standing **Shell + UI/UX** specialist session.
> Fix 9 operator-harvested dark-mode gaps in the widget Configure modal.
> Spec (read it): `tools/darkmode_config_gaps_0609.md`.

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
If any file RESTORED -> do not proceed until git status --short is clean of real truncation.

## Step 0b — §40 mandatory skill reads (before any work)
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
```
Then read the Shell specialist skills for THIS task:
```
Read: .claude/skills/ux-ui-expert/...            (WHAT: visual/contrast/UX intent)
Read: .claude/skills/frontend-design/...          (HOW: design tokens, dark theme)
Read: .claude/skills/blazor-frontend-design/...   (HOW: Blazor/Bootstrap specifics, RTL)
Read: .claude/skills/blazor-server-expert/...     (render-mode/circuit correctness)
Read: .claude/skills/app-cyber-security-expert/...(no token/PII in client, XSS/MarkupString CODE-02, §41)
```

## Multi-session sync (§42.6) — slug shell-0609
> Apply the machinery from `tools/cc_prompt_sync_block.md` (READ it first): it defines the
> phantom-aware `/tmp/acquire_lock.py` + the S1/S3/S4 steps. This section only fills slug+claims.
Claims for this task (EXCLUSIVE, received via operator handover from metrics-2-0607 + test-5-0607):
  - src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
  - src/CcDashboard.Web/wwwroot/app.css
  - src/CcDashboard.Web/Components/App.razor   (css cache-bump only)
- **S1 push-barrier:** `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> if match STOP & report.
- **S2 claims:** `python3 tools/coord_check_claims.py shell-0609 src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor src/CcDashboard.Web/wwwroot/app.css src/CcDashboard.Web/Components/App.razor` -> exit 1 = STOP. Touch ONLY these 3 files (+ /tmp scratch).
- **S3 commit.lock** around every git add/commit. Create + use `/tmp/acquire_lock.py` EXACTLY as defined in `tools/cc_prompt_sync_block.md` (phantom-aware, retry 5×60s, owner `shell-0609`); FAILED after 5 = abort+report; 15-min stale = report+wait, never auto-delete. Covers the §0.4 plumbing path too.
- **S4 post-commit:** `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then `sync`.
- **S5:** no git push.

## §0.3 — Edit tool BANNED. All writes via Python read->modify->write + os.fsync, then `sync && tail -3 && wc -l`. Same for the .razor.

---

## The work — 9 gaps (full table in tools/darkmode_config_gaps_0609.md)

All gaps are in ONE file: `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`
(every widget Configure modal renders there, ~lines 246-2108). Dark CSS prefix:
`.editor-fullscreen.dark-mode .editor-modal ...` in `wwwroot/app.css` (existing block ~2850-2913).
Toggle: `.dark-mode` class on `.editor-fullscreen` / `.editor-modal`.

1. Agent Grid · active nav-tab white -> `.nav-tabs .nav-link.active` dark bg + light text.
2. Agent Grid · Columns · table header row ("NAME/METRIC") white -> thead/`.bg-light`/header class.
3. Agent Grid · Score · rule-row CARD borders white + "Preview" card white bg -> container border + preview bg.
4. Queue Grid · Rows · row-card borders white.
5. Queue Grid · Columns · col-card borders white.
6. ASD · Status Group / Agent State segment LABELS invisible -> label text -> light (#E4E4E7).
7. Data Slot · Appearance · toggle SWITCHES white -> `.form-check-input` (switch) dark track/knob.
   NOTE: switches are `:not([type=checkbox])`-EXCLUDED by the generic input rule on purpose — add an
   explicit dark rule for the switch (track off/on + knob), do NOT remove the exclusion.
8. Day Trend · Call Metrics · metric-row card/border white.
9. Day Trend · Agent Metrics · metric-row card/border white (same fix as #8).

### Rules
- Plain input/select/textarea borders are ALREADY dark (app.css ~2869-2901). The white "обводы" the
  operator sees are CONTAINER/CARD borders (rule-row / row-card / metric-row / preview) — find those
  container classes in ScreenEditorPage.razor and theme them under the dark prefix.
- Reuse existing tokens ONLY: bg #1E1E1E, field #2D2D2D, text #E4E4E7, borders rgba(255,255,255,0.08/0.15),
  focus var(--clr-primary). No new hardcoded palette.
- Keep light mode unchanged (scope every new rule under `.editor-fullscreen.dark-mode .editor-modal`
  or `.editor-modal.dark-mode`).
- Bump cache version in App.razor: `app.css?v=15` -> `app.css?v=16`.

### Verify (mandatory, before commit)
- `dotnet build src/CcDashboard.Web -c Debug` -> 0 errors.
- Re-read each changed CSS rule; confirm all 9 gaps have a corresponding selector and none leak into
  light mode. List, per gap #, the exact selector you added/changed.
- Confirm App.razor shows v=16.

## Commit (web:)
```bash
bash tools/pre-commit-check.sh   # exit 1 -> restore truncated, retry Python write, re-check
# acquire commit.lock (S3), then:
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor src/CcDashboard.Web/wwwroot/app.css src/CcDashboard.Web/Components/App.razor
# commit-tree path (HEAD.lock-safe, §0.4) OR normal commit -m "web: dark-mode parity for configurator modal (9 gaps) [shell-0609]"
```
Then §0.6 post-commit verify (git status clean, diff HEAD empty, line counts match) ->
S4 `bash tools/cc_post_commit.sh shell-0609 <hash>` -> §0.6/PD-007 re-sync the 3 files from HEAD -> `sync`.

## Report back
Per-gap selector list (1..9) ; build result ; commit hash ; v=16 confirmation ; git status --short clean. NO push.
