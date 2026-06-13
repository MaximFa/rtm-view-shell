# CC Task — Implement TextWidget (static text content widget)

> **Planned by:** daytrend-3-0609 (Widget specialist), 2026-06-13. Design locked with operator.
> **Primary executor (proposed):** shell-0609 — owns `ScreenEditorPage.razor` (EXCLUSIVE), `app.css`,
> and `Components/Widgets/*.razor`. Coordinator confirms/splits territory before issuing (see "Territory" below).
> **NOT a Grid widget** — no SignalR, no RTSGrid_*, no SQL, no metrics, no simulator. Standard widget deletion only.

---

## 0. Mandatory reads — before any code (NO EXCEPTIONS)

```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md   (focus §16 Dark Mode, §18 UI guidelines, §21 Config modal tabs, §22 CC template)
Read: .claude/skills/session-coord/session-coord.md
```
Then inspect `src/CcDashboard.Web/Components/Widgets/InfoSlotWidget.razor` and its config wiring in
`ScreenEditorPage.razor` (`IsInfoSlotWidget`) + `InfoSlotWidgetConfig` — **the new widget mirrors this
pattern exactly but simpler** (single static text, no DB messages).

## 0.6a — Integrity check (Step 0, run first)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"; else echo "OK: $f"; fi
done
sync; echo "=== integrity check complete ==="
```

## Multi-session sync — MANDATORY

Session slug: `shell-0609`  (coordinator confirms executor)
Claims for this task:
- `src/CcDashboard.Web/Components/Widgets/TextWidget.razor` (NEW)
- `src/CcDashboard.Web/Components/Widgets/TextWidget.razor.css` (NEW, if needed)
- `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor` (shell-0609 EXCLUSIVE — config tabs + predicate + save)
- `src/CcDashboard.Web/wwwroot/app.css` (shell-0609 — widget container styling if needed)
- `src/CcDashboard.Web/Resources/SharedResources*.resx` (new @L keys)
- `src/CcDashboard.Contracts/DTOs/Widgets/TextWidgetConfig.cs` OR the shared WidgetConfig (config fields) — **coordinator: confirm Contracts owner / grant**
- `src/CcDashboard.Infrastructure/Persistence/<DatabaseInitializer or seed file>` (WidgetCatalogItem seed row) — **coordinator: confirm Infrastructure owner / grant**

### S1. Push barrier check
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
    echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1
fi
```
### S2. Claim check
```bash
python3 tools/coord_check_claims.py shell-0609 <each claimed path...>
# exit 1 -> STOP, conflict to .coord/queue.md (skill §9). ScreenEditorPage.razor/app.css are shell-0609 standing-EXCLUSIVE.
```
Modify ONLY claimed files (+ /tmp throwaways). Touch outside claims -> STOP and report.
### S3. commit.lock around every git add/commit (template in tools/cc_prompt_sync_block.md S3 — phantom-aware, retry 5×60s).
While holding: `bash tools/pre-commit-check.sh` -> `git add` (claimed only) -> `git commit` (prefix `web:` for src; `db:` only if a migration is added) -> §0.6 post-commit verify.
### S4. After commit (LAST step): `bash tools/cc_post_commit.sh shell-0609 $(git log -1 --format=%h)` then `sync`.
### S5. Do NOT `git push` (§37). Push only via tools/cc_prompt_push.md after the barrier.

---

## 1. Widget design (locked with operator 2026-06-13)

**Name:** TextWidget — "Text" (static text block)
**Type:** Static content. No data source, no SignalR, no SQL, no metrics.
**Content:** Static text typed by admin/Editor at screen-config time. Displayed as-is.
**Editing:** Edit-mode only (admin/Editor). No View-mode user configurator (no gear icon, no UserWidgetSettings).
**Formatting:** Basic — font size, bold, alignment, text colour, background colour. **Light/Dark theme aware (mandatory).**

### 1.1 Security (L-35, CODE-02) — render as PLAIN TEXT
The text is rendered as a plain text node with `white-space: pre-wrap` (preserves user line breaks).
**Do NOT use `@((MarkupString)...)`** — no HTML/markdown is interpreted, so there is no XSS surface.
This is the whole reason formatting is config-driven (font/colour/align), not inline markup.

### 1.2 Config (mirror `InfoSlotWidgetConfig` conventions)
Record `TextWidgetConfig` (or extend the shared widget config — follow whatever InfoSlot uses):

| Field | Type | Default | Notes |
|---|---|---|---|
| `DisplayName` | string | "" | widget header title |
| `Text` | string | "" | the content (multiline) |
| `FontSizePx` | int | 16 | font size in px (or reuse tenant font-size set if InfoSlot does) |
| `Bold` | bool | false | font-weight bold toggle |
| `TextAlign` | string | "start" | logical: `start` / `center` / `end` (RTL-safe, CSS logical) |
| `VerticalAlign` | string | "top" | `top` / `middle` / `bottom` (optional) |
| `BackgroundColor` | string | "auto" | "auto" = follow theme; else hex. Light value. |
| `TextColor` | string | "auto" | "auto" = follow theme; else hex. Light value. |
| `DarkBackgroundColor` | string | "auto" | dark-theme override (mirror InfoSlot `Dark*` fields) |
| `DarkTextColor` | string | "auto" | dark-theme override |

**Theme handling:** reuse the exact `data-bg`/`data-text` + `WidgetStyle` mechanism from `InfoSlotWidget.razor`
(it already resolves Light vs Dark colours and "auto"). Do NOT invent a new theming approach.

### 1.3 Config modal tabs (Phase 2.5) — 2 tabs
- **General:** Display name; Text (multiline `<textarea>`); Text alignment; Vertical alignment.
- **Appearance:** Font size; Bold; Text colour (light) + dark; Background colour (light) + dark.
Wire via an `IsTextWidget(widget)` predicate in `ScreenEditorPage.razor`, exactly like `IsInfoSlotWidget`
(gate the tab `@if` blocks + the config-save object construction).

### 1.4 Localization (Phase 2.6, L-34)
All visible config labels via `@L["Key"]`. Check `SharedResources.en-US.resx` for existing keys
(reuse `InfoSlot_*` appearance keys where identical, e.g. background/text colour, font size, alignment).
New keys prefix `Text_` (e.g. `Text_Content`, `Text_Align`, `Text_EmptyState`). Run the L-34 key-match
verification (razor `@L[...]` ⊆ resx `data name`) — output MUST be empty before commit.
Empty-state (no text configured): show `@L["Text_EmptyState"]` (e.g. "No text configured").

### 1.5 Catalogue seed (§N.9)
Add a `WidgetCatalogItem`: `Category = "General"`, `Name = "Text"`, `Description = "Static text block"`,
`IsActive = true`. Add idempotently next to existing catalogue seed rows (find via
`grep -rn "new WidgetCatalogItem\|WidgetCatalogItem {" src/CcDashboard.Infrastructure` — likely DatabaseInitializer).

### 1.6 Access control
Add to screen (Edit mode): Editor / Administrator / Superadmin (same as other widgets). View: all with screen View.
No special permission. No RTS/permission-group resource scoping (it shows no CC data).

### 1.7 Deletion — STANDARD (not Specialized Grid)
This widget creates NO `RTSGrid_*` records. Deletion removes the `DashboardWidget` only.
**Do NOT** add it to the 3-place `DeleteQueueGridRtsCommand` chain in `ScreenEditorPage.razor` (L-26 does NOT apply).

### 1.8 Draggable config modal (L-36)
The config modal already supports drag (shared ScreenEditorPage modal). No extra work unless a new modal is introduced.

---

## 2. Deliverables

| # | Deliverable | Location |
|---|---|---|
| 1 | `TextWidgetConfig` fields | `src/CcDashboard.Contracts/DTOs/...` (mirror InfoSlotWidgetConfig) |
| 2 | `TextWidget.razor` (+ `.razor.css` if needed) | `src/CcDashboard.Web/Components/Widgets/` |
| 3 | Config tabs + `IsTextWidget` predicate + save wiring | `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor` |
| 4 | `@L` keys (`Text_*`) | `src/CcDashboard.Web/Resources/SharedResources*.resx` |
| 5 | `WidgetCatalogItem` seed row | `src/CcDashboard.Infrastructure/Persistence/<seed>` |
| 6 | Container CSS (if needed; reuse InfoSlot patterns) | `app.css` or `TextWidget.razor.css` |

## 3. Acceptance criteria
- [ ] `dotnet build CcDashboard.sln` — 0 errors.
- [ ] "Text" appears in the widget catalogue (General category) in the New-Screen / ScreenEditor picker.
- [ ] Adding the widget + opening config shows 2 tabs (General, Appearance) with all §1.2 fields.
- [ ] Saving config persists `Text` + appearance; reopening shows saved values.
- [ ] Viewer renders the configured text with chosen font size/bold/alignment/colours.
- [ ] **Light/Dark:** toggling theme correctly applies BackgroundColor/TextColor vs Dark* (matches InfoSlot behaviour); "auto" inherits theme.
- [ ] Text rendered as plain text (`pre-wrap`), NOT MarkupString — verify no HTML injection (enter `<b>x</b>` -> shows literally).
- [ ] Empty text shows `@L["Text_EmptyState"]`.
- [ ] L-34 key-match check empty (razor `@L` keys ⊆ resx).
- [ ] Deleting the widget + Save leaves NO orphaned records (it never created RTSGrid_* rows; confirm standard delete).
- [ ] RTL: alignment uses CSS logical (`start`/`end`), correct under `dir="rtl"`.

## 4. Territory note for coordinator (read before issuing)
This task spans THREE ownership zones:
1. **shell-0609 (EXCLUSIVE standing):** `ScreenEditorPage.razor`, `app.css`, `Components/Widgets/*.razor` — primary.
2. **Contracts:** `TextWidgetConfig` DTO — confirm owner or grant to shell-0609.
3. **Infrastructure:** WidgetCatalogItem seed — confirm owner or grant to shell-0609.
Recommend: issue as ONE prompt to shell-0609 with temporary grants on the Contracts DTO + Infra seed file
(both are small, additive, uncontested), OR split off deliverables #1 and #5 to the respective owners.
Coordinator decides + runs §4 review before the operator issues `Выполни задачу из файла tools/cc_prompt_text_widget.md`.
