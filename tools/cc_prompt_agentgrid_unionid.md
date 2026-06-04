# CC Task: Fix AgentGrid wrong UnionId — use BusinessUnit.Id, not RtsUserGridId

## Root Cause

AgentGridWidget.ApplyConfig() reads Config.RtsUserGridId (= 7 = RTSUserGrid_Grid.GridId row ID)
and uses it as the Union ID for RTM Service subscription.

But the correct Union ID = Config.BusinessUnit = "74" (BU.Id = UnionId in RTM Service).
These are completely different numbers:
- RtsUserGridId = 7  → row ID in RTSUserGrid_Grid table (NOT meaningful for RTM Service)
- BusinessUnit = "74" → BU.Id = Union ID in RTM Service (correct ID for SubscribeUnionAsync)

ConfigJson already has "businessUnit": "74" saved correctly. No save-side changes needed.

## File to modify

src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor

### Change: ApplyConfig() — use BusinessUnit.Id as union ID

Find in ApplyConfig() (around the section setting _rtsGridId):
```csharp
            if (Config.RtsUserGridId is > 0)
                _rtsGridId = Config.RtsUserGridId.Value;
```

Replace with:
```csharp
            // Union ID for RTM Service = BusinessUnit.Id (BU.Id = Union ID in Engine.UnionList).
            // RtsUserGridId is the RTSUserGrid_Grid row ID, NOT the union ID — do not use it here.
            if (!string.IsNullOrEmpty(Config.BusinessUnit) &&
                int.TryParse(Config.BusinessUnit, out var buId) && buId > 0)
                _rtsGridId = buId;
            else if (Config.RtsUserGridId is > 0)
                _rtsGridId = Config.RtsUserGridId.Value; // fallback: legacy configs without BusinessUnit
```

## Build and commit

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj -c Release
```

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
git add src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
git commit -m "fix: AgentGrid use BusinessUnit.Id as UnionId (not RTSUserGrid_Grid row ID)

Config.RtsUserGridId = 7 is the RTSUserGrid_Grid.GridId (a table row ID).
Config.BusinessUnit = '74' is the BU.Id = actual Union ID in RTM Service.
Widget was subscribing to union 7 ('5004' supergroup) instead of union 74 (לפני_רכישה).
"
```

```bash
git show HEAD:src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor > \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
echo "Re-synced"
sync
```
