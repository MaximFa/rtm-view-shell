body.push(H1("1. Before you start"));
body.push(P("You need three things: the web address of your RTM View Shell (usually a name in front of the company domain — e.g. acme.cc-dashboard.local); your username or e-mail; and access to the mailbox tied to your account, because sign-in uses an e-mailed verification code."));
body.push(P("RTM View Shell runs in any modern browser — Chrome, Firefox, Edge (latest two versions) or Safari 16+. The connection is always secured (HTTPS); if your browser warns that the address is not secure, stop and contact your administrator."));
body.push(H1("2. Signing in"));
body.push(P("There are two ways to sign in. Your organisation decides which is available to you."));
body.push(P([{t:"Single Sign-On (SSO). ",b:true},"If your organisation uses SSO, the sign-in page shows a prominent Sign in with SSO button at the top — use your corporate account. If your SSO provider already performed a multi-factor check, you will not be asked for a separate code."]));
body.push(P([{t:"Username and password. ",b:true},"Below the divider “or username and password”, enter your username or e-mail and your password, then select Sign in. Passwords are at least 12 characters and mix upper-case, lower-case, a digit and a special character."]));
body.push(callout("note","One message for every problem",[
  "If sign-in fails, you always see the same message — “Invalid username or password” — whether the username, the password, or something else was wrong. This is deliberate: it stops anyone probing for valid accounts."]));
body.push(H1("3. Two-factor authentication (the e-mailed code)"));
body.push(P("After your password is accepted, RTM View Shell sends a 6-digit code to your account’s e-mail and shows a “2FA · step 2 of 2” screen. Open your mailbox, read the code from the message body (the subject never contains it), and type it in."));
body.push(...bullets(["The code is valid for 10 minutes.","You have 3 attempts; after that the code is cancelled and you request a new one.","Resend is available once per minute if the code did not arrive — check spam first."]));
body.push(H1("4. Your first password change"));
body.push(P("The first time you sign in — and again whenever your password reaches its expiry (90 days by default) — you must set a new password before anything else. A live checklist turns green as you satisfy each rule:"));
body.push(...bullets(["at least 12 characters;","an upper-case letter (A–Z);","a lower-case letter (a–z);","a digit (0–9);","a special character (! @ # $ …);","and it must not match any of your last 10 passwords."]));
body.push(H1("5. If you forget your password"));
body.push(P("On the sign-in page select Forgot password?, enter your e-mail, and select Send link. If an account exists, a reset link is e-mailed (valid 24 hours). For your security the page shows the same confirmation whether or not the address is registered."));
body.push(H1("6. Finding your way around"));
body.push(P("After signing in you land on Screens — the dashboards you are allowed to see. On the left is the navigation sidebar, grouped into sections; you only see items your role and permissions allow:"));
body.push(...bullets([
 [{t:"Content",b:true}," — Screens (your dashboards) and Widget Catalogue."],
 [{t:"Administration",b:true}," — Users and Permission Groups (administrators only)."],
 [{t:"Tenant",b:true}," — Tenant Settings and Audit (administrators only)."],
 [{t:"Platform",b:true}," — Tenants (the platform Superadmin only)."]
]));
body.push(P("The four roles: a Viewer sees/opens permitted dashboards; an Editor also creates/edits dashboards; an Administrator manages users and permission groups; the Superadmin governs the whole platform. If something you expect is missing, it is almost always a permissions matter — ask your administrator."));
body.push(H1("7. Opening a dashboard"));
body.push(P("From Screens, select a dashboard card to open it. A dashboard shows live data with a “Live · update 5s” indicator; you can Pause and Resume live updates, and switch between queues using the top tabs. The full viewer is the Dashboard Viewer Guide (B-05)."));
body.push(H1("8. Your profile"));
body.push(P("From your profile you can change your password, turn two-factor on or off (unless your administrator requires it), and set your preferred language; the interface switches immediately, including right-to-left layouts. See the Profile & Settings Guide (B-04)."));
body.push(H1("9. Signing out"));
body.push(P("Use Sign out from the top bar when you finish, especially on a shared computer — it ends your session and clears your preferences from that browser."));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Sign-in troubleshooting"));
body.push(tbl(["Symptom","What it means","What to do"],[
 ["“Invalid username or password”","Username, password, or account/organisation mismatch","Re-check; if it persists, contact your administrator"],
 ["Account locked","5 failed attempts → 15-minute lockout","Wait 15 minutes, then try again"],
 ["Code did not arrive","E-mail delay or spam","Check spam; use Resend (once per minute)"],
 ["“Code expired”","More than 10 minutes passed","Request a new code and enter it promptly"],
 ["Forced password change rejected","A rule is unmet (often last-10 history)","Follow the live checklist; use a password you have not used before"]
],[2700,3300,3360],{zebra:true}));
