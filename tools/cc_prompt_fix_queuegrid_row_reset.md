# Task: Fix QueueGrid losing display values on parameter change (DarkMode toggle)

## Root cause

In `QueueGridWidget.razor`, `ApplyConfig()` is called on every `OnParametersSetAsync`
(including DarkMode toggle). It contains:

```csharp
// Initialize rows from row definitions
_rows = _rowDefs.Select(r => new QueueRowData
{
    RowId = r.Id,
    QueueName = r.QueueName ?? r.BusinessUnitName ?? ""
}).ToList();
```

`_rows` is fully recreated with empty `DisplayValue` for all columns.
Data shows as "-" until the next RTM push arrives.

AgentGrid is not affected because agent data is stored in `RtmRelayService`
snapshot and delivered immediately on re-subscribe.

## Fix

In `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor`,
find the rows initialization block inside `ApplyConfig()` and replace with:

```csharp
// Rebuild rows — preserve existing display values if row structure unchanged
var newRows = _rowDefs.Select(r => new QueueRowData
{
    RowId = r.Id,
    QueueName = r.QueueName ?? r.BusinessUnitName ?? ""
}).ToList();

// Carry over display values from existing rows (same RowId = same data)
// This prevents flicker when DarkMode/other params change without row changes
if (_rows.Count > 0)
{
    var existingById = _rows.ToDictionary(r => r.RowId);
    foreach (var row in newRows)
    {
        if (existingById.TryGetValue(row.RowId, out var existing))
        {
            foreach (var kv in existing.ColumnValues)
                row.ColumnValues[kv.Key] = kv.Value;
        }
    }
}
_rows = newRows;
```

**Note:** Check the actual property name for column display values in `QueueRowData`.
It may be `ColumnValues`, `Values`, or `DisplayValues` — look at how values are set
in the RTM update handler and use the same field name.

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After deploy: toggle DarkMode on dashboard with QueueGrid —
existing values should remain visible, not reset to "-".

## Commit message

```
fix: preserve QueueGrid display values on ApplyConfig (DarkMode toggle)

_rows was fully recreated in ApplyConfig() called on every parameter change,
including DarkMode toggle. New rows had no display values -> showed "-".
Fix: carry over existing ColumnValues by RowId when rebuilding rows.
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```
