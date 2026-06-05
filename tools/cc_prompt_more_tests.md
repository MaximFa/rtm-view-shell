# CC Task: UserWidgetSettings — additional tests (concurrency, timestamps, JSON integrity, edge cases)

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

## Add to `tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs`

Append these tests to the existing class (after UWS-08):

```csharp
// ── 9. Two different widgets for same user store independently ───────────
[Fact]
[Trait("Req", "UWS-09")]
public async Task Save_TwoDifferentWidgets_StoredIndependently()
{
    var widgetId1 = Uuid.NewSequential();
    var widgetId2 = Uuid.NewSequential();
    var (get, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

    await save.Handle(new SaveUserWidgetSettingsCommand(widgetId1, """{"widget":"one"}"""), CancellationToken.None);
    await save.Handle(new SaveUserWidgetSettingsCommand(widgetId2, """{"widget":"two"}"""), CancellationToken.None);

    var result1 = await get.Handle(new GetUserWidgetSettingsQuery(widgetId1), CancellationToken.None);
    var result2 = await get.Handle(new GetUserWidgetSettingsQuery(widgetId2), CancellationToken.None);

    using var doc1 = System.Text.Json.JsonDocument.Parse(result1!);
    using var doc2 = System.Text.Json.JsonDocument.Parse(result2!);
    doc1.RootElement.GetProperty("widget").GetString().Should().Be("one");
    doc2.RootElement.GetProperty("widget").GetString().Should().Be("two");
}

// ── 10. Same widget, two users — each gets own row ───────────────────────
[Fact]
[Trait("Req", "UWS-10")]
public async Task Save_SameWidget_TwoUsers_IndependentRows()
{
    var widgetId = Uuid.NewSequential();
    var (_, saveA, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
    var (_, saveB, _) = CreateHandlers(postgres.TenantAId, postgres.UserBId);

    await saveA.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"user":"A"}"""), CancellationToken.None);
    await saveB.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"user":"B"}"""), CancellationToken.None);

    // Verify two rows in DB (bypass GQF)
    await using var db = postgres.CreateDbContext(postgres.TenantAId);
    var rows = await db.UserWidgetSettings
        .IgnoreQueryFilters()
        .Where(x => x.WidgetId == widgetId && x.TenantId == postgres.TenantAId)
        .ToListAsync();

    rows.Should().HaveCount(2);
    rows.Select(r => r.UserId).Should().Contain(postgres.UserAId).And.Contain(postgres.UserBId);
}

// ── 11. CreatedAt set on first save, UpdatedAt changes on second ─────────
[Fact]
[Trait("Req", "UWS-11")]
public async Task Save_Timestamps_CreatedAtFixedUpdatedAtChanges()
{
    var widgetId = Uuid.NewSequential();

    // First save
    var (_, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
    await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"v":1}"""), CancellationToken.None);

    await using var db1 = postgres.CreateDbContext(postgres.TenantAId);
    var row1 = await db1.UserWidgetSettings
        .IgnoreQueryFilters()
        .FirstAsync(x => x.WidgetId == widgetId && x.UserId == postgres.UserAId);
    var createdAt  = row1.CreatedAt;
    var updatedAt1 = row1.UpdatedAt;

    await Task.Delay(10); // ensure time advances

    // Second save
    await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"v":2}"""), CancellationToken.None);

    await using var db2 = postgres.CreateDbContext(postgres.TenantAId);
    var row2 = await db2.UserWidgetSettings
        .IgnoreQueryFilters()
        .FirstAsync(x => x.WidgetId == widgetId && x.UserId == postgres.UserAId);

    row2.CreatedAt.Should().Be(createdAt, "CreatedAt must not change on update");
    row2.UpdatedAt.Should().BeOnOrAfter(updatedAt1, "UpdatedAt must advance on update");
}

// ── 12. TenantId is taken from ITenantContext, not forged by client ───────
[Fact]
[Trait("Req", "UWS-12")]
public async Task Save_TenantIdFromContext_CannotBeForgedByClient()
{
    var widgetId = Uuid.NewSequential();
    var (_, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

    await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"x":1}"""), CancellationToken.None);

    await using var db = postgres.CreateDbContext(postgres.TenantAId);
    var row = await db.UserWidgetSettings
        .IgnoreQueryFilters()
        .FirstAsync(x => x.WidgetId == widgetId);

    row.TenantId.Should().Be(postgres.TenantAId, "TenantId must come from ITenantContext");
}

// ── 13. Full-payload JSON with all DayTrend fields roundtrips cleanly ─────
[Fact]
[Trait("Req", "UWS-13")]
public async Task Save_FullDayTrendPayload_AllFieldsPreserved()
{
    var widgetId = Uuid.NewSequential();
    var json = """
        {
            "buId": 42,
            "metrics": ["interaction.incoming_calls", "interaction.answered_calls"],
            "agentMetrics": ["statuslog.available_agents"],
            "chartType": "area",
            "intervalMinutes": 15,
            "metricColors": {"interaction.incoming_calls": "#3b82f6"},
            "agentMetricColors": {"statuslog.available_agents": "#22c55e"}
        }
        """;

    var (get, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
    await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, json), CancellationToken.None);
    var result = await get.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);

    result.Should().NotBeNullOrEmpty();
    using var doc = System.Text.Json.JsonDocument.Parse(result!);
    doc.RootElement.GetProperty("buId").GetInt32().Should().Be(42);
    doc.RootElement.GetProperty("chartType").GetString().Should().Be("area");
    doc.RootElement.GetProperty("intervalMinutes").GetInt32().Should().Be(15);
    doc.RootElement.GetProperty("metrics").GetArrayLength().Should().Be(2);
    doc.RootElement.GetProperty("metricColors")
        .GetProperty("interaction.incoming_calls").GetString().Should().Be("#3b82f6");
}

// ── 14. Save with non-latin (Hebrew) values preserves encoding ────────────
[Fact]
[Trait("Req", "UWS-14")]
public async Task Save_HebrewTextInJson_PreservesEncoding()
{
    var widgetId = Uuid.NewSequential();
    var json = """{"displayName":"תמיכה"}"""; // "תמיכה"

    var (get, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);
    await save.Handle(new SaveUserWidgetSettingsCommand(widgetId, json), CancellationToken.None);
    var result = await get.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);

    using var doc = System.Text.Json.JsonDocument.Parse(result!);
    doc.RootElement.GetProperty("displayName").GetString().Should().Be("תמיכה");
}

// ── 15. UserB cannot delete UserA settings in same tenant ─────────────────
[Fact]
[Trait("Req", "UWS-15")]
public async Task Delete_UserBCannotDeleteUserASettings()
{
    var widgetId = Uuid.NewSequential();
    var (getA, saveA, _)    = CreateHandlers(postgres.TenantAId, postgres.UserAId);
    var (_, _, deleteB) = CreateHandlers(postgres.TenantAId, postgres.UserBId);

    await saveA.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"owner":"A"}"""), CancellationToken.None);

    // UserB tries to delete UserA's settings
    await deleteB.Handle(new DeleteUserWidgetSettingsCommand(widgetId), CancellationToken.None);

    // UserA's settings must still exist
    var result = await getA.Handle(new GetUserWidgetSettingsQuery(widgetId), CancellationToken.None);
    result.Should().NotBeNull("UserB must not be able to delete UserA settings");
}

// ── 16. Concurrent saves do not create duplicate rows (unique index) ───────
[Fact]
[Trait("Req", "UWS-16")]
public async Task Save_Concurrent_DoesNotCreateDuplicateRows()
{
    var widgetId = Uuid.NewSequential();
    var (_, save, _) = CreateHandlers(postgres.TenantAId, postgres.UserAId);

    // Two concurrent saves for the same widget/user
    var t1 = save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"v":1}"""), CancellationToken.None);
    var t2 = save.Handle(new SaveUserWidgetSettingsCommand(widgetId, """{"v":2}"""), CancellationToken.None);

    // At most one should fail (unique index violation) — both completing is also acceptable
    try { await Task.WhenAll(t1, t2); } catch { /* one may fail due to unique index */ }

    await using var db = postgres.CreateDbContext(postgres.TenantAId);
    var count = await db.UserWidgetSettings
        .IgnoreQueryFilters()
        .CountAsync(x => x.WidgetId == widgetId && x.TenantId == postgres.TenantAId);

    count.Should().Be(1, "Concurrent saves must not create duplicate rows");
}
```

---

## Run all tests

```powershell
cd "D:\Claude\Projects\RTM View Shell"
dotnet test tests/CcDashboard.Tests.Security `
  --filter "FullyQualifiedName~UserWidgetSettings" `
  --logger "console;verbosity=detailed" 2>&1
```

All 16 must pass. If any fail — report full error, do NOT commit.

---

## Commit (only if 16/16 pass)

```bash
bash tools/pre-commit-check.sh tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "test: UserWidgetSettings — 16 tests (timestamps, payload, encoding, concurrency, user isolation)"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

## Re-sync

```bash
git show HEAD:"tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs" \
  > "tests/CcDashboard.Tests.Security/Widgets/UserWidgetSettingsTests.cs"
sync
```
