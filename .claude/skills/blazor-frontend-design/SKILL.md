---
name: blazor-frontend-design
invocation: user
description: >
  Apply the RTM View Shell design system to Blazor Server components.
  Trigger this skill whenever the user mentions: Blazor component styling, CSS, Bootstrap
  customisation, design tokens, color palette, typography, spacing, sidebar, topbar, modal
  styling, table styling, badge, pill, threshold colours, RTL support, dir attribute,
  CSS logical properties, Bootstrap RTL, responsive layout, dark mode stub, accessibility
  (a11y), focus ring, screen reader, ARIA, app.css, tokens.css, wwwroot, wireframe
  implementation, "make it look good", "polish the UI", "implement the login screen",
  "style the dashboard", "fix the sidebar", "add RTL", or any of the 5 project screens
  (Login/2FA, User Management, Permission Groups, Screen Management, Dashboard Viewer).
  Never skip this skill for any visual, CSS, or component styling work.
---

# Blazor Frontend Design — RTM View Shell

This skill is the single source of truth for implementing the project's design system
inside Blazor Server components. Read it before touching any CSS or layout work.

---

## 1. File map

```
wwwroot/
  css/
    app.css          ← main stylesheet; import tokens.css first
    tokens.css       ← threshold colour tokens + utility classes (already created)
  bootstrap/
    bootstrap.min.css          ← LTR build
    bootstrap.rtl.min.css      ← RTL build (download separately — see §4)
  js/
    app.js           ← minimal JS interop helpers
```

`app.css` must start with:

```css
@import url('tokens.css');
```

---

## 2. Design tokens (global CSS custom properties)

Define in `:root` inside `app.css` (not tokens.css — keep threshold tokens separate):

```css
:root {
  /* Brand */
  --color-brand-primary:   #1e3461;   /* dark navy — sidebar, primary buttons */
  --color-brand-accent:    #2e6be6;   /* blue — links, active states, focus ring */
  --color-brand-light:     #e8edf8;   /* light blue tint — hover bg in sidebar */

  /* Surface */
  --color-surface-bg:      #f4f6fb;   /* page background */
  --color-surface-card:    #ffffff;   /* card / panel background */
  --color-surface-sidebar: #1e3461;   /* sidebar background */
  --color-surface-topbar:  #ffffff;   /* top bar background */

  /* Text */
  --color-text-primary:    #1a2035;   /* headings, primary labels */
  --color-text-secondary:  #5a6478;   /* secondary labels, placeholders */
  --color-text-muted:      #a0aec0;   /* disabled, hints */
  --color-text-inverse:    #ffffff;   /* text on dark surfaces */

  /* Border */
  --color-border-default:  #dde3ee;
  --color-border-focus:    #2e6be6;   /* same as accent */

  /* Status (non-threshold — UI state only) */
  --color-success:  #28a745;
  --color-warning:  #ffc107;
  --color-danger:   #dc3545;
  --color-info:     #17a2b8;

  /* Layout */
  --sidebar-width:    220px;
  --topbar-height:    56px;
  --content-padding:  1.5rem;

  /* Radius */
  --radius-sm:  4px;
  --radius-md:  8px;
  --radius-lg:  12px;

  /* Shadow */
  --shadow-card:   0 1px 3px rgba(0,0,0,.08), 0 1px 6px rgba(0,0,0,.04);
  --shadow-modal:  0 8px 32px rgba(0,0,0,.14);

  /* Transition */
  --transition-fast:   150ms ease;
  --transition-normal: 250ms ease;
}
```

---

## 3. App.razor — locale-driven RTL and Bootstrap swap

```razor
@* src/CcDashboard.Web/Components/App.razor *@
@using System.Globalization

@{
    var culture = CultureInfo.CurrentUICulture;
    var isRtl   = culture.TextInfo.IsRightToLeft;
    var dir     = isRtl ? "rtl" : "ltr";
}

<!DOCTYPE html>
<html lang="@culture.Name" dir="@dir">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>RTM View Shell</title>

    @* Swap Bootstrap build based on text direction *@
    @if (isRtl)
    {
        <link rel="stylesheet" href="bootstrap/bootstrap.rtl.min.css" />
    }
    else
    {
        <link rel="stylesheet" href="bootstrap/bootstrap.min.css" />
    }

    <link rel="stylesheet" href="css/app.css?v=1" />
    <HeadOutlet />
</head>
<body>
    <Routes />
    <script src="_framework/blazor.web.js"></script>
    <script src="js/app.js"></script>
</body>
</html>
```

**Bootstrap RTL download:**
```
https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.rtl.min.css
→ wwwroot/bootstrap/bootstrap.rtl.min.css
```

---

## 4. CSS logical properties — RTL rule

Never use physical direction properties. Always use logical equivalents:

| Physical (forbidden) | Logical (required) |
|---|---|
| `margin-left` | `margin-inline-start` |
| `margin-right` | `margin-inline-end` |
| `padding-left` | `padding-inline-start` |
| `padding-right` | `padding-inline-end` |
| `border-left` | `border-inline-start` |
| `border-right` | `border-inline-end` |
| `left: 0` | `inset-inline-start: 0` |
| `right: 0` | `inset-inline-end: 0` |
| `text-align: left` | `text-align: start` |
| `text-align: right` | `text-align: end` |
| `float: left` | `float: inline-start` |

Bootstrap 5 utility classes that are already RTL-aware: `ms-*`, `me-*`, `ps-*`, `pe-*`, `text-start`, `text-end`.

---

## 5. MainLayout — sidebar + topbar shell

```razor
@* src/CcDashboard.Web/Components/Layout/MainLayout.razor *@
@inherits LayoutComponentBase

<div class="app-shell">
    <nav class="app-sidebar" aria-label="Main navigation">
        <NavMenu />
    </nav>

    <div class="app-main">
        <header class="app-topbar">
            <TopBar />
        </header>
        <main class="app-content" id="main-content" tabindex="-1">
            @Body
        </main>
    </div>
</div>
```

```css
/* MainLayout */
.app-shell {
  display: flex;
  min-block-size: 100vh;
  background: var(--color-surface-bg);
}

.app-sidebar {
  inline-size: var(--sidebar-width);
  flex-shrink: 0;
  background: var(--color-surface-sidebar);
  display: flex;
  flex-direction: column;
  position: sticky;
  inset-block-start: 0;
  block-size: 100vh;
  overflow-y: auto;
}

.app-main {
  flex: 1;
  min-inline-size: 0;
  display: flex;
  flex-direction: column;
}

.app-topbar {
  block-size: var(--topbar-height);
  background: var(--color-surface-topbar);
  border-block-end: 1px solid var(--color-border-default);
  display: flex;
  align-items: center;
  padding-inline: var(--content-padding);
  position: sticky;
  inset-block-start: 0;
  z-index: 100;
  box-shadow: 0 1px 3px rgba(0,0,0,.06);
}

.app-content {
  flex: 1;
  padding: var(--content-padding);
  outline: none;             /* tabindex="-1" skip-link target */
}
```

---

## 6. NavMenu — sidebar component

```css
/* Sidebar branding */
.sidebar-brand {
  padding: 1.25rem 1rem;
  border-block-end: 1px solid rgba(255,255,255,.1);
  margin-block-end: .5rem;
}

.sidebar-brand-name {
  font-size: .95rem;
  font-weight: 600;
  color: var(--color-text-inverse);
  letter-spacing: .02em;
}

/* Section labels */
.nav-section-label {
  font-size: .75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #a0b0c0;            /* override Bootstrap text-muted on dark bg */
  padding: 1rem 1rem .25rem;
  display: block;
}

/* Nav items */
.nav-item-link {
  display: flex;
  align-items: center;
  gap: .625rem;
  padding: .5rem 1rem;
  color: rgba(255,255,255,.75);
  text-decoration: none;
  border-radius: var(--radius-sm);
  margin-inline: .5rem;
  transition: background var(--transition-fast), color var(--transition-fast);
  font-size: .875rem;
}

.nav-item-link:hover {
  background: rgba(255,255,255,.08);
  color: var(--color-text-inverse);
}

.nav-item-link.active {
  background: var(--color-brand-accent);
  color: var(--color-text-inverse);
}

.nav-item-link .nav-icon {
  inline-size: 16px;
  flex-shrink: 0;
  opacity: .8;
}

/* User avatar at bottom */
.sidebar-user {
  margin-block-start: auto;
  padding: 1rem;
  border-block-start: 1px solid rgba(255,255,255,.1);
  display: flex;
  align-items: center;
  gap: .75rem;
}

.user-avatar {
  inline-size: 32px;
  block-size: 32px;
  border-radius: 50%;
  background: rgba(255,255,255,.2);
  color: var(--color-text-inverse);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: .8rem;
  font-weight: 600;
  flex-shrink: 0;
}

.sidebar-user-name {
  font-size: .8rem;
  color: rgba(255,255,255,.85);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
```

---

## 7. Page structure — standard content page pattern

```razor
<div class="page-header">
    <div>
        <h1 class="page-title">@L["Users"]</h1>
        <p class="page-subtitle">@L["ManageUsersSubtitle"]</p>
    </div>
    <div class="page-actions">
        <button class="btn btn-primary btn-sm" @onclick="OpenCreate">
            + @L["NewUser"]
        </button>
    </div>
</div>

<div class="content-card">
    @* toolbar, table, pagination *@
</div>
```

```css
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-block-end: 1.25rem;
  gap: 1rem;
  flex-wrap: wrap;
}

.page-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--color-text-primary);
  margin: 0;
}

.page-subtitle {
  font-size: .875rem;
  color: var(--color-text-secondary);
  margin: .25rem 0 0;
}

.page-actions {
  display: flex;
  gap: .5rem;
  flex-shrink: 0;
}

.content-card {
  background: var(--color-surface-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);
  border: 1px solid var(--color-border-default);
  overflow: hidden;
}
```

---

## 8. Data table styling

```css
.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: .875rem;
}

.data-table thead th {
  padding: .625rem 1rem;
  font-size: .75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: var(--color-text-secondary);
  background: #f8f9fc;
  border-block-end: 1px solid var(--color-border-default);
  white-space: nowrap;
  cursor: pointer;           /* sortable columns */
  user-select: none;
}

.data-table thead th:hover {
  background: #f0f2f8;
  color: var(--color-text-primary);
}

.data-table tbody tr {
  border-block-end: 1px solid var(--color-border-default);
  transition: background var(--transition-fast);
}

.data-table tbody tr:last-child {
  border-block-end: none;
}

.data-table tbody tr:hover {
  background: #f8f9fc;
}

.data-table td {
  padding: .75rem 1rem;
  color: var(--color-text-primary);
  vertical-align: middle;
}

/* Clickable row */
.data-table tbody tr.clickable {
  cursor: pointer;
}

/* Threshold-coloured rows (use tokens.css classes) */
/* tr.thr-ok | tr.thr-warn | tr.thr-crit | tr.thr-null */
```

---

## 9. Badges and pills

```css
/* Status pills */
.badge-active   { background: #d1fae5; color: #065f46; }
.badge-inactive { background: #f3f4f6; color: #374151; }
.badge-blocked  { background: #fee2e2; color: #991b1b; }

/* Role badges */
.badge-role-superadmin    { background: #ede9fe; color: #4c1d95; }
.badge-role-administrator { background: #dbeafe; color: #1e40af; }
.badge-role-editor        { background: #d1fae5; color: #065f46; }
.badge-role-viewer        { background: #f3f4f6; color: #374151; }

/* Common pill base */
.status-pill {
  display: inline-flex;
  align-items: center;
  padding: .2rem .625rem;
  border-radius: 999px;
  font-size: .75rem;
  font-weight: 500;
  line-height: 1.4;
  white-space: nowrap;
}

/* Threshold badges (from tokens.css) */
/* .badge-thr-ok | .badge-thr-warn | .badge-thr-crit | .badge-thr-null */
```

Razor usage:

```razor
<span class="status-pill @GetStatusClass(user.IsActive, user.IsLocked)">
    @L[user.IsActive ? "Active" : "Inactive"]
</span>

@code {
    private static string GetStatusClass(bool isActive, bool isLocked) =>
        isLocked ? "badge-blocked" :
        isActive ? "badge-active"  : "badge-inactive";
}
```

---

## 10. Modal pattern

```razor
@* Generic modal shell — use for all create/edit dialogs *@
@if (IsOpen)
{
    <div class="modal-backdrop" @onclick="OnBackdropClick" role="dialog"
         aria-modal="true" aria-labelledby="modal-title">
        <div class="modal-box @SizeClass" @onclick:stopPropagation>
            <div class="modal-header">
                <h5 class="modal-title" id="modal-title">@Title</h5>
                <button class="modal-close-btn" @onclick="Close"
                        aria-label="@L["Close"]">✕</button>
            </div>
            <div class="modal-body">
                @ChildContent
            </div>
            @if (Footer is not null)
            {
                <div class="modal-footer">
                    @Footer
                </div>
            }
        </div>
    </div>
}
```

```css
.modal-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1050;
  padding: 1rem;
  animation: backdrop-in var(--transition-fast) ease;
}

@keyframes backdrop-in {
  from { opacity: 0; }
  to   { opacity: 1; }
}

.modal-box {
  background: var(--color-surface-card);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-modal);
  inline-size: 100%;
  max-block-size: calc(100vh - 4rem);
  display: flex;
  flex-direction: column;
  animation: modal-in var(--transition-normal) ease;
}

@keyframes modal-in {
  from { transform: translateY(-12px); opacity: 0; }
  to   { transform: translateY(0);     opacity: 1; }
}

.modal-box.modal-sm { max-inline-size: 400px; }
.modal-box.modal-md { max-inline-size: 560px; }
.modal-box.modal-lg { max-inline-size: 760px; }

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.25rem 1.5rem 0;
  flex-shrink: 0;
}

.modal-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-text-primary);
  margin: 0;
}

.modal-close-btn {
  background: none;
  border: none;
  color: var(--color-text-muted);
  font-size: 1.1rem;
  cursor: pointer;
  padding: .25rem .5rem;
  border-radius: var(--radius-sm);
  transition: color var(--transition-fast), background var(--transition-fast);
}

.modal-close-btn:hover {
  color: var(--color-text-primary);
  background: var(--color-surface-bg);
}

.modal-body {
  padding: 1.25rem 1.5rem;
  overflow-y: auto;
  flex: 1;
}

.modal-footer {
  padding: .75rem 1.5rem 1.25rem;
  display: flex;
  justify-content: flex-end;
  gap: .5rem;
  flex-shrink: 0;
  border-block-start: 1px solid var(--color-border-default);
}
```

---

## 11. Form controls

```css
/* Override Bootstrap form controls to use design tokens */

.form-control,
.form-select {
  border-color: var(--color-border-default);
  border-radius: var(--radius-sm);
  font-size: .875rem;
  color: var(--color-text-primary);
  background-color: var(--color-surface-card);
  transition: border-color var(--transition-fast), box-shadow var(--transition-fast);
}

.form-control:focus,
.form-select:focus {
  border-color: var(--color-border-focus);
  box-shadow: 0 0 0 3px rgba(46,107,230,.15);
}

.form-label {
  font-size: .8125rem;
  font-weight: 500;
  color: var(--color-text-secondary);
  margin-block-end: .375rem;
}

.form-text {
  font-size: .75rem;
  color: var(--color-text-muted);
}

/* Validation states */
.form-control.is-invalid { border-color: var(--color-danger); }
.form-control.is-invalid:focus {
  box-shadow: 0 0 0 3px rgba(220,53,69,.15);
}
.invalid-feedback { font-size: .75rem; }
```

---

## 12. Button hierarchy

```
Primary action:    btn btn-primary          ← brand blue, one per form/modal
Secondary action:  btn btn-outline-secondary ← cancel, back
Danger action:     btn btn-outline-danger    ← delete (always needs confirm dialog)
Ghost/link:        btn btn-link              ← inline text actions
Icon-only:         btn btn-icon             ← toolbar icon buttons
```

```css
/* Primary — override Bootstrap to use brand colour */
.btn-primary {
  background-color: var(--color-brand-accent);
  border-color:     var(--color-brand-accent);
}
.btn-primary:hover {
  background-color: #1d58c8;
  border-color:     #1d58c8;
}

/* Icon-only button */
.btn-icon {
  inline-size: 32px;
  block-size: 32px;
  padding: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--radius-sm);
  background: none;
  border: none;
  color: var(--color-text-secondary);
  transition: background var(--transition-fast), color var(--transition-fast);
}
.btn-icon:hover {
  background: var(--color-surface-bg);
  color: var(--color-text-primary);
}
```

---

## 13. Screen-specific patterns

### Screen 01 — Login / 2FA / Change Password

```css
/* Auth page — centred card layout (no sidebar) */
.auth-page {
  min-block-size: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-surface-bg);
  padding: 1rem;
}

.auth-card {
  background: var(--color-surface-card);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-modal);
  padding: 2.5rem;
  inline-size: 100%;
  max-inline-size: 400px;
}

.auth-logo {
  text-align: center;
  margin-block-end: 2rem;
}

/* 6-box OTP input [2FA-02] */
.otp-group {
  display: flex;
  gap: .5rem;
  justify-content: center;
}

.otp-digit {
  inline-size: 48px;
  block-size: 56px;
  text-align: center;
  font-size: 1.5rem;
  font-weight: 600;
  border: 2px solid var(--color-border-default);
  border-radius: var(--radius-sm);
  transition: border-color var(--transition-fast);
}

.otp-digit:focus {
  border-color: var(--color-border-focus);
  outline: none;
  box-shadow: 0 0 0 3px rgba(46,107,230,.15);
}

/* Password rule checklist */
.pwd-rules { list-style: none; padding: 0; margin: .75rem 0 0; }
.pwd-rules li {
  font-size: .8rem;
  display: flex;
  align-items: center;
  gap: .375rem;
  color: var(--color-text-secondary);
  padding: .1rem 0;
}
.pwd-rules li.rule-ok   { color: #065f46; }
.pwd-rules li.rule-fail { color: #991b1b; }
```

### Screen 02 — User Management

Two-line user cell in table:

```css
.user-cell { display: flex; align-items: center; gap: .75rem; }
.user-cell-avatar {
  inline-size: 34px;
  block-size: 34px;
  border-radius: 50%;
  background: var(--color-brand-primary);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: .78rem;
  font-weight: 600;
  flex-shrink: 0;
}
.user-cell-name  { font-weight: 500; font-size: .875rem; line-height: 1.3; }
.user-cell-email { font-size: .78rem; color: var(--color-text-secondary); }
```

### Screen 03 — Permission Groups

Left-panel / right-panel split:

```css
.pg-shell {
  display: flex;
  gap: 1rem;
  min-block-size: calc(100vh - var(--topbar-height) - 3rem);
}

.pg-list-panel {
  inline-size: 280px;
  flex-shrink: 0;
  background: var(--color-surface-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);
  border: 1px solid var(--color-border-default);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.pg-edit-panel {
  flex: 1;
  min-inline-size: 0;
  background: var(--color-surface-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);
  border: 1px solid var(--color-border-default);
}

/* Group card in list */
.pg-card {
  padding: .75rem 1rem;
  cursor: pointer;
  border-block-end: 1px solid var(--color-border-default);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: .5rem;
  transition: background var(--transition-fast);
}
.pg-card:hover    { background: var(--color-brand-light); }
.pg-card.selected { background: var(--color-brand-light);
                    border-inline-start: 3px solid var(--color-brand-accent); }
.pg-card-name  { font-size: .875rem; font-weight: 500; }
.pg-card-count { font-size: .75rem; color: var(--color-text-secondary); }
```

### Screen 04 — Screen Management (dashboard grid)

```css
.screen-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
}

.screen-card {
  background: var(--color-surface-card);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);
  border: 1px solid var(--color-border-default);
  cursor: pointer;
  transition: box-shadow var(--transition-fast), transform var(--transition-fast);
  overflow: hidden;
}

.screen-card:hover {
  box-shadow: 0 4px 16px rgba(0,0,0,.10);
  transform: translateY(-2px);
}

.screen-card-preview {
  block-size: 120px;
  background: #f0f4fc;
  display: grid;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: 1fr 1fr;
  gap: 4px;
  padding: 8px;
}

.screen-preview-block {
  background: var(--color-brand-light);
  border-radius: 3px;
}

.screen-preview-block:first-child {
  grid-column: span 2;
  background: #d4e0f5;
}

.screen-card-body {
  padding: .75rem;
}

.screen-card-name {
  font-size: .875rem;
  font-weight: 600;
  margin-block-end: .25rem;
}

.screen-card-meta {
  font-size: .75rem;
  color: var(--color-text-secondary);
}
```

### Screen 05 — Dashboard Viewer

```css
/* Full-width viewer — no inner padding (widgets fill space) */
.viewer-shell {
  display: flex;
  flex-direction: column;
  block-size: calc(100vh - var(--topbar-height));
  overflow: hidden;
}

.viewer-topbar {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: .5rem 1.25rem;
  background: var(--color-surface-card);
  border-block-end: 1px solid var(--color-border-default);
  flex-shrink: 0;
}

.viewer-live-dot {
  inline-size: 8px;
  block-size: 8px;
  border-radius: 50%;
  background: #28a745;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50%       { opacity: .4; }
}

.viewer-queue-tabs {
  display: flex;
  gap: 0;
  border-block-end: 1px solid var(--color-border-default);
  background: var(--color-surface-card);
  overflow-x: auto;
  flex-shrink: 0;
}

.viewer-tab {
  padding: .5rem 1rem;
  font-size: .8125rem;
  border: none;
  background: none;
  color: var(--color-text-secondary);
  border-block-end: 2px solid transparent;
  white-space: nowrap;
  cursor: pointer;
  transition: color var(--transition-fast), border-color var(--transition-fast);
}

.viewer-tab:hover  { color: var(--color-text-primary); }
.viewer-tab.active {
  color: var(--color-brand-accent);
  border-block-end-color: var(--color-brand-accent);
  font-weight: 500;
}

/* Widget stub placeholder */
.widget-stub {
  background: var(--color-surface-bg);
  border: 2px dashed var(--color-border-default);
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-text-muted);
  font-size: .8rem;
  min-block-size: 120px;
}

/* Status bar */
.viewer-statusbar {
  margin-block-start: auto;
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: .25rem 1.25rem;
  background: var(--color-surface-card);
  border-block-start: 1px solid var(--color-border-default);
  font-size: .75rem;
  color: var(--color-text-secondary);
  flex-shrink: 0;
}
```

---

## 14. Accessibility requirements

```css
/* Focus ring — visible on all interactive elements */
:focus-visible {
  outline: 2px solid var(--color-brand-accent);
  outline-offset: 2px;
  border-radius: var(--radius-sm);
}
/* Remove default outline only when :focus-visible is available */
:focus:not(:focus-visible) { outline: none; }
```

ARIA patterns for Blazor:

```razor
@* Skip-link for keyboard users *@
<a href="#main-content" class="skip-link">@L["SkipToMain"]</a>

@* Sortable table header *@
<th @onclick="() => SortBy(col)"
    role="button"
    tabindex="0"
    @onkeydown="e => { if (e.Key == "Enter") SortBy(col); }"
    aria-sort="@GetAriaSortValue(col)">
    @col.Label
</th>

@* Loading state *@
@if (Loading)
{
    <div role="status" aria-live="polite" aria-label="@L["Loading"]">
        <span class="spinner-border spinner-border-sm" aria-hidden="true"></span>
    </div>
}

@* Error message *@
@if (Error is not null)
{
    <div role="alert" class="alert alert-danger">@Error</div>
}
```

```css
/* Skip-link */
.skip-link {
  position: absolute;
  inset-block-start: -100%;
  inset-inline-start: 1rem;
  background: var(--color-brand-primary);
  color: #fff;
  padding: .5rem 1rem;
  border-radius: 0 0 var(--radius-sm) var(--radius-sm);
  z-index: 9999;
  text-decoration: none;
  font-size: .875rem;
}
.skip-link:focus { inset-block-start: 0; }
```

---

## 15. Responsive breakpoints

| Breakpoint | Behaviour |
|---|---|
| `>= 1280px` | Full sidebar + content (default) |
| `768px – 1279px` | Sidebar collapses to icon-only (72px) |
| `< 768px` | Sidebar hidden; hamburger menu; Viewer is read-only [COMPAT-02] |

```css
@media (max-width: 1279px) {
  .app-sidebar {
    inline-size: 72px;
  }
  .sidebar-brand-name,
  .nav-section-label,
  .nav-item-link span,
  .sidebar-user-name {
    display: none;
  }
  .nav-item-link {
    justify-content: center;
    padding: .625rem;
    margin-inline: .25rem;
  }
}

@media (max-width: 767px) {
  .app-sidebar  { display: none; }
  .app-content  { padding: 1rem; }
}
```

---

## 16. Toast notifications

```css
.toast-container {
  position: fixed;
  inset-block-end: 1.25rem;
  inset-inline-end: 1.25rem;
  z-index: 1100;
  display: flex;
  flex-direction: column;
  gap: .5rem;
  pointer-events: none;
}

.toast-item {
  display: flex;
  align-items: center;
  gap: .75rem;
  background: var(--color-text-primary);
  color: #fff;
  padding: .75rem 1rem;
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-modal);
  font-size: .875rem;
  pointer-events: auto;
  min-inline-size: 280px;
  max-inline-size: 400px;
  animation: toast-in var(--transition-normal) ease;
}

@keyframes toast-in {
  from { transform: translateX(20px); opacity: 0; }
  to   { transform: translateX(0);    opacity: 1; }
}

.toast-item.toast-success { background: #065f46; }
.toast-item.toast-error   { background: #991b1b; }
.toast-item.toast-warning { background: #92400e; }
```

---

## 17. Toolbar pattern (search + filters + action button)

```razor
<div class="toolbar">
    <div class="toolbar-filters">
        <input class="form-control form-control-sm" type="search"
               placeholder="@L["SearchByNameEmail"]"
               @bind-value="Filter.Search" @bind-value:event="oninput" />
        <select class="form-select form-select-sm" @bind="Filter.Role">
            <option value="">@L["AllRoles"]</option>
            @foreach (var role in Roles) {
                <option value="@role">@role</option>
            }
        </select>
        <select class="form-select form-select-sm" @bind="Filter.Status">
            <option value="">@L["AllStatuses"]</option>
            <option value="active">@L["Active"]</option>
            <option value="inactive">@L["Inactive"]</option>
        </select>
    </div>
    <button class="btn btn-primary btn-sm" @onclick="OpenCreate">
        + @L["NewUser"]
    </button>
</div>
```

```css
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: .75rem;
  padding: .75rem 1rem;
  border-block-end: 1px solid var(--color-border-default);
  flex-wrap: wrap;
}

.toolbar-filters {
  display: flex;
  gap: .5rem;
  flex-wrap: wrap;
  flex: 1;
}

.toolbar-filters .form-control,
.toolbar-filters .form-select {
  inline-size: auto;
  min-inline-size: 140px;
  max-inline-size: 220px;
}
```

---

## 18. Anti-pattern table

| Anti-pattern | Why it's wrong | Correct approach |
|---|---|---|
| `margin-left` / `padding-right` | Breaks RTL layout | Use `margin-inline-start` / `padding-inline-end` |
| Hard-coded hex in CSS rules | Breaks theming, hard to maintain | Use CSS custom properties from `:root` |
| `text-align: left` | Breaks RTL | `text-align: start` |
| `position: absolute; left: 0` | Breaks RTL | `inset-inline-start: 0` |
| `text-muted` on dark sidebar | Invisible on dark background | Use `color: #a0b0c0 !important` override (nav-section-label) |
| `<MarkupString>userInput</MarkupString>` without sanitisation | XSS [CODE-02] | `HtmlEncoder.Default.Encode(userInput)` or `Ganss.Xss` |
| Inline style `color: red` for thresholds | Inconsistent, hard to change | Use `.thr-crit` / `.badge-thr-crit` from tokens.css |
| Loading all records to a `<select>` | N+1 on page load [PERF-02] | Server-side search with debounce |
| No `aria-label` on icon-only buttons | Screen reader sees nothing | Always add `aria-label="@L["Delete"]"` |
| `focus:outline: none` globally | Keyboard users lose focus indicator | Only suppress when `:focus-visible` is not active |
| Missing `role="alert"` on error messages | Screen reader misses errors | Use `role="alert"` on validation / error divs |
| Bootstrap LTR loaded for RTL locale | Layout mirrors incorrectly | Swap to `bootstrap.rtl.min.css` in App.razor based on `isRtl` |

---

## 19. Pre-commit checklist

- [ ] All physical direction properties replaced with CSS logical equivalents
- [ ] Bootstrap RTL swap implemented in `App.razor` based on `CultureInfo.CurrentUICulture.TextInfo.IsRightToLeft`
- [ ] All colours use CSS custom properties from `:root` (no raw hex in component CSS)
- [ ] Threshold colouring uses `thr-*` / `badge-thr-*` / `dot-thr-*` classes from `tokens.css`
- [ ] `:focus-visible` ring present on all interactive elements
- [ ] `aria-label` on every icon-only button
- [ ] `role="alert"` on error messages; `role="status" aria-live="polite"` on loading indicators
- [ ] No `(MarkupString)userInput` without sanitisation
- [ ] Skip-link `<a href="#main-content">` present in `MainLayout`
- [ ] `tabindex="-1"` on `<main id="main-content">` for skip-link target
- [ ] All UI strings from `.resx` via `@L["Key"]` — no hard-coded string literals
- [ ] Modals trap focus and return focus to trigger element on close
- [ ] Data tables use server-side pagination — no `ToList()` without `Take()`
- [ ] Confirmation dialog required before all destructive actions (delete, deactivate)
- [ ] Page tested at 1280px (desktop), 1024px (tablet), 375px (mobile viewer)
