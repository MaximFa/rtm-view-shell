---
name: cc-dashboard-shell
description: .NET/Blazor Server graphical shell for real-time contact center data display
sources: [backfill]
aliases: [CC Dashboard Shell, ТЗ]
---
- [stated] Substantial .NET/Blazor Server project: a graphical shell for real-time contact center data display
- [stated] Max drove requirements gathering; a full technical specification (ТЗ) was produced
- [stated] Multi-tenancy via EF Core Global Query Filters
- [stated] Four user roles; Permission Group-based access control with data-object filtering
- [stated] JWT RS256 auth with refresh token rotation; PBKDF2 password hashing
- [stated] CSRNG-based 2FA; SSO abstraction; audit logging
- [stated] i18n with RTL/LTR support
- [stated] Uses MS SQL Server
- [stated] Hybrid on-premise + cloud deployment model with Docker/CI/CD