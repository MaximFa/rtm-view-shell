# RTM View Shell — Multi-Tenant Management Guide (A-07)

> Audience: Superadmin (platform operator). Brand: INSIGHTENSE. Route: /platform/tenants (Screen 06).
> Source: CLAUDE.md §5/§6/§16/§20/§21-Screen06/§33/§34.

## Document revision history
| Version | Date | Summary | Product release ID | Shipped-with |
|---|---|---|---|---|
| 1.0 | 2026-06-13 | Initial | RTM-REL-2026.06 | (pending push) |
| 1.1 | 2026-06-22 | Added SlThresholdSeconds tenant setting (Historical Reports SL) | RTM-REL-2026.06 | (pending push) |

1. **Overview** — shared-DB/schema multi-tenancy; TenantId discriminator; Superadmin governs; one RTM Service = one tenant; Screen 06 (4 tabs).
2. **Lifecycle** — Active/Suspended/Deleted (+ audit events); create (Name/Slug), suspend/resume, soft-delete (≥30d purge); acme walkthrough.
3. **Settings** — 11-row table incl. password policy, 2FA, SignalR URL, retention, **SlThresholdSeconds** (per-tenant SL target for Historical Reports).
4. **Appearance & localisation** — per-tenant fonts/palettes; BCP-47 + RTL; UTC storage.
5. **Agent-state model** — State/Group/Definition; seed 5; add/reassign/deactivate (soft); LUNCH walkthrough.
6. **SSO** — per-tenant SAML2/OIDC/AD-LDAP; JIT; amr=mfa skips 2FA; v1 = configurable stub.
7. **RTM binding** — one instance/tenant; RTM:TenantId (empty=fatal) + SignalR URL; deployment checklist; midnight-clear tenant-scope safety.
8. **Impersonation** — Superadmin tenant switch, audited (Tenant.Switched).
9. **Isolation/compliance** — GQF auto-scoping; audited bypass; prefixed cache/RT/storage; login binds user↔tenant.
10. **Audit** — Tenant.* + CrossTenantAccess + WidgetCatalog.* + AuditPurged; retention 365d default.

Appendices A–D: settings reference, agent-state seed/validation, RTM deploy checklist, audit catalogue.
