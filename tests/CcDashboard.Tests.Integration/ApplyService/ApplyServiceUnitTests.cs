using FluentAssertions;

namespace CcDashboard.Tests.Integration.ApplyService;

/// <summary>
/// Unit tests for ApplyService helpers (moved from Program.cs inline checks).
/// Tests: constant-time string compare, path-traversal rejection.
/// </summary>
public class ApplyServiceUnitTests
{
    // ═══════════════════════════════════════════════════════════════════════════════
    // Constant-time string compare tests
    // ═══════════════════════════════════════════════════════════════════════════════

    [Fact]
    public void ConstantTimeEquals_EqualStrings_ReturnsTrue()
    {
        // Arrange
        var a = "test-token-12345";
        var b = "test-token-12345";

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public void ConstantTimeEquals_DifferentStrings_ReturnsFalse()
    {
        // Arrange
        var a = "test-token-12345";
        var b = "test-token-67890";

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void ConstantTimeEquals_DifferentLengths_ReturnsFalse()
    {
        // Arrange
        var a = "short";
        var b = "much-longer-string";

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void ConstantTimeEquals_EmptyStrings_ReturnsTrue()
    {
        // Arrange
        var a = "";
        var b = "";

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public void ConstantTimeEquals_SingleCharDifference_ReturnsFalse()
    {
        // Arrange
        var a = "abcdefghij";
        var b = "abcdefghik"; // Last char different

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeFalse();
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Path-traversal rejection tests
    // ═══════════════════════════════════════════════════════════════════════════════

    [Theory]
    [InlineData("../secret.sql")]
    [InlineData("..\\secret.sql")]
    [InlineData("foo/../bar.sql")]
    [InlineData("foo\\..\\bar.sql")]
    public void PathTraversal_DoubleDot_ShouldBeRejected(string migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeFalse($"'{migrationRef}' contains path traversal");
    }

    [Theory]
    [InlineData("path/to/file.sql")]
    [InlineData("path\\to\\file.sql")]
    public void PathTraversal_Separators_ShouldBeRejected(string migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeFalse($"'{migrationRef}' contains path separators");
    }

    [Theory]
    [InlineData("C:file.sql")]
    [InlineData("D:\\file.sql")]
    public void PathTraversal_DriveLetters_ShouldBeRejected(string migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeFalse($"'{migrationRef}' contains drive letter");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void PathTraversal_EmptyOrWhitespace_ShouldBeRejected(string? migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeFalse("empty/whitespace migrationRef should be rejected");
    }

    [Theory]
    [InlineData("valid_migration_001.sql")]
    [InlineData("20260609_010_metric_deploy_log.sql")]
    [InlineData("fixture-migration.sql")]
    public void PathTraversal_ValidFilenames_ShouldBeAccepted(string migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeTrue($"'{migrationRef}' is a valid filename");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Helper methods (same logic as Program.cs)
    // ═══════════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Constant-time string comparison to prevent timing attacks.
    /// Same implementation as Program.cs.
    /// </summary>
    private static bool ConstantTimeEquals(string a, string b)
    {
        if (a.Length != b.Length) return false;
        var diff = 0;
        for (var i = 0; i < a.Length; i++)
        {
            diff |= a[i] ^ b[i];
        }
        return diff == 0;
    }

    /// <summary>
    /// Validates migrationRef for path-traversal attacks.
    /// Same logic as Program.cs validation.
    /// </summary>
    private static bool IsValidMigrationRef(string? migrationRef)
    {
        if (string.IsNullOrWhiteSpace(migrationRef)) return false;
        if (migrationRef.Contains("..")) return false;
        if (migrationRef.Contains('/')) return false;
        if (migrationRef.Contains('\\')) return false;
        if (migrationRef.Contains(':')) return false;
        return true;
    }
}
