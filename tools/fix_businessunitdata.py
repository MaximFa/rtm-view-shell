import os

path = r'RTM\RTM\BusinessUnitData.cs'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Add using statement for Configuration namespace at top
if 'using RTM.Configuration;' not in text:
    text = text.replace('using RTM.Tools;', 'using RTM.Tools;\nusing RTM.Configuration;')

# Pattern: For functions that have no parameters (null), add TenantId param
# NGC_GetBusinessUnitTable
text = text.replace(
    'var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitTable", null);',
    '''var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitTable", parameters);'''
)

# NGC_GetSupergroupTable
text = text.replace(
    'var dataTable = DBAdapter.GetDataTable("NGC_GetSupergroupTable", null);',
    '''var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                var dataTable = DBAdapter.GetDataTable("NGC_GetSupergroupTable", parameters);'''
)

# NGC_GetBusinessUnitQueueClassificationTable
text = text.replace(
    'var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitQueueClassificationTable", null);',
    '''var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitQueueClassificationTable", parameters);'''
)

# NGC_GetBusinessUnitSupergroupTable
text = text.replace(
    'var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitSupergroupTable", null);',
    '''var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitSupergroupTable", parameters);'''
)

# NGC_GetSupergroupAgentgroupTable
text = text.replace(
    'var dataTable = DBAdapter.GetDataTable("NGC_GetSupergroupAgentgroupTable", null);',
    '''var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                var dataTable = DBAdapter.GetDataTable("NGC_GetSupergroupAgentgroupTable", parameters);'''
)

# NGC_CreateBusinessUnit - add TenantId before GetScalar
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                int businessUnitID = Convert.ToInt32(DBAdapter.GetScalar("NGC_CreateBusinessUnit", parameters));''',
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                int businessUnitID = Convert.ToInt32(DBAdapter.GetScalar("NGC_CreateBusinessUnit", parameters));'''
)

# NGC_DeleteBusinessUnit - add TenantId
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@BusinessUnitID", businessUnitID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnit", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@BusinessUnitID", businessUnitID));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnit", parameters);'''
)

# NGC_ModifyBusinessUnit - add TenantId
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@Description", description));
                DBAdapter.ExecuteNonQuery("NGC_ModifyBusinessUnit", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@Description", description));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_ModifyBusinessUnit", parameters);'''
)

# NGC_CreateSupergroup (first overload - returns int)
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                supergroupId = Convert.ToInt32(DBAdapter.GetScalar("NGC_CreateSupergroup", parameters));''',
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                supergroupId = Convert.ToInt32(DBAdapter.GetScalar("NGC_CreateSupergroup", parameters));'''
)

# NGC_CreateSupergroup (second overload - returns bool, has SupergroupID param)
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@SupergroupID", id));
                parameters.Add(new NpgsqlParameter("@SupergroupName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                DBAdapter.ExecuteNonQuery("NGC_CreateSupergroup", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@SupergroupID", id));
                parameters.Add(new NpgsqlParameter("@SupergroupName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_CreateSupergroup", parameters);'''
)

# NGC_DeleteSupergroup - add TenantId
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteSupergroup", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_DeleteSupergroup", parameters);'''
)

# NGC_ModifySupergroup - add TenantId
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                parameters.Add(new NpgsqlParameter("@SupergroupName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                DBAdapter.ExecuteNonQuery("NGC_ModifySupergroup", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                parameters.Add(new NpgsqlParameter("@SupergroupName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_ModifySupergroup", parameters);'''
)

# NGC_CreateBusinessUnitQueueClassificationMapping
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                DBAdapter.ExecuteNonQuery("NGC_CreateBusinessUnitQueueClassificationMapping", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_CreateBusinessUnitQueueClassificationMapping", parameters);'''
)

# NGC_DeleteBusinessUnitQueueClassificationMapping
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@ClassificationID", classificationID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnitQueueClassificationMapping", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@ClassificationID", classificationID));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnitQueueClassificationMapping", parameters);'''
)

# NGC_CreateBusinessUnitSupergroupMapping
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                DBAdapter.ExecuteNonQuery("NGC_CreateBusinessUnitSupergroupMapping", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_CreateBusinessUnitSupergroupMapping", parameters);'''
)

# NGC_DeleteBusinessUnitSupergroupMapping
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnitSupergroupMapping", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnitSupergroupMapping", parameters);'''
)

# NGC_CreateSupergroupAgentgroupMapping
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                DBAdapter.ExecuteNonQuery("NGC_CreateSupergroupAgentgroupMapping", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_CreateSupergroupAgentgroupMapping", parameters);'''
)

# NGC_DeleteSupergroupAgentgroupMapping
text = text.replace(
    '''parameters.Add(new NpgsqlParameter("@AgentgroupID", agentgroupID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteSupergroupAgentgroupMapping", parameters);''',
    '''parameters.Add(new NpgsqlParameter("@AgentgroupID", agentgroupID));
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                DBAdapter.ExecuteNonQuery("NGC_DeleteSupergroupAgentgroupMapping", parameters);'''
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

# Count TenantId occurrences
count = text.count('@TenantId')
print(f'Updated BusinessUnitData.cs - {count} TenantId params added')
