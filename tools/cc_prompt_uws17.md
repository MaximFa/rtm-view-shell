# CC Task: Add UWS-17 — TenantB cannot delete TenantA settings

## Mandatory — read before starting
Read file: .claude/skills/qa-expert/SKILL.md

## Git push
Do NOT run `git push`.

## SCOPE: ONE FILE
`tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs`

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

## Add test UWS-17 to existing class

Append to `UserWidgetSettingsTests.cs` (after UWS-16):

```csharp
// ── 17. TenantB cannot delete TenantA settings (cross-tenant delete) ──────
[Fact]
[Trait("Req", "UWS-17")]
public async Task Delete_TenantBCannotDeleteTenantASettings()
{
    var widgetId = Uuid.NewSequential();

    // TenantA saves settings
    var (getA, saveA, _)    = CreateHandlers(postgres.TenantAId, postgres.UserAId);
    var (_, _, deleteBtenant) = CreateHandlers(postgres.TenantBId, postgres.UserAId); // same UserId, different tenant

    await saveA.Handle(
        new SaveUserWidgetSettingsCommand(widgetId, """{"owner":"tenantA"}"""),
        CancellationToken.None);

    // TenantB (same UserId) tries to delete TenantA's settings
    await deleteBtenant.Handle(
        new DeleteUserWidgetSettingsCommand(widgetId),
        CancellationToken.None);

    // TenantA's settings must still exist
    var result = await getA.Handle(
        new GetUserWidgetSettingsQuery(widgetId),
        CancellationToken.None);

    result.Should().NotBeNull("GQF must prevent TenantB from deleting TenantA settings");
}
```

---

## Run all 17 tests

```powershell
cd "D:\Claude\Projects\RTM View Shell"
dotnet test tests/CcDashboard.Tests.Security `
  --filter "FullyQualifiedName~UserWidgetSettings" `
  --logger "console;verbosity=detailed" 2>&1
```

All 17 must pass. If UWS-17 fails — this is a real security bug in the handler.
Report full output. DO NOT commit if any test fails.

---

## Commit (only if 17/17 pass)

```bash
bash tools/pre-commit-check.sh tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "test: UWS-17 cross-tenant delete isolation (QA gap G-03)"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

## Re-sync

```bash
git show HEAD:"tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs" \
  > "tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs"
sync
```
