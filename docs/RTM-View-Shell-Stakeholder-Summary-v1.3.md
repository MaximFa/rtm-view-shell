# RTM View Shell — Stakeholder Summary

**Version:** 1.3  
**Date:** 2026-05-25  
**Audience:** Product owners, project managers, non-technical stakeholders  
**Prepared by:** Development team

---

## What is RTM View Shell?

RTM View Shell is a web-based management platform for contact-centre real-time monitoring
dashboards. It allows organisations to:

- Create and manage named **dashboards** (screens) that display live contact-centre data.
- Control **who sees what** through a Permission Groups system — restricting access to
  specific queues, business units, and dashboards per user group.
- Manage **user accounts** with enterprise-grade security (two-factor authentication,
  single sign-on, session auditing).
- Maintain a full **audit trail** of all user and administrative actions.

The system is designed to run on a standard Windows Server and connects to an existing
contact-centre platform database.

---

## What the system does (v1.3)

### User and access management

- Create, edit, and deactivate user accounts within an organisation (tenant).
- Assign users to roles: Administrator, Editor, or Viewer.
- Group users into **Permission Groups** that control access to menus, dashboards, queues,
  business units, and agent supergroups.
- Administrators see only their own organisation's data; Superadmins can manage all tenants.

### Dashboard (screen) management

- Create named screens and assign them to one or more Permission Groups.
- Mark screens as public (visible to all users in the organisation) or restricted.
- Search screens by name, filter by group or status.
- Soft-delete with configurable retention period.

### Widget catalogue

- Browse available widget types by category (Queues, Agents, General metrics).
- Select widgets for placement on a dashboard.
- Widget types are platform-wide; Superadmins manage the catalogue.

> **Note:** Widget *rendering* (live data display) and drag-and-drop layout are planned
> for a future widget-library release. In v1.3, widget selection is recorded but not
> yet displayed as live data.

### Security

- Passwords: minimum 12 characters, complexity requirements, 90-day expiry, no reuse
  of last 10 passwords.
- Two-factor authentication via email OTP (6-digit code, 10-minute validity).
- Single Sign-On support for Active Directory/LDAP, OIDC, and SAML 2.0 (v1.3 stub;
  full integration in next sprint).
- Automatic lockout after 5 failed login attempts (15-minute lockout).
- All sessions and administrative actions are logged to a tamper-resistant audit trail.
- Audit logs retained for 365 days (configurable per organisation).

### Multi-language support

- Interface available in any language via resource files; no code change required.
- Right-to-left layout support (Arabic, Hebrew, Farsi).
- Date/time formats follow the user's locale setting.

---

## What is NOT in scope for v1.3

The following features are planned for future releases:

| Feature | Target version |
|---|---|
| Live widget data rendering | Widget-library sprint |
| Drag-and-drop dashboard layout | Widget-library sprint |
| Widget configuration forms | Widget-library sprint |
| Per-tenant licence enforcement | v1.4 |
| Real CC backend API notifications | v1.4 (Outbox pattern) |
| Per-tenant branding / colour themes | v1.4 |
| Full SSO integration (AD/OIDC/SAML) | Next sprint |

---

## Quality and security milestones reached in v1.3

| Milestone | Status |
|---|---|
| 313 automated tests (unit, integration, security, architecture) | Complete |
| 7 security findings found and fixed (including 1 critical cross-tenant data leak) | Complete |
| All 8 architecture decisions documented (ADR-001..008) | Complete |
| Full audit trail covering all authentication and permission events | Complete |
| Interactive wireframes for all 5 main screens | Complete |
| Deployment scripts for Windows Server / IIS | Complete |

---

## Architecture at a glance

The system runs entirely on a single Windows Server (no cloud infrastructure required):

- **Web application:** Blazor Server (.NET 8) — live, server-rendered UI over WebSocket
- **Database:** PostgreSQL 15+ — all business data, shared with CC platform
- **Cache:** Redis (Memurai) — session state, rate limiting, permission cache
- **Email:** SMTP / SendGrid / AWS SES / Mailgun — configurable without code change
- **Hosting:** IIS on Windows Server 2019/2022

All sensitive data (passwords, tokens, encryption keys) is stored using industry-standard
algorithms (PBKDF2-SHA512, RS256 JWT, AES data protection) and is never stored in plain text.

---

## Deployment checklist (summary)

1. Windows Server 2019 or 2022 with .NET 8 Hosting Bundle and IIS.
2. PostgreSQL 15+ and Redis (Memurai) installed and configured for localhost-only access.
3. Run `Install-CcDashboard.ps1` — creates IIS sites, configures HTTPS, applies database
   migrations, and sets up first-run seed data.
4. Log in as Superadmin; change password on first login.
5. Create the first tenant and assign an Administrator.

Full deployment guide: see Technical Specification §24 and `Install-CcDashboard.ps1`.

---

## Roadmap (next steps after v1.3)

1. **v1.4 — Licensing and backend integration:** per-tenant seat enforcement, outbox-based
   CC platform notifications, full SSO integration.
2. **Widget-library sprint:** live widget rendering, drag-and-drop layout, widget configuration.
3. **v1.5 — Theming and advanced analytics:** per-tenant colour palette, font presets,
   extended audit reporting and CSV export.

---

*For technical details, see the full Technical Specification (`CC_Dashboard_Shell_TZ_v1.3_EN.docx`)
and the Architecture Decision Records (`decisions/ADR-001..ADR-008`).*
