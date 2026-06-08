---
name: ux-ui-expert
invocation: user
description: >
  Apply UX/UI design expertise to the RTM View Shell (CC Dashboard Shell) project.
  Trigger this skill whenever the user mentions: user experience, information architecture,
  interaction design, form UX, error states, empty states, loading states, feedback patterns,
  toast notifications, confirmation dialogs, destructive actions, onboarding, navigation patterns,
  data tables UX, filter and search UX, dashboard layout, card design, status indicators,
  live data display, contact centre metrics UX, operator experience, real-time monitoring UX,
  permission management UX, user management UX, multi-step flows, progressive disclosure,
  micro-interactions, visual hierarchy, colour usage, iconography, button design, badge design,
  responsive UX, mobile UX, keyboard navigation UX, focus management UX, or screen flow design.
  Also trigger on: "how should this look", "is this good UX", "make it more intuitive",
  "improve usability", "user doesn't understand", "confusing UI", "what's the best way to show",
  "design the flow for", "what should happen when", or any request to improve a specific screen.
  Never skip this skill when designing screen flows, interaction patterns, or error/empty states.
---

# UX/UI Expert — RTM View Shell

This skill guides all UX and interaction design decisions in the **CC Dashboard Shell**.
The primary users are **contact centre supervisors and administrators** — they work in
high-pressure environments, often on 1280×768 monitors, watching multiple screens simultaneously.
Good UX here means: fast, dense, scannable, predictable, and forgiving.

---

## 0. Before designing anything — know the users

**Primary users:**
- **Supervisor / Viewer** — watches live dashboards, reads queue data, monitors agents. No admin access.
- **Editor** — creates and manages screens/dashboards. May manage own team's view.
- **Administrator** — manages users, permission groups, tenant settings. Tech-savvy, not a developer.
- **Superadmin** — platform-level operator. Manages all tenants. Power user.

**Environment:**
- Often multiple monitors; shell is one of several windows open
- 1280×768 minimum resolution [COMPAT-02]
- Time-pressured: they need to find information in under 3 seconds
- Not always their primary language (RTL locales: Arabic, Hebrew, Farsi) [I18N-02]

**Design principle:** reduce cognitive load. Show the user only what they need for their current task.

---

## 1. Information hierarchy — visual priority rules

Every screen must have exactly one **primary action** (the thing most users came to do).

| Priority | Element | Treatment |
|---|---|---|
| Primary | The main CTA button | `btn-primary`, always visible, right-aligned in toolbar or modal footer |
| Secondary | Supporting actions | `btn-secondary` or `btn-outline-secondary` |
| Destructive | Delete, deactivate, revoke | `btn-danger`, always in a separate "Danger zone" section with confirmation |
| Passive | Cancel, back | `btn-outline-secondary` or text link |

**Button order in modals and forms:**
```
[Cancel]  [Primary action →]
```
Cancel on the left, primary action on the right. Never reverse this.
Primary action label must describe the outcome: "Create user →", "Save changes →", "Delete screen".

---

## 2. Loading states

Never show a blank space while loading. Every async operation needs feedback.

### Page / section loading
```razor
@if (_loading)
{
    <div class="d-flex align-items-center gap-2 py-4 text-muted" aria-busy="true" aria-live="polite">
        <div class="spinner-border spinner-border-sm" aria-hidden="true"></div>
        <span>@L["Loading"]</span>
    </div>
}
else if (_items?.Count == 0)
{
    <EmptyState ... />
}
else
{
    <DataTable ... />
}
```

### Inline button loading (form submit)
Use `AppButton Loading="_saving"` — shows spinner inside button, disables it.
The button label stays visible next to the spinner; do not replace it with "Loading...".

### Table skeleton (preferred for list pages)
Show 5 placeholder rows with `placeholder` CSS class while loading:
```html
<tr aria-hidden="true">
    <td><span class="placeholder col-6"></span></td>
    <td><span class="placeholder col-4"></span></td>
    <td><span class="placeholder col-3"></span></td>
</tr>
```

---

## 3. Empty states

Empty states must explain why it's empty and what to do next.

```razor
@* Components/Shared/EmptyState.razor *@
<div class="text-center py-5" role="status">
    <div class="mb-3 opacity-50">
        @* Bootstrap Icons SVG — relevant to context *@
        <svg width="48" height="48">...</svg>
    </div>
    <h3 class="h5 text-muted mb-2">@Title</h3>
    <p class="text-muted small mb-4">@Description</p>
    @if (OnAction.HasDelegate)
    {
        <AppButton Variant="primary" OnClick="OnAction">@ActionLabel</AppButton>
    }
</div>
```

| Context | Title | Description | Action |
|---|---|---|---|
| User list, no users | "No users yet" | "Add your first user to get started." | "New user" |
| PG list, no groups | "No permission groups" | "Create a group to control what users can access." | "New group" |
| Dashboard list, no screens | "No screens yet" | "Create a screen and add widgets to monitor your contact centre." | "+ New screen" |
| Search returns nothing | "No results for "{query}"" | "Try different keywords or clear the filter." | "Clear search" |
| Queue tab empty | "No queues assigned" | "This group has no queue access. Empty list = access denied." | — |

---

## 4. Error states

### Inline field validation
Show errors below the field, in red, linked via `aria-describedby`:
```html
<input class="form-control is-invalid" aria-describedby="email-error" />
<div class="invalid-feedback" id="email-error">
    Email address is already in use within this tenant.
</div>
```

### Form-level errors (save failed)
Show a dismissible alert above the submit button — not a toast (user must acknowledge):
```razor
@if (_saveError is not null)
{
    <div class="alert alert-danger d-flex align-items-center gap-2" role="alert">
        <svg aria-hidden="true">...</svg>
        <div>@_saveError</div>
        <button type="button" class="btn-close ms-auto"
                @onclick="() => _saveError = null"
                aria-label="@L["Dismiss"]"></button>
    </div>
}
```

### Concurrency conflict
Show a specific message — never a generic "Something went wrong":
> "This record was modified by another user while you were editing. Please reload and try again."
With a "Reload" button that re-fetches the record.

### Network / circuit error
SignalR reconnecting: show a non-blocking banner at the top:
```
⚠  Connection lost — reconnecting... [Reload page]
```
Use `position: sticky; top: 0` so it stays visible regardless of scroll position.

---

## 5. Confirmation dialogs — when and how

### When to require confirmation
| Action | Confirmation required | Type |
|---|---|---|
| Delete user | ✅ Yes | Modal dialog |
| Deactivate user | ✅ Yes | Modal dialog |
| Delete permission group | ✅ Yes | Modal dialog with user count |
| Delete screen (dashboard) | ✅ Yes [DASH-03] | Modal dialog |
| Force logout user | ✅ Yes | Inline confirm (2-step button) |
| Reset password (sends email) | ❌ No | Direct action + toast |
| Save user edits | ❌ No | Direct action + toast |
| Block user | ✅ Yes | Inline confirm |

### Confirmation modal pattern
```
┌─────────────────────────────────────────┐
│  Delete "Agent Monitor" screen?         │
│                                         │
│  This action cannot be undone.          │
│  The screen will be permanently deleted │
│  along with its widget layout.          │
│                                         │
│           [Cancel]  [Delete screen]     │
└─────────────────────────────────────────┘
```
- Title: verb + object ("Delete X?") — never just "Are you sure?"
- Body: what will be lost, whether it's reversible
- Destructive button: `btn-danger`, label matches the action ("Delete screen", not "OK")
- Default focus: Cancel button (safe default)
- Close on Escape → Cancel (not Delete)

### Inline 2-step confirm (for compact UX)
```razor
@if (!_confirmingDelete)
{
    <button class="btn btn-sm btn-outline-danger"
            @onclick="() => _confirmingDelete = true">
        Delete
    </button>
}
else
{
    <span class="text-danger small me-2">Sure?</span>
    <button class="btn btn-sm btn-danger" @onclick="DoDelete">Yes, delete</button>
    <button class="btn btn-sm btn-link" @onclick="() => _confirmingDelete = false">Cancel</button>
}
```

---

## 6. Toast / notification system

Use toasts for **non-critical, reversible confirmations** — things that succeeded or that the user doesn't need to act on.

| Use toast for | Do NOT use toast for |
|---|---|
| "User created successfully" | Errors that require action |
| "Password reset email sent" | Concurrency conflicts |
| "Permissions saved" | Destructive confirmation |
| "Group deactivated" | Critical system errors |

```
Position: bottom-end (bottom-right in LTR, bottom-left in RTL)
Duration:  4 seconds auto-dismiss
Max stack: 3 toasts visible at once
```

```razor
@* Components/Shared/ToastContainer.razor *@
<div class="toast-container position-fixed bottom-0 end-0 p-3" aria-live="polite">
    @foreach (var toast in _toasts)
    {
        <div class="toast show align-items-center border-0
                    @(toast.IsError ? "bg-danger text-white" : "bg-success text-white")"
             role="status" aria-atomic="true">
            <div class="d-flex">
                <div class="toast-body">@toast.Message</div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto"
                        @onclick="() => Dismiss(toast)"
                        aria-label="@L["Close"]"></button>
            </div>
        </div>
    }
</div>
```

---

## 7. Data tables — UX rules

Contact centre admins manage hundreds of users. Tables must be fast to scan.

### Column design
- **User column:** avatar initial (coloured circle) + display name in medium weight + email in muted small text — two-line cell.
- **Status column:** pill badge, always coloured. Never plain text.
- **Date column:** relative time ("2 hours ago") with absolute in tooltip on hover. Or formatted absolute (`dd MMM yyyy HH:mm`) for audit log.
- **Actions column:** icon buttons (`btn-sm btn-icon`), right-aligned, hidden behind hover if space is tight.
- **Boolean column** (e.g. 2FA enabled): checkmark icon (✓) for true, dash (–) for false. Never "Yes/No" text.

### Sorting
- Click column header → sort ascending; click again → descending; third click → unsorted.
- Show sort indicator: ↑ / ↓ in the column header.
- Sort indicator must be visually distinct but not the main focus.

### Filtering toolbar
```
[Search input          🔍] [Role ▾] [Group ▾] [Status ▾]  ·  [+ New user]
```
- Search input: debounce 300ms; `placeholder` = "Search by name or email...".
- Dropdowns: show selected value; show "All roles" / "All groups" as default.
- Active filters: show a count badge ("Filters: 2") or pill tags that can be dismissed.
- "Clear all filters" link appears only when at least one filter is active.

### Row interaction
- Entire row is **not** a link — only explicit action buttons/links. Accidental clicks on rows that navigate are frustrating.
- Hover state: subtle background (`var(--clr-overlay)`), no dramatic change.
- Selected row (when relevant): `var(--clr-primary-subtle)` background + left border in `var(--clr-primary)`.

---

## 8. Sidebar navigation UX

```
┌─────────────────────┐
│  CC Dashboard       │   ← product name / logo
├─────────────────────┤
│  CONTENT            │   ← section label (uppercase, muted, small)
│  ○ Screens          │   ← NavLink with icon
│  ○ Widget Catalogue │
├─────────────────────┤
│  ADMINISTRATION     │
│  ● Users            │   ← active (primary colour, bold)
│  ○ Perm. Groups     │
├─────────────────────┤
│  SYSTEM             │
│  ○ Settings         │
│  ○ Audit            │
│  ○ Tenants          │   ← only for Superadmin
└─────────────────────┘
│  [avatar] Max F.    │   ← user panel at bottom
│  Administrator      │
│  [Logout]           │
└─────────────────────┘
```

**Rules:**
- Active item: `var(--clr-primary)` text, `var(--clr-primary-subtle)` background, `4px` left border.
- Hide menu items the user has no `menu.*` permission for (cosmetic only — backend also checks).
- Section labels: uppercase, `var(--clr-text-faint)`, `font-size: var(--text-xs)`, `letter-spacing: 0.05em`.
- Sidebar width: `220px` fixed. Collapsible to `60px` (icon-only) at ≤1400px.

---

## 9. Screen 01 — Login UX decisions

**SSO button first** (prominent) — most enterprise users will use SSO. Local login is fallback.

**OTP input UX:**
- 6 separate single-character inputs (one per digit).
- Auto-advance to next input on digit entry.
- Auto-submit on last digit entry.
- Backspace on empty input focuses previous.
- Paste of 6-digit string fills all boxes at once.

```razor
@* 6-box OTP — JS interop required for auto-advance *@
<div class="d-flex gap-2" role="group" aria-label="@L["OtpCode"]">
    @for (int i = 0; i < 6; i++)
    {
        var idx = i;
        <input type="text" inputmode="numeric" maxlength="1"
               class="form-control text-center fw-bold fs-4"
               style="width: 48px; height: 56px;"
               @ref="_otpRefs[idx]"
               @oninput="e => OnOtpInput(idx, e)" />
    }
</div>
```

**Password rules checklist:** Show live validation ticks while typing (not just on submit).
Green tick = rule met, red cross = rule not met. Never hide the rules — they reduce friction.

**"Forgot password?" flow:** Uniform response ("If this email exists, you'll receive a link")
regardless of whether the email is registered [BFP-03]. Show it as a calm info alert, not an error.

---

## 10. Screen 02 — User Management UX decisions

**Create user modal — progressive disclosure:**
- Show `PermissionGroupId` dropdown only when Role ≠ Superadmin.
- Show a helper note: "A temporary password will be emailed to the user."
- Do not ask for a password — it's auto-generated [USR-03].

**Edit user modal — section grouping:**
```
Basic info:     First name, Last name, Email, Username
Account:        Role, Permission Group, Status toggle, 2FA toggle
Security:       [Reset password →]  [Force logout →]
Danger zone:    [Delete user]
```
Visually separate sections with a light divider or section heading.

**"Force logout" as an inline confirm** (2-step), not a modal — the consequence is recoverable.
**"Delete user" always as a modal** — irreversible.

**Status badge design:**

| Status | Background | Text | Meaning |
|---|---|---|---|
| active | `--clr-success-subtle` | `--clr-success` | User can log in |
| inactive | `--clr-overlay` | `--clr-text-muted` | User blocked |
| blocked | `--clr-danger-subtle` | `--clr-danger` | Auto-locked (BFP) |

---

## 11. Screen 03 — Permission Groups UX decisions

**Split-pane layout:** Group list on the left (fixed ~280px), edit panel on the right (fills remaining).
On mobile/narrow: accordion (list collapses, opens panel full-width).

**Group list card:**
```
┌──────────────────────────────────┐
│  Sales Team             [3 users]│  ← name + user count badge
│  Queues: Sales, Support          │  ← first 2-3 resource names
│  ● Active                        │  ← status dot
└──────────────────────────────────┘
```

**"Delete group" button states:**
- Has 0 users → enabled, triggers confirmation modal.
- Has ≥1 users → disabled with tooltip: "Cannot delete: 3 users assigned. Reassign them first." [PG-06]

**Empty resource tabs (Queues / Skills / BU):**
Show an amber warning banner, not just empty state:
> ⚠ Empty list = access denied. This group cannot see any queues. [PG-03]

**Dual-pane selector for adding resources:**
```
┌─────────────────┐   ┌─────────────────┐
│  Available      │   │  Assigned       │
│  ─────────────  │   │  ─────────────  │
│  □ Sales        │ → │  ✓ Support      │
│  □ Tech Support │ ← │  ✓ Billing      │
│  □ Complaints   │   │                 │
└─────────────────┘   └─────────────────┘
          [Add selected →]  [← Remove]
```

---

## 12. Screen 04 — Dashboard Management UX decisions

**Grid vs List toggle:** Default is grid (cards). List view for admins who manage many screens.

**Screen card design:**
```
┌─────────────────────────────┐
│  ┌──┬──┐  ┌──┬──┐          │  ← widget placeholder grid
│  └──┴──┘  └──┴──┘          │     (grey blocks, no real data)
│  ┌──────────────┐           │
│  └──────────────┘           │
├─────────────────────────────┤
│  Agent Monitor        ✦ ✎   │  ← name + quick actions (star, edit)
│  Sales · Support      ●pub  │  ← groups + status badge
└─────────────────────────────┘
```

**"+ New screen" placement:** Top-right of toolbar, always visible. Primary button style.

**IsPublic checkbox UX:**
- Label: "Visible to all users in this tenant"
- When checked: show info note "This screen will be visible to all authenticated users, regardless of their permission group."
- When unchecked: show "Only visible to assigned groups."

**Widget category chips (create modal):**
- Show chips as a multi-select group.
- Selected chips: filled/coloured background.
- Chips are purely informational in v1 (stub) — add note: "Widget layout is configured in the screen editor after creation."

---

## 13. Screen 05 — Dashboard Viewer UX decisions

**Live indicator:** Blinking green dot + "Live · 5s" in top bar. Accessible alternative: `aria-label="Live data, updating every 5 seconds"`.

**Pause/Resume toggle:** Icon button + label. When paused: amber static badge "Paused", live dot disappears. Useful for supervisors taking a screenshot or comparing data.

**Queue filter tabs:**
- "All queues" tab is always first.
- Per-queue tabs come from user's `pg_queues` list.
- If many queues (>6): show first 5 + "More ▾" dropdown.
- Active tab: bottom border in `var(--clr-primary)`, 2px.

**Widget stub placeholder:**
```
┌─────────────────────────────────┐
│                                 │
│   [widget icon]                 │
│   Queue Summary                 │
│   Widget available in next      │  ← friendly message, not "TODO"
│   version of this dashboard.    │
│                                 │
└─────────────────────────────────┘
```
Use muted colours. Never show raw `// TODO: widget-library` text to the user.

**Status bar (bottom):**
```
Blazor Server · SignalR ●connected     18ms     Max F.
```
- `●connected` = green dot. `●reconnecting` = amber dot. `●disconnected` = red dot.
- Latency: show only if >100ms (otherwise it's noise). When showing, amber >300ms, red >1000ms.

---

## 14. Responsive behaviour

| Breakpoint | Behaviour |
|---|---|
| ≥1280px | Full layout: sidebar expanded + content |
| 1024–1279px | Sidebar collapsed to icons (60px), tooltip on hover shows label |
| 768–1023px | Sidebar hidden, top nav hamburger menu |
| <768px | Viewer-only read mode [COMPAT-02]; admin pages show a banner: "Admin features require a wider screen." |

**Critical:** Never break the dashboard viewer below 768px — supervisors may use tablets.

---

## 15. Micro-interactions and feedback

| Interaction | Feedback |
|---|---|
| Save succeeds | Green toast bottom-right, 4s auto-dismiss |
| Save fails | Inline red alert above submit button (sticky) |
| Row deleted | Row fades out (150ms) before being removed from DOM |
| Item added to list | Row slides in from top, briefly highlighted in `--clr-primary-subtle` |
| Status toggled | Badge animates colour change (150ms transition) |
| Connection lost | Amber banner appears at top, non-blocking |
| Connection restored | Banner auto-hides after 3s |
| Permission denied | Red toast "You don't have permission to do this." |

All animations guarded with `@media (prefers-reduced-motion: reduce)` — skip to final state instantly.

---

## 16. Writing for the UI — tone and microcopy

| Situation | ✅ Good | ❌ Avoid |
|---|---|---|
| Empty state | "No users yet. Add the first one." | "No records found." |
| Delete confirm | "Delete 'Sales Team' group?" | "Are you sure?" |
| Error | "Email already in use in this tenant." | "Error 400: Validation failed." |
| Success | "User created. A temporary password was sent to their email." | "Success." |
| Loading | "Loading users…" | Blank / spinner with no text |
| Permission denied | "You don't have access to this feature." | "403 Forbidden" |
| Forced password change | "Your password has expired. Please set a new one to continue." | "MustChangePasswordAt is set." |
| Uniform login error [BFP-03] | "Invalid username or password." | "User not found." / "Wrong password." |

**Rules:**
- Sentence case for all UI text (not Title Case).
- Active voice: "Saving…" not "Being saved…".
- Short: if it takes more than 10 words to explain an action, reconsider the design.
- Never expose internal IDs, stack traces, or technical field names in user-facing messages.
- All text through `IStringLocalizer` [I18N-03].

---

## 17. Accessibility UX

- **Error announcement:** Use `role="alert"` on error containers so screen readers announce immediately.
- **Success announcement:** Use `aria-live="polite"` on toast container.
- **Loading:** `aria-busy="true"` on loading containers.
- **Focus trap in modals:** Tab cycles within modal; Escape closes.
- **Skip links:** Provide "Skip to main content" link as first focusable element on each page.
- **Icon-only buttons:** Always `aria-label` that describes the action ("Edit user Max F.", not "Edit").
- **Status badges:** Don't rely on colour alone — include text label inside the badge.
- **Data tables:** `<th scope="col">` on all headers; `<th scope="row">` on row headers.

---

## Pre-commit UX checklist

- [ ] Every async operation has a loading state
- [ ] Every list page has an empty state with context-appropriate message and CTA
- [ ] All errors shown inline (field errors) or in dismissible alert (form-level errors)
- [ ] Destructive actions require confirmation dialog; delete button labeled with action + subject
- [ ] Success feedback via toast; error feedback via inline alert (not toast)
- [ ] Confirmation dialog default focus is Cancel (safe default)
- [ ] Escape closes modals
- [ ] Microcopy follows tone guide (sentence case, active voice, no tech jargon)
- [ ] Status badges use both colour AND text (not colour alone)
- [ ] Live indicators use `aria-label` in addition to visual dot
- [ ] All animations guarded with `prefers-reduced-motion`
- [ ] Widget stubs show friendly placeholder text, not raw TODO comments
