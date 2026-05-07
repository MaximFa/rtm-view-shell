using CcDashboard.Application.DTOs;
using CcDashboard.Application.Validators;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Validators;

public class CreateScreenRequestValidatorTests
{
    private readonly CreateScreenRequestValidator _sut = new();

    [Fact]
    public void Valid_name_passes()
    {
        _sut.Validate(new CreateScreenRequest("My Dashboard")).IsValid.Should().BeTrue();
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Empty_name_fails(string name)
    {
        var result = _sut.Validate(new CreateScreenRequest(name));
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void Name_exceeding_256_chars_fails()
    {
        var name = new string('A', 257);
        var result = _sut.Validate(new CreateScreenRequest(name));
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Name");
    }

    [Fact]
    public void Name_at_256_chars_passes()
    {
        var name = new string('A', 256);
        _sut.Validate(new CreateScreenRequest(name)).IsValid.Should().BeTrue();
    }
}
