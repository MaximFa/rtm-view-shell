# Task: Fix &nbsp; rendering in AgentGridWidget

## Problem

RTM Service uses `"&nbsp;"` as a placeholder for empty/no-value fields
(17+ places in UserManager.cs). This was designed for the original HTML-based
RTMView client where `&nbsp;` rendered as an invisible non-breaking space.

In our Blazor AgentGridWidget, cell values are rendered as plain text (`@cellValue`),
so `&nbsp;` appears literally as the string `&nbsp;` in the STATE column and
any other column that has no value.

**Observed behavior:**
- Agent with no current state → STATE shows `&nbsp;`
- Agent after status change → STATE shows correct value (e.g. `לא זמין`)
- Agent logs out / returns to no-state → STATE shows `&nbsp;` again

## Fix

In `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`,
find the `GetCellDisplay` method (or wherever the raw value from AgentSnapshot
is returned before rendering).

Add a single check: if the value is `"&nbsp;"`, return `string.Empty`.

```csharp
private string GetCellDisplay(AgentRow row, string metricId)
{
    // ... existing logic to get value ...
    var value = // ... whatever the current logic returns;

    // RTM Service uses &nbsp; as placeholder for empty fields (legacy HTML client).
    // Render as empty string instead of literal "&nbsp;".
    if (value == "&nbsp;") return string.Empty;

    return value;
}
```

Also apply the same check to any other place where AgentSnapshot field values
are rendered directly (e.g. avatar initials, threshold comparisons).

**Important:** Do NOT use `HtmlDecode` — that would turn `&nbsp;` into a
non-breaking space character (\u00A0) which could break threshold text matching
(e.g. threshold rule `textMatch: "Available"` would never match `\u00A0Available`).
Simple equality check `== "&nbsp;"` is correct.

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
# No build errors

grep -n '"&nbsp;"' src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Should show the new guard check
```

## Commit message

```
fix: render RTM &nbsp; placeholder as empty string in AgentGridWidget

RTM Service sends "&nbsp;" for fields with no value (legacy HTML client pattern).
Blazor renders it as literal text. Fix: treat "&nbsp;" as empty string.
Do not use HtmlDecode — would produce \u00A0 and break threshold text matching.
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```
