# CC Task: RTM Service — Add TenantId support

## Context

RTM Service writes real-time CC data to a shared PostgreSQL database.
The database is multi-tenant (all NGC_* and RTSData_* tables have a TenantId column).
RTM Service currently ignores TenantId — it reads/writes data for ALL tenants simultaneously.

Fix: add `TenantId` to `appsettings.json` (set at deployment), propagate it to all
22 affected SQL functions and 3 C# caller files.

Full spec: CLAUDE.md §33 (read it first).

---

## Rules (MANDATORY)

- Work ONLY in `RTM/` directory — do NOT touch `src/` or `tests/`
- Edit tool is BANNED — all file writes via Python atomic read→modify→write + `os.fsync()`
- Before every commit: `bash tools/pre-commit-check.sh`
- After every commit: `git status --short` must be empty
- Re-sync committed files from HEAD at session end (§0.6 PD-007)

---

## Session-resume integrity check (§0.2) — run FIRST

```bash
cd D:\Claude\Projects\RTM View Shell
git status --short
git log --oneline -5
```

For every M file in RTM/: `tail -3 <path>` — check for truncation.
Restore truncated: `git show HEAD:<path> > <path>`

---

## Phase 1 — appsettings.json + AppConfig.cs

**File:** `RTM/RTM/appsettings.json`

Add `"TenantId"` to the `"RTM"` section:
```json
"RTM": {
  "TenantId": "00000000-0000-0000-0000-000000000000",
  ...
}
```
The placeholder `00000000-...` is intentional — operator must set a real UUID at deployment.

**File:** `RTM/RTM.Configuration/AppConfig.cs`

1. Add property: `public static Guid TenantId { get; private set; }`
2. In `Initialize()`: `TenantId = Guid.Parse(configuration["RTM:TenantId"]);`
3. Add startup log: `AsyncLogger.Info($"AppConfig.TenantId = {TenantId}");`
4. In `ValidateConfiguration()`: throw if `TenantId == Guid.Empty`:
   ```csharp
   if (TenantId == Guid.Empty)
       throw new InvalidOperationException("RTM:TenantId is not configured. Set a valid tenant UUID in appsettings.json.");
   ```

---

## Phase 2 — DBMng.cs (RTSData_* calls)

**File:** `RTM/RTM/DBMng.cs`

1. Add field: `private readonly Guid _tenantId = AppConfig.TenantId;`
2. For each of the 5 DB calls, append `@TenantId` as the LAST parameter:

   **RTSData_SetUserStatus** (line ~368): append after `@UpdateTime`
   ```csharp
   parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
   ```

   **RTSData_SetInteraction** (line ~423): append after `@OnDate`
   ```csharp
   parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
   ```

   **RTSData_SetChatMessage** (line ~443): append after `@OnDate`
   ```csharp
   parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
   ```

   **RTSData_getUsersStatuses** (line ~477): append after `@OnDate`
   ```csharp
   parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
   ```

   **RTSData_getInteractions** (line ~484): append after `@OnDate`
   ```csharp
   parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
   ```

   **midnightClear()**: add TenantId param:
   ```csharp
   var parameters = new List<NpgsqlParameter>();
   parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
   DBAdapter.ExecuteNonQuery("RTSData_MidnightClear", parameters);
   ```

---

## Phase 3 — BusinessUnitData.cs (NGC_* calls, 17 total)

**File:** `RTM/RTM/BusinessUnitData.cs`

Add `parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));`
as the **last** parameter before each `DBAdapter.*` call.

Functions to update (append @TenantId to each):
- `NGC_GetBusinessUnitTable` (no params currently → add 1)
- `NGC_GetSupergroupTable` (no params currently → add 1)
- `NGC_GetBusinessUnitQueueClassificationTable` (no params → add 1)
- `NGC_GetBusinessUnitSupergroupTable` (no params → add 1)
- `NGC_GetSupergroupAgentgroupTable` (no params → add 1)
- `NGC_CreateBusinessUnit` (currently: Name, Description, SiteId, CreatedBy → add TenantId)
- `NGC_DeleteBusinessUnit` (BusinessUnitID → add TenantId)
- `NGC_ModifyBusinessUnit` (BusinessUnitID, Name, Description → add TenantId)
- `NGC_CreateSupergroup` — TWO overloads (lines ~257 and ~280); add TenantId to both
- `NGC_DeleteSupergroup` (SupergroupID → add TenantId)
- `NGC_ModifySupergroup` (SupergroupID, Name, Description → add TenantId)
- `NGC_CreateBusinessUnitQueueClassificationMapping` (BU, Queue, Classification, CreatedBy → add TenantId)
- `NGC_DeleteBusinessUnitQueueClassificationMapping` (BU, Queue, Classification → add TenantId)
- `NGC_CreateBusinessUnitSupergroupMapping` (BU, Supergroup, CreatedBy → add TenantId)
- `NGC_DeleteBusinessUnitSupergroupMapping` (BU, Supergroup, DeletedBy → add TenantId)
- `NGC_CreateSupergroupAgentgroupMapping` (Supergroup, Agentgroup, CreatedBy → add TenantId)
- `NGC_DeleteSupergroupAgentgroupMapping` (Supergroup, Agentgroup, DeletedBy → add TenantId)

---

## Phase 4 — RealtimeData.cs (NGC_* + RTSGrid_* calls)

**File:** `RTM/RTM/RealtimeData.cs`

Add `parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));` to:
- `NGC_GetSiteTable` (currently no params → add 1)
- `RTSGrid_GetAllUnionQueueClassifications` (currently no params → add 1)
- `RTSGrid_GetAllUnionUserGroups` (currently no params → add 1)

These 3 functions join NGC_ tables and need TenantId to filter by tenant.
All other RTSGrid_* / RTSUserGrid_* calls — do NOT add TenantId (no TenantId column).

---

## Phase 5 — SQL functions: 01_ngc_functions.sql

**File:** `RTM/sql/pgsql/01_ngc_functions.sql`

For every NGC_* function, add `p_tenant_id uuid` as the **last** parameter.

Pattern for READ functions (NGC_Get*): add `WHERE "TenantId" = p_tenant_id` to SELECT.
Pattern for INSERT functions (NGC_Create*): add `"TenantId"` to INSERT columns and `p_tenant_id` to VALUES.
Pattern for UPDATE functions (NGC_Modify*): add `AND "TenantId" = p_tenant_id` to WHERE.
Pattern for DELETE functions (NGC_Delete*): add `AND "TenantId" = p_tenant_id` to WHERE.

Also drop old signatures (without p_tenant_id) before creating new ones.

---

## Phase 6 — SQL functions: 02_rtsdata_functions.sql

**File:** `RTM/sql/pgsql/02_rtsdata_functions.sql`

Add `p_tenant_id uuid` as last parameter to:
1. `RTSData_SetInteraction` — set `"TenantId" = p_tenant_id` on INSERT and in ON CONFLICT DO UPDATE
2. `RTSData_SetUserStatus` — same pattern
3. `RTSData_SetChatMessage` — same pattern
4. `RTSData_getUsersStatuses` — add WHERE `"TenantId" = p_tenant_id`
5. `RTSData_getInteractions` — add WHERE `"TenantId" = p_tenant_id`
6. `RTSData_MidnightClear` — add `p_tenant_id uuid`, change DELETE to `WHERE "TenantId" = p_tenant_id`

**[RTM-SEC-001] MidnightClear is CRITICAL** — without this fix it deletes ALL tenants' data.

---

## Phase 7 — SQL functions: 03_rtsgrid_read_functions.sql

**File:** `RTM/sql/pgsql/03_rtsgrid_read_functions.sql`

Update `RTSGrid_GetAllUnionQueueClassifications` and `RTSGrid_GetAllUnionUserGroups`:
- Add `p_tenant_id uuid` as last parameter
- Add `WHERE ngc."TenantId" = p_tenant_id` (or equivalent JOIN filter) to scope NGC_ table reads

---

## Phase 8 — Update staging fix files

**File:** `RTM/staging/fix_set_interaction.sql`
- Add `p_tenant_id uuid` as last param to the PROCEDURE
- Add `"TenantId"` to INSERT column list and `p_tenant_id` to VALUES
- Add `"TenantId" = EXCLUDED."TenantId"` to ON CONFLICT DO UPDATE

**File:** `RTM/staging/fix_set_userstatus.sql`
- Same pattern as above for RTSData_UserStatus

---

## Phase 9 — Commit

```bash
bash tools/pre-commit-check.sh \
  RTM/RTM/appsettings.json \
  RTM/RTM.Configuration/AppConfig.cs \
  RTM/RTM/DBMng.cs \
  RTM/RTM/BusinessUnitData.cs \
  RTM/RTM/RealtimeData.cs \
  RTM/sql/pgsql/01_ngc_functions.sql \
  RTM/sql/pgsql/02_rtsdata_functions.sql \
  RTM/sql/pgsql/03_rtsgrid_read_functions.sql \
  RTM/staging/fix_set_interaction.sql \
  RTM/staging/fix_set_userstatus.sql
```

Commit message:
```
feat(RTM): add TenantId support — one instance = one tenant

- appsettings.json: TenantId placeholder (set at deployment)
- AppConfig.cs: TenantId property + validation (empty GUID = fatal error)
- DBMng.cs: _tenantId field, passed to all 6 RTSData SP calls
- BusinessUnitData.cs: @TenantId appended to all 17 NGC_ calls
- RealtimeData.cs: @TenantId appended to NGC_GetSiteTable + 2 RTSGrid_ joins
- 01_ngc_functions.sql: p_tenant_id uuid added to all 17 NGC_ functions
- 02_rtsdata_functions.sql: p_tenant_id uuid added to all 6 RTSData_ functions
- 03_rtsgrid_read_functions.sql: TenantId filter in 2 RTSGrid_ NGC joins
- staging: fix_set_interaction + fix_set_userstatus updated with TenantId
Fixes RTM-SEC-001: MidnightClear no longer deletes all tenants data
```

---

## Phase 10 — Re-sync from HEAD (§0.6 PD-007, MANDATORY)

```bash
for f in \
  RTM/RTM/appsettings.json \
  RTM/RTM.Configuration/AppConfig.cs \
  RTM/RTM/DBMng.cs \
  RTM/RTM/BusinessUnitData.cs \
  RTM/RTM/RealtimeData.cs \
  RTM/sql/pgsql/01_ngc_functions.sql \
  RTM/sql/pgsql/02_rtsdata_functions.sql \
  RTM/sql/pgsql/03_rtsgrid_read_functions.sql \
  RTM/staging/fix_set_interaction.sql \
  RTM/staging/fix_set_userstatus.sql; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
