# Solution Plan — Widget alignment guides + widget grouping (Shell/UI canvas)

> Author: shell-0609 (Shell + UI/UX). For coordinator §4 / `коорд: ревью`. 2026-06-13.
> Three operator features on the dashboard editor canvas (ScreenEditorPage.razor):
>   F-A: during widget MOVE, project horizontal + vertical alignment guide lines vs other widgets (only while dragging).
>   F-B: a grouping option so several widgets move together as one block.
> This is a PLAN only — no code written. On §4 PASS I author the CC prompt(s) → operator runs.

## 0. Current architecture (grounded — what we build on)
- Widgets render on a canvas in `ScreenEditorPage.razor`, absolutely positioned in px (`style.left/top`, width/height).
- Drag/resize is JS-interop: `wwwroot/js/widget-resize.js` (`window.widgetResize`), `init(dotNetRef)`, global
  mousemove/mouseup. `StartMove(widgetId,e)` (razor `@onmousedown` on `.widget-drag-handle`) → `startMove` →
  `onMouseMove` updates `widget.style.left/top` live → `onMouseUp` commits via
  `dotNetRef.invokeMethodAsync('OnWidgetMoved', widgetId, left, top)` (Blazor persists position).
- So: smooth drag is client-side JS; Blazor persists only on drop. Position store = per-widget left/top/size
  (DashboardWidget / Config / PositionJson — confirm exact field at impl).
- NOTE (raise to coordinator): CLAUDE.md §1 + WGT-04 still say "drag-and-drop layout … out of scope". That line is
  STALE — drag/resize/move/templates are implemented. Recommend coordinator update §1/WGT-04 (or confirm in-scope)
  so this work isn't built against documented out-of-scope. Not a blocker, a doc-sync item.

## 1. Territory / claims (coordinator to ratify; possible split with Widget specialist)
The canvas interaction layer is Shell + UI/UX:
  - `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`  (my standing EXCLUSIVE claim)
  - `src/CcDashboard.Web/wwwroot/js/widget-resize.js`
  - `src/CcDashboard.Web/wwwroot/app.css`
  - 3× `SharedResources.*.resx` (any new UI strings, I18N-03)
F-B *persistent* groups (option B2 below) would touch the widget DATA MODEL (DashboardWidget + migration + commands)
= Widget/backend/DBA territory, NOT pure Shell. Flagged so coordinator assigns / splits before any data-model work.

## 2. Feature A — alignment guide lines during move
**Goal:** while dragging a widget, show a horizontal and/or vertical guide line when the dragged widget's edge or
centre aligns (within a threshold) with another widget's edge/centre (and canvas centre/edges). Lines appear only
during the drag and disappear on drop. Pure visual feedback; optional light snapping.

**Design (client-side only — no Blazor/DB change):**
1. In `widget-resize.js`, during `onMouseMove` in `mode==='move'`: after computing the new left/top, gather candidate
   alignment targets = for every OTHER widget on the canvas (`canvas.querySelectorAll('.widget')` minus the dragged
   one): its left, centreX, right, top, centreY, bottom. Also canvas centre/edges.
2. Compute the dragged widget's own left/centreX/right/top/centreY/bottom at the candidate position. For each axis,
   if |draggedValue − targetValue| ≤ THRESHOLD (≈6 px), record a match.
3. Render guides: one reusable vertical line div + one horizontal line div appended to the canvas (created once,
   shown/positioned on match, hidden when no match). Full canvas height/width, 1px, accent colour, `pointer-events:none`,
   high z-index. Class e.g. `.widget-align-guide.vertical/.horizontal` in app.css (dark-mode + RTL safe via logical props).
4. OPTIONAL snap (propose as config/default-on): when a match is within threshold, set the dragged widget's left/top
   to the matched value so it clicks into alignment. If snapped, the committed `OnWidgetMoved` already carries the
   snapped coords — no extra persistence path.
5. On `onMouseUp` / drag end: hide/remove both guide lines. Also clear on Escape-cancel if cancel exists.
**Files:** widget-resize.js (move loop + guide draw/clear), app.css (guide line styles). No .razor change strictly
needed (JS creates the guide divs), but may add a `.widget-canvas` anchor class if not present.
**Acceptance:** dragging a widget shows V/H lines when edges/centres align with another widget or canvas centre;
lines vanish on drop; no lines when not dragging; works at 1280-wide, light+dark, LTR+RTL; no persistence side-effects.
**Effort:** S (1 focused CC task, JS+CSS).

## 3. Feature B — widget grouping / move several as one block
Two viable scopes; recommend phasing B1 → (later) B2.

**B1 — ephemeral multi-select + move-together (RECOMMENDED v1, Shell-only):**
- Selection: Ctrl/⌘-click (or Shift-click) a widget toggles it into a selection set; click empty canvas clears.
  (Stretch: rubber-band marquee select — can be a follow-up.) Selected widgets get a `.selected` outline.
- Move: when `startMove` fires on a widget that is part of the selection, drag moves ALL selected widgets by the
  same delta (dx,dy) in `onMouseMove`; guides (F-A) reference the group's bounding box.
- Commit: on mouseup, persist EACH moved widget — either call `OnWidgetMoved` per widget, or add a batch
  `OnWidgetsMoved([{id,left,top}...])` JSInvokable (cleaner, one round-trip). Blazor persists each position.
- State: selection set lives in JS (and/or Blazor field) — NO data model change, NO migration. Pure interaction.
- Files: widget-resize.js (selection set + group delta move + batch commit), ScreenEditorPage.razor (selection
  click handlers, `.selected` rendering, optional "group move" affordance + a batch [JSInvokable]), app.css
  (selection outline + group bounding box), resx (any labels).
- **Acceptance:** Ctrl-click selects multiple; dragging any selected widget moves all by the same delta; each new
  position persists; click-empty deselects; single-widget drag unaffected; undo/refresh shows persisted positions.
- **Effort:** M.

**B2 — persistent named groups (LATER, cross-territory — needs data model):**
- A widget can belong to a Group; group is saved; selecting one selects the group; group moves as a unit always.
- Requires: `GroupId` on DashboardWidget (or a join) + EF migration + create/ungroup commands + persistence.
- That is Widget/backend/DBA work (data model + migration + commands), NOT pure Shell. Out of my lane —
  needs coordinator to scope a multi-session task (Shell does the UI, Widget/backend the model/commands, DBA the migration).
- Recommend deferring B2 to a follow-up unless the operator specifically wants groups to PERSIST across sessions.

**Open question for operator/coordinator:** does "grouping" mean just *move-many-together right now* (B1, no
persistence) or *saved groups that persist* (B2, data model)? B1 satisfies the literal ask ("передвигать несколько
виджетов одним блоком") with no schema change. Recommend B1 first.

## 4. Risks / notes
- JS perf: guide computation runs per mousemove — keep it O(n) over widgets, cache the sibling rect list at drag
  start (positions of non-dragged widgets don't change mid-drag), recompute only the dragged box. Avoids layout thrash.
- RTL: use logical offsets; guides are absolute px so mostly direction-agnostic, but selection/affordance UI must be RTL-safe.
- Touch: current drag is mouse-events only; touch is out of scope unless asked (note it).
- §1/WGT-04 doc-sync (stale out-of-scope line) — flag to coordinator/techwriter.
- No security surface (pure client interaction + existing persist path; no new inputs/DML).

## 5. Proposed phasing → CC prompts (authored after §4 PASS)
1. CC-1: Feature A alignment guides (widget-resize.js + app.css). [S]
2. CC-2: Feature B1 ephemeral multi-select + group move + batch commit (widget-resize.js + ScreenEditorPage.razor +
   app.css + resx). [M]  — guides (F-A) reference group bbox once CC-1 lands.
3. (Deferred) CC-3: Feature B2 persistent groups — coordinator-scoped multi-session (data model) IF operator wants persistence.
Each CC prompt carries the standard mandatory blocks (§0.6a integrity, §40 skills, §42.6 sync/claims, §0.3 Python-only,
fix/feat commit, no push) and acceptance criteria above.

## Task 3 — left palette PUSHES the canvas (in-flow) + collapse-to-zero  [REVISED 2026-06-13: keep LEFT, do NOT move to top]
**Operator change:** keep the palette on the LEFT (cancel the top-strip idea), but it must SHIFT the canvas (push),
not float OVER it, and still collapse to zero so the whole screen is visible.

**Current code (verified):** `.editor-fullscreen` = column flex [header][canvas]; `.editor-palette` is
`position:fixed; inset-block-start:56px; inset-inline-start:0; width:300px; z-index:50; box-shadow; translateX(-100%)`,
`.open → translateX(0)`. `.editor-canvas{flex:1}` always spans full width under the header. => palette is an OVERLAY
that slides in OVER the canvas and HIDES the widgets behind it (operator's "выходит сверху / наезжает"). Toggle =
`TogglePalette` → `PaletteOpen` → `.editor-palette.open`.

**Design (Shell/UI only — markup + CSS, no data model):**
1. Wrap palette + canvas in a horizontal flex row under the header: `.editor-body { display:flex; flex:1; min-height:0; }`
   (insert `<div class="editor-body">` around `.editor-palette` + `.editor-canvas` in ScreenEditorPage.razor).
2. `.editor-palette`: REMOVE `position:fixed` + `transform`/translateX + `box-shadow` overlay. Make it an in-flow
   flex item: `flex:0 0 auto; width:0; overflow:hidden; transition:width var(--dur-slow) var(--ease-out);` keep the
   inline-end border. `.editor-palette.open { width:300px; }` → opening GROWS the column and the canvas reflows.
3. `.editor-canvas`: `flex:1; min-width:0;` (min-width:0 so it can shrink) — it now takes the REMAINING width, i.e.
   it is PUSHED right by the open palette and reclaims the space when closed = collapse-to-zero (width 0, no residual).
4. Toggle unchanged (`TogglePalette` / `.open`); width animates 0↔300. Closed = literal 0 width, full canvas.
5. RTL: drop the `[dir=rtl] translateX` rule — flex order already puts the palette on the inline-start; verify in he-IL.
6. Persist open/closed per-user (localStorage `cc:screeneditor:palette:{userId}`, §41) so it stays as the user left it.
**Files:** ScreenEditorPage.razor (wrap palette+canvas in `.editor-body`), app.css (`.editor-body` + rewrite
`.editor-palette` to in-flow width-collapse + `.editor-canvas` min-width:0; remove the fixed/translateX/RTL-translate
rules incl. the dark-mode palette rule if it sets position). app.css?v bump (App.razor — FLAG, not in claims). resx: none new (toggle exists).
**Acceptance:** open palette pushes the canvas right (widgets fully visible, never covered); close collapses it to 0
width and canvas fills the screen; smooth width transition; state persists per-user; 1280-wide, light+dark, LTR+RTL OK;
drag&drop from palette to canvas still works.
**Effort:** S–M (CSS restructure + one markup wrapper).
**Superseded:** the earlier top-horizontal-strip mockup (kept for history) — operator chose LEFT-push instead.

## 6. Ask of coordinator (§4 / ревью)
- Verdict on this plan (PASS / REVISE).
- Ratify Shell territory for the canvas-interaction files; confirm B2 (if pursued) is a separate Widget/backend/DBA task.
- Decide B1 vs B2 for "grouping" (recommend B1 first) — or relay the operator's intent.
- Confirm the §1/WGT-04 out-of-scope line should be updated (doc-sync).
- On PASS: I author CC-1 (F-A) + CC-2 (F-B1) + CC-3 (Task 3 top-palette/collapse) under tools/ → your §4 → operator runs.
