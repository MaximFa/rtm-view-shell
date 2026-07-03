body.push(H1("1. What you can do here"));
body.push(P("Info Slots let you put short written messages on contact-centre dashboards in real time — a shift note, a service alert, a reminder. You write the messages; they appear immediately inside the Info Slot widget on every dashboard that shows that slot, and disappear when you remove them or they expire. The Info Slots themselves are created by an administrator (Info Slot Administration Guide, A-08); this guide is about writing and managing the messages."));
body.push(P([{t:"Where: ",b:true},"message management is at /info-slots."]));
body.push(H1("2. Which Info Slots you can write to"));
body.push(P("You see and can write to an Info Slot only if your permission group has been granted access; Administrators and the Superadmin can write to all. The page lists the Info Slots available to you as cards showing the slot’s name, its display mode, how many messages are active, and which dashboards it appears on. Select “Manage messages” on a slot to work with its messages."));
body.push(H1("3. Adding a message"));
body.push(P("In Manage messages, select “+ Add Message” and fill in:"));
body.push(...bullets([
 [{t:"Content",b:true}," — the message text (required)."],
 [{t:"Priority",b:true}," — Normal or High. High-priority messages are shown first and can be styled to stand out."],
 [{t:"Expires At",b:true}," — an optional date/time after which the message removes itself; tick “Never expires” to leave it up until you remove it."]
]));
body.push(P("Submit and the message appears on the dashboards straight away — adding it is publishing it."));
body.push(H1("4. Editing and removing messages"));
body.push(P("Each active message shows its priority, author, time, content and expiry. Use the pencil to edit a message inline and Save; use deactivate to take it down."));
body.push(callout("note","What you may edit",["Viewers and Editors can edit and remove their own messages only — the pencil is hidden on others’ messages. Administrators and the Superadmin can edit or remove any message. Only one message is edited at a time."]));
body.push(H1("5. Ticker or Sequential — the display mode"));
body.push(P("From Manage messages you can switch the slot between Ticker (messages scroll continuously) and Sequential (one at a time, auto-advancing every few seconds — minimum 3). Switching takes effect on every dashboard showing the slot in real time. In both modes, High-priority messages are shown first."));
body.push(H1("6. How expiry works"));
body.push(P("A message with an expiry time is removed automatically when that time passes — you need not come back to take it down. A message with “Never expires” stays until someone deactivates it. This makes it safe to post time-bound notices and trust them to clear themselves."));
body.push(H1("7. Worked example"));
body.push(...nums([
 "Open /info-slots and select Manage messages on the relevant Info Slot.",
 "Select “+ Add Message”.",
 "Content: “Payments system degraded — expect delays.” Priority: High. Expires At: today 15:00.",
 "Submit — the notice appears at the front of the slot on every dashboard showing it.",
 "At 15:00 it disappears on its own; no follow-up needed."
]));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Message quick reference"));
body.push(tbl(["You want to…","Do this"],[
 ["Write a message","Manage messages → + Add Message → Content, Priority, Expires At → Submit"],
 ["Make it stand out","Set Priority = High (shown first)"],
 ["Have it clear itself","Set Expires At; otherwise tick Never expires"],
 ["Change a message","Pencil → edit inline → Save (own messages; admins any)"],
 ["Take one down","Deactivate (own messages; admins any)"],
 ["Change scrolling vs one-at-a-time","Toggle Ticker / Sequential in Manage messages"]
],[3500,5860],{zebra:true}));
