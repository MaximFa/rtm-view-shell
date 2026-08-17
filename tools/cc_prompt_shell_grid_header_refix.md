# CC task — GRID HEADER re-fix (shell): text-transform:none (beat global .table thead th) + stop mid-word break — §4 (part of the 4-edit batch)
> Follow-up to 0f270bd (2 operator remarks, coordinator-diagnosed on 140):
> REMARK 1 — headers STILL uppercase. ROOT: NOT the widget scoped CSS (now clean) — a GLOBAL rule `.table thead th { text-transform: uppercase }` in `wwwroot/app.css` matches the widget grid `<th>` and overrides. FIX (WIDGETS ONLY — operator-confirmed): force `text-transform: none` at higher specificity via the INLINE GetTheadCellStyle(). Do NOT touch the global app.css `.table thead th` (admin-list tables KEEP uppercase).
> REMARK 2 — wrapping breaks letters mid-word. ROOT: `overflow-wrap: anywhere`. FIX: change to `overflow-wrap: normal` (keep `white-space: pre-line` → wraps at word/\n only; column min-content = longest word).
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `fix(web):`. **NO push**. Narrow claim.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/session-coord/session-coord.md

## INIT — §0.6a integrity + BRANCH NORM
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null); [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }; done; sync
```

## §0.6b BINDING PREAMBLE — .coord/cc/shell.md
```
## BINDING 2026-07-14T08:43:35Z | spec: shell | directive: tools/cc_prompt_shell_grid_header_refix.md | status: open
### DIRECTIVE (spec->CC): header re-fix — GetTheadCellStyle += text-transform:none (beat global .table thead th) + overflow-wrap anywhere->normal (AgentGrid/QueueGrid + DataSlot header). v3, fix(web):, NO push. build0/unit0.
```

## §42.6 CLAIM (file-mode, web)
- src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor  (GetTheadCellStyle :1314)
- src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor  (GetTheadCellStyle :1162)
- src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor(.css) — the DataSlot header/title (`.data-slot-title`, css:32) — add `text-transform:none` where its header renders; DataSlot has no th/GetTheadCellStyle, its title is CSS `.data-slot-title` (already un-uppercased in 0f270bd) BUT verify no global rule re-uppercases it; if a global rule hits it, add `text-transform:none !important` to `.data-slot-title` (scoped) — verify on object-store, only if needed.

## THE WORK
1. AgentGridWidget.razor:1314 & QueueGridWidget.razor:1162 — GetTheadCellStyle() currently:
   `$"white-space: pre-line; overflow-wrap: anywhere; vertical-align: top; color: {color}; font-size: {fs};"`
   change to:
   `$"white-space: pre-line; overflow-wrap: normal; vertical-align: top; text-transform: none; color: {color}; font-size: {fs};"`
   (inline `text-transform:none` beats the global `.table thead th` uppercase; `overflow-wrap:normal` stops mid-word breaks; keep pre-line + vertical-align:top.)
2. DataSlot: `.data-slot-title` scoped rule already has NO uppercase (0f270bd). VERIFY on 140/object-store whether a global rule re-uppercases the DataSlot title; if yes, add `text-transform: none;` to `.data-slot-title` in DataSlotWidget.razor.css. If the title is already As-Is, leave DataSlot untouched (note it in RESULT).
3. Nothing else — do NOT edit app.css `.table thead th` (admin lists keep uppercase per operator).

## VERIFY / DoD
- Object-store: both GetTheadCellStyle carry `text-transform: none` + `overflow-wrap: normal` (no `anywhere`), keep pre-line+vertical-align:top; app.css `.table thead th` UNCHANGED.
- Soma: /ops/build 0 + /ops/test?suite=unit failed 0.
- ⛔ LIVE (coord 140 post-rebuild): widget headers As-Is (not caps); words never break mid-letter; column shrinks only to the longest word; top-align intact; admin-list tables STILL uppercase (unchanged).

## COMMIT
- pre-commit-check → commit.lock → stage claimed files → `fix(web): grid headers — text-transform:none (beat global .table thead th) + overflow-wrap normal (no mid-word break) [shell-0609]` → cc_post_commit → §0.6 → NO push → §0.7 re-sync. BATCH: lands on v3 with the other 3 edits before ONE Shell rebuild.

## §0.6b BINDING POSTAMBLE
```
### RESULT (CC->spec): commits <hash> . build <0/W n> . unit <failed 0/passed n> . files AgentGrid/QueueGrid.razor (+DataSlot if needed) . status . verified: object-store (LIVE = coord 140)
```
