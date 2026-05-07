namespace CcDashboard.Contracts.DTOs.TenantSettings;

public record TenantSettingsDto(
    Guid TenantId,
    int PasswordMinLength,
    int PasswordExpireDays,
    bool Require2faForAll,
    int AuditRetentionDays,
    string DefaultLocale,
    bool SoftDeleteDashboards,
    int SoftDeleteRetentionDays);

public record UpdateTenantSettingsRequest(
    int PasswordMinLength,
    int PasswordExpireDays,
    bool Require2faForAll,
    int AuditRetentionDays,
    string DefaultLocale,
    bool SoftDeleteDashboards,
    int SoftDeleteRetentionDays);
