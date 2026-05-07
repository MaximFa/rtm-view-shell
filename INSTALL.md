# RTM View Shell — Installation Guide

Deployment target: **Windows Server 2019 / 2022, IIS, PostgreSQL, Memurai (Redis)**

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [PostgreSQL Setup](#2-postgresql-setup)
3. [Memurai (Redis) Setup](#3-memurai-redis-setup)
4. [Build & Publish](#4-build--publish)
5. [Application Configuration](#5-application-configuration)
6. [IIS Setup](#6-iis-setup)
7. [Apply Database Migrations](#7-apply-database-migrations)
8. [First Launch — Create Admin Account](#8-first-launch--create-admin-account)
9. [Verify Installation](#9-verify-installation)
10. [Updating the Application](#10-updating-the-application)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

Install the following on the Windows Server machine before proceeding.

### 1.1 .NET 8 Runtime (ASP.NET Core)

Download and install the **ASP.NET Core Runtime 8.x** (not SDK) from Microsoft:

```
https://dotnet.microsoft.com/download/dotnet/8.0
→ ASP.NET Core Runtime 8.x → Windows x64 Installer
```

Verify:

```powershell
dotnet --list-runtimes
# Should include: Microsoft.AspNetCore.App 8.x.x
```

### 1.2 IIS with ASP.NET Core Module

Enable IIS and install the **ASP.NET Core Module v2** (included in the .NET Hosting Bundle):

```
https://dotnet.microsoft.com/download/dotnet/8.0
→ Hosting Bundle → Windows x64 Installer
```

> The Hosting Bundle installs both the Runtime and the IIS module in one step.

After installation, verify the module is present:

```powershell
Get-WebConfiguration -Filter "system.webServer/globalModules/*" |
    Where-Object { $_.name -like "*AspNetCore*" } |
    Select-Object name
```

### 1.3 PostgreSQL 16+

Download from: `https://www.postgresql.org/download/windows/`

During installation:
- Set a strong password for the `postgres` superuser
- Default port: **5432**
- Ensure the PostgreSQL service starts automatically

### 1.4 Memurai (Redis for Windows)

Download from: `https://www.memurai.com/`

> Memurai is a Redis-compatible cache server for Windows.  
> Alternatively, run Redis 7 inside WSL2.

Install as a Windows Service (default). Default port: **6379**.

---

## 2. PostgreSQL Setup

Open **pgAdmin** or **psql** as the `postgres` superuser and run the following:

```sql
-- Create dedicated application user
CREATE USER ccdashboard_user
    WITH PASSWORD 'STRONG_PASSWORD_HERE'
    LOGIN
    NOCREATEDB
    NOCREATEROLE;

-- Create application database
CREATE DATABASE "RTMViewDB"
    OWNER ccdashboard_user
    ENCODING 'UTF8'
    LC_COLLATE 'en-US'
    LC_CTYPE 'en-US'
    TEMPLATE template0;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE "RTMViewDB" TO ccdashboard_user;

-- Connect to the new database and grant schema privileges
\c RTMViewDB
GRANT ALL ON SCHEMA public TO ccdashboard_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES TO ccdashboard_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON SEQUENCES TO ccdashboard_user;
```

Test the connection:

```powershell
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" `
    -U ccdashboard_user -h localhost -p 5432 -d RTMViewDB `
    -c "SELECT current_user;"
```

---

## 3. Memurai (Redis) Setup

After installation, verify the service is running:

```powershell
Get-Service -Name Memurai
# Status should be: Running
```

Test connectivity:

```powershell
& "C:\Program Files\Memurai\memurai-cli.exe" ping
# Expected response: PONG
```

To set a password (recommended for production):

1. Open `C:\Program Files\Memurai\memurai.conf`
2. Uncomment and set: `requirepass STRONG_REDIS_PASSWORD`
3. Restart the service: `Restart-Service Memurai`

---

## 4. Build & Publish

On the **build machine** (developer workstation with .NET 8 SDK):

```powershell
# Clone or copy the repository
cd "C:\Build\RTM View Shell"

# Restore dependencies
dotnet restore CcDashboard.sln

# Publish for IIS (self-contained: false — uses the server's runtime)
dotnet publish src/CcDashboard.Web `
    -c Release `
    -o "C:\Publish\RTMView" `
    --self-contained false `
    -r win-x64
```

Copy the contents of `C:\Publish\RTMView` to the server, for example:

```
C:\inetpub\RTMView\
```

The publish folder should contain `CcDashboard.Web.exe`, `web.config`, and all `.dll` files.

---

## 5. Application Configuration

Create the production secrets file on the server. This file is **never committed to source control**.

Create `C:\inetpub\RTMView\appsettings.Production.json`:

```json
{
  "ConnectionStrings": {
    "Default": "Host=localhost;Port=5432;Database=RTMViewDB;Username=ccdashboard_user;Password=STRONG_PASSWORD_HERE;SSL Mode=Require;Trust Server Certificate=false"
  },
  "Jwt": {
    "Secret": "REPLACE_WITH_64_CHAR_RANDOM_STRING",
    "Issuer": "RTMView",
    "Audience": "RTMView.Users",
    "AccessTokenExpiryMinutes": 15,
    "RefreshTokenExpiryDays": 7
  },
  "Smtp": {
    "Host": "your-smtp-server",
    "Port": 587,
    "UseSsl": true,
    "Username": "your-smtp-username",
    "Password": "your-smtp-password",
    "FromAddress": "noreply@your-domain.com"
  },
  "Redis": {
    "ConnectionString": "localhost:6379,password=STRONG_REDIS_PASSWORD"
  },
  "Serilog": {
    "FilePath": "C:\\inetpub\\RTMView\\logs\\log-.txt"
  }
}
```

> **Generating a JWT secret:** run in PowerShell:
> ```powershell
> -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | % {[char]$_})
> ```

Secure the file so only the IIS Application Pool identity can read it:

```powershell
$acl = Get-Acl "C:\inetpub\RTMView\appsettings.Production.json"
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "IIS AppPool\RTMViewPool", "Read", "Allow")
$acl.AddAccessRule($rule)
Set-Acl "C:\inetpub\RTMView\appsettings.Production.json" $acl
```

Create the log directory:

```powershell
New-Item -ItemType Directory -Path "C:\inetpub\RTMView\logs" -Force
icacls "C:\inetpub\RTMView\logs" /grant "IIS AppPool\RTMViewPool:(OI)(CI)F"
```

---

## 6. IIS Setup

### 6.1 Create Application Pool

```powershell
Import-Module WebAdministration

New-WebAppPool -Name "RTMViewPool"
Set-ItemProperty "IIS:\AppPools\RTMViewPool" -Name "managedRuntimeVersion" -Value ""
Set-ItemProperty "IIS:\AppPools\RTMViewPool" -Name "startMode" -Value "AlwaysRunning"
Set-ItemProperty "IIS:\AppPools\RTMViewPool" -Name "processModel.idleTimeout" -Value "00:00:00"
```

> `managedRuntimeVersion = ""` means **No Managed Code** — required for ASP.NET Core.

### 6.2 Create Website

```powershell
New-Website -Name "RTMView" `
    -PhysicalPath "C:\inetpub\RTMView" `
    -ApplicationPool "RTMViewPool" `
    -Port 80 `
    -HostHeader "rtmview.your-domain.com"
```

### 6.3 HTTPS Binding

Add a TLS certificate binding (certificate must already be in the Windows Certificate Store):

```powershell
$cert = Get-ChildItem Cert:\LocalMachine\My |
    Where-Object { $_.Subject -like "*rtmview.your-domain.com*" }

New-WebBinding -Name "RTMView" -Protocol "https" -Port 443 `
    -HostHeader "rtmview.your-domain.com" -SslFlags 1

$binding = Get-WebBinding -Name "RTMView" -Protocol "https"
$binding.AddSslCertificate($cert.Thumbprint, "my")
```

### 6.4 web.config

The publish step generates `web.config` automatically. Verify it contains the `aspNetCore` handler:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="aspNetCore" path="*" verb="*"
           modules="AspNetCoreModuleV2" resourceType="Unspecified" />
    </handlers>
    <aspNetCore processPath=".\CcDashboard.Web.exe"
                arguments=""
                stdoutLogEnabled="false"
                stdoutLogFile=".\logs\stdout"
                hostingModel="inprocess">
      <environmentVariables>
        <environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
      </environmentVariables>
    </aspNetCore>
  </system.webServer>
</configuration>
```

### 6.5 Set folder permissions

```powershell
icacls "C:\inetpub\RTMView" /grant "IIS AppPool\RTMViewPool:(OI)(CI)RX"
icacls "C:\inetpub\RTMView\logs" /grant "IIS AppPool\RTMViewPool:(OI)(CI)F"
```

---

## 7. Apply Database Migrations

Run EF Core migrations from the **build machine** (or directly on the server if the .NET SDK is installed):

```powershell
dotnet ef database update `
    --project src/CcDashboard.Infrastructure `
    --startup-project src/CcDashboard.Web `
    --connection "Host=localhost;Port=5432;Database=RTMViewDB;Username=ccdashboard_user;Password=STRONG_PASSWORD_HERE;SSL Mode=Disable"
```

Verify the schema was created:

```powershell
$env:PGPASSWORD = "STRONG_PASSWORD_HERE"
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" `
    -U ccdashboard_user -h localhost -d RTMViewDB -c "\dt"
# Should list: AuditEvents, PermissionGroups, Screens, Users, ...
```

---

## 8. First Launch — Create Admin Account

1. Open a browser and navigate to `https://rtmview.your-domain.com/setup`
2. The setup page is only accessible when **no users exist** in the database
3. Fill in:
   - **Email** — administrator email address
   - **Display name** — full name
   - **Password** — minimum 12 characters, must include uppercase, lowercase, digit, and special character
4. Click **Create account**
5. You will be redirected to the login page
6. Sign in with the credentials you just created

> The `/setup` page automatically becomes inaccessible after the first user is created.

---

## 9. Verify Installation

### Health check

```powershell
Invoke-WebRequest -Uri "https://rtmview.your-domain.com/health" -UseBasicParsing |
    Select-Object StatusCode, Content
# Expected: 200, {"status":"Healthy"}
```

### Smoke test checklist

- [ ] `https://rtmview.your-domain.com` redirects to `/login`
- [ ] Login with the admin account succeeds and redirects to `/dashboard`
- [ ] **Dashboards** page loads without errors
- [ ] **Admin → Users** shows the admin account
- [ ] **Admin → Permission Groups** page loads
- [ ] **Widget Catalogue** page loads
- [ ] Sign out redirects to `/login`

### Security headers

```powershell
(Invoke-WebRequest -Uri "https://rtmview.your-domain.com/login" -UseBasicParsing).Headers |
    Where-Object { $_.Key -in @("X-Frame-Options","X-Content-Type-Options","Content-Security-Policy") }
```

---

## 10. Updating the Application

1. Publish a new build:
   ```powershell
   dotnet publish src/CcDashboard.Web -c Release -o "C:\Publish\RTMView" --self-contained false
   ```

2. Stop the IIS site:
   ```powershell
   Stop-Website -Name "RTMView"
   ```

3. Copy new files to the server (overwrite, keep `appsettings.Production.json`):
   ```powershell
   # Copy all except appsettings.Production.json
   robocopy "C:\Publish\RTMView" "C:\inetpub\RTMView" /MIR /XF appsettings.Production.json
   ```

4. Apply new migrations (if any):
   ```powershell
   dotnet ef database update --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web
   ```

5. Start the site:
   ```powershell
   Start-Website -Name "RTMView"
   ```

---

## 11. Troubleshooting

### Application fails to start — check stdout log

Enable stdout logging temporarily in `web.config`:

```xml
<aspNetCore stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" ...>
```

Then check `C:\inetpub\RTMView\logs\stdout_*.log`.

**Disable `stdoutLogEnabled` again after diagnosing** — it writes a log file per request.

### HTTP 500.30 — ASP.NET Core app failed to start

Common causes:

| Symptom | Fix |
|---|---|
| `Cannot find appsettings.Production.json` | File missing or wrong path — check `C:\inetpub\RTMView\` |
| `Password authentication failed for user` | Wrong DB password in connection string |
| `Connection refused (127.0.0.1:5432)` | PostgreSQL service not running — `Start-Service postgresql*` |
| `No ASP.NET Core Runtime found` | Install the Hosting Bundle on the server |
| `Access is denied` (logs folder) | Fix permissions: `icacls "C:\inetpub\RTMView\logs" /grant "IIS AppPool\RTMViewPool:(OI)(CI)F"` |

### Cookie not set after login (HTTP only)

`CookieSecurePolicy.Always` requires HTTPS. Ensure the IIS binding uses a valid TLS certificate and the request reaches the app over HTTPS (check if a reverse proxy is stripping the scheme).

### 2FA emails not delivered

- Verify SMTP settings in `appsettings.Production.json`
- Test SMTP from the server:
  ```powershell
  Send-MailMessage -SmtpServer "your-smtp" -Port 587 -UseSsl `
      -From "noreply@your-domain.com" -To "test@your-domain.com" `
      -Subject "SMTP Test" -Body "Test from RTM View"
  ```

### Serilog not writing to log file

- Confirm the log directory exists: `C:\inetpub\RTMView\logs\`
- Confirm the App Pool identity has write permission to that folder
- Check the Serilog `FilePath` value in `appsettings.Production.json`
