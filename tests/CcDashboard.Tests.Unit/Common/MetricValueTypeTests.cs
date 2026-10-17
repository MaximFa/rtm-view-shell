using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// The column's type is the METRIC's type, from the catalogue — never deduced from the data.
/// These tests pin that rule and the operator reconciliation that follows from it.
/// </summary>
public class MetricValueTypeTests
{
    // ── The type does not come from the data ─────────────────────────────────

    [Theory]
    [InlineData("Number", MetricValueType.Number)]
    [InlineData("number", MetricValueType.Number)]
    [InlineData("NUMBER", MetricValueType.Number)]
    [InlineData("Time", MetricValueType.Time)]
    [InlineData("time", MetricValueType.Time)]
    [InlineData("TimeMs", MetricValueType.Time)]
    [InlineData("String", MetricValueType.Text)]
    [InlineData("text", MetricValueType.Text)]
    public void Normalize_IsCaseInsensitive(string catalogueValue, string expected)
    {
        // The seeded catalogue stores lower case, older rows use "Number"/"Time": a case-sensitive
        // comparison silently never fires and the type check decides nothing.
        MetricValueType.Normalize(catalogueValue).Should().Be(expected);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("whatever-new-type")]
    public void Normalize_UnknownOrMissing_IsText(string? catalogueValue)
    {
        // Text only disables ordered comparisons; a wrong "number" breaks sorting and thresholds.
        MetricValueType.Normalize(catalogueValue).Should().Be(MetricValueType.Text);
    }

    [Theory]
    [InlineData("07:43")]
    [InlineData("5")]
    [InlineData("")]
    [InlineData("ONPHONE")]
    public void TypeIgnoresTheValue_SameTypeWhateverTheFirstRowHolds(string firstRowValue)
    {
        // The old defect: "В свободном" arrived as 07:43 for one agent and as 5 for another, so the
        // column's type changed with whoever happened to be first. The type now depends on the
        // catalogue only — the value is not even an input.
        _ = firstRowValue;
        MetricValueType.Normalize("String").Should().Be(MetricValueType.Text);
        MetricValueType.IsOrdered("String").Should().BeFalse();
    }

    [Theory]
    [InlineData("Number", true)]
    [InlineData("Time", true)]
    [InlineData("String", false)]
    [InlineData(null, false)]
    public void IsOrdered_OnlyNumberAndTime(string? valueType, bool expected)
        => MetricValueType.IsOrdered(valueType).Should().Be(expected);

    // ── Operators valid for any type are never touched ───────────────────────

    [Theory]
    [InlineData("equal")]
    [InlineData("notequal")]
    [InlineData("empty")]
    [InlineData("notempty")]
    public void FourSharedOperators_FitEveryType(string op)
    {
        MetricValueType.OperatorFitsType(op, "Number").Should().BeTrue();
        MetricValueType.OperatorFitsType(op, "Time").Should().BeTrue();
        MetricValueType.OperatorFitsType(op, "String").Should().BeTrue();
        MetricValueType.NearestOperator(op, "Number").Should().Be(op);
        MetricValueType.NearestOperator(op, "String").Should().Be(op);
    }

    // ── Substitution: the two honest cases ───────────────────────────────────

    [Theory]
    [InlineData("contains", "equal")]
    [InlineData("notcontains", "notequal")]
    public void TextOperatorOnOrderedMetric_IsReplacedByNearest(string saved, string expected)
    {
        // For a number, "contains 5" in practice meant "= 5": the meaning narrows predictably.
        MetricValueType.NearestOperator(saved, "Number").Should().Be(expected);
        MetricValueType.NearestOperator(saved, "Time").Should().Be(expected);
    }

    // ── NEGATIVE HALF: a rule that already fits must come back untouched ─────

    [Theory]
    [InlineData("greater", "Number")]
    [InlineData("greaterequal", "Time")]
    [InlineData("less", "Number")]
    [InlineData("lessequal", "Time")]
    [InlineData("contains", "String")]
    [InlineData("notcontains", "String")]
    [InlineData("startswith", "String")]
    [InlineData("endswith", "String")]
    public void AlreadyFittingOperator_IsReturnedByteForByte(string op, string valueType)
    {
        // Without this half the suite stays green even if the code substitutes everything.
        MetricValueType.OperatorFitsType(op, valueType).Should().BeTrue();
        MetricValueType.NearestOperator(op, valueType).Should().BeSameAs(op);
    }

    // ── No honest nearest operator ───────────────────────────────────────────

    [Theory]
    [InlineData("greater", "String")]
    [InlineData("greaterequal", "String")]
    [InlineData("less", "String")]
    [InlineData("lessequal", "String")]
    [InlineData("startswith", "Number")]
    [InlineData("endswith", "Time")]
    public void SixCasesWithNoCounterpart_BecomeEqual(string op, string valueType)
    {
        // Decided by the operator on 2026-10-17 with the cost stated: every substitution NARROWS
        // the set of rows. "Status greater than 5" on a text metric becomes "status = 5", and
        // "calls starting with 1" becomes "calls = 1", so 10, 15 and 100 stop passing. A narrowed
        // filter is visible as "too few rows"; a widened one looks like a filter that does nothing.
        MetricValueType.OperatorFitsType(op, valueType).Should().BeFalse();
        MetricValueType.NearestOperator(op, valueType).Should().Be("equal");
    }

    [Fact]
    public void EverySubstitutionIsDefined_NothingIsLeftWithoutAnOperator()
    {
        // No case may come back without an operator: that was the earlier design and it is gone.
        var operators = new[]
        {
            "equal", "notequal", "empty", "notempty",
            "greater", "greaterequal", "less", "lessequal",
            "contains", "notcontains", "startswith", "endswith"
        };

        foreach (var op in operators)
        foreach (var valueType in new[] { "Number", "Time", "String" })
            MetricValueType.NearestOperator(op, valueType)
                .Should().NotBeNullOrEmpty($"{op} on {valueType} must resolve to some operator");
    }
}
