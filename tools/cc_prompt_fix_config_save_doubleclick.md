# CC Task: Fix double-click Save in widget configurator (DbContext concurrency error)

## Problem
Clicking "Save" twice in the widget configurator modal fires two concurrent
`SaveWidgetConfig()` calls → both use the same scoped `BackendEmulationDbContext`
→ EF Core throws "A second operation was started on this context instance before
a previous operation completed."

## Fix
Three changes in `ScreenEditorPage.razor`:
1. Add `_configSaving` bool field
2. Wrap `SaveWidgetConfig()` with try/finally to set/reset the flag
3. Disable the Save button while `_configSaving == true`

## File
`src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Environment rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — bash tools/pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change 1 — Add _configSaving field (near line 2239 where `private bool Saving;` is)

Find this line:
```
    private bool Saving;
```

Add after it:
```
    private bool _configSaving;  // Guards SaveWidgetConfig against double-click
```

## Change 2 — Disable Save button in configurator modal (line 2134)

Find this exact line:
```
                    <button class="btn btn-primary" @onclick="async () => await SaveWidgetConfig()">@L["Common_Save"]</button>
```

Replace with:
```
                    <button class="btn btn-primary" @onclick="async () => await SaveWidgetConfig()" disabled="@_configSaving">@L["Common_Save"]</button>
```

## Change 3 — Wrap SaveWidgetConfig with try/finally (starts at line 4007)

Find:
```csharp
    private async Task SaveWidgetConfig()
    {
        if (ConfiguringWidget is null || Dashboard is null) return;
```

Replace with:
```csharp
    private async Task SaveWidgetConfig()
    {
        if (ConfiguringWidget is null || Dashboard is null) return;
        if (_configSaving) return;  // Guard against double-click
        _configSaving = true;
        StateHasChanged();
        try
        {
```

Then find the closing brace of SaveWidgetConfig — the `}` just before
`private async Task SaveLayout()` (around line 4760). Replace that lone `}` with:
```csharp
        }
        finally
        {
            _configSaving = false;
            StateHasChanged();
        }
    }
```

**Important:** the method body is already inside a try/catch block in some branches —
add the outer try/finally AROUND the entire existing method body (after the guard checks),
not inside an existing try/catch.

Verify the structure is:
```
SaveWidgetConfig() {
    if null checks...
    if (_configSaving) return;
    _configSaving = true;
    StateHasChanged();
    try {
        ... existing method body ...
    }
    finally {
        _configSaving = false;
        StateHasChanged();
    }
}
```

---

## Verification after writing

```bash
sync
tail -5 src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
wc -l src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor

# Confirm field added
grep -n "_configSaving" src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor

# Confirm button disabled
grep -n "SaveWidgetConfig" src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor | grep "disabled"

# Confirm try/finally wraps method
grep -n "finally\|_configSaving\|Guard against" src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
```

---

## Commit

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
# Only if exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
GIT_INDEX_FILE=/tmp/cc-idx git add tools/cc_prompt_fix_config_save_doubleclick.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: disable Save button during widget config save to prevent DbContext concurrency error"
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
for f in src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
          tools/cc_prompt_fix_config_save_doubleclick.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
