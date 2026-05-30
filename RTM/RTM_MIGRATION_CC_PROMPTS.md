# RTM Backend — SQL Server → PostgreSQL Migration
## Claude Code Task Prompts

> Migration plan reference: `RTM_Migration_Plan_MSSQL_to_PostgreSQL.docx` v4.0  
> Staging DB: `cc_rtm_staging` (PostgreSQL) — do NOT touch production until RTM-M7 sign-off  
> All work in branch: `v2`  

---

## RTM-M1 — EF Core: 4 Missing Tables + UNIQUE Indexes

```
You are working in the CcDashboard solution (Blazor Server, .NET 8, PostgreSQL, EF Core 8).
The task is to add 4 missing entity classes and register them in BackendEmulationDbContext.

CONTEXT
-------
BackendEmulationDbContext owns all RTM backend tables. It currently has 19 entities.
Four tables needed by active stored procedures are missing:
  1. RTSData_ChatMessage  — needed by RTSData_SetChatMessage UPSERT
  2. RTSGrid_Statistic    — needed by RTSGrid_GetAllStatistics read SP
  3. RTSGrid_TemplateCell — needed by RTSGrid_GetDataCells JOIN
  4. RTSGrid_UserStatus   — needed by RTSGrid_SetUserStatus UPSERT (NO DDL in SQL Server dump — reconstruct from SP params)

Existing entity patterns are in:
  src/CcDashboard.Domain/Domain/RtsDataEntities.cs   ← add RtsDataChatMessage here
  src/CcDashboard.Domain/Domain/RtsEntities.cs        ← add RtsGridStatistic, RtsGridTemplateCell, RtsGridUserStatus here
  src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs ← register all 4 + indexes

STEP 1 — Add to RtsDataEntities.cs (after RtsDataUserStatusLog class)
---------------------------------------------------------------------------
Add class RtsDataChatMessage with these properties (all match SQL Server columns):
  MessageId       string  (PK part)
  ServerId        string  (PK part)
  OnDate          string  (PK part — "DD/MM/YYYY" varchar, same pattern as other RtsData tables)
  InteractionId   string?
  SegmentId       int?
  UserId          string?
  MsgDirection    string?
  Sender          string?
  Recipient       string?
  Body            string?
  DeliveryStatus  string?
  UpdateTime      DateTime?
  MsgTimeStamp    DateTime?   ← renamed from "TimeStamp" (reserved C# keyword); map to column "TimeStamp"

STEP 2 — Add to RtsEntities.cs
---------------------------------
Add class RtsGridStatistic:
  StatisticId   int          (IDENTITY PK)
  Category      string?
  Definition    string?
  ParamType1    string?  … ParamType10   string?   (10 columns)
  ParamValue1   string?  … ParamValue10  string?   (10 columns)
  — Total: 23 properties

Add class RtsGridTemplateCell:
  CellTemplateId  int         (IDENTITY PK — also FK from RtsGridColumn.CellTemplateId)
  StyleId         int?
  CellType        string?
  Value           string?
  Tooltip         string?
  OnClick         string?

Add class RtsGridUserStatus:
  UserId          string    (PK part)
  StatusId        string    (PK part)
  StatusName      string?
  StatusGroup     string?
  TotalDuration   int?
  MaxDuraction    int?      ← intentional typo — matches SQL Server SP parameter name
  TotalCount      int?
  SourceServer    string?
  OnDate          string?

STEP 3 — Register in BackendEmulationDbContext.cs
---------------------------------------------------
Add DbSet properties (follow existing pattern — expression-bodied => Set<>() syntax).
In OnModelCreating add configuration for each entity:

  RtsDataChatMessage:
    e.ToTable("RTSData_ChatMessage");
    e.HasKey(x => new { x.MessageId, x.ServerId, x.OnDate });
    e.Property(x => x.MsgTimeStamp).HasColumnName("TimeStamp");
    // UPSERT conflict key is (MessageId, ServerId) — 2-col, NOT the 3-col PK
    e.HasIndex(x => new { x.MessageId, x.ServerId }).IsUnique();

  RtsGridStatistic:
    e.ToTable("RTSGrid_Statistic");
    e.HasKey(x => x.StatisticId);
    e.Property(x => x.StatisticId).ValueGeneratedOnAdd();

  RtsGridTemplateCell:
    e.ToTable("RTSGrid_TemplateCell");
    e.HasKey(x => x.CellTemplateId);
    e.Property(x => x.CellTemplateId).ValueGeneratedOnAdd();

  RtsGridUserStatus:
    e.ToTable("RTSGrid_UserStatus");
    e.HasKey(x => new { x.UserId, x.StatusId });

  Also add for EXISTING RtsDataInteraction — UPSERT conflict key fix:
    e.HasIndex(x => new { x.InteractionId, x.Segment, x.ServerId }).IsUnique().HasDatabaseName("IX_RTSData_Interaction_UpsertKey");

STEP 4 — EF Migration
-----------------------
Run:
  dotnet ef migrations add AddMissingRtmTables \
    --context BackendEmulationDbContext \
    --project src/CcDashboard.Infrastructure \
    --startup-project src/CcDashboard.Web

Review the generated migration. Verify it creates:
  - RTSData_ChatMessage table with PK(MessageId, ServerId, OnDate) and UNIQUE IX on (MessageId, ServerId)
  - RTSGrid_Statistic table with SERIAL StatisticId PK
  - RTSGrid_TemplateCell table with SERIAL CellTemplateId PK
  - RTSGrid_UserStatus table with PK(UserId, StatusId)
  - UNIQUE index IX_RTSData_Interaction_UpsertKey on RTSData_Interaction(InteractionId, Segment, ServerId)

STEP 5 — Build check
----------------------
  dotnet build CcDashboard.sln

IMPORTANT FILE-WRITE RULE
---------------------------
The Edit tool has a known partial-write failure on this mount (see CLAUDE.md §0.3).
Every file write — including single-line changes — must use an atomic Python script:
  python3 /tmp/write_x.py
After every write run:
  tail -3 <path> && wc -l <path>

MANDATORY BEFORE COMMIT
------------------------
  bash tools/pre-commit-check.sh
# If exit code 1: restore truncated files, retry Python write, then re-check
# Only after exit code 0: proceed with git add

Commit message: "feat(rtm-m1): add 4 missing RTM entities + UPSERT unique indexes to BackendEmulationDbContext"
```

---

## RTM-M2 — Npgsql Driver Swap (RTM Projects)

```
You are working in the RTM backend solution — a .NET 8 Windows Service in subdirectory RTM/.
The task is to replace Microsoft.Data.SqlClient with Npgsql across all RTM projects.

CONTEXT
-------
The RTM backend uses raw ADO.NET (no ORM) via a static DBAdapter class.
All DB calls go through stored procedures. Three projects need changes:
  RTM/RTM.Tools/RTM.Tools.csproj   ← contains DBAdapter.cs
  RTM/RTM.Tools/DBAdapter.cs       ← all Sql* types here
  RTM/RTM.Configuration/AppConfig.cs ← connection string builder

STEP 1 — Update NuGet in RTM.Tools.csproj
------------------------------------------
Remove:   <PackageReference Include="Microsoft.Data.SqlClient" ... />
Add:      <PackageReference Include="Npgsql" Version="8.0.*" />

Also check RTM/RTM/RTM.csproj and RTM/RTM.Configuration/RTM.Configuration.csproj
for any SqlClient references and replace the same way.

STEP 2 — DBAdapter.cs
-----------------------
File: RTM/RTM.Tools/DBAdapter.cs

Replace ALL occurrences:
  using Microsoft.Data.SqlClient;   →  using Npgsql;
  SqlConnection                     →  NpgsqlConnection
  SqlCommand                        →  NpgsqlCommand
  SqlParameter                      →  NpgsqlParameter
  SqlDataAdapter                    →  NpgsqlDataAdapter
  SqlDateTime.MinValue.Value        →  DateTime.MinValue   (in getDateTimeValue method)

REMOVE the entire setDatetime() method (it returns SqlDateTime which no longer exists):
  private SqlDateTime setDatetime(DateTime value) { ... }

IMPORTANT — CommandType for result-set functions:
PL/pgSQL functions that RETURN TABLE must be called with CommandType.Text + SELECT syntax.
Change GetDataTable() and GetQueryDataTable() methods:
  BEFORE:
    cmd.CommandType = CommandType.StoredProcedure;
    cmd.CommandText = procedureName;
  AFTER:
    // Build SELECT * FROM "FunctionName"(params) call
    cmd.CommandType = CommandType.Text;
    if (parameters != null && parameters.Count > 0)
    {
        var paramPlaceholders = string.Join(", ", parameters.Select((_, i) => $"${i + 1}"));
        cmd.CommandText = $"SELECT * FROM \"{procedureName}\"({paramPlaceholders})";
        // Re-add parameters WITHOUT @-prefix names (Npgsql uses positional $1,$2... for text mode)
        foreach (var p in parameters)
            cmd.Parameters.Add(new NpgsqlParameter { Value = p.Value ?? DBNull.Value });
    }
    else
    {
        cmd.CommandText = $"SELECT * FROM \"{procedureName}\"()";
    }

For ExecuteNonQuery() (void functions / CALL):
    cmd.CommandType = CommandType.StoredProcedure;  ← keep for void PL/pgSQL functions

STEP 3 — AppConfig.cs
-----------------------
File: RTM/RTM.Configuration/AppConfig.cs

One-line change in the connection string builder:
  BEFORE:  builder["User ID"] = DatabaseUser;
  AFTER:   builder["Username"] = DatabaseUser;

Also update the connection string format from SQL Server to PostgreSQL:
  BEFORE:  $"Server={DatabaseServer};Database={DatabaseName};..."
  AFTER:   $"Host={DatabaseServer};Database={DatabaseName};Username={DatabaseUser};Password={DatabasePassword};SSL Mode=Prefer;"
  
  OR keep using SqlConnectionStringBuilder → switch to NpgsqlConnectionStringBuilder:
    var builder = new NpgsqlConnectionStringBuilder();
    builder.Host = DatabaseServer;
    builder.Database = DatabaseName;
    builder.Username = DatabaseUser;
    builder.Password = DatabasePassword;
    builder.SslMode = SslMode.Prefer;

STEP 4 — Build check
----------------------
  cd RTM && dotnet build

IMPORTANT FILE-WRITE RULE: CLAUDE.md §0.3 — use Python atomic writes, never Edit tool.
After every write: tail -3 <path> && wc -l <path>

MANDATORY BEFORE COMMIT
  bash tools/pre-commit-check.sh

Commit message: "feat(rtm-m2): replace SqlClient with Npgsql across RTM projects"
```

---

## RTM-M3 — PL/pgSQL: NGC_* Functions (18 functions)

```
You are working in the CcDashboard / RTM backend migration.
Task: create all NGC_* PL/pgSQL functions to replace SQL Server stored procedures.
Output file: RTM/sql/pgsql/01_ngc_functions.sql

CONTEXT
-------
These functions are called from RTM/RTM/BusinessUnitData.cs via DBAdapter.
All table names use PascalCase — EVERY identifier must be double-quoted in PL/pgSQL.
SQL Server IDENTITY columns → PostgreSQL SERIAL (ValueGeneratedOnAdd in EF).
SQL Server UPSERT pattern: UPDATE + IF @@ROWCOUNT=0 INSERT → PostgreSQL INSERT ... ON CONFLICT DO UPDATE.
NGC_CreateBusinessUnit and NGC_CreateSupergroup return the generated integer ID.

TABLE REFERENCE (all in BackendEmulationDbContext, PK column names from EF config):
  "NGC_BusinessUnit"                    PK: "BusinessUnitId" (serial int)
  "NGC_Supergroup"                      PK: "SupergroupId" (serial int)
  "NGC_BusinessUnitQueueClassification" PK: ("BusinessUnitId", "QueueId")
  "NGC_BusinessUnitSupergroup"          PK: ("BusinessUnitId", "SupergroupId")
  "NGC_SupergroupAgentgroup"            PK: "Id" (surrogate serial — EF added it)
  "NGC_Site"                            PK: "SiteId"

FUNCTIONS TO WRITE (18 total):
-------------------------------

1. NGC_GetBusinessUnitTable()
   SELECT all columns FROM "NGC_BusinessUnit" ORDER BY "BusinessUnitId"

2. NGC_GetSupergroupTable()
   SELECT all columns FROM "NGC_Supergroup" ORDER BY "SupergroupId"

3. NGC_GetBusinessUnitQueueClassificationTable()
   SELECT all columns FROM "NGC_BusinessUnitQueueClassification"

4. NGC_GetBusinessUnitSupergroupTable()
   SELECT all columns FROM "NGC_BusinessUnitSupergroup"

5. NGC_GetSupergroupAgentgroupTable()
   SELECT all columns FROM "NGC_SupergroupAgentgroup"

6. NGC_GetSiteTable()
   SELECT all columns FROM "NGC_Site"

7. NGC_CreateBusinessUnit(p_business_unit_name text, p_description text)
   INSERT INTO "NGC_BusinessUnit" ... RETURNING "BusinessUnitId"
   Return type: TABLE("BusinessUnitId" integer)
   (C# reads result as scalar string then converts to int)

8. NGC_ModifyBusinessUnit(p_business_unit_id integer, p_business_unit_name text, p_description text)
   UPDATE "NGC_BusinessUnit" SET ... WHERE "BusinessUnitId" = p_business_unit_id
   Return: void (use RETURNS void)

9. NGC_DeleteBusinessUnit(p_business_unit_id integer)
   DELETE FROM "NGC_BusinessUnit" WHERE "BusinessUnitId" = p_business_unit_id
   Return: void

10. NGC_CreateSupergroup(p_supergroup_name text, p_description text)
    INSERT INTO "NGC_Supergroup" ... RETURNING "SupergroupId"
    Return type: TABLE("SupergroupId" integer)

11. NGC_ModifySupergroup(p_supergroup_id integer, p_supergroup_name text, p_description text)
    UPDATE "NGC_Supergroup" SET ... WHERE "SupergroupId" = p_supergroup_id

12. NGC_DeleteSupergroup(p_supergroup_id integer)
    DELETE FROM "NGC_Supergroup" WHERE "SupergroupId" = p_supergroup_id

13. NGC_CreateBusinessUnitQueueClassificationMapping(p_business_unit_id integer, p_queue_id text)
    INSERT INTO "NGC_BusinessUnitQueueClassification" ("BusinessUnitId","QueueId") VALUES (...)
    ON CONFLICT ("BusinessUnitId","QueueId") DO NOTHING

14. NGC_DeleteBusinessUnitQueueClassificationMapping(p_business_unit_id integer, p_queue_id text)
    DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId"=p_business_unit_id AND "QueueId"=p_queue_id

15. NGC_CreateBusinessUnitSupergroupMapping(p_business_unit_id integer, p_supergroup_id integer)
    INSERT INTO "NGC_BusinessUnitSupergroup" ... ON CONFLICT DO NOTHING

16. NGC_DeleteBusinessUnitSupergroupMapping(p_business_unit_id integer, p_supergroup_id integer)
    DELETE FROM "NGC_BusinessUnitSupergroup"
    WHERE "BusinessUnitId"=p_business_unit_id AND "SupergroupId"=p_supergroup_id

17. NGC_CreateSupergroupAgentgroupMapping(p_supergroup_id integer, p_agentgroup_id integer)
    INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId","AgentgroupId") VALUES (...)
    ON CONFLICT DO NOTHING

18. NGC_DeleteSupergroupAgentgroupMapping(p_supergroup_id integer, p_agentgroup_id integer)
    DELETE FROM "NGC_SupergroupAgentgroup"
    WHERE "SupergroupId"=p_supergroup_id AND "AgentgroupId"=p_agentgroup_id

IMPLEMENTATION RULES
---------------------
- Use CREATE OR REPLACE FUNCTION for all.
- Functions 1-6 return RETURNS TABLE (...) — list all column names and types explicitly.
- Column names must exactly match BackendEmulationDbContext (read entity class properties to verify).
- Check RtsEntities.cs and NgcEntities.cs for exact column names.
- Functions 7,10 return RETURNS TABLE with single integer column (RETURNING pattern).
- Functions 8,9,11-18: RETURNS void.
- Language: LANGUAGE plpgsql.
- Every identifier double-quoted: "NGC_BusinessUnit", "BusinessUnitId", etc.
- Add DROP FUNCTION IF EXISTS before each CREATE OR REPLACE for clean re-run.

COLUMN NAMES TO VERIFY
------------------------
Before writing the SQL, read these files to get exact column names:
  src/CcDashboard.Domain/Domain/NgcEntities.cs
  src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs
  (look for e.ToTable("NGC_*") sections and HasKey/HasColumnName overrides)

VERIFICATION
-------------
After writing the file, verify it is syntactically complete:
  psql -c "\i RTM/sql/pgsql/01_ngc_functions.sql" [on staging DB]
  OR: grep -c "CREATE OR REPLACE FUNCTION" RTM/sql/pgsql/01_ngc_functions.sql
  Expected: 18

MANDATORY BEFORE COMMIT
  bash tools/pre-commit-check.sh
  
Commit message: "feat(rtm-m3): PL/pgSQL NGC_* functions (18)"
```

---

## RTM-M4 — PL/pgSQL: RTSData_* Functions (6 functions)

```
You are working in the CcDashboard / RTM backend migration.
Task: create RTSData_* PL/pgSQL functions.
Output file: RTM/sql/pgsql/02_rtsdata_functions.sql

CONTEXT
-------
These 6 functions handle real-time data writes and reads from RTM/RTM/DBMng.cs.
Two functions have UPSERT conflict key mismatches vs EF PK — see notes below.
RTSData_MidnightClear has a CRITICAL name difference: C# calls "RTSData_MidnightClear"
but SQL Server SP is named "RTSData_MidnightClear_1" — the PL/pgSQL function name
MUST be "RTSData_MidnightClear" (no "_1" suffix).

TABLE REFERENCE
---------------
"RTSData_Interaction"   EF PK: (InteractionId,Segment,OnDate,ServerId,Workgroup) 5-col
                        UPSERT UNIQUE INDEX: (InteractionId,Segment,ServerId) 3-col  ← use this for ON CONFLICT
"RTSData_UserStatus"    EF PK = UPSERT key: (UserId,StatusId,ServerId,OnDate) 4-col  ← no mismatch
"RTSData_ChatMessage"   EF PK: (MessageId,ServerId,OnDate) 3-col
                        UPSERT UNIQUE INDEX: (MessageId,ServerId) 2-col              ← use this for ON CONFLICT
"RTSData_UserStatusLog" has Id BIGINT IDENTITY PK (added by EF), Duration is bigint (ms)

FUNCTIONS TO WRITE (6 total):
------------------------------

1. RTSData_SetInteraction(... all SP params as p_* ...)
   T-SQL UPSERT → PostgreSQL:
     INSERT INTO "RTSData_Interaction" (...all columns...)
     VALUES (...)
     ON CONFLICT ("InteractionId","Segment","ServerId")   ← 3-col index, NOT the 5-col PK
     DO UPDATE SET
       [all non-key columns] = EXCLUDED.[column]
   
   Original SP parameters (map @Param → p_param, nvarchar→text, datetime→timestamptz, bit→boolean, int→integer):
     @InteractionId, @Segment, @OnDate, @ServerId, @Workgroup, @UserId,
     @ClassificationCode, @InteractionType, @CallType, @Direction, @CustomCallData,
     @IsTransferred, @IsAnswered, @IsInQueue, @IsTalk, @IsAbandoned,
     @TimeInQueue, @TalkTime, @InQueueDateTime, @AnsweredDateTime, @UpdateTime,
     @LastUserId, @LastWorkgroup, @IsMessaging, @RemoteAddress, @IsCallbackRequest, @TimeZone
   
   IMPORTANT: verify exact column names from RtsDataEntities.cs before writing.
   Returns: void

2. RTSData_SetUserStatus(... all SP params ...)
   INSERT INTO "RTSData_UserStatus" (...)
   VALUES (...)
   ON CONFLICT ("UserId","StatusId","ServerId","OnDate")   ← all 4 PK cols, no mismatch
   DO UPDATE SET [non-key columns] = EXCLUDED.[column]
   
   Original SP parameters:
     @UserId, @StatusId, @StatusName, @StatusGroup, @TotalDuration, @MaxDuration,
     @TotalCount, @SourceServer, @OnDate, @UpdateTime, @DisplayName, @TimeZone
   Returns: void

3. RTSData_SetChatMessage(... all SP params ...)
   INSERT INTO "RTSData_ChatMessage" (...)
   VALUES (...)
   ON CONFLICT ("MessageId","ServerId")   ← 2-col index, NOT the 3-col PK
   DO UPDATE SET [non-key columns] = EXCLUDED.[column]
   
   Note: column "TimeStamp" in DB but "MsgTimeStamp" in C# entity — use the DB column name "TimeStamp".
   
   Original SP parameters:
     @MessageId, @InteractionId, @SegmentId, @UserId, @MsgDirection, @Sender,
     @Recipient, @Body, @DeliveryStatus, @ServerId, @UpdateTime, @OnDate, @TimeStamp
   Returns: void

4. RTSData_MidnightClear()
   ⚠ FUNCTION NAME = "RTSData_MidnightClear" — NOT "RTSData_MidnightClear_1"
   Body (from SQL Server SP):
     DELETE FROM "RTSData_Interaction";
     DELETE FROM "RTSData_UserStatus";
   RTSData_ChatMessage is NOT cleared — this is intentional per production behavior.
   Returns: void

5. RTSData_GetInteractions()
   Note: C# calls this as "RTSData_getInteractions" (lowercase g).
   Create as "RTSData_GetInteractions" AND add alias:
     CREATE OR REPLACE FUNCTION "RTSData_getInteractions"() RETURNS TABLE (...) AS
     $$ SELECT * FROM "RTSData_GetInteractions"(); $$  LANGUAGE sql;
   
   Body: SELECT all columns FROM "RTSData_Interaction" WHERE [condition from original SP]
   Read the original SP body from H_RTM.sql analysis or write a full table scan if unclear.
   Returns: TABLE with all RTSData_Interaction columns.

6. RTSData_GetUsersStatuses()
   Same alias pattern as above: create "RTSData_GetUsersStatuses" AND "RTSData_getUsersStatuses".
   Body: SELECT all columns FROM "RTSData_UserStatus"
   Returns: TABLE with all RTSData_UserStatus columns.

VERIFICATION
  grep -c "CREATE OR REPLACE FUNCTION" RTM/sql/pgsql/02_rtsdata_functions.sql
  Expected: 8 (6 main + 2 lowercase aliases)

MANDATORY BEFORE COMMIT
  bash tools/pre-commit-check.sh

Commit message: "feat(rtm-m4): PL/pgSQL RTSData_* functions (6 + 2 aliases)"
```

---

## RTM-M5 — PL/pgSQL: RTSGrid Read Functions (8 functions)

```
You are working in the CcDashboard / RTM backend migration.
Task: create RTSGrid_* and RTSUserGrid_* read functions called from C#.
Output file: RTM/sql/pgsql/03_rtsgrid_read_functions.sql

CONTEXT
-------
These functions are called from RTM/RTM/RealtimeData.cs.
C# reads columns BY INDEX (row[0], row[1], ...) — column ORDER in RETURNS TABLE
must exactly match the order in the original T-SQL SELECT statement.
All identifiers must be double-quoted (PascalCase tables/columns).

CRITICAL DEPENDENCY:
Functions 1-3 JOIN "RTSGrid_TemplateCell" — this table was added in RTM-M1.
Make sure RTM-M1 is deployed before running this script.
Function 7 queries "RTSGrid_Statistic" — also added in RTM-M1.

FUNCTIONS TO WRITE (8 total):
------------------------------

1. RTSGrid_GetDataCells()
   Source T-SQL (from H_RTM.sql — column order is fixed):
     SELECT c."CellId", c."CellType", g."GridId", o."ColumnId", r."RowId",
            c."UnionId", g."UnionId" AS "GridUnionId", r."UnionId" AS "RowUnionId",
            c."Value" AS "Metric", t."Value" AS "ColumnMetric"
     FROM "RTSGrid_Grid" g, "RTSGrid_Row" r, "RTSGrid_Cell" c,
          "RTSGrid_Column" o, "RTSGrid_TemplateCell" t
     WHERE g."GridId" = r."GridId"
       AND c."RowId" = r."RowId"
       AND c."ColumnId" = o."ColumnId"
       AND o."CellTemplateId" = t."CellTemplateId"
       AND (c."CellType" = 'Data' OR (c."CellType" = 'None' AND t."CellType" = 'Data'))
   
   RETURNS TABLE: ("CellId" integer, "CellType" text, "GridId" integer, "ColumnId" integer,
                   "RowId" integer, "UnionId" integer, "GridUnionId" integer, "RowUnionId" integer,
                   "Metric" text, "ColumnMetric" text)
   
   Verify column names from RtsEntities.cs (RtsGridGrid, RtsGridRow, RtsGridCell, RtsGridColumn entities).

2. RTSGrid_GetStatisticCells()
   SELECT c."CellId", g."GridId", c."Value" AS "Title"
   FROM "RTSGrid_Grid" g, "RTSGrid_Row" r, "RTSGrid_Cell" c
   WHERE g."GridId" = r."GridId" AND c."RowId" = r."RowId" AND c."CellType" = 'Statistic'
   RETURNS TABLE: ("CellId" integer, "GridId" integer, "Title" text)

3. NGC_GetSiteTable()
   Already defined in RTM-M3 (01_ngc_functions.sql).
   Skip — do NOT duplicate.

4. RTSGrid_GetAllUnionQueueClassifications()
   The active version queries NGC tables (old RTSGrid_Union* queries are commented out in SQL Server).
   Reconstruct from H_RTM.sql SP body:
     SELECT [columns as in original SP]
     FROM "NGC_BusinessUnitQueueClassification" bq
     JOIN "NGC_BusinessUnit" bu ON bq."BusinessUnitId" = bu."BusinessUnitId"
     JOIN "NGC_Site" s ON bu."SiteId" = s."SiteId"
   
   Read the original SP body: grep for RTSGrid_GetAllUnionQueueClassifications in H_RTM.sql
   and reproduce the exact SELECT column list and ORDER.
   
   RETURNS TABLE: match original SP output columns exactly.

5. RTSGrid_GetAllUnionUserGroups()
   The active version queries NGC tables.
   Reconstruct from H_RTM.sql SP body:
     SELECT [columns]
     FROM "NGC_SupergroupAgentgroup" sa
     JOIN "NGC_BusinessUnitSupergroup" bs ON sa."SupergroupId" = bs."SupergroupId"
     JOIN "NGC_BusinessUnit" bu ON bs."BusinessUnitId" = bu."BusinessUnitId"
     JOIN "NGC_Site" s ON bu."SiteId" = s."SiteId"
   
   RETURNS TABLE: match original SP output exactly.

6. RTSGrid_GetAllMetrics()
   SELECT m."MetricId",
          CASE WHEN m."Description" IS NULL OR m."Description" = '' THEN m."MetricId"
               ELSE m."Description" END AS "Description",
          m."DataType", m."MetricFunction", m."MetricParameter", m."MetricFormat", m."DefaultValue"
   FROM "RTSGrid_Metric" m
   RETURNS TABLE: ("MetricId" text, "Description" text, "DataType" text,
                   "MetricFunction" text, "MetricParameter" text, "MetricFormat" text, "DefaultValue" text)
   
   Verify column names from RtsGridMetric.cs domain entity.

7. RTSGrid_GetAllStatistics()
   SELECT "StatisticId","Category","Definition",
          "ParamType1","ParamValue1","ParamType2","ParamValue2",
          ... (all 10 pairs) ...
          "ParamType10","ParamValue10"
   FROM "RTSGrid_Statistic"
   RETURNS TABLE: 23 columns — (StatisticId integer, Category text, Definition text,
                                 ParamType1..10 text, ParamValue1..10 text)

8. RTSGrid_GetUnionUsersMetrics()
   SELECT DISTINCT g."UnionId", c."MetricId"
   FROM "RTSUserGrid_Column" c, "RTSUserGrid_Grid" g
   WHERE c."ColumnsSetId" = g."ColumnsSetId"
   ORDER BY g."UnionId"
   RETURNS TABLE: ("UnionId" integer, "MetricId" text)

9. RTSUserGrid_GetAllGrids()
   Read original SP body from H_RTM.sql.
   Likely: SELECT all columns FROM "RTSUserGrid_Grid" [possibly with JOIN to ColumnsSet]
   RETURNS TABLE: all RTSUserGrid_Grid columns (verify from RtsEntities.cs RtsUserGridGrid entity)

PRE-WRITE CHECKLIST
--------------------
Before writing each function:
1. Read the entity class in src/CcDashboard.Domain/Domain/ to get exact column names
2. Read the original SP body in RTM/H_RTM.sql (use: iconv -f UTF-16 -t UTF-8 RTM/H_RTM.sql | grep -n "SP_NAME")
3. Match column ORDER in RETURNS TABLE to original SQL SELECT

VERIFICATION
  grep -c "CREATE OR REPLACE FUNCTION" RTM/sql/pgsql/03_rtsgrid_read_functions.sql
  Expected: 8

MANDATORY BEFORE COMMIT
  bash tools/pre-commit-check.sh

Commit message: "feat(rtm-m5): PL/pgSQL RTSGrid read functions (8)"
```

---

## RTM-M6 — PL/pgSQL: Missing SPs from Scratch + DNN Stub

```
You are working in the CcDashboard / RTM backend migration.
Task: write 3 PL/pgSQL functions that either have no SQL Server definition
or depend on a DNN CMS table.
Output file: RTM/sql/pgsql/04_missing_functions.sql

CONTEXT
-------
Two functions (NGC_GetDataGrid, NGC_GetCellsByDataGrid) are called from
RTM/RTM/RealtimeData.cs but are ABSENT from H_RTM.sql — they must be
reverse-engineered from the C# column-access code and available table schemas.

One function (RTSUserView_GetHTMLSettings) reads from DNN's ModuleSettings
table which won't exist in PostgreSQL. Implement as a stub returning empty.

FUNCTION 1: NGC_GetDataGrid(p_grid_id integer)
-----------------------------------------------
Called from RealtimeData.cs lines 335-360.
C# accesses result columns BY INDEX — exact column order below:
  row[0] → title (string)
  row[1] → businessUnitID (int)
  row[2] → cssStyleID (int)
  row[3] → thresholdID (int)
  row[4] → thresholdScript (string)
  row[5] → isToggle (bool)
  row[6] → toggleDefault (bool)

Before writing, read "RTSGrid_Grid" entity in src/CcDashboard.Domain/Domain/RtsEntities.cs
to find exact column names for: Title, BusinessUnitId (or similar), StyleId, ThresholdId,
ThresholdScript (or get from joined RTSGrid_Threshold), IsToggle, ToggleDefault.

Also run: iconv -f UTF-16 -t UTF-8 RTM/H_RTM.sql | grep -A5 "RTSGrid_Grid" | head -40
to see the full RTSGrid_Grid DDL columns.

If ThresholdScript is in a separate "RTSGrid_Threshold" table:
  SELECT g."Title", g."BusinessUnitId", g."StyleId", g."ThresholdId",
         COALESCE(th."Script", '') AS "ThresholdScript",
         g."IsToggle", g."ToggleDefault"
  FROM "RTSGrid_Grid" g
  LEFT JOIN "RTSGrid_Threshold" th ON g."ThresholdId" = th."ThresholdId"
  WHERE g."GridId" = p_grid_id

RETURNS TABLE must have columns in EXACTLY the order above (7 columns).

FUNCTION 2: NGC_GetCellsByDataGrid(p_grid_id integer)
------------------------------------------------------
Called from RealtimeData.cs lines 371-398.
C# accesses 11 result columns BY INDEX:
  row[0]  → cellID (int)
  row[1]  → (used but variable name not shown — likely ColumnId or CellType variant)
  row[2]  → rowNumber (int)
  row[3]  → (used but variable name not shown)
  row[4]  → cssStyleID (int)         → likely cell StyleId
  row[5]  → gridStyleId (int)        → RTSGrid_Grid StyleId
  row[6]  → rowStyleId (int)         → RTSGrid_Row StyleId
  row[7]  → cellType (string)        → RTSGrid_Cell CellType
  row[8]  → value (string)           → RTSGrid_Cell Value
  row[9]  → tooltip (string)         → RTSGrid_TemplateCell Tooltip
  row[10] → onClick (string)         → RTSGrid_TemplateCell OnClick

Read ALL relevant entity files to determine exact column names.
Suggested query (adapt based on actual column names):
  SELECT c."CellId",
         c."ColumnId",
         r."RowNumber",
         r."RowId",
         c."StyleId"  AS "CssStyleId",
         g."StyleId"  AS "GridStyleId",
         r."StyleId"  AS "RowStyleId",
         c."CellType",
         c."Value",
         COALESCE(t."Tooltip", '') AS "Tooltip",
         COALESCE(t."OnClick", '') AS "OnClick"
  FROM "RTSGrid_Cell" c
  JOIN "RTSGrid_Row" r ON c."RowId" = r."RowId"
  JOIN "RTSGrid_Grid" g ON r."GridId" = g."GridId"
  LEFT JOIN "RTSGrid_Column" o ON c."ColumnId" = o."ColumnId"
  LEFT JOIN "RTSGrid_TemplateCell" t ON o."CellTemplateId" = t."CellTemplateId"
  WHERE g."GridId" = p_grid_id

Columns 1 and 3 (row[1], row[3]) — if C# discards them or they're filler, use
the most logical values (ColumnId, RowId) and document the decision in a comment.

RETURNS TABLE must output exactly 11 columns in the order above.

FUNCTION 3: RTSUserView_GetHTMLSettings()
-----------------------------------------
Original SP reads from DNN ModuleSettings table — won't exist in PostgreSQL.
Implement as a stub returning empty result set:
  CREATE OR REPLACE FUNCTION "RTSUserView_GetHTMLSettings"()
  RETURNS TABLE("SettingValue" text)
  LANGUAGE plpgsql AS $$
  BEGIN
      -- STUB: Original SP reads from DNN ModuleSettings (portal CMS table).
      -- DNN is not migrated to PostgreSQL. Returns empty result set.
      -- TODO: Replace with appsettings.json config read in C# (OQ-01).
      RETURN;
  END;
  $$;

OPEN QUESTION NOTE
-------------------
Add a comment block at the top of the file:
  -- OQ-01: RTSUserView_GetHTMLSettings is a stub. The C# caller (RealtimeData.cs:475)
  -- reads HTML settings from DNN ModuleSettings. Decide: stub / port table / move to config.
  -- OQ-03: NGC_GetDataGrid and NGC_GetCellsByDataGrid were absent from H_RTM.sql dump.
  --        Functions below are reverse-engineered from C# column-index access patterns.
  --        Validate against production SQL Server before go-live.

VERIFICATION
  grep -c "CREATE OR REPLACE FUNCTION" RTM/sql/pgsql/04_missing_functions.sql
  Expected: 3

MANDATORY BEFORE COMMIT
  bash tools/pre-commit-check.sh

Commit message: "feat(rtm-m6): missing SPs from scratch (NGC_GetDataGrid, NGC_GetCellsByDataGrid) + DNN stub"
```

---

## RTM-M7 — Staging DB: pgloader Setup + Data Migration

```
You are working in the CcDashboard / RTM backend migration — final phase.
Task: set up PostgreSQL staging database, apply all migrations, load data from SQL Server.
Output: RTM/sql/pgloader/rtm_staging.load

PREREQUISITES — verify all completed before starting:
  ✅ RTM-M1: 4 new EF entities deployed (dotnet ef database update run on staging)
  ✅ RTM-M3: NGC_* functions deployed
  ✅ RTM-M4: RTSData_* functions deployed
  ✅ RTM-M5: RTSGrid read functions deployed
  ✅ RTM-M6: missing functions deployed

STEP 1 — Create staging database
----------------------------------
  psql -U postgres -c "CREATE DATABASE cc_rtm_staging;"
  psql -U postgres -c "CREATE USER cc_rtm_app WITH PASSWORD 'changeme';"
  psql -U postgres -c "GRANT ALL ON DATABASE cc_rtm_staging TO cc_rtm_app;"

STEP 2 — Run EF migrations against staging
-------------------------------------------
Set connection string to cc_rtm_staging in appsettings.Development.json (User Secrets),
then:
  dotnet ef database update --context AppDbContext \
    --project src/CcDashboard.Infrastructure \
    --startup-project src/CcDashboard.Web

  dotnet ef database update --context BackendEmulationDbContext \
    --project src/CcDashboard.Infrastructure \
    --startup-project src/CcDashboard.Web

STEP 3 — Deploy PL/pgSQL functions
-------------------------------------
  psql -U cc_rtm_app -d cc_rtm_staging -f RTM/sql/pgsql/01_ngc_functions.sql
  psql -U cc_rtm_app -d cc_rtm_staging -f RTM/sql/pgsql/02_rtsdata_functions.sql
  psql -U cc_rtm_app -d cc_rtm_staging -f RTM/sql/pgsql/03_rtsgrid_read_functions.sql
  psql -U cc_rtm_app -d cc_rtm_staging -f RTM/sql/pgsql/04_missing_functions.sql

STEP 4 — Write pgloader script
--------------------------------
File: RTM/sql/pgloader/rtm_staging.load

Content template:
  LOAD DATABASE
    FROM mssql://sa:PASSWORD@localhost/RTMViewDB
    INTO postgresql://cc_rtm_app:changeme@localhost/cc_rtm_staging

  WITH include drop, create tables, create indexes,
       reset sequences, foreign keys, workers = 4

  SET work_mem to '128MB', maintenance_work_mem to '512MB'

  CAST
    type datetime to timestamptz using zero-dates-to-null,
    type bit to boolean,
    type nvarchar to text

  INCLUDING ONLY TABLE NAMES MATCHING
    -- Category A (19 existing tables)
    'NGC_Site', 'NGC_BusinessUnit', 'NGC_Supergroup', 'NGC_Queues', 'NGC_AgentGroups',
    'NGC_BusinessUnitQueueClassification', 'NGC_BusinessUnitSupergroup', 'NGC_SupergroupAgentgroup',
    'RTSGrid_Metric', 'RTSGrid_Grid', 'RTSGrid_Column', 'RTSGrid_Row', 'RTSGrid_Cell',
    'RTSUserGrid_Grid', 'RTSUserGrid_ColumnsSet', 'RTSUserGrid_Column',
    'RTSData_Interaction', 'RTSData_UserStatus',
    -- Category B (3 new tables)
    'RTSData_ChatMessage', 'RTSGrid_Statistic', 'RTSGrid_TemplateCell',
    -- Category D (admin UI tables)
    'RTSGrid_Style', 'RTSGrid_CellImage', 'RTSGrid_Threshold', 'RTSGrid_ThresholdSet',
    'RTSGrid_Union', 'RTSGrid_UnionMetric', 'RTSGrid_UnionSupergroup',
    'RTSGrid_Supergroup', 'RTSGrid_SupergroupUsergroup', 'RTSUserGrid_Style',
    'NGC_RTMServer'

  EXCLUDING TABLE NAMES MATCHING
    -- Category E: backups and temp tables
    ~/BackUp/, ~/Old$/, ~/Old2$/, ~/tmp_/, ~/_05082024$/, ~/_17032024$/, ~/_13_2$/

  BEFORE LOAD DO
    $$ SET session_replication_role = replica; $$  -- disable FK checks during load

  AFTER LOAD DO
    $$ SET session_replication_role = DEFAULT; $$

Note: RTSData_UserStatusLog handled separately (needs Duration * 1000 transform — see below).
Note: RTSGrid_UserStatus (Cat. C) has no SQL Server DDL — skip from pgloader, start empty.

STEP 5 — RTSData_UserStatusLog special migration
--------------------------------------------------
pgloader cannot multiply a column during migration natively. Use a two-pass approach:
  Pass 1: pgloader copies RTSData_UserStatusLog to a temp table with original int Duration
  Pass 2: SQL transform:
    INSERT INTO "RTSData_UserStatusLog" ("UserId","StatusId","ServerId","OnDate","StartTime",
                                          "EndTime","Duration","UpdateTime","TimeZone")
    SELECT "UserId","StatusId","ServerId","OnDate","StartTime","EndTime",
           "Duration" * 1000,   -- convert seconds → milliseconds
           "UpdateTime","TimeZone"
    FROM tmp_userstatuslog;

STEP 6 — Verification queries
--------------------------------
File: RTM/sql/pgloader/verify_migration.sql

Write queries to check:
  1. Row count match for each table (compare vs SQL Server counts)
  2. UPSERT test: re-insert one existing RTSData_Interaction row — should update, not error
  3. Function smoke test:
       SELECT COUNT(*) FROM "NGC_GetSiteTable"();
       SELECT COUNT(*) FROM "RTSGrid_GetAllMetrics"();
       SELECT COUNT(*) FROM "RTSGrid_GetDataCells"();
  4. Check RTSData_UserStatusLog.Duration values are > 1000 (confirming ms conversion)

STEP 7 — RTM backend smoke test
---------------------------------
Update RTM appsettings to point to cc_rtm_staging PostgreSQL.
Start RTM service in dev mode. Verify:
  - Service starts without connection errors
  - BusinessUnitData loads NGC tables (log shows data)
  - RealtimeData loads grid config (log shows data)
  - One UPSERT write completes without SQL exception

MANDATORY BEFORE COMMIT
  bash tools/pre-commit-check.sh

Commit message: "feat(rtm-m7): pgloader staging setup + verification scripts"
```

---

## GitHub Project Setup

### Labels
```
rtm-migration       #0075ca  RTM PostgreSQL migration work
phase:ef-schema     #e4e669  EF Core schema changes
phase:driver        #f9d0c4  ADO.NET driver swap
phase:plpgsql       #c5def5  PL/pgSQL function writing
phase:data-load     #bfd4f2  pgloader / data migration
priority:critical   #b60205  Blocks all other work
priority:high       #d93f0b  Must complete before go-live
open-question       #ee0701  Requires decision before implementation
```

### Milestones
```
RTM-Phase1-Schema    → RTM-M1 (EF Core entities)
RTM-Phase2-Driver    → RTM-M2 (Npgsql)
RTM-Phase3-PgSQL     → RTM-M3, M4, M5, M6 (all PL/pgSQL functions)
RTM-Phase4-Staging   → RTM-M7 (pgloader + smoke test)
```

### Issues to Create
```
[RTM-M1] Add 4 missing EF Core entities + UNIQUE indexes      → labels: rtm-migration, phase:ef-schema, priority:critical
[RTM-M2] Replace SqlClient with Npgsql in RTM projects        → labels: rtm-migration, phase:driver, priority:critical
[RTM-M3] PL/pgSQL — NGC_* functions (18)                      → labels: rtm-migration, phase:plpgsql, priority:high
[RTM-M4] PL/pgSQL — RTSData_* functions (6 + 2 aliases)       → labels: rtm-migration, phase:plpgsql, priority:critical
[RTM-M5] PL/pgSQL — RTSGrid read functions (8)                → labels: rtm-migration, phase:plpgsql, priority:high
[RTM-M6] PL/pgSQL — missing SPs from scratch + DNN stub       → labels: rtm-migration, phase:plpgsql, priority:critical
[RTM-M7] pgloader staging setup + data migration              → labels: rtm-migration, phase:data-load, priority:high
[OQ-01]  Decide: RTSUserView_GetHTMLSettings DNN dependency   → labels: rtm-migration, open-question, priority:critical
[OQ-03]  Validate NGC_GetDataGrid / NGC_GetCellsByDataGrid     → labels: rtm-migration, open-question, priority:critical
```

