# CC task — T6 (6A): template doesn't save widget SIZE -> drops at default 280x200 (role-shell)
> §4-PASS by coordinator-0612 2026-06-17T14:15Z (operator chose 6A: no migration, Shell-only). Owner: role-shell. Executor: native CC.
> Claims: Components/Dashboard/ScreenEditorPage.razor (WidgetConfig model + SaveAsTemplate + template-drop). Commit `fix:`. **NO push**. PACKAGE FINALE.
> 6A = store W/H inside WidgetConfig (serialized into the existing ConfigJson). NO DB / NO migration. 6B columns+migration = DEFERRED cross-territory.

## INIT (role-shell §A + §C-green) + §40. §0.6a integrity + POST-VERIFY (ls+cat+git, NOT -f/-s). §42.6 sync shell-0609 (S1-S5). §0.3 Python+fsync. Binding PREAMBLE -> .coord/cc/shell.md.

## ROOT (object-store)
WidgetTemplate persists only ConfigJson (no W/H column); SaveAsTemplate serializes the widget's WidgetConfig (no size) -> on template DROP the widget is created at the hardcoded default Width=280/Height=200 (ScreenEditorPage ~3068 and ~3112) -> user must re-stretch. 6A: carry W/H inside WidgetConfig (ConfigJson) so it round-trips template->drop.

## THE WORK — 6A (size in ConfigJson, no migration)
1. **WidgetConfig model (ScreenEditorPage.razor:5282 `public class WidgetConfig`):** add `public int? Width { get; set; }` and `public int? Height { get; set; }` (nullable so old configs/templates without size fall back to default).
2. **SaveAsTemplate (handler ~2194 `SaveAsTemplate`):** before serializing the config into the template's ConfigJson, set `config.Width = widget.Width; config.Height = widget.Height;` (capture the CURRENT widget size of `WidgetToSaveAsTemplate`). So the template's ConfigJson carries the size.
3. **Template DROP (the default-size site that applies to dropping FROM a template — inspect ~3068 and ~3112; identify which is the template-instantiation path):** when creating a widget FROM a template, use the template config's saved size if present: `Width = templateConfig.Width ?? 280; Height = templateConfig.Height ?? 200;` (keep 280x200 ONLY as the fallback when the template has no saved size). Do NOT change the NEW-from-catalog default (that legitimately starts 280x200) unless it's the same path — distinguish them.
4. Confirm the config (de)serialization includes the new fields (System.Text.Json auto-includes public props; no special handling unless a custom converter/ignore exists — grep to be sure).

## Acceptance (product on 5239, operator floor)
Resize a widget; Save as template; drop that template onto a screen -> the new widget appears at the SAVED size (not 280x200). Old templates (no saved size) still drop at 280x200. New-from-catalog widget still starts at its normal default.

## VERIFY (build-cite or honest 'not run')
- Object-store: WidgetConfig has int? Width/Height; SaveAsTemplate sets config.Width/Height from the widget; template-drop reads config.Width ?? 280 / Height ?? 200; new-from-catalog default unchanged.
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line; else honest "BUILD: not run (no dotnet)".** New props are standard int? -> no new @inject/@using needed; confirm no JSON converter excludes them.

## §0.6b CAPTURE -> role-shell §B if a real lesson (e.g. carry size in ConfigJson to avoid a schema migration for template-size).

## Commit (fix:, NO push) under commit.lock: git add (ScreenEditorPage.razor + role-shell.md if CAPTURE) ; commit -m "fix: template saves+restores widget size via WidgetConfig W/H in ConfigJson (was dropping at default 280x200) (T6 6A) [shell-0609]" ; §0.6 post-commit ; cc_post_commit.sh ; PD-007 re-sync ; sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; WidgetConfig int? Width/Height; SaveAsTemplate captures size; template-drop applies config.Width??280/Height??200; new-from-catalog default unchanged; build cite OR 'not run'; CAPTURE if any. NO push. verified: object-store (+build if avail).

## Report (chat): commit hash; the 3 edits via git show HEAD; build line OR honest not-run; product-floor=operator 5239 (template keeps size). NO push. NOTE: this is the package finale -> after product-verify, coordinator assembles the push barrier.

## CONFIRMED ANCHORS (object-store by shell-0609 2026-06-17T14:18Z — use THESE exact sites; supersedes the ~3068/~3112 guess in step 3)
- **WidgetConfig class @5282** — add `public int? Width { get; set; }` + `public int? Height { get; set; }` (nullable -> old templates fall back).
- **SaveAsTemplate serialize @~5562** — `var configJson = JsonSerializer.Serialize(WidgetToSaveAsTemplate.Config, _jsonOptions);`. BEFORE that line set `WidgetToSaveAsTemplate.Config.Width = WidgetToSaveAsTemplate.Width; WidgetToSaveAsTemplate.Config.Height = WidgetToSaveAsTemplate.Height;` so the size goes into ConfigJson.
- **Template DROP = `OnDropTemplateAtPosition` @~5622** — the `new PlacedWidget { ... Width = 280, Height = 200 ... }` @~5672-5673. Change ONLY these two to `Width = config.Width ?? 280, Height = config.Height ?? 200` (config = ParseWidgetConfig(DraggedTemplate.ConfigJson) @5638). This is the template path.
- **DO NOT TOUCH the two CATALOG-drop sites** (`Width = 280, Height = 200` near ~3061 and ~3105, `CatalogItemId = DraggedWidget.Id`, `Config = new WidgetConfig()`) — new-from-catalog legitimately starts 280x200.
- `ParseWidgetConfig` @5247 uses `JsonSerializer.Deserialize<WidgetConfig>` (auto-includes new public int? props); `_jsonOptions` @5241 — confirm no DefaultIgnoreCondition that would drop the size on write (int? with a value writes regardless of WhenWritingNull).
