namespace CcDashboard.Tests.Unit;

using CcDashboard.Contracts.Common;
using FluentAssertions;

/// <summary>
/// Tests for <see cref="ContrastInk"/> — covers the crash-path defense (non-hex inputs)
/// and the contrast-based ink selection for threshold fills.
/// </summary>
public class ContrastInkTests
{
    #region Non-measurable inputs (must return null, never throw)

    [Fact]
    public void ReadableColorOnFill_Transparent_ReturnsNull()
        => ContrastInk.ReadableColorOnFill("transparent").Should().BeNull();

    [Fact]
    public void ReadableColorOnFill_Default_ReturnsNull()
        => ContrastInk.ReadableColorOnFill("default").Should().BeNull();

    [Fact]
    public void ReadableColorOnFill_EmptyString_ReturnsNull()
        => ContrastInk.ReadableColorOnFill("").Should().BeNull();

    [Fact]
    public void ReadableColorOnFill_Null_ReturnsNull()
        => ContrastInk.ReadableColorOnFill(null).Should().BeNull();

    [Fact]
    public void ReadableColorOnFill_RgbFunction_ReturnsNull()
        => ContrastInk.ReadableColorOnFill("rgb(255,0,0)").Should().BeNull();

    [Fact]
    public void ReadableColorOnFill_InvalidString_ReturnsNull()
        => ContrastInk.ReadableColorOnFill("notacolour").Should().BeNull();

    #endregion

    #region Valid hex inputs (must return correct ink)

    [Fact]
    public void ReadableColorOnFill_HashUpperHex_ReturnsDarkInk()
        => ContrastInk.ReadableColorOnFill("#ABCDEF").Should().Be(ContrastInk.DarkInk);

    [Fact]
    public void ReadableColorOnFill_HashLowerHex_ReturnsDarkInk()
        => ContrastInk.ReadableColorOnFill("#abcdef").Should().Be(ContrastInk.DarkInk);

    [Fact]
    public void ReadableColorOnFill_NoHashUpperHex_ReturnsDarkInk()
        => ContrastInk.ReadableColorOnFill("ABCDEF").Should().Be(ContrastInk.DarkInk);

    [Fact]
    public void ReadableColorOnFill_PastelRed_ReturnsDarkInk()
        => ContrastInk.ReadableColorOnFill("#fee2e2").Should().Be(ContrastInk.DarkInk);

    [Fact]
    public void ReadableColorOnFill_PastelAmber_ReturnsDarkInk()
        => ContrastInk.ReadableColorOnFill("#fef3c7").Should().Be(ContrastInk.DarkInk);

    [Fact]
    public void ReadableColorOnFill_PastelGreen_ReturnsDarkInk()
        => ContrastInk.ReadableColorOnFill("#dcfce7").Should().Be(ContrastInk.DarkInk);

    [Fact]
    public void ReadableColorOnFill_DarkFill_ReturnsLightInk()
        => ContrastInk.ReadableColorOnFill("#7f1d1d").Should().Be(ContrastInk.LightInk);

    [Fact]
    public void ReadableColorOnFill_ShortHashWhite_ReturnsDarkInk()
        => ContrastInk.ReadableColorOnFill("#FFF").Should().Be(ContrastInk.DarkInk);

    [Fact]
    public void ReadableColorOnFill_ShortHashBlack_ReturnsLightInk()
        => ContrastInk.ReadableColorOnFill("#000").Should().Be(ContrastInk.LightInk);

    #endregion

    #region Property-style checks: contrast >= 4.5 for pastels

    [Theory]
    [InlineData("#fee2e2")] // pastel red
    [InlineData("#fef3c7")] // pastel amber
    [InlineData("#dcfce7")] // pastel green
    public void ReadableColorOnFill_Pastels_ContrastIsAtLeast4_5(string fill)
    {
        var ink = ContrastInk.ReadableColorOnFill(fill);
        ink.Should().NotBeNull();

        var contrast = ContrastInk.GetContrastRatio(ink, fill);
        contrast.Should().NotBeNull();
        contrast.Should().BeGreaterThanOrEqualTo(4.5);
    }

    [Fact]
    public void ReadableColorOnFill_DarkFill_ChoosesInkByMeasuredContrast()
    {
        // For #7f1d1d, the returned ink's contrast should beat the other ink's contrast
        const string fill = "#7f1d1d";
        var chosenInk = ContrastInk.ReadableColorOnFill(fill);
        chosenInk.Should().Be(ContrastInk.LightInk);

        var lightContrast = ContrastInk.GetContrastRatio(ContrastInk.LightInk, fill);
        var darkContrast = ContrastInk.GetContrastRatio(ContrastInk.DarkInk, fill);

        lightContrast.Should().NotBeNull();
        darkContrast.Should().NotBeNull();
        lightContrast!.Value.Should().BeGreaterThan(darkContrast!.Value, "light ink should have higher contrast on dark fill");
    }

    #endregion

    #region GetContrastRatio sanity checks

    [Fact]
    public void GetContrastRatio_WhiteOnBlack_Returns21()
    {
        var ratio = ContrastInk.GetContrastRatio("#FFFFFF", "#000000");
        ratio.Should().BeApproximately(21.0, 0.1);
    }

    [Fact]
    public void GetContrastRatio_WhiteOnWhite_Returns1()
    {
        var ratio = ContrastInk.GetContrastRatio("#FFFFFF", "#FFFFFF");
        ratio.Should().BeApproximately(1.0, 0.01);
    }

    [Fact]
    public void GetContrastRatio_InvalidInput_ReturnsNull()
    {
        ContrastInk.GetContrastRatio("transparent", "#FFFFFF").Should().BeNull();
        ContrastInk.GetContrastRatio("#FFFFFF", "rgb(0,0,0)").Should().BeNull();
    }

    #endregion
}
