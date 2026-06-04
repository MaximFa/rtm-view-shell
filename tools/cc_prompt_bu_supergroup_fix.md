# Fix: BU/Supergroup save + Tenant column — UnitOfWork BackendEmulationDbContext

**Session name:** RTM — BU UnitOfWork Fix
**Files:**
- `src/CcDashboard.Infrastructure/Services/UnitOfWork.cs`
- `src/CcDashboard.Web/Components/Admin/Configuration/BusinessUnitsPage.razor`

---

## §0 — Session-resume integrity check

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
```

---

## Root cause — системная проблема всех NGC write-операций

`UnitOfWork` wraps только `AppDbContext.SaveChangesAsync()`.
Все 5 NGC repositories (`NgcSite`, `NgcBusinessUnit`, `NgcSupergroup`, `NgcQueue`, `NgcAgentGroup`)
используют `BackendEmulationDbContext` — **другой DbContext**.

Результат: SaveSite, SaveBU, DeleteBU, SaveSupergroup, DeleteSupergroup — все write-операции
через NGC repos **никогда не сохраняются** в БД.

---

## Bug 1 — Tenant column missing for Superadmin

**File:** `src/CcDashboard.Web/Components/Admin/Configuration/BusinessUnitsPage.razor`

Superadmin всегда должен видеть Tenant колонку.

В `<thead>` после `<th>@L["BU_Name"]</th>`:
```razor
@if (CurrentUser.Role == "Superadmin")
{
    <th>@L["PG_Tenant"]</th>
}
```

В `<tbody>` после `<td>@bu.BusinessUnitName</td>`:
```razor
@if (CurrentUser.Role == "Superadmin")
{
    var tenantName = Tenants.FirstOrDefault(t => t.Id == bu.TenantId)?.Name ?? bu.TenantId.ToString();
    <td><span class="badge bg-light text-dark border">@tenantName</span></td>
}
```

**Проверь:** если `BusinessUnitDto` не содержит `TenantId` — добавить в DTO
и в `GetBusinessUnitsQueryHandler`.

---

## Bug 2 — Fix UnitOfWork: добавить BackendEmulationDbContext

**File:** `src/CcDashboard.Infrastructure/Services/UnitOfWork.cs`

Текущий код:
```csharp
public class UnitOfWork(AppDbContext db) : IUnitOfWork
{
    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
```

**Исправление** — добавить `BackendEmulationDbContext`:
```csharp
public class UnitOfWork(AppDbContext db, BackendEmulationDbContext beDb) : IUnitOfWork
{
    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        var result = await db.SaveChangesAsync(ct);
        await beDb.SaveChangesAsync(ct);  // Save NGC repositories (Site, BU, Supergroup etc.)
        return result;
    }
}
```

**Почему это безопасно:** если `BackendEmulationDbContext` не имеет отслеживаемых изменений,
`SaveChangesAsync()` возвращает 0 (no-op). Существующие команды AppDbContext не затрагиваются.

**Проверить usings** — добавить если нужно:
```csharp
using CcDashboard.Infrastructure.Persistence;
```

---

## Build check

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
dotnet build CcDashboard.sln
```

0 errors.

---

## MANDATORY pre-commit check

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Infrastructure/Services/UnitOfWork.cs \
  src/CcDashboard.Web/Components/Admin/Configuration/BusinessUnitsPage.razor
```

---

## Git commit

```bash
git add \
  src/CcDashboard.Infrastructure/Services/UnitOfWork.cs \
  src/CcDashboard.Web/Components/Admin/Configuration/BusinessUnitsPage.razor

git commit -m "fix(infra): UnitOfWork saves BackendEmulationDbContext + BU Tenant column

Root cause: UnitOfWork only called AppDbContext.SaveChangesAsync().
All 5 NGC repositories (NgcSite, NgcBU, NgcSupergroup, NgcQueue, NgcAgentGroup)
use BackendEmulationDbContext — none of their write operations were persisted.

Fix: UnitOfWork now calls SaveChangesAsync on both AppDbContext and
BackendEmulationDbContext. If beDb has no tracked changes, it's a no-op.

Also: add Tenant column to Business Units list for Superadmin (always visible)."
```

---

## MANDATORY post-commit + re-sync

```bash
git status --short

for f in \
  src/CcDashboard.Infrastructure/Services/UnitOfWork.cs \
  src/CcDashboard.Web/Components/Admin/Configuration/BusinessUnitsPage.razor; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f"
done
sync
```
