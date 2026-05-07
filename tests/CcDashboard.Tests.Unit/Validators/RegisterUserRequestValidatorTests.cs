using CcDashboard.Application.DTOs;
using CcDashboard.Application.Validators;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Validators;

public class RegisterUserRequestValidatorTests
{
    private readonly RegisterUserRequestValidator _sut = new();

    private static RegisterUserRequest Valid() =>
        new("user@example.com", "Test User", "ValidPass1!xyz");

    [Fact]
    public void Valid_request_passes()
    {
        _sut.Validate(Valid()).IsValid.Should().BeTrue();
    }

    [Theory]
    [InlineData("")]
    [InlineData("notanemail")]
    [InlineData("missing@")]
    public void Invalid_email_fails(string email)
    {
        var result = _sut.Validate(Valid() with { Email = email });
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Email");
    }

    [Fact]
    public void Empty_display_name_fails()
    {
        var result = _sut.Validate(Valid() with { DisplayName = "" });
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "DisplayName");
    }

    [Theory]
    [InlineData("short1!A")]          // < 12 chars
    [InlineData("alllowercase1!")]     // no uppercase
    [InlineData("ALLUPPERCASE1!")]     // no lowercase
    [InlineData("NoDigitsHere!!")]     // no digit
    [InlineData("NoSpecialChar1A")]    // no special char
    public void Weak_password_fails(string password)
    {
        var result = _sut.Validate(Valid() with { Password = password });
        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName == "Password");
    }

    [Theory]
    [InlineData("StrongP@ss12")]
    [InlineData("Another#Valid9Pass")]
    [InlineData("Aa1!Aa1!Aa1!")]
    public void Strong_password_passes(string password)
    {
        _sut.Validate(Valid() with { Password = password }).IsValid.Should().BeTrue();
    }
}
