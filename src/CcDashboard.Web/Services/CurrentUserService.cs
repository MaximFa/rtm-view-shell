using System.Security.Claims;
using CcDashboard.Core.Interfaces;

namespace CcDashboard.Web.Services;

// IHttpContextAccessor.HttpContext is available for SSR requests and for
// scoped services resolved during the Blazor Server circuit's initial HTTP handshake.
// Interactive components should read claims via AuthenticationStateProvider directly.
public class CurrentUserService : ICurrentUser
{
    private readonly IHttpContextAccessor _accessor;

    public CurrentUserService(IHttpContextAccessor accessor) => _accessor = accessor;

    private ClaimsPrincipal? Principal => _accessor.HttpContext?.User;

    public Guid UserId
    {
        get
        {
            var value = Principal?.FindFirstValue(ClaimTypes.NameIdentifier);
            return Guid.TryParse(value, out var id) ? id : Guid.Empty;
        }
    }

    public string Email =>
        Principal?.FindFirstValue(ClaimTypes.Email) ?? string.Empty;

    public bool IsAuthenticated =>
        Principal?.Identity?.IsAuthenticated ?? false;

    public bool IsAdmin =>
        Principal?.HasClaim("role", "admin") ?? false;

    public IReadOnlyList<Guid> GroupIds =>
        Principal?.FindAll("group_id")
            .Select(c => Guid.TryParse(c.Value, out var g) ? g : Guid.Empty)
            .Where(g => g != Guid.Empty)
            .ToList()
        ?? (IReadOnlyList<Guid>)Array.Empty<Guid>();
}
