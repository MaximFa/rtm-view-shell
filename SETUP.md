# RTM View Shell — Quick Start with Claude Code

## Prerequisites

Install these once on your machine:

1. [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8) — verify: `dotnet --version`
2. [Claude Code](https://claude.ai/code) — `npm install -g @anthropic-ai/claude-code`
3. PostgreSQL 16 (Windows installer from postgresql.org)
4. Redis: [Memurai for Windows](https://www.memurai.com/) (free tier)

---

## Scaffold the solution (run once)

Open a terminal in this folder and run:

```powershell
# Create solution
dotnet new sln -n CcDashboard

# Core — domain logic, no dependencies
dotnet new classlib -n CcDashboard.Core -o src/CcDashboard.Core --framework net8.0
dotnet sln add src/CcDashboard.Core

# Application — use-cases and services
dotnet new classlib -n CcDashboard.Application -o src/CcDashboard.Application --framework net8.0
dotnet sln add src/CcDashboard.Application
dotnet add src/CcDashboard.Application reference src/CcDashboard.Core

# Infrastructure — EF Core, Npgsql, Redis, email
dotnet new classlib -n CcDashboard.Infrastructure -o src/CcDashboard.Infrastructure --framework net8.0
dotnet sln add src/CcDashboard.Infrastructure
dotnet add src/CcDashboard.Infrastructure reference src/CcDashboard.Core
dotnet add src/CcDashboard.Infrastructure reference src/CcDashboard.Application

# Web — Blazor Server host
dotnet new blazorserver -n CcDashboard.Web -o src/CcDashboard.Web --framework net8.0 --auth None
dotnet sln add src/CcDashboard.Web
dotnet add src/CcDashboard.Web reference src/CcDashboard.Application
dotnet add src/CcDashboard.Web reference src/CcDashboard.Infrastructure

# Tests
dotnet new xunit -n CcDashboard.Tests.Unit -o tests/CcDashboard.Tests.Unit --framework net8.0
dotnet sln add tests/CcDashboard.Tests.Unit
dotnet add tests/CcDashboard.Tests.Unit reference src/CcDashboard.Core
dotnet add tests/CcDashboard.Tests.Unit reference src/CcDashboard.Application

dotnet new xunit -n CcDashboard.Tests.Integration -o tests/CcDashboard.Tests.Integration --framework net8.0
dotnet sln add tests/CcDashboard.Tests.Integration
dotnet add tests/CcDashboard.Tests.Integration reference src/CcDashboard.Infrastructure
```

---

## Install key NuGet packages

```powershell
# EF Core + Postgres
dotnet add src/CcDashboard.Infrastructure package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/CcDashboard.Infrastructure package Microsoft.EntityFrameworkCore.Design
dotnet add src/CcDashboard.Web package Microsoft.EntityFrameworkCore.Design

# ASP.NET Core Identity
dotnet add src/CcDashboard.Infrastructure package Microsoft.AspNetCore.Identity.EntityFrameworkCore

# JWT
dotnet add src/CcDashboard.Web package Microsoft.AspNetCore.Authentication.JwtBearer

# Redis
dotnet add src/CcDashboard.Infrastructure package StackExchange.Redis
dotnet add src/CcDashboard.Web package Microsoft.Extensions.Caching.StackExchangeRedis

# FluentValidation
dotnet add src/CcDashboard.Application package FluentValidation
dotnet add src/CcDashboard.Application package FluentValidation.DependencyInjectionExtensions

# Serilog
dotnet add src/CcDashboard.Web package Serilog.AspNetCore
dotnet add src/CcDashboard.Web package Serilog.Sinks.File

# EF Core tools (global)
dotnet tool install --global dotnet-ef

# Testing
dotnet add tests/CcDashboard.Tests.Unit package FluentAssertions
dotnet add tests/CcDashboard.Tests.Integration package Testcontainers.PostgreSql
dotnet add tests/CcDashboard.Tests.Integration package FluentAssertions
```

---

## Configure secrets (never commit these)

```powershell
# Copy template and fill in real values
copy appsettings.template.json src/CcDashboard.Web/appsettings.Production.json
# Edit the file: replace all REPLACE_ME values
```

For development use `dotnet user-secrets`:
```powershell
cd src/CcDashboard.Web
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;..."
dotnet user-secrets set "Jwt:SecretKey" "your-secret-key-here"
```

---

## Start Claude Code

```powershell
# In the project root folder:
claude
```

Claude Code will read CLAUDE.md automatically and have full context of the project.

**Example first prompts:**
- `"Создай сущности домена User, PermissionGroup, Screen, AuditEvent согласно CLAUDE.md"`
- `"Настрой AppDbContext с конфигурациями EF для всех сущностей"`
- `"Создай UserService с методами Create, Update, Deactivate, GetById"`
- `"Добавь JWT аутентификацию в Program.cs"`
- `"Напиши EF миграцию и примени её"`

Claude Code сам запустит `dotnet build`, увидит ошибки и исправит их.
