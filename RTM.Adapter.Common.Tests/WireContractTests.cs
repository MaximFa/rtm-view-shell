using RTM.Tools;
using RTM.Types;
using Newtonsoft.Json;
using Xunit;

namespace RTM.Adapter.Common.Tests;

/// <summary>
/// WIRE contract tests per CLAUDE.md §48 [WIRE-01..05]
/// Guards the adapter-side serialization format.
/// </summary>
public class WireContractTests
{
    /// <summary>
    /// [WIRE-02] DateTime format: "yyyy-MM-ddTHH:mm:ss.fffffffK"
    /// </summary>
    [Fact]
    public void DateTimeFormat_MatchesWire02Spec()
    {
        var utcDate = new DateTime(2026, 7, 11, 8, 4, 5, DateTimeKind.Utc);
        var dict = new Dictionary<string, object> { { "d", utcDate } };
        
        var json = DictionarySerializer.SerializeToJson(dict);
        
        // Must contain the ISO 8601 format with 7-digit fractional seconds and Z suffix
        Assert.Contains("2026-07-11T08:04:05.0000000Z", json);
    }

    /// <summary>
    /// [WIRE-01] userStatusChanged dict round-trips with case-sensitive keys
    /// </summary>
    [Fact]
    public void UserStatusChangedDict_RoundTrips_CaseSensitiveKeys()
    {
        var dict = new Dictionary<string, object>
        {
            { "method", "userStatusChanged" },
            { "userId", "agent123" },
            { "statusId", "AVAILABLE" },
            { "statusName", "Available" },
            { "statusGroup", "Ready" },
            { "loggedIn", true },
            { "onPhone", false },
            { "messageId", "msg-001" }
        };
        
        var json = DictionarySerializer.SerializeToJson(dict);
        var restored = DictionarySerializer.DeserializeFromJson(json);
        
        // All keys must be preserved exactly (case-sensitive)
        Assert.Equal("userStatusChanged", DictionarySerializer.getString(restored["method"]));
        Assert.Equal("agent123", DictionarySerializer.getString(restored["userId"]));
        Assert.Equal("AVAILABLE", DictionarySerializer.getString(restored["statusId"]));
        Assert.Equal("Available", DictionarySerializer.getString(restored["statusName"]));
        Assert.Equal("Ready", DictionarySerializer.getString(restored["statusGroup"]));
        Assert.True(DictionarySerializer.getBool(restored["loggedIn"]));
        Assert.False(DictionarySerializer.getBool(restored["onPhone"]));
        Assert.Equal("msg-001", DictionarySerializer.getString(restored["messageId"]));
        
        // Verify case sensitivity: "Method" (wrong case) should NOT exist
        Assert.False(restored.ContainsKey("Method"));
        Assert.False(restored.ContainsKey("UserId"));
    }

    /// <summary>
    /// [WIRE-03] Agent DTO uses PascalCase property names (default Newtonsoft behavior)
    /// </summary>
    [Fact]
    public void AgentDto_UsesPascalCasePropertyNames()
    {
        var agents = new List<Agent>
        {
            new Agent
            {
                UserId = "u1",
                DisplayName = "Agent One",
                WorkerSid = "ws1",
                StatusId = "AVAILABLE",
                LoggedIn = true
            }
        };
        
        var json = JsonConvert.SerializeObject(agents);
        
        // PascalCase property names (NOT camelCase)
        Assert.Contains("\"UserId\"", json);
        Assert.Contains("\"DisplayName\"", json);
        Assert.Contains("\"WorkerSid\"", json);
        Assert.Contains("\"StatusId\"", json);
        Assert.Contains("\"LoggedIn\"", json);
        
        // NOT camelCase
        Assert.DoesNotContain("\"userId\"", json);
        Assert.DoesNotContain("\"displayName\"", json);
    }

    /// <summary>
    /// [WIRE-05] Serializer settings parity - DateFormatString is exact
    /// </summary>
    [Fact]
    public void SerializerSettings_DateFormatStringIsExact()
    {
        // Round-trip through serialization
        var originalDate = new DateTime(2026, 1, 15, 14, 30, 45, 123, DateTimeKind.Utc)
            .AddTicks(4567); // Add sub-millisecond precision
        
        var dict = new Dictionary<string, object> { { "timestamp", originalDate } };
        var json = DictionarySerializer.SerializeToJson(dict);
        
        // The format should have exactly 7 fractional digits
        // 123ms + 4567 ticks = 1234567 fractional (0.1234567 seconds)
        Assert.Contains("T14:30:45.1234567Z", json);
    }

    /// <summary>
    /// All 10 method dispatch keys are properly handled (smoke test)
    /// </summary>
    [Theory]
    [InlineData("setStatistic")]
    [InlineData("userStatusChanged")]
    [InlineData("userWorkgroupActivation")]
    [InlineData("userConfigurationChanged")]
    [InlineData("interactionChanged")]
    [InlineData("interactionRemoved")]
    [InlineData("setUsers")]
    [InlineData("setSkills")]
    [InlineData("setWorkgroups")]
    [InlineData("messageEventReceived")]
    public void MethodDispatchKey_RoundTrips(string methodName)
    {
        var dict = new Dictionary<string, object> { { "method", methodName } };
        var json = DictionarySerializer.SerializeToJson(dict);
        var restored = DictionarySerializer.DeserializeFromJson(json);
        
        Assert.Equal(methodName, DictionarySerializer.getString(restored["method"]));
    }
}
