using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.Security;

public class SsoService : ISsoService
{
    private readonly ILogger<SsoService> _logger;

    public SsoService(ILogger<SsoService> logger)
    {
        _logger = logger;
    }

    public string InitiateLogin()
    {
        _logger.LogWarning("SSO login initiated but SSO provider is not yet implemented");
        throw new NotImplementedException("SSO provider implementation is pending for a future sprint.");
    }

    public Task<string> HandleCallbackAsync(string callbackData, CancellationToken ct = default)
    {
        _logger.LogWarning("SSO callback received but SSO provider is not yet implemented");
        throw new NotImplementedException("SSO provider implementation is pending for a future sprint.");
    }
}
