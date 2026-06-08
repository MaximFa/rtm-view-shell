---
name: frontend-design
invocation: user
description: >
  Apply modern frontend best practices to the RTM View Shell (Blazor Server) project.
  Trigger this skill whenever the user mentions: creating Blazor components, CSS, styling,
  design system, design tokens, layouts, themes, color palette, typography, spacing, RTL
  support, accessibility (a11y), responsive design, wireframe implementation, UI polish,
  visual consistency, Bootstrap customisation, or any screen described in CLAUDE.md §21.
  Also trigger on: "make it look good", "fix the UI", "add dark mode", "style this",
  "implement the login screen", "create the user management page", or any reference to
  wireframes in wireframes/en/. Never skip this skill for any visual or component work —
  it ensures the project's design system, RTL support, and accessibility are applied consistently.
---

# Frontend Design — RTM View Shell

This skill guides implementation of all UI/frontend work in the **CC Dashboard Shell**
Blazor Server project. Read it in full before writing any `.razor` or `.css` file.

---

## 0. Before writing any code — read context

1. **Read `CLAUDE.md`** (especially §21 Wireframes, §22 i18n). Understand the screen you're building.
2. Open the relevant wireframe: `wireframes/en/0N_*.html` — inspect field names, labels, modal structure, and requirement IDs (e.g. `[DASH-01]`).
3. If `docs/frontend.md` exists, read it for project-specific overrides.
4. **Never overwrite `CLAUDE.md`**. To record a frontend decision, append a `## 29. Frontend conventions` section at the bottom or update `docs/frontend.md`.

---

## 1. Stack and technology choices

| Concern | Choice |
|---|---|
| CSS framework | Bootstrap 5.3+ with RTL build (`bootstrap.rtl.min.css`) |
| Custom styles | CSS custom properties (design tokens) in `wwwroot/css/tokens.css` |
| Icons | Bootstrap Icons SVG sprite (no external CDN) |
| JS | Blazor JS interop only — no React, Vue, or bundled SPA |
| Fonts | System font stack — no Google Fonts (external CDN blocked per DEPLOY-08) |
| Animations | Always guarded with `@media (prefers-reduced-motion: reduce)` |
| Scoped styles | `ComponentName.razor.css` (Blazor CSS isolation) for component-level rules |

---

## 2. Design token system

All visual constants live in `wwwroot/css/tokens.css`. Import it first in `app.css` before Bootstrap. **Never hardcode a colour, size, or spacing value outside this file.**

```css
/* wwwroot/css/tokens.css */
:root {
  /* ── Brand colours ─────────────────────────── */
  --clr-primary:        #185FA5;
  --clr-primary-hover:  #125088;
  --clr-primary-subtle: #E6F1FB;
  --clr-danger:         #A32D2D;
  --clr-danger-subtle:  #FCEBEB;
  --clr-success:        #3B6D11;
  --clr-success-subtle: #EAF3DE;
  --clr-warning:        #854F0B;
  --clr-warning-subtle: #FAEEDA;

  /* ── Neutrals ───────────────────────────────── */
  --clr-bg:        #F5F5F3;   /* page background   */
  --clr-surface:   #FAFAF9;   /* card / sidebar    */
  --clr-overlay:   #EBEBEA;   /* hover, dividers   */
  --clr-text:      #1A1A1A;
  --clr-text-muted:#666666;
  --clr-text-faint:#AAAAAA;
  --clr-border:    rgba(0,0,0,.10);
  --clr-border-md: rgba(0,0,0,.18);

  /* ── Typography ─────────────────────────────── */
  --font: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  --text-xs:   11px;
  --text-sm:   12px;
  --text-base: 13px;   /* shell default — compact UI */
  --text-md:   14px;
  --text-lg:   15px;
  --text-xl:   16px;
  --text-2xl:  18px;
  --fw-normal: 400;
  --fw-medium: 500;
  --fw-bold:   600;

  /* ── Spacing (4 px grid) ─────────────────────── */
  --sp-1: 4px;   --sp-2: 8px;   --sp-3: 12px;
  --sp-4: 16px;  --sp-5: 20px;  --sp-6: 24px;
  --sp-8: 32px;  --sp-10: 40px; --sp-12: 48px;

  /* ── Radii ───────────────────────────────────── */
  --r-sm: 4px;  --r-md: 8px;  --r-lg: 12px;  --r-pill: 9999px;

  /* ── Shadows ─────────────────────────────────── */
  --shadow-sm: 0 1px 3px rgba(0,0,0,.08);
  --shadow-md: 0 4px 16px rgba(0,0,0,.10);
  --shadow-lg: 0 8px 32px rgba(0,0,0,.12);

  /* ── Focus ring ──────────────────────────────── */
  --focus-ring: 0 0 0 3px rgba(24,95,165,.22);

  /* ── Transitions ─────────────────────────────── */
  --dur-fast: 100ms;  --dur-normal: 150ms;  --dur-slow: 250ms;
  --ease-out: cubic-bezier(0,0,.2,1);
}

/* Dark mode */
@media (prefers-color-scheme: dark) {
  :root {
    --clr-bg:        #1A1A18;
    --clr-surface:   #222220;
    --clr-overlay:   #2C2C2A;
    --clr-text:      #F0F0EE;
    --clr-text-muted:#999999;
    --clr-border:    rgba(255,255,255,.10);
    --clr-border-md: rgba(255,255,255,.20);
    --clr-primary-subtle: #1A3A5C;
  }
}

/* Reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 1ms !important;
    transition-duration: 1ms !important;
  }
}
```

---

## 3. RTL / LTR — CSS logical properties

This project supports RTL locales (Arabic, Hebrew, Farsi) per [I18N-02].
`MainLayout.razor` sets `dir="rtl"` or `dir="ltr"` on `<html>` based on `PreferredLocale`.

Bootstrap 5 RTL build is loaded conditionally:
```razor
@* MainLayout.razor *@
<link rel="stylesheet" href="@(IsRtl ? "css/bootstrap.rtl.min.css" : "css/bootstrap.min.css")" />
```

**Mandatory: always use CSS logical properties.**

| ❌ Forbidden (physical) | ✅ Required (logical) |
|---|---|
| `margin-left / margin-right` | `margin-inline-start / margin-inline-end` |
| `padding-left / padding-right` | `padding-inline-start / padding-inline-end` |
| `border-left / border-right` | `border-inline-start / border-inline-end` |
| `left: 0 / right: 0` | `inset-inline-start: 0 / inset-inline-end: 0` |
| `text-align: left` | `text-align: start` |
| `float: left / right` | `float: inline-start / inline-end` |

---

## 4. Blazor component patterns

### File organisation
```
src/CcDashboard.Web/Components/
  Shared/          # Atoms: Button, Badge, Modal, DataTable, Spinner, Pagination
  Layout/          # AppShell, NavMenu, TopBar, StatusBar
  Auth/            # LoginPage, TwoFactorPage, PasswordChangePage, ResetPasswordPage, SsoCallback
  Dashboard/       # ScreenList, ScreenCard, CreateScreenModal, EditScreenModal, DashboardViewer
  Admin/           # UserAdmin, UserCreateModal, UserEditModal
                   # GroupAdmin, GroupEditPanel, MenuPermTab, ScreenPermTab, QueuePermTab
                   # AuditLog, TenantSettings
  Widgets/         # WidgetCategoryBrowser, WidgetPicker  (stub — // TODO: widget-library)
```

### Razor component rules
- Use `[Parameter(CaptureUnmatchedValues = true)]` on shared atoms — it forwards `aria-*`,
  `data-*`, `id`, etc. to the root element without extra parameters.
- Use `EventCallback<T>` (not `Action<T>`): integrates with Blazor's change detection and
  correctly marshals async continuations on the circuit thread.
- Never call `StateHasChanged()` inside an async method without wrapping in `InvokeAsync()`.
- Use `@key` on list items to preserve DOM state across re-renders.
- Inject `IStringLocalizer<T>` for every user-visible string — hard-coded text is forbidden [I18N-03].
- Set `@rendermode InteractiveServer` only on components that truly need server interactivity;
  leave static sections (headers, nav) without it to reduce circuit overhead.

### Shared Button atom
```razor
@* Components/Shared/AppButton.razor *@
<button class="btn btn-@Variant @(Loading ? "btn-loading" : "") @Class"
        disabled="@(Disabled || Loading)"
        type="@Type"
        @onclick="OnClick"
        @attributes="Extra">
    @if (Loading)
    {
        <span class="spinner-border spinner-border-sm" aria-hidden="true"></span>
    }
    @ChildContent
</button>

@code {
    [Parameter] public RenderFragment? ChildContent { get; set; }
    [Parameter] public string Variant { get; set; } = "secondary";
    [Parameter] public string Type   { get; set; } = "button";
    [Parameter] public bool Disabled { get; set; }
    [Parameter] public bool Loading  { get; set; }
    [Parameter] public string? Class { get; set; }
    [Parameter] public EventCallback OnClick { get; set; }
    [Parameter(CaptureUnmatchedValues = true)]
    public Dictionary<string, object>? Extra { get; set; }
}
```

---

## 5. Navigation sidebar — structure

All screens share the same sidebar, driven by `menu.*` permission claims (never hardcode role names in Razor):

```
Content
  Screens               → /screens           (menu.dashboards — all roles)
  Widget Catalogue      → /widgets           (menu.widgetCatalog — Admin, Editor, SA)
Administration
  Users                 → /admin/users       (menu.users — Admin, SA)
  Permission Groups     → /admin/perm-groups (menu.permissionGroups — Admin, SA)
System / Tenant
  Tenant Settings       → /admin/settings    (menu.tenantSettings — Admin, SA)
  Audit                 → /admin/audit       (menu.audit — Admin, SA)
  Tenants               → /admin/tenants     (menu.tenants — SA only)
```

Use `IPermissionService.HasMenuAccess(menuKey)` to drive `NavLink` visibility.

---

## 6. Status badges and role colours

Define once in `wwwroot/css/badges.css`, use everywhere:

```css
.badge-published { background: var(--clr-success-subtle); color: var(--clr-success); }
.badge-draft     { background: var(--clr-warning-subtle); color: var(--clr-warning); }
.badge-active    { background: var(--clr-success-subtle); color: var(--clr-success); }
.badge-inactive  { background: var(--clr-overlay);        color: var(--clr-text-muted); }
.badge-blocked   { background: var(--clr-danger-subtle);  color: var(--clr-danger); }

/* Role badges */
.role-sa    { background: #F0E8FF; color: #5C2D91; }  /* Superadmin */
.role-admin { background: var(--clr-primary-subtle); color: var(--clr-primary); }
.role-editor{ background: #E8F4EE; color: #1A5E38; }
.role-viewer{ background: var(--clr-overlay); color: var(--clr-text-muted); }
```

---

## 7. Accessibility — WCAG 2.2 AA baseline

- **Focus management:** opening a modal → focus moves to its first focusable element.
  Closing → focus returns to the trigger element. Use `@ref` + `IJSRuntime.InvokeVoidAsync("focusElement", ref)`.
- **Keyboard:** `Escape` closes modals and dropdowns. Arrow keys navigate dropdown lists.
- **ARIA:** every icon-only button needs `aria-label`. Modals need `role="dialog"`,
  `aria-modal="true"`, `aria-labelledby` pointing at the modal `<h2>`.
- **Colour contrast:** all text/background pairs from the token system are pre-validated at 4.5:1+.
- **Loading states:** use `aria-busy="true"` on containers that are loading.
- **Forms:** every `<input>` paired with `<label for="">`. Validation errors linked via `aria-describedby`.

```razor
@* Pattern: accessible modal *@
<div role="dialog" aria-modal="true" aria-labelledby="modal-@Id-title"
     tabindex="-1" @ref="_dialogRef">
    <h2 id="modal-@Id-title">@Title</h2>
    @ChildContent
</div>
```

---

## 8. Implementing a screen from wireframes — checklist

When asked to implement any of the 5 application screens:

1. Open `wireframes/en/0N_*.html` — note all field names, labels, hints, requirement IDs
2. Map UI elements to Blazor components and permission checks (§5)
3. Write `.razor` + scoped `.razor.css`
4. Wire `IStringLocalizer` for every displayed string
5. Add `[Authorize(Policy = "...")]` on the page component
6. Log `Dashboard.Viewed` (or relevant) audit event via `IAuditService` on page load [AUD-*]
7. Write a unit test for non-trivial display logic

---

## 9. CLAUDE.md — safe extension rule

If you discover a convention worth persisting for future sessions, **append only**:

```markdown
@* At the end of CLAUDE.md — never modify §1–§28 *@

## 29. Frontend conventions (frontend-design skill)
- Tokens: wwwroot/css/tokens.css
- RTL: CSS logical properties + conditional Bootstrap RTL build
- Components: src/CcDashboard.Web/Components/
- Accessibility baseline: WCAG 2.2 AA
```

---

## Pre-commit checklist

- [ ] All colours/sizes via `var(--token)` — no hardcoded values
- [ ] Logical CSS properties — no `margin-left/right`
- [ ] `aria-label` on icon-only buttons; `role="dialog"` on modals
- [ ] `[Authorize]` on every route component
- [ ] All strings through `IStringLocalizer`
- [ ] `@rendermode InteractiveServer` only where needed
- [ ] Tested at 768 px width
- [ ] Dark mode: tokens correctly override in `prefers-color-scheme: dark`
- [ ] Animations guarded with `prefers-reduced-motion`
