using CcDashboard.Core.Domain;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Integration.Infrastructure;
using FluentAssertions;

namespace CcDashboard.Tests.Integration.Repositories;

[Collection(DatabaseCollection.Name)]
public class UserRepositoryIntegrationTests : IAsyncLifetime
{
    private readonly DatabaseFixture _fixture;

    public UserRepositoryIntegrationTests(DatabaseFixture fixture)
    {
        _fixture = fixture;
    }

    public Task InitializeAsync() => _fixture.CleanAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    private static User NewUser(string email = "test@example.com") => new()
    {
        Id = Guid.NewGuid(),
        Email = email,
        DisplayName = "Test User",
        PasswordHash = "salt:hash",
        IsActive = true,
        CreatedAt = DateTime.UtcNow
    };

    [Fact]
    public async Task AddAsync_then_GetByIdAsync_roundtrip()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);
        var user = NewUser();

        await repo.AddAsync(user);
        var found = await repo.GetByIdAsync(user.Id);

        found.Should().NotBeNull();
        found!.Email.Should().Be(user.Email);
        found.DisplayName.Should().Be(user.DisplayName);
    }

    [Fact]
    public async Task GetByEmailAsync_returns_correct_user()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);
        var user = NewUser("lookup@example.com");
        await repo.AddAsync(user);

        var found = await repo.GetByEmailAsync("lookup@example.com");

        found.Should().NotBeNull();
        found!.Id.Should().Be(user.Id);
    }

    [Fact]
    public async Task GetByEmailAsync_returns_null_for_unknown_email()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);

        var result = await repo.GetByEmailAsync("nobody@example.com");
        result.Should().BeNull();
    }

    [Fact]
    public async Task UpdateAsync_persists_changes()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);
        var user = NewUser("update@example.com");
        await repo.AddAsync(user);

        user.DisplayName = "Updated Name";
        user.IsActive = false;
        await repo.UpdateAsync(user);

        db.ChangeTracker.Clear();
        var reloaded = await repo.GetByIdAsync(user.Id);
        reloaded!.DisplayName.Should().Be("Updated Name");
        reloaded.IsActive.Should().BeFalse();
    }

    [Fact]
    public async Task DeleteAsync_removes_user()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);
        var user = NewUser("delete@example.com");
        await repo.AddAsync(user);

        await repo.DeleteAsync(user);

        db.ChangeTracker.Clear();
        var found = await repo.GetByIdAsync(user.Id);
        found.Should().BeNull();
    }

    [Fact]
    public async Task ExistsAsync_returns_true_when_user_present()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);
        var user = NewUser("exists@example.com");
        await repo.AddAsync(user);

        var exists = await repo.ExistsAsync(u => u.Email == "exists@example.com");
        exists.Should().BeTrue();
    }

    [Fact]
    public async Task ExistsAsync_returns_false_when_user_absent()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);

        var exists = await repo.ExistsAsync(u => u.Email == "absent@example.com");
        exists.Should().BeFalse();
    }

    [Fact]
    public async Task GetAllAsync_returns_all_added_users()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);
        await repo.AddAsync(NewUser("a@example.com"));
        await repo.AddAsync(NewUser("b@example.com"));

        var all = await repo.GetAllAsync();

        all.Should().HaveCount(2);
        all.Should().Contain(u => u.Email == "a@example.com");
        all.Should().Contain(u => u.Email == "b@example.com");
    }

    [Fact]
    public async Task AddToGroupAsync_creates_membership()
    {
        await using var db = _fixture.CreateContext();
        var repo = new UserRepository(db);
        var user = NewUser("group@example.com");
        await repo.AddAsync(user);

        var group = new PermissionGroup
        {
            Id = Guid.NewGuid(),
            Name = "Test Group",
            Description = "",
            MenuPermissions = new List<string>(),
            CreatedAt = DateTime.UtcNow
        };
        db.PermissionGroups.Add(group);
        await db.SaveChangesAsync();

        await repo.AddToGroupAsync(user.Id, group.Id);

        db.ChangeTracker.Clear();
        var withGroups = await repo.GetByIdWithGroupsAsync(user.Id);
        withGroups!.Groups.Should().ContainSingle(g => g.GroupId == group.Id);
    }
}
