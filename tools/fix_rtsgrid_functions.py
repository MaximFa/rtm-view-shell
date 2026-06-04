import os

path = r'RTM\sql\pgsql\03_rtsgrid_read_functions.sql'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# ============================================================================
# RTSGrid_GetAllUnionQueueClassifications - add p_tenant_id and filter NGC_ joins
# ============================================================================
text = text.replace(
    '''DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionQueueClassifications"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionQueueClassifications"()''',
    '''DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionQueueClassifications"();
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionQueueClassifications"(uuid);

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionQueueClassifications"(p_tenant_id uuid)'''
)
text = text.replace(
    '''FROM "NGC_BusinessUnitQueueClassification" u,
         "NGC_BusinessUnit" b,
         "NGC_Site" s
    WHERE b."BusinessUnitId" = u."BusinessUnitId"
      AND b."SiteId" = s."SiteId";''',
    '''FROM "NGC_BusinessUnitQueueClassification" u,
         "NGC_BusinessUnit" b,
         "NGC_Site" s
    WHERE b."BusinessUnitId" = u."BusinessUnitId"
      AND b."SiteId" = s."SiteId"
      AND u."TenantId" = p_tenant_id
      AND b."TenantId" = p_tenant_id
      AND s."TenantId" = p_tenant_id;'''
)

# ============================================================================
# RTSGrid_GetAllUnionUserGroups - add p_tenant_id and filter NGC_ joins
# ============================================================================
text = text.replace(
    '''DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionUserGroups"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionUserGroups"()''',
    '''DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionUserGroups"();
DROP FUNCTION IF EXISTS "RTSGrid_GetAllUnionUserGroups"(uuid);

CREATE OR REPLACE FUNCTION "RTSGrid_GetAllUnionUserGroups"(p_tenant_id uuid)'''
)
text = text.replace(
    '''FROM "NGC_SupergroupAgentgroup" s,
         "NGC_BusinessUnitSupergroup" u,
         "NGC_BusinessUnit" b,
         "NGC_Site" t
    WHERE b."BusinessUnitId" = u."BusinessUnitId"
      AND s."SupergroupId" = u."SupergroupId"
      AND b."SiteId" = t."SiteId";''',
    '''FROM "NGC_SupergroupAgentgroup" s,
         "NGC_BusinessUnitSupergroup" u,
         "NGC_BusinessUnit" b,
         "NGC_Site" t
    WHERE b."BusinessUnitId" = u."BusinessUnitId"
      AND s."SupergroupId" = u."SupergroupId"
      AND b."SiteId" = t."SiteId"
      AND s."TenantId" = p_tenant_id
      AND u."TenantId" = p_tenant_id
      AND b."TenantId" = p_tenant_id
      AND t."TenantId" = p_tenant_id;'''
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

count = text.count('p_tenant_id')
print(f'Updated 03_rtsgrid_read_functions.sql - {count} p_tenant_id references')
