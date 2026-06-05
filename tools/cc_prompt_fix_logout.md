# CC Task: Fix LogoutPage — remove IJSRuntime from SSR page (causes startup failure on IIS)

## Git push
Do NOT run `git push`. Commit only.

---

## Step 0 — Mandatory integrity check (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f — restoring"
        git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== OK ==="
```

---

## Problem

`LogoutPage.razor` is an SSR page (`[CascadingParameter] HttpContext`).
`@inject IJSRuntime JS` was added to it — this is incompatible with SSR mode
and causes startup failures on IIS with certain Blazor Server configurations.

## Fix — `src/CcDashboard.Web/Components/Auth/LogoutPage.razor`

Replace entire file content with:

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

Note: localStorage clear on logout will be implemented differently
(client-side JS in App.razor on navigation, not via Blazor interop in SSR context).

---

## Implementation steps

1. `git status --short` + integrity check (Step 0)
2. Python atomic write + fsync (Edit BANNED)
3. `dotnet build CcDashboard.sln` — 0 errors
4. `bash tools/pre-commit-check.sh`
5. Commit: `fix: remove IJSRuntime from SSR LogoutPage (caused IIS startup failure)`
6. Re-sync from HEAD

---

## Re-sync

```bash
git show HEAD:"src/CcDashboard.Web/Components/Auth/LogoutPage.razor" \
  > "src/CcDashboard.Web/Components/Auth/LogoutPage.razor"
sync
```
