import os

path = r'RTM\RTM\RealtimeData.cs'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Add using statement for Configuration namespace
if 'using RTM.Configuration;' not in text:
    text = text.replace('using RTM.Tools;', 'using RTM.Tools;\nusing RTM.Configuration;')

# NGC_GetSiteTable - add TenantId
text = text.replace(
    'var dataTable = DBAdapter.GetDataTable("NGC_GetSiteTable", null);',
    '''var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                var dataTable = DBAdapter.GetDataTable("NGC_GetSiteTable", parameters);'''
)

# RTSGrid_GetAllUnionQueueClassifications - add TenantId
text = text.replace(
    'var dataTable = DBAdapter.GetDataTable("RTSGrid_GetAllUnionQueueClassifications", null);',
    '''var parameters = new List<NpgsqlParameter>();
            parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetAllUnionQueueClassifications", parameters);'''
)

# RTSGrid_GetAllUnionUserGroups - add TenantId
text = text.replace(
    'var dataTable = DBAdapter.GetDataTable("RTSGrid_GetAllUnionUserGroups", null);',
    '''var parameters = new List<NpgsqlParameter>();
            parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetAllUnionUserGroups", parameters);'''
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

count = text.count('@TenantId')
print(f'Updated RealtimeData.cs - {count} TenantId params added')
