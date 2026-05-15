TECHNICAL SPECIFICATION
Real-Time Contact Centre Data Display Shell
(CC Dashboard Shell)

Version 1.2
Date: 2026

# Change History

| Version | Date | Changes |
| --- | --- | --- |
| 1.0 | 2026-04 | Initial document revision. |
| 1.1 | 2026-05 | Cross-replacement MS SQL Server → PostgreSQL 15+. Section 2 reworked after review: Blazor authentication (cookie) and API (JWT) separated; Clean Architecture and dependency directions fixed; cross-cutting concerns added; tenant resolution strategy chosen (subdomain with fallback); cross-tenant entities, tenant lifecycle, Superadmin-bypass mechanism described; background services, cache isolation, SignalR group, blob storage requirements added; Solution structure supplemented with Contracts, Tests.Architecture, Tests.Security projects; data model aligned with sections 4–7, missing tables added (RefreshTokens, UserPasswordHistory, TwoFactorCodes, TenantSettings, SsoConfigurations, EmailProviderSettings, MenuPermissions, DashboardPermissions); UTC, optimistic concurrency, soft-delete metadata, encryption, seed data requirements added; ER diagram moved to Appendix D. |
| 1.2 | 2026-05 | Target deployment platform changed from Docker to local installation on Windows Server (2019+/2022+), all-in-one (Web + API + PostgreSQL + Redis on one machine). Section 10 rewritten: server preparation requirements, IIS hosting (in-process via ASP.NET Core Module), service account/gMSA, PostgreSQL and Redis for Windows installation, TLS certificate, Windows Firewall, log rotation; CI/CD redirected to building self-contained package (folder publish + MSI/archive) and delivery via WebDeploy/PowerShell DSC. Section 1.5: "Containerisation" replaced with "Hosting and OS". ARCH-00 clarified (two IIS websites instead of two Docker containers). REL-03: backup using pg_basebackup as scheduled task + WAL archive on separate disk. SCALE-01..03 adapted for all-in-one with explicit note that horizontal scaling is out of scope for v1 but architecture does not prevent it. Appendix B (OWASP A05): non-root Docker replaced with Windows hardening. Appendix C: questions about backup scheme and Redis distribution added. |


# Table of Contents
1. General Provisions
1.1 Document Purpose
1.2 System Goals and Objectives
1.3 Project Scope
1.4 Terms and Definitions
1.5 Technology Stack
2. System Architecture
2.1 General Architecture
2.2 Multi-tenancy
2.3 Project Structure (.NET Solution)
2.4 Data Model — Key Entities
2.5 Diagram Requirements
3. User Management
3.1 User Roles
3.2 User Attributes
3.3 Functional Requirements — User Management
4. Permission Management System (Permission Groups)
4.1 Concept
4.2 Permission Structure
4.3 Managing Permission Groups
5. Authentication and Security
5.1 General Security Requirements
5.2 Authentication — Blazor Server (cookie)
5.3 Authentication — REST API (JWT)
5.4 Password Policy
5.5 Brute Force Protection
5.6 Two-Factor Authentication (2FA)
5.7 Single Sign-On (SSO)
5.8 Secure Code Requirements
6. Connection and Action Audit
6.1 Audit Record Structure
6.2 Auditable Event Types
6.3 Audit Requirements
6.4 Audit UI Page
7. Dashboard (Screen) Management
7.1 Dashboard Model
7.2 Functional Requirements
7.3 Widget Catalogue
8. Localisation and Internationalisation (i18n)
9. Non-Functional Requirements
10. Deployment Requirements
11. Appendices

# 1. General Provisions
## 1.1 Document Purpose
This Technical Specification (hereinafter — TS) defines the requirements for the development of the real-time contact centre data display graphical shell (hereinafter — CC Dashboard Shell, or the System).
The document serves as the basis for development, testing and acceptance of the System.
## 1.2 System Goals and Objectives
The System is designed to provide a web interface that enables:
- creating and managing dashboards (screens) based on Blazor Server components;
- managing users, permission groups (Permission Groups) and their rights;
- providing secure user authentication and authorisation;
- auditing security events and user actions;
- supporting a multi-tenant model (multiple client organisations);
- supporting any interface language with RTL/LTR layout.
## 1.3 Project Scope
The following are implemented within this TS:
- Shell: navigation menu, user management, permission groups, audit, widget selection from catalogue.
- Security: cookie authentication for Blazor Server, JWT authentication for REST API, 2FA via email, SSO preparation (SAML 2.0 / OAuth 2.0 / OIDC / AD — protocol determined during design), connection auditing.
- Multi-tenancy: data isolation at Tenant level, chosen resolution strategy — subdomain.

The following are NOT implemented within this TS:
- Data visualisation components (widgets) — only selection from catalogue.
- Drag-and-drop placement and widget configuration on screen.
- Integration with real-time data sources (specific CC platforms).
## 1.4 Terms and Definitions

| Term | Definition |
| --- | --- |
| CC Dashboard Shell | Graphical shell — subject of this TS |
| Tenant | Client organisation in a multi-tenant system |
| Permission Group (PG) | Permission group defining user rights |
| Dashboard / Screen | Page with a set of widgets created by a user |
| Widget | Data visualisation component connected to a dashboard |
| Queue | Service queue in a contact centre |
| Skill | Contact centre operator skill |
| Agent Supergroup | Contact centre operator supergroup |
| Business Unit | Contact centre business division |
| JWT | JSON Web Token — authorisation token standard (RFC 7519) |
| 2FA | Two-Factor Authentication |
| SSO | Single Sign-On |
| RBAC | Role-Based Access Control |
| RTL / LTR | Right-to-Left / Left-to-Right — text direction |
| Tenant Resolution | Mechanism for determining the current tenant from a request (in this TS — by subdomain) |
| Cross-tenant entity | DB entity shared across the whole platform, not subject to Global Query Filter by TenantId |
| UUIDv7 | Time-ordered UUID (RFC 9562) — used as PK to optimise B-Tree indexes in PostgreSQL |
| JSONB | PostgreSQL binary JSON type with indexing support |

## 1.5 Technology Stack

| Component | Technology |
| --- | --- |
| Frontend / UI (shell) | Blazor Server (.NET 8+) — cookie authentication |
| Backend / REST API (optional) | ASP.NET Core Web API + SignalR (.NET 8+) — JWT Bearer |
| Database | PostgreSQL 15+ (16+ recommended) |
| ORM | Entity Framework Core 8+ (Code-First) with Npgsql.EntityFrameworkCore.PostgreSQL provider |
| Authentication | ASP.NET Core Identity + Cookie (Blazor) + JWT Bearer (API) |
| Distributed cache / state | Redis 7+ (for token revocation, rate limiting, permission cache, SignalR backplane for horizontal scaling) |
| Email | Configurable provider (IEmailSender): SMTP / external service |
| Column encryption | pgcrypto + ASP.NET Core Data Protection |
| Hosting and OS | Windows Server 2019+ / 2022+; IIS (in-process via ASP.NET Core Module) |
| Deployment model | Local installation on customer server, all-in-one (Web + API + PostgreSQL + Redis on one machine). Horizontal scale-out — outside v1 scope, but architecturally not prohibited. |
| Development language | C# 12+ |


# 2. System Architecture
## 2.1 General Architecture
The System is implemented in Clean Architecture (Onion) style with the following layers and dependency direction: Domain ← Application ← Infrastructure ← Presentation (Web / Api). Dependencies point strictly inward: upper layers have no knowledge of lower ones. CQRS is applied within a single database (Command/Query separation via MediatR without a separate read model and without event sourcing).
Layer composition:
- Presentation Layer (Web) — Blazor Server (server-side rendering, interactivity via SignalR). Uses ASP.NET Core Identity cookie authentication. JWT is not applied to Blazor circuit (see 5.2).
- Presentation Layer (Api, optional) — ASP.NET Core Web API for external integrations and future SPA/mobile clients. Uses JWT Bearer.
- Application Layer — business logic services, MediatR commands and queries (CQRS), DTOs, FluentValidation validators, pipeline behaviours (logging, validation, transactions, authorisation).
- Domain Layer — domain models, enumerations, value objects, domain interfaces (repositories, domain services). No dependencies on any other Solution projects.
- Infrastructure Layer — repository implementations (EF Core / Npgsql), Identity store, email delivery, audit, external integrations (SSO, blob storage, Redis), background services.
- Database Layer — PostgreSQL 15+ with tenant data separation via Global Query Filter.
Cross-cutting concerns, implemented in Infrastructure and registered in the DI container at the composition root:
- ITenantContext — current TenantId; implemented via AsyncLocal or ScopedService, initialised by middleware/CircuitHandler.
- ICurrentUserAccessor — current UserId, UserName, Role, PermissionGroupId, locale; read from ClaimsPrincipal.
- IDateTimeProvider — all timestamps are taken from this service; always UTC.
- IUnitOfWork — wraps SaveChanges in a PostgreSQL transaction.
- MediatR pipeline behaviours: LoggingBehavior, ValidationBehavior (FluentValidation), TransactionBehavior, AuthorizationBehavior, AuditBehavior.
- Global exception handler (ExceptionHandlerMiddleware) returning ProblemDetails for API and user-friendly pages for Blazor.
[ARCH-00] Composition root: Web (Blazor Server) and Api (if enabled) are built as two independent ASP.NET Core hosts (two Program.cs), deployed as two separate IIS sites (or Application Pools) on the same Windows Server, see section 10. Business logic is shared via the common CcDashboard.Application assembly (see 2.3) — duplication is prohibited: API controllers must delegate to the same MediatR commands/queries as Blazor pages.
## 2.2 Multi-tenancy
The multi-tenancy architecture uses a shared database with a Tenant discriminator (Shared Database, Shared Schema). Each record in multi-tenant tables contains a TenantId (uuid) field.
[ARCH-01] All queries to multi-tenant tables must be automatically filtered by TenantId of the current ITenantContext via Global Query Filter in EF Core. Bypassing the filter (IgnoreQueryFilters) is only permitted in dedicated repositories for system services and Superadmin-level operations; each such usage is accompanied by an AuditLog entry with EventType = Tenant.CrossTenantAccess.
[ARCH-02] The platform Superadmin must be able to switch between tenants via a dedicated administrative interface. Switching is implemented as a change of TenantId in the active Superadmin session (cookie claim for Blazor / JWT refresh for Api), with mandatory recording of Tenant.Switched event in AuditLog.
[ARCH-03] Tenant resolution: the current tenant is determined by the request subdomain (e.g. acme.cc-dashboard.local → tenant slug = "acme"). The resolver is implemented as middleware (ASP.NET Core) and CircuitHandler (Blazor Server). If the tenant cannot be determined (e.g. access via root domain) the user is redirected to a tenant selection page, then redirected to the corresponding subdomain. Alternative strategies (path-based, header-based) may be enabled in a future version via additional ITenantResolver implementations.
[ARCH-04] During authentication, the system verifies that the user's TenantId matches the tenant determined from the request. On mismatch, login is rejected with the message "Invalid credentials" (without disclosing the reason). The event is recorded in AuditLog as Login.Failure with subtype TenantMismatch.
[ARCH-05] Cross-tenant (platform) entities, not subject to Global Query Filter: Tenant, WidgetCatalogItem, Role (ASP.NET Identity), MenuItem (if the menu reference is stored in the DB). All other tables are multi-tenant.
[ARCH-06] Tenant lifecycle: the Tenant entity must have a Status field (enum: Active, Suspended, Deleted). System behaviour: Active — normal operation; Suspended — all login attempts by users of this tenant are rejected with the message "Access to the organisation is temporarily suspended"; Deleted — users of this tenant do not exist for authentication, data is not displayed. Physical deletion of tenant data is performed by a separate background procedure no earlier than 30 days after transition to Deleted, with mandatory GDPR export before deletion.
[ARCH-07] Background services (IHostedService) run outside user context. To access multi-tenant data, a background service must: (a) create a dedicated DI scope; (b) explicitly set TenantId in ITenantContext before operations; (c) either iterate over all active tenants, or use SystemTenantContext with IgnoreQueryFilters and explicit invariant checks.
[ARCH-08] All distributed cache (Redis) and in-memory cache keys must include TenantId in the key prefix (format: "{tenantId}:{namespace}:{key}"). This applies to token revocation list, rate limiting counters, Permission Group permission cache, tenant-level localised string cache.
[ARCH-09] SignalR groups and broadcast messages must be prefixed with TenantId (group name format: "t:{tenantId}:{groupName}"). Hub methods must verify TenantId in ClaimsPrincipal before adding a connection to a group.
[ARCH-10] File storage (widget icons, audit CSV exports, tenant logos) — via IBlobStorage abstraction. Implementations (local disk, S3-compatible storage, Azure Blob) must isolate tenant data: either by a separate container/bucket per tenant, or by a "{tenantId}/..." prefix in a shared container. Access to foreign paths must return 404 without disclosing existence.
## 2.3 Project Structure (.NET Solution)
Solution structure and dependency directions between projects:

| Project | Purpose | Depends on |
| --- | --- | --- |
| CcDashboard.Domain | Entities, value objects, enumerations, domain interfaces (repositories, domain services). | BCL only (System.*). |
| CcDashboard.Contracts | DTOs, ProblemDetails, strongly-typed IDs (TenantId, UserId), common enums, ResultMonad. | BCL only. |
| CcDashboard.Application | Services, MediatR commands/queries, FluentValidation validators, mapping (Mapster/AutoMapper), pipeline behaviours, infrastructure port interfaces. | Domain, Contracts. |
| CcDashboard.Infrastructure | EF Core DbContext, entity configurations, migrations, repositories, Identity store, EmailSender, BlobStorage, SSO adapters, background services. | Domain, Contracts, Application. |
| CcDashboard.Web | Blazor Server: pages, components, SignalR hubs, cookie authentication, composition root. | Application, Infrastructure (only in Program.cs / DI registrations). |
| CcDashboard.Api | ASP.NET Core Web API (optional): controllers, JWT Bearer, OpenAPI, composition root. | Application, Infrastructure (only in Program.cs). |
| CcDashboard.Tests.Unit | Unit tests for domain logic and Application services (xUnit + FluentAssertions + Moq/NSubstitute). | Domain, Application. |
| CcDashboard.Tests.Integration | Integration tests with real PostgreSQL (Testcontainers) and WebApplicationFactory. | Web, Api, Infrastructure. |
| CcDashboard.Tests.Architecture | Architectural tests on NetArchTest (dependency direction control per 2.3 and 2.1). | All projects as assemblies for reflection. |
| CcDashboard.Tests.Security | Security tests: cross-tenant isolation, JWT validation, token revocation, refresh reuse detection, login attempt limiting, correct Permission Group filtering. | Web, Api. |

[ARCH-11] Direct use of Infrastructure classes in Web/Api beyond the composition root (Program.cs and DI registrations) is prohibited. All access is via interfaces from Application and Domain. This rule is automatically enforced by CcDashboard.Tests.Architecture tests.
## 2.4 Data Model — Key Entities
Entity and DB table listing. ER diagram is in Appendix D. Standards: PK = uuid (UUIDv7, generated on application side); all timestamp fields — timestamptz; table names — pluralized snake_case or CamelCase (fixed in EF convention); PostgreSQL schemas: public — business data, audit — audit tables, identity — ASP.NET Core Identity tables.

| Entity | DB Table | Tenant? | Description |
| --- | --- | --- | --- |
| Tenant | tenants | cross-tenant | Client organisation. Fields: Id, Slug (for subdomain), Name, Status (Active/Suspended/Deleted), CreatedAt, UpdatedAt. |
| ApplicationUser | identity.users | multi-tenant | System user (inherits IdentityUser<Guid>). See 3.2. |
| ApplicationRole | identity.roles | cross-tenant | System role (inherits IdentityRole<Guid>): Superadmin, Administrator, Editor, Viewer. |
| IdentityUserRole / ... | identity.* (standard) | multi-tenant (UserRole) / cross-tenant (Role) | Standard ASP.NET Core Identity tables. |
| UserPasswordHistory | identity.user_password_history | multi-tenant | User password hash history (last 10). Fields: Id, UserId, PasswordHash, CreatedAt. See PWD-04. |
| RefreshToken | identity.refresh_tokens | multi-tenant | API Refresh tokens. Fields: Id, UserId, TenantId, Jti, TokenHash (SHA-256), ExpiresAt, IssuedAt, RevokedAt?, ReplacedByTokenId?, IpAddress, UserAgent. See AUTH-03..05. |
| TwoFactorCode | identity.two_factor_codes | multi-tenant | OTP 2FA codes. Fields: Id, UserId, TenantId, CodeHash (HMAC-SHA256), Salt, ExpiresAt, AttemptCount, ConsumedAt?. See 2FA-02..04. |
| PermissionGroup | permission_groups | multi-tenant | Permission group. Fields: Id, TenantId, Name, Description, IsActive, RowVersion (xmin), CreatedAt, CreatedByUserId, UpdatedAt, UpdatedByUserId. |
| MenuPermission | menu_permissions | multi-tenant | PG permissions for menu items. PK = (PermissionGroupId, MenuKey). See 4.2.1. |
| DashboardPermission | dashboard_permissions | multi-tenant | PG permissions for dashboards. Fields: PermissionGroupId, DashboardId, AccessLevel (bitmask: View=1, Edit=2, Delete=4). See 4.2.2. |
| Dashboard | dashboards | multi-tenant | Screen. Fields: Id, TenantId, Name, Description, IsPublic, CreatedByUserId, CreatedAt, UpdatedAt, UpdatedByUserId, IsDeleted, DeletedAt?, DeletedByUserId?, RowVersion (xmin), LayoutJson (jsonb). |
| DashboardWidget | dashboard_widgets | multi-tenant | Widget on dashboard (reserved for next version): Id, DashboardId, WidgetCatalogItemId, PositionJson (jsonb), ConfigJson (jsonb). |
| WidgetCatalogItem | widget_catalog | cross-tenant | Widget catalogue. Fields: Id, Category, Name, Description, IconUrl, IsActive. |
| Queue | queues | multi-tenant | CC queue. Fields: Id, TenantId, ExternalId, Name, IsActive. |
| Skill | skills | multi-tenant | Skill. Same as Queue. |
| AgentSupergroup | agent_supergroups | multi-tenant | Supergroup. Same as Queue. |
| BusinessUnit | business_units | multi-tenant | Business unit. Same as Queue. |
| PG_Queue / PG_Skill / PG_AgentSupergroup / PG_BusinessUnit | pg_queues / pg_skills / pg_agent_supergroups / pg_business_units | multi-tenant | Lists of allowed CC objects per PG. PK = (PermissionGroupId, ObjectId). |
| TenantSettings | tenant_settings | multi-tenant | Tenant settings (one-to-one with Tenant): PasswordPolicy (json), Require2faForAll, AuditRetentionDays, DefaultLocale, EmailProviderConfig (encrypted via pgcrypto), SsoConfigurationId?. |
| SsoConfiguration | sso_configurations | multi-tenant | SSO settings for tenant. Fields: Id, TenantId, Provider (SAML/OIDC/AD), MetadataUrl, ClientId, ClientSecret (encrypted), ClaimMappings (jsonb), IsActive. |
| AuditLog | audit.audit_logs | multi-tenant (TenantId nullable) | Audit log entry. Partitioned by month on CreatedAt (declarative in PostgreSQL). Details field — jsonb with GIN index. |

[DATA-01] All timestamp fields are stored in UTC (PostgreSQL timestamptz). Conversion to user local time (based on PreferredLocale) is performed at the UI layer.
[DATA-02] All mutable business entities implement the IAuditableEntity interface (fields CreatedAt, CreatedByUserId, UpdatedAt, UpdatedByUserId), automatically populated by EF Core SaveChangesInterceptor. Entity audit fields do not replace AuditLog (section 6) and are intended for UI display.
[DATA-03] Optimistic concurrency for frequently edited entities (Dashboard, PermissionGroup): the PostgreSQL system column xmin is used as a concurrency token (via [ConcurrencyCheck] attribute and Npgsql convention). On conflict, DbUpdateConcurrencyException is returned, which at the UI level is converted to the message "Record modified by another user".
[DATA-04] Soft-delete for Dashboard is enabled by a tenant configuration flag. When enabled, Global Query Filter "e => !e.IsDeleted" is added (combined with TenantId filter), and IsDeleted, DeletedAt, DeletedByUserId fields are populated on the entity. Physical deletion of soft-deleted dashboards is performed by a scheduled background service (configurable, default 90 days).
[DATA-05] Primary keys of all entities are uuid, generated as UUIDv7 (RFC 9562) on the application side. This ensures time-monotonicity and minimises B-Tree index fragmentation in PostgreSQL. Using gen_random_uuid() (UUIDv4) for multi-tenant table PKs is prohibited.
[DATA-06] Encryption of sensitive columns (TenantSettings.EmailProviderConfig, SsoConfiguration.ClientSecret, potentially other secrets): at the application level via ASP.NET Core Data Protection with keys in Azure Key Vault / HashiCorp Vault. Additionally, pgcrypto may be enabled in PostgreSQL for DB-level encryption (determined during design). OTP hashes, refresh token hashes and password hashes do not require additional encryption (already hashed).
[DATA-07] Seeding (initial data migration): at first launch — Identity roles (Superadmin, Administrator, Editor, Viewer); "platform" system tenant with a Superadmin account; mandatory Superadmin password change on first login. Seeding is idempotent.
[DATA-08] Unique indexes: tenants(slug); identity.users(NormalizedEmail, TenantId); identity.users(NormalizedUserName, TenantId); permission_groups(TenantId, Name). Regular indexes: all FK fields; audit.audit_logs(TenantId, CreatedAt DESC); audit.audit_logs(EventType, CreatedAt DESC); audit.audit_logs USING GIN (Details jsonb_path_ops); dashboards(TenantId, Name).
## 2.5 Diagram Requirements
[ARCH-12] Before development begins, the developer must provide and keep up to date the following diagrams (PlantUML or Mermaid in repository, exported as PNG/SVG): C4 Context diagram — user, shell, DB, Redis, email provider, SSO interaction. C4 Container diagram — Web, Api, PostgreSQL, Redis, background services. C4 Component diagram — main Application and Infrastructure modules. ER database diagram (Appendix D). Sequence diagrams: Login + 2FA, Refresh Token, Tenant resolution processes.

# 3. User Management
## 3.1 User Roles
The system defines four fixed roles, implemented via ASP.NET Core Identity Roles (identity.roles table, IdentityRole<Guid>). Role assignment — via IdentityUserRole. One user — one role (invariant, checked on save).

| Role | Permissions and Capabilities |
| --- | --- |
| Superadmin | Full access to all functions of all tenants. Management of tenants and their lifecycle. Not restricted by Permission Group. |
| Administrator | Managing users, Permission Groups and settings within their tenant. Viewing tenant audit. Creating/editing/deleting dashboards within their PG. |
| Editor | Creating, editing and deleting dashboards within their PG permissions. |
| Viewer | View-only access to dashboards available according to their Permission Group. |

⚠ Note: Role defines the type of access (what a user can do in principle). Permission Group defines which specific objects that access applies to.
## 3.2 User Attributes
ApplicationUser : IdentityUser<Guid>. Additional fields beyond standard:

| Field | Type | Description |
| --- | --- | --- |
| Id | uuid (UUIDv7) | Unique identifier (PK), inherited from IdentityUser |
| TenantId | uuid | Tenant membership |
| UserName | varchar(256) | Login (unique within tenant; index by NormalizedUserName + TenantId) |
| Email | varchar(256) | Email; unique within tenant; used for 2FA and notifications |
| PasswordHash | text | Password hash (managed by Identity, PBKDF2) |
| FirstName | varchar(100) | First name |
| LastName | varchar(100) | Last name |
| PermissionGroupId | uuid? | Reference to Permission Group (NULL for Superadmin role) |
| IsActive | boolean | Activity flag (soft lock) |
| Is2faEnabled | boolean | Whether email-based 2FA is enabled for the user |
| AccessFailedCount | integer | Failed attempt counter (standard Identity field) |
| LockoutEnd | timestamptz? | Lockout end time (standard Identity field) |
| CreatedAt | timestamptz | Creation date (UTC) |
| LastLoginAt | timestamptz? | Last successful login (UTC) |
| PreferredLocale | varchar(10) | Interface language (BCP-47, e.g. en-US, ar-AE) |
| MustChangePasswordAt | timestamptz? | If set — password change required at next login |

⚠ Note: The Role field is absent from the users table itself: the role is stored in the standard identity.user_roles table. A "user role" query is materialised via JOIN or denormalised into a claim at authentication time.
## 3.3 Functional Requirements — User Management
### 3.3.1 User Creation
[USR-01] Administrator and Superadmin can create new users within their tenant.
[USR-02] User creation requires: UserName, Email, Role, PermissionGroupId (if role is not Superadmin).
[USR-03] The system must generate a temporary password and send it to the user's email. On first login the user must change the password (MustChangePasswordAt = NOW()).
[USR-04] Email must pass format validation and uniqueness check within the tenant. Email duplication is not permitted.
[USR-05] Administrator cannot create users with the Superadmin role or with a TenantId different from their own.
### 3.3.2 User Editing
[USR-06] The following fields are editable: FirstName, LastName, Email, Role, PermissionGroupId, IsActive, PreferredLocale.
[USR-07] A user role change must be recorded in the audit log with the previous and new role.
[USR-08] An administrator cannot change their own role.
### 3.3.3 Deactivation and Restoration
[USR-09] Administrator can deactivate a user (IsActive = false). A deactivated user immediately loses the ability to log in; active sessions — for Blazor are terminated via CircuitHandler on IsActive change event, for Api all their refresh tokens are marked Revoked, access tokens are added to the revocation list (see AUTH-05).
[USR-10] Restoration (IsActive = true) is available to Administrator and Superadmin.
### 3.3.4 Password Reset
[USR-11] Administrator can initiate a password reset for any tenant user. The system generates a one-time token (stored in identity.user_tokens, 24-hour TTL) and sends a link with the token to the user's email.
[USR-12] A user can independently request a password reset via the "Forgot password?" form. The link is sent to the registered email (regardless of user existence, the UI response is uniform — see BFP-03).
### 3.3.5 User List Viewing
[USR-13] The user list must support server-side pagination (page size: 10/25/50/100), sorting by all fields, and filtering by: UserName, Email, Role, PermissionGroup, IsActive.
[USR-14] Administrator sees only their tenant's users. Superadmin sees users of all tenants with TenantId filter.

# 4. Permission Management System (Permission Groups)
## 4.1 Concept
Each user (except Superadmin) belongs to exactly one Permission Group. The Permission Group defines:
- Visibility of navigation menu items (via menu_permissions table).
- Access to screens (dashboards): View, Edit, Delete (via dashboard_permissions table).
- Filtering of CC object data: Queues, Skills, Agent Supergroups, Business Units (via pg_queues, pg_skills, pg_agent_supergroups, pg_business_units tables).
⚠ Note: Permission Group does not replace role. Role defines the type of action, PG — the scope of application.
## 4.2 Permission Structure
### 4.2.1 Menu Permissions

| Menu Item | Permission Key | Applicable Roles |
| --- | --- | --- |
| Dashboards | menu.dashboards | All roles |
| User Management | menu.users | Superadmin, Administrator |
| Permission Groups | menu.permissionGroups | Superadmin, Administrator |
| Widget Catalogue | menu.widgetCatalog | Superadmin, Administrator, Editor |
| Audit | menu.audit | Superadmin, Administrator |
| Tenant Settings | menu.tenantSettings | Superadmin, Administrator |
| Tenant Management | menu.tenants | Superadmin only |

### 4.2.2 Screen (Dashboard) Permissions
Stored in dashboard_permissions table with AccessLevel bitmask:

| Right | Mask Value | Description |
| --- | --- | --- |
| View | 1 | View screen and its contents |
| Edit | 2 | Change widget composition and configuration (includes View). Mask: 3 |
| Delete | 4 | Delete screen (includes View). Mask: 5 |
| Full | 7 | View + Edit + Delete |

[PG-01] A screen can be created by a user with the role Editor or Administrator. When creating a screen, the creator and their PG are automatically assigned AccessLevel = Full (7).
[PG-02] Superadmin has full access to all screens of all tenants without PG restrictions.
### 4.2.3 Contact Centre Object Permissions

| Object Type | Junction Table | Description |
| --- | --- | --- |
| Queue | pg_queues | Allowed service queues |
| Skill | pg_skills | Allowed operator skills |
| Agent Supergroup | pg_agent_supergroups | Allowed operator supergroups |
| Business Unit | pg_business_units | Allowed business divisions |

[PG-03] If a Permission Group contains no explicit list of objects of a given type (list is empty), access to all objects of that type is considered denied.
[PG-04] CC object filtering must be applied at the Application Layer (in MediatR query handlers), not only at the UI level. Implementation — via AuthorizationBehavior pipeline.
## 4.3 Managing Permission Groups
[PG-05] Administrator and Superadmin can create, edit and delete PGs within a tenant.
[PG-06] Deleting a PG is not permitted if at least one user is assigned to it. The system must return an error with the count and list of users.
[PG-07] When editing a PG, changes are applied to user sessions of that group at the next token/cookie refresh or forcibly via SignalR notification requiring re-authentication. The Redis permission cache is invalidated immediately.
[PG-08] The PG list supports pagination, sorting by name, and filtering by name and active status.

# 5. Authentication and Security
## 5.1 General Security Requirements
[SEC-01] All traffic must be transmitted exclusively over HTTPS (TLS 1.2+). HTTP must automatically redirect to HTTPS.
[SEC-02] HTTP security headers must be configured: Content-Security-Policy, X-Frame-Options: DENY, X-Content-Type-Options: nosniff, Strict-Transport-Security (HSTS), Referrer-Policy: strict-origin-when-cross-origin, Permissions-Policy.
[SEC-03] Sensitive data (passwords, OTP codes, secrets) must never be logged or placed in URL parameters.
[SEC-04] All input data must be validated at the Application Layer (FluentValidation via MediatR ValidationBehavior). EF Core / Npgsql parameterised queries are mandatory — direct string concatenation in SQL queries is prohibited.
[SEC-05] Anti-forgery (CSRF) tokens must be applied to all state-modifying forms. In Blazor Server this is automatic; if REST API is present — via AntiforgeryMiddleware or protection at SameSite=Strict cookie + Origin check level.
## 5.2 Authentication — Blazor Server (cookie)
[AUTH-WEB-01] Blazor Server authentication is implemented via ASP.NET Core Identity with cookie scheme (AddIdentity / UseAuthentication). Cookie: HttpOnly, Secure, SameSite=Strict, sliding expiration 30 minutes (configurable per tenant), absolute expiration 8 hours. Cookie name is prefixed with "__Host-".
[AUTH-WEB-02] TenantId and Role are materialised in user claims at login. Changes to TenantId or Role in the DB require re-authentication (see PG-07).
[AUTH-WEB-03] Session termination (logout) deletes the cookie and invalidates the server-side circuit representation. Forced logout of all user sessions — via SecurityStamp change in IdentityUser (standard Identity mechanism).
## 5.3 Authentication — REST API (JWT)
[AUTH-API-01] REST API authentication is implemented via JWT Bearer (RFC 7519).
[AUTH-API-02] JWT Access Token: lifetime — 15 minutes. Signing algorithm — RS256 (asymmetric, RSA-2048 minimum). Payload: sub (UserId), tenant_id, role, permission_group_id, jti, iat, exp, iss, aud.
[AUTH-API-03] Refresh Token: lifetime — 8 hours (configurable per tenant). Stored in identity.refresh_tokens as SHA-256 hash. Delivered to client via HttpOnly Secure SameSite=Strict cookie with "__Host-" prefix. Placement in localStorage is prohibited.
[AUTH-API-04] Refresh Token rotation: on each Access Token refresh, the old Refresh is marked Revoked and a new one is issued, reference to new in ReplacedByTokenId. Reuse of a Revoked token must trigger immediate invalidation of ALL user refresh tokens (Refresh Token Reuse Detection) and a Token.Revoked event in the audit log.
[AUTH-API-05] Token revocation for Access Token: on logout, deactivation or forced logout, jti is added to a Redis list with TTL = remaining access token lifetime. Middleware checks jti on each request. Redis key is prefixed with TenantId (see ARCH-08).
[AUTH-API-06] JWT secrets (RSA private key) must be stored in secure storage: Azure Key Vault, HashiCorp Vault, or an encrypted file with 600 permissions on the server. Keys must be rotated at least once every 12 months; support for multiple kid (key id) in JWKS for seamless rotation is mandatory.
## 5.4 Password Policy
[PWD-01] Minimum password length by default: 12 characters (configurable per tenant).
[PWD-02] Password must contain at least: 1 uppercase letter, 1 lowercase letter, 1 digit, 1 special character.
[PWD-03] Password hashing: ASP.NET Core Identity PBKDF2 with HMACSHA512, 100,000 iterations — configured explicitly via PasswordHasherOptions.
[PWD-04] Password history: reuse of last 10 passwords is prohibited. Hashes are stored in identity.user_password_history.
[PWD-05] Forced password change: on first login and after 90 days (configurable per tenant via TenantSettings.PasswordPolicy).
## 5.5 Brute Force Protection
[BFP-01] Account lockout after 5 consecutive failed login attempts. Lockout duration: 15 minutes (configurable via LockoutOptions).
[BFP-02] Rate limiting on login endpoint: no more than 10 requests per minute from a single IP (ASP.NET Core Rate Limiting Middleware with Redis backend for distributed counting).
[BFP-03] Login error message must not reveal whether the user exists or the tenant is correct: uniform response "Invalid credentials".
[BFP-04] All failed login attempts must be recorded in AuditLog with IP address, User-Agent, timestamp and reason subtype (UserNotFound, WrongPassword, TenantMismatch, TenantSuspended, AccountLocked).
## 5.6 Two-Factor Authentication (2FA)
[2FA-01] 2FA is implemented via a one-time code (OTP) sent to the user's email.
[2FA-02] OTP: 6-digit numeric code. Lifetime — 10 minutes. Generated by cryptographically strong CSRNG (System.Security.Cryptography.RandomNumberGenerator).
[2FA-03] OTP is stored in identity.two_factor_codes as HMAC-SHA256 of the code with an individual salt. After use or expiry the record is marked ConsumedAt or deleted by a background service.
[2FA-04] Maximum 3 OTP entry attempts. On exceeding — OTP is cancelled, new send required. OTP resend — no more than once per minute (rate limit on UserId via Redis).
[2FA-05] Email with OTP must not contain links — only the code. The email subject must not contain the code itself.
[2FA-06] Enabling/disabling 2FA is available to: the user themselves (in profile settings) and Administrator (forced enablement for all tenant users — TenantSettings.Require2faForAll).
[2FA-07] The email sending service is implemented via IEmailSender interface, allowing connection of any provider (SMTP, SendGrid, AWS SES, Mailgun) via configuration without code changes.
## 5.7 Single Sign-On (SSO)
[SSO-01] The architecture must allow an SSO provider to be connected at configuration stage without changing business logic. The protocol (SAML 2.0, OAuth 2.0/OIDC, AD/LDAP) is determined by the customer during design and fixed in SsoConfiguration per tenant.
[SSO-02] SSO integration is implemented via IExternalAuthProvider abstraction. Recommended: Microsoft.AspNetCore.Authentication.OpenIdConnect (OIDC), ITfoxtec.Identity.Saml2 (SAML 2.0), Novell.Directory.Ldap.NETStandard (LDAP).
[SSO-03] On SSO login, a local user record must be created (if not exists) or the existing one updated. TenantId is determined either from the subdomain (see ARCH-03) or from a provider claim specified in SsoConfiguration.ClaimMappings.
[SSO-04] 2FA on SSO login: if the provider guarantees MFA on their side (amr claim contains mfa), system-level 2FA is not applied. Otherwise — it is applied.
## 5.8 Secure Code Requirements
### 5.8.1 Injections
[CODE-01] EF Core with LINQ queries is mandatory. Direct string.Format or concatenation in SQL queries is prohibited. Raw SQL — only via FromSqlInterpolated / ExecuteSqlRaw with parameterisation.
[CODE-02] User input displayed in Blazor components must be passed via MarkupString only after explicit sanitisation (HtmlEncoder.Default.Encode or Ganss.Xss). Using @((MarkupString)userInput) without sanitisation is prohibited.
### 5.8.2 Authorisation
[CODE-03] Authorisation is applied at two levels: [Authorize] attribute on Blazor pages/components and API controllers, plus explicit rights checking in the Application Layer via IAuthorizationService and MediatR AuthorizationBehavior. Relying solely on UI element hiding is not permitted.
[CODE-04] All SignalR Hub methods must be protected with the [Authorize] attribute. TenantId verification in Hub methods is mandatory (see ARCH-09).
### 5.8.3 Secret Management
[CODE-05] Secrets (connection strings, JWT keys, email provider keys, SSO ClientSecret) must not be stored in source code or configuration files in plain text. Use: Azure Key Vault / AWS Secrets Manager / HashiCorp Vault (cloud), User Secrets (development), environment variables only in combination with OS-level encryption / Secrets Manager (production on-premise).
[CODE-06] PostgreSQL ConnectionString should use passwordless authentication where possible: SCRAM-SHA-256 with client certificate, IAM authentication (AWS RDS), Managed Identity (Azure Database for PostgreSQL Flexible Server), Unix peer authentication (on-premise). Storing the DB password in plain text in configuration is prohibited. TLS connection to DB is mandatory (sslmode=verify-full).
### 5.8.4 Dependencies
[CODE-07] All NuGet packages must be regularly checked for known vulnerabilities via `dotnet list package --vulnerable`. Critical vulnerabilities must be remediated within 48 hours.
[CODE-08] Use of deprecated or unsupported packages is prohibited.

# 6. Connection and Action Audit
## 6.1 Audit Record Structure

| Field | PostgreSQL Type | Description |
| --- | --- | --- |
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid? | Tenant (NULL for platform-level system events) |
| UserId | uuid? | User (NULL if unauthenticated) |
| UserName | varchar(256) | Login at time of event (denormalised) |
| EventType | varchar(64) | Event type (see 6.2) |
| EventResult | varchar(16) | Success / Failure / Warning |
| IpAddress | inet | Client IP address (PostgreSQL inet type) |
| UserAgent | text | Browser User-Agent |
| Details | jsonb | JSON with additional event data (GIN index using jsonb_path_ops for filtering) |
| CreatedAt | timestamptz | Event timestamp (UTC) |

The audit.audit_logs table is declaratively partitioned by month on the CreatedAt field (PARTITION BY RANGE), simplifying archiving and retention-based deletion.
## 6.2 Auditable Event Types
### 6.2.1 Authentication Events
- Login.Success — successful login (with/without 2FA).
- Login.Failure — failed login attempt (with reason subtype).
- Login.Lockout — account lockout.
- Logout — session logout.
- Token.Refresh — Access Token refresh.
- Token.Revoked — token revocation (including reuse detection).
- 2FA.CodeSent — OTP send.
- 2FA.Success — successful OTP verification.
- 2FA.Failure — failed OTP verification.
- SSO.Login — login via external provider.
- Password.Reset — password reset.
- Password.Changed — password change.
### 6.2.2 User Management Events
- User.Created — user creation.
- User.Updated — data modification.
- User.Deactivated / User.Activated — deactivation/activation.
- User.RoleChanged — role change.
- User.PermissionGroupChanged — Permission Group change.
### 6.2.3 Permission Management Events
- PermissionGroup.Created / Updated / Deleted — PG operations.
- PermissionGroup.PermissionChanged — permission composition change.
### 6.2.4 Dashboard Events
- Dashboard.Created / Updated / Deleted — screen operations.
- Dashboard.Viewed — screen view.
### 6.2.5 Platform-Level Events (Superadmin / system)
- Tenant.Created / Suspended / Resumed / Deleted — tenant management.
- Tenant.Switched — Superadmin switching between tenants (see ARCH-02).
- Tenant.CrossTenantAccess — access to another tenant's data (see ARCH-01).
- WidgetCatalog.ItemAdded / Updated / Deactivated — widget catalogue changes.
- System.AuditPurged — cleanup of expired audit records.
## 6.3 Audit Requirements
[AUD-01] AuditLog entry must be atomic and independent of the main business operation transaction. Audit write failure must not roll back the main operation — audit is written via a separate DbContext or OutBox pattern (recommended).
[AUD-02] AuditLog records cannot be edited or deleted via the standard interface. At DB level — read access is INSERT and SELECT only via a dedicated PostgreSQL role; UPDATE/DELETE are revoked for application roles (REVOKE).
[AUD-03] Audit record retention period: 365 days (configurable per tenant). Cleanup of expired records — via background service (IHostedService) by detaching and DROPping old audit.audit_logs table partitions. Each cleanup is recorded as System.AuditPurged event.
[AUD-04] Client IP address must be correctly extracted even with a reverse proxy present (X-Forwarded-For, X-Real-IP headers). Trusted proxies are configured via ForwardedHeadersOptions; IP source is stored in PostgreSQL inet type for CIDR filtering (`<<=` operator).
## 6.4 Audit UI Page
[AUD-05] Audit page is accessible to users with Superadmin and Administrator roles.
[AUD-06] The page must contain: filters by EventType, EventResult, UserId, date range, IP/CIDR; server-side pagination; sorting by CreatedAt (default descending).
[AUD-07] Clicking a record opens a detail card with formatted JSON content of the Details field.
[AUD-08] Export of audit data in CSV format for a selected period. Export is limited to 50,000 records per request; for larger exports — asynchronous job with email notification and delivery via IBlobStorage with a time-limited link.

# 7. Dashboard (Screen) Management
## 7.1 Dashboard Model
A Dashboard — the main data display object. Within this TS, dashboard management as containers is implemented; widget placement is outside the TS scope.

| Field | PostgreSQL Type | Description |
| --- | --- | --- |
| Id | uuid (UUIDv7) | PK |
| TenantId | uuid | Tenant membership |
| Name | varchar(200) | Dashboard name |
| Description | varchar(500)? | Description |
| IsPublic | boolean | Visible to all tenant users (subject to PG) |
| CreatedByUserId | uuid | Creator |
| CreatedAt | timestamptz | Creation date (UTC) |
| UpdatedAt | timestamptz | Date of last modification (UTC) |
| UpdatedByUserId | uuid | Author of last modification |
| IsDeleted | boolean | Soft-delete flag (see DATA-04) |
| DeletedAt | timestamptz? | Soft-delete time (UTC) |
| DeletedByUserId | uuid? | Who marked as deleted |
| xmin | system column | PostgreSQL concurrency token (see DATA-03) |
| LayoutJson | jsonb | Grid configuration JSON (reserved for next version) |

## 7.2 Functional Requirements
[DASH-01] A user with the role Editor or Administrator can create a new dashboard specifying Name, Description, IsPublic.
[DASH-02] The dashboard list displays only screens to which the user has View right according to their Permission Group (or IsPublic = true and PG has no explicit deny).
[DASH-03] Dashboard deletion requires confirmation. Deletion type (physical vs soft-delete) is determined by TenantSettings (see DATA-04).
[DASH-04] Dashboards support name search (trigram index pg_trgm for performance), filtering by author, creation date, IsPublic, and pagination.
[DASH-05] Concurrent editing of the same dashboard is handled via optimistic concurrency based on xmin (see DATA-03). On conflict, the user receives a notification.
## 7.3 Widget Catalogue
[WGT-01] The system contains a catalogue of widget types (WidgetCatalogItem) with fields: Id, Category, Name, Description, IconUrl, IsActive.
[WGT-02] Users with roles Editor/Administrator/Superadmin can view the widget catalogue, filtering by category and name.
[WGT-03] Superadmin can add, edit and deactivate catalogue entries. Deactivated widgets are not displayed to regular users.
[WGT-04] The widget catalogue is a cross-tenant entity (see ARCH-05) shared across the entire platform. Tenant-specific widgets are a future-version extension (requires adding TenantId? to widget_catalog with conditional Global Query Filter).

# 8. Localisation and Internationalisation (i18n)
## 8.1 Requirements
[I18N-01] The system must support any interface language based on the BCP-47 standard without code changes. Adding a new language — via a resource file (.resx or JSON).
[I18N-02] Support for RTL text direction (Arabic, Hebrew, Persian, etc.) and LTR. Direction is determined automatically based on the user locale (PreferredLocale) and applied via the dir attribute at HTML <html> and Blazor component level.
[I18N-03] All UI strings, error messages and notification texts are extracted to resource files. Hardcoding strings is prohibited (controlled by code review and Roslyn analyser).
[I18N-04] Date, number and time format must match the user locale (CultureInfo.CurrentUICulture). All timestamps in DB — UTC, conversion at UI.
[I18N-05] Email notifications (2FA, password reset) must be sent in the user's PreferredLocale language.
[I18N-06] Language switching from user profile without page reload. Selected locale is saved in PreferredLocale and in a cookie for Blazor.
## 8.2 Technical Implementation Requirements
- Use Microsoft.Extensions.Localization (IStringLocalizer<T>).
- For RTL: CSS must use logical properties (margin-inline-start, padding-inline-end) instead of margin-left/right. Bootstrap 5+ with RTL support or equivalent.
- Localisation tests must verify correct display in at least two directions (LTR + RTL).

# 9. Non-Functional Requirements
## 9.1 Performance
[PERF-01] UI page response time under normal load: no more than 2 seconds (P95) with up to 500 concurrent users.
[PERF-02] List pages (users, PGs, dashboards, audit) must use server-side pagination. Loading all records without pagination is prohibited.
[PERF-03] PostgreSQL indexes: see DATA-08. Additionally — pg_trgm for trigram search on dashboards.name; pg_stat_statements for query monitoring; auto_explain for slow queries.
## 9.2 Reliability and Availability
[REL-01] The system must correctly handle SignalR connection interruptions and automatically reconnect without losing user session.
[REL-02] All data modification operations are executed in PostgreSQL transactions. Partial updates are not permitted. Transactions are initiated by the MediatR pipeline TransactionBehavior.
[REL-03] PostgreSQL backup: daily full backup via pg_basebackup, launched by Windows Task Scheduler from a dedicated backup_user account; simultaneously — continuous WAL archiving to a separate logical disk (not the same disk as the data directory) via archive_command for point-in-time recovery; copy retention — 30 days. Restoration is documented in a separate runbook (prepared during deployment).
## 9.3 Scalability
For v1, the target topology is all-in-one on one Windows Server (see section 10). The requirements below describe further scaling capabilities: the architecture must not prevent transition to a distributed topology without rewriting code.
[SCALE-01] When transitioning to multiple CcDashboard.Web instances, Blazor Server requires Sticky Sessions (Session Affinity) at balancer level (IIS ARR, F5, nginx, etc.) or SignalR backplane on Redis. Backplane support is built into the architecture from v1 (using AddSignalR().AddStackExchangeRedis(...)).
[SCALE-02] Distributed state for token revocation, rate limiting, permission cache and SignalR backplane is stored in Redis from the start (even in all-in-one). This eliminates state migration on horizontal scaling. All keys are prefixed with TenantId (see ARCH-08).
[SCALE-03] PostgreSQL in v1 is deployed as a single instance. The architecture must allow (without code changes) transition to a configuration with streaming replication and read-replica for heavy reporting queries (e.g. extended audit_logs filtering). Connection pooling — via built-in Npgsql pooling; PgBouncer recommended at >200 concurrent clients.
## 9.4 Maintainability
[MAINT-01] Unit test code coverage: at least 80% for Application and Domain layers.
[MAINT-02] Logging: Microsoft.Extensions.Logging + Serilog. Levels: Information (normal operations), Warning (non-standard situations), Error (failures). Structured logging is mandatory. Sensitive data in logs is prohibited.
[MAINT-03] API documentation: Swagger/OpenAPI for all CcDashboard.Api REST endpoints. API versioning via path segment (/v1/...).
[MAINT-04] Database migrations: only via EF Core Migrations with Npgsql provider. Manual schema changes outside migrations are prohibited. CI must fail if there are pending migrations.
[MAINT-05] Architectural rules (dependency directions per 2.3) are enforced by tests in CcDashboard.Tests.Architecture (NetArchTest), run in CI on each PR.
## 9.5 Browser Compatibility
[COMPAT-01] Supported browsers: Google Chrome, Mozilla Firefox, Microsoft Edge (last 2 versions each), Safari 16+.
[COMPAT-02] Responsive design: minimum resolution — 1280×768px. Mobile devices: basic view support (Viewer).

# 10. Deployment Requirements
## 10.1 Configuration
System configuration is divided into priority levels (highest to lowest):
- Environment Variables — for secrets in production.
- Azure Key Vault / AWS Secrets Manager / HashiCorp Vault — for cryptographic materials.
- appsettings.{Environment}.json — for non-secret environment settings.
- appsettings.json — base defaults.
## 10.2 Tenant Configuration Parameters
Each tenant (TenantSettings) can independently configure:
- Password policy (minimum length, complexity, expiry).
- Mandatory 2FA for all users.
- Audit record retention period.
- Email provider settings (SMTP host/port/credentials or API key, in encrypted form).
- SSO configuration (separate SsoConfiguration entity).
- Tenant default interface language.
- Whether soft-delete is enabled for dashboards and physical deletion retention.
## 10.3 Target Environment: Windows Server (all-in-one)
Target deployment model for v1: one server with all system components installed. Delivery is as a self-contained package (folder publish .NET 8) accompanied by a PowerShell installer.
### 10.3.1 Server Requirements
[DEPLOY-01] Operating system: Windows Server 2019 or 2022 (2022 recommended). Edition: Standard or Datacenter. Local administrator for installation; in operation, services must run under dedicated accounts with minimal permissions.
[DEPLOY-02] Minimum specifications (for load of up to 500 concurrent users per PERF-01): 8 vCPUs, 32 GB RAM, separate logical disks — system (≥100 GB SSD), data (PostgreSQL data directory, ≥500 GB SSD), wal (PostgreSQL WAL archive, ≥200 GB), backup (backup copies, ≥1 TB HDD/SSD, network preferred). Specific values are refined during sizing.
[DEPLOY-03] Pre-installed software: .NET 8 Hosting Bundle (ASP.NET Core Module + .NET Runtime for IIS), IIS role with components: Static Content, Default Document, HTTP Errors, HTTP Logging, Request Filtering, WebSocket Protocol, Application Initialization, Windows Authentication (optional for intranet). PowerShell 7+. PostgreSQL 15+ (16+ recommended) — installation via EDB Postgres Installer or official MSI; Redis 7+ for Windows — Memurai (recommended as a supported product) or Redis in WSL2 (choice fixed during deployment).
### 10.3.2 ASP.NET Core Hosting (IIS)
[DEPLOY-04] CcDashboard.Web and CcDashboard.Api are deployed as two separate IIS sites in separate Application Pools (No Managed Code). Hosting — in-process via ASP.NET Core Module v2 (AspNetCoreModuleV2). Pool identity: dedicated account (see DEPLOY-05). Recycling: disable regular timer recycle (only on update and memory limit); idle timeout = 0 (applications are not unloaded on idle — critical for Blazor Server circuit and background services).
[DEPLOY-05] IIS Application Pool account — Group Managed Service Account (gMSA) if Active Directory is available; without AD — local account with long random password stored in Windows Credential Manager. Account must have: Logon as a service; read/execute on application directory; read/write on log directory; PostgreSQL connection (SCRAM-SHA-256 password or domain account via Kerberos/GSS if PostgreSQL is configured accordingly).
[DEPLOY-06] Enabling WebSocket Protocol at IIS level is mandatory for Blazor Server. Timings: <requestTimeout> for ASP.NET Core Module — at least 20 minutes (default 02:00:00 is acceptable); shutdownTimeLimit = 60 seconds.
### 10.3.3 Network Security and TLS
[DEPLOY-07] External access — HTTPS only (TLS 1.2+). TLS certificate — wildcard for the system root domain (*.cc-dashboard.local) to serve tenant subdomains (see ARCH-03). Storage in Windows Certificate Store (LocalMachine\My); rotation — 30 days before expiry. HTTP (port 80) — redirect to HTTPS at IIS URL Rewrite level. Weak ciphers (RC4, 3DES, TLS 1.0/1.1) disabled via IISCrypto or Group Policy.
[DEPLOY-08] Windows Firewall: open inbound ports — 443 (HTTPS, public), 80 (HTTP, public, redirect only). Internal services (PostgreSQL 5432, Redis 6379) listen on 127.0.0.1 only — external access blocked by firewall rules.
### 10.3.4 PostgreSQL: Installation and Hardening
[DEPLOY-09] PostgreSQL service runs under a dedicated local account postgres_svc (not Network Service, not Local System). Data directory and WAL archive are on separate disks (see DEPLOY-02), accessible only to postgres_svc and backup_user. pg_hba.conf authentication: local all postgres peer (console administration only), host all all 127.0.0.1/32 scram-sha-256, hostssl all all 127.0.0.1/32 scram-sha-256, any external connections — reject. Extensions enabled: pgcrypto, pg_trgm, pg_stat_statements.
[DEPLOY-10] Performance parameters (starting point, adjusted based on load test results): shared_buffers = 25% RAM, effective_cache_size = 75% RAM, work_mem = 16 MB, maintenance_work_mem = 1 GB, max_connections = 200, wal_compression = on, archive_mode = on, archive_command = copy WAL segment to backup disk directory.
### 10.3.5 Redis: Installation
[DEPLOY-11] Redis (Memurai or Redis in WSL2) listens on 127.0.0.1 only, requires AUTH (password from secret storage, see CODE-05), persistence — RDB snapshot every 5 minutes (for token revocation list, last few minutes of data loss is acceptable — refresh tokens are invalidated via DB, see AUTH-API-04). Runs as a Windows Service.
### 10.3.6 Logging and Health-Check
[DEPLOY-12] Application logging via Serilog: structured JSON logs to file with rotation (Serilog.Sinks.File with RollingInterval.Day, retainedFileCountLimit = 30). Additionally — Serilog.Sinks.EventLog for Warning and above events in Windows Event Log (source: "CC Dashboard Shell"). IIS logs — standard W3C, daily rotation, 90-day retention.
[DEPLOY-13] Health-check endpoints: /health (Liveness) and /health/ready (Readiness) implemented via ASP.NET Core Health Checks. Readiness checks PostgreSQL availability (AspNetCore.HealthChecks.NpgSql) and Redis (AspNetCore.HealthChecks.Redis). Endpoints are used by local monitoring (Zabbix/SCOM agent) — specific solution fixed during deployment.
### 10.3.7 Installation and Updates
[DEPLOY-14] Delivery: zip archive with self-contained .NET 8 (folder publish for win-x64, no external runtime dependencies) + PowerShell installer script (Install-CcDashboard.ps1). Script is idempotent and performs: IIS site and pool creation, HTTPS binding configuration, file extraction to C:\Program Files\CcDashboard, NTFS permissions for pool account, EF Core migrations via CcDashboard.Web.exe migrate (separate command), Windows Event Log source registration.
[DEPLOY-15] Update: PowerShell script Update-CcDashboard.ps1: stops IIS pools, backs up application directory, copies new files, applies migrations (with prior DB backup via pg_basebackup), starts pools. Rollback — restore directory and DB from backup. Scripts must handle simultaneous service unavailability of no more than 2 minutes.
## 10.4 CI/CD Requirements
[CICD-01] Pipeline must include: build (dotnet build), unit tests (CcDashboard.Tests.Unit), integration tests (Testcontainers with PostgreSQL), architectural tests (CcDashboard.Tests.Architecture), security tests (CcDashboard.Tests.Security), static code analysis (SonarQube or equivalent), dependency vulnerability check (`dotnet list package --vulnerable`).
[CICD-02] Build artifact: self-contained folder publish for win-x64 (`dotnet publish -c Release -r win-x64 --self-contained`), packed into a zip archive together with the PowerShell installer and set of migrations (SQL scripts generated by `dotnet ef migrations script --idempotent` for transparency and manual DBA application).
[CICD-03] Artifact delivery to target Windows Server: WebDeploy (msdeploy), WinRM/PowerShell remoting, or Octopus Deploy / Azure DevOps Release Pipeline. Specific solution fixed during CI/CD setup; TS does not mandate one.
[CICD-04] Secrets must not be passed via environment variables in unencrypted form in CI/CD pipeline. Use CI/CD secrets management (GitHub Secrets, GitLab CI Variables with masking, Azure Pipelines Library / Variable Groups, HashiCorp Vault).

# 11. Appendices
## Appendix A. Role Access Matrix

| Function | Superadmin | Administrator | Editor | Viewer |
| --- | --- | --- | --- | --- |
| Tenant Management | ✓ | — | — | — |
| Switch between tenants (impersonation) | ✓ | — | — | — |
| Manage tenant users | ✓ | ✓ | — | — |
| Manage Permission Groups | ✓ | ✓ | — | — |
| Manage tenant settings (TenantSettings) | ✓ | ✓ | — | — |
| Manage tenant SSO configuration | ✓ | ✓ | — | — |
| Create dashboard | ✓ | ✓ | ✓ (PG) | — |
| Edit dashboard | ✓ | ✓ | ✓ (PG) | — |
| Delete dashboard | ✓ | ✓ | ✓ (PG) | — |
| View dashboard | ✓ | ✓ | ✓ (PG) | ✓ (PG) |
| View widget catalogue | ✓ | ✓ | ✓ | — |
| Manage widget catalogue | ✓ | — | — | — |
| View audit page | ✓ | ✓ | — | — |
| Export audit to CSV | ✓ | ✓ | — | — |

⚠ Note: (PG) — access is restricted by the user's Permission Group permissions.
## Appendix B. Secure Code Requirements (OWASP Top 10)

| Vulnerability (OWASP) | Requirement IDs | Mitigations |
| --- | --- | --- |
| A01 Broken Access Control | CODE-03, PG-04, ARCH-01, ARCH-09, AUTH-API-05 | Service-level authorisation, TenantId filtering (Global Query Filter), Hub checks, token revocation |
| A02 Cryptographic Failures | AUTH-API-02, AUTH-API-03, PWD-03, CODE-05, CODE-06, DATA-06 | RS256 JWT, PBKDF2-HMACSHA512, HttpOnly+Secure+SameSite cookie, Key Vault, Data Protection, sslmode=verify-full to Postgres |
| A03 Injection | CODE-01, CODE-02, SEC-04 | EF Core / Npgsql parameterisation, HtmlEncoder, FluentValidation |
| A04 Insecure Design | ARCH-01..ARCH-10, AUTH-API-04, ARCH-11 | Clean Architecture, Global Query Filter, Refresh Token Rotation, enforced architectural tests |
| A05 Security Misconfiguration | SEC-02, CODE-06, DEPLOY-05, DEPLOY-07, DEPLOY-08, DEPLOY-09 | Security headers, dedicated service accounts/gMSA, disable weak TLS ciphers, Windows Firewall (PostgreSQL/Redis on loopback), pg_hba.conf hardening |
| A07 Auth Failures | BFP-01..04, PWD-01..05, 2FA-01..07, AUTH-WEB-01..03, AUTH-API-01..06 | Lockout, Rate limiting, 2FA, password history, secure cookie/JWT |
| A09 Logging Failures | AUD-01..04, MAINT-02, AUTH-WEB-03, DEPLOY-12 | Independent audit (OutBox), structured logging, no sensitive data, partitioning, append-only via REVOKE, rotation and Windows Event Log |
| A06 Vulnerable Components | CODE-07, CODE-08, CICD-01 | Regular `dotnet list package --vulnerable`, static analysis, package updates |
| A08 Software and Data Integrity Failures | CICD-01, CICD-04, MAINT-04, DEPLOY-14, DEPLOY-15 | Pipeline tests, secrets management, EF Migrations only, idempotent install/update with DB backup |
| A10 SSRF | CODE-05, SSO-01..04 | SSO callback URL validation, provider metadata allowlist |

## Appendix C. Open Questions

| No. | Question | Owner | Deadline |
| --- | --- | --- | --- |
| 1 | SSO protocol choice (SAML 2.0 / OIDC / AD) | Customer | Before development start |
| 2 | Email provider choice (SMTP / SendGrid / AWS SES / Mailgun) | Customer | Before development start |
| 3 | List of initial localisation languages | Customer | Before development start |
| 4 | CC platform list for future data integration (outside TS) | Customer | Next phase |
| 5 | SLA requirements (% uptime) | Customer | Before development start |
| 6 | Server sizing parameters (vCPU, RAM, disk) for customer target load (PERF-01 assumes up to 500 users) | Customer / Infra | Before hardware procurement |
| 7 | Enable pgcrypto at DB level in addition to Data Protection (see DATA-06) | Architect / Customer | During design phase |
| 8 | Final Tenant Resolution strategy: subdomain only or multi-strategy (subdomain + path for legacy) | Architect | Before development start |
| 9 | Redis distribution for Windows: Memurai (commercial support) or Redis in WSL2 | Customer / Infra | Before deployment start |
| 10 | Customer Active Directory availability — determines gMSA for IIS Application Pool (DEPLOY-05) and GSS/Kerberos for PostgreSQL | Customer | Before deployment start |
| 11 | TLS certificate: customer internal CA, public CA or self-signed (test environments only); wildcard for system root domain for tenant subdomains | Customer | Before deployment start |
| 12 | Monitoring system to receive health-check endpoints and Windows Event Log (Zabbix, SCOM, Prometheus + windows_exporter) | Customer / Infra | During deployment phase |

## Appendix D. Database ER Diagram
The ER diagram is maintained in the repository in Mermaid format (file /docs/diagrams/er.mmd). The textual representation below is for reference. The graphical version is exported as PNG/SVG in CI and published in the project documentation.
Key relationships (simplified):
- Tenant 1 — N ApplicationUser; Tenant 1 — 1 TenantSettings; Tenant 1 — N PermissionGroup; Tenant 1 — N Dashboard; Tenant 1 — N Queue/Skill/AgentSupergroup/BusinessUnit.
- ApplicationUser N — 1 PermissionGroup (null for Superadmin). ApplicationUser N — N Role via IdentityUserRole.
- PermissionGroup 1 — N MenuPermission, DashboardPermission, PG_Queue, PG_Skill, PG_AgentSupergroup, PG_BusinessUnit.
- Dashboard 1 — N DashboardWidget (reserved). DashboardWidget N — 1 WidgetCatalogItem.
- WidgetCatalogItem — cross-tenant, no TenantId.
- AuditLog N — 0..1 Tenant; N — 0..1 ApplicationUser. Partitioned by CreatedAt by month.
- RefreshToken N — 1 ApplicationUser; self-reference ReplacedByTokenId N — 0..1 RefreshToken.
- TwoFactorCode N — 1 ApplicationUser. UserPasswordHistory N — 1 ApplicationUser.
- SsoConfiguration 1 — 1 Tenant (via TenantSettings.SsoConfigurationId).
Full Mermaid syntax (ER) is included in the repository and must be kept up to date by the developer when DB schema changes.