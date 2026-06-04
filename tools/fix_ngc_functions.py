import os

path = r'RTM\sql\pgsql\01_ngc_functions.sql'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# ============================================================================
# READ FUNCTIONS - add p_tenant_id parameter and WHERE filter
# ============================================================================

# 1. NGC_GetBusinessUnitTable
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitTable"();

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitTable"()''',
    '''DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitTable"();
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitTable"(p_tenant_id uuid)'''
)
text = text.replace(
    '''FROM "NGC_BusinessUnit" bu
    ORDER BY bu."BusinessUnitId";''',
    '''FROM "NGC_BusinessUnit" bu
    WHERE bu."TenantId" = p_tenant_id
    ORDER BY bu."BusinessUnitId";'''
)

# 2. NGC_GetSupergroupTable
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_GetSupergroupTable"();

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupTable"()''',
    '''DROP FUNCTION IF EXISTS "NGC_GetSupergroupTable"();
DROP FUNCTION IF EXISTS "NGC_GetSupergroupTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupTable"(p_tenant_id uuid)'''
)
text = text.replace(
    '''FROM "NGC_Supergroup" sg
    ORDER BY sg."SupergroupId";''',
    '''FROM "NGC_Supergroup" sg
    WHERE sg."TenantId" = p_tenant_id
    ORDER BY sg."SupergroupId";'''
)

# 3. NGC_GetBusinessUnitQueueClassificationTable
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitQueueClassificationTable"();

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitQueueClassificationTable"()''',
    '''DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitQueueClassificationTable"();
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitQueueClassificationTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitQueueClassificationTable"(p_tenant_id uuid)'''
)
text = text.replace(
    'FROM "NGC_BusinessUnitQueueClassification" bq;',
    'FROM "NGC_BusinessUnitQueueClassification" bq\n    WHERE bq."TenantId" = p_tenant_id;'
)

# 4. NGC_GetBusinessUnitSupergroupTable
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitSupergroupTable"();

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitSupergroupTable"()''',
    '''DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitSupergroupTable"();
DROP FUNCTION IF EXISTS "NGC_GetBusinessUnitSupergroupTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetBusinessUnitSupergroupTable"(p_tenant_id uuid)'''
)
text = text.replace(
    'FROM "NGC_BusinessUnitSupergroup" bs;',
    'FROM "NGC_BusinessUnitSupergroup" bs\n    WHERE bs."TenantId" = p_tenant_id;'
)

# 5. NGC_GetSupergroupAgentgroupTable
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_GetSupergroupAgentgroupTable"();

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupAgentgroupTable"()''',
    '''DROP FUNCTION IF EXISTS "NGC_GetSupergroupAgentgroupTable"();
DROP FUNCTION IF EXISTS "NGC_GetSupergroupAgentgroupTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetSupergroupAgentgroupTable"(p_tenant_id uuid)'''
)
text = text.replace(
    'FROM "NGC_SupergroupAgentgroup" sa;',
    'FROM "NGC_SupergroupAgentgroup" sa\n    WHERE sa."TenantId" = p_tenant_id;'
)

# 6. NGC_GetSiteTable
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_GetSiteTable"();

CREATE OR REPLACE FUNCTION "NGC_GetSiteTable"()''',
    '''DROP FUNCTION IF EXISTS "NGC_GetSiteTable"();
DROP FUNCTION IF EXISTS "NGC_GetSiteTable"(uuid);

CREATE OR REPLACE FUNCTION "NGC_GetSiteTable"(p_tenant_id uuid)'''
)
text = text.replace(
    'FROM "NGC_Site" s;',
    'FROM "NGC_Site" s\n    WHERE s."TenantId" = p_tenant_id;'
)

# ============================================================================
# CREATE FUNCTIONS - add p_tenant_id parameter and INSERT TenantId column
# ============================================================================

# 7. NGC_CreateBusinessUnit
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnit"(
    p_business_unit_name text,
    p_description text
)''',
    '''DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text);
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnit"(text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnit"(
    p_business_unit_name text,
    p_description text,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''INSERT INTO "NGC_BusinessUnit" ("BusinessUnitName", "Description", "CreatedDatetime")
    VALUES (p_business_unit_name, p_description, NOW())''',
    '''INSERT INTO "NGC_BusinessUnit" ("BusinessUnitName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_name, p_description, NOW(), p_tenant_id)'''
)

# 8. NGC_ModifyBusinessUnit
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_ModifyBusinessUnit"(integer, text, text);

CREATE OR REPLACE FUNCTION "NGC_ModifyBusinessUnit"(
    p_business_unit_id integer,
    p_business_unit_name text,
    p_description text
)''',
    '''DROP FUNCTION IF EXISTS "NGC_ModifyBusinessUnit"(integer, text, text);
DROP FUNCTION IF EXISTS "NGC_ModifyBusinessUnit"(integer, text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_ModifyBusinessUnit"(
    p_business_unit_id integer,
    p_business_unit_name text,
    p_description text,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''WHERE "BusinessUnitId" = p_business_unit_id;
END;
$$;

-- ============================================================================
-- 9. NGC_DeleteBusinessUnit''',
    '''WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 9. NGC_DeleteBusinessUnit'''
)

# 9. NGC_DeleteBusinessUnit
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnit"(integer);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnit"(
    p_business_unit_id integer
)''',
    '''DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnit"(integer);
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnit"(integer, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnit"(
    p_business_unit_id integer,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''DELETE FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitId" = p_business_unit_id;
END;
$$;

-- ============================================================================
-- 10. NGC_CreateSupergroup''',
    '''DELETE FROM "NGC_BusinessUnit"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 10. NGC_CreateSupergroup'''
)

# 10. NGC_CreateSupergroup
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_CreateSupergroup"(text, text);

CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(
    p_supergroup_name text,
    p_description text
)''',
    '''DROP FUNCTION IF EXISTS "NGC_CreateSupergroup"(text, text);
DROP FUNCTION IF EXISTS "NGC_CreateSupergroup"(text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(
    p_supergroup_name text,
    p_description text,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''INSERT INTO "NGC_Supergroup" ("SupergroupName", "Description", "CreatedDatetime")
    VALUES (p_supergroup_name, p_description, NOW())''',
    '''INSERT INTO "NGC_Supergroup" ("SupergroupName", "Description", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_name, p_description, NOW(), p_tenant_id)'''
)

# 11. NGC_ModifySupergroup
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_ModifySupergroup"(integer, text, text);

CREATE OR REPLACE FUNCTION "NGC_ModifySupergroup"(
    p_supergroup_id integer,
    p_supergroup_name text,
    p_description text
)''',
    '''DROP FUNCTION IF EXISTS "NGC_ModifySupergroup"(integer, text, text);
DROP FUNCTION IF EXISTS "NGC_ModifySupergroup"(integer, text, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_ModifySupergroup"(
    p_supergroup_id integer,
    p_supergroup_name text,
    p_description text,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''WHERE "SupergroupId" = p_supergroup_id;
END;
$$;

-- ============================================================================
-- 12. NGC_DeleteSupergroup''',
    '''WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 12. NGC_DeleteSupergroup'''
)

# 12. NGC_DeleteSupergroup
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_DeleteSupergroup"(integer);

CREATE OR REPLACE FUNCTION "NGC_DeleteSupergroup"(
    p_supergroup_id integer
)''',
    '''DROP FUNCTION IF EXISTS "NGC_DeleteSupergroup"(integer);
DROP FUNCTION IF EXISTS "NGC_DeleteSupergroup"(integer, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteSupergroup"(
    p_supergroup_id integer,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''DELETE FROM "NGC_Supergroup"
    WHERE "SupergroupId" = p_supergroup_id;
END;
$$;

-- ============================================================================
-- 13. NGC_CreateBusinessUnitQueueClassificationMapping''',
    '''DELETE FROM "NGC_Supergroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;
END;
$$;

-- ============================================================================
-- 13. NGC_CreateBusinessUnitQueueClassificationMapping'''
)

# 13. NGC_CreateBusinessUnitQueueClassificationMapping
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text
)''',
    '''DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text);
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''INSERT INTO "NGC_BusinessUnitQueueClassification" ("BusinessUnitId", "QueueId", "CreatedDatetime")
    VALUES (p_business_unit_id, p_queue_id, NOW())''',
    '''INSERT INTO "NGC_BusinessUnitQueueClassification" ("BusinessUnitId", "QueueId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_queue_id, NOW(), p_tenant_id)'''
)

# 14. NGC_DeleteBusinessUnitQueueClassificationMapping
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping"(integer, text);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text
)''',
    '''DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping"(integer, text);
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitQueueClassificationMapping"(integer, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnitQueueClassificationMapping"(
    p_business_unit_id integer,
    p_queue_id text,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "QueueId" = p_queue_id;''',
    '''DELETE FROM "NGC_BusinessUnitQueueClassification"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "QueueId" = p_queue_id
      AND "TenantId" = p_tenant_id;'''
)

# 15. NGC_CreateBusinessUnitSupergroupMapping
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer
)''',
    '''DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer);
DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''INSERT INTO "NGC_BusinessUnitSupergroup" ("BusinessUnitId", "SupergroupId", "CreatedDatetime")
    VALUES (p_business_unit_id, p_supergroup_id, NOW())''',
    '''INSERT INTO "NGC_BusinessUnitSupergroup" ("BusinessUnitId", "SupergroupId", "CreatedDatetime", "TenantId")
    VALUES (p_business_unit_id, p_supergroup_id, NOW(), p_tenant_id)'''
)

# 16. NGC_DeleteBusinessUnitSupergroupMapping
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping"(integer, integer);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer
)''',
    '''DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping"(integer, integer);
DROP FUNCTION IF EXISTS "NGC_DeleteBusinessUnitSupergroupMapping"(integer, integer, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteBusinessUnitSupergroupMapping"(
    p_business_unit_id integer,
    p_supergroup_id integer,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''DELETE FROM "NGC_BusinessUnitSupergroup"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "SupergroupId" = p_supergroup_id;''',
    '''DELETE FROM "NGC_BusinessUnitSupergroup"
    WHERE "BusinessUnitId" = p_business_unit_id
      AND "SupergroupId" = p_supergroup_id
      AND "TenantId" = p_tenant_id;'''
)

# 17. NGC_CreateSupergroupAgentgroupMapping
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text);

CREATE OR REPLACE FUNCTION "NGC_CreateSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text
)''',
    '''DROP FUNCTION IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text);
DROP FUNCTION IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_CreateSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId", "CreatedDatetime")
    VALUES (p_supergroup_id, p_agentgroup_id, NOW());''',
    '''INSERT INTO "NGC_SupergroupAgentgroup" ("SupergroupId", "AgentgroupId", "CreatedDatetime", "TenantId")
    VALUES (p_supergroup_id, p_agentgroup_id, NOW(), p_tenant_id);'''
)

# 18. NGC_DeleteSupergroupAgentgroupMapping
text = text.replace(
    '''DROP FUNCTION IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping"(integer, text);

CREATE OR REPLACE FUNCTION "NGC_DeleteSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text
)''',
    '''DROP FUNCTION IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping"(integer, text);
DROP FUNCTION IF EXISTS "NGC_DeleteSupergroupAgentgroupMapping"(integer, text, uuid);

CREATE OR REPLACE FUNCTION "NGC_DeleteSupergroupAgentgroupMapping"(
    p_supergroup_id integer,
    p_agentgroup_id text,
    p_tenant_id uuid
)'''
)
text = text.replace(
    '''DELETE FROM "NGC_SupergroupAgentgroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "AgentgroupId" = p_agentgroup_id;''',
    '''DELETE FROM "NGC_SupergroupAgentgroup"
    WHERE "SupergroupId" = p_supergroup_id
      AND "AgentgroupId" = p_agentgroup_id
      AND "TenantId" = p_tenant_id;'''
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

count = text.count('p_tenant_id')
print(f'Updated 01_ngc_functions.sql - {count} p_tenant_id references')
