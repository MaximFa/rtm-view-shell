using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit;

/// <summary>
/// Tests for <see cref="ThresholdTextMatch"/> — covers the full truth table from the spec.
/// 7 match types × 9 cell values = 63 core cases, plus edge cases.
/// </summary>
public class ThresholdTextMatchTests
{
    // Pattern used in all tests: "Break"
    private const string Pattern = "Break";

    #region Truth table: 7×9 matrix

    // Row 1: "Break" (exact match)
    [Fact] public void Exact_Equal_Matches() => ThresholdTextMatch.IsMatch("equal", "Break", Pattern).Should().BeTrue();
    [Fact] public void Exact_NotEqual_DoesNotMatch() => ThresholdTextMatch.IsMatch("notequal", "Break", Pattern).Should().BeFalse();
    [Fact] public void Exact_Contains_Matches() => ThresholdTextMatch.IsMatch("contains", "Break", Pattern).Should().BeTrue();
    [Fact] public void Exact_StartsWith_Matches() => ThresholdTextMatch.IsMatch("startswith", "Break", Pattern).Should().BeTrue();
    [Fact] public void Exact_EndsWith_Matches() => ThresholdTextMatch.IsMatch("endswith", "Break", Pattern).Should().BeTrue();
    [Fact] public void Exact_Empty_DoesNotMatch() => ThresholdTextMatch.IsMatch("empty", "Break", Pattern).Should().BeFalse();
    [Fact] public void Exact_NotEmpty_Matches() => ThresholdTextMatch.IsMatch("notempty", "Break", Pattern).Should().BeTrue();

    // Row 2: "break" (different case)
    [Fact] public void DifferentCase_Equal_Matches() => ThresholdTextMatch.IsMatch("equal", "break", Pattern).Should().BeTrue();
    [Fact] public void DifferentCase_NotEqual_DoesNotMatch() => ThresholdTextMatch.IsMatch("notequal", "break", Pattern).Should().BeFalse();
    [Fact] public void DifferentCase_Contains_Matches() => ThresholdTextMatch.IsMatch("contains", "break", Pattern).Should().BeTrue();
    [Fact] public void DifferentCase_StartsWith_Matches() => ThresholdTextMatch.IsMatch("startswith", "break", Pattern).Should().BeTrue();
    [Fact] public void DifferentCase_EndsWith_Matches() => ThresholdTextMatch.IsMatch("endswith", "break", Pattern).Should().BeTrue();
    [Fact] public void DifferentCase_Empty_DoesNotMatch() => ThresholdTextMatch.IsMatch("empty", "break", Pattern).Should().BeFalse();
    [Fact] public void DifferentCase_NotEmpty_Matches() => ThresholdTextMatch.IsMatch("notempty", "break", Pattern).Should().BeTrue();

    // Row 3: "Break time" (pattern at start)
    [Fact] public void AtStart_Equal_DoesNotMatch() => ThresholdTextMatch.IsMatch("equal", "Break time", Pattern).Should().BeFalse();
    [Fact] public void AtStart_NotEqual_Matches() => ThresholdTextMatch.IsMatch("notequal", "Break time", Pattern).Should().BeTrue();
    [Fact] public void AtStart_Contains_Matches() => ThresholdTextMatch.IsMatch("contains", "Break time", Pattern).Should().BeTrue();
    [Fact] public void AtStart_StartsWith_Matches() => ThresholdTextMatch.IsMatch("startswith", "Break time", Pattern).Should().BeTrue();
    [Fact] public void AtStart_EndsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("endswith", "Break time", Pattern).Should().BeFalse();
    [Fact] public void AtStart_Empty_DoesNotMatch() => ThresholdTextMatch.IsMatch("empty", "Break time", Pattern).Should().BeFalse();
    [Fact] public void AtStart_NotEmpty_Matches() => ThresholdTextMatch.IsMatch("notempty", "Break time", Pattern).Should().BeTrue();

    // Row 4: "On Break now" (pattern in middle)
    [Fact] public void InMiddle_Equal_DoesNotMatch() => ThresholdTextMatch.IsMatch("equal", "On Break now", Pattern).Should().BeFalse();
    [Fact] public void InMiddle_NotEqual_Matches() => ThresholdTextMatch.IsMatch("notequal", "On Break now", Pattern).Should().BeTrue();
    [Fact] public void InMiddle_Contains_Matches() => ThresholdTextMatch.IsMatch("contains", "On Break now", Pattern).Should().BeTrue();
    [Fact] public void InMiddle_StartsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("startswith", "On Break now", Pattern).Should().BeFalse();
    [Fact] public void InMiddle_EndsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("endswith", "On Break now", Pattern).Should().BeFalse();
    [Fact] public void InMiddle_Empty_DoesNotMatch() => ThresholdTextMatch.IsMatch("empty", "On Break now", Pattern).Should().BeFalse();
    [Fact] public void InMiddle_NotEmpty_Matches() => ThresholdTextMatch.IsMatch("notempty", "On Break now", Pattern).Should().BeTrue();

    // Row 5: "Long Break" (pattern at end)
    [Fact] public void AtEnd_Equal_DoesNotMatch() => ThresholdTextMatch.IsMatch("equal", "Long Break", Pattern).Should().BeFalse();
    [Fact] public void AtEnd_NotEqual_Matches() => ThresholdTextMatch.IsMatch("notequal", "Long Break", Pattern).Should().BeTrue();
    [Fact] public void AtEnd_Contains_Matches() => ThresholdTextMatch.IsMatch("contains", "Long Break", Pattern).Should().BeTrue();
    [Fact] public void AtEnd_StartsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("startswith", "Long Break", Pattern).Should().BeFalse();
    [Fact] public void AtEnd_EndsWith_Matches() => ThresholdTextMatch.IsMatch("endswith", "Long Break", Pattern).Should().BeTrue();
    [Fact] public void AtEnd_Empty_DoesNotMatch() => ThresholdTextMatch.IsMatch("empty", "Long Break", Pattern).Should().BeFalse();
    [Fact] public void AtEnd_NotEmpty_Matches() => ThresholdTextMatch.IsMatch("notempty", "Long Break", Pattern).Should().BeTrue();

    // Row 6: "" (empty string)
    [Fact] public void EmptyString_Equal_DoesNotMatch() => ThresholdTextMatch.IsMatch("equal", "", Pattern).Should().BeFalse();
    [Fact] public void EmptyString_NotEqual_Matches() => ThresholdTextMatch.IsMatch("notequal", "", Pattern).Should().BeTrue();
    [Fact] public void EmptyString_Contains_DoesNotMatch() => ThresholdTextMatch.IsMatch("contains", "", Pattern).Should().BeFalse();
    [Fact] public void EmptyString_StartsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("startswith", "", Pattern).Should().BeFalse();
    [Fact] public void EmptyString_EndsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("endswith", "", Pattern).Should().BeFalse();
    [Fact] public void EmptyString_Empty_Matches() => ThresholdTextMatch.IsMatch("empty", "", Pattern).Should().BeTrue();
    [Fact] public void EmptyString_NotEmpty_DoesNotMatch() => ThresholdTextMatch.IsMatch("notempty", "", Pattern).Should().BeFalse();

    // Row 7: "   " (whitespace only)
    [Fact] public void WhitespaceOnly_Equal_DoesNotMatch() => ThresholdTextMatch.IsMatch("equal", "   ", Pattern).Should().BeFalse();
    [Fact] public void WhitespaceOnly_NotEqual_Matches() => ThresholdTextMatch.IsMatch("notequal", "   ", Pattern).Should().BeTrue();
    [Fact] public void WhitespaceOnly_Contains_DoesNotMatch() => ThresholdTextMatch.IsMatch("contains", "   ", Pattern).Should().BeFalse();
    [Fact] public void WhitespaceOnly_StartsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("startswith", "   ", Pattern).Should().BeFalse();
    [Fact] public void WhitespaceOnly_EndsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("endswith", "   ", Pattern).Should().BeFalse();
    [Fact] public void WhitespaceOnly_Empty_Matches() => ThresholdTextMatch.IsMatch("empty", "   ", Pattern).Should().BeTrue();
    [Fact] public void WhitespaceOnly_NotEmpty_DoesNotMatch() => ThresholdTextMatch.IsMatch("notempty", "   ", Pattern).Should().BeFalse();

    // Row 8: null (treated as empty string, simulates metric not found)
    [Fact] public void NullValue_Equal_DoesNotMatch() => ThresholdTextMatch.IsMatch("equal", null, Pattern).Should().BeFalse();
    [Fact] public void NullValue_NotEqual_Matches() => ThresholdTextMatch.IsMatch("notequal", null, Pattern).Should().BeTrue();
    [Fact] public void NullValue_Contains_DoesNotMatch() => ThresholdTextMatch.IsMatch("contains", null, Pattern).Should().BeFalse();
    [Fact] public void NullValue_StartsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("startswith", null, Pattern).Should().BeFalse();
    [Fact] public void NullValue_EndsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("endswith", null, Pattern).Should().BeFalse();
    [Fact] public void NullValue_Empty_Matches() => ThresholdTextMatch.IsMatch("empty", null, Pattern).Should().BeTrue();
    [Fact] public void NullValue_NotEmpty_DoesNotMatch() => ThresholdTextMatch.IsMatch("notempty", null, Pattern).Should().BeFalse();

    // Row 9: anomaly values (NaN/Infinity rendered as empty string after fix)
    // These are handled by the widget (FormatTimeString returns ""), so the value reaching IsMatch is ""
    // Tests confirm the empty-string behavior is consistent
    [Fact] public void Anomaly_Equal_DoesNotMatch() => ThresholdTextMatch.IsMatch("equal", "", Pattern).Should().BeFalse();
    [Fact] public void Anomaly_NotEqual_Matches() => ThresholdTextMatch.IsMatch("notequal", "", Pattern).Should().BeTrue();
    [Fact] public void Anomaly_Contains_DoesNotMatch() => ThresholdTextMatch.IsMatch("contains", "", Pattern).Should().BeFalse();
    [Fact] public void Anomaly_StartsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("startswith", "", Pattern).Should().BeFalse();
    [Fact] public void Anomaly_EndsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("endswith", "", Pattern).Should().BeFalse();
    [Fact] public void Anomaly_Empty_Matches() => ThresholdTextMatch.IsMatch("empty", "", Pattern).Should().BeTrue();
    [Fact] public void Anomaly_NotEmpty_DoesNotMatch() => ThresholdTextMatch.IsMatch("notempty", "", Pattern).Should().BeFalse();

    #endregion

    #region Edge cases

    // EDGE: Empty pattern — .NET Contains/StartsWith/EndsWith return true for empty pattern
    [Fact] public void EmptyPattern_Contains_ReturnsTrue() => ThresholdTextMatch.IsMatch("contains", "anything", "").Should().BeTrue();
    [Fact] public void EmptyPattern_StartsWith_ReturnsTrue() => ThresholdTextMatch.IsMatch("startswith", "anything", "").Should().BeTrue();
    [Fact] public void EmptyPattern_EndsWith_ReturnsTrue() => ThresholdTextMatch.IsMatch("endswith", "anything", "").Should().BeTrue();
    [Fact] public void EmptyPattern_Equal_OnlyMatchesEmpty() => ThresholdTextMatch.IsMatch("equal", "", "").Should().BeTrue();
    [Fact] public void EmptyPattern_Equal_DoesNotMatchNonEmpty() => ThresholdTextMatch.IsMatch("equal", "anything", "").Should().BeFalse();

    // Unknown/null match type defaults to "equal"
    [Fact] public void UnknownMatchType_DefaultsToEqual() => ThresholdTextMatch.IsMatch("unknown", "Break", Pattern).Should().BeTrue();
    [Fact] public void NullMatchType_DefaultsToEqual() => ThresholdTextMatch.IsMatch(null, "Break", Pattern).Should().BeTrue();
    [Fact] public void EmptyMatchType_DefaultsToEqual() => ThresholdTextMatch.IsMatch("", "Break", Pattern).Should().BeTrue();

    // Null pattern treated as empty string
    [Fact] public void NullPattern_Contains_ReturnsTrue() => ThresholdTextMatch.IsMatch("contains", "anything", null).Should().BeTrue();
    [Fact] public void NullPattern_Equal_MatchesEmpty() => ThresholdTextMatch.IsMatch("equal", "", null).Should().BeTrue();

    #endregion

    #region IsEmpty tests

    [Fact] public void IsEmpty_Null_ReturnsTrue() => ThresholdTextMatch.IsEmpty(null).Should().BeTrue();
    [Fact] public void IsEmpty_EmptyString_ReturnsTrue() => ThresholdTextMatch.IsEmpty("").Should().BeTrue();
    [Fact] public void IsEmpty_Whitespace_ReturnsTrue() => ThresholdTextMatch.IsEmpty("   ").Should().BeTrue();
    [Fact] public void IsEmpty_Tab_ReturnsTrue() => ThresholdTextMatch.IsEmpty("\t").Should().BeTrue();
    [Fact] public void IsEmpty_Newline_ReturnsTrue() => ThresholdTextMatch.IsEmpty("\n").Should().BeTrue();
    [Fact] public void IsEmpty_NonEmpty_ReturnsFalse() => ThresholdTextMatch.IsEmpty("text").Should().BeFalse();
    [Fact] public void IsEmpty_Zero_ReturnsFalse() => ThresholdTextMatch.IsEmpty("0").Should().BeFalse();
    [Fact] public void IsEmpty_ZeroPercent_ReturnsFalse() => ThresholdTextMatch.IsEmpty("0%").Should().BeFalse();

    #endregion
}