import os

path = r'RTM\RTM\DBMng.cs'

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find and fix SetUserStatus - insert TenantId param before the ExecuteNonQuery call
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    # Check if this line is UpdateTime for UserStatus (has StratTime reference earlier)
    if '@UpdateTime", DateTime.SpecifyKind(userStatusRequest.UpdateTime' in line:
        # Insert TenantId param after this line
        indent = '                            '
        new_lines.append(f'{indent}parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));\n')

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
    f.flush()
    os.fsync(f.fileno())

print(f'Fixed - {len(new_lines)} lines')
