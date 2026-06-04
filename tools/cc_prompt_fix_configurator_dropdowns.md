# Task: Fix dropdown alignment — position under/above input field

## Problem

Current implementation uses `e.ClientX - 10` and `e.ClientY + 8` for
dropdown position — this puts it at the cursor, not aligned with the input field.

## Fix — use OffsetX/OffsetY to find input bounds

`MouseEventArgs` provides `OffsetX`/`OffsetY` — position of click WITHIN the
target element. Using these we can compute the element's left edge and bottom
without any JS interop.

Update all three Open methods in `ScreenEditorPage.razor`:

```csharp
private void OpenMetricDropdown(string colId, MouseEventArgs e)
{
    _activeMetricDropdown = colId;
    _metricSearchText = "";
    _dropdownRects[$"metric-{colId}"] = CalcDropdownRect(e);
}

private void OpenQueueRowBuDropdown(int rowIdx, MouseEventArgs e)
{
    _queueRowBuDropdownOpenFor = rowIdx;
    _queueRowBuSearchText = "";
    _dropdownRects[$"queuerowbu-{rowIdx}"] = CalcDropdownRect(e);
}

private void OpenQueueMetricDropdown(string colId, MouseEventArgs e)
{
    _activeQueueMetricDropdown = colId;
    _queueMetricSearchText = "";
    _dropdownRects[$"queuemetric-{colId}"] = CalcDropdownRect(e);
}

/// Calculates dropdown position aligned to the clicked input/button.
/// OffsetX/OffsetY = position within the target element.
/// So (ClientX - OffsetX) = left edge, (ClientY - OffsetY) = top edge.
private static DropdownRect CalcDropdownRect(MouseEventArgs e)
{
    const double inputHeight = 34;  // Bootstrap form-control height
    const double dropdownWidth = 280;
    const double maxDropdownH = 210;
    const double viewportH = 700;   // conservative modal viewport height

    var left = e.ClientX - e.OffsetX;
    var top  = e.ClientY - e.OffsetY;   // top of the input element
    var bottom = top + inputHeight;

    // Flip upward if not enough space below
    var spaceBelow = viewportH - bottom;
    var openUpward = spaceBelow < maxDropdownH && top > maxDropdownH;
    var dropTop = openUpward ? top - maxDropdownH : bottom + 2;

    return new DropdownRect(dropTop, left, dropdownWidth, openUpward);
}
```

Note: `viewportH = 700` is the modal-body height from the existing style.
If the modal can be resized, use a larger value (e.g. `window.innerHeight`).

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After deploy: dropdown appears directly below (or above) the input field,
left-aligned with it. No JS interop needed.

## Git push
Do NOT run `git push` automatically. Commit only.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
fix: align dropdown to input field using MouseEventArgs OffsetX/OffsetY

Dropdown was appearing at cursor position.
OffsetX/OffsetY gives element-relative click coords.
(ClientX - OffsetX) = input left edge, (ClientY - OffsetY + height) = bottom.
No JS interop needed.
```
