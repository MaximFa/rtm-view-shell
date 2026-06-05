# CC Task: Fix 2 failing UserWidgetSettings tests — JSONB space normalization

## Git push
Do NOT run `git push`.

---

## Step 0 — Integrity check

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        git show HEAD:"$f" > "$f" && echo "Restored: $f"
    fi
done && sync
```

---

## Problem

PostgreSQL JSONB stores `{"chartType":"bar"}` as `{"chartType": "bar"}` (space after colon).
Tests UWS-02 and UWS-03 assert compact form `"chartType":"bar"` — this fails.

## Fix — `tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs`

### Test UWS-02: Save_ThenGet_ReturnsPersistedJson

Find:
```csharp
result.Should().Contain("\"chartType\":\"bar\"");
```
Replace with (parse JSON properly):
```csharp
using var doc = System.Text.Json.JsonDocument.Parse(result!);
doc.RootElement.GetProperty("chartType").GetString().Should().Be("bar");
doc.RootElement.GetProperty("intervalMinutes").GetInt32().Should().Be(30);
```

### Test UWS-03: Save_Twice_UpdatesExistingRow_NoDuplicate

Find:
```csharp
rows[0].SettingsJson.Should().Contain("\"chartType\":\"bar\"");
```
Replace with:
```csharp
using var doc = System.Text.Json.JsonDocument.Parse(rows[0].SettingsJson);
doc.RootElement.GetProperty("chartType").GetString().Should().Be("bar");
```

---

## Run tests after fix

```powershell
cd "D:\Claude\Projects\RTM View Shell"
dotnet test tests/CcDashboard.Tests.Security `
  --filter "FullyQualifiedName~UserWidgetSettings" `
  --logger "console;verbosity=detailed" 2>&1
```

All 8 must pass. If not — report failures, do NOT commit.

---

## Commit (only if 8/8 pass)

```bash
bash tools/pre-commit-check.sh tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: UserWidgetSettings tests — use JsonDocument.Parse for JSONB comparison"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

## Re-sync

```bash
git show HEAD:"tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs" \
  > "tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs"
sync
```
