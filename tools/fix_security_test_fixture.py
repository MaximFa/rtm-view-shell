#!/usr/bin/env python3
"""Fix ApplyService security test fixture — inject token via UseSetting + write SQL without BOM"""
import os

repo = r"D:\Claude\Projects\RTM View Shell"
fixture_path = os.path.join(repo, "tests", "CcDashboard.Tests.Integration", "ApplyService", "ApplyServiceFixture.cs")

with open(fixture_path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix 1: Change CreateWebApplicationFactory to use UseSetting for token (runs earlier than ConfigureAppConfiguration)
# This fix was already applied, check if it's there
if 'builder.UseSetting("ApplyService:Token", tokenToUse);' not in content:
    print("ERROR: UseSetting fix not found - need to apply it first")
    exit(1)

# Fix 2: All SQL file writes must use UTF8 WITHOUT BOM
# PostgreSQL chokes on BOM at the start of SQL files
# Change: Encoding.UTF8 -> new UTF8Encoding(false)

# Add using statement if not present
if "using System.Text;" not in content:
    content = content.replace("using System.Security.Cryptography;",
                              "using System.Security.Cryptography;\nusing System.Text;")

# Replace all Encoding.UTF8 with new UTF8Encoding(false) in File.WriteAllText calls
# Pattern 1: File.WriteAllText(path, content, Encoding.UTF8)
content = content.replace(
    'File.WriteAllText(filePath, sql, Encoding.UTF8);',
    'File.WriteAllText(filePath, sql, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));'
)

content = content.replace(
    'File.WriteAllText(Path.Combine(MigrationsDir, tamperedFile), sql, Encoding.UTF8);',
    'File.WriteAllText(Path.Combine(MigrationsDir, tamperedFile), sql, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));'
)

content = content.replace(
    'File.WriteAllText(Path.Combine(MigrationsDir, noHashFile), sql, Encoding.UTF8);',
    'File.WriteAllText(Path.Combine(MigrationsDir, noHashFile), sql, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));'
)

content = content.replace(
    'File.WriteAllText(Path.Combine(MigrationsDir, badFile), sql, Encoding.UTF8);',
    'File.WriteAllText(Path.Combine(MigrationsDir, badFile), sql, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));'
)

# Also fix manifest writes
content = content.replace(
    'File.WriteAllText(ManifestPath, json, Encoding.UTF8);',
    'File.WriteAllText(ManifestPath, json, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));'
)

# Write with fsync
with open(fixture_path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed: {fixture_path}")
print(f"  - All SQL/JSON file writes now use UTF-8 without BOM")
print(f"  - File size: {os.path.getsize(fixture_path)} bytes")
