using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Contracts;
using RTMMaintenance.ReadPlane.Models;
using RTMMaintenance.ReadPlane.Validation;

namespace RTMMaintenance.ReadPlane.Tests;

/// <summary>
/// SF-MS-003 INJECTION SECURITY TESTS.
///
/// These tests are a §4-critical / security re-review gate.
/// Build is NOT done without these passing.
///
/// Test corpus includes: shell metacharacters, path traversal,
/// command injection, null bytes, oversized inputs.
/// </summary>
public class InjectionSecurityTests
{
    private readonly CollectIncidentValidator _validator;
    private readonly JsonSerializerOptions _jsonOptions;

    public InjectionSecurityTests()
    {
        var options = Options.Create(new JobOptions { MaxTimeSpanDays = 7 });
        _validator = new CollectIncidentValidator(options, NullLogger<CollectIncidentValidator>.Instance);

        _jsonOptions = new JsonSerializerOptions
        {
            Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter(allowIntegerValues: false) },
            PropertyNameCaseInsensitive = true
        };
    }

    #region Signal Injection Tests - JsonException on invalid enum values

    [Theory]
    [InlineData("\"; rm -rf")]
    [InlineData("& calc")]
    [InlineData("| whoami")]
    [InlineData("$(id)")]
    [InlineData("`whoami`")]
    [InlineData("eventlog; del")]
    [InlineData("eventlog' OR '1'='1")]
    public void Signal_InjectionAttempt_ThrowsJsonException(string maliciousSignal)
    {
        var json = $"{{\"Since\":\"2026-01-01T00:00:00Z\",\"Until\":\"2026-01-02T00:00:00Z\",\"Signals\":[\"{maliciousSignal}\"]}}";

        var ex = Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CollectIncidentRequest>(json, _jsonOptions));

        ex.Should().NotBeNull();
    }

    [Theory]
    [InlineData("../../etc/passwd")]
    [InlineData("..\\\\..\\\\windows")]
    public void Signal_PathTraversal_ThrowsJsonException(string maliciousSignal)
    {
        var json = $"{{\"Since\":\"2026-01-01T00:00:00Z\",\"Until\":\"2026-01-02T00:00:00Z\",\"Signals\":[\"{maliciousSignal}\"]}}";

        var ex = Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CollectIncidentRequest>(json, _jsonOptions));

        ex.Should().NotBeNull();
    }

    [Fact]
    public void Signal_OversizedInput_ThrowsJsonException()
    {
        var oversizedSignal = new string('A', 10000);
        var json = $"{{\"Since\":\"2026-01-01T00:00:00Z\",\"Until\":\"2026-01-02T00:00:00Z\",\"Signals\":[\"{oversizedSignal}\"]}}";

        var ex = Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CollectIncidentRequest>(json, _jsonOptions));

        ex.Should().NotBeNull();
    }

    [Fact]
    public void Signal_IntegerValue_ThrowsJsonException()
    {
        var json = "{\"Since\":\"2026-01-01T00:00:00Z\",\"Until\":\"2026-01-02T00:00:00Z\",\"Signals\":[999]}";

        var ex = Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CollectIncidentRequest>(json, _jsonOptions));

        ex.Should().NotBeNull();
    }

    [Fact]
    public void Signal_UnknownEnumValue_ThrowsJsonException()
    {
        var json = "{\"Since\":\"2026-01-01T00:00:00Z\",\"Until\":\"2026-01-02T00:00:00Z\",\"Signals\":[\"NotASignal\"]}";

        var ex = Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CollectIncidentRequest>(json, _jsonOptions));

        ex.Should().NotBeNull();
    }

    [Fact]
    public void Signal_ValidEnumValue_Parses()
    {
        var json = "{\"Since\":\"2026-01-01T00:00:00Z\",\"Until\":\"2026-01-02T00:00:00Z\",\"Signals\":[\"EventLog\"]}";

        var request = JsonSerializer.Deserialize<CollectIncidentRequest>(json, _jsonOptions);

        request.Should().NotBeNull();
        request!.Signals.Should().ContainSingle().Which.Should().Be(SignalType.EventLog);
    }

    #endregion

    #region Timestamp Injection Tests

    [Theory]
    [InlineData("\"; rm -rf")]
    [InlineData("& calc")]
    [InlineData("| whoami")]
    [InlineData("$(id)")]
    public void Since_InjectionAttempt_ThrowsJsonException(string maliciousSince)
    {
        var json = $"{{\"Since\":\"{maliciousSince}\",\"Until\":\"2026-01-02T00:00:00Z\",\"Signals\":[\"EventLog\"]}}";

        var ex = Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CollectIncidentRequest>(json, _jsonOptions));

        ex.Should().NotBeNull();
    }

    [Theory]
    [InlineData("\"; rm -rf")]
    [InlineData("& calc")]
    [InlineData("| whoami")]
    [InlineData("$(id)")]
    public void Until_InjectionAttempt_ThrowsJsonException(string maliciousUntil)
    {
        var json = $"{{\"Since\":\"2026-01-01T00:00:00Z\",\"Until\":\"{maliciousUntil}\",\"Signals\":[\"EventLog\"]}}";

        var ex = Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<CollectIncidentRequest>(json, _jsonOptions));

        ex.Should().NotBeNull();
    }

    #endregion

    #region Validation Logic Tests

    [Fact]
    public void Validator_SpanExceeds7Days_Rejects()
    {
        var request = new CollectIncidentRequest
        {
            Since = DateTime.UtcNow.AddDays(-10),
            Until = DateTime.UtcNow,
            Signals = [SignalType.EventLog]
        };

        var result = _validator.Validate(request);

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void Validator_SinceAfterUntil_Rejects()
    {
        var request = new CollectIncidentRequest
        {
            Since = DateTime.UtcNow,
            Until = DateTime.UtcNow.AddDays(-1),
            Signals = [SignalType.EventLog]
        };

        var result = _validator.Validate(request);

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void Validator_EmptySignals_Rejects()
    {
        var request = new CollectIncidentRequest
        {
            Since = DateTime.UtcNow.AddDays(-1),
            Until = DateTime.UtcNow,
            Signals = []
        };

        var result = _validator.Validate(request);

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void Validator_DuplicateSignals_Rejects()
    {
        var request = new CollectIncidentRequest
        {
            Since = DateTime.UtcNow.AddDays(-1),
            Until = DateTime.UtcNow,
            Signals = [SignalType.EventLog, SignalType.EventLog]
        };

        var result = _validator.Validate(request);

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void Validator_FutureUntil_Rejects()
    {
        var request = new CollectIncidentRequest
        {
            Since = DateTime.UtcNow,
            Until = DateTime.UtcNow.AddDays(1),
            Signals = [SignalType.EventLog]
        };

        var result = _validator.Validate(request);

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void Validator_ValidationRejection_DoesNotEchoInput()
    {
        var request = new CollectIncidentRequest
        {
            Since = DateTime.UtcNow.AddDays(-10),
            Until = DateTime.UtcNow,
            Signals = [SignalType.EventLog, SignalType.EventLog]
        };

        var result = _validator.Validate(request);

        result.IsValid.Should().BeFalse();
        result.ErrorMessage.Should().NotContain("EventLog");
        result.ErrorMessage.Should().NotContain(request.Since.ToString());
        result.ErrorMessage.Should().NotContain(request.Until.ToString());
    }

    [Fact]
    public void Validator_ValidRequest_Passes()
    {
        var request = new CollectIncidentRequest
        {
            Since = DateTime.UtcNow.AddDays(-1),
            Until = DateTime.UtcNow,
            Signals = [SignalType.EventLog, SignalType.Health]
        };

        var result = _validator.Validate(request);

        result.IsValid.Should().BeTrue();
    }

    #endregion

    #region SignalScriptMap Tests

    [Fact]
    public void SignalScriptMap_AllSignalsMapped()
    {
        var act = () => SignalScriptMap.VerifyCompleteness();

        act.Should().NotThrow();
    }

    [Fact]
    public void SignalScriptMap_EachSignalMapsToExactlyOneScript()
    {
        var allSignals = Enum.GetValues<SignalType>();
        var scriptIds = new HashSet<string>();

        foreach (var signal in allSignals)
        {
            var scriptId = SignalScriptMap.GetScriptId(signal);

            scriptId.Should().NotBeNullOrEmpty();
            scriptIds.Add(scriptId).Should().BeTrue($"Signal {signal} maps to duplicate script ID");
        }

        scriptIds.Count.Should().Be(allSignals.Length);
    }

    [Fact]
    public void SignalScriptMap_MappedCountEqualsEnumCount()
    {
        var enumCount = Enum.GetValues<SignalType>().Length;

        SignalScriptMap.MappedCount.Should().Be(enumCount);
    }

    #endregion

    #region ArgumentArrayGuard Tests

    [Fact]
    public void ArgumentArrayGuard_ProducesNoShellMetachars()
    {
        var request = new CollectIncidentRequest
        {
            Since = DateTime.UtcNow.AddDays(-1),
            Until = DateTime.UtcNow,
            Signals = [SignalType.EventLog]
        };

        var args = ArgumentArrayGuard.BuildArgumentArray(request, SignalType.EventLog);

        foreach (var arg in args)
        {
            ArgumentArrayGuard.ContainsShellMetachars(arg).Should().BeFalse(
                $"Argument '{arg}' contains shell metacharacters");
        }
    }

    [Fact]
    public void ArgumentArrayGuard_TimestampsAreISO8601()
    {
        var request = new CollectIncidentRequest
        {
            Since = new DateTime(2026, 1, 15, 10, 30, 0, DateTimeKind.Utc),
            Until = new DateTime(2026, 1, 16, 10, 30, 0, DateTimeKind.Utc),
            Signals = [SignalType.EventLog]
        };

        var args = ArgumentArrayGuard.BuildArgumentArray(request, SignalType.EventLog);

        var argList = args.ToList();
        var sinceIdx = argList.IndexOf("-Since") + 1;
        var untilIdx = argList.IndexOf("-Until") + 1;

        argList[sinceIdx].Should().MatchRegex(@"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}");
        argList[untilIdx].Should().MatchRegex(@"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}");
    }

    [Theory]
    [InlineData("|")]
    [InlineData("&")]
    [InlineData(";")]
    [InlineData("$")]
    [InlineData("`")]
    [InlineData("(")]
    [InlineData(")")]
    [InlineData("{")]
    [InlineData("}")]
    [InlineData("<")]
    [InlineData(">")]
    [InlineData("\n")]
    [InlineData("\r")]
    [InlineData("\0")]
    public void ArgumentArrayGuard_DetectsShellMetachar(string metachar)
    {
        ArgumentArrayGuard.ContainsShellMetachars($"safe{metachar}value").Should().BeTrue();
    }

    #endregion
}
