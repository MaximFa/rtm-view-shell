body.push(H1("1. Where your settings live"));
body.push(P("Your personal settings are reached from your profile, opened from your name in the top bar. From there you can change your password, control two-factor authentication, and set your preferred language. These choices affect only your own account. Your role, permission group and active status are controlled by an administrator — ask them if any of those need to change."));
body.push(H1("2. Changing your password"));
body.push(P("Select Change password, then enter your current password followed by your new password twice. A live checklist turns green as you meet each rule:"));
body.push(...bullets(["at least 12 characters (your organisation may require more);","an upper-case letter (A–Z);","a lower-case letter (a–z);","a digit (0–9);","a special character (! @ # $ …);","and it must be different from your last 10 passwords."]));
body.push(P("Passwords expire periodically (90 days by default); you are asked to set a new one at sign-in. A strong, unique password you do not use elsewhere is the single most important protection for the account."));
body.push(callout("note","If you have forgotten your current password",["You cannot change it here — sign out and use Forgot password? on the sign-in page for an e-mailed reset link."]));
body.push(H1("3. Two-factor authentication (2FA)"));
body.push(P("Two-factor adds a second check: after your password, a 6-digit code is e-mailed to you. From your profile you can turn 2FA on or off — unless your administrator has made it mandatory for everyone, in which case the toggle is fixed on. Leaving 2FA on is strongly recommended. The code is valid 10 minutes, allows 3 attempts, and can be resent once per minute; it is only ever in the e-mail body."));
body.push(H1("4. Choosing your language"));
body.push(P("Set your preferred language from the profile. The interface switches immediately, without a reload, and is remembered. Any language can be offered; Arabic, Hebrew and Farsi flip the whole layout right-to-left. Dates, times and numbers follow your language, and the 2FA / password-reset e-mails arrive in it."));
body.push(H1("5. Appearance"));
body.push(P("Where enabled, you may see presentation options such as font size and colour, drawn from the set your administrator made available. These change how dashboards look for you and have no effect on data or permissions."));
body.push(H1("6. A note on shared computers"));
body.push(P("On a shared or public computer, always use Sign out when you finish rather than closing the tab. Signing out ends your session and clears your saved preferences from that browser."));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Settings quick reference"));
body.push(tbl(["Setting","Where","Notes"],[
 ["Password","Profile → Change password","12+ chars, mixed; not your last 10; expires ~90 days"],
 ["Two-factor authentication","Profile → 2FA toggle","E-mailed 6-digit code; may be mandatory (toggle fixed on)"],
 ["Language","Profile → preferred language","Switches immediately; RTL for Arabic/Hebrew/Farsi; sets e-mail language"],
 ["Appearance","Profile (if enabled)","Font size / colour from the administrator’s set"],
 ["Forgotten password","Sign-in page → Forgot password?","Reset link by e-mail (not changeable inside the app)"]
],[2900,3000,3460],{zebra:true}));
