# Fix: Tenant column for Sites and Supergroups pages (Superadmin)

**Session name:** RTM — Tenant Column Fix
**Files:**
- `src/CcDashboard.Contracts/DTOs/Configuration/ConfigurationDtos.cs`
- `src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs`
- `src/CcDashboard.Web/Components/Admin/Configuration/SitesPage.razor`
- `src/CcDashboard.Web/Components/Admin/Configuration/SupergroupsPage.razor`

---

## §0 — Session-resume integrity check

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
```

---

## Что делаем

SitesPage и SupergroupsPage имеют фильтр по тенанту для Superadmin,
но в таблице нет колонки Tenant. Superadmin не видит какому тенанту принадлежит каждая запись.

BusinessUnitsPage уже исправлен в предыдущем коммите (f3508ba).

---

## Шаг 1 — Добавить TenantId в DTO

**File:** `src/CcDashboard.Contracts/DTOs/Configuration/ConfigurationDtos.cs`

### SiteDto — добавить TenantId:
```csharp
// Было:
public record SiteDto(
    string SiteId,
    string? SiteName,
    string? Description,
    string? TimeZone,
    string? ClearTime);

// Стало:
public record SiteDto(
    string SiteId,
    Guid TenantId,
    string? SiteName,
    string? Description,
    string? TimeZone,
    string? ClearTime);
```

### SupergroupDto — добавить TenantId:
```csharp
// Было:
public record SupergroupDto(
    int SupergroupId,
    string? SupergroupName,
    string? Description,
    IReadOnlyList<string> AgentGroupIds);

// Стало:
public record SupergroupDto(
    int SupergroupId,
    Guid TenantId,
    string? SupergroupName,
    string? Description,
    IReadOnlyList<string> AgentGroupIds);
```

---

## Шаг 2 — Обновить mapping в Query handlers

**File:** `src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs`

### GetSitesQueryHandler — добавить TenantId в mapping:
Найти:
```csharp
return items.Select(s => new SiteDto(s.SiteId, s.SiteName, s.Description, s.TimeZone, s.ClearTime)).ToList();
```
Заменить на:
```csharp
return items.Select(s => new SiteDto(s.SiteId, s.TenantId, s.SiteName, s.Description, s.TimeZone, s.ClearTime)).ToList();
```

### GetSupergroupsQueryHandler — добавить TenantId в mapping:
Найти:
```csharp
return items.Select(sg => new SupergroupDto(
    sg.SupergroupId,
    sg.SupergroupName,
    sg.Description,
    sg.AgentGroupAssignments.Select(a => a.AgentgroupId ?? "").Where(id => !string.IsNullOrEmpty(id)).ToList())).ToList();
```
Заменить на:
```csharp
return items.Select(sg => new SupergroupDto(
    sg.SupergroupId,
    sg.TenantId,
    sg.SupergroupName,
    sg.Description,
    sg.AgentGroupAssignments.Select(a => a.AgentgroupId ?? "").Where(id => !string.IsNullOrEmpty(id)).ToList())).ToList();
```

---

## Шаг 3 — SitesPage: добавить Tenant колонку

**File:** `src/CcDashboard.Web/Components/Admin/Configuration/SitesPage.razor`

В `<thead>` после `<th>@L["Sites_SiteId"]</th>` добавить:
```razor
@if (CurrentUser.Role == "Superadmin")
{
    <th>@L["PG_Tenant"]</th>
}
```

В `<tbody>` в строке сайта после первой `<td>` (`@site.SiteId`) добавить:
```razor
@if (CurrentUser.Role == "Superadmin")
{
    var tenantName = Tenants.FirstOrDefault(t => t.Id == site.TenantId)?.Name ?? site.TenantId.ToString();
    <td><span class="badge bg-light text-dark border small">@tenantName</span></td>
}
```

---

## Шаг 4 — SupergroupsPage: добавить Tenant колонку

**File:** `src/CcDashboard.Web/Components/Admin/Configuration/SupergroupsPage.razor`

В `<thead>` после `<th>@L["SG_Name"]</th>` добавить:
```razor
@if (CurrentUser.Role == "Superadmin")
{
    <th>@L["PG_Tenant"]</th>
}
```

В `<tbody>` в строке supergroup после первой `<td>` (`@sg.SupergroupName`) добавить:
```razor
@if (CurrentUser.Role == "Superadmin")
{
    var tenantName = Tenants.FirstOrDefault(t => t.Id == sg.TenantId)?.Name ?? sg.TenantId.ToString();
    <td><span class="badge bg-light text-dark border small">@tenantName</span></td>
}
```

---

## Шаг 5 — Build check

```bash
dotnet build CcDashboard.sln
```

0 errors. Если появятся ошибки компиляции из-за изменения SiteDto/SupergroupDto —
найти все места где они создаются и добавить TenantId параметр.

---

## MANDATORY pre-commit check

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Contracts/DTOs/Configuration/ConfigurationDtos.cs \
  src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs \
  src/CcDashboard.Web/Components/Admin/Configuration/SitesPage.razor \
  src/CcDashboard.Web/Components/Admin/Configuration/SupergroupsPage.razor
```

---

## Git commit

```bash
git add \
  src/CcDashboard.Contracts/DTOs/Configuration/ConfigurationDtos.cs \
  src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs \
  src/CcDashboard.Web/Components/Admin/Configuration/SitesPage.razor \
  src/CcDashboard.Web/Components/Admin/Configuration/SupergroupsPage.razor

git commit -m "fix(admin): add Tenant column to Sites and Supergroups pages for Superadmin

- SiteDto: add TenantId field
- SupergroupDto: add TenantId field
- GetSitesQueryHandler/GetSupergroupsQueryHandler: include TenantId in mapping
- SitesPage/SupergroupsPage: show Tenant badge column when Superadmin"
```

---

## MANDATORY post-commit + re-sync

```bash
git status --short

for f in \
  src/CcDashboard.Contracts/DTOs/Configuration/ConfigurationDtos.cs \
  src/CcDashboard.Application/Queries/Configuration/ConfigurationQueries.cs \
  src/CcDashboard.Web/Components/Admin/Configuration/SitesPage.razor \
  src/CcDashboard.Web/Components/Admin/Configuration/SupergroupsPage.razor; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f"
done
sync
```
