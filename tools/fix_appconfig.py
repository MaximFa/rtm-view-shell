import os

path = r'RTM\RTM.Configuration\AppConfig.cs'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Fix: replace backslash-dollar with just dollar
text = text.replace('\\$"AppConfig.TenantId', '$"AppConfig.TenantId')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print('Fixed')
