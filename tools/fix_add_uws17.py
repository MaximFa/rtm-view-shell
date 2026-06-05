#!/usr/bin/env python3
"""Add UWS-17 cross-tenant delete isolation test."""
import os

path = r"D:\Claude\Projects\RTM View Shell\tests\CcDashboard.Tests.Security\Widgets\UserWidgetSettingsTests.cs"

new_test = '''
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
'''

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Insert before the final closing brace
content = content.rstrip()
if content.endswith("}"):
    content = content[:-1] + new_test + "}\n"

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Added UWS-17 to: {path}")

# Verify
with open(path, "r", encoding="utf-8") as f:
    verify = f.read()

count = verify.count("[Fact]")
print(f"Total [Fact] count: {count}")
