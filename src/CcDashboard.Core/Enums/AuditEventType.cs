namespace CcDashboard.Core.Enums;

public enum AuditEventType
{
    Login,
    LoginFailed,
    Logout,
    TwoFactorSent,
    TwoFactorVerified,
    TwoFactorFailed,
    PasswordChanged,
    AccountLocked,
    SsoLogin,
    TokenRefreshed,
    TokenRevoked
}
