body.push(H1("1. Overview — what “multi-tenant” means here"));
body.push(P("RTM View Shell hosts many customer organisations (“tenants”) on one installation. The model is shared database, shared schema: every tenant-scoped row carries a TenantId discriminator, and the application automatically filters every query by the current tenant. A tenant is the unit of isolation — its users, permission groups, dashboards, queues, skills and agent-state model are private to it."));
body.push(P("Three facts frame everything in this guide:"));
body.push(...bullets([
 [{t:"One Superadmin governs the whole platform.",b:true}," The Superadmin is the only role that sees across tenants, creates them, and can switch into any one of them (impersonation, always audited). Every other role — Administrator, Editor, Viewer — is confined to a single tenant."],
 [{t:"Isolation is enforced in code, not just the UI.",b:true}," Global Query Filters scope every database read to the active tenant; hiding a menu is cosmetic only. §9 documents this in full."],
 [{t:"One RTM Service instance serves exactly one tenant.",b:true}," The data-collection Windows Service is bound to a tenant at deployment time through its configuration file. Binding is covered in §7."]
]));
body.push(P("Tenant management lives on Screen 06 — Tenant Management (/platform/tenants), visible to the Superadmin only. Its four tabs — General, Settings, Appearance, Agent States — map to §2–§5 below."));
body.push(H1("2. The tenant lifecycle"));
body.push(P("A tenant is always in exactly one of three states (Tenant.Status):"));
body.push(tbl(["State","Meaning","Effect on login","Data"],
 [["Active","Normal operation","Logins permitted","Live"],
  ["Suspended","Temporarily disabled","All logins for the tenant rejected","Retained intact"],
  ["Deleted","Decommissioned","Invisible to authentication","Purged ≥ 30 days after transition"]],
 [1500,2700,2960,2200],{zebra:true}));
body.push(P("Each transition writes an audit event (Tenant.Created, Tenant.Suspended, Tenant.Resumed, Tenant.Deleted), so the lifecycle is fully traceable (§10)."));
body.push(P([{t:"Create a tenant",b:true}," (General tab → “+ New Tenant”): supply a display Name and a unique Slug. The slug becomes the tenant’s subdomain — acme resolves acme.cc-dashboard.local to this tenant — so it must be lowercase, unique, and stable. On first save the platform seeds the tenant: its tenant_settings row with defaults (§3), the five standard agent-state definitions (§5), and an empty permission-group set."]));
body.push(P([{t:"Suspend / Resume",b:true}," (General tab → Status dropdown): set Suspended to immediately block every login without touching data; set it back to Active to restore. Existing sessions are rejected on their next authenticated action."]));
body.push(P([{t:"Delete",b:true}," (General tab → Status → Deleted): a soft transition. The tenant disappears from authentication immediately, but its data remains on disk for at least 30 days before the background purge job removes it."]));
body.push(callout("ok","Worked walkthrough — stand up tenant “acme”",[
  [{t:"1.",b:true}," General tab → “+ New Tenant” → Name “Acme Corp”, Slug acme, Status Active → Save. The platform writes the tenants row, a default tenant_settings row, seeds five agent-state definitions; Tenant.Created lands in the audit log."],
  [{t:"2.",b:true}," Settings tab → set the password policy and 2FA requirement for Acme (§3)."],
  [{t:"3.",b:true}," Create Acme’s first Administrator (User Management, A-02) — that Administrator then builds Acme’s permission groups, users and dashboards."],
  [{t:"4.",b:true}," When Acme’s RTM Service is deployed, copy Acme’s tenant UUID from this screen into the service config (§7). Acme is now live and fully isolated."]
]));
body.push(H1("3. Tenant Settings"));
body.push(P("The Settings tab edits the tenant’s tenant_settings row (one-to-one with the tenant). Every value here applies only to this tenant:"));
body.push(tbl(["Setting","Field","Default","Effect"],
 [["Licensing — purchased licences","integer","—","Informational seat cap"],
  ["Licensing — user connections","integer","0","Max concurrent connections; 0 = unlimited"],
  ["Password — minimum length","PasswordMinLength","12","Enforced on every password set"],
  ["Password — expiry (days)","PasswordExpireDays","90","Forces a change after N days"],
  ["Security — require 2FA for all","Require2faForAll","off","Forces e-mail 2FA on for every user"],
  ["Security — default locale","DefaultLocale","en-US","BCP-47 culture for new users / login"],
  ["SignalR Widgets — connection URL","SignalRConnectionUrl","—","RTM Service hub URL the relay connects to (§7)"],
  ["Data — audit retention (days)","AuditRetentionDays","365","Age beyond which audit partitions drop"],
  ["Data — soft-delete screens","SoftDeleteDashboards","off","Deleting a dashboard hides vs removes"],
  ["Data — soft-delete retention (days)","SoftDeleteRetentionDays","90","Age after which soft-deleted dashboards purge"],
  ["Service level — SL threshold (seconds)","SlThresholdSeconds","— (unset)","Per-tenant service-level target in seconds; used by Historical Reports SL calculations"]],
 [2700,2200,1260,3200],{zebra:true,codeCols:[1]}));
body.push(P("The password and 2FA settings feed the security behaviour documented in the Installation & Security guides; the SignalR connection URL is the single binding between this tenant and its RTM Service hub (§7). Sensitive provider fields (e-mail credentials, SSO client secret) are stored encrypted."));
body.push(H1("4. Appearance & localisation"));
body.push(P("The Appearance tab sets per-tenant presentation defaults that the (future) widget editor inherits: available font sizes, a background colour palette, and a font colour palette. These do not affect isolation or security — they brand the tenant’s screens."));
body.push(P("Localisation is driven by Default locale (Settings tab) plus each user’s own PreferredLocale. The platform supports any BCP-47 language by adding a resource file — no code change — and renders right-to-left layouts automatically for Arabic, Hebrew and Farsi. All timestamps are stored in UTC and converted to the user’s locale in the UI."));
body.push(H1("5. The agent-state model"));
body.push(P("The Agent States tab (Superadmin-only) defines how the raw agent-status names from the contact-centre platform are grouped for display and metric aggregation. Three concepts:"));
body.push(...bullets([
 [{t:"Agent State",b:true}," — a raw state name as the CC platform emits it (e.g. AVAILABLE, LUNCH, ONPHONE)."],
 [{t:"State Group",b:true}," — a display bucket (e.g. Available, Break) that one or more states roll up into."],
 [{t:"Definition",b:true}," — the mapping that assigns exactly one State to exactly one Group, per tenant."]
]));
body.push(P("The metric identifier is not stored on the definition; it is resolved at query time by joining the metric catalogue on the state name. Every tenant is seeded with five standard definitions: AVAILABLE → Available, ONPHONE → On Phone, BREAK → Break, PAPERWORK → Paperwork, TRAINING → Training."));
body.push(P([{t:"Managing groups",b:true}," (Section 1): add a group, rename it inline, or deactivate it (Danger-Zone: reassign the group’s states to another active group, or deactivate all its states — you must choose)."]));
body.push(P([{t:"Managing states",b:true}," (Section 2): add a state (name + a target active group), change a state’s mapped group, or deactivate a state (this also deactivates its definition). Nothing is ever physically deleted; deactivation is a soft state."]));
body.push(P([{t:"Validation:",b:true}," state names and group names are each unique per tenant, case-insensitive; a state cannot exist without being assigned to a group."]));
body.push(callout("ok","Worked walkthrough — add a “LUNCH” state",[
  "Acme’s platform emits a distinct LUNCH status that should report under breaks but separately from short breaks.",
  [{t:"1.",b:true}," Section 1 → “+ Add State Group” → Meal Break."],
  [{t:"2.",b:true}," Section 2 → “+ Add State” → name LUNCH, group Meal Break → Save."],
  "From the next refresh, time in LUNCH aggregates under Meal Break in every agent-state metric for Acme — no code change, no effect on other tenants."
]));
body.push(H1("6. SSO configuration (per tenant)"));
body.push(P("Each tenant may have its own single-sign-on provider, stored in sso_configurations and linked from the tenant’s settings. Supported protocols: SAML 2.0, OIDC, and AD / LDAP. You provide the provider metadata and a claim-mapping that translates the provider’s claims into local user fields; on SSO login a local user is provisioned just-in-time. If the provider asserts MFA (amr=mfa), system 2FA is skipped."));
body.push(callout("note","Version note",[
  "In the current release SSO is a configurable stub: the screens accept and store a configuration, but live federation is delivered in a later sprint. Until then, users sign in with local accounts plus e-mail two-factor. The configuration you enter now is preserved and activates when the provider integration ships."]));
body.push(H1("7. Binding an RTM Service instance to a tenant"));
body.push(P("The RTM Service collects real-time data and pushes it to the Shell. It has no logged-in user, so it is bound to a tenant statically, at deployment. One instance = one tenant. Two halves:"));
body.push(...nums([
 [{t:"In the service config",b:true}," (appsettings.json, section RTM): set \"TenantId\" to the tenant’s UUID. Empty/missing = fatal start-up error."],
 [{t:"In the Shell",b:true}," (Settings tab → SignalR Connection URL): set the tenant’s hub URL; the Shell’s relay opens one server-to-server connection (browsers never connect to the service directly)."]
]));
body.push(P("Deployment checklist: (1) copy the tenant UUID from Screen 06; (2) set RTM:TenantId before first start; (3) confirm the bound TenantId in the start-up log; (4) verify the tenant’s business units are visible and non-zero where data exists."));
body.push(callout("warn","Safety note — never run an unscoped midnight clear",[
  "The service’s daily housekeeping deletes interaction and user-status rows. It must be tenant-scoped (WHERE \"TenantId\" = …); an unscoped version would wipe all tenants. Confirm the deployed routine is the tenant-scoped build before enabling the schedule."]));
body.push(P([{t:"For the full install / upgrade mechanics of the service, see A-01 — Installation & Deployment Guide.",i:true}]));
body.push(H1("8. Tenant switching (impersonation)"));
body.push(P("The Superadmin can switch the active tenant from the admin UI to operate inside a tenant’s context — to reproduce a problem, verify a configuration, or assist support. Switching changes the TenantId on the active session and writes a Tenant.Switched audit event, so every impersonation is on the record. Switch back the same way when finished."));
body.push(H1("9. Isolation & security guarantees (the compliance story)"));
body.push(...bullets([
 [{t:"Automatic query scoping.",b:true}," Every read on a tenant-scoped table is filtered by the active TenantId through Global Query Filters. Application code cannot accidentally read another tenant’s rows."],
 [{t:"Audited escape hatch only.",b:true}," The filter is bypassed solely inside dedicated system repositories, and every such use writes a Tenant.CrossTenantAccess audit event."],
 [{t:"Defence in depth.",b:true}," Cache keys, real-time group names and blob containers are all tenant-prefixed — isolation holds in Redis, SignalR and storage, not only the database."],
 [{t:"Intentionally shared platform data.",b:true}," The widget catalogue, application roles and the tenant registry are cross-tenant and carry no customer data."],
 [{t:"Login binds user to tenant.",b:true}," Authentication verifies the user’s tenant matches the resolved subdomain; a mismatch is rejected with the generic failed-login message and recorded as Login.Failure / TenantMismatch."]
]));
body.push(H1("10. Auditing tenant operations"));
body.push(P("Every platform-level action is recorded and viewable on the Audit screen. Tenant-relevant events: Tenant.Created/Suspended/Resumed/Deleted; Tenant.Switched; Tenant.CrossTenantAccess; WidgetCatalog.ItemAdded/ItemUpdated/ItemDeactivated; System.AuditPurged. Each entry carries actor, UTC timestamp, IP, user-agent, JSON details; retained per AuditRetentionDays (default 365). Exports over 50,000 rows run as a background job delivered by e-mail."));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Tenant Settings reference"));
body.push(P("The full tenant_settings column set, types, defaults and effect — see the table in §3 (incl. SlThresholdSeconds). Encrypted fields (e-mail provider config, SSO client secret) are protected at rest and never shown in plaintext."));
body.push(H1("Appendix B — Agent-state seed & validation"));
body.push(P("Seed (every tenant, first run): AVAILABLE → Available, ONPHONE → On Phone, BREAK → Break, PAPERWORK → Paperwork, TRAINING → Training. Validation: state/group names unique per tenant (case-insensitive); one state → one group; no state without a group; deactivation is soft."));
body.push(H1("Appendix C — RTM Service per-tenant deployment checklist"));
body.push(P("Copy the tenant UUID (Screen 06) → set RTM:TenantId (empty = fatal) → set the SignalR Connection URL in the Shell → start; confirm bound TenantId in the log → verify data is scoped (non-zero BU count) → confirm the midnight-clear routine is tenant-scoped before enabling the schedule."));
body.push(H1("Appendix D — Audit event catalogue (tenant operations)"));
body.push(P("Tenant.Created, Tenant.Suspended, Tenant.Resumed, Tenant.Deleted, Tenant.Switched, Tenant.CrossTenantAccess, WidgetCatalog.ItemAdded, WidgetCatalog.ItemUpdated, WidgetCatalog.ItemDeactivated, System.AuditPurged. Each: actor, UTC timestamp, IP, user-agent, JSON details; retained per AuditRetentionDays."));
