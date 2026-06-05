#!/usr/bin/env python3
"""localStorage security hardening — UserId in key + clear on logout."""
import os

BASE = r"D:\Claude\Projects\RTM View Shell"

def fix_daytrendwidget():
    path = os.path.join(BASE, "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor")
    print(f"Processing {path}")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    # 1. Add inject for ICurrentUserAccessor after existing injects
    text = text.replace(
        "@inject IDbContextFactory<AppDbContext> AppDbFactory",
        "@inject IDbContextFactory<AppDbContext> AppDbFactory\n@inject CcDashboard.Domain.Interfaces.ICurrentUserAccessor CurrentUser"
    )

    # 2. Change LocalStorageKey to include UserId
    text = text.replace(
        'private string LocalStorageKey => $"cc:daytrendview:{WidgetInstanceId}";',
        'private string LocalStorageKey =>\n        $"cc:daytrendview:{CurrentUser.UserId}:{WidgetInstanceId}";'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"  Done: {original_len} -> {len(text)} bytes")

def fix_appjs():
    path = os.path.join(BASE, "src/CcDashboard.Web/wwwroot/js/app.js")
    print(f"Processing {path}")

    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    original_len = len(text)

    # Add ccApp.clearLocalStorage at the end
    new_code = '''

// localStorage security — clear all cc: prefixed keys on logout (CLAUDE.md §41)
window.ccApp = window.ccApp || {};

window.ccApp.clearLocalStorage = function () {
    const keys = Object.keys(localStorage).filter(k => k.startsWith('cc:'));
    keys.forEach(k => localStorage.removeItem(k));
    console.debug(`ccApp.clearLocalStorage: removed ${keys.length} key(s)`);
};
'''
    text = text.rstrip() + new_code

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())

    print(f"  Done: {original_len} -> {len(text)} bytes")

def fix_logoutpage():
    path = os.path.join(BASE, "src/CcDashboard.Web/Components/Auth/LogoutPage.razor")
    print(f"Processing {path}")

    new_content = '''@page "/logout"
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
'''
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
        f.flush()
        os.fsync(f.fileno())

    print(f"  Done: wrote {len(new_content)} bytes")

if __name__ == "__main__":
    fix_daytrendwidget()
    fix_appjs()
    fix_logoutpage()
    print("\nAll files updated!")
