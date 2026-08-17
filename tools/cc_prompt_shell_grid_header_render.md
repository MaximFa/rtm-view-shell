# CC task — GRID HEADER rendering (shell): As-Is text + wrap + top-align (AgentGrid + QueueGrid + DataSlot) — AWAITING §4-REVIEW (coordinator)
> Operator UI task (all grid widget headers): (1) stop force-UPPERCASE → show header text As-Is ("Abandoned Calls", not "ABANDONED CALLS"); (2) allow wrapping — natural word-wrap AND an explicit line break in the name if present; (3) on resize, a header that would overflow into a HORIZONTAL SCROLL must WRAP to two lines instead (no nowrap); (4) vertical-align = TOP — a 1-line header (and its filter icon) aligns to the TOP when a sibling header wraps to 2 lines and grows the row.
> SCOPE (object-store-enumerated): exactly THREE widgets have UPPERCASE headers → AgentGrid, QueueGrid, DataSlot. Other widgets are charts (DayTrend, AgentStateDistribution) or have no th headers (grep: no other `text-transform: uppercase`). CAUTION: only HEADER cells get As-Is+wrap+top-align — do NOT regress DATA cells (`table td` vertical-align:middle) or badges (`.threshold-badge`/`.badge-status` white-space:nowrap — those STAY).
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix(web):`. **NO push** (§37). Narrow claim (widget .razor/.razor.css only).

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + BRANCH NORM (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3; verify HEAD == v3 tip
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- ALL commits to **v3** only. §0.3 Python+fsync; Edit BANNED.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING 2026-07-14T05:55:37Z | spec: shell | directive: tools/cc_prompt_shell_grid_header_render.md | status: open
### DIRECTIVE (spec->CC): grid header rendering — As-Is (drop uppercase) + wrap (drop nowrap, honor \n) + top-align (th + filter icon) for AgentGrid/QueueGrid/DataSlot headers; data cells untouched. v3, fix(web):, NO push, §4-reviewed. Report build=0.
```

## §42.6 CLAIM (file-mode, web — widget files only)
- src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor.css
- src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
- src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css
- src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor
- src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor.css

## GROUNDING (object-store @ v3)
- HEADER uppercase (REMOVE): AgentGridWidget.razor.css:30 (`.agent-grid-body table th`), QueueGridWidget.razor.css:8 (`.queue-grid-body table th`), DataSlotWidget.razor.css:34 (`.data-slot-title`).
- HEADER single-line nowrap (CHANGE): inline via `GetTheadCellStyle()` returning `"white-space: nowrap; color:...; font-size:...;"` — AgentGridWidget.razor:1314, QueueGridWidget.razor:1162. Applied to `<th class="text-start position-relative" style="@GetTheadCellStyle()">` (Agent:74; Queue:76 queue-name col + :103 metric cols).
- th inner content: a sort `<span>@colDef.Name</span>` (+ optional caret) then a filter `<button>` (funnel, `ms-1`) — both inline in the th (Agent:74-95).
- DO NOT TOUCH (data): `table td { vertical-align: middle }` (Agent:36 / Queue:14); `.threshold-badge`/`.badge-status` `white-space:nowrap` (Agent.css:46,:105; Queue.css) — these are DATA badges, keep nowrap.

## THE WORK
### 1. As-Is (remove uppercase) — 3 CSS files
- AgentGridWidget.razor.css:30 — delete `text-transform: uppercase;` from `.agent-grid-body table th`.
- QueueGridWidget.razor.css:8 — delete `text-transform: uppercase;` from `.queue-grid-body table th`.
- DataSlotWidget.razor.css:34 — delete `text-transform: uppercase;` from `.data-slot-title`.
(Leave letter-spacing/font-weight as-is — only capitalization changes.)
### 2. Wrap (honor \n + natural wrap, no horizontal scroll) — the two GetTheadCellStyle()
- AgentGridWidget.razor:1314 & QueueGridWidget.razor:1162 — change the returned style from `white-space: nowrap; ...` to:
  `white-space: pre-line; overflow-wrap: anywhere; vertical-align: top; color: {color}; font-size: {fs};`
  · `pre-line` = wraps naturally AND honors an explicit `\n` in the stored name (req 2+3).
  · `overflow-wrap: anywhere` = a long single token still breaks instead of forcing horizontal scroll.
  · `vertical-align: top` (inline on th) covers req 4 for the cell.
### 3. Top-align the filter icon (req 4) — funnel aligns to the TOP, not vertically centered with a 2-line sibling
- Add `vertical-align: top;` to the filter button's inline style — `GetFilterButtonStyle(...)` (Agent:1318, Queue:~1166) append `vertical-align: top;` to the returned string; (and the sort `<span>` is inline so it top-aligns with the cell). If the funnel does not visually top-align inline, instead give the th a flex layout — `display: flex; align-items: flex-start; gap: .25rem;` on the header `th` in the .razor.css (`.agent-grid-body table th` / `.queue-grid-body table th`) — CHOOSE whichever gives a clean top-aligned text+funnel on the LIVE gate (flex is more robust for the text-wraps-to-2-lines + icon-stays-top case). If you use flex on th, keep the sort-span able to wrap (it will).
### 4. Guards
- Data cells + badges UNCHANGED. RTL: use only logical/neutral props (th already `text-start`; vertical-align/white-space are axis-neutral) — no physical left/right. i18n: `@colDef.Name` is the stored name, rendered As-Is — no hard-coded strings. DataSlot has no filter icon/th — just the As-Is title (wrap is natural).

## VERIFY / DoD (role-shell §A — ⛔ LIVE visual gate)
- **Object-store:** the 3 uppercase rules removed; both GetTheadCellStyle() return pre-line+overflow-wrap+vertical-align:top (no nowrap); filter button/th top-aligned; data td/badges untouched; no physical L/R props; no hard-coded strings.
- **Soma (Profile A):** /ops/build = **0 errors** (self-build §47) (+ /ops/test?suite=unit failed=0 for the standing rule — CSS/markup only, expect unchanged pass count).
- **⛔ LIVE VISUAL (coordinator on 140 after Shell rebuild):** grid headers show As-Is text (e.g. "Abandoned Calls"); a long header wraps to two lines on a narrow widget (NO horizontal scroll); a 1-line header AND its filter funnel align to the TOP when a sibling header is 2 lines; data cells/numbers/badges unchanged; RTL intact. Do NOT report GREEN without the visual.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY the claimed widget files (+ role-shell.md via `git add -f` if CAPTURE). Commit `fix(web): grid headers — As-Is text + wrap (honor \n, no h-scroll) + top-align (AgentGrid/QueueGrid/DataSlot) [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.
- BATCH NOTE: lands on v3 with Defect K for the NEXT single Shell rebuild+redeploy (coordinator-controlled).

## §0.6b CAPTURE -> role-shell §B: "Grid widget headers force-uppercased (CSS text-transform) + single-lined (inline GetTheadCellStyle white-space:nowrap) → ALL-CAPS + horizontal scroll on resize. FIX: drop uppercase (As-Is); header white-space nowrap→pre-line + overflow-wrap:anywhere (natural wrap + honor \n, no h-scroll); vertical-align:top on th + filter button (top-align when a sibling wraps to 2 lines). Only HEADER th — data td (vertical-align:middle) + badges (nowrap) stay. Enumerate by object-store: exactly the widgets with `text-transform:uppercase` headers." SOURCE:AgentGridWidget/QueueGridWidget/DataSlotWidget .razor(.css) + operator 2026-07-14. Binding RESULT -> cc/shell.md.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed n> . files AgentGridWidget.razor(.css) + QueueGridWidget.razor(.css) + DataSlotWidget.razor.css . status done|failed . blockers . verified: object-store (LIVE header As-Is+wrap+top-align = coordinator 140 visual, pending)
```
