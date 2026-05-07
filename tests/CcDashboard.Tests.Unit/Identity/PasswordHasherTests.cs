using CcDashboard.Infrastructure.Identity;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Identity;

public class PasswordHasherTests
{
    private readonly PasswordHasher _hasher = new();

    [Fact]
    public void Hash_ReturnsNonEmptyString()
    {
        var hash = _hasher.Hash("S0meP@ssword!");
        hash.Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public void Hash_ContainsSaltAndHashSeparatedByColon()
    {
        var hash = _hasher.Hash("S0meP@ssword!");
        hash.Split(':').Should().HaveCount(2);
    }

    [Fact]
    public void Hash_ProducesDifferentOutputForSamePassword()
    {
        var h1 = _hasher.Hash("S0meP@ssword!");
        var h2 = _hasher.Hash("S0meP@ssword!");
        h1.Should().NotBe(h2, "salt must be randomly generated each call");
    }

    [Fact]
    public void Verify_ReturnsTrueForCorrectPassword()
    {
        var hash = _hasher.Hash("C0rrectP@ss#99");
        _hasher.Verify("C0rrectP@ss#99", hash).Should().BeTrue();
    }

    [Fact]
    public void Verify_ReturnsFalseForWrongPassword()
    {
        var hash = _hasher.Hash("C0rrectP@ss#99");
        _hasher.Verify("wr0ngP@ss#99", hash).Should().BeFalse();
    }

    [Fact]
    public void Verify_ReturnsFalseForMalformedHash()
    {
        _hasher.Verify("anypassword", "notavalidhash").Should().BeFalse();
    }

    [Fact]
    public void Verify_ReturnsFalseForEmptyHash()
    {
        _hasher.Verify("anypassword", string.Empty).Should().BeFalse();
    }
}
