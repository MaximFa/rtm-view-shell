# WfmServingStateGroups: an empty list must be saved as empty

Target file: `src/CcDashboard.Application/Commands/TenantSettings/UpdateTenantSettingsCommand.cs`
Scope: this one field. Everything else in the handler is out of this run.

## Before (line 43)

```csharp
settings.WfmServingStateGroups = (r.WfmServingStateGroups is { Count: > 0 }) ? r.WfmServingStateGroups.ToArray() : settings.WfmServingStateGroups;
```

`Count: > 0` collapses two different inputs into one branch:
- `null` — the caller did not send the field. Keeping the stored value is correct.
- `[]` — the caller sent "no groups". Keeping the stored value is wrong: the operator's change is
  silently discarded and the page reloads showing the old groups, with nothing in the log.

## After

```csharp
// null = field not sent -> keep stored value; [] = sent empty -> store empty.
// Collapsing the two (Count: > 0) silently discarded "no groups at all", which is a legitimate
// setting: it means "not configured", and WfmRealtimeLoop.cs:99 already tolerates it
// (`settings.WfmServingStateGroups ?? Array.Empty<string>()`).
settings.WfmServingStateGroups = r.WfmServingStateGroups?.ToArray() ?? settings.WfmServingStateGroups;
```

## Measured, not assumed

- DTO type is `List<string>?` — `Contracts/DTOs/TenantSettings/TenantSettingsDto.cs:43` — so `null`
  is expressible and the two cases really are distinguishable.
- The UI never sends `null`: `Web/Components/Admin/TenantsPage.razor:934` initialises
  `EditWfmServingStateGroups = new()` and `:1119` passes it unconditionally. Clearing every checkbox
  therefore produces `[]`, which is exactly the input the old line threw away. This answers the
  question that was going to be put to shell — no need to ask it.
- The consumer already handles empty: `Infrastructure/Wfm/WfmRealtimeLoop.cs:99`. So storing `[]`
  yields an honest "not configured", not an exception.
- Survey of the same shape across `src/`: `Count: > 0` occurs **7** times, not once. (My first
  predicate said "expected 1" and measured 7 — a false expectation, recorded here rather than
  quietly corrected.) The other six are a different semantic and are correctly written:
  `HistoricalReports/ReportScope.cs:28,42` and `ReportWidgetConfig.cs:58` treat empty as "no filter /
  take the default", and `ScreenEditorPage.razor:4549,4559` and `AgentGridWidget.razor:623` as
  "nothing configured". None of them discards a value the user just saved. Line 43 is the only place
  where empty means "silently keep the previous stored setting", which is why it is the only line
  changed. Other list fields on this handler go through `SerializeList` (:55-59), which maps both
  `null` and `[]` to `null` — one storage slot for both, a deliberate different semantic, not touched.

## Named, NOT fixed in this run

- `UpdateTenantSettingsCommand.cs:22` — `cmd.TenantId ?? currentUser.TenantId!.Value`: same pair of
  defects already reported for `GetTenantStatusGroupsQuery` (explicit foreign TenantId with no rights
  check; NRE when the user has no tenant). Third instance of that construct, after
  `GetTenantSettingsQuery.cs:20`.
- `TenantSettings.cs:34` and `TenantsPage.razor:1041` — the twin hard-coded defaults
  `{ Available, On Phone, Paperwork }`. In the v3 tree both are still present (`TenantSettings.cs`
  blob a23ab8637e662e2bb60b42f4f2859cbd66c409e4). shell reports having replaced the domain default
  with `Array.Empty<string>()` in v4, blob 0db31d1b — I cannot confirm that by eye: this session's
  bridge sees only the v3 working tree, the v4 tree is not mounted here. Stated as unverified, not
  as done.
