import os

# ============================================================================
# fix_set_interaction.sql
# ============================================================================
path1 = r'RTM\staging\fix_set_interaction.sql'

with open(path1, 'r', encoding='utf-8') as f:
    text = f.read()

# Add p_tenant_id as last parameter
text = text.replace(
    '''p_on_date               text                -- @OnDate
)''',
    '''p_on_date               text,               -- @OnDate
    p_tenant_id             uuid                -- @TenantId
)'''
)

# Add TenantId to INSERT column list
text = text.replace(
    '''"IsCallbackRequest", "TimeZone"
    )''',
    '''"IsCallbackRequest", "TimeZone", "TenantId"
    )'''
)

# Add p_tenant_id to VALUES
text = text.replace(
    '''p_is_callback_request, p_time_zone
    )''',
    '''p_is_callback_request, p_time_zone, p_tenant_id
    )'''
)

# Add TenantId to ON CONFLICT UPDATE
text = text.replace(
    '''"IsCallbackRequest"   = EXCLUDED."IsCallbackRequest",
        "TimeZone"            = EXCLUDED."TimeZone";''',
    '''"IsCallbackRequest"   = EXCLUDED."IsCallbackRequest",
        "TimeZone"            = EXCLUDED."TimeZone",
        "TenantId"            = EXCLUDED."TenantId";'''
)

with open(path1, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f'Updated fix_set_interaction.sql - {text.count("TenantId")} TenantId references')

# ============================================================================
# fix_set_userstatus.sql
# ============================================================================
path2 = r'RTM\staging\fix_set_userstatus.sql'

with open(path2, 'r', encoding='utf-8') as f:
    text = f.read()

# Add p_tenant_id as last parameter
text = text.replace(
    '''p_update_time       timestamptz         -- @UpdateTime
)''',
    '''p_update_time       timestamptz,        -- @UpdateTime
    p_tenant_id         uuid                -- @TenantId
)'''
)

# Add TenantId to INSERT column list
text = text.replace(
    '''"UpdateTime", "DisplayName", "TimeZone"
    )''',
    '''"UpdateTime", "DisplayName", "TimeZone", "TenantId"
    )'''
)

# Add p_tenant_id to VALUES
text = text.replace(
    '''p_update_time, p_display_name, p_time_zone
    )''',
    '''p_update_time, p_display_name, p_time_zone, p_tenant_id
    )'''
)

# Add TenantId to ON CONFLICT UPDATE
text = text.replace(
    '''"DisplayName"   = EXCLUDED."DisplayName",
        "TimeZone"      = EXCLUDED."TimeZone";''',
    '''"DisplayName"   = EXCLUDED."DisplayName",
        "TimeZone"      = EXCLUDED."TimeZone",
        "TenantId"      = EXCLUDED."TenantId";'''
)

with open(path2, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f'Updated fix_set_userstatus.sql - {text.count("TenantId")} TenantId references')
