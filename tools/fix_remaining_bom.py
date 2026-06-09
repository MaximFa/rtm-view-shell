#!/usr/bin/env python3
"""Fix remaining Encoding.UTF8 usages in manifest writes"""
import os

repo = r"D:\Claude\Projects\RTM View Shell"
fixture_path = os.path.join(repo, "tests", "CcDashboard.Tests.Integration", "ApplyService", "ApplyServiceFixture.cs")

with open(fixture_path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix remaining manifest writes that still use Encoding.UTF8
old1 = 'File.WriteAllText(ManifestPath, JsonSerializer.Serialize(manifest), Encoding.UTF8);'
new1 = 'File.WriteAllText(ManifestPath, JsonSerializer.Serialize(manifest), new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));'

count = content.count(old1)
content = content.replace(old1, new1)

# Write with fsync
with open(fixture_path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed: {fixture_path}")
print(f"  - Replaced {count} occurrences of Encoding.UTF8 in manifest writes")
print(f"  - File size: {os.path.getsize(fixture_path)} bytes")
