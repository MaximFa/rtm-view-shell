---
name: app-cyber-security-expert
invocation: user
description: >
  Apply application security expertise to the RTM View Shell (CC Dashboard Shell) project.
  Trigger this skill whenever the user mentions: authentication, authorization, JWT, tokens,
  refresh tokens, token rotation, token revocation, cookie security, session management,
  two-factor authentication, 2FA, OTP, SSO, SAML, OIDC, LDAP, password hashing, password policy,
  password history, brute force protection, rate limiting, lockout, account enumeration,
  input validation, XSS, CSRF, SQL injection, parameterised queries, security headers, CSP,
  HSTS, X-Frame-Options, CORS, anti-forgery, secrets management, key vault, connection strings,
  PBKDF2, HMAC, RSA keys, JWT signing, JWKS, audit logging from security perspective,
  multi-tenancy isolation, cross-tenant access, global query filters, tenant bypass,
  permission enforcement, authorization behavior, role claims, privilege escalation,
  security middleware, HTTPS, TLS, certificate management, Redis security, PostgreSQL security,
  IIS hardening, Windows Server security, OWASP, CVSS, CVE, vulnerable packages,
  penetration testing, or security code review.
  Also trigger on: "is this secure", "security concern", "how to protect", "prevent attack",
  "safe to store", "should I encrypt", "token reuse", "session fixation", "injection risk",
  "privilege escalation risk", or any reference to security requirements AUTH-*, PWD-*, BFP-*,
  2FA-*, SSO-*, SEC-*, CODE-*, DEPLOY-* from CLAUDE.md.
  Never skip this skill for any auth, token, secret, or input handling work.
---

# Application Cyber Security Expert — RTM View Shell

This skill governs all security decisions in the **CC Dashboard Shell** project.
Read it in full before writing any authentication, authorisation, token, secret,
input handling, or data access code. Every requirement ID maps to `CLAUDE.md`.

---

## 0. Before writing any security-sensitive code — verify

1. Read `CLAUDE.md` §8–§16 (Auth, Passwords, BFP, 2FA, SSO, Security Headers, Permissions, Audit).
2. Check the PR security checklist in `CLAUDE.md §25` — it must pass before every merge.
3. Run `dotnet list package --vulnerable` [CODE-07] — fix Critical CVEs within 48h.
4. If touching JWT / cookie / secret handling: read §9 (JWT) and §14 (Security Headers) again.

---

## 1. Threat model — top risks for this application

| Threat | Attack vector | Mitigated by |
|---|---|---|
| Cross-tenant data leak | Forgetting TenantId in query | EF Global Query Filters [ARCH-01] |
| Session hijacking | Cookie theft / XSS | HttpOnly + Secure + SameSite=Strict cookies |
| JWT forgery | Weak signing key / algorithm | RS256 (RSA-2048 min), never HS256 in prod [AUTH-API-02] |
| Token reuse after compromise | Stolen refresh token | Rotation + reuse detection [AUTH-API-04] |
| Brute force / credential stuffing | Login endpoint flooding | Lockout after 5 attempts + rate limit 10/min [BFP-01/02] |
| Account enumeration | Different error messages | Uniform error: "Invalid username or password" [BFP-03] |
| Privilege escalation | UI hides but API allows | Two-level enforcement: attribute + AuthorizationBehavior [CODE-03] |
| SQL injection | String-concatenated queries | EF Core parameterised queries only [CODE-01] |
| XSS via stored content | Raw MarkupString rendering | HtmlEncoder / Ganss.Xss [CODE-02] |
| Secrets in source code | Committed appsettings | User Secrets (dev) / Key Vault (prod) [CODE-05] |
| Insecure direct object reference | Accessing other tenant's resource by UUID | GQF + explicit TenantId check in handler |
| OTP replay attack | Reusing consumed 2FA code | `ConsumedAt` check + max 3 attempts [2FA-03/04] |
| Password hash weakness | Too few iterations | PBKDF2-HMACSHA512, 100 000 iterations [PWD-03] |

---

## 2. Cookie authentication security [AUTH-WEB-01]

```csharp
// Program.cs / Auth configuration
services.ConfigureApplicationCookie(options =>
{
    options.Cookie.Name = "__Host-CcDash";   // __Host- prefix: enforces Secure + no Domain
    options.Cookie.HttpOnly = true;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.Cookie.SameSite = SameSiteMode.Strict;
    options.SlidingExpiration = true;
    options.ExpireTimeSpan = TimeSpan.FromMinutes(30);    // Sliding window
    options.Cookie.MaxAge = TimeSpan.FromHours(8);        // Absolute maximum

    // On 401 in Blazor: return 401, not redirect to /login (handled by circuit)
    options.Events.OnRedirectToLogin = ctx =>
    {
        ctx.Response.StatusCode = 401;
        return Task.CompletedTask;
    };
});
```

**`__Host-` prefix rules:**
- Forces `Secure` flag.
- Forces `Path=/`.
- Forbids `Domain` attribute — cookie bound to exact origin.
- Most resistant to subdomain-based cookie injection.

**SecurityStamp invalidation:**
Any change to user Role, TenantId, or IsActive must call:
```csharp
await userManager.UpdateSecurityStampAsync(user);
```
This invalidates all existing sessions [AUTH-WEB-02].

---

## 3. JWT security [AUTH-API-01..06]

### Access Token — issuance

```csharp
// Application/Security/JwtTokenService.cs
public string IssueAccessToken(ApplicationUser user, string permissionGroupId)
{
    var now = DateTime.UtcNow;
    var jti = Guid.NewGuid().ToString();

    var claims = new[]
    {
        new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
        new Claim(JwtRegisteredClaimNames.Jti, jti),
        new Claim(JwtRegisteredClaimNames.Iat,
            EpochTime.GetIntDate(now).ToString(), ClaimValueTypes.Integer64),
        new Claim("tenant_id", user.TenantId.ToString()),
        new Claim(ClaimTypes.Role, user.Role),
        new Claim("permission_group_id", permissionGroupId),
    };

    var credentials = new SigningCredentials(
        _rsaPrivateKey,          // RSA-2048 minimum [AUTH-API-02]
        SecurityAlgorithms.RsaSha256);  // RS256 — asymmetric, never HS256 in prod

    var token = new JwtSecurityToken(
        issuer: _options.Issuer,
        audience: _options.Audience,
        claims: claims,
        notBefore: now,
        expires: now.AddMinutes(15),   // 15-min TTL [AUTH-API-02]
        signingCredentials: credentials);

    return new JwtSecurityTokenHandler().WriteToken(token);
}
```

### Refresh Token — storage and rotation [AUTH-API-03/04]

```csharp
// NEVER store raw token — only SHA-256 hash
public string IssueRefreshToken(Guid userId, Guid tenantId, string ipAddress, string userAgent)
{
    var rawToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
    var tokenHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawToken)));

    var entity = new RefreshToken
    {
        Id = UUIDNext.Uuid.NewSequential(),
        UserId = userId,
        TenantId = tenantId,
        Jti = Guid.NewGuid(),
        TokenHash = tokenHash,
        ExpiresAt = DateTime.UtcNow.AddHours(8),
        IssuedAt = DateTime.UtcNow,
        IpAddress = ipAddress,
        UserAgent = userAgent
    };
    // Save entity, return rawToken (sent to client via HttpOnly cookie)
    return rawToken;
}

// Rotation on refresh
public async Task<(string newAccess, string newRefresh)> RotateAsync(
    string rawRefreshToken, string ipAddress, CancellationToken ct)
{
    var hash = Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(rawRefreshToken)));

    var existing = await repo.GetByHashAsync(hash, ct)
        ?? throw new SecurityTokenException("Token not found.");

    if (existing.RevokedAt is not null)
    {
        // REUSE DETECTED — revoke ALL tokens for this user [AUTH-API-04]
        await repo.RevokeAllForUserAsync(existing.UserId, ct);
        await audit.LogAsync(AuditEvents.Auth.TokenRevoked,
            new { existing.UserId, Reason = "TokenReuse", ipAddress }, ct);
        throw new SecurityTokenException("Token reuse detected.");
    }

    if (existing.ExpiresAt < DateTime.UtcNow)
        throw new SecurityTokenException("Token expired.");

    // Mark old as revoked
    existing.RevokedAt = DateTime.UtcNow;
    // existing.ReplacedByTokenId = newId; (set after creating new token)

    var newRefresh = IssueRefreshToken(existing.UserId, existing.TenantId, ipAddress, ...);
    var newAccess  = IssueAccessToken(...);
    return (newAccess, newRefresh);
}
```

### Access Token revocation via Redis [AUTH-API-05]

```csharp
// On logout, deactivation, or force-logout:
// Add jti to Redis revocation list with TTL = remaining token lifetime
public async Task RevokeAccessTokenAsync(string jti, Guid tenantId, DateTime tokenExpiry)
{
    var ttl = tokenExpiry - DateTime.UtcNow;
    if (ttl <= TimeSpan.Zero) return;  // Already expired — no need to revoke

    var key = $"{tenantId}:revoked_jti:{jti}";
    await redis.StringSetAsync(key, "1", ttl);
}

// In JWT middleware — check on EVERY request
public async Task<bool> IsRevokedAsync(string jti, Guid tenantId)
{
    var key = $"{tenantId}:revoked_jti:{jti}";
    return await redis.KeyExistsAsync(key);
}
```

### RSA key management [AUTH-API-06]

```csharp
// Load from encrypted file / Key Vault — NEVER from appsettings.json
var rsa = RSA.Create();
var keyPem = await File.ReadAllTextAsync(config["Jwt:PrivateKeyPath"]);
rsa.ImportFromPem(keyPem);
// File permissions: NTFS ACL — only app service account has Read

// JWKS endpoint for public key distribution (for API consumers)
// Maintain multiple kid entries during key rotation
```

---

## 4. Password security [PWD-01..05]

```csharp
// Program.cs — PasswordHasherOptions
services.Configure<PasswordHasherOptions>(options =>
{
    options.CompatibilityMode = PasswordHasherCompatibilityMode.IdentityV3;
    options.IterationCount = 100_000;   // PBKDF2-HMACSHA512, 100k iterations [PWD-03]
});

// Custom IPasswordHasher<T> if you need to enforce the algorithm explicitly:
// Use Rfc2898DeriveBytes with HashAlgorithmName.SHA512
```

### Password policy validator

```csharp
public class StrictPasswordValidator<TUser> : IPasswordValidator<TUser>
    where TUser : class
{
    public Task<IdentityResult> ValidateAsync(
        UserManager<TUser> manager, TUser user, string? password)
    {
        if (password is null || password.Length < 12)        // [PWD-01]
            return Fail("Minimum 12 characters required.");

        if (!password.Any(char.IsUpper))                      // [PWD-02]
            return Fail("At least one uppercase letter required.");

        if (!password.Any(char.IsLower))
            return Fail("At least one lowercase letter required.");

        if (!password.Any(char.IsDigit))
            return Fail("At least one digit required.");

        if (!password.Any(c => !char.IsLetterOrDigit(c)))
            return Fail("At least one special character required.");

        return Task.FromResult(IdentityResult.Success);
    }
}
```

### Password history check [PWD-04]

```csharp
// Before saving new password — check last 10 hashes
var history = await db.UserPasswordHistory
    .Where(h => h.UserId == userId)
    .OrderByDescending(h => h.CreatedAt)
    .Take(10)
    .ToListAsync(ct);

foreach (var entry in history)
{
    var result = hasher.VerifyHashedPassword(user, entry.PasswordHash, newPassword);
    if (result != PasswordVerificationResult.Failed)
        throw new DomainException("Password was used recently. Choose a different password.");
}
```

---

## 5. Brute-force protection [BFP-01..04]

### Account lockout (ASP.NET Core Identity)

```csharp
services.Configure<LockoutOptions>(options =>
{
    options.AllowedForNewUsers = true;
    options.MaxFailedAccessAttempts = 5;             // [BFP-01]
    options.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
});
```

### Rate limiting on login endpoint [BFP-02]

```csharp
// Program.cs
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("login", limiter =>
    {
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.PermitLimit = 10;
        limiter.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiter.QueueLimit = 0;
    });
    options.RejectionStatusCode = 429;
    // Use Redis-backed distributed rate limiting for multi-instance
    // StackExchange.Redis + custom IPartitionedRateLimiter
});

// Apply to login endpoint only
app.MapPost("/auth/login", ...)
   .RequireRateLimiting("login");
```

### Uniform error message [BFP-03]

```csharp
// ALWAYS return this message for any login failure:
// UserNotFound | WrongPassword | TenantMismatch | TenantSuspended | AccountLocked
private const string InvalidCredentialsMessage = "Invalid username or password.";

// Log the real reason in audit — but NEVER send it to the client
await audit.LogAsync(AuditEvents.Auth.LoginFailure,
    new { UserName = input.UserName, Reason = "UserNotFound", IpAddress = ip }, ct);

return IdentityResult.Failed(new IdentityError { Description = InvalidCredentialsMessage });
```

---

## 6. Two-factor authentication security [2FA-01..07]

```csharp
// Generate 6-digit OTP via CSRNG [2FA-02]
private static string GenerateOtp()
{
    Span<byte> bytes = stackalloc byte[4];
    RandomNumberGenerator.Fill(bytes);
    var number = BitConverter.ToUInt32(bytes) % 1_000_000;
    return number.ToString("D6");
}

// Store as HMAC-SHA256(code, salt) — never plaintext [2FA-03]
private static string HashOtp(string code, string salt)
{
    var key  = Encoding.UTF8.GetBytes(salt);
    var data = Encoding.UTF8.GetBytes(code);
    return Convert.ToHexString(HMACSHA256.HashData(key, data));
}

// Verify with timing-safe comparison
private static bool VerifyOtp(string inputCode, string salt, string storedHash)
{
    var inputHash = HashOtp(inputCode, salt);
    return CryptographicOperations.FixedTimeEquals(
        Convert.FromHexString(inputHash),
        Convert.FromHexString(storedHash));
}
```

### Attempt limiting [2FA-04]

```csharp
var code = await db.TwoFactorCodes
    .Where(c => c.UserId == userId && c.ConsumedAt == null && c.ExpiresAt > DateTime.UtcNow)
    .FirstOrDefaultAsync(ct);

if (code is null) return OtpResult.Expired;

if (code.AttemptCount >= 3)
{
    // Invalidate code — user must request resend
    code.ConsumedAt = DateTime.UtcNow;  // Mark as consumed (prevents further use)
    await db.SaveChangesAsync(ct);
    return OtpResult.TooManyAttempts;
}

code.AttemptCount++;
if (!VerifyOtp(inputCode, code.Salt, code.CodeHash))
{
    await db.SaveChangesAsync(ct);
    return OtpResult.Invalid;
}

code.ConsumedAt = DateTime.UtcNow;
await db.SaveChangesAsync(ct);
return OtpResult.Success;
```

### Resend rate limit [2FA-04]

```csharp
var rateLimitKey = $"{tenantId}:2fa_resend:{userId}";
var canResend = await redis.StringSetAsync(
    rateLimitKey, "1",
    TimeSpan.FromMinutes(1),
    When.NotExists);   // SET NX EX 60

if (!canResend)
    return ResendResult.RateLimited;
```

---

## 7. Input validation and injection prevention

### SQL injection — EF Core only [CODE-01]

```csharp
// ✅ Always parameterised via EF
var users = await db.Users
    .Where(u => u.Email == email && u.TenantId == tenantId)
    .ToListAsync(ct);

// ✅ Raw SQL — use interpolated (EF handles parameterisation)
var result = await db.Users
    .FromSqlInterpolated($"SELECT * FROM identity.users WHERE id = {userId}")
    .ToListAsync(ct);

// ❌ FORBIDDEN — string concatenation
var sql = "SELECT * FROM users WHERE email = '" + email + "'";
```

### XSS prevention [CODE-02]

```csharp
// ✅ Safe: Blazor encodes by default
<p>@userInputString</p>

// ✅ Safe: explicit encoding before MarkupString
var safe = HtmlEncoder.Default.Encode(userInputString);
<p>@((MarkupString)safe)</p>

// ✅ For rich-text (if ever needed): sanitise first
var sanitised = new HtmlSanitizer().Sanitize(userInputHtml);

// ❌ FORBIDDEN — raw user input as MarkupString
<p>@((MarkupString)userInputString)</p>
```

### FluentValidation — always validate commands

```csharp
// Every IRequest must have a corresponding AbstractValidator<T>
// Registered automatically via:
services.AddValidatorsFromAssembly(ApplicationAssembly);
services.AddMediatR(cfg => cfg.AddBehavior<IPipelineBehavior<,>, ValidationBehavior<,>>());

// Validator example — sanitise and constrain all inputs
public class CreateUserCommandValidator : AbstractValidator<CreateUserCommand>
{
    public CreateUserCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().EmailAddress().MaximumLength(256);

        RuleFor(x => x.UserName)
            .NotEmpty().MaximumLength(256)
            .Matches(@"^[a-zA-Z0-9._\-@]+$")  // No script-injection chars
            .WithMessage("Username contains invalid characters.");

        RuleFor(x => x.FirstName)
            .MaximumLength(100)
            .Matches(@"^[^<>""';&|]+$");  // No HTML/shell metacharacters
    }
}
```

---

## 8. Security headers middleware [SEC-05]

```csharp
// Web/Middleware/SecurityHeadersMiddleware.cs
public class SecurityHeadersMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var nonce = Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));
        context.Items["csp-nonce"] = nonce;

        context.Response.Headers["Content-Security-Policy"] =
            $"default-src 'self'; " +
            $"script-src 'self' 'nonce-{nonce}'; " +
            $"style-src 'self' 'nonce-{nonce}'; " +
            $"img-src 'self' data:; " +
            $"font-src 'self'; " +
            $"connect-src 'self'; " +
            $"frame-ancestors 'none';";

        context.Response.Headers["X-Frame-Options"] = "DENY";
        context.Response.Headers["X-Content-Type-Options"] = "nosniff";
        context.Response.Headers["Strict-Transport-Security"] =
            "max-age=31536000; includeSubDomains";
        context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
        context.Response.Headers["Permissions-Policy"] =
            "camera=(), microphone=(), geolocation=()";

        // Remove server fingerprinting headers
        context.Response.Headers.Remove("Server");
        context.Response.Headers.Remove("X-Powered-By");
        context.Response.Headers.Remove("X-AspNet-Version");

        await next(context);
    }
}

// Program.cs — register BEFORE UseRouting and UseAuthentication
app.UseMiddleware<SecurityHeadersMiddleware>();
```

---

## 9. Multi-tenancy isolation security

### Global Query Filter — the first line of defence [ARCH-01]

```csharp
// AppDbContext — every multi-tenant entity MUST have this filter
modelBuilder.Entity<ApplicationUser>()
    .HasQueryFilter(u => u.TenantId == _tenantContext.TenantId);

modelBuilder.Entity<PermissionGroup>()
    .HasQueryFilter(g => g.TenantId == _tenantContext.TenantId);
```

**Never use `IgnoreQueryFilters()` without:**
1. Being inside a designated system repository.
2. Writing a `Tenant.CrossTenantAccess` audit event.
3. Adding an explicit `Where(e => e.TenantId == targetTenantId)`.

### Tenant mismatch on login [ARCH-04]

```csharp
// Always verify that User.TenantId matches the resolved tenant from subdomain
if (user.TenantId != resolvedTenantId)
{
    await audit.LogAsync(AuditEvents.Auth.LoginFailure,
        new { Reason = "TenantMismatch", UserName = input.UserName, resolvedTenantId }, ct);

    return AuthResult.Fail(InvalidCredentialsMessage);  // Generic message [BFP-03]
}
```

### Redis key isolation [ARCH-08]

```
ALL Redis keys must be prefixed: "{tenantId}:{namespace}:{key}"

Examples:
  {tenantId}:revoked_jti:{jti}          ← JWT revocation list
  {tenantId}:pg_permissions:{pgId}      ← Permission Group cache
  {tenantId}:2fa_resend:{userId}        ← 2FA resend rate limit
  {tenantId}:rate_limit:login:{ip}      ← Login rate limit (per tenant+IP)
```

---

## 10. Authorization enforcement — two levels [CODE-03]

### Level 1 — Page / Controller attribute

```csharp
// Blazor page
@attribute [Authorize(Roles = "Superadmin,Administrator")]

// API controller action
[HttpDelete("{id}")]
[Authorize(Policy = "CanDeleteDashboard")]
public async Task<IActionResult> Delete(Guid id, CancellationToken ct) { ... }
```

### Level 2 — AuthorizationBehavior (MediatR pipeline)

```csharp
// Application/Behaviors/AuthorizationBehavior.cs
public class AuthorizationBehavior<TRequest, TResponse>(
    ICurrentUserAccessor currentUser,
    IPermissionService permissionService
) : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        if (request is IRequiresPermission permReq)
        {
            await permissionService.EnforceAsync(permReq.RequiredPermission, currentUser, ct);
            // Throws ForbiddenException → mapped to 403 by ExceptionHandlingMiddleware
        }
        return await next();
    }
}
```

**UI-only hiding is a security anti-pattern.** Backend must always enforce independently.

---

## 11. Secrets management [CODE-05/06]

### Development

```bash
# User Secrets — never commit to source
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;..." \
  --project src/CcDashboard.Web

dotnet user-secrets set "Jwt:PrivateKeyPath" "C:\keys\cc-dashboard-dev.pem" \
  --project src/CcDashboard.Web
```

### Production

```csharp
// Option A: Azure Key Vault
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{vaultName}.vault.azure.net/"),
    new DefaultAzureCredential());

// Option B: HashiCorp Vault
builder.Configuration.AddVaultConfiguration(...);

// Option C (minimum for on-prem): encrypted config via DPAPI / Windows Credential Manager
// DO NOT use plain-text appsettings.Production.json for secrets
```

**PostgreSQL connection:** Always `sslmode=verify-full` in connection string [CODE-06]:
```
Host=127.0.0.1;Database=ccdashboard;Username=app_user;Password=***;SSL Mode=VerifyFull;
```

---

## 12. Audit log security [AUD-01/02]

```sql
-- Grant INSERT and SELECT only — NEVER UPDATE or DELETE [AUD-02]
REVOKE UPDATE, DELETE ON audit.audit_logs FROM app_role;
GRANT SELECT, INSERT ON audit.audit_logs TO app_role;
```

```csharp
// AuditDbContext is SEPARATE from AppDbContext
// Audit writes never roll back with the business transaction [AUD-01]
public class AuditService(AuditDbContext auditDb, ICurrentUserAccessor currentUser,
    IHttpContextAccessor httpCtx, IDateTimeProvider clock) : IAuditService
{
    public async Task LogAsync(string eventType, object details, CancellationToken ct = default)
    {
        var entry = new AuditLog
        {
            Id = UUIDNext.Uuid.NewSequential(),
            TenantId = currentUser.TenantId,
            UserId = currentUser.UserId,
            UserName = currentUser.UserName ?? "system",
            EventType = eventType,
            EventResult = "Success",
            IpAddress = GetClientIp(),
            UserAgent = httpCtx.HttpContext?.Request.Headers.UserAgent.ToString(),
            Details = JsonSerializer.SerializeToDocument(details),
            CreatedAt = clock.UtcNow
        };

        auditDb.AuditLogs.Add(entry);
        await auditDb.SaveChangesAsync(ct);  // Separate SaveChanges — never rolls back
    }

    private string? GetClientIp()
    {
        // Use X-Forwarded-For with trusted proxy config [AUD-04]
        var forwarded = httpCtx.HttpContext?
            .Request.Headers["X-Forwarded-For"].FirstOrDefault();
        return forwarded?.Split(',').FirstOrDefault()?.Trim()
            ?? httpCtx.HttpContext?.Connection.RemoteIpAddress?.ToString();
    }
}
```

**Never log:**
- Plain-text passwords or password hashes
- Raw auth tokens (access or refresh)
- Full credit card / PAN numbers
- Raw OTP codes

---

## 13. CORS and anti-forgery [SEC-05]

### CORS — whitelist only

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("ApiCors", policy =>
    {
        policy.WithOrigins(config.GetSection("AllowedOrigins").Get<string[]>()!)
              .AllowCredentials()
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Authorization", "Content-Type");
        // Never .AllowAnyOrigin() in production
    });
});
```

### Blazor Server anti-forgery

Blazor Server auto-validates anti-forgery for form submissions.
For SSR pages, always include `<AntiforgeryToken />` inside forms:

```razor
<form method="post" @formname="my-form">
    <AntiforgeryToken />
    ...
</form>
```

### API anti-forgery — Origin check

```csharp
// REST API: validate SameSite=Strict cookie + Origin header
app.Use(async (context, next) =>
{
    if (context.Request.Method is "POST" or "PUT" or "DELETE" or "PATCH")
    {
        var origin = context.Request.Headers.Origin.ToString();
        if (!string.IsNullOrEmpty(origin) && !_allowedOrigins.Contains(origin))
        {
            context.Response.StatusCode = 403;
            return;
        }
    }
    await next();
});
```

---

## 14. PostgreSQL and Redis hardening [DEPLOY-08/09/11]

### PostgreSQL

```
# pg_hba.conf — reject ALL external connections
local   all   postgres   peer
host    all   all   127.0.0.1/32   scram-sha-256
hostssl all   all   127.0.0.1/32   scram-sha-256
# No external IPs allowed
```

```sql
-- Principle of least privilege
CREATE ROLE app_role LOGIN PASSWORD '***';
GRANT CONNECT ON DATABASE ccdashboard TO app_role;
GRANT USAGE ON SCHEMA public, identity TO app_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_role;
GRANT SELECT, INSERT ON audit.audit_logs TO app_role;
REVOKE UPDATE, DELETE ON audit.audit_logs FROM app_role;
```

### Redis

```
# redis.conf (Memurai)
bind 127.0.0.1
requirepass <strong-random-password>
rename-command FLUSHALL ""        # Disable dangerous commands
rename-command CONFIG ""
rename-command DEBUG ""
save 300 1                        # RDB snapshot every 5 min
```

---

## 15. Dependency scanning [CODE-07]

```powershell
# Run before every PR merge
dotnet list package --vulnerable --include-transitive

# Expected output: "No vulnerable packages"
# If any found:
#   CRITICAL / HIGH → fix within 48h, block PR
#   MEDIUM         → fix in next sprint, add to backlog
#   LOW            → schedule remediation

# Also run regularly in CI pipeline
```

---

## 16. Security code review checklist — per PR

```
Authentication & Sessions
  [ ] Cookie: __Host- prefix, HttpOnly, Secure, SameSite=Strict [AUTH-WEB-01]
  [ ] JWT: RS256 (not HS256), 15-min TTL [AUTH-API-02]
  [ ] Refresh tokens: stored as SHA-256 hash, never raw [AUTH-API-03]
  [ ] Token rotation implemented; reuse detection revokes ALL tokens [AUTH-API-04]
  [ ] Revoked JTIs added to Redis on logout/deactivation [AUTH-API-05]
  [ ] SecurityStamp updated on role/tenant/status change [AUTH-WEB-02]

Passwords & 2FA
  [ ] PBKDF2-HMACSHA512, 100k iterations [PWD-03]
  [ ] Last 10 password hashes checked on change [PWD-04]
  [ ] OTP generated via CSRNG, stored as HMAC-SHA256+salt [2FA-02/03]
  [ ] Max 3 OTP attempts enforced [2FA-04]
  [ ] Resend rate limit: 1/min per userId via Redis [2FA-04]

Authorisation
  [ ] [Authorize] on every page, controller, Hub method
  [ ] AuthorizationBehavior checks in MediatR pipeline [CODE-03]
  [ ] No UI-only permission hiding without backend check

Input & Output
  [ ] All inputs validated via FluentValidation
  [ ] No raw MarkupString without HtmlEncoder / sanitiser [CODE-02]
  [ ] No string-concatenated SQL [CODE-01]
  [ ] EF: AsNoTracking() on all read-only queries

Multi-tenancy
  [ ] GQF active on all multi-tenant entities [ARCH-01]
  [ ] IgnoreQueryFilters() guarded by CrossTenantAccess audit event
  [ ] Redis keys prefixed with tenantId [ARCH-08]
  [ ] Tenant mismatch on login returns generic error [ARCH-04]

Secrets & Config
  [ ] No secrets in appsettings.json or source code [CODE-05]
  [ ] PostgreSQL sslmode=verify-full [CODE-06]
  [ ] dotnet list package --vulnerable passes [CODE-07]

Logging & Audit
  [ ] Audit event written for every auth/permission change [AUD-01]
  [ ] No passwords, tokens, or OTP codes in logs [MAINT-02]
  [ ] AuditDbContext separate — never rolls back with business tx

Infrastructure
  [ ] Security headers middleware applied globally [SEC-05]
  [ ] CORS whitelist only — no AllowAnyOrigin
  [ ] Anti-forgery tokens in all SSR forms
```