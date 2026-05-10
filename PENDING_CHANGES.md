# Pending Changes for Superadmin Cross-Tenant Dashboard Editing

These changes were rolled back because drag-drop stopped working. Re-apply when root cause is found.

## 1. ScreenEditorPage.razor - Load BusinessUnits from dashboard's tenant

```csharp
// OLD (current):
BusinessUnits = (await Mediator.Send(new GetBusinessUnitsQuery(), _cts.Token)).ToList();

// NEW (rolled back):
Guid? dashboardTenantId = Dashboard?.TenantId;
BusinessUnits = (await Mediator.Send(new GetBusinessUnitsQuery(dashboardTenantId), _cts.Token)).ToList();
```

## 2. Already applied and working (keep these):

### UpdateDashboardCommand.cs
- Uses `bypassTenantFilter: isSuperadmin` when getting dashboard

### DeleteDashboardCommand.cs  
- Uses `bypassTenantFilter: isSuperadmin` when getting dashboard

### UpdateDashboardWidgetsCommand.cs
- Uses `bypassTenantFilter: isSuperadmin` when getting dashboard
- Uses `dashboard.TenantId` instead of `currentUser.TenantId` for new widgets

### GetDashboardByIdQuery.cs
- Uses `bypassTenantFilter: isSuperadmin` when getting dashboard

### CreateDashboardCommand.cs
- Superadmin can specify target TenantId via `cmd.Request.TenantId`

### ScreenListPage.razor
- Tenant selector in create modal for Superadmin
