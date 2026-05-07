using System.Security.Claims;
using CcDashboard.Application.DTOs;

namespace CcDashboard.Application.Security;

public interface IJwtTokenService
{
    TokenPair GenerateTokenPair(UserDto user);
    ClaimsPrincipal? ValidateAccessToken(string token);
}
