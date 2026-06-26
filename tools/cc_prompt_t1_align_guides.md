# CC task — T1: widget alignment guide lines during move (Shell, F-A)
> §4-PASS by coordinator-0612 2026-06-15T07:10Z (widget-plan T1, Shell-only, B-package). Owner: shell-0609. Executor: native CC.
> Claims: src/CcDashboard.Web/wwwroot/js/widget-resize.js + src/CcDashboard.Web/wwwroot/app.css + src/CcDashboard.Web/Components/App.razor (app.css?v bump, ratified).
> Commit prefix `feat:`. **NO push** (§37). Pure client-side (JS+CSS), no Blazor/DB/model change, no security surface.

## Step 0 — §0.6a integrity (first)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  H=$(git show HEAD:"$f" 2>/dev/null | wc -l); W=$(wc -l < "$f" 2>/dev/null)
  if [ "$((H-W))" -gt 0 ]; then echo "TRUNC $f"; git show HEAD:"$f" > "$f"; fi
done
sync
git rev-parse --abbrev-ref HEAD   # v2-backend
```
Verify claimed files by HASH (git hash-object vs git rev-parse HEAD:<f>) — byte-drift at equal line counts happens on this mount.

## Step 0b — §40 skill reads
Read: .claude/skills/widget-planner/widget-planner.md ; widget-creator ; session-coord ; (ux-ui-expert WHAT / frontend-design HOW / blazor-frontend-design).

## §42.6 sync — slug shell-0609 (apply tools/cc_prompt_sync_block.md machinery)
- S1: `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> if match STOP.
- S2: `python3 tools/coord_check_claims.py shell-0609 src/CcDashboard.Web/wwwroot/js/widget-resize.js src/CcDashboard.Web/wwwroot/app.css src/CcDashboard.Web/Components/App.razor` -> exit1=STOP. Touch ONLY these (+ /tmp).
- S3: commit.lock (acquire_lock owner shell-0609) around git add/commit.
- S4: `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then sync.
- S5: NO push.
## §0.3 — Edit BANNED. Python read->modify->write + os.fsync; then sync && tail -3 && wc -l per file.

## Binding PREAMBLE -> .coord/cc/shell.md (Python+fsync):
## 2026-06-15T07:10Z | binding: shell <-> CC | directive: tools/cc_prompt_t1_align_guides.md | status: open
### DIRECTIVE: F-A alignment guides during move (widget-resize.js + app.css + App.razor bump). feat:. NO push.

## THE WORK — F-A alignment guides (grounded in widget-resize.js move loop)
In `wwwroot/js/widget-resize.js`, in the MOVE path (`onMouseMove`, mode==='move'), after computing the dragged widget's new left/top:
1. At drag START (startMove), CACHE the rects of all OTHER widgets on the canvas (`canvas.querySelectorAll('.widget')` minus dragged) — their left/centreX/right/top/centreY/bottom — plus canvas centre/edges. (They don't move mid-drag; cache once to avoid layout thrash, keep O(n).)
2. Each mousemove: compute dragged widget's left/centreX/right/top/centreY/bottom at the candidate position. For each axis, if |dragged − target| <= THRESHOLD (~6px), record a match (nearest wins per axis).
3. Render guides: ONE reusable vertical line div + ONE horizontal line div, created once, appended to the canvas; show/position on match, hide when no match. Full canvas height/width, 1px, accent colour, `pointer-events:none`, high z-index. Class `.widget-align-guide` + `.vertical`/`.horizontal` in app.css (dark-mode + RTL-safe via logical props / direction-agnostic absolute px).
4. OPTIONAL snap (default ON): when matched within threshold, set dragged left/top to the matched value (clicks into alignment). Snapped coords flow through the existing `OnWidgetMoved` commit — NO new persistence path.
5. On `onMouseUp`/drag end (and Escape-cancel if present): hide/remove both guide lines.

## Verify (mandatory)
- `dotnet build src/CcDashboard.Web -c Debug` -> 0 errors (or note JS-only change needs no build; still build to be safe).
- JS parses (no syntax error); guides appear on edge/centre alignment vs another widget + canvas centre; vanish on drop; none when not dragging; works 1280-wide, light+dark, LTR+RTL; no persistence side-effects (single-widget drag commit unchanged).
- app.css?v bumped in App.razor (cache bust for new class).

## Commit (feat:, NO push) under commit.lock
bash tools/pre-commit-check.sh ; git add (changed claimed files) ; git commit -m "feat: widget alignment guide lines during move (F-A) + optional snap [shell-0609]" ; git rev-parse HEAD
§0.6 post-commit -> cc_post_commit.sh shell-0609 <hash> -> PD-007 re-sync committed files from HEAD (hash-verify) -> sync.

## Binding RESULT -> .coord/cc/shell.md (status: done): commit <hash>; guides V/H on align + snap; app.css?v bumped; build 0 err; no persistence change. NO push. verified: object-store.

## Report (chat): files changed; build; guide behaviour (align/snap/clear); app.css?v bump; commit hash. NO push.
