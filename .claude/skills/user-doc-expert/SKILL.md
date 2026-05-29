---
name: user-doc-expert
invocation: user
description: >
  Enterprise-Grade user documentation expert for RTM View Shell.
  Trigger this skill whenever the user mentions: user documentation, admin guide,
  user manual, end-user documentation, documentation package, documentation plan,
  doc registry, documentation audit, what documents do we need, document set,
  documentation status, update the docs, create a guide, write a manual,
  training materials, presentation for users, onboarding materials,
  quick reference card, release notes for users, documentation gap,
  missing documentation, what docs exist, document the feature,
  write a user guide for, document the Info Slot, document the dashboard,
  document permission groups, supervisor guide, administrator manual,
  PPT for training, slide deck for users, user-facing documentation,
  documentation maintenance, keep docs up to date.
  Also trigger on: "what documentation do we have", "what documentation do we need",
  "create the full doc package", "update docs for new feature", "document this for users",
  "what should the admin guide contain", "create training materials".
  Never skip this skill for any user-facing or admin-facing documentation task.
---

# User Documentation Expert — RTM View Shell

This skill governs the creation and maintenance of the **Enterprise-Grade documentation
package** for RTM View Shell. It covers all user-facing, admin-facing, and management-facing
documents. Read it in full before creating or updating any documentation.

**Rule:** This skill is for **Cowork** (documentation planning and writing).
**Rule:** Use the `docx` skill for Word output. Use the `pptx` skill for presentations.
**Rule:** Always read existing project docs before writing — never duplicate or contradict them.

---

## 0. Before starting any documentation task

### 0.1 Read existing project sources (mandatory)

Before writing or planning any document, read the following sources in order:

| Source | Location | What it covers |
|---|---|---|
| Technical Specification | `CLAUDE.md` | Complete system spec — the single source of truth |
| Widget Specification | `docs/widget-specification.md` | All widget types, config, data model |
| Backend Tasks | `docs/backend-tasks.md` | Implemented features, CC tasks history |
| Wireframes | `wireframes/en/` | UI screens — open in browser for exact field names |
| Doc Registry | `docs/user-documentation/DOC-REGISTRY.md` | What documents exist and their status |

### 0.2 Establish context — ask before writing

If not already clear, ask the user:

1. **Audience:** Administrator? Supervisor? Viewer? Executive? Trainer?
2. **Scope:** Single document or full package update?
3. **Trigger:** New feature documented? Existing doc updated? New doc from scratch?
4. **Format:** Word (.docx)? PowerPoint (.pptx)? Markdown? PDF?
5. **Language:** English? Russian? Both?

### 0.3 Gap analysis — what information is missing

For any document, identify what the project sources do NOT cover:
- UI screenshots (request from user: "please provide a screenshot of X")
- Real deployment details (server names, IP addresses, actual URLs)
- Customer-specific configuration (email provider, SSO details)
- Branding (logo, colour scheme for PPT cover pages)

Explicitly list missing information before starting and ask the user to provide it.

---

## 1. Enterprise-Grade Documentation Package

The complete documentation set for RTM View Shell. Maintain status in `DOC-REGISTRY.md`.

### Package A — Administrator Documentation
*Audience: IT administrators, system administrators, contact centre IT team*

| ID | Document | Format | Status trigger |
|---|---|---|---|
| A-01 | System Administrator Guide | .docx | New system deployed |
| A-02 | Installation & Deployment Guide | .docx | New system deployed |
| A-03 | Tenant Configuration Guide | .docx | New tenant setup |
| A-04 | User Management Guide | .docx | v1.0 delivered |
| A-05 | Permission Groups Management Guide | .docx | v1.0 delivered |
| A-06 | SSO Configuration Guide | .docx | SSO feature enabled |
| A-07 | Backup & Recovery Runbook | .docx | Before go-live |
| A-08 | Security Configuration Checklist | .docx | Before go-live |
| A-09 | Info Slot Management Guide | .docx | CC-010 delivered |

### Package B — End-User Documentation
*Audience: supervisors, team leaders, contact centre managers, Viewers*

| ID | Document | Format | Status trigger |
|---|---|---|---|
| B-01 | Supervisor Quick Start Guide | .docx | v1.0 delivered |
| B-02 | Dashboard User Guide | .docx | v1.0 delivered |
| B-03 | Widget Reference Card | .docx | Each new widget |
| B-04 | Info Slot User Guide | .docx | CC-010 delivered |
| B-05 | Account Settings Guide | .docx | v1.0 delivered |
| B-06 | Quick Reference Card (1-page) | .docx / .pdf | v1.0 delivered |

### Package C — Training Materials
*Audience: trainers, new users (onboarding), management*

| ID | Document | Format | Status trigger |
|---|---|---|---|
| C-01 | Administrator Onboarding Presentation | .pptx | Before go-live |
| C-02 | Supervisor Onboarding Presentation | .pptx | Before go-live |
| C-03 | What's New — Feature Overview Deck | .pptx | Each release |
| C-04 | Info Slot Feature Overview Deck | .pptx | CC-010 delivered |
| C-05 | Training Exercise Workbook | .docx | Before training |

### Package D — Management / Executive Documentation
*Audience: contact centre directors, C-level, procurement*

| ID | Document | Format | Status trigger |
|---|---|---|---|
| D-01 | Solution Overview | .pptx / .docx | Pre-sale / go-live |
| D-02 | Release Notes (user-facing) | .docx | Each release |
| D-03 | Feature Roadmap Summary | .pptx | Quarterly review |

---

## 2. Doc Registry — format and maintenance

Maintain `docs/user-documentation/DOC-REGISTRY.md` with the following structure:

```markdown
# RTM View Shell — User Documentation Registry

Last updated: YYYY-MM-DD

## Status legend
- 🟢 Current — matches implemented features
- 🟡 Needs update — feature changed since last revision
- 🔴 Missing — not yet created
- ⚪ Not applicable — not required for current deployment

| ID | Document | Format | Version | Last updated | Status | Notes |
|---|---|---|---|---|---|---|
| A-01 | System Administrator Guide | .docx | v1.0 | 2026-05-29 | 🟢 | |
| A-09 | Info Slot Management Guide | .docx | — | — | 🔴 | CC-010 delivered, doc pending |
...
```

**When to update the registry:**
- After any CC task is committed → check which documents are affected → set status 🟡 or 🔴
- After any document is created/updated → set status 🟢 with new version and date
- At the start of any documentation session → review registry and report gaps to user

---

## 3. Document structure templates

### 3.1 Administrator Guide (A-01 pattern)

```
Cover page: title, version, date, audience
Table of Contents (auto-generated)

Chapter 1 — Introduction
  1.1 About this guide
  1.2 Who this guide is for (role description)
  1.3 System overview (2–3 paragraphs, non-technical)
  1.4 How to use this guide

Chapter 2 — Getting Started
  2.1 Logging in (with screenshot)
  2.2 Two-factor authentication setup
  2.3 Navigating the interface (annotated screenshot of main layout)
  2.4 Understanding your role and permissions

Chapter N — [Feature area] (one chapter per major feature)
  N.1 Overview (what this section covers)
  N.2 Step-by-step procedures (numbered, one action per step)
  N.3 Field reference table (field name | type | description | required)
  N.4 Notes, warnings, tips

Appendix A — Glossary
Appendix B — Keyboard shortcuts / Quick reference
Appendix C — Troubleshooting (symptom → cause → solution table)

Footer: version, date, confidentiality notice
```

### 3.2 User Guide (B-series pattern)

```
Cover page
Table of Contents

Introduction
  What you can do (role capabilities summary)
  What you cannot do (scope boundaries — avoid frustration)

Getting Started
  Logging in
  Your dashboard view

[Task-oriented chapters — one procedure per section]
  Chapter title = task ("Viewing queue statistics", "Managing messages")
  Each procedure:
    Goal (what you will accomplish)
    Before you start (prerequisites)
    Steps (numbered, screenshot per key step)
    Result (what success looks like)

Tips and shortcuts
Glossary (CC terminology explained for non-technical users)
Getting help (who to contact)
```

### 3.3 Onboarding Presentation (C-series .pptx pattern)

```
Slide 1 — Cover: title, date, audience role
Slide 2 — Agenda (5–7 topics)
Slide 3 — What is RTM View Shell? (2–3 bullet points, visual)
Slide 4 — Your role in the system (role-specific capabilities)
Slide 5–N — [One slide per major task/feature]
  Title = task name
  Left: screenshot or visual
  Right: 3–5 bullet points (what, why, how)
Slide N+1 — Key terminology (glossary table, 5–8 terms max)
Slide N+2 — Quick reference (most used actions on one slide)
Slide N+3 — Q&A / Getting help
Slide N+4 — Thank you / contact info
```

### 3.4 Info Slot documents (A-09, B-04, C-04) — additional structure

These documents cover the Info Slot feature (CC-010). Read `docs/widget-specification.md §6`
before writing. Key topics to cover:

**For Administrators (A-09):**
- What is an Info Slot (concept explanation)
- Creating and configuring an Info Slot (Name, DisplayMode: Ticker/Sequential, SecondsPerMessage)
- Assigning Permission Groups to an Info Slot
- Placing an Info Slot widget on a dashboard
- Configuring widget appearance (scroll direction, speed, colours, priority colours)
- Deactivating and deleting Info Slots (placement guard explained)
- Managing messages: viewing, deactivating, editing any message

**For Users/Supervisors (B-04):**
- Accessing the Info Slots page (/info-slots)
- Understanding which Info Slots are available to you
- Writing a new message (content, priority, expiry)
- Setting priority: Normal vs High (visual difference explained)
- Setting expiry date vs "Never expires"
- Editing your own message
- Deactivating your own message
- Switching display mode (Ticker ↔ Sequential) and seconds per message

**For Training deck (C-04):**
- Use case: "Inform agents about a system outage" (High priority, time-limited)
- Use case: "Daily reminder about meeting" (Normal priority, no expiry)
- Use case: "Change display to ticker for busy periods"
- Demo flow: Admin creates IS → assigns to PG → Supervisor writes message → widget shows it

---

## 4. Writing rules (user-facing documents)

### 4.1 Language and tone

| Document family | Tone | Person | Tense |
|---|---|---|---|
| Administrator guides | Professional, direct | Second ("You") | Present imperative ("Click", "Select") |
| User guides | Friendly, task-focused | Second ("You") | Present imperative |
| Training decks | Engaging, visual | Second ("You") | Present |
| Executive docs | Professional, outcomes-focused | Third ("The system") | Present |

**Never use:** jargon without definition, passive voice in instructions, future tense in steps ("You will click" → "Click").

### 4.2 Terminology consistency (user-facing)

| Technical term | User-facing equivalent | Notes |
|---|---|---|
| Permission Group | Permission Group | Keep as-is — users learn this term |
| Dashboard / Screen | Dashboard | Use "Dashboard" consistently in user docs |
| Tenant | — | Never mention to end users |
| Info Slot | Info Slot | Introduce with brief definition on first use |
| DisplayMode | Display Mode | Two words, title case |
| Ticker | Ticker (scrolling ticker) | Add clarification on first use |
| Sequential | Sequential (one at a time) | Add clarification on first use |
| 2FA | Two-Factor Authentication (2FA) | Define on first use |
| BU | Business Unit | Always spell out in user docs |

### 4.3 Screenshots and visuals

- **Every modal gets a screenshot.** Request from user if not available.
- **Annotate with callout numbers** (①②③) and describe each below the image.
- **Use arrows** to highlight buttons and fields being discussed.
- **Caption format:** `Figure N: [Description]. [Screen: /route-path]`
- For PPTs: prefer screenshots over hand-drawn diagrams. Real UI > illustration.

### 4.4 Admonitions

```
📝 Note: Used for important information that isn't a warning.
⚠️ Warning: Used before an action that could cause data loss or access issues.
💡 Tip: Used for shortcuts or best practices.
🔒 Security: Used for security-sensitive steps.
```

### 4.5 Procedure format (mandatory)

Every procedure must follow this pattern:
```
**To [accomplish task]:**

1. Navigate to [location] (e.g., **Administration → Info Slots**).
2. Click **[Button name]**.
3. In the **[Field name]** field, enter [description].
4. Click **Save →**.

✅ **Result:** [What the user will see confirming success.]
```

---

## 5. Requesting missing information

When information needed for documentation is not in project sources, use this script:

**For screenshots:**
> "To complete the [document name], I need screenshots of:
> - [Screen 1: /route] — specifically showing [modal/state]
> - [Screen 2: /route] — showing [specific feature]
> Please provide screenshots or confirm I should create placeholder references."

**For deployment details:**
> "The Deployment Guide needs site-specific details not in the spec:
> - Server hostname / IP address
> - IIS site name and port
> - PostgreSQL server hostname
> - SMTP relay hostname
> Please provide these or confirm I should use placeholders."

**For business context:**
> "The Solution Overview needs business context:
> - What problem does this system solve for your contact centre?
> - What were you using before?
> - What is the primary benefit after deployment?
> 2–3 sentences per question is sufficient."

---

## 6. Document update workflow

When a new CC task is committed:

1. **Identify affected documents** — check which features changed against the doc registry
2. **Set status to 🟡** for affected documents in `DOC-REGISTRY.md`
3. **Report to user:** "The following documents need updating: [list]. Which should I update first?"
4. **Update document** — read the relevant spec section, then update only changed sections
5. **Increment version** — minor change: v1.0 → v1.1; major change: v1.1 → v2.0
6. **Update registry** — set status to 🟢, update version and date

**CC tasks → affected documents mapping (current):**

| CC task | Affected documents |
|---|---|
| CC-010 (Info Slot base) | A-09 (new), B-04 (new), C-04 (new), A-01 update (Nav menu item), B-01 update |
| CC-011 (Message Edit) | A-09 update §Edit, B-04 update §Edit your message |
| CC-012 (DisplayMode toggle) | A-09 update §Display mode, B-04 update §Change display mode |

---

## 7. Output format rules

### Word documents (.docx)
- Use `docx` skill for all .docx output
- Save to: `docs/user-documentation/{ID}_{ShortName}_v{N.N}_{YYYY-MM-DD}.docx`
- Example: `docs/user-documentation/A-09_InfoSlot_Admin_Guide_v1.0_2026-05-29.docx`
- Always include: cover page (title, version, date, audience), table of contents, footer with version

### PowerPoint (.pptx)
- Use `pptx` skill for all .pptx output
- Save to: `docs/user-documentation/{ID}_{ShortName}_v{N.N}_{YYYY-MM-DD}.pptx`
- Slide count: 10–15 slides for onboarding; 5–8 for feature overview
- Always include: cover slide, agenda slide, Q&A slide

### Quick Reference Cards (.docx / 1 page)
- Single page, landscape orientation preferred
- Three columns: task name | steps (brief) | notes
- Font size minimum 9pt for body, 12pt for headings
- No more than 15 tasks per card

---

## 8. Session workflow

### Starting a documentation session

1. Read `docs/user-documentation/DOC-REGISTRY.md` (create it if it doesn't exist)
2. Report registry status: "Here is the current documentation package status: [table]"
3. Identify gaps (🔴 Missing, 🟡 Needs update)
4. Ask user: "Which document should we work on first?"

### Creating a new document

1. Read relevant spec sections (CLAUDE.md §N, widget-specification.md §N, wireframes)
2. List missing information and request from user (Phase 0.3)
3. Propose document outline — get user approval before writing
4. Write document section by section
5. Read `docx` or `pptx` skill before building the output file
6. Save file to `docs/user-documentation/`
7. Update `DOC-REGISTRY.md`

### Updating an existing document

1. Read the current document
2. Read what changed in the spec (ask user: "What changed?")
3. Identify exactly which sections need updating
4. Update only changed sections — don't rewrite unchanged content
5. Increment version number
6. Update registry

---

## 9. Current documentation status (initial)

At the time this skill was created (2026-05-29), the following features are implemented:

| Feature | CC Task | Docs status |
|---|---|---|
| User management | CC-001 | 🔴 Not documented |
| Permission Groups | CC-002 | 🔴 Not documented |
| Dashboard management | CC-003 | 🔴 Not documented |
| Authentication / 2FA | CC-004 | 🔴 Not documented |
| Info Slot base | CC-010 | 🔴 Not documented |
| Info Slot message edit | CC-011 | 🔴 Not documented |
| Info Slot display mode | CC-012 | 🔴 Not documented |

**Recommended first documents to create:**
1. A-09 — Info Slot Management Guide (covers newest feature, most value now)
2. B-04 — Info Slot User Guide (for supervisors managing messages)
3. C-04 — Info Slot Feature Overview Deck (for introducing the feature to management)
4. A-04 — User Management Guide (core admin function)
5. B-01 — Supervisor Quick Start Guide (first thing new users need)

---

*User Doc Expert Skill v1.0 — created 2026-05-29.*
*Covers: full Enterprise-Grade doc package, registry management, Info Slot docs (CC-010/011/012), writing rules, output workflow.*
