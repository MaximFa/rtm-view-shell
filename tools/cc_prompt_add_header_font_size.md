# CC Task: Add Header Font Size to Appearance tab (AgentGrid, QueueGrid, DataSlot)

## Goal
Add a "Header Font Size" setting to the Appearance tab of the configurators for
AgentGrid, QueueGrid, and DataSlot widgets. Rename the existing "Font Size" label to
"Table Font Size". Both use the same `_tenantFontSizes` list.

- **Table Font Size** = font size for data rows (existing `FontSize` config field)
- **Header Font Size** = font size for the header row / title element (new `HeaderFontSize` config field)

## Files to change
1. `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`
2. `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor`
3. `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`
4. `src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor`
5. `src/CcDashboard.Web/Resources/SharedResources.en-US.resx`
6. `src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx`
7. `src/CcDashboard.Web/Resources/SharedResources.he-IL.resx`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change 1 — ScreenEditorPage.razor (4 sub-changes)

### 1a. WidgetConfig class — add HeaderFontSize property
Find (around line 5103):
```csharp
        public string? FontSize { get; set; }
```
Add after it:
```csharp
        public string? HeaderFontSize { get; set; }
```

### 1b. State field — add ConfigHeaderFontSize
Find (around line 2290):
```csharp
    private string ConfigFontSize = "14";
```
Add after it:
```csharp
    private string ConfigHeaderFontSize = "14";
```

### 1c. Appearance UI — rename label and add second dropdown
Find this block (around line 546):
```razor
                                    <label class="form-label small text-muted mb-1">Font Size</label>
                                    <select class="form-select form-select-sm" @bind="ConfigFontSize">
                                        @foreach (var size in _tenantFontSizes)
                                        {
                                            <option value="@size">@size px</option>
                                        }
                                    </select>
```
Replace with:
```razor
                                    <label class="form-label small text-muted mb-1">@L["Widgets_TableFontSize"]</label>
                                    <select class="form-select form-select-sm" @bind="ConfigFontSize">
                                        @foreach (var size in _tenantFontSizes)
                                        {
                                            <option value="@size">@size px</option>
                                        }
                                    </select>
```
Then find the `</div>` that closes the `col-md-6` div containing the Font Size select
(it's the `</div>` right after the `</select>`), and after it add a new col:
```razor
                                <div class="col-md-6">
                                    <label class="form-label small text-muted mb-1">@L["Widgets_HeaderFontSize"]</label>
                                    <select class="form-select form-select-sm" @bind="ConfigHeaderFontSize">
                                        @foreach (var size in _tenantFontSizes)
                                        {
                                            <option value="@size">@size px</option>
                                        }
                                    </select>
                                </div>
```

### 1d. Load config — read HeaderFontSize
Find (around line 3151):
```csharp
        ConfigFontSize = ResolveFontSizeToPixel(widget.Config.FontSize);
```
Add after it:
```csharp
        ConfigHeaderFontSize = ResolveFontSizeToPixel(widget.Config.HeaderFontSize);
```

### 1e. Save config — write HeaderFontSize
Find (around line 4293):
```csharp
            FontSize = ConfigFontSize,
```
Add after it:
```csharp
            HeaderFontSize = ConfigHeaderFontSize,
```

---

## Change 2 — QueueGridWidget.razor (3 sub-changes)

### 2a. Add _headerFontSize field
Find:
```csharp
    private string? _fontSize;
```
Add after it:
```csharp
    private string? _headerFontSize;
```

### 2b. Load from Config
Find:
```csharp
            _fontSize = Config.FontSize;
```
Add after it:
```csharp
            _headerFontSize = Config.HeaderFontSize;
```

### 2c. Apply in GetTheadStyle()
Find in `GetTheadStyle()` — it ends with:
```csharp
        if (!string.IsNullOrEmpty(fg))
            styles.Add($"color: {fg}");

        return string.Join("; ", styles);
    }
```
Replace with:
```csharp
        if (!string.IsNullOrEmpty(fg))
            styles.Add($"color: {fg}");

        var headerFs = !string.IsNullOrEmpty(_headerFontSize) ? _headerFontSize : _fontSize;
        if (!string.IsNullOrEmpty(headerFs))
            styles.Add($"font-size: {ResolveFontSizePx(headerFs)}");

        return string.Join("; ", styles);
    }
```

---

## Change 3 — AgentGridWidget.razor (3 sub-changes)

### 3a. Add _headerFontSize field
Find in AgentGridWidget:
```csharp
    private string? _fontSize;
```
Wait — check the actual field name in AgentGridWidget. It may differ. Search for `_fontSize` in AgentGridWidget.razor and add `_headerFontSize` after it.

### 3b. Load from Config
Find in AgentGridWidget where `_fontSize` is loaded from Config (e.g. `_fontSize = Config.FontSize;`).
Add after it:
```csharp
            _headerFontSize = Config.HeaderFontSize;
```

### 3c. Apply in GetTheadStyle()
Find `GetTheadStyle()` in AgentGridWidget. It ends similarly to QueueGridWidget.
Before the final `return string.Join("; ", styles);` line, add:
```csharp
        var headerFs = !string.IsNullOrEmpty(_headerFontSize) ? _headerFontSize : _fontSize;
        if (!string.IsNullOrEmpty(headerFs))
            styles.Add($"font-size: {ResolveFontSizePx(headerFs)}");
```

---

## Change 4 — DataSlotWidget.razor (3 sub-changes)

For DataSlot, "header" = the `data-slot-title` element (the label above the value).
Currently `GetFontColorStyle()` renders the title without font-size.

### 4a. Add _headerFontSize field
Find:
```csharp
    private string _fontSize = "normal";
```
Add after it:
```csharp
    private string _headerFontSize = "normal";
```

### 4b. Load from Config
Find:
```csharp
        _fontSize = Config.FontSize ?? "normal";
```
Add after it:
```csharp
        _headerFontSize = Config.HeaderFontSize ?? "normal";
```

### 4c. Apply in GetFontColorStyle()
Find:
```csharp
    private string GetFontColorStyle()
    {
        // Title uses base font color (not affected by thresholds)
        var fg = BaseFontColor;
        return !string.IsNullOrEmpty(fg) ? $"color: {fg};" : "";
    }
```
Replace with:
```csharp
    private string GetFontColorStyle()
    {
        // Title uses base font color (not affected by thresholds)
        var fg = BaseFontColor;
        var fs = ResolveFontSizePx(_headerFontSize);
        var result = new System.Text.StringBuilder();
        if (!string.IsNullOrEmpty(fg)) result.Append($"color: {fg}; ");
        result.Append($"font-size: {fs};");
        return result.ToString();
    }
```

---

## Change 5 — Localization (3 resx files)

### en-US (SharedResources.en-US.resx)
Find:
```xml
  <data name="Widgets_FontSize"><value>Font Size</value></data>
```
Add after it (keep Widgets_FontSize for backward compat, add two new keys):
```xml
  <data name="Widgets_TableFontSize"><value>Table Font Size</value></data>
  <data name="Widgets_HeaderFontSize"><value>Header Font Size</value></data>
```

### ru-RU (SharedResources.ru-RU.resx)
Find:
```xml
  <data name="Widgets_FontSize"><value>Размер шрифта</value></data>
```
Add after it:
```xml
  <data name="Widgets_TableFontSize"><value>Размер шрифта таблицы</value></data>
  <data name="Widgets_HeaderFontSize"><value>Размер шрифта заголовка</value></data>
```

### he-IL (SharedResources.he-IL.resx)
Find the section with `TenantSettings_FontSizes` (he-IL may not have Widgets_FontSize).
Add anywhere in the data section:
```xml
  <data name="Widgets_TableFontSize"><value>גודל גופן טבלה</value></data>
  <data name="Widgets_HeaderFontSize"><value>גודל גופן כותרת</value></data>
```

---

## Verification

```bash
# Confirm keys in resources
grep -c "TableFontSize\|HeaderFontSize" \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx
# Each must show 2

# Confirm WidgetConfig has new property
grep -n "HeaderFontSize" \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | head -10

# Confirm widgets load the new field
grep -n "_headerFontSize\|HeaderFontSize" \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor | head -20
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx \
  src/CcDashboard.Web/Resources/SharedResources.he-IL.resx
# Only if exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx \
  src/CcDashboard.Web/Resources/SharedResources.he-IL.resx \
  tools/cc_prompt_add_header_font_size.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: add Header Font Size to Appearance tab (AgentGrid, QueueGrid, DataSlot); rename Font Size → Table Font Size"
cp /tmp/cc-idx .git/index
```

Post-commit (§0.6):
```bash
git status --short
git log --oneline -3
```

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.

---

## Re-sync from HEAD (§0.6 PD-007, mandatory last step)

```bash
for f in \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor \
  src/CcDashboard.Web/Resources/SharedResources.en-US.resx \
  src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx \
  src/CcDashboard.Web/Resources/SharedResources.he-IL.resx; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
