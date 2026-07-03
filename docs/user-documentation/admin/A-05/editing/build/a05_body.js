body.push(H1("1. What SSO gives you"));
body.push(P("Single Sign-On lets a tenant’s users authenticate with their existing corporate identity instead of a separate RTM View Shell password. It is configured per tenant and supports three protocols:"));
body.push(...bullets([[{t:"OpenID Connect (OIDC)",b:true}," — modern token-based federation."],[{t:"SAML 2.0",b:true}," — the long-established enterprise standard."],[{t:"Active Directory / LDAP",b:true}," — direct directory authentication."]]));
body.push(P("When SSO is active, the sign-in page offers a prominent Sign in with SSO option; local sign-in can remain as a fallback."));
body.push(callout("note","Release status",["In the current version SSO is a configurable stub: the screens accept and store a provider configuration, but live federation is delivered in a later sprint. Until then, users sign in with local accounts plus e-mail two-factor. Everything you configure now is preserved and activates when the provider integration ships."]));
body.push(H1("2. Where SSO is configured"));
body.push(P("A tenant’s SSO settings live with its Tenant Settings (A-07). For the chosen protocol you provide:"));
body.push(tbl(["Field","Used by","Notes"],[
 ["Provider","all","OIDC, SAML2, or AD_LDAP"],["Metadata / discovery URL","OIDC, SAML2","The provider’s discovery or metadata endpoint"],
 ["Client ID","OIDC","The application’s client identifier at the provider"],["Client secret","OIDC","Stored encrypted; never shown in plaintext"],
 ["Claim mappings","all","How provider claims map to local user fields (§3)"],["Active","all","Turns this configuration on"]
],[2500,1900,4960],{zebra:true}));
body.push(P("Credentials are encrypted at rest; only an administrator can replace them, and they are never displayed back."));
body.push(H1("3. Claim mapping"));
body.push(P("A claim mapping tells RTM View Shell how to read the provider’s assertion and fill in the local user. At minimum map the user identifier and e-mail; optionally first/last name and a tenant-selector claim. The tenant is normally determined by the subdomain; a claim-based mapping is available where one address serves several tenants."));
body.push(H1("4. Just-in-time provisioning"));
body.push(P("On a successful SSO sign-in, if no local account exists yet, RTM View Shell creates one from the mapped claims; if it exists, its mapped fields are updated. New SSO users still need a permission group to see anything — decide whether to assign a default group at rollout or provision + assign manually before first sign-in."));
body.push(H1("5. SSO and two-factor"));
body.push(P("If your provider performs its own multi-factor check and asserts it (amr contains mfa), RTM View Shell skips its system-level code — the user is not asked twice. If the provider does not assert MFA, the system applies its own two-factor. Either way you keep a second factor without double-prompting."));
body.push(H1("6. Choosing a protocol"));
body.push(...bullets([[{t:"Choose OIDC",b:true}," for modern providers (Azure AD / Entra ID, Okta, Google Workspace, Keycloak) — simplest to operate, uses discovery."],[{t:"Choose SAML 2.0",b:true}," when your IdP or policy standardises on SAML."],[{t:"Choose AD / LDAP",b:true}," to authenticate against an on-premises directory without a federation layer."]]));
body.push(H1("7. Verification and troubleshooting"));
body.push(P("When SSO goes live, verify end-to-end: a test user reaches the provider from the SSO button, returns authenticated, lands in the correct tenant, and has the expected permission group. Common issues: a mismatched return URL/audience, a claim mapping that doesn’t match the provider’s actual claim names, or a user with no permission group. The audit log records each SSO.Login — the first place to look."));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Provider field reference"));
body.push(P("See §2. The client secret and credentials are encrypted at rest and never displayed back; replace rather than view them."));
body.push(H1("Appendix B — Claim mapping (minimum)"));
body.push(P("Map at least the user identifier and e-mail; optionally first/last name and a tenant-selector claim. Tenant is normally taken from the subdomain. New users are provisioned just-in-time and need a permission group assigned to gain access."));
body.push(H1("Appendix C — MFA interplay"));
body.push(P("Provider asserts amr=mfa → system 2FA skipped. Provider does not assert MFA → system e-mail 2FA applies. Either path keeps a second factor without double-prompting."));
