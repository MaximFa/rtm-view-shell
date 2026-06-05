#!/usr/bin/env python3
"""Fix UserWidgetSettings tests - use JsonDocument.Parse for JSONB comparison."""
import os

path = r"D:\Claude\Projects\RTM View Shell\tests\CcDashboard.Tests.Security\Widgets\UserWidgetSettingsTests.cs"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix test UWS-02: Save_ThenGet_ReturnsPersistedJson
old1 = '''        result.Should().NotBeNullOrEmpty();
        result.Should().Contain("\\"chartType\\":\\"bar\\"");
    }

    // ── 3. Second Save'''

new1 = '''        result.Should().NotBeNullOrEmpty();
        using var doc = System.Text.Json.JsonDocument.Parse(result!);
        doc.RootElement.GetProperty("chartType").GetString().Should().Be("bar");
        doc.RootElement.GetProperty("intervalMinutes").GetInt32().Should().Be(30);
    }

    // ── 3. Second Save'''

content = content.replace(old1, new1)

# Fix test UWS-03: Save_Twice_UpdatesExistingRow_NoDuplicate
old2 = '''        rows.Should().HaveCount(1);
        rows[0].SettingsJson.Should().Contain("\\"chartType\\":\\"bar\\"");
    }

    // ── 4. Delete'''

new2 = '''        rows.Should().HaveCount(1);
        using var doc = System.Text.Json.JsonDocument.Parse(rows[0].SettingsJson);
        doc.RootElement.GetProperty("chartType").GetString().Should().Be("bar");
    }

    // ── 4. Delete'''

content = content.replace(old2, new2)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed: {path}")

# Verify
with open(path, "r", encoding="utf-8") as f:
    verify = f.read()

if "JsonDocument.Parse" in verify:
    print("Verification: JsonDocument.Parse found - fix applied correctly")
else:
    print("ERROR: Fix not applied!")
