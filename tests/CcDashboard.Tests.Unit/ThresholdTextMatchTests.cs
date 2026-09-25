using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit;

/// <summary>
/// Tests for <see cref="ThresholdTextMatch"/> — covers the full truth table from the spec.
/// 7 match types × 9 cell values = 63 core cases, plus edge cases and empty pattern matrix.
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
    [Fact] public void Anomaly_Equal_DoesNotMatch() => ThresholdTextMatch.IsMatch("equal", "", Pattern).Should().BeFalse();
    [Fact] public void Anomaly_NotEqual_Matches() => ThresholdTextMatch.IsMatch("notequal", "", Pattern).Should().BeTrue();
    [Fact] public void Anomaly_Contains_DoesNotMatch() => ThresholdTextMatch.IsMatch("contains", "", Pattern).Should().BeFalse();
    [Fact] public void Anomaly_StartsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("startswith", "", Pattern).Should().BeFalse();
    [Fact] public void Anomaly_EndsWith_DoesNotMatch() => ThresholdTextMatch.IsMatch("endswith", "", Pattern).Should().BeFalse();
    [Fact] public void Anomaly_Empty_Matches() => ThresholdTextMatch.IsMatch("empty", "", Pattern).Should().BeTrue();
    [Fact] public void Anomaly_NotEmpty_DoesNotMatch() => ThresholdTextMatch.IsMatch("notempty", "", Pattern).Should().BeFalse();

    #endregion

    #region Edge cases — empty pattern (existing tests, 4 changed)

    // CHANGED: these 4 tests previously expected true, now false (renamed for clarity)
    [Fact] public void EmptyPattern_Contains_NeverMatches() => ThresholdTextMatch.IsMatch("contains", "anything", "").Should().BeFalse();
    [Fact] public void EmptyPattern_StartsWith_NeverMatches() => ThresholdTextMatch.IsMatch("startswith", "anything", "").Should().BeFalse();
    [Fact] public void EmptyPattern_EndsWith_NeverMatches() => ThresholdTextMatch.IsMatch("endswith", "anything", "").Should().BeFalse();
    [Fact] public void EmptyPattern_Equal_NeverMatches() => ThresholdTextMatch.IsMatch("equal", "", "").Should().BeFalse();
    // UNCHANGED: this test already expected false
    [Fact] public void EmptyPattern_Equal_DoesNotMatchNonEmpty() => ThresholdTextMatch.IsMatch("equal", "anything", "").Should().BeFalse();

    #endregion

    #region Empty pattern full matrix — 45 new tests (5 types × 3 patterns × 3 cells)

    // All must return false: an empty pattern never matches

    // === equal with null pattern ===
    [Fact] public void EmptyPattern_Null_Equal_Text_False() => ThresholdTextMatch.IsMatch("equal", "text", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_Equal_Empty_False() => ThresholdTextMatch.IsMatch("equal", "", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_Equal_Whitespace_False() => ThresholdTextMatch.IsMatch("equal", "   ", null).Should().BeFalse();
    // === equal with "" pattern ===
    [Fact] public void EmptyPattern_String_Equal_Text_False() => ThresholdTextMatch.IsMatch("equal", "text", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_Equal_Empty_False() => ThresholdTextMatch.IsMatch("equal", "", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_Equal_Whitespace_False() => ThresholdTextMatch.IsMatch("equal", "   ", "").Should().BeFalse();
    // === equal with "   " pattern ===
    [Fact] public void EmptyPattern_Ws_Equal_Text_False() => ThresholdTextMatch.IsMatch("equal", "text", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_Equal_Empty_False() => ThresholdTextMatch.IsMatch("equal", "", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_Equal_Whitespace_False() => ThresholdTextMatch.IsMatch("equal", "   ", "   ").Should().BeFalse();

    // === notequal with null pattern ===
    [Fact] public void EmptyPattern_Null_NotEqual_Text_False() => ThresholdTextMatch.IsMatch("notequal", "text", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_NotEqual_Empty_False() => ThresholdTextMatch.IsMatch("notequal", "", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_NotEqual_Whitespace_False() => ThresholdTextMatch.IsMatch("notequal", "   ", null).Should().BeFalse();
    // === notequal with "" pattern ===
    [Fact] public void EmptyPattern_String_NotEqual_Text_False() => ThresholdTextMatch.IsMatch("notequal", "text", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_NotEqual_Empty_False() => ThresholdTextMatch.IsMatch("notequal", "", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_NotEqual_Whitespace_False() => ThresholdTextMatch.IsMatch("notequal", "   ", "").Should().BeFalse();
    // === notequal with "   " pattern ===
    [Fact] public void EmptyPattern_Ws_NotEqual_Text_False() => ThresholdTextMatch.IsMatch("notequal", "text", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_NotEqual_Empty_False() => ThresholdTextMatch.IsMatch("notequal", "", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_NotEqual_Whitespace_False() => ThresholdTextMatch.IsMatch("notequal", "   ", "   ").Should().BeFalse();

    // === contains with null pattern ===
    [Fact] public void EmptyPattern_Null_Contains_Text_False() => ThresholdTextMatch.IsMatch("contains", "text", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_Contains_Empty_False() => ThresholdTextMatch.IsMatch("contains", "", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_Contains_Whitespace_False() => ThresholdTextMatch.IsMatch("contains", "   ", null).Should().BeFalse();
    // === contains with "" pattern ===
    [Fact] public void EmptyPattern_String_Contains_Text_False() => ThresholdTextMatch.IsMatch("contains", "text", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_Contains_Empty_False() => ThresholdTextMatch.IsMatch("contains", "", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_Contains_Whitespace_False() => ThresholdTextMatch.IsMatch("contains", "   ", "").Should().BeFalse();
    // === contains with "   " pattern ===
    [Fact] public void EmptyPattern_Ws_Contains_Text_False() => ThresholdTextMatch.IsMatch("contains", "text", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_Contains_Empty_False() => ThresholdTextMatch.IsMatch("contains", "", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_Contains_Whitespace_False() => ThresholdTextMatch.IsMatch("contains", "   ", "   ").Should().BeFalse();

    // === startswith with null pattern ===
    [Fact] public void EmptyPattern_Null_StartsWith_Text_False() => ThresholdTextMatch.IsMatch("startswith", "text", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_StartsWith_Empty_False() => ThresholdTextMatch.IsMatch("startswith", "", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_StartsWith_Whitespace_False() => ThresholdTextMatch.IsMatch("startswith", "   ", null).Should().BeFalse();
    // === startswith with "" pattern ===
    [Fact] public void EmptyPattern_String_StartsWith_Text_False() => ThresholdTextMatch.IsMatch("startswith", "text", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_StartsWith_Empty_False() => ThresholdTextMatch.IsMatch("startswith", "", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_StartsWith_Whitespace_False() => ThresholdTextMatch.IsMatch("startswith", "   ", "").Should().BeFalse();
    // === startswith with "   " pattern ===
    [Fact] public void EmptyPattern_Ws_StartsWith_Text_False() => ThresholdTextMatch.IsMatch("startswith", "text", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_StartsWith_Empty_False() => ThresholdTextMatch.IsMatch("startswith", "", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_StartsWith_Whitespace_False() => ThresholdTextMatch.IsMatch("startswith", "   ", "   ").Should().BeFalse();

    // === endswith with null pattern ===
    [Fact] public void EmptyPattern_Null_EndsWith_Text_False() => ThresholdTextMatch.IsMatch("endswith", "text", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_EndsWith_Empty_False() => ThresholdTextMatch.IsMatch("endswith", "", null).Should().BeFalse();
    [Fact] public void EmptyPattern_Null_EndsWith_Whitespace_False() => ThresholdTextMatch.IsMatch("endswith", "   ", null).Should().BeFalse();
    // === endswith with "" pattern ===
    [Fact] public void EmptyPattern_String_EndsWith_Text_False() => ThresholdTextMatch.IsMatch("endswith", "text", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_EndsWith_Empty_False() => ThresholdTextMatch.IsMatch("endswith", "", "").Should().BeFalse();
    [Fact] public void EmptyPattern_String_EndsWith_Whitespace_False() => ThresholdTextMatch.IsMatch("endswith", "   ", "").Should().BeFalse();
    // === endswith with "   " pattern ===
    [Fact] public void EmptyPattern_Ws_EndsWith_Text_False() => ThresholdTextMatch.IsMatch("endswith", "text", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_EndsWith_Empty_False() => ThresholdTextMatch.IsMatch("endswith", "", "   ").Should().BeFalse();
    [Fact] public void EmptyPattern_Ws_EndsWith_Whitespace_False() => ThresholdTextMatch.IsMatch("endswith", "   ", "   ").Should().BeFalse();

    #endregion

    #region Edge cases — other

    // Unknown/null match type defaults to "equal"
    [Fact] public void UnknownMatchType_DefaultsToEqual() => ThresholdTextMatch.IsMatch("unknown", "Break", Pattern).Should().BeTrue();
    [Fact] public void NullMatchType_DefaultsToEqual() => ThresholdTextMatch.IsMatch(null, "Break", Pattern).Should().BeTrue();
    [Fact] public void EmptyMatchType_DefaultsToEqual() => ThresholdTextMatch.IsMatch("", "Break", Pattern).Should().BeTrue();

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
