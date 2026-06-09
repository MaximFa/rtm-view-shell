using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Commands.PermissionGroups;
using CcDashboard.Application.Commands.Tenants;
using CcDashboard.Application.Commands.TenantSettings;
using CcDashboard.Contracts.DTOs.Users;
using FluentValidation;

namespace CcDashboard.Application.Validators;

// ── Security: Safe text pattern — no HTML/script injection chars ──────────────
// Used for names, descriptions, and other user-visible text fields [CODE-02]
internal static class SecurityPatterns
{
    /// <summary>
    /// Allows letters (any script), digits, spaces, and common punctuation.
    /// Blocks: &lt; &gt; " ' ; &amp; | ` $ { } [ ] \
    /// </summary>
    public const string SafeTextPattern = @"^[^<>""';`&|$\{\}\[\]\\]*$";
    public const string SafeTextMessage = "Field contains invalid characters (< > \" ' ; & | ` $ { } [ ] \\ are not allowed).";

    /// <summary>
    /// Username: letters, digits, underscore, hyphen, dot, @
    /// </summary>
    public const string UsernamePattern = @"^[a-zA-Z0-9._\-@]+$";
    public const string UsernameMessage = "Username may only contain letters, digits, dots, underscores, hyphens, and @.";

    /// <summary>
    /// Safe name pattern for display names (allows Unicode letters, spaces, hyphens, apostrophes)
    /// </summary>
    public const string PersonNamePattern = @"^[\p{L}\p{M}' \-\.]+$";
    public const string PersonNameMessage = "Name may only contain letters, spaces, hyphens, apostrophes, and dots.";
}

// ── Users [CODE-02] ───────────────────────────────────────────────────────────

public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.UserName)
            .NotEmpty().WithMessage("Username is required.")
            .MinimumLength(2).WithMessage("Username must be at least 2 characters.")
            .MaximumLength(256).WithMessage("Username cannot exceed 256 characters.")
            .Matches(SecurityPatterns.UsernamePattern).WithMessage(SecurityPatterns.UsernameMessage);

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required.")
            .EmailAddress().WithMessage("Invalid email format.")
            .MaximumLength(256).WithMessage("Email cannot exceed 256 characters.");

        RuleFor(x => x.FirstName)
            .MaximumLength(100).WithMessage("First name cannot exceed 100 characters.")
            .Matches(SecurityPatterns.PersonNamePattern).WithMessage(SecurityPatterns.PersonNameMessage)
            .When(x => !string.IsNullOrEmpty(x.FirstName));

        RuleFor(x => x.LastName)
            .MaximumLength(100).WithMessage("Last name cannot exceed 100 characters.")
            .Matches(SecurityPatterns.PersonNamePattern).WithMessage(SecurityPatterns.PersonNameMessage)
            .When(x => !string.IsNullOrEmpty(x.LastName));

        RuleFor(x => x.Role)
            .NotEmpty().WithMessage("Role is required.")
            .Must(r => r is "Superadmin" or "Administrator" or "Editor" or "Viewer")
            .WithMessage("Invalid role. Must be Superadmin, Administrator, Editor, or Viewer.");
    }
}

public class UpdateUserRequestValidator : AbstractValidator<UpdateUserRequest>
{
    public UpdateUserRequestValidator()
    {
        RuleFor(x => x.Id)
            .NotEmpty().WithMessage("User ID is required.");

        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required.")
            .EmailAddress().WithMessage("Invalid email format.")
            .MaximumLength(256).WithMessage("Email cannot exceed 256 characters.");

        RuleFor(x => x.FirstName)
            .MaximumLength(100).WithMessage("First name cannot exceed 100 characters.")
            .Matches(SecurityPatterns.PersonNamePattern).WithMessage(SecurityPatterns.PersonNameMessage)
            .When(x => !string.IsNullOrEmpty(x.FirstName));

        RuleFor(x => x.LastName)
            .MaximumLength(100).WithMessage("Last name cannot exceed 100 characters.")
            .Matches(SecurityPatterns.PersonNamePattern).WithMessage(SecurityPatterns.PersonNameMessage)
            .When(x => !string.IsNullOrEmpty(x.LastName));

        RuleFor(x => x.Role)
            .NotEmpty().WithMessage("Role is required.")
            .Must(r => r is "Superadmin" or "Administrator" or "Editor" or "Viewer")
            .WithMessage("Invalid role.");

        RuleFor(x => x.PreferredLocale)
            .MaximumLength(10).WithMessage("Locale cannot exceed 10 characters.")
            .Matches(@"^[a-z]{2}-[A-Z]{2}$").WithMessage("Locale must be in format xx-XX (e.g., en-US).")
            .When(x => !string.IsNullOrEmpty(x.PreferredLocale));
    }
}

// ── Dashboards ────────────────────────────────────────────────────────────────

public class CreateDashboardCommandValidator : AbstractValidator<CreateDashboardCommand>
{
    public CreateDashboardCommandValidator()
    {
        RuleFor(x => x.Request.Name)
            .NotEmpty().WithMessage("Dashboard name is required.")
            .MaximumLength(200).WithMessage("Dashboard name cannot exceed 200 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage);

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage)
            .When(x => !string.IsNullOrEmpty(x.Request.Description));
    }
}

public class UpdateDashboardCommandValidator : AbstractValidator<UpdateDashboardCommand>
{
    public UpdateDashboardCommandValidator()
    {
        RuleFor(x => x.Request.Name)
            .NotEmpty().WithMessage("Dashboard name is required.")
            .MaximumLength(200).WithMessage("Dashboard name cannot exceed 200 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage);

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage)
            .When(x => !string.IsNullOrEmpty(x.Request.Description));
    }
}

// ── Tenants ───────────────────────────────────────────────────────────────────

public class CreateTenantCommandValidator : AbstractValidator<CreateTenantCommand>
{
    public CreateTenantCommandValidator()
    {
        RuleFor(x => x.Request.Slug)
            .NotEmpty().WithMessage("Slug is required.")
            .MinimumLength(2).WithMessage("Slug must be at least 2 characters.")
            .MaximumLength(100).WithMessage("Slug cannot exceed 100 characters.")
            .Matches(@"^[a-zA-Z0-9\-]+$").WithMessage("Slug may only contain letters, digits, and hyphens.");

        RuleFor(x => x.Request.Name)
            .NotEmpty().WithMessage("Tenant name is required.")
            .MaximumLength(200).WithMessage("Tenant name cannot exceed 200 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage);
    }
}

public class UpdateTenantCommandValidator : AbstractValidator<UpdateTenantCommand>
{
    public UpdateTenantCommandValidator()
    {
        RuleFor(x => x.TenantId)
            .NotEmpty().WithMessage("Tenant ID is required.");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Tenant name is required.")
            .MaximumLength(200).WithMessage("Tenant name cannot exceed 200 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage);
    }
}

// ── Permission Groups ─────────────────────────────────────────────────────────

public class CreatePermissionGroupCommandValidator : AbstractValidator<CreatePermissionGroupCommand>
{
    public CreatePermissionGroupCommandValidator()
    {
        RuleFor(x => x.Request.Name)
            .NotEmpty().WithMessage("Permission group name is required.")
            .MaximumLength(200).WithMessage("Name cannot exceed 200 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage);

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage)
            .When(x => !string.IsNullOrEmpty(x.Request.Description));
    }
}

public class UpdatePermissionGroupCommandValidator : AbstractValidator<UpdatePermissionGroupCommand>
{
    public UpdatePermissionGroupCommandValidator()
    {
        RuleFor(x => x.Request.Id)
            .NotEmpty().WithMessage("Permission group ID is required.");

        RuleFor(x => x.Request.Name)
            .NotEmpty().WithMessage("Permission group name is required.")
            .MaximumLength(200).WithMessage("Name cannot exceed 200 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage);

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.")
            .Matches(SecurityPatterns.SafeTextPattern).WithMessage(SecurityPatterns.SafeTextMessage)
            .When(x => !string.IsNullOrEmpty(x.Request.Description));

        RuleFor(x => x.Request.AllowedQueueIds)
            .Must(ids => ids == null || ids.Count <= 1000)
            .WithMessage("Cannot assign more than 1000 queues.");

        RuleFor(x => x.Request.AllowedAgentGroupIds)
            .Must(ids => ids == null || ids.Count <= 1000)
            .WithMessage("Cannot assign more than 1000 agent groups.");

        RuleFor(x => x.Request.AllowedDashboardIds)
            .Must(ids => ids == null || ids.Count <= 500)
            .WithMessage("Cannot assign more than 500 dashboards.");
    }
}

// ── Sites ─────────────────────────────────────────────────────────────────────

public class SaveSiteCommandValidator : AbstractValidator<SaveSiteCommand>
{
    public SaveSiteCommandValidator()
    {
        RuleFor(x => x.Request.SiteId)
            .NotEmpty().WithMessage("Site ID is required.")
            .MaximumLength(100).WithMessage("Site ID cannot exceed 100 characters.")
            .Matches(@"^[A-Za-z0-9_\-]+$").WithMessage("Site ID may only contain letters, digits, underscores, and hyphens.");

        RuleFor(x => x.Request.SiteName)
            .MaximumLength(200).WithMessage("Site name cannot exceed 200 characters.");

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");

        RuleFor(x => x.Request.TimeZone)
            .MaximumLength(10).WithMessage("Time zone offset cannot exceed 10 characters.")
            .Matches(@"^[+-]\d{2}:\d{2}$").WithMessage("Time zone must be in format +HH:MM or -HH:MM (e.g. +03:00).")
            .When(x => !string.IsNullOrEmpty(x.Request.TimeZone));

        RuleFor(x => x.Request.ClearTime)
            .MaximumLength(5).WithMessage("Clear time cannot exceed 5 characters.")
            .Matches(@"^\d{2}:\d{2}$").WithMessage("Clear time must be in format HH:MM (e.g. 08:00).")
            .When(x => !string.IsNullOrEmpty(x.Request.ClearTime));
    }
}

// ── Business Units ────────────────────────────────────────────────────────────

public class SaveBusinessUnitCommandValidator : AbstractValidator<SaveBusinessUnitCommand>
{
    public SaveBusinessUnitCommandValidator()
    {
        RuleFor(x => x.Request.BusinessUnitName)
            .NotEmpty().WithMessage("Business unit name is required.")
            .MaximumLength(200).WithMessage("Name cannot exceed 200 characters.");

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");

        RuleFor(x => x.Request.SiteId)
            .MaximumLength(100).WithMessage("Site ID cannot exceed 100 characters.")
            .When(x => !string.IsNullOrEmpty(x.Request.SiteId));

        RuleForEach(x => x.Request.QueueIds)
            .MaximumLength(100).WithMessage("Queue ID cannot exceed 100 characters.");

        RuleFor(x => x.Request.QueueIds)
            .Must(ids => ids.Count <= 500).WithMessage("Cannot assign more than 500 queues.");

        RuleFor(x => x.Request.SupergroupIds)
            .Must(ids => ids.Count <= 500).WithMessage("Cannot assign more than 500 supergroups.");
    }
}

// ── Supergroups ───────────────────────────────────────────────────────────────

public class SaveSupergroupCommandValidator : AbstractValidator<SaveSupergroupCommand>
{
    public SaveSupergroupCommandValidator()
    {
        RuleFor(x => x.Request.SupergroupName)
            .NotEmpty().WithMessage("Supergroup name is required.")
            .MaximumLength(200).WithMessage("Name cannot exceed 200 characters.");

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");

        RuleForEach(x => x.Request.AgentGroupIds)
            .MaximumLength(100).WithMessage("Agent group ID cannot exceed 100 characters.");

        RuleFor(x => x.Request.AgentGroupIds)
            .Must(ids => ids.Count <= 500).WithMessage("Cannot assign more than 500 agent groups.");
    }
}

