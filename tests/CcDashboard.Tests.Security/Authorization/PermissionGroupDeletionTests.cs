using CcDashboard.Application.Commands.PermissionGroups;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Infrastructure.Services;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// Integration tests for PG-06: cannot delete PG with assigned users [DoD-8].
/// Per CLAUDE.md §15: "[PG-06] Cannot delete a PG that has >=1 user assigned. Return error with user count + list."
/// </summary>
[Collection("Postgres")]
public class PermissionGroupDeletionTests
{
    private readonly PostgresFixture _fixture;

    public PermissionGroupDeletionTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    [Trait("Req", "PG-06")]
    public async Task DeletePermissionGroup_WithAssignedUsers_ReturnsFailureWithUserCount()
    {
        // Arrange - create an isolated PG with exactly 1 user to avoid interference from other tests
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);

        var isolatedPgId = Uuid.NewSequential();
        var isolatedPg = new PermissionGroup
        {
            Id = isolatedPgId,
            TenantId = _fixture.TenantAId,
            Name = "Isolated PG for Delete Test",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };
        db.PermissionGroups.Add(isolatedPg);

        var isolatedUser = new CcDashboard.Infrastructure.Identity.ApplicationUser
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.TenantAId,
            UserName = $"isolated_{Uuid.NewSequential():N}@test.local",
            Email = $"isolated_{Uuid.NewSequential():N}@test.local",
            NormalizedUserName = $"ISOLATED_{Uuid.NewSequential():N}@TEST.LOCAL",
            NormalizedEmail = $"ISOLATED_{Uuid.NewSequential():N}@TEST.LOCAL",
            EmailConfirmed = true,
            FirstName = "Isolated",
            LastName = "User",
            IsActive = true,
            PermissionGroupId = isolatedPgId
        };
        db.Users.Add(isolatedUser);
        await db.SaveChangesAsync();

        var repo = new PermissionGroupRepository(db);
        var apiHook = new Mock<IConfigurationApiHook>();

        var handler = new DeletePermissionGroupCommandHandler(repo, apiHook.Object);
        var command = new DeletePermissionGroupCommand(isolatedPgId);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse("Cannot delete PG with assigned users [PG-06]");
        result.Error.Should().Contain("1", "Error should contain user count");
        result.Error.Should().Contain("PG-06", "Error should reference PG-06 requirement");
    }

    [Fact]
    [Trait("Req", "PG-06")]
    public async Task DeletePermissionGroup_WithNoUsers_Succeeds()
    {
        // Arrange - create a new PG with no users
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);

        var emptyPgId = Uuid.NewSequential();
        var emptyPg = new PermissionGroup
        {
            Id = emptyPgId,
            TenantId = _fixture.TenantAId,
            Name = "Empty PG",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };

        db.PermissionGroups.Add(emptyPg);
        await db.SaveChangesAsync();

        var repo = new PermissionGroupRepository(db);
        var apiHook = new Mock<IConfigurationApiHook>();

        var handler = new DeletePermissionGroupCommandHandler(repo, apiHook.Object);
        var command = new DeletePermissionGroupCommand(emptyPgId);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // TransactionBehavior normally saves changes; in tests we need to do it manually
        if (result.IsSuccess)
            await db.SaveChangesAsync();

        // Assert
        result.IsSuccess.Should().BeTrue("PG with no users should be deletable");

        // Verify it was actually deleted
        var exists = await db.PermissionGroups
            .IgnoreQueryFilters()
            .AnyAsync(pg => pg.Id == emptyPgId);
        exists.Should().BeFalse("PG should be removed from database");
    }

    [Fact]
    [Trait("Req", "PG-06")]
    public async Task DeletePermissionGroup_NotFound_ThrowsNotFoundException()
    {
        // Arrange
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);

        var repo = new PermissionGroupRepository(db);
        var apiHook = new Mock<IConfigurationApiHook>();

        var handler = new DeletePermissionGroupCommandHandler(repo, apiHook.Object);
        var command = new DeletePermissionGroupCommand(Uuid.NewSequential()); // Non-existent ID

        // Act & Assert
        var act = async () => await handler.Handle(command, CancellationToken.None);

        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage("*PermissionGroup*");
    }

    [Fact]
    [Trait("Req", "PG-06")]
    public async Task DeletePermissionGroup_WithMultipleUsers_ReturnsCorrectCount()
    {
        // Arrange - create a PG with multiple users
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);

        var pgId = Uuid.NewSequential();
        var pg = new PermissionGroup
        {
            Id = pgId,
            TenantId = _fixture.TenantAId,
            Name = "Multi-User PG",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };

        db.PermissionGroups.Add(pg);
        await db.SaveChangesAsync();

        // Add 3 users to this PG
        for (int i = 0; i < 3; i++)
        {
            var user = new CcDashboard.Infrastructure.Identity.ApplicationUser
            {
                Id = Uuid.NewSequential(),
                TenantId = _fixture.TenantAId,
                UserName = $"user{i}@test.local",
                Email = $"user{i}@test.local",
                NormalizedUserName = $"USER{i}@TEST.LOCAL",
                NormalizedEmail = $"USER{i}@TEST.LOCAL",
                EmailConfirmed = true,
                FirstName = "User",
                LastName = i.ToString(),
                IsActive = true,
                PermissionGroupId = pgId
            };
            db.Users.Add(user);
        }
        await db.SaveChangesAsync();

        var repo = new PermissionGroupRepository(db);
        var apiHook = new Mock<IConfigurationApiHook>();

        var handler = new DeletePermissionGroupCommandHandler(repo, apiHook.Object);
        var command = new DeletePermissionGroupCommand(pgId);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse("Cannot delete PG with 3 assigned users");
        result.Error.Should().Contain("3", "Error should contain correct user count (3)");
    }

    [Fact]
    [Trait("Req", "PG-06")]
    public async Task CountUsersAsync_ReturnsCorrectCount()
    {
        // Arrange - create isolated PG with known user count to avoid interference
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);

        var isolatedPgId = Uuid.NewSequential();
        var isolatedPg = new PermissionGroup
        {
            Id = isolatedPgId,
            TenantId = _fixture.TenantAId,
            Name = "Count Test PG",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = _fixture.UserAId,
            UpdatedByUserId = _fixture.UserAId
        };
        db.PermissionGroups.Add(isolatedPg);

        for (int i = 0; i < 2; i++)
        {
            var user = new CcDashboard.Infrastructure.Identity.ApplicationUser
            {
                Id = Uuid.NewSequential(),
                TenantId = _fixture.TenantAId,
                UserName = $"counttest{i}_{Uuid.NewSequential():N}@test.local",
                Email = $"counttest{i}_{Uuid.NewSequential():N}@test.local",
                NormalizedUserName = $"COUNTTEST{i}_{Uuid.NewSequential():N}@TEST.LOCAL",
                NormalizedEmail = $"COUNTTEST{i}_{Uuid.NewSequential():N}@TEST.LOCAL",
                EmailConfirmed = true,
                FirstName = "Count",
                LastName = i.ToString(),
                IsActive = true,
                PermissionGroupId = isolatedPgId
            };
            db.Users.Add(user);
        }
        await db.SaveChangesAsync();

        var repo = new PermissionGroupRepository(db);

        // Act
        var count = await repo.CountUsersAsync(isolatedPgId, CancellationToken.None);

        // Assert
        count.Should().Be(2, "Isolated PG should have exactly 2 users assigned");
    }
}
