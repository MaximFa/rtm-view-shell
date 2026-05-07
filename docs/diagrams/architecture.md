# RTM View Shell — Architecture Diagrams

## C4 Context

```mermaid
C4Context
    title System Context — RTM View Shell

    Person(agent, "CC Agent / Supervisor", "Views real-time dashboards")
    Person(admin, "Administrator", "Manages users, groups, tenants")
    Person(superadmin, "Superadmin", "Platform-wide management")

    System(shell, "RTM View Shell", "Blazor Server web shell; manages auth, users, permissions, and screen layout")

    System_Ext(postgres, "PostgreSQL 15+", "Primary data store (shared schema, TenantId GQF)")
    System_Ext(redis, "Redis 7+", "Session state, rate limits, revocation lists, PG permission cache")
    System_Ext(smtp, "SMTP / Email Provider", "2FA OTP codes, password reset, welcome emails")
    System_Ext(sso, "SSO Provider", "SAML2 / OIDC / AD-LDAP (v1 stub)")

    Rel(agent, shell, "HTTPS (Blazor Server)")
    Rel(admin, shell, "HTTPS (Blazor Server)")
    Rel(superadmin, shell, "HTTPS (Blazor Server)")
    Rel(shell, postgres, "EF Core 8 / Npgsql")
    Rel(shell, redis, "StackExchange.Redis")
    Rel(shell, smtp, "SmtpClient / SMTP")
    Rel(shell, sso, "OIDC / SAML2 / LDAP")
```

## C4 Container

```mermaid
C4Container
    title Container Diagram — RTM View Shell

    Person(user, "User")

    Container(web, "CcDashboard.Web", "Blazor Server (.NET 8)", "Interactive server-side UI, cookie auth, SignalR circuits")
    Container(api, "CcDashboard.Api", "ASP.NET Core Web API (.NET 8)", "Optional REST API, JWT Bearer auth")
    ContainerDb(postgres, "PostgreSQL 15+", "Relational Database", "Schemas: public, identity, audit")
    ContainerDb(redis, "Redis 7+", "Cache / State Store", "Revocation, rate limits, PG cache, SignalR backplane")
    Container(bg, "Background Services", "IHostedService", "Audit cleanup, soft-delete GC, token expiry")

    Rel(user, web, "HTTPS / WSS", "Blazor Server + SignalR")
    Rel(user, api, "HTTPS / JSON", "JWT Bearer")
    Rel(web, postgres, "TCP", "EF Core 8")
    Rel(api, postgres, "TCP", "EF Core 8")
    Rel(web, redis, "TCP", "StackExchange.Redis")
    Rel(api, redis, "TCP")
    Rel(bg, postgres, "TCP")
    Rel(bg, redis, "TCP")
```

## Dependency Rules (Clean Architecture)

```mermaid
graph TD
    Domain["Domain\n(entities, interfaces, enums)"]
    Contracts["Contracts\n(DTOs, result types)"]
    Application["Application\n(CQRS, use-cases, validators)"]
    Infrastructure["Infrastructure\n(EF Core, Identity, Redis, SMTP)"]
    Web["Web / Api\n(Blazor Server, REST API)"]

    Contracts --> Domain
    Application --> Domain
    Application --> Contracts
    Infrastructure --> Application
    Infrastructure --> Domain
    Web --> Application
    Web --> Contracts
    Web -.->|"Program.cs only"| Infrastructure
```

## MediatR Pipeline

```mermaid
graph LR
    A[LoggingBehavior] --> B[ValidationBehavior]
    B --> C[TransactionBehavior]
    C --> D[AuthorizationBehavior]
    D --> E[AuditBehavior]
    E --> F[Handler]
```

## Login + 2FA Sequence

```mermaid
sequenceDiagram
    actor User
    participant Browser
    participant LoginPage as LoginPage (SSR)
    participant IdentityAuth as IdentityAuthService
    participant SignInMgr as SignInManager
    participant TwoFA as TwoFactorService
    participant Redis
    participant Email as IEmailSender
    participant TwoFAPage as TwoFactorPage (SSR)

    User->>Browser: Enter username + password
    Browser->>LoginPage: POST /login
    LoginPage->>IdentityAuth: PasswordSignInAsync(tenantId, user, pw)
    IdentityAuth->>SignInMgr: CheckPasswordSignInAsync(lockoutOnFailure=true)
    SignInMgr-->>IdentityAuth: Succeeded

    alt 2FA enabled
        IdentityAuth->>Browser: Set TwoFactorUserIdScheme cookie
        IdentityAuth->>TwoFA: SendCodeAsync(userId, tenantId, email)
        TwoFA->>Redis: SET 2fa_resend:{userId} TTL=60s
        TwoFA->>Email: Send OTP code
        IdentityAuth-->>LoginPage: RequiresTwoFactor
        LoginPage-->>Browser: Redirect /login/2fa

        User->>Browser: Enter 6-digit OTP
        Browser->>TwoFAPage: POST /login/2fa
        TwoFAPage->>IdentityAuth: CompleteTwoFactorAsync(code)
        IdentityAuth->>Browser: AuthenticateAsync(TwoFactorUserIdScheme)
        IdentityAuth->>TwoFA: VerifyCodeAsync(userId, code)
        TwoFA-->>IdentityAuth: Succeeded
        IdentityAuth->>SignInMgr: SignInAsync(user)
        IdentityAuth->>Browser: Clear TwoFactorUserIdScheme cookie
        IdentityAuth-->>TwoFAPage: Login.Success
        TwoFAPage-->>Browser: Redirect /screens
    else No 2FA
        IdentityAuth->>SignInMgr: SignInAsync(user)
        IdentityAuth-->>LoginPage: Login.Success
        LoginPage-->>Browser: Redirect /screens
    end
```

## ER Diagram (Core Entities)

```mermaid
erDiagram
    tenants ||--o{ users : "has"
    tenants ||--|| tenant_settings : "has"
    tenants ||--o{ permission_groups : "has"
    tenants ||--o{ dashboards : "has"

    users ||--o{ refresh_tokens : "has"
    users ||--o{ two_factor_codes : "has"
    users ||--o{ user_password_history : "has"
    users }o--|| permission_groups : "belongs to"

    permission_groups ||--o{ menu_permissions : "has"
    permission_groups ||--o{ dashboard_permissions : "has"
    permission_groups ||--o{ pg_queues : "has"
    permission_groups ||--o{ pg_skills : "has"

    dashboards ||--o{ dashboard_permissions : "has"
    dashboards ||--o{ dashboard_widgets : "has"

    widget_catalog ||--o{ dashboard_widgets : "used in"

    tenants {
        uuid id PK
        string slug
        string name
        string status
    }

    users {
        uuid id PK
        uuid tenant_id FK
        uuid permission_group_id FK
        string username
        string email
        bool is_active
        bool is_2fa_enabled
        timestamptz must_change_password_at
    }

    permission_groups {
        uuid id PK
        uuid tenant_id FK
        string name
        bool is_active
        uint row_version
    }

    dashboards {
        uuid id PK
        uuid tenant_id FK
        string name
        bool is_public
        string status
        bool is_deleted
        uint row_version
    }
```
