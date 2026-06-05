# CC Task: localStorage security hardening — userId in key + clear on logout

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Context

CLAUDE.md §41 defines localStorage security policy for contact centre environments
(shared workstations). Two mandatory measures:
1. UserId in key — prevents cross-user data leakage
2. Clear all cc: keys on logout — data must not survive the session

---

## Change 1 — DayTrendWidget.razor: add UserId to localStorage key

### 1a — Add inject

After existing `@inject` lines, add:
```razor
@inject CcDashboard.Domain.Interfaces.ICurrentUserAccessor CurrentUser
```

### 1b — Change LocalStorageKey property

Find:
```csharp
private string LocalStorageKey => $"cc:daytrendview:{WidgetInstanceId}";
```

Replace with:
```csharp
private string LocalStorageKey =>
    $"cc:daytrendview:{CurrentUser.UserId}:{WidgetInstanceId}";
```

`CurrentUser.UserId` is type `Guid?` — use `.ToString()` implicitly via string interpolation.
If `CurrentUser.UserId` is null (unauthenticated), the key becomes `cc:daytrendview::{id}` —
acceptable since unauthenticated users cannot access View Mode.

---

## Change 2 — wwwroot/js/app.js (or site.js): add clearLocalStorage helper

Find the main JS file in `src/CcDashboard.Web/wwwroot/js/` (likely `app.js` or `site.js`).
If it doesn't exist, create `src/CcDashboard.Web/wwwroot/js/app.js`.

Add this function:

```javascript
window.ccApp = window.ccApp || {};

window.ccApp.clearLocalStorage = function () {
    const keys = Object.keys(localStorage).filter(k => k.startsWith('cc:'));
    keys.forEach(k => localStorage.removeItem(k));
    console.debug(`ccApp.clearLocalStorage: removed ${keys.length} key(s)`);
};
```

If `app.js` is new, also add a `<script>` reference in
`src/CcDashboard.Web/Components/App.razor` (or wherever scripts are loaded):
```html
<script src="js/app.js"></script>
```

---

## Change 3 — LogoutPage.razor: clear localStorage before sign-out

File: `src/CcDashboard.Web/Components/Auth/LogoutPage.razor`

Current content:
```razor
@page "/logout"
@inject IIdentityAuthService AuthService
@inject NavigationManager Nav
@using CcDashboard.Application.Interfaces

@code {
    [CascadingParameter] public HttpContext? HttpContext { get; set; }

    protected override async Task OnInitializedAsync()
    {
        if (HttpContext is not null)
            await AuthService.SignOutAsync();

        Nav.NavigateTo("/login?info=You+have+been+signed+out.", forceLoad: true);
    }
}
```

Replace with:
```razor
@page "/logout"
@inject IIdentityAuthService AuthService
@inject NavigationManager Nav
@inject IJSRuntime JS
@using CcDashboard.Application.Interfaces

@code {
    [CascadingParameter] public HttpContext? HttpContext { get; set; }

    protected override async Task OnInitializedAsync()
    {
        // Clear all application localStorage keys before sign-out (§41.4)
        try { await JS.InvokeVoidAsync("ccApp.clearLocalStorage"); }
        catch { /* JS may not be available in SSR context — safe to ignore */ }

        if (HttpContext is not null)
            await AuthService.SignOutAsync();

        Nav.NavigateTo("/login?info=You+have+been+signed+out.", forceLoad: true);
    }
}
```

---

## Change 4 — Commit CLAUDE.md (§41 already written by Cowork)

Stage `CLAUDE.md` along with the code changes.

---

## Verification

```bash
# 1. Key includes UserId
grep -n "LocalStorageKey" src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
# Must show: CurrentUser.UserId in the string

# 2. Logout clears storage
grep -n "clearLocalStorage" src/CcDashboard.Web/Components/Auth/LogoutPage.razor
# Must show: ccApp.clearLocalStorage call

# 3. JS function exists
grep -n "clearLocalStorage" src/CcDashboard.Web/wwwroot/js/app.js
# Must show: function definition
```

---

## Implementation steps

1. Read skill files
2. `git status --short` + integrity check
3. Apply changes via Python atomic write + fsync (Edit tool BANNED)
4. `dotnet build CcDashboard.sln` — 0 errors
5. `bash tools/pre-commit-check.sh`
6. Commit: `security: localStorage keys scoped by UserId + clear on logout (CLAUDE.md §41)`
7. Re-sync from HEAD

---

## Re-sync block (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Components/Auth/LogoutPage.razor" \
  "src/CcDashboard.Web/wwwroot/js/app.js" \
  "CLAUDE.md"; do
  [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
