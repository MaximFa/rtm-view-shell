---
name: technical-writer
invocation: user
description: >
  Apply professional technical writing expertise to the RTM View Shell project.
  Trigger this skill whenever the user mentions: technical documentation, architecture
  documentation, system description, solution overview, solution description, executive summary
  of the system, architecture decision record, ADR, C4 diagram description, component description,
  API documentation, REST API docs, Swagger description, endpoint documentation, data dictionary,
  entity description, database schema documentation, integration guide, deployment guide,
  installation guide, operations manual, runbook, infrastructure documentation,
  user guide, user manual, end-user documentation, how-to guide, quick start guide,
  admin guide, administrator manual, supervisor guide, operator guide, onboarding guide,
  release notes, changelog, README, wiki article, knowledge base article, FAQ,
  requirements document, functional specification, technical specification, design document,
  security documentation, compliance documentation, audit documentation,
  glossary, terminology guide, style guide for docs, documentation structure,
  documentation plan, document template, or any request to write, rewrite, structure,
  review, or improve any document about the RTM View Shell system.
  Also trigger on: "write docs for", "document this", "create a guide for",
  "explain how this works in a document", "write a README", "describe the architecture",
  "user guide for supervisors", "admin documentation", "onboarding document",
  "how should I structure this document", "what should the docs contain".
  Never skip this skill for any documentation writing or structuring task.
---

# Technical Writer — RTM View Shell

This skill governs all documentation produced for or about the **CC Dashboard Shell** project.
It covers four document families: **Technical/Architecture**, **Solution Overview**,
**API/Developer Reference**, and **User Guides**. Read it in full before writing
or structuring any document.

---

## 0. Before writing any document — establish context

Ask (or infer from context) four things:

1. **Audience:** Who will read this? Developer? Sysadmin? Supervisor? CEO?
2. **Purpose:** To explain? To instruct? To justify? To reference?
3. **Format:** Word doc (.docx)? Markdown? HTML? In-code comment?
4. **Depth:** Overview (2 pages)? Detailed spec (20+ pages)? Quick reference (1 page)?

Use the `docx` skill for Word documents. Use Markdown for wiki/GitHub. Use the `pdf` skill for PDFs.

---

## 1. Document families and templates

### Family A — Technical and Architecture Documentation
*Audience: developers, architects, tech leads, DevOps*

| Document | Purpose | Typical length |
|---|---|---|
| Architecture Overview | System structure, technology choices, C4 diagrams | 8–15 pages |
| Architecture Decision Records (ADR) | Why a specific technical decision was made | 1–2 pages each |
| Data Dictionary | All entities, fields, types, constraints | 10–20 pages |
| Security Design Document | Auth flows, token lifecycle, threat model | 8–12 pages |
| Deployment Guide | Step-by-step installation on Windows Server / IIS | 10–15 pages |
| Operations Runbook | How to run the system day-to-day, troubleshoot, backup | 8–12 pages |
| Integration Guide | How to connect the widget adapter to the ACD platform | 6–10 pages |

### Family B — Solution Overview / Executive Documentation
*Audience: business stakeholders, project sponsors, procurement, directors, CEO*

| Document | Purpose | Typical length |
|---|---|---|
| Solution Overview | What the system is, what it does, why it matters | 4–6 pages |
| Executive Summary | One-page brief for leadership | 1 page |
| Business Case | ROI, costs, benefits, risks | 5–8 pages |
| Product Roadmap | v1 scope, v2 plan, future vision | 2–4 pages |
| Release Notes | What changed in this version | 1–3 pages |

### Family C — Developer / API Reference
*Audience: developers integrating with or extending the system*

| Document | Purpose | Typical length |
|---|---|---|
| API Reference | All endpoints, request/response schemas, errors | auto-generated + manual intro |
| Developer Quick Start | Get the solution running locally in 30 min | 3–5 pages |
| Contribution Guide | How to add features, coding standards, PR process | 3–5 pages |
| Widget Adapter Contract | Interface that widget providers must implement | 3–5 pages |

### Family D — User Guides
*Audience: supervisors, administrators, department managers, directors*

| Document | Purpose | Typical length |
|---|---|---|
| Administrator Guide | User management, permission groups, tenant settings | 15–25 pages |
| Supervisor Guide | Viewing dashboards, filtering queues, live monitoring | 8–12 pages |
| Quick Reference Card | One-page cheat sheet for daily tasks | 1 page |
| Onboarding Guide | First-time user setup, role-specific walkthrough | 4–6 pages |

---

## 2. Writing principles — universal rules

### 2.1 Audience-first language

| Audience | Vocabulary | Tone | Example |
|---|---|---|---|
| Developer | Technical, precise. Use exact class/method names. | Neutral, direct | "The `AuthorizationBehavior` runs after `ValidationBehavior` in the MediatR pipeline." |
| Sysadmin | Command-line oriented. Steps, not theory. | Procedural | "Run `dotnet ef database update` from the project root." |
| Business stakeholder | No jargon. Outcomes, not mechanisms. | Professional, clear | "The system ensures that each team sees only the queues they are responsible for." |
| End user (supervisor) | CC terminology. Task-oriented. | Friendly, direct | "To add a queue to a group, click '+ Add queue' and search by name." |

### 2.2 Structure before prose

Always outline the document before writing:
1. Write section headings first.
2. Add one bullet per section with the key point.
3. Expand into prose only after the structure is agreed.

### 2.3 One idea per sentence

Bad: "The system uses JWT tokens which are signed with RS256 and have a 15-minute TTL and are validated on every API request."

Good: "API access tokens use JWT format, signed with RS256. Each token is valid for 15 minutes. The API validates the token signature on every request."

### 2.4 Active voice, present tense

| ❌ Passive / past | ✅ Active / present |
|---|---|
| "The token is validated by the middleware." | "The middleware validates the token." |
| "A permission group was created by the admin." | "The administrator creates a permission group." |
| "Settings can be configured in the panel." | "Configure settings in the Settings panel." |

### 2.5 Consistent terminology

Use the project glossary. Never use synonyms for technical terms — pick one and stick to it.

| Always use | Never use |
|---|---|
| Permission Group | Role group, access group, user group |
| Dashboard / Screen | Wallboard (in UI docs), page, view |
| Tenant | Organisation, company, client (in technical docs) |
| Agent Supergroup | Super group, team aggregate |
| Business Unit / BU | Department, division, site (in technical docs) |
| Two-Factor Authentication / 2FA | Two-step verification, MFA (unless referring to generic MFA) |
| Audit log | Event log, activity log, access log |

---

## 3. Architecture documentation — patterns

### 3.1 C4 model — levels to document

```
Level 1 — System Context
  Who uses the system and what other systems does it talk to?
  Audience: anyone (including business)

Level 2 — Containers
  What are the deployable units? (Web, API, PostgreSQL, Redis, Email)
  Audience: developers, architects, DevOps

Level 3 — Components
  What are the major components inside each container?
  (Application layer: UserService, PermissionService, AuditService etc.)
  Audience: developers

Level 4 — Code
  Class diagrams, sequence diagrams for complex flows.
  Audience: developers working on that specific component
```

### 3.2 Architecture document structure

```
1. Overview
   1.1 Purpose of this document
   1.2 System name and version
   1.3 Intended audience

2. System context (C4 Level 1)
   2.1 Actors (users and external systems)
   2.2 Context diagram

3. Container architecture (C4 Level 2)
   3.1 Container diagram
   3.2 Container descriptions (Web, API, DB, Redis, Email)

4. Technology stack
   4.1 Stack summary table
   4.2 Technology decision rationale

5. Key architectural decisions
   5.1 [ADR-001] Blazor Server over Blazor WebAssembly
   5.2 [ADR-002] Shared schema multi-tenancy
   5.3 [ADR-003] PostgreSQL over SQL Server
   ... (one section per ADR)

6. Data architecture
   6.1 Schema overview (schemas: public, identity, audit)
   6.2 Multi-tenancy strategy (Global Query Filters)
   6.3 Entity relationship summary

7. Security architecture
   7.1 Authentication flows (cookie + JWT)
   7.2 Authorisation model (Permission Groups)
   7.3 Data protection measures

8. Deployment architecture
   8.1 Topology diagram (Windows Server, IIS, PostgreSQL, Redis)
   8.2 Network boundaries (ports, firewall rules)
   8.3 Scalability path

9. Non-functional requirements compliance
   9.1 Performance [PERF-*]
   9.2 Reliability [REL-*]
   9.3 Security [SEC-*]

Appendix A: Glossary
Appendix B: Requirement IDs reference
```

### 3.3 Architecture Decision Record (ADR) template

```markdown
# ADR-001: Blazor Server over Blazor WebAssembly

**Status:** Accepted
**Date:** 2026-05-09
**Deciders:** [names]

## Context
The UI framework must integrate with ASP.NET Core Identity for cookie-based session
management. The application is deployed on a closed intranet (no CDN, no public internet).

## Decision
Use Blazor Server (SignalR circuit model) rather than Blazor WebAssembly.

## Rationale
- Cookie authentication integrates natively with Blazor Server circuits.
- No client-side download of .NET runtime (important for low-bandwidth environments).
- Server-side rendering is simpler to secure (no token exposure in browser).
- Disadvantage: requires persistent SignalR connection; mitigated by Redis SignalR backplane [SCALE-01].

## Consequences
- All UI logic runs on the server — latency sensitive to server location.
- Circuit management required (CircuitHandler for force-logout [USR-09]).
- Auto-reconnect must be implemented [REL-01].
```

---

## 4. Data dictionary — entity documentation template

```markdown
## Entity: PermissionGroup

**Table:** `public.permission_groups`
**Schema:** Multi-tenant (has TenantId, Global Query Filter applied)
**Purpose:** Defines a named set of access permissions assigned to users.
            A user belongs to exactly one Permission Group.

### Fields

| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| Id | uuid | No | UUIDv7 | Primary key, generated by application |
| TenantId | uuid | No | — | Foreign key to `tenants.Id`; enforced by GQF |
| Name | varchar(200) | No | — | Unique within tenant |
| Description | text | Yes | NULL | Optional free-text description |
| IsActive | boolean | No | true | Inactive groups block permission checks |
| RowVersion | uint | No | xmin | PostgreSQL `xmin` — optimistic concurrency token |
| CreatedAt | timestamptz | No | — | UTC timestamp, set by IAuditableEntity interceptor |
| CreatedByUserId | uuid | No | — | FK to `identity.users.Id` |
| UpdatedAt | timestamptz | No | — | UTC, updated on every save |
| UpdatedByUserId | uuid | No | — | FK to `identity.users.Id` |

### Indexes
- `UNIQUE (TenantId, Name)` — enforces name uniqueness within tenant
- `INDEX (TenantId)` — GQF performance
- `INDEX (CreatedByUserId)` — audit queries

### Relationships
- Has many `MenuPermission` (1:N)
- Has many `DashboardPermission` (1:N)
- Has many `ApplicationUser` (1:N via PermissionGroupId)

### Business rules
- [PG-06] Cannot be deleted if it has ≥1 user assigned.
- [PG-07] Editing permissions invalidates Redis cache `{tenantId}:pg_permissions:{id}`.
- Soft-delete is NOT used — deletion is physical after reassigning all users.
```

---

## 5. Deployment guide — structure and writing rules

### Document structure

```
1. Prerequisites
   - Hardware requirements
   - Software requirements (versions)
   - Network requirements
   - Required accounts and permissions

2. Pre-installation checklist
   (table: item | required | verified)

3. Installation steps
   (numbered, one action per step, expected output shown)

4. Post-installation verification
   (how to confirm it works)

5. Troubleshooting
   (symptom → cause → fix table)

6. Rollback procedure
```

### Writing rules for procedural docs

- **One action per step.** Never combine "install X and then configure Y" in one step.
- **Show expected output.** After a command, show what success looks like.
- **Flag warnings before the action,** not after.
- **Number every step.** Use sub-steps (3.1, 3.2) for related actions.

```markdown
## Step 3 — Apply database migrations

> ⚠️ **Before proceeding:** Ensure PostgreSQL is running and the connection string
> in `appsettings.json` points to the correct database.

3.1. Open a Command Prompt as Administrator.

3.2. Navigate to the solution root:
     ```
     cd "C:\Program Files\CcDashboard"
     ```

3.3. Apply migrations:
     ```
     dotnet ef database update \
       --project src\CcDashboard.Infrastructure \
       --startup-project src\CcDashboard.Web
     ```

     **Expected output:**
     ```
     Build started...
     Build succeeded.
     Applying migration '20260101000001_InitialCreate'...
     Done.
     ```

3.4. Verify: open pgAdmin, connect to `ccdashboard` database, confirm tables
     exist in schemas `public`, `identity`, and `audit`.
```

---

## 6. User guide — structure and writing rules

### 6.1 Administrator Guide structure

```
Introduction
  About this guide
  Who this guide is for
  System overview (1 paragraph, non-technical)

Getting Started
  Logging in
  Navigating the interface
  Understanding your role

Managing Users
  Creating a new user
  Editing a user
  Blocking / unblocking a user
  Resetting a user's password
  Forcing a user logout

Managing Permission Groups
  What is a Permission Group?
  Creating a group
  Configuring menu access
  Configuring screen access
  Assigning queues and skills
  Assigning Business Units
  Deleting a group

Managing Screens (Dashboards)
  Creating a screen
  Sharing a screen with groups
  Editing a screen
  Deleting a screen

Tenant Settings
  Password policy
  Session settings
  Two-factor authentication policy
  Email provider configuration

Audit Log
  Viewing the audit log
  Filtering events
  Exporting audit data

Troubleshooting
  Common issues and solutions

Glossary
```

### 6.2 Supervisor / Viewer Guide structure

```
Introduction
  About this guide
  What you can do as a Supervisor

Viewing Your Dashboards
  Opening a dashboard
  Understanding the live indicator
  Pausing and resuming live updates

Using Queue Filters
  Switching between queues
  Understanding queue metrics
  Colour indicators explained

Understanding Widget Data
  KPI tiles
  Queue status
  Agent status board

Account Settings
  Changing your password
  Setting your preferred language
  Enabling two-factor authentication

Getting Help
  Who to contact for access issues
  Who to contact for technical problems
```

### 6.3 User guide writing rules

- **Task-oriented headings.** Use gerunds: "Creating a user", "Filtering by queue", not "User Creation", "Queue Filter".
- **Screenshot every modal and form.** Label each field with a callout number. Describe below.
- **Use note/warning/tip admonitions** to highlight important information:
  ```
  > 📝 **Note:** Deactivating a user immediately terminates their active session.
  > ⚠️ **Warning:** Deleting a Permission Group is permanent and cannot be undone.
  > 💡 **Tip:** Use the search box to quickly find users by email address.
  ```
- **Write in second person:** "You can filter the list by role..." not "The user can filter..."
- **Step numbers reset to 1 in each procedure.** Don't continue numbering across sections.
- **Every procedure ends with a result statement:** "The user is created and a temporary password is sent to their email."

---

## 7. API documentation — patterns

### 7.1 Endpoint documentation template

```markdown
## POST /v1/users

Creates a new user in the current tenant.

**Authentication:** Bearer token required
**Roles:** Superadmin, Administrator
**Audit event:** `User.Created`

### Request body

| Field | Type | Required | Description |
|---|---|---|---|
| firstName | string | No | Max 100 characters |
| lastName | string | No | Max 100 characters |
| email | string | Yes | Must be unique within tenant |
| userName | string | Yes | Max 256 characters |
| role | string | Yes | One of: `Administrator`, `Editor`, `Viewer` |
| permissionGroupId | uuid | Conditional | Required if role ≠ `Superadmin` |

### Example request
```json
{
  "email": "jane.doe@example.com",
  "userName": "jane.doe",
  "firstName": "Jane",
  "lastName": "Doe",
  "role": "Editor",
  "permissionGroupId": "019x-..."
}
```

### Responses

| Status | Description |
|---|---|
| 201 Created | User created. Body: `{ "id": "uuid" }` |
| 400 Bad Request | Validation failed. Body: `ValidationProblemDetails` |
| 401 Unauthorized | Missing or invalid token |
| 403 Forbidden | Role does not have permission to create users |
| 409 Conflict | Email already in use within this tenant |

### Notes
- A temporary password is generated and emailed to the user [USR-03].
- `MustChangePasswordAt` is set to `now` — the user must change password on first login [PWD-05].
```

### 7.2 Error response format (standardised)

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.5",
  "title": "Validation failed",
  "status": 400,
  "traceId": "00-abc123-def456-00",
  "errors": {
    "email": ["Email address is already in use within this tenant."],
    "role": ["Role must be one of: Administrator, Editor, Viewer."]
  }
}
```

---

## 8. Release notes — template

```markdown
# RTM View Shell — Release Notes

## Version 1.0.0 — [Date]

### What's new
- User management: create, edit, block, and reset passwords for tenant users
- Permission Groups: granular access control for menus, screens, queues, skills, and BUs
- Dashboard management: create and manage named screens (widget layout in v2)
- Widget catalogue: browse available widget types by category
- Authentication: local accounts + email 2FA + SSO stub
- Audit log: full trail of all authentication and permission events

### Security
- JWT RS256, 15-minute access tokens, 8-hour refresh tokens with rotation
- PBKDF2-HMACSHA512 password hashing, 100,000 iterations
- Brute-force protection: 5 attempts → 15-minute lockout
- Security headers: CSP, HSTS, X-Frame-Options

### Known limitations
- Widget rendering not included (stub only) — planned for v2
- Drag-and-drop layout not included — planned for v2
- SSO: stub returns NotImplementedException — full implementation in v1.1

### Upgrade notes
- N/A (initial release)
- Run `dotnet ef database update` after deployment
```

---

## 9. Document quality checklist — before publishing

### Technical documents
- [ ] Audience identified in the introduction
- [ ] All requirement IDs referenced (ARCH-*, AUTH-*, etc.) where relevant
- [ ] All technical terms defined in a glossary
- [ ] Code examples tested (not copy-pasted without verification)
- [ ] Diagrams match the current codebase (not the planned state)
- [ ] Version number and date on title page
- [ ] Reviewed by at least one developer who worked on the described component

### User guides
- [ ] Every procedure tested by someone who did not write it
- [ ] All screenshots current (not from an earlier UI version)
- [ ] Every menu item, button, and field name matches exactly what appears in the UI
- [ ] All cross-references (see section X) are valid
- [ ] Glossary covers all CC and system terms used
- [ ] Tone is consistent (second person, active voice, present tense)
- [ ] Translated to required locales (if i18n required)

### All documents
- [ ] No orphaned sections (headings with no content)
- [ ] No placeholder text ("TODO", "TBD", "INSERT X HERE") left in
- [ ] File name follows convention: `CC_Dashboard_[DocType]_v[N.N]_[YYYY-MM-DD]`
- [ ] Saved in the agreed format (.docx, .md, .html) and location

---

## 10. File naming and versioning convention

```
CC_Dashboard_Architecture_Overview_v1.0_2026-05-09.docx
CC_Dashboard_Deployment_Guide_v1.0_2026-05-09.docx
CC_Dashboard_Admin_Guide_v1.0_2026-05-09.docx
CC_Dashboard_Supervisor_Guide_v1.0_2026-05-09.docx
CC_Dashboard_API_Reference_v1.0_2026-05-09.html
CC_Dashboard_Security_Design_v1.0_2026-05-09.docx
CC_Dashboard_Data_Dictionary_v1.0_2026-05-09.docx
CC_Dashboard_Release_Notes_v1.0_2026-05-09.md

ADR-001_Blazor_Server_choice.md
ADR-002_Multi_tenancy_shared_schema.md
ADR-003_PostgreSQL_over_SQL_Server.md
```

Version increments:
- `v1.0` → `v1.1` — minor update (corrections, additions, clarifications)
- `v1.1` → `v2.0` — major update (new sections, structural change, new software version)

---

## 11. Localisation of documentation

Per [I18N-01], the system supports any language without code changes.
Documentation should follow the same principle where possible.

| Document | Primary language | Required translations |
|---|---|---|
| Architecture docs | English | None (developers) |
| Deployment Guide | English | None (IT/DevOps) |
| API Reference | English | None (developers) |
| Admin Guide | English | Russian (if CIS deployment) |
| Supervisor Guide | English | Russian, Arabic (if Arabic locale used) |
| Quick Reference Card | English | All supported locales |

Translation rule: translate meaning, not words. CC terminology in Arabic/Russian must use
the terms that operators in those markets actually use — not literal translations of English.

---

## 12. Style reference — quick rules

| Rule | Example |
|---|---|
| System name | CC Dashboard Shell (full), CcDashboard (code), RTM shell (informal) |
| UI elements | **Bold** ("Click **Save changes**") |
| Code and technical names | `monospace` ("the `TransactionBehavior` class") |
| Menu paths | bold with arrow ("**Administration → Users**") |
| Keyboard shortcuts | Kbd style ("Press **Escape** to close") |
| Warnings before actions | Always before the step, never after |
| Numbers | Spell out one to nine; numerals for 10+ |
| Dates | ISO 8601 in technical docs (2026-05-09); "9 May 2026" in user docs |
| Abbreviations | Define on first use: "Two-Factor Authentication (2FA)" |
| Passive voice | Avoid — rewrite to active |
| Future tense in instructions | Avoid — use imperative ("Click", not "You will click") |
