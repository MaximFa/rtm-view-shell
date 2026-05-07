namespace CcDashboard.Domain.Interfaces;

public interface IExternalAuthProvider
{
    string InitiateLogin(Guid tenantId);
    Task<ExternalAuthResult> HandleCallbackAsync(string code, string state, CancellationToken ct = default);
}

public record ExternalAuthResult(
    bool Success,
    string? Email,
    string? ExternalId,
    bool MfaVerified,
    string? ErrorMessage);
