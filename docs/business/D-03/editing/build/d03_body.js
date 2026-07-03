body.push(H1("1. About this release"));
body.push(P("RTM View Shell v1.0 is the secure management shell for a contact-centre real-time monitoring system. It manages users, permissions and dashboards, and provides the secure foundation — authentication, multi-tenancy, and a full audit trail — on which live data widgets and historical reports are delivered. It is built on .NET 8 and Blazor Server with PostgreSQL and Redis, and deploys to Windows Server."));
body.push(H1("2. What’s delivered"));
body.push(...bullets([
 [{t:"Multi-tenant platform. ",b:true},"Many isolated organisations on one installation; per-tenant settings; a Superadmin who governs the platform; audited tenant switching."],
 [{t:"User management. ",b:true},"Create, edit, block and reset users; roles (Superadmin, Administrator, Editor, Viewer); temporary-password onboarding; server-side paged, filterable lists."],
 [{t:"Permission groups. ",b:true},"Granular access to menus, screens, queues, skills, business units and agent supergroups; empty-list-denies safe defaults; backend-enforced at every request."],
 [{t:"Dashboard management + editor. ",b:true},"Create, rename, delete and search dashboards; per-group / public access; a screen editor with drag-and-drop layout, alignment guides, multi-select and grid."],
 [{t:"Widgets + Info Slots. ",b:true},"Widget catalogue and rendered widgets; Info Slots for live on-screen messages."],
 [{t:"Historical Reports. ",b:true},"Queue and agent reports (Queue Interval, Queue Wait Time, Agent Monthly, Agent Shift Detail) with date filters, permission-scoping, service-level threshold and export."],
 [{t:"Secure authentication. ",b:true},"Hardened cookie sessions, e-mail two-factor, RSA-signed JWT for the REST API with rotation and reuse-detection, and per-tenant SSO configuration."],
 [{t:"Full audit trail. ",b:true},"Append-only logging of every authentication, permission-change, and tenant action; viewable and exportable, with per-tenant retention."]
]));
body.push(H1("3. Known limitations in v1.0"));
body.push(...bullets([
 "Single Sign-On is configurable but federation is a stub in v1.0; users sign in with local accounts plus e-mail two-factor until the provider integration ships.",
 "Some report exports and the newest screen-editor refinements are being finalised; see the current known-issues list for details."
]));
body.push(H1("4. Compatibility"));
body.push(tbl(["Area","Supported"],[
 ["Browsers","Chrome, Firefox, Edge (latest two); Safari 16+"],
 ["Minimum resolution","1280×768; Viewer read-only on mobile (basic)"],
 ["Runtime",".NET 8 (LTS)"],
 ["Database","PostgreSQL 15+ (16/18 recommended)"],
 ["Cache","Redis-compatible 7+ (Memurai / Garnet on Windows)"],
 ["Hosting","Windows Server 2019 / 2022"]
],[2600,6760],{zebra:true}));
body.push(H1("5. Installation & upgrade"));
body.push(P("Installation and upgrade are scripted for Windows Server. The Installation & Deployment Guide (A-01) and the Upgrade & Patch Guide (A-09) cover first install and in-place updates; both are finalised against the confirmed production deployment."));
body.push(H1("6. The road ahead"));
body.push(...bullets([
 "Live SSO federation (OIDC / SAML 2.0 / AD-LDAP) replacing the v1.0 stub.",
 "Continued reporting and widget enhancements.",
 "Operational tooling: backup/restore runbook, health and monitoring, cache migration (Garnet)."
]));
body.push(callout("note","Security posture",[
 "The v1.0 security controls are summarised in the Security & Compliance Summary (D-02) and detailed in the Security Configuration Guide (A-04)."]));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Feature status at a glance"));
body.push(tbl(["Capability","Status in v1.0"],[
 ["Multi-tenant user & permission management","Delivered"],
 ["Dashboard management + screen editor","Delivered"],
 ["Widget rendering + Info Slots","Delivered"],
 ["Historical Reports","Delivered (exports being finalised)"],
 ["Secure auth (cookie, 2FA, JWT)","Delivered"],
 ["Audit trail","Delivered"],
 ["SSO live federation","Configurable; stub in v1.0"]
],[5200,4160],{zebra:true}));
