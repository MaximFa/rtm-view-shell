# CC task — PR234-1b fix (shell): restore Thresholds tab for DataSlot — AWAITING §4-BLESS
> Prod regression (deployed b58e2c2, live in v3): the DataSlot widget lost its **Thresholds** tab in the dashboard config modal. ROOT (diagnosed): the Thresholds tab BUTTON is gated `@if (IsQueueGridWidget(ConfiguringWidget) || IsAgentGridWidget(ConfiguringWidget))` (ScreenEditorPage.razor:275) → DataSlot is excluded; the flat-threshold CONTENT branch still exists (ConfigThresholds, ~:1378) but is unreachable. Introduced by 924e444 (hid Thresholds for ASD, collaterally dropped DataSlot).
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37). Report-scoped, parity-guard.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + BRANCH NORM (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3 — if not, `git checkout v3`; verify HEAD is the v3 tip before any work
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- ⚠ ALL commits to **v3** only (v2-backend consolidated in — never commit to old branches). pre-existing `D Installations/*` = not ours. §0.3 Python+fsync; Edit BANNED.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING <UTC> | spec: shell | directive: tools/cc_prompt_shell_pr234_1b_dataslot_thresholds.md | status: open
### DIRECTIVE (spec->CC): PR234-1b add DataSlot to Thresholds tab gate (ScreenEditorPage:275) + confirm content branch. v3, fix:, NO push, §4 + QA gate.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor — MODIFY (:275 tab gate; verify :1378 content branch)
- (.claude/skills/role-shell/role-shell.md via `git add -f` if CAPTURE)

## THE WORK
1. ScreenEditorPage.razor :275 — change the Thresholds tab-button gate from:
   `@if (IsQueueGridWidget(ConfiguringWidget) || IsAgentGridWidget(ConfiguringWidget))`
   to include DataSlot:
   `@if (IsQueueGridWidget(ConfiguringWidget) || IsAgentGridWidget(ConfiguringWidget) || IsDataSlotWidget(ConfiguringWidget))`
   (keep ASD excluded — 924e444's intent to hide it for ASD stays; only DataSlot is restored.)
2. Confirm the Thresholds tab CONTENT for DataSlot renders: the content region (`@if (ConfigActiveTab == "thresholds")`, ~:1226) has a per-column branch (grids, ~:1254 GetColumnThresholds) and a flat-list branch (ConfigThresholds, ~:1378). Verify DataSlot hits the correct branch (flat ConfigThresholds, like it did pre-924e444). If DataSlot needs the flat-list branch and the current content-branch condition excludes it, adjust the CONTENT condition too (report-scoped) so DataSlot shows its threshold editor — mirror how DataSlot thresholds worked in the last stable build (4648b81/9b4a7d3).
3. No other change. Do NOT alter Queue/Agent/ASD threshold behaviour.

## VERIFY / DoD (role-shell §A — ⛔ LIVE gate, not object-store)
- **Object-store:** :275 gate now includes IsDataSlotWidget; ASD still excluded; the DataSlot threshold content branch reachable; no Queue/Agent/ASD change.
- **Soma (Profile A):** /ops/build 0 + /ops/test?suite=unit 0 failed + serilog [ERR]/[FTL] clean + /ops/health.
- **⛔ LIVE GATE (operator/coordinator on 234):** open a DataSlot widget config → the **Thresholds** tab is present → its editor renders and lets you add/edit a threshold rule; Queue/Agent still have Thresholds; ASD still does NOT. Do NOT report without live confirmation.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY ScreenEditorPage.razor (+ role-skill if CAPTURE). Commit `fix(web): PR234-1b restore Thresholds tab for DataSlot (add IsDataSlotWidget to tab gate) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b CAPTURE -> role-shell §B (if confirmed): "924e444 narrowed the Thresholds tab gate to Queue/Agent to hide it for ASD, collaterally dropping DataSlot. A tab-visibility gate must enumerate ALL types that need the tab; excluding-by-omission is fragile — prefer explicit include-list per tab." SOURCE:<commit>. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0/unit n/0> . files ScreenEditorPage.razor . status done|failed . blockers . verified: object-store (LIVE DataSlot Thresholds = operator gate, pending)
```
