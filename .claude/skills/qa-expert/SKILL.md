---
name: qa-expert
invocation: user
description: >
  QA and testing expert for the RTM View Shell project. Trigger this skill whenever:
  writing unit or integration tests, planning a test suite for a new feature,
  reviewing test coverage, generating test cases for a handler/command/query,
  finding gaps in existing tests, planning regression tests after a bug fix,
  writing tests for UserWidgetSettings, RTS grid lifecycle, auth flows,
  multi-tenancy isolation, permission enforcement, or any DB-backed feature.
  Also trigger on: "write tests", "test plan", "what should I test", "add tests",
  "check coverage", "find untested cases", "regression test", "тесты", "напиши тесты",
  "тест-план", "покрытие тестами".
  Always use alongside widget-planner and widget-creator for new widget work.
---

# QA Expert — RTM View Shell

Read this skill when planning or writing any test for this project.
It defines the test infrastructure, patterns, and mandatory coverage rules.

---

## 0. Test infrastructure

| Tool | Purpose |
|---|---|
| xUnit | Test framework |
| FluentAssertions | Readable assertions (`Should().Be(...)`) |
| NSubstitute | Mocking (`Substitute.For<IInterface>()`) |
| Testcontainers.PostgreSql | Real PostgreSQL in Docker for integration tests |
| `PostgresFixture` | Shared DB fixture — see `tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs` |

**Key fixture methods:**
- `postgres.CreateDbContext(tenantId)` — AppDbContext scoped to tenant
- `postgres.CreateDbContextFactory(tenantId)` — IDbContextFactory for handlers
- `postgres.TenantAId` / `postgres.TenantBId` — pre-seeded tenant GUIDs
- `postgres.UserAId` / `postgres.UserBId` — pre-seeded user GUIDs

**Collection:** always use `[Collection("Postgres")]` and inject `PostgresFixture`.

---

## 1. Test categories

### Unit tests (no DB, no I/O)
Location: `tests/CcDashboard.Tests.Unit/`
What: pure domain logic, validators, utility methods.
Pattern: no fixture, just `new Handler(mocked deps)`.

### Integration tests (real PostgreSQL via Testcontainers)
Location: `tests/CcDashboard.Tests.Security/` (subfolders by domain)
What: handlers, commands, queries, DB persistence, GQF isolation.
Requires: Docker running.
Pattern:
```csharp
[Collection("Postgres")]
public class MyFeatureTests(PostgresFixture postgres)
{
    [Fact]
    [Trait("Req", "FEAT-01")]
    public async Task MyHandler_HappyPath_SavesCorrectly()
    {
        // Arrange — create handler with real DbContextFactory + NSubstitute mocks
        var factory = postgres.CreateDbContextFactory(postgres.TenantAId);
        var currentUser = Substitute.For<ICurrentUserAccessor>();
        currentUser.UserId.Returns(postgres.UserAId);
        var handler = new MyCommandHandler(factory, currentUser, ...);

        // Act
        await handler.Handle(new MyCommand(...), CancellationToken.None);

        // Assert — verify in real DB
        await using var db = postgres.CreateDbContext(postgres.TenantAId);
        var row = await db.MyTable.FirstOrDefaultAsync(x => x.Id == ...);
        row.Should().NotBeNull();
        row!.Field.Should().Be(expectedValue);
    }
}
```

### Architecture tests
Location: `tests/CcDashboard.Tests.Architecture/`
What: dependency direction enforcement (no Infrastructure reference from Web except Program.cs).

---

## 2. Mandatory test cases for every new DB-backed feature

For every new entity + Get/Save/Delete handlers, write these tests in order:

| # | Test | Asserts |
|---|---|---|
| 01 | Get — returns null when row doesn't exist | Default empty state |
| 02 | Save → Get roundtrip | Data persists correctly |
| 03 | Save twice → upsert, no duplicate row | Unique constraint respected |
| 04 | Delete removes row | Row gone after delete |
| 05 | Delete is no-op when row doesn't exist | No exception thrown |
| 06 | Tenant isolation: TenantB cannot read TenantA data | GQF works |
| 07 | User isolation: UserB cannot read UserA data in same tenant | UserId filter works |
| 08 | Get returns null when UserId is null (unauthenticated) | Auth guard works |
| 09 | Two different entity IDs for same user → independent | WidgetId/EntityId filter |
| 10 | Same entity, two users → two independent rows | Per-user isolation |
| 11 | CreatedAt fixed on update, UpdatedAt changes | Timestamp audit |
| 12 | TenantId comes from ITenantContext, not client | Security: no tenant forgery |
| 13 | Full payload roundtrip: all fields present in result | No field truncation |
| 14 | Unicode/non-ASCII values preserved (Hebrew, Arabic) | Encoding correctness |
| 15 | UserB cannot delete UserA's data | Cross-user write isolation |
| 16 | Concurrent saves → no duplicate rows | Race condition / unique index |

**Note on JSONB:** PostgreSQL normalizes JSON with spaces after colons.
Always parse with `JsonDocument.Parse(result)` — never assert raw JSON string equality.

---

## 3. Mandatory test cases for MediatR handlers

### Command handlers (write operations)
- Happy path: correct data written to DB
- Invalid input: validator rejects, no DB write
- Unauthorized: AuthorizationBehavior throws ForbiddenException
- Wrong tenant: GQF returns empty result or 404

### Query handlers (read operations)
- Returns correct data for authorized user
- Returns empty/null for non-existent resource
- Tenant isolation: other tenant's resources not returned
- Role-based visibility: Viewer can't see Admin-only data

---

## 4. Security-specific test patterns

### Multi-tenancy isolation (ARCH-01)
```csharp
// 1. Save data for TenantA
// 2. Try to read with TenantB context
// 3. Result must be null/empty
```

### Authorization enforcement (CODE-03)
```csharp
// Test via WebApplicationFactory or direct handler with minimal role claims
// Verify ForbiddenException is thrown for insufficient role
```

### Brute force / rate limiting (BFP-01/02)
```csharp
// Covered in Tests.Security/BruteForce/ — see existing tests
```

---

## 5. Test naming convention

```
{Method}_{Scenario}_{ExpectedResult}
```

Examples:
- `Get_ReturnsNull_WhenNoSettingsExist`
- `Save_TwoDifferentWidgets_StoredIndependently`
- `Delete_UserBCannotDeleteUserASettings`

Use `[Trait("Req", "UWS-01")]` to link to requirement ID.

---

## 6. JSONB comparison pattern (PostgreSQL-specific)

**Never do this:**
```csharp
result.Should().Contain("\"chartType\":\"bar\""); // FAILS — JSONB adds spaces
```

**Always do this:**
```csharp
using var doc = System.Text.Json.JsonDocument.Parse(result!);
doc.RootElement.GetProperty("chartType").GetString().Should().Be("bar");
```

---

## 7. Running tests

```powershell
# All security + integration tests
dotnet test tests/CcDashboard.Tests.Security --logger "console;verbosity=minimal"

# Specific test class
dotnet test tests/CcDashboard.Tests.Security --filter "FullyQualifiedName~UserWidgetSettings"

# All tests in solution
dotnet test CcDashboard.sln
```

**Requires:** Docker Desktop running (for Testcontainers PostgreSQL).

---

## 8. Test plan template — new feature

When asked to plan tests for a new feature, output this table filled in:

| # | Test name | Category | Covers |
|---|---|---|---|
| 01 | Get_ReturnsNull_WhenNotFound | Integration | Empty state |
| 02 | Save_ThenGet_ReturnsData | Integration | Roundtrip |
| ... | ... | ... | ... |

Then generate the full test class following patterns in §2-3 above.

---

## 9. When to invoke this skill

| Situation | Action |
|---|---|
| New entity + handlers | Run §2 checklist — write all 16 base tests |
| New MediatR command/query | Run §3 — write handler tests |
| Bug fix | Write regression test that fails before fix, passes after |
| New widget (via widget-planner) | Generate test plan in Phase 4 before CC task |
| Code review / pre-push | Verify §2 checklist covered for changed handlers |
| CC task prompt | Include: `Read file: .claude/skills/qa-expert/SKILL.md` |

---

## 10. Reference test files

| Test file | What it covers |
|---|---|
| `Widgets/UserWidgetSettingsTests.cs` | §2 full 16-test suite — use as template |
| `Widgets/RtsGridLifecycleTests.cs` | RTS Grid CRUD + dual-write |
| `MultiTenancy/NgcIsolationTests.cs` | Tenant isolation patterns |
| `Authentication/JwtClaimsTests.cs` | JWT + cookie auth flows |
| `Authorization/PermissionGroupTests.cs` | RBAC enforcement |
