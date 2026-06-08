---
name: platform-presale
invocation: user
description: >
  Apply presales and marketing content expertise to the RTM View Shell project.
  Trigger this skill whenever the user mentions: presentation, pitch deck, slide deck,
  sales deck, demo presentation, product presentation, client presentation,
  proposal presentation, executive presentation, board presentation for sales,
  email to client, cold email, follow-up email, introduction email, demo follow-up,
  proposal email, outreach email, nurture email, email sequence, email campaign,
  one-pager, one page summary, product one-pager, solution brief, leave-behind,
  flyer, brochure, fact sheet, sell sheet, product sheet,
  website content, landing page, product page, homepage copy, feature page,
  about page copy, case study, customer story, testimonial, social proof,
  LinkedIn post, LinkedIn article, social media content, blog post,
  product description, value proposition, elevator pitch, tagline, messaging,
  competitive positioning, differentiator, objection handling, FAQ for sales,
  RFP response, tender response, proposal document, statement of work intro,
  demo script, discovery call script, qualification questions,
  pricing page, ROI calculator copy, business case summary for client,
  product screenshot captions, feature descriptions, release announcement,
  press release, product launch content, partner content, reseller content,
  or any request to create persuasive, promotional, or client-facing content
  about the RTM View Shell / CC Dashboard Shell platform.
  Also trigger on: "how do I pitch this", "write a sales email", "create a deck",
  "what's the value proposition", "how to present to the client",
  "write something for the website", "one-pager for the meeting".
  Never skip this skill for any client-facing or sales-oriented content.
---

# Platform Presales — RTM View Shell

This skill governs all presales, marketing, and client-facing content for the
**CC Dashboard Shell** platform (market name: **RTM View Shell**).

Read it before writing any presentation, email, one-pager, or website copy.
It defines the platform's messaging hierarchy, buyer personas, value propositions,
and content templates — so every piece of content speaks to the right person
with the right message in the right format.

---

## 0. Platform positioning — the foundation

### What we sell (one sentence)

> **RTM View Shell** is a secure, vendor-agnostic real-time monitoring shell for contact centres
> that gives every role in the organisation exactly the live operational visibility they need —
> and nothing they shouldn't see.

### What makes it different (three differentiators)

1. **Platform-agnostic** — works with Avaya, Genesys, Cisco, NICE, or any ACD via a data adapter.
   Competitors lock you into their ecosystem. We don't.

2. **Role-based visibility by design** — Permission Groups control who sees which queues,
   screens, and data. Not a shared password to a vendor dashboard.

3. **Enterprise security built in** — SSO, 2FA, full audit trail, JWT rotation, GDPR-compliant
   access logging. Most CC wallboard vendors treat security as an afterthought.

### What it is NOT (important for honest selling)

- Not a real-time data platform (the data comes from your ACD — we display it).
- Not a WFM system (no scheduling, forecasting, or shift planning).
- Not a CRM or ticketing system.
- Not a drag-and-drop builder in v1 (layout editor in v2 roadmap).

---

## 1. Buyer personas

Match every piece of content to one primary persona.

### Persona 1 — The IT Decision Maker
*CTO, IT Director, Head of IT, Enterprise Architect*

**What they care about:**
- Security posture (JWT, 2FA, SSO, audit log, GDPR).
- Technology stack compatibility (.NET 8, Windows Server, PostgreSQL — no exotic dependencies).
- Total cost of ownership (no per-seat SaaS licence, on-prem, internally maintained).
- Vendor lock-in risk (platform-agnostic, open adapter interface).
- Integration effort (clean API, documented adapter contract).

**Their objection:** "We already have a wallboard from our ACD vendor."
**Answer:** "That wallboard shows one platform's data, requires their admin access, and has no audit trail. RTM View Shell aggregates across platforms and applies your own access control layer."

**Content to use:** Architecture overview, security features, technology stack, deployment model.

---

### Persona 2 — The CC Operations Director
*Head of CC, Director of Operations, VP Customer Service*

**What they care about:**
- Supervisors having the right data without data governance risk.
- One platform for all sites and all ACD vendors.
- Rapid deployment and minimal change management.
- Cost avoidance vs buying per-seat licences from ACD vendors.
- Audit trail for regulatory compliance.

**Their objection:** "Will it work with our existing ACD?"
**Answer:** "Yes. The platform displays data from any source via a lightweight adapter. We support Avaya, Genesys, and Cisco out of the box, and the adapter interface is documented for any other platform."

**Content to use:** Solution overview, ROI story, compliance angle, reference to CC standards (ISO 18295, COPC).

---

### Persona 3 — The CEO / CFO
*Chief Executive, Chief Financial Officer, Managing Director*

**What they care about:**
- Cost reduction vs current solution.
- Risk reduction (data breach, regulatory penalty).
- Competitive advantage (better service visibility = better customer outcomes).
- Speed of deployment and payback period.

**Their objection:** "What's the ROI?"
**Answer:** "Replacing three vendor wallboard licences at £15,000/year each saves £45,000/year. Eliminating one GDPR access-control incident saves potentially millions. Most clients see payback in under 24 months."

**Content to use:** Executive summary, business case, ROI numbers, compliance risk reduction.

---

### Persona 4 — The Procurement / Commercial Lead
*Procurement Manager, Commercial Director, IT Procurement*

**What they care about:**
- Pricing model (one-time licence? annual? per user?).
- Support and maintenance terms.
- Contract flexibility and exit clauses.
- Security certification and accreditations.
- Reference customers.

**Their objection:** "How do we know it's enterprise-grade?"
**Answer:** "Built on .NET 8, PostgreSQL 16, deployed on Windows Server IIS. Same stack as tier-1 enterprise banking and insurance applications. Security design follows OWASP Top 10 and includes a full penetration test report."

**Content to use:** Technical specification summary, security documentation summary, pricing one-pager.

---

## 2. Messaging hierarchy

Use this framework to build any piece of content:

```
Level 1 — THE HEADLINE (one line, emotional/outcome)
  "Your whole team. One view. Zero data leaks."

Level 2 — THE PROBLEM (what pain does this solve?)
  Contact centres run on real-time data. But most wallboard solutions are locked to one
  vendor, shared with everyone, and have no audit trail. Supervisors see too much or too
  little. IT can't prove who accessed what.

Level 3 — THE SOLUTION (what does RTM View Shell do?)
  RTM View Shell gives every person in your CC — from supervisor to CEO — a live view
  of exactly the data they need, secured by role-based permissions, protected by
  enterprise-grade authentication, and tracked in a tamper-proof audit log.

Level 4 — THE PROOF (why should they believe you?)
  • Platform-agnostic: works with Avaya, Genesys, Cisco, NICE, and more.
  • Built on .NET 8 and PostgreSQL — deployed on your own Windows Server, no cloud dependency.
  • Full SSO, 2FA, JWT token rotation, GDPR-compliant audit log.
  • Permission Groups: granular control over who sees which queues, screens, and data.

Level 5 — THE CALL TO ACTION (what should they do next?)
  "Book a 30-minute demo."  /  "Download the solution brief."  /  "Request a proof of concept."
```

---

## 3. Taglines and headlines (use as-is or adapt)

### Primary tagline
> **"Real-time visibility. Role-based by design."**

### Alternative taglines
- "Every supervisor sees what they need. Nothing they shouldn't."
- "One platform. Every ACD. Zero vendor lock-in."
- "Your contact centre data. Secured, audited, and always live."
- "See your operations as they happen — whoever needs to see them."

### Feature-specific headlines
- Security: "Enterprise security that most CC vendors have never heard of."
- Multi-tenancy: "One deployment. Unlimited clients, sites, or brands."
- Vendor-agnostic: "Already running Avaya AND Genesys? We handle both."
- Audit log: "When the regulator asks who saw what, you'll have the answer."
- Permissions: "The supervisor in Sales should not see the Complaints queue. Now they won't."

---

## 4. Presentation templates

### 4.1 Executive pitch deck (10 slides)

```
Slide 1 — Cover
  Title: RTM View Shell
  Subtitle: Real-time contact centre visibility — secured, audited, vendor-agnostic
  [Logo] [Client name if personalised] [Date]

Slide 2 — The problem (3 bullets max)
  • CC wallboards are locked to one ACD vendor
  • Shared access = everyone sees everything (data governance risk)
  • No audit trail = regulatory exposure

Slide 3 — The cost of the problem (quantify)
  • Average 3 ACD vendor wallboard licences: £45,000/year
  • One GDPR data access incident: up to 4% global annual revenue
  • Supervisor time lost to manual reporting: X hours/week (customise per client)

Slide 4 — Introducing RTM View Shell
  [Screenshot of Screen 05 — Dashboard Viewer]
  One sentence: "A secure, vendor-agnostic real-time monitoring shell that gives
  every role in your CC exactly the visibility they need."

Slide 5 — How it works (simple diagram)
  ACD Platform(s) → Data Adapter → RTM View Shell → Role-based Dashboard
  [Avaya] [Genesys] [Cisco]     →    [Adapter]    →   [Supervisor View]
                                                    →   [Manager View]
                                                    →   [Director View]

Slide 6 — Key features (3 columns)
  [Security]          [Permissions]        [Visibility]
  SSO + 2FA           Permission Groups     5 screen types
  JWT RS256           Queue filtering       Live + historical
  Audit log           Multi-tenant          All ACD platforms

Slide 7 — Security & compliance
  • JWT access tokens (15 min), refresh token rotation
  • Full audit log: every login, access, permission change
  • GDPR Article 25 compliant (privacy by design)
  • SSO (SAML2, OIDC, AD/LDAP)
  [Use as differentiator vs ACD vendor wallboards]

Slide 8 — ROI snapshot (customise per client)
  Current state:   3 × ACD wallboard licences = £45k/year
                   Manual access management = 2 FTE-days/month
  With RTM Shell:  One platform, role-based, self-service
  Saving:          £45k licences + £18k admin time = £63k/year
  Payback:         [Implementation cost] ÷ £63k = X months

Slide 9 — Deployment & technology
  • .NET 8, Windows Server, IIS — no exotic dependencies
  • PostgreSQL 15+, Redis — runs on your own infrastructure
  • No SaaS, no cloud dependency, no data leaves your network
  • Deployed and live in [X weeks]

Slide 10 — Next steps
  [Option A] Book a live demo (30 min)
  [Option B] Proof of concept — your data, your ACD, 4 weeks
  [Option C] Proposal and commercial terms
  [Contact details]
```

### 4.2 Technical deep-dive deck (for IT audience, 8 slides)

```
Slide 1 — Cover (same as above)

Slide 2 — Architecture overview
  [C4 Level 2 container diagram]
  Web (Blazor Server) | API (ASP.NET Core) | PostgreSQL | Redis | Email

Slide 3 — Security design
  Authentication: Cookie (Blazor) + JWT Bearer (API)
  Tokens: RS256, 15 min TTL, refresh rotation with reuse detection
  MFA: Email OTP (HMAC-SHA256+salt), SSO with amr=mfa pass-through
  Audit: Separate DbContext, INSERT-only, partitioned by month

Slide 4 — Multi-tenancy model
  Shared schema, Global Query Filters on every table
  Each tenant = isolated data + isolated Redis keys
  Superadmin cross-tenant access = audited every time

Slide 5 — Permission model
  Permission Groups → Menu access + Screen access + Queue/Skill/BU filter
  AccessLevel bitmask: View=1, Edit=2, Delete=4
  Enforced at two levels: [Authorize] attribute + AuthorizationBehavior

Slide 6 — Deployment model
  Windows Server 2019/2022 + IIS in-process
  No Docker, no Linux, no cloud requirement
  Install script: idempotent PowerShell, EF migrations, IIS config

Slide 7 — Integration (adapter interface)
  IWidgetDataAdapter contract (documented, testable)
  Platform adapters: Avaya CMS, Genesys (roadmap), custom
  Data flows via SignalR to authenticated browser circuits

Slide 8 — Technology stack table
  [Layer | Technology | Version | Notes]
```

---

## 5. Email templates

### 5.1 Cold outreach — CC Operations Director

```
Subject: How [CompanyName] supervisors see live queue data — without sharing passwords

Hi [FirstName],

Most contact centres solve real-time visibility the same way:
share the ACD wallboard login with everyone who needs it.

It works. Until someone leaves, a regulator asks who accessed what,
or you add a second ACD platform and suddenly half your supervisors
can't see the data they need.

We built RTM View Shell to fix this.

It's a vendor-agnostic monitoring shell that:
→ Works with Avaya, Genesys, Cisco, and more — simultaneously
→ Gives each supervisor a view built around their specific queues and skills
→ Logs every login and data access event for compliance

[CompanyName] runs [X ACD platforms / X sites] — would it be worth 30 minutes
to see how it handles a setup like yours?

[Your name]
[Title] | [Company]
[Calendar link]

P.S. No per-seat licences. Deployed on your own Windows Server. Yours to own.
```

---

### 5.2 Follow-up after demo

```
Subject: RTM View Shell — what we showed you + next steps

Hi [FirstName],

Thank you for the time yesterday. A quick recap of what we covered:

✓ Live dashboard with role-based queue filtering (your supervisors see only their queues)
✓ Permission Groups — the model that controls what each role can access
✓ Audit log — every login and data access, timestamped and exportable
✓ SSO integration (your [Azure AD / ADFS / LDAP] — 30-minute setup)
✓ Deployment on your Windows Server — no cloud dependency

[If there were specific questions raised:]
You asked about [X] — I've attached a brief on that.

Suggested next steps — whichever works best for you:

1. Proof of concept (4 weeks): we connect to your [ACD name] test environment,
   configure 2–3 permission groups matching your actual roles, and you evaluate
   with real data.

2. Proposal: I send commercial terms and an implementation timeline this week.

3. Reference call: I connect you with [reference client type] who deployed last quarter.

What makes sense?

[Your name]
[Calendar link]
```

---

### 5.3 Re-engagement (went quiet after initial interest)

```
Subject: Quick question about [CompanyName]'s wallboard situation

Hi [FirstName],

We spoke [X weeks] ago about RTM View Shell. I don't want to assume
the need has gone away — CC data access challenges have a habit of
coming back (especially around audit season or when a new ACD gets added).

One thing I didn't show you last time: the audit log export.
For teams dealing with GDPR access requests or FCA compliance,
it's often the feature that makes the conversation with legal much simpler.

Would a 15-minute call this week make sense?
If the timing isn't right, just say so — I'll check back in Q[X].

[Your name]
[Calendar link]
```

---

### 5.4 Proposal submission cover email

```
Subject: RTM View Shell — Proposal for [CompanyName]

Hi [FirstName],

Please find attached our proposal for RTM View Shell at [CompanyName].

The proposal covers:
• Solution scope and architecture
• Implementation approach and timeline ([X] weeks to go-live)
• Commercial terms
• Support and maintenance model

Key numbers from the proposal:
  Implementation:      £[X]
  Annual saving:       £[X] (licence consolidation + admin time)
  Payback period:      [X] months

I'm available [Day] or [Day] this week to walk through it together —
a 45-minute call is usually enough to cover the questions that come up.

[Your name]
[Direct number] | [Email]
```

---

## 6. One-pager templates

### 6.1 Solution one-pager (A4, 2-column layout)

```
┌─────────────────────────────────────────────────────────────┐
│  RTM VIEW SHELL                                             │
│  Real-time contact centre visibility — secured by design    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────┐  ┌─────────────────────────────────┐
│  THE PROBLEM            │  │  THE SOLUTION                   │
│                         │  │                                 │
│  • ACD wallboards lock  │  │  RTM View Shell is a secure,    │
│    you to one vendor    │  │  vendor-agnostic monitoring     │
│                         │  │  shell that gives every role    │
│  • Shared logins mean   │  │  exactly the visibility         │
│    everyone sees        │  │  they need — and nothing        │
│    everything           │  │  they shouldn't.                │
│                         │  │                                 │
│  • No audit trail =     │  │  Works with: Avaya · Genesys    │
│    regulatory exposure  │  │  Cisco · NICE · any ACD         │
└─────────────────────────┘  └─────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  KEY CAPABILITIES                                           │
│                                                             │
│  🔐 SECURITY              📊 VISIBILITY                     │
│  SSO + 2FA                5 configurable screen types       │
│  JWT RS256 tokens          Live queue and agent data         │
│  Full audit log            Queue filter tabs by role         │
│  GDPR-compliant            Real-time and interval metrics    │
│                                                             │
│  👥 ACCESS CONTROL        🔌 INTEGRATION                    │
│  Permission Groups         Vendor-agnostic data adapter      │
│  Menu-level control        Avaya · Genesys · Cisco ready     │
│  Queue/skill filtering     .NET 8 · PostgreSQL · Windows     │
│  Business Unit isolation   On-premises, no cloud required    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  ROI AT A GLANCE                                            │
│                                                             │
│  Eliminate 3 ACD wallboard licences    → £45,000/year       │
│  Reduce access management admin        → £18,000/year       │
│  GDPR audit evidence on demand         → Risk mitigation    │
│  Typical payback period                → 18–24 months       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  DEPLOYMENT                                                 │
│  Windows Server 2019/2022 · IIS · PostgreSQL 15+            │
│  Redis · Deployed and live in [X] weeks                     │
│  No per-seat licences · Your infrastructure · Your data     │
└─────────────────────────────────────────────────────────────┘

[Logo] [Website] [Email] [Phone]
```

### 6.2 Security one-pager (for IT / Compliance audience)

```
┌─────────────────────────────────────────────────────────────┐
│  RTM VIEW SHELL — SECURITY OVERVIEW                         │
│  Enterprise-grade security for contact centre operations    │
└─────────────────────────────────────────────────────────────┘

AUTHENTICATION
  □ SSO: SAML2, OIDC, Active Directory/LDAP
  □ Local accounts with enforced password policy (12+ chars, complexity)
  □ Two-Factor Authentication: email OTP, HMAC-SHA256+salt, 10-min TTL
  □ Brute-force protection: 5 attempts → 15-min lockout

SESSION SECURITY
  □ Cookie: __Host- prefix, HttpOnly, Secure, SameSite=Strict
  □ JWT: RS256 (RSA-2048), 15-min access token, 8h refresh token
  □ Refresh token rotation: every use issues a new token; reuse = all sessions revoked
  □ Forced logout: invalidates all sessions instantly (SecurityStamp)

ACCESS CONTROL
  □ Role-based: Superadmin · Administrator · Editor · Viewer
  □ Permission Groups: granular menu, screen, queue, skill, and BU access
  □ Two-level enforcement: attribute (UI) + pipeline behaviour (API)
  □ Multi-tenant isolation: Global Query Filters on every data table

AUDIT & COMPLIANCE
  □ Immutable audit log: every login, logout, access, and permission change
  □ INSERT-only: application cannot delete audit records
  □ GDPR Article 25 compliant: privacy by design, access by permission
  □ Exportable: CSV up to 50,000 records; async for larger exports

INFRASTRUCTURE
  □ Security headers: CSP with nonce, HSTS, X-Frame-Options: DENY
  □ PostgreSQL: localhost only, scram-sha-256, encrypted connection (sslmode=verify-full)
  □ Redis: localhost only, password-protected, dangerous commands disabled
  □ Secrets: Azure Key Vault / HashiCorp Vault (no secrets in config files)

STANDARDS ALIGNMENT
  □ OWASP Top 10 mitigations addressed
  □ GDPR Article 25 (privacy by design)
  □ PCI-DSS considerations documented
  □ Penetration test report available on request

[Logo] [Security contact] [Documentation link]
```

---

## 7. Website / landing page copy

### 7.1 Hero section

```
HEADLINE:
  Real-time contact centre visibility.
  Role-based by design.

SUBHEADLINE:
  RTM View Shell gives every person in your contact centre —
  from supervisor to CEO — a live operational view secured
  by permission groups, protected by enterprise-grade authentication,
  and backed by a tamper-proof audit trail.

CTA BUTTONS:
  [Book a demo]  [Download solution brief]
```

### 7.2 Problem section

```
SECTION HEADLINE:
  Your current wallboard was designed for one platform. Your operation isn't.

BODY:
  Most contact centre wallboards are locked to a single ACD vendor.
  When you add a second platform, you get a second wallboard — with a second
  shared login, a second set of admin headaches, and still no audit trail.

  Meanwhile, your supervisors see each other's queues.
  Your compliance team has no idea who accessed what.
  And when the regulator asks, you have no answer.
```

### 7.3 Features section (3-column)

```
VENDOR-AGNOSTIC
  Works with Avaya, Genesys, Cisco, NICE, and more — simultaneously.
  One platform. Every ACD. No more "but we use two vendors."

PERMISSION BY DEFAULT
  Permission Groups control exactly which menus, screens, queues,
  skills, and business units each role can see. Not a shared password.
  Role-based from the ground up.

AUDIT TRAIL INCLUDED
  Every login, every screen view, every permission change —
  timestamped, IP-traced, and impossible to delete.
  Answer GDPR access requests in minutes, not days.
```

### 7.4 Social proof section (template — fill with real clients)

```
"We had three ACD vendors across five sites. RTM View Shell
 was the only platform that gave our supervisors a unified view
 without rebuilding our entire tech stack."
— [Title], [Company type], [Country]

"The audit log alone justified the investment.
 Our first FCA access request was answered in 20 minutes."
— [Title], [Company type], [Country]
```

### 7.5 CTA section

```
HEADLINE:
  See your contact centre as it happens.

BODY:
  Book a 30-minute demo. We'll show you how RTM View Shell works
  with your ACD platform, configure a permission group for your
  exact team structure, and walk you through the audit log.

  No pitch. No pressure. Just the platform working with your data.

CTA: [Book a demo] [or download the one-pager first →]
```

---

## 8. LinkedIn content

### 8.1 Thought leadership post (Operations Director persona)

```
Most contact centre wallboards have a problem nobody talks about.

They show everything to everyone.

Your Sales supervisor can see the Complaints queue metrics.
Your evening shift team sees the VIP client data.
And when a regulator asks who accessed what last Tuesday, you have no answer.

Permission-based real-time monitoring isn't a luxury — it's table stakes for any
regulated contact centre in 2026.

RTM View Shell was built for exactly this:
→ Each supervisor sees only the queues they manage
→ Full audit log of every login and data access
→ SSO, 2FA, GDPR-compliant from day one

Happy to show you what this looks like in practice.
[Book a demo] or DM me.

#ContactCentre #CustomerService #RealTimeMonitoring #DataGovernance #CX
```

### 8.2 Product announcement post

```
We built something that contact centre teams have been asking for.

A real-time monitoring shell that:
✓ Works with ANY ACD platform (Avaya, Genesys, Cisco, NICE — simultaneously)
✓ Controls who sees what via Permission Groups
✓ Tracks every access event in an immutable audit log
✓ Runs on your own Windows Server — no SaaS, no cloud dependency

RTM View Shell v1.0 is live.

If you're managing a CC with more than one platform, more than one team,
or more than one regulator looking over your shoulder — let's talk.

[Link to landing page]

#ContactCentre #RTM #Wallboard #CX #EnterpriseIT
```

---

## 9. Objection handling — quick reference

| Objection | Response |
|---|---|
| "We already have a wallboard from our ACD vendor." | "Great — that wallboard shows one platform's data, requires vendor admin access, and has no audit trail or permission model. RTM View Shell sits above it and gives you access control, multi-platform consolidation, and GDPR evidence." |
| "It's too expensive for what it does." | "Compare to three ACD wallboard licences at £15k each — that's £45k/year. We typically pay back in under 24 months, after which it's pure saving." |
| "We don't have in-house .NET developers to maintain it." | "The platform is designed for low maintenance. Once deployed, day-to-day admin is UI-based. For upgrades, we offer a support contract. Most clients run it with their existing Windows Server admin." |
| "We're moving to the cloud / a new ACD." | "Perfect timing. RTM View Shell is vendor-agnostic — when you migrate your ACD, you swap the adapter, not the shell. Your permission groups, screens, and audit history all stay intact." |
| "Our ACD vendor already has a permission model." | "ACD permission models control platform access. RTM View Shell controls *data visibility* — which queues, which teams, which business units. They solve different problems." |
| "We need SSO to work with Azure AD." | "SSO is built in: SAML2, OIDC, and AD/LDAP. Azure AD OIDC setup typically takes 30 minutes." |
| "Can you show us a reference customer?" | "Yes. I'll arrange a reference call with a [similar industry] client who deployed [X months ago]. They went live in [X weeks]." |
| "We'd need to do a pen test before we buy." | "We welcome it. We have a security design document and previous pen test findings available under NDA. The platform is built to OWASP Top 10 standards with full audit trail." |

---

## 10. Content quality checklist — before sending

### All client-facing content
- [ ] Persona match: is this written for the right audience?
- [ ] No technical jargon for non-technical audiences (and vice versa)
- [ ] Value proposition clear in the first 3 sentences
- [ ] Every claim is either a feature (verifiable) or a client outcome (attributed)
- [ ] No "we" without "you" — every we-statement has a you-benefit
- [ ] Call to action is specific (not "contact us" — "book a 30-min demo")
- [ ] Client name / company name personalised where template has [placeholders]
- [ ] Spelling and grammar checked (especially client name, title, company)

### Presentations
- [ ] Maximum 8 words per bullet on a slide
- [ ] No slide has more than 5 bullets
- [ ] Every slide has one key takeaway (can be stated in one sentence)
- [ ] Screenshots are current (not from a wireframe or earlier version)
- [ ] Brand colours and fonts consistent throughout
- [ ] Slide numbers included

### Emails
- [ ] Subject line under 50 characters
- [ ] First line is not "I hope this email finds you well"
- [ ] One clear ask per email (not three options in the same sentence)
- [ ] Signature includes direct contact (phone or calendar link)
- [ ] Tested: does it read well on mobile?

### One-pagers
- [ ] Fits on one A4 page (or one screen without scrolling)
- [ ] Logo and contact details included
- [ ] PDF version created (not just .docx)
- [ ] Date or version number in footer
