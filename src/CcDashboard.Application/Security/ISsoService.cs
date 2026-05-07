namespace CcDashboard.Application.Security;

public interface ISsoService
{
    string InitiateLogin();
    Task<string> HandleCallbackAsync(string callbackData, CancellationToken ct = default);
}
