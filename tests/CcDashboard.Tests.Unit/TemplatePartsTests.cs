namespace CcDashboard.Tests.Unit;

using CcDashboard.Contracts.Common;
using FluentAssertions;

public class TemplatePartsTests
{
    [Fact]
    public void Parse_NormalOrder_ReturnsPartsInCorrectOrder()
    {
        // "Showing {0} of {1}" with values [7, 41] should produce: "Showing ", 7, " of ", 41
        var parts = TemplateParts.Parse("Showing {0} of {1}", 7, 41).ToList();

        parts.Should().HaveCount(4);
        parts[0].Should().Be(new TemplateParts.Part(false, "Showing ", -1));
        parts[1].Should().Be(new TemplateParts.Part(true, "7", 0));
        parts[2].Should().Be(new TemplateParts.Part(false, " of ", -1));
        parts[3].Should().Be(new TemplateParts.Part(true, "41", 1));
    }

    [Fact]
    public void Parse_ReversedOrder_ResolvesIndicesCorrectly()
    {
        // "{1} of {0}" with values [7, 41] should produce: "", 41, " of ", 7
        // This is the KEY test: the old Split-based code would incorrectly produce 7, 41
        var parts = TemplateParts.Parse("{1} of {0}", 7, 41).ToList();

        parts.Should().HaveCount(3);
        parts[0].Should().Be(new TemplateParts.Part(true, "41", 1)); // {1} -> values[1] = 41
        parts[1].Should().Be(new TemplateParts.Part(false, " of ", -1));
        parts[2].Should().Be(new TemplateParts.Part(true, "7", 0));  // {0} -> values[0] = 7
    }

    [Fact]
    public void Parse_NoPlaceholders_ReturnsEntireTemplateAsLiteral()
    {
        var parts = TemplateParts.Parse("No placeholders here", 1, 2, 3).ToList();

        parts.Should().HaveCount(1);
        parts[0].Should().Be(new TemplateParts.Part(false, "No placeholders here", -1));
    }

    [Fact]
    public void Parse_RepeatedPlaceholder_ResolvesToSameValue()
    {
        // "{0} and {0} again" should substitute values[0] twice
        var parts = TemplateParts.Parse("{0} and {0} again", "X", "Y").ToList();

        parts.Should().HaveCount(4);
        parts[0].Should().Be(new TemplateParts.Part(true, "X", 0));
        parts[1].Should().Be(new TemplateParts.Part(false, " and ", -1));
        parts[2].Should().Be(new TemplateParts.Part(true, "X", 0));
        parts[3].Should().Be(new TemplateParts.Part(false, " again", -1));
    }

    [Fact]
    public void Parse_MissingValue_ReturnsEmptyString()
    {
        // "{0} and {5}" where values has only 2 elements - {5} should resolve to ""
        var parts = TemplateParts.Parse("{0} and {5}", "A", "B").ToList();

        parts.Should().HaveCount(3);
        parts[0].Should().Be(new TemplateParts.Part(true, "A", 0));
        parts[1].Should().Be(new TemplateParts.Part(false, " and ", -1));
        parts[2].Should().Be(new TemplateParts.Part(true, "", 5)); // Out of range -> empty
    }

    [Fact]
    public void Parse_NullTemplate_ReturnsEmpty()
    {
        var parts = TemplateParts.Parse(null, 1, 2).ToList();
        parts.Should().BeEmpty();
    }

    [Fact]
    public void Parse_EmptyTemplate_ReturnsEmpty()
    {
        var parts = TemplateParts.Parse("", 1, 2).ToList();
        parts.Should().BeEmpty();
    }

    [Fact]
    public void Parse_SinglePlaceholder_Works()
    {
        // "Sorted by: {0}" with value "Name"
        var parts = TemplateParts.Parse("Sorted by: {0}", "Name").ToList();

        parts.Should().HaveCount(2);
        parts[0].Should().Be(new TemplateParts.Part(false, "Sorted by: ", -1));
        parts[1].Should().Be(new TemplateParts.Part(true, "Name", 0));
    }

    [Fact]
    public void HasPlaceholders_WithPlaceholders_ReturnsTrue()
    {
        TemplateParts.HasPlaceholders("Hello {0}").Should().BeTrue();
        TemplateParts.HasPlaceholders("{0} {1} {2}").Should().BeTrue();
    }

    [Fact]
    public void HasPlaceholders_WithoutPlaceholders_ReturnsFalse()
    {
        TemplateParts.HasPlaceholders("No placeholders").Should().BeFalse();
        TemplateParts.HasPlaceholders("").Should().BeFalse();
        TemplateParts.HasPlaceholders(null).Should().BeFalse();
    }

    // =====================================================================
    // NEGATIVE TEST: This test demonstrates that the OLD Split-based approach
    // would produce wrong results for reversed placeholder order.
    // =====================================================================
    [Fact]
    public void OldSplitApproach_ReversedOrder_ProducesWrongResult()
    {
        // This simulates the OLD code behavior:
        // showTpl.Split(new[] { "{0}", "{1}" }, StringSplitOptions.None)
        // Then using parts in order: parts[0], value1, parts[1], value2, parts[2]

        var template = "{1} of {0}"; // Reversed order template
        var pagedRowsCount = 7;
        var filteredRowCount = 41;

        // OLD approach (buggy): Split by placeholders and substitute in fixed order
        var oldParts = template.Split(new[] { "{0}", "{1}" }, StringSplitOptions.None);
        // oldParts = ["", " of ", ""] (3 parts because both {0} and {1} are split out)
        // Then the old code did: parts[0] + value0 + parts[1] + value1 + parts[2]
        // Which produces: "" + 7 + " of " + 41 + "" = "7 of 41"
        // But the template says {1} first, so it SHOULD be "41 of 7"

        var oldResult = oldParts.Length == 3
            ? $"{oldParts[0]}{pagedRowsCount}{oldParts[1]}{filteredRowCount}{oldParts[2]}"
            : string.Format(template, pagedRowsCount, filteredRowCount);

        // The OLD code produces "7 of 41" which is WRONG
        oldResult.Should().Be("7 of 41", "the old Split approach ignores placeholder indices");

        // NEW approach (correct): Parse respects indices
        var newParts = TemplateParts.Parse(template, pagedRowsCount, filteredRowCount).ToList();
        var newResult = string.Join("", newParts.Select(p => p.Text));

        // The NEW code produces "41 of 7" which is CORRECT
        newResult.Should().Be("41 of 7", "the new Parse approach respects placeholder indices");

        // The key assertion: OLD and NEW produce DIFFERENT results for reversed templates
        oldResult.Should().NotBe(newResult, "this proves the old approach had a bug");
    }
}
