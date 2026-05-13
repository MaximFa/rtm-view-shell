# Task: Add "Filters" tab to widget editor modal

## Context

File: `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`
File: `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`

The widget editor modal already has tabs: General, Appearance, Thresholds, Columns.
The Thresholds tab (around line 372) and its implementation are the reference pattern to follow.

The AgentGridWidget already has per-column interactive filters (class `ColumnFilter`, method
`MatchesFilter`, `GetOperatorsForMetric` logic). The new Filters tab adds a **saved,
persistent** row filter that is stored in `WidgetConfig` and applied on every render — before
the interactive column filters.

Columns in the table are **dynamic** — defined by `ConfigAgentColumnDefs` (List of
`AgentGridColumnDef` with `Name` and `MetricId` fields). The column dropdown in each filter
rule must be populated from this list.

---

## Step 1 — Add `TableFilterRule` class

In `ScreenEditorPage.razor`, alongside the existing `AgentGridColumnDef` and `ThresholdRule`
classes, add a new `TableFilterRule` class with four string properties:
- `MetricId` — references `AgentGridColumnDef.MetricId`
- `Operator` — same MatchType strings already used in `ColumnFilter` (contains, equal,
  greater, etc.)
- `Value` — the filter value as text
- `Connector` — `"AND"` or `"OR"`, defaults to `"AND"`. Represents the logical connector
  that precedes this rule (unused on the first rule).

---

## Step 2 — Extend `WidgetConfig`

Add `List<TableFilterRule>? TableFilters` property to the `WidgetConfig` class, alongside
the existing `ColumnThresholds` property.

---

## Step 3 — Editor state and lifecycle in `ScreenEditorPage.razor`

Add a `List<TableFilterRule> ConfigTableFilters` private field, initialised to empty list.

In `OpenWidgetConfig`: populate `ConfigTableFilters` from `widget.Config.TableFilters` (deep
copy each rule), defaulting to empty list if null. Follow the same pattern as
`ConfigColumnThresholds` loading.

In `SaveWidgetConfig`: write `ConfigTableFilters` back to `config.TableFilters`. Only include
rules where `MetricId` is not empty. Set to null if no rules remain.

In the config reset block (where `ConfigColumnThresholds = new()` is set): also reset
`ConfigTableFilters = new()`.

Add two helper methods:
- `AddTableFilterRule()` — appends a new `TableFilterRule` with the first available
  `MetricId` from `ConfigAgentColumnDefs`, default operator based on whether that metric is
  numeric (use the same `IsNumericColumn` / `NumericColumns` logic already in the file),
  empty value, connector `"AND"`.
- `RemoveTableFilterRule(int index)` — removes the rule at the given index.

Add a helper method `GetOperatorsForMetric(string metricId)` that returns the appropriate
operator options based on whether the metric is numeric. For numeric metrics: greater,
greaterequal, less, lessequal, equal, notequal, empty, notempty. For text metrics: contains,
notcontains, equal, notequal, startswith, endswith, empty, notempty. Use the same
`NumericColumns` / `IsNumericColumn` logic already present.

---

## Step 4 — Add tab button

In the tab navigation `<ul class="nav nav-tabs">` (around line 193), add a "Filters" tab
button after the existing Thresholds tab button. Use the same pattern as the other tab
buttons, with `ConfigActiveTab == "filters"` condition.

---

## Step 5 — Add tab content

After the Thresholds tab content block and before the Columns tab block, add the Filters tab
content block (`@if (ConfigActiveTab == "filters")`).

The tab content layout:
- Header row: label "Row filter — applied before display" on the left, "Add condition"
  button (btn-outline-primary btn-sm) on the right that calls `AddTableFilterRule()`.
- If `ConfigTableFilters` is empty: show a muted hint text.
- For each rule in `ConfigTableFilters` (use index loop, capture index in local variable):
  - If not the first rule: show a centered AND/OR `<select>` bound to `rule.Connector`.
  - A flex row containing:
    1. Column `<select>` — options from `ConfigAgentColumnDefs` (value = MetricId, label =
       Name). On change: update `MetricId` and reset `Operator` to the appropriate default
       for the new metric type.
    2. Operator `<select>` — options from `GetOperatorsForMetric(rule.MetricId)`. On change:
       update `rule.Operator`.
    3. Value `<input type="text">` — hidden when operator is `"empty"` or `"notempty"`.
       On change: update `rule.Value`.
    4. Remove button (btn-outline-danger btn-sm, trash icon) that calls
       `RemoveTableFilterRule(idx)`.

---

## Step 6 — Apply saved filter in `AgentGridWidget.razor`

In the `AllFilteredAgents` computed property, after the existing `_columnFilters` loop and
before the sorting block, add evaluation of `Config.TableFilters`.

Skip if `Config.TableFilters` is null or empty, or if all rules have empty `MetricId`.

Evaluate rules sequentially:
- First rule result = initial boolean value.
- For each subsequent rule: combine with previous result using the rule's `Connector`
  (`"AND"` → `&&`, `"OR"` → `||`).

To evaluate a single `TableFilterRule` against an `AgentStatusDto`: convert `MetricId` to
column key using the existing `MetricIdToColumnKey` method, then reuse the existing
`MatchesFilter` logic by constructing a temporary `ColumnFilter` with `Mode = "value"`,
`MatchType = rule.Operator`, `TextValue = rule.Value`.

---

## Step 7 — Verify

Run `dotnet build CcDashboard.sln` — must compile with no errors.

Manual check: open AgentGrid widget editor → Filters tab → add two conditions with AND/OR →
save → verify the filter is applied in the viewer.
