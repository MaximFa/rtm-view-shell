# CC task — PR234-2 fix (shell): bump app.css?v — stale cache collapses the editor widget palette — AWAITING §4-BLESS
> BLOCKER (v3, live on 234): the dashboard editor's widget palette is stuck at ~1px width → can't add any widget (editor unusable). ROOT (coordinator live-confirmed): the browser serves a STALE cached `app.css?v=29` (last bumped 50f27a5, 06-25) that PREDATES the current `.editor-palette.open { width:300px }` rule — the `open` class IS on the element but the cached CSS lacks the rule, so width stays 0 (+1px border). The repo/server app.css is CORRECT (contains the rule). app.css was edited 6× since v=29 (table-chrome 510fb80 + 5 more) with NO ?v bump → §29.1 cache-bust was skipped. FIX = bump the version so browsers fetch current CSS. This also clears any other stale-CSS reports regressions.
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37). Report-scoped (one line).

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
## BINDING 2026-07-02T05:41:23Z | spec: shell | directive: tools/cc_prompt_shell_pr234_2_appcss_bump.md | status: open
### DIRECTIVE (spec->CC): PR234-2 bump App.razor app.css?v=29 -> ?v=30 (stale cache collapsed editor palette). v3, fix:, NO push, §4 + LIVE gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/App.razor — MODIFY (line 28 ONLY: `app.css?v=29` -> `app.css?v=30`)

## THE WORK (one line — Python+fsync, Edit BANNED)
1. App.razor :28 — change `<link rel="stylesheet" href="app.css?v=29" />` to `href="app.css?v=30"`. Nothing else.
2. Do NOT touch tokens.css?v=2 (unchanged) or any other line.

## VERIFY / DoD (role-shell §A — ⛔ LIVE gate, not object-store)
- **Object-store:** App.razor:28 = `app.css?v=30`; no other change; v3.
- **Soma (Profile A):** /ops/build 0 err + serilog [ERR]/[FTL] clean + /ops/health (CSS-only bump — build must stay green).
- **⛔ LIVE GATE (coordinator on 234, after rebuild + hard-refresh / new ?v):** open the dashboard editor → click the Widgets toggle → palette **expands to 300px** → widget types render + are draggable → **confirm DataSlot IS listed** (was clipped at 1px). If DataSlot still absent once open → DATA (widget_catalog), flag coordinator for dba/bi (`SELECT name,is_active FROM widget_catalog`) — NOT this fix. Do NOT report GREEN without the live 300px palette.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY App.razor (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): PR234-2 bump app.css?v=30 — stale cache collapsed editor widget palette [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B: "Editor widget palette collapsed to ~1px on 234 = STALE app.css cache: `.editor-palette.open{width:300px}` present in repo/served CSS but the browser ran cached `app.css?v=29` (not bumped despite 6 app.css edits) → `open` class applied but rule missing → width:0. ALWAYS bump App.razor `app.css?v=N` when app.css changes (§29.1); a skipped bump silently ships old CSS. Consider a durable content-hash cache-bust to end manual bumps." SOURCE:App.razor:28 + coordinator live 2026-07-02. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err> . files App.razor (app.css?v 29->30) . status done|failed . blockers . verified: object-store (LIVE 300px palette + DataSlot-listed = coordinator gate, pending)
```
