import os

path = r'RTM\RTM\DBMng.cs'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Add _tenantId field after _machineName field in DBMng class
old_field = 'private string _machineName;'
new_field = '''private string _machineName;
        private readonly Guid _tenantId = RTM.Configuration.AppConfig.TenantId;'''
text = text.replace(old_field, new_field)

# 2. RTSData_SetUserStatus - add TenantId after TimeZone param
old_userstatus = '''parameters.Add(new NpgsqlParameter("@TimeZone", userStatusRequest.TimeZone));
                            parameters.Add(new NpgsqlParameter("@UpdateTime", DateTime.SpecifyKind(userStatusRequest.UpdateTime, DateTimeKind.Utc)));
                            DBAdapter.ExecuteNonQuery("RTSData_SetUserStatus", parameters);'''
new_userstatus = '''parameters.Add(new NpgsqlParameter("@TimeZone", userStatusRequest.TimeZone));
                            parameters.Add(new NpgsqlParameter("@UpdateTime", DateTime.SpecifyKind(userStatusRequest.UpdateTime, DateTimeKind.Utc)));
                            parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
                            DBAdapter.ExecuteNonQuery("RTSData_SetUserStatus", parameters);'''
text = text.replace(old_userstatus, new_userstatus)

# 3. RTSData_SetInteraction - add TenantId after OnDate param
old_interaction = '''parameters.Add(new NpgsqlParameter("@OnDate", interactionRequest.OnDate));
                            DBAdapter.ExecuteNonQuery("RTSData_SetInteraction", parameters);'''
new_interaction = '''parameters.Add(new NpgsqlParameter("@OnDate", interactionRequest.OnDate));
                            parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
                            DBAdapter.ExecuteNonQuery("RTSData_SetInteraction", parameters);'''
text = text.replace(old_interaction, new_interaction)

# 4. RTSData_SetChatMessage - add TenantId after TimeStamp param
old_chat = '''parameters.Add(new NpgsqlParameter("@TimeStamp", interactionRequest.TimeStamp));
                            DBAdapter.ExecuteNonQuery("RTSData_SetChatMessage", parameters);'''
new_chat = '''parameters.Add(new NpgsqlParameter("@TimeStamp", interactionRequest.TimeStamp));
                            parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
                            DBAdapter.ExecuteNonQuery("RTSData_SetChatMessage", parameters);'''
text = text.replace(old_chat, new_chat)

# 5. midnightClear - add TenantId parameter
old_midnight = '''public void midnightClear()
        {
            try
            {
                DBAdapter.ExecuteNonQuery("RTSData_MidnightClear", null);
            }'''
new_midnight = '''public void midnightClear()
        {
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
                DBAdapter.ExecuteNonQuery("RTSData_MidnightClear", parameters);
            }'''
text = text.replace(old_midnight, new_midnight)

# 6. getUsersStatuses - add TenantId param
old_getusers = '''parameters.Add(new NpgsqlParameter("@OnDate", OnDate));
            return DBAdapter.GetDataTable("RTSData_getUsersStatuses", parameters);'''
new_getusers = '''parameters.Add(new NpgsqlParameter("@OnDate", OnDate));
            parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
            return DBAdapter.GetDataTable("RTSData_getUsersStatuses", parameters);'''
text = text.replace(old_getusers, new_getusers)

# 7. getIntercations - add TenantId param
old_getint = '''parameters.Add(new NpgsqlParameter("@OnDate", OnDate));
            return DBAdapter.GetDataTable("RTSData_getInteractions", parameters);'''
new_getint = '''parameters.Add(new NpgsqlParameter("@OnDate", OnDate));
            parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
            return DBAdapter.GetDataTable("RTSData_getInteractions", parameters);'''
text = text.replace(old_getint, new_getint)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f'Updated DBMng.cs - {text.count(chr(10))} lines')
