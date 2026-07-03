# CC task — PR234-1a PROBE (shell): capture the live ConfigJson round-trip to pin the config-loss — AWAITING §4-BLESS
> Prod regression (in b58e2c2 + v3): widget config saves null/empty into dashboard_widgets. Static analysis established: persist handlers faithful (not backend); DTO order correct (no swap); PlacedWidget.Config non-null; **WidgetConfig schema is IDENTICAL between b58e2c2 and v3 (109 props, no change) → the "schema break" hypothesis is DISPROVEN**; and since b58e2c2 already ships the bug the introducing commit predates it. The remaining suspect is a RUNTIME path — `ParseWidgetConfig` (:5247-5255) silently `catch{ return new WidgetConfig(); }` (empty) on a deserialize THROW (a data value, not schema) OR the save flow building an empty newConfig. This PROBE captures the live truth; it is INSTRUMENTATION ONLY (temp logging), NOT the fix.
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `chore:` (temp probe). **NO push** (§37). Report-scoped.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + BRANCH NORM (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3 (checkout v3 if not); verify HEAD == v3 tip
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- ALL commits to **v3** only. §0.3 Python+fsync; Edit BANNED. `D Installations/*` = not ours.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_pr234_1a_probe.md | status: open
### DIRECTIVE (spec->CC): PR234-1a PROBE — temp-log ConfigJson in/out + swallowed exception; reproduce live; report exact cause. v3, chore:, NO push, §4.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — MODIFY (TEMP logging only in ParseWidgetConfig + SaveWidgetConfig + SaveLayout)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## THE WORK (temporary instrumentation — clearly marked `// PROBE PR234-1a`)
1. `ParseWidgetConfig` (:5247): inject an `ILogger` (the component likely already has one — else use `Logger`); in the `?? new WidgetConfig()` null branch AND the `catch` branch, log at Warning: the widget context + the RAW `configJson` (first ~500 chars) + `ex.GetType().Name + ex.Message` (catch). This reveals whether deserialize THROWS (and on what value) or returns null, and the exact stored ConfigJson that fails.
2. `SaveWidgetConfig` (:~4602-4620): before Send, log the widgetId + `System.Text.Json.JsonSerializer.Serialize(newConfig, _jsonOptions)` (first ~500 chars) — confirms whether the OUTGOING config is full or empty at modal-save.
3. `SaveLayout` (:~4972-4979): log, per widget, widgetId + whether `w.Config` is a populated or default/empty instance + the serialized ConfigJson (first ~500 chars) — confirms whether the toolbar-Save serializes real vs empty config.
4. Keep all logging behind `// PROBE PR234-1a` comments so it's trivially removable. No behavioural change.

## RUN + CAPTURE (this is the deliverable)
- Build + bring up the app (Profile A). On Test66/Prod Mirror reproduce the config-loss: configure a widget (esp. DataSlot / a widget that showed the null), Save, reload, observe values lost.
- Capture the Shell log (Soma `/logs/tail?source=serilog`): the ParseWidgetConfig warning(s) — deserialize throw? on which field/value? which raw ConfigJson? — and the SaveWidgetConfig/SaveLayout outgoing JSON (full vs empty).
- REPORT to inbox/coordinator.md + cc/shell.md: (a) exact cause — deserialize-throw (name the value/field) OR empty-newConfig-build OR a genuinely NULL DB row; (b) if a DB row is literally NULL → flag as data/backend; (c) the fix approach (make ParseWidgetConfig NOT silently overwrite: preserve raw ConfigJson on parse-failure / surface the error / migrate) + candidate introducing commit (bisect BEFORE b58e2c2 on the relevant path).

## VERIFY / DoD (role-shell §A)
- **Object-store:** temp `// PROBE PR234-1a` logging added in the 3 spots; no behavioural change; v3.
- **Soma (Profile A):** /ops/build 0 + /shell up + serilog readable. The probe's VALUE = the captured log lines + the reported exact cause (this is a diagnostic, not a user-facing gate).
- After findings reported + the 1a fix decided: a follow-up prompt removes the probe logging (or the fix supersedes it). Do NOT leave probe logging in the shipped bundle.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY ScreenEditorPage.razor. Commit `chore(web): PR234-1a temp probe logging (ConfigJson round-trip) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0/unit n/0> . PROBE FINDINGS: cause=<deserialize-throw:field | empty-newConfig | db-null> . raw ConfigJson sample . fix approach . introducing-commit candidate . status done|failed . verified: live-log
```
