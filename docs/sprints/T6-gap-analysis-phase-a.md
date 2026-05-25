# T6 Phase A Gap Analysis — User Management

**Sprint:** T6 User Management + Audit Trail
**Phase:** A (User Management)
**Date:** 2026-05-25
**Status:** Production gaps identified, fixes required before testing

---

## 1. Files Analyzed

| File | Purpose |
|---|---|
| `src/CcDashboard.Infrastructure/Identity/UserManagementService.cs` | Core user management operations |
| `src/CcDashboard.Application/Interfaces/IUserManagementService.cs` | Service interface |
| `src/CcDashboard.Application/Queries/Users/GetUsersQuery.cs` | User list query with pagination |
| `src/CcDashboard.Contracts/DTOs/Users/UserDto.cs` | DTOs for user operations |

---

## 2. GAP-T6-01: Missing `User.RoleChanged` / `User.PermissionGroupChanged` Audit Events

### Requirement
- **USR-07:** Role change → audit event `User.RoleChanged` (old role + new role in Details)
- **§16:** `User.PermissionGroupChanged` must be written when PermissionGroupId changes

### Current State
`UserManagementService.UpdateAsync()` (lines 113-144):

```csharp
// Update role
var currentRoles = await userManager.GetRolesAsync(user);
if (!currentRoles.Contains(req.Role))
{
    await userManager.RemoveFromRolesAsync(user, currentRoles);
    await userManager.AddToRoleAsync(user, req.Role);
}

await audit.LogAsync("User.Updated", AuditEventResult.Success, ...);  // ← Only User.Updated
```

**Problem:** When role changes, only `User.Updated` is emitted. No `User.RoleChanged` event.
Similarly, `PermissionGroupId` is assigned directly without detecting change or emitting
`User.PermissionGroupChanged`.

### Required Fix
1. Capture old role and old PG before mutation
2. Compare after mutation
3. Emit `User.RoleChanged` with `{ OldRole, NewRole }` in Details if changed
4. Emit `User.PermissionGroupChanged` with `{ OldPermissionGroupId, NewPermissionGroupId }` if changed

---

## 3. GAP-T6-02: Cross-Tenant Mutation Vulnerability

### Requirement
- **USR-05:** Administrator cannot create users in a different tenant
- **ARCH-01:** Every operation must be tenant-scoped via Global Query Filters

### Current State
`UserManagementService.UpdateAsync()` (line 115):

```csharp
var user = await userManager.FindByIdAsync(req.Id.ToString());
if (user == null) return (false, "User not found.");
```

`UserManagementService.DeleteAsync()` (line 199):

```csharp
var user = await userManager.FindByIdAsync(userId.ToString());
if (user == null) return (false, "User not found.");
```

**Problem:** `UserManager.FindByIdAsync()` bypasses Global Query Filters. If an attacker knows
a `userId` from tenant B, they can update/delete that user while authenticated as tenant A.

Same issue in:
- `SetActiveAsync()` (line 147)
- `AdminResetPasswordAsync()` (line 167)
- `ForceLogoutAsync()` (line 191)

### Required Fix
After finding the user, verify `user.TenantId == currentUser.TenantId` (unless Superadmin).
Return `NotFoundException` or authorization error if mismatch.

---

## 4. GAP-T6-03: Admin Can Change Own Role

### Requirement
- **USR-08:** Administrator cannot change their own role

### Current State
`UserManagementService.UpdateAsync()` has no check for self-role-change:

```csharp
// Update role — no check if currentUser.UserId == req.Id
var currentRoles = await userManager.GetRolesAsync(user);
if (!currentRoles.Contains(req.Role))
{
    await userManager.RemoveFromRolesAsync(user, currentRoles);
    await userManager.AddToRoleAsync(user, req.Role);
}
```

**Problem:** An Administrator could escalate to Superadmin or demote themselves to bypass
audit trail expectations.

### Required Fix
Add guard: if `currentUser.UserId == req.Id` AND role is changing → reject with error
"Cannot change own role."

---

## 5. GAP-T6-04 (discovered during testing): CreateAsync missing USR-05 guards

### Requirement
- **USR-05:** Administrator cannot create Superadmin users or users in a different tenant

### Current State (before fix)
`UserManagementService.CreateAsync()` accepts `tenantId` and `req.Role` without validating
that the calling user (from `currentUser`) is authorized to create users with that role in
that tenant.

### Fix Applied
Added two guards in `CreateAsync()`:
1. If `req.Role == "Superadmin"` and `currentUser.Role != "Superadmin"` → reject
2. If `currentUser.Role != "Superadmin"` and `currentUser.TenantId != tenantId` → reject

---

## 6. Production Fix Plan

### Step 1: Add tenant ownership check to UpdateAsync signature
The interface method `UpdateAsync(UpdateUserRequest req, ...)` lacks `tenantId` parameter.
Either:
- (A) Add `tenantId` parameter to interface and all callers — invasive
- (B) Use `ICurrentUserAccessor.TenantId` injected into service — minimal change ✓

**Decision:** Use existing `ICurrentUserAccessor currentUser` (already injected). Verify
`user.TenantId == currentUser.TenantId` unless `currentUser.Role == "Superadmin"`.

### Step 2: Detect and emit granular audit events
```csharp
var oldRole = (await userManager.GetRolesAsync(user)).FirstOrDefault();
var oldPgId = user.PermissionGroupId;

// ... mutations ...

if (oldRole != req.Role)
    await audit.LogAsync("User.RoleChanged", ...Details: { OldRole = oldRole, NewRole = req.Role });

if (oldPgId != req.PermissionGroupId)
    await audit.LogAsync("User.PermissionGroupChanged", ...Details: { OldPgId = oldPgId, NewPgId = req.PermissionGroupId });
```

### Step 3: Add self-role-change guard
```csharp
if (currentUser.UserId == req.Id && currentUser.Role != "Superadmin")
{
    var existingRole = (await userManager.GetRolesAsync(user)).FirstOrDefault();
    if (existingRole != req.Role)
        return (false, "Cannot change own role.");
}
```

---

## 6. Methods Requiring Tenant Check

| Method | Fix Required |
|---|---|
| `UpdateAsync` | Verify `user.TenantId == currentUser.TenantId` (unless Superadmin) |
| `DeleteAsync` | Same |
| `SetActiveAsync` | Same |
| `AdminResetPasswordAsync` | Same |
| `ForceLogoutAsync` | Same |

---

## 7. Test Coverage After Fixes

Per DoD-A2..A10, the following test scenarios validate the fixes:

- **DoD-A4:** Admin cross-tenant creation rejected → validates GAP-T6-02
- **DoD-A5:** Update with role change emits `User.RoleChanged` → validates GAP-T6-01
- **DoD-A5:** Admin cannot change own role → validates GAP-T6-03
- **DoD-A6:** Cross-tenant update/delete rejected → validates GAP-T6-02
