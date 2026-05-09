using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Commands.PermissionGroups;
using CcDashboard.Application.Commands.Tenants;
using CcDashboard.Application.Commands.TenantSettings;
using FluentValidation;

namespace CcDashboard.Application.Validators;

// ── Dashboards ────────────────────────────────────────────────────────────────

public class CreateDashboardCommandValidator : AbstractValidator<CreateDashboardCommand>
{
    public CreateDashboardCommandValidator()
    {
        RuleFor(x => x.Request.Name)
            .NotEmpty().WithMessage("Dashboard name is required.")
            .MaximumLength(200).WithMessage("Dashboard name cannot exceed 200 characters.");

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");
    }
}

public class UpdateDashboardCommandValidator : AbstractValidator<UpdateDashboardCommand>
{
    public UpdateDashboardCommandValidator()
    {
        RuleFor(x => x.Request.Name)
            .NotEmpty().WithMessage("Dashboard name is required.")
            .MaximumLength(200).WithMessage("Dashboard name cannot exceed 200 characters.");

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");
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
            .MaximumLength(200).WithMessage("Tenant name cannot exceed 200 characters.");
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
            .MaximumLength(200).WithMessage("Tenant name cannot exceed 200 characters.");
    }
}

// ── Permission Groups ─────────────────────────────────────────────────────────

public class CreatePermissionGroupCommandValidator : AbstractValidator<CreatePermissionGroupCommand>
{
    public CreatePermissionGroupCommandValidator()
    {
        RuleFor(x => x.Request.Name)
            .NotEmpty().WithMessage("Permission group name is required.")
            .MaximumLength(200).WithMessage("Name cannot exceed 200 characters.");

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");
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
            .MaximumLength(200).WithMessage("Name cannot exceed 200 characters.");

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");

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

// ── RTS Grid Metrics ──────────────────────────────────────────────────────────

public class SaveRtsGridMetricCommandValidator : AbstractValidator<SaveRtsGridMetricCommand>
{
    public SaveRtsGridMetricCommandValidator()
    {
        RuleFor(x => x.Request.MetricId)
            .NotEmpty().WithMessage("Metric ID is required.")
            .MaximumLength(100).WithMessage("Metric ID cannot exceed 100 characters.")
            .Matches(@"^[A-Za-z0-9_\-\.]+$").WithMessage("Metric ID may only contain letters, digits, underscores, hyphens, and dots.");

        RuleFor(x => x.Request.DataType)
            .NotEmpty().WithMessage("Data type is required.")
            .MaximumLength(50).WithMessage("Data type cannot exceed 50 characters.");

        RuleFor(x => x.Request.MetricFunction)
            .NotEmpty().WithMessage("Metric function is required.")
            .MaximumLength(200).WithMessage("Metric function cannot exceed 200 characters.");

        RuleFor(x => x.Request.MetricParameter)
            .NotEmpty().WithMessage("Metric parameter is required.")
            .MaximumLength(200).WithMessage("Metric parameter cannot exceed 200 characters.");

        RuleFor(x => x.Request.MetricFormat)
            .MaximumLength(100).WithMessage("Metric format cannot exceed 100 characters.")
            .When(x => !string.IsNullOrEmpty(x.Request.MetricFormat));

        RuleFor(x => x.Request.Description)
            .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");

        RuleFor(x => x.Request.DefaultValue)
            .MaximumLength(100).WithMessage("Default value cannot exceed 100 characters.");
    }
}

// ── Tenant Settings ───────────────────────────────────────────────────────────

public class UpdateTenantSettingsCommandValidator : AbstractValidator<UpdateTenantSettingsCommand>
{
    public UpdateTenantSettingsCommandValidator()
    {
        RuleFor(x => x.Request.PasswordMinLength)
            .InclusiveBetween(8, 128).WithMessage("Password minimum length must be between 8 and 128.");

        RuleFor(x => x.Request.PasswordExpireDays)
            .InclusiveBetween(0, 365).WithMessage("Password expiry must be between 0 and 365 days.");

        RuleFor(x => x.Request.AuditRetentionDays)
            .InclusiveBetween(30, 3650).WithMessage("Audit retention must be between 30 and 3650 days.");

        RuleFor(x => x.Request.DefaultLocale)
            .NotEmpty().WithMessage("Default locale is required.")
            .MaximumLength(10).WithMessage("Locale cannot exceed 10 characters.")
            .Matches(@"^[a-z]{2}-[A-Z]{2}$").WithMessage("Locale must be in format xx-XX (e.g., en-US).");

        RuleFor(x => x.Request.SoftDeleteRetentionDays)
            .InclusiveBetween(1, 365).WithMessage("Soft delete retention must be between 1 and 365 days.");

        RuleFor(x => x.Request.PurchasedLicences)
            .GreaterThanOrEqualTo(0).WithMessage("Purchased licences cannot be negative.");

        RuleFor(x => x.Request.MaxConcurrentConnections)
            .GreaterThanOrEqualTo(0).WithMessage("Max concurrent connections cannot be negative.");
    }
}
