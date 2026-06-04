# Task: Fix ClassificationId = "ALL" in NGC_BusinessUnitQueueClassification

## Root cause

RTM Engine (Engine.cs LoadData) calls `union.addWorkgroup(QueueId, ...)` only when
`ClassificationId == "ALL"`. Without this, Union.Queues stays empty — incoming calls
don't match the union — `getOrAddWGManager` creates a duplicate BU instead of
reusing the existing one — cells for Grid 31/32 never receive data — QueueGrid shows nothing.

Shell saves `NgcBusinessUnitQueueClassification` records without setting `ClassificationId`,
so it defaults to null/"". All records created via Shell UI or seeding are broken.

## Changes required

### 1. src/CcDashboard.Application/Commands/Configuration/ConfigurationCommands.cs

In the `foreach (var qid in req.QueueIds)` loop, add `ClassificationId = "ALL"`:

```csharp
bu.QueueAssignments.Add(new NgcBusinessUnitQueueClassification
{
    BusinessUnitId = bu.BusinessUnitId,
    QueueId = qid,
    TenantId = tenantId,
    ClassificationId = "ALL",   // ADD THIS
    CreatedDatetime = now,
    CreatedBy = createdBy
});
```

### 2. src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs

In the seed loop (around line 380), add `ClassificationId = "ALL"`:

```csharp
toAdd.Add(new NgcBusinessUnitQueueClassification
{
    TenantId = tenant.Id,
    BusinessUnitId = bu.BusinessUnitId,
    QueueId = queueId,
    ClassificationId = "ALL",   // ADD THIS
    CreatedDatetime = DateTime.UtcNow,
    CreatedBy = "system"
});
```

### 3. EF BackendEmulation migration — fix existing data

```bash
dotnet ef migrations add FixNgcQueueClassificationId \
  --context BackendEmulationDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

Migration Up():
```csharp
migrationBuilder.Sql(
    "UPDATE \"NGC_BusinessUnitQueueClassification\"" +
    " SET \"ClassificationId\" = 'ALL'" +
    " WHERE \"ClassificationId\" IS NULL OR \"ClassificationId\" = ''"
);
```

Migration Down(): empty (irreversible data fix).

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore

grep -A 8 "QueueAssignments.Add" src/CcDashboard.Application/Commands/Configuration/ConfigurationCommands.cs | grep "ClassificationId"

grep -A 8 "NgcBusinessUnitQueueClassification {" src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs | grep "ClassificationId"
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
fix: set ClassificationId="ALL" in NgcBusinessUnitQueueClassification saves

RTM Engine only calls addWorkgroup() when ClassificationId=="ALL".
Without it Union.Queues stays empty, incoming calls do not match the union,
getOrAddWGManager creates a duplicate BU, and QueueGrid cells never receive data.

Fix: always set ClassificationId="ALL" in ConfigurationCommands and
DatabaseInitializer. EF migration updates all existing null/"" records.
```
