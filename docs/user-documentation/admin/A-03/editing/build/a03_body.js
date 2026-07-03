body.push(H1("1. How access works"));
body.push(P("Every user except the Superadmin belongs to exactly one permission group (PG). The group, not the user, carries the access rules; to change what a user can reach you change their group, or move them to a different one. The Superadmin bypasses all permission-group checks and has full access across every tenant."));
body.push(P("Two principles to fix in mind:"));
body.push(...bullets([
 [{t:"Most-permissive wins.",b:true}," Where rules could combine, a user’s effective access is the union of what their group grants — access is never reduced by adding a grant."],
 [{t:"The backend enforces, not the UI.",b:true}," Hiding a menu item is cosmetic. Every restriction here is also checked in the application on every request, so a user cannot reach restricted data by guessing a URL or calling the API directly."]
]));
body.push(P("Permission groups are managed on the Permission Groups screen (/admin/permission-groups): a list of groups on the left, an editor with five tabs on the right."));
body.push(H1("2. Creating, editing and deleting a group"));
body.push(P([{t:"Create",b:true}," a group with “New group”, give it a name (unique within your organisation) and an optional description, and mark it active. ",{t:"Edit",b:true}," by selecting its card and adjusting the tabs, then saving. A group can be made inactive without deleting it."]));
body.push(P([{t:"Delete",b:true}," is only allowed when no users are assigned; if any are, the delete control is disabled and tells you how many users must be moved first. Saving a change refreshes the group’s cached permissions immediately; live sessions pick it up on their next action."]));
body.push(callout("note","Concurrency",["If two administrators edit the same group at once, the second save is rejected with “Record modified by another user”. Reload and reapply."]));
body.push(H1("3. The Menu tab — which sections appear"));
body.push(P("The Menu tab controls which navigation items the group’s users see. Some items are inherently limited to certain roles regardless of the group:"));
body.push(tbl(["Menu item","Permission key","Available to roles"],[
 ["Dashboards / Screens","menu.dashboards","All"],["User Management","menu.users","Superadmin, Administrator"],
 ["Permission Groups","menu.permissionGroups","Superadmin, Administrator"],["Widget Catalogue","menu.widgetCatalog","Superadmin, Administrator, Editor"],
 ["Audit","menu.audit","Superadmin, Administrator"],["Tenant Settings","menu.tenantSettings","Superadmin, Administrator"],
 ["Tenant Management","menu.tenants","Superadmin only"]
],[2700,2900,3760],{zebra:true,codeCols:[1]}));
body.push(P("Rows that do not apply to the group’s role are greyed out. The menu only governs visibility — the screens are still protected by the tabs below and by the backend."));
body.push(H1("4. The Screens tab — dashboard access"));
body.push(P("The Screens tab gives each group three independent permissions — View, Edit, Delete — via checkboxes:"));
body.push(tbl(["Permission","Meaning"],[["View","Open and read the dashboard"],["Edit","Change it (implies View)"],["Delete","Remove it (implies View)"],["Full","View + Edit + Delete"]],[3000,6360],{zebra:true}));
body.push(P("When a user creates a dashboard, their own group is granted Full on it automatically. A dashboard also appears to a user if it is marked public, unless the group is explicitly denied."));
body.push(H1("5. The resource tabs — Queues, Skills, BU / SG"));
body.push(P("The remaining tabs restrict the contact-centre resources whose data the group may see: Queues, Skills, Business Units and Agent Supergroups. Each is a list you add allowed items to."));
body.push(callout("warn","An empty list means access is denied, not allowed",["If a group’s Queues tab is empty, the group sees no queues — not all of them. To grant access you add the specific items. This is the safe default: a new or misconfigured group exposes nothing until you deliberately grant it."]));
body.push(P("Business Units and Agent Supergroups share one tab and scope a group’s view of the organisation — e.g. limiting a regional team to its own business unit. As with menus, these limits are enforced in the application layer, not merely the UI."));
body.push(H1("6. Worked example — read-only sales supervisors"));
body.push(...nums(["Create the group “Sales Floor Supervisors”, active.","Menu tab: leave Dashboards visible; admin-only items stay greyed out.","Screens tab: tick View (not Edit or Delete) on each sales dashboard.","Queues tab: add the specific sales queues — and nothing else.","BU / SG tab: add the Sales business unit.","Save. Assign supervisors to this group in User Management (A-02)."]));
body.push(P("The supervisors now see exactly the sales dashboards and queues, read-only — and the backend enforces it even against a crafted direct request."));
body.push(new Paragraph({ children:[new PageBreak()] }));
body.push(H1("Appendix A — Menu keys and role limits"));
body.push(P("See §3. Menu visibility is necessary but never sufficient — the Screens and resource tabs plus the backend check are what protect data."));
body.push(H1("Appendix B — Dashboard access levels"));
body.push(P("View = read · Edit = change (implies View) · Delete = remove (implies View) · Full = View+Edit+Delete. A dashboard’s creator group receives Full automatically. Public dashboards are visible to all tenant users unless a group is explicitly denied."));
body.push(H1("Appendix C — Resource-tab rule"));
body.push(P("For Queues, Skills, Business Units and Agent Supergroups: an empty list denies all of that type; grants are explicit additions; enforcement is in the application layer. Editing a group refreshes its cached permissions immediately for live sessions."));
