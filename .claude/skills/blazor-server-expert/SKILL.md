---
name: blazor-server-expert
invocation: user
description: >
  Apply Blazor Server best practices to the RTM View Shell project.
  Trigger this skill whenever the user mentions: Blazor components, Razor files (.razor),
  SignalR circuits, component lifecycle, StateHasChanged, EventCallback, cascading parameters,
  render modes, InteractiveServer, SSR, form handling, validation, @formname, AntiforgeryToken,
  JS interop, IJSRuntime, ElementReference, component parameters, @ref, @key, DI in Blazor,
  scoped services, circuit-scoped state, NavigationManager, AuthenticationStateProvider,
  Authorize attribute in Blazor, Blazor routing, NavLink, InputText, EditForm,
  DataAnnotationsValidator, custom validators, modal dialogs, tabs, pagination components,
  real-time updates via SignalR, SignalR reconnect, circuit handlers, CascadingAuthenticationState,
  IStringLocalizer in Blazor, Blazor localization, or any component listed in CLAUDE.md §3/§21.
  Also trigger on: "component not updating", "StateHasChanged not working", "circuit error",
  "blazor form", "modal in blazor", "how to pass data between components", "inject in razor".
  Never skip this skill for any Blazor component work.
---

# Blazor Server Expert — RTM View Shell

This skill covers all Blazor Server patterns, gotchas, and component conventions for the
**CC Dashboard Shell** project. Read it in full before creating or modifying any `.razor` file.

---

## 0. Before writing any component — read context

1. **Read `CLAUDE.md` §21** — identify which screen you're building; open the wireframe.
2. **Read the `frontend-design` skill** for design tokens, RTL rules, and WCAG requirements.
3. **Read `CLAUDE.md` §3** — confirm the correct folder under `Components/`.
4. Decide render mode: SSR or `@rendermode InteractiveServer` (see §2 below).

---

## 1. Blazor Server fundamentals — project rules

| Rule | Detail |
|---|---|
| Circuit model | Each connected browser tab = one SignalR circuit on the server |
| Services in Blazor | Use `Scoped` for circuit-lifetime state; `Singleton` for shared (Redis-backed) |
| Never `.Result` / `.Wait()` | All async calls must use `await`; blocking deadlocks the circuit |
| `StateHasChanged()` | Only call from UI thread; wrap with `InvokeAsync` from background threads |
| `@key` directive | Always on list items (`@foreach`) to preserve DOM identity across re-renders |
| `IDisposable` | Implement on components that subscribe to events, timers, or channels |
| `CancellationToken` | Use `ComponentBase.CancellationToken` (from `CancellationTokenSource` in `Dispose`) |

---

## 2. Render mode — choosing correctly

```
SSR (no @rendermode)          → Auth pages (/login, /forgot-password), static content
@rendermode InteractiveServer → Any page with user interaction (admin pages, modals, forms)
```

**SSR pages** use `@formname` + `<AntiforgeryToken />` for form handling (Blazor 8 enhanced forms).
They do NOT have a SignalR circuit — no `StateHasChanged`, no JS interop on load.

**InteractiveServer pages** have a full circuit. Use for:
- All Admin screens (User Management, Permission Groups)
- Dashboard list, Screen management
- Widget catalogue browser

**Never** put `@rendermode InteractiveServer` on layout components (`MainLayout`, `NavMenu`)
unless absolutely necessary — it increases circuit count.

### SSR form example (Login page)

```razor
@page "/login"
@* No @rendermode — SSR for clean form POST *@

<form method="post" @formname="login-form">
    <AntiforgeryToken />
    <input type="text" name="Input.UserName" />
    <input type="password" name="Input.Password" />
    <button type="submit">@L["SignIn"]</button>
</form>

@code {
    [SupplyParameterFromForm]
    public LoginInputModel Input { get; set; } = new();

    private async Task OnValidSubmit()
    {
        // Called on POST — no circuit needed
    }
}
```

---

## 3. Component lifecycle — correct order

```
SetParametersAsync      ← parameters injected; called before OnInitialized
OnInitialized(Async)    ← one-time setup; load initial data here
OnParametersSet(Async)  ← called when parent re-renders with new parameters
OnAfterRender(Async)    ← DOM is ready; use for JS interop and focus management
ShouldRender            ← return false to skip re-render (performance optimisation)
IDisposable.Dispose     ← cancel timers, unsubscribe events, cancel tokens
```

### Data loading pattern

```csharp
private IReadOnlyList<UserDto>? _users;
private bool _loading = true;
private string? _error;

protected override async Task OnInitializedAsync()
{
    try
    {
        _users = await sender.Send(new GetUsersQuery(), _cts.Token);
    }
    catch (Exception ex)
    {
        _error = ex.Message;
        logger.LogError(ex, "Failed to load users");
    }
    finally
    {
        _loading = false;
    }
}
```

Use `aria-busy="true"` on the container while `_loading = true`.

---

## 4. StateHasChanged — rules

```csharp
// ✅ Called from UI event (button click, EventCallback) — no wrapper needed
private async Task OnButtonClick()
{
    await DoWork();
    // Blazor auto-calls StateHasChanged after EventCallback completes
}

// ✅ Called from background thread / timer / SignalR message
private async Task OnSignalRMessage(string data)
{
    _data = data;
    await InvokeAsync(StateHasChanged);  // REQUIRED when called off the UI thread
}

// ❌ Wrong — will throw if called from non-UI thread
private void OnTimerElapsed(object? state)
{
    _counter++;
    StateHasChanged();  // Can throw — use InvokeAsync instead
}
```

---

## 5. EventCallback vs Action

| | `EventCallback<T>` | `Action<T>` |
|---|---|---|
| Blazor change detection | ✅ Triggers automatically | ❌ Must call StateHasChanged manually |
| Async support | ✅ Returns `Task` | ❌ Sync only (or `Func<T, Task>`) |
| Thread marshalling | ✅ Automatic | ❌ Manual InvokeAsync needed |
| Use case | All Blazor component callbacks | Never — use EventCallback |

**Always use `EventCallback<T>` for component parameter callbacks.**

```razor
@* Child component *@
<button @onclick="() => OnItemSelected.InvokeAsync(Item)">Select</button>

@code {
    [Parameter] public UserDto Item { get; set; } = null!;
    [Parameter] public EventCallback<UserDto> OnItemSelected { get; set; }
}
```

---

## 6. Form handling with EditForm + FluentValidation

```razor
<EditForm Model="_model" OnValidSubmit="HandleSubmit">
    <FluentValidationValidator />   @* nuget: Blazored.FluentValidation *@
    <ValidationSummary />

    <div class="mb-3">
        <label for="firstName" class="form-label">@L["FirstName"]</label>
        <InputText id="firstName" class="form-control"
                   @bind-Value="_model.FirstName"
                   aria-describedby="firstNameValidation" />
        <ValidationMessage For="@(() => _model.FirstName)"
                           id="firstNameValidation" />
    </div>

    <AppButton Type="submit" Variant="primary" Loading="_saving">
        @L["Save"]
    </AppButton>
</EditForm>

@code {
    private readonly CreateUserModel _model = new();
    private bool _saving;

    private async Task HandleSubmit()
    {
        _saving = true;
        try
        {
            await sender.Send(new CreateUserCommand(_model.FirstName, ...));
            Nav.NavigateTo("/admin/users");
        }
        finally { _saving = false; }
    }
}
```

**Rules:**
- Pair every `<InputText>` with `<label for="">` (accessibility).
- Link `<ValidationMessage>` via `aria-describedby`.
- Disable submit button while `_saving = true` (use `AppButton Loading="_saving"`).

---

## 7. Modal pattern — standard implementation

All modals share the same state pattern. Never use JS-based Bootstrap modal JS API —
control visibility through Blazor state only.

```razor
@* In parent page *@
@if (_editUser is not null)
{
    <UserEditModal User="_editUser"
                   OnSaved="OnUserSaved"
                   OnCancelled="CloseEditModal" />
}

@code {
    private UserDto? _editUser;

    private void OpenEditModal(UserDto user)
    {
        _editUser = user;
    }

    private async Task OnUserSaved()
    {
        CloseEditModal();
        await LoadUsers();  // refresh list
    }

    private void CloseEditModal() => _editUser = null;
}
```

```razor
@* UserEditModal.razor *@
<div class="modal-backdrop fade show"></div>
<div class="modal fade show d-block"
     role="dialog"
     aria-modal="true"
     aria-labelledby="modal-edit-user-title"
     tabindex="-1"
     @ref="_dialogRef">

    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h2 class="modal-title fs-5" id="modal-edit-user-title">
                    @L["EditUser"]
                </h2>
                <button type="button" class="btn-close"
                        @onclick="OnCancelled"
                        aria-label="@L["Close"]"></button>
            </div>
            <div class="modal-body">
                @* form here *@
            </div>
        </div>
    </div>
</div>

@code {
    [Parameter] public UserDto User { get; set; } = null!;
    [Parameter] public EventCallback OnSaved { get; set; }
    [Parameter] public EventCallback OnCancelled { get; set; }

    private ElementReference _dialogRef;

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            // Move focus to dialog on open (WCAG 2.2)
            await JS.InvokeVoidAsync("focusElement", _dialogRef);
        }
    }
}
```

**Keyboard:** `Escape` key closes modal — add `@onkeydown` on the outer div or handle in JS interop.

---

## 8. Server-side pagination pattern

```razor
@* Reusable pagination state — keep in parent component *@
@code {
    private int _pageIndex = 0;
    private int _pageSize = 25;
    private int _totalCount;
    private IReadOnlyList<UserDto> _items = [];

    private async Task LoadPage()
    {
        var result = await sender.Send(
            new GetUsersQuery(PageIndex: _pageIndex, PageSize: _pageSize),
            _cts.Token);
        _items = result.Items;
        _totalCount = result.TotalCount;
    }

    private async Task OnPageChanged(int newPage)
    {
        _pageIndex = newPage;
        await LoadPage();
    }

    private async Task OnPageSizeChanged(int newSize)
    {
        _pageSize = newSize;
        _pageIndex = 0;
        await LoadPage();
    }
}
```

**Rules [PERF-02]:**
- Never load all records — always `PageIndex + PageSize` in the query.
- Pass `CancellationToken` to cancel in-flight requests on rapid page changes.
- Show `aria-busy="true"` on table container while loading.

---

## 9. Tabs pattern

```razor
@code {
    private string _activeTab = "menu";
}

<ul class="nav nav-tabs" role="tablist">
    @foreach (var tab in new[] { "menu", "screens", "queues", "skills", "bu-sg" })
    {
        <li class="nav-item" role="presentation">
            <button class="nav-link @(_activeTab == tab ? "active" : "")"
                    role="tab"
                    aria-selected="@(_activeTab == tab)"
                    @onclick="() => _activeTab = tab">
                @L[$"Tab_{tab}"]
            </button>
        </li>
    }
</ul>

<div class="tab-content mt-3" role="tabpanel">
    @if (_activeTab == "menu")   { <MenuPermTab Group="_group" /> }
    @if (_activeTab == "screens") { <ScreenPermTab Group="_group" /> }
    @* ... *@
</div>
```

---

## 10. Real-time updates via SignalR

The dashboard viewer receives live data updates. Implement via `HubConnection` inside the component.

```csharp
// Components/Dashboard/DashboardViewer.razor.cs
private HubConnection? _hub;
private bool _paused;

protected override async Task OnInitializedAsync()
{
    _hub = new HubConnectionBuilder()
        .WithUrl(Nav.ToAbsoluteUri("/hubs/dashboard"))
        .WithAutomaticReconnect()          // [REL-01]
        .Build();

    _hub.On<DashboardUpdateDto>("Update", async update =>
    {
        if (_paused) return;
        _latestData = update;
        await InvokeAsync(StateHasChanged);   // Off UI thread — must use InvokeAsync
    });

    _hub.Closed += async _ =>
    {
        _connectionStatus = "Disconnected";
        await InvokeAsync(StateHasChanged);
    };

    _hub.Reconnected += async _ =>
    {
        _connectionStatus = "Connected";
        await InvokeAsync(StateHasChanged);
    };

    await _hub.StartAsync(_cts.Token);
}

public async ValueTask DisposeAsync()
{
    _cts.Cancel();
    if (_hub is not null) await _hub.DisposeAsync();
}
```

**Hub authentication — mandatory [ARCH-09]:**
```csharp
// Hubs/DashboardHub.cs
[Authorize]
public class DashboardHub(ICurrentUserAccessor currentUser) : Hub
{
    public override async Task OnConnectedAsync()
    {
        // Verify TenantId from ClaimsPrincipal before adding to group
        var tenantId = currentUser.TenantId
            ?? throw new HubException("Tenant not resolved.");

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            $"t:{tenantId}:dashboard");  // [ARCH-09]

        await base.OnConnectedAsync();
    }
}
```

---

## 11. JS interop — safe patterns

```csharp
// Focus element (used in modal open/close)
await JS.InvokeVoidAsync("focusElement", elementRef);

// Check if element is visible (pagination / infinite scroll)
var isVisible = await JS.InvokeAsync<bool>("isElementVisible", elementRef);
```

Add the interop functions to `wwwroot/js/app.js`:
```javascript
window.focusElement = (element) => {
    if (element) element.focus();
};
window.isElementVisible = (element) => {
    if (!element) return false;
    const rect = element.getBoundingClientRect();
    return rect.top >= 0 && rect.bottom <= window.innerHeight;
};
```

**Rules:**
- Only call JS interop in `OnAfterRenderAsync` or event handlers — never in `OnInitializedAsync` (DOM not ready).
- JS interop fails silently when the circuit is disconnected — always try/catch.
- Never pass sensitive data (tokens, passwords) through JS interop.

---

## 12. Dependency injection in Blazor

```razor
@* In .razor file — inject at top, before @code block *@
@inject ISender Sender
@inject NavigationManager Nav
@inject IStringLocalizer<SharedResources> L
@inject ILogger<UserAdmin> Logger
@inject AuthenticationStateProvider AuthStateProvider
@inject IJSRuntime JS
```

```csharp
// In code-behind (.razor.cs) — constructor injection preferred
public partial class UserAdmin(
    ISender sender,
    NavigationManager nav,
    IStringLocalizer<SharedResources> localizer,
    ILogger<UserAdmin> logger
)
{
    // ...
}
```

**Service lifetime rules in Blazor Server:**
| Lifetime | Use for |
|---|---|
| `Scoped` | Circuit-lifetime state (one instance per browser tab). DB context, current user, tenant context. |
| `Singleton` | Shared across all circuits. Redis cache, widget catalogue (read-only). |
| `Transient` | Stateless utilities. Avoid in components — creates a new instance per injection. |

---

## 13. Authorization in Blazor

```razor
@* Page-level authorization *@
@attribute [Authorize(Roles = "Superadmin,Administrator")]
@page "/admin/users"
@rendermode InteractiveServer

@* Conditional rendering by permission *@
<AuthorizeView Roles="Superadmin,Administrator">
    <Authorized>
        <button @onclick="OpenCreateModal">@L["NewUser"]</button>
    </Authorized>
</AuthorizeView>

@* Permission-based (custom policy) *@
<AuthorizeView Policy="CanEditDashboard">
    <Authorized Context="authCtx">
        <button>@L["Edit"]</button>
    </Authorized>
</AuthorizeView>
```

**Forced redirect on unauthorized:**
```csharp
// In App.razor — wrap routes with CascadingAuthenticationState
<CascadingAuthenticationState>
    <Router AppAssembly="typeof(App).Assembly">
        <Found Context="routeData">
            <AuthorizeRouteView RouteData="routeData"
                                DefaultLayout="typeof(MainLayout)">
                <NotAuthorized>
                    @if (!context.User.Identity?.IsAuthenticated ?? true)
                    {
                        <RedirectToLogin />
                    }
                    else
                    {
                        <p>@L["AccessDenied"]</p>
                    }
                </NotAuthorized>
            </AuthorizeRouteView>
        </Found>
    </Router>
</CascadingAuthenticationState>
```

---

## 14. Localisation in Blazor

```razor
@inject IStringLocalizer<SharedResources> L

<h1>@L["UserManagement"]</h1>
<p>@L["UserCount", _totalCount]</p>  @* Formatted: "Total users: 42" *@
```

```csharp
// Resources/SharedResources.resx  (en-US)
// UserManagement = User Management
// UserCount      = Total users: {0}

// Resources/SharedResources.ru-RU.resx
// UserManagement = Управление пользователями
// UserCount      = Всего пользователей: {0}
```

**Rules [I18N-03]:**
- Every user-visible string through `@L["Key"]` — no hardcoded text.
- Start all resource keys with an uppercase letter (English and Russian).
- Date/time via `@user.LastLoginAt?.ToString("g", CultureInfo.CurrentUICulture)`.
- RTL: `dir` set on `<html>` in `App.razor` from `CultureInfo.CurrentUICulture.TextInfo.IsRightToLeft`.

---

## 15. Circuit handler — session invalidation

Register a `CircuitHandler` to handle forced logouts when a user is deactivated. [USR-09]

```csharp
// Web/Services/AuthCircuitHandler.cs
public class AuthCircuitHandler(
    IConnectionMapping connectionMapping,
    ILogger<AuthCircuitHandler> logger
) : CircuitHandler
{
    private string? _circuitId;

    public override Task OnConnectionUpAsync(Circuit circuit, CancellationToken ct)
    {
        _circuitId = circuit.Id;
        connectionMapping.Add(circuit.Id, /* userId from auth state */);
        return Task.CompletedTask;
    }

    public override Task OnConnectionDownAsync(Circuit circuit, CancellationToken ct)
    {
        if (_circuitId is not null)
            connectionMapping.Remove(_circuitId);
        return Task.CompletedTask;
    }
}
```

To terminate a specific user's circuit (force logout):
```csharp
// Send a SignalR message to the user's circuit; component listens and calls Nav.NavigateTo("/login")
await hubContext.Clients
    .Group($"t:{tenantId}:user:{userId}")
    .SendAsync("ForceLogout", ct);
```

---

## 16. Common Blazor mistakes — anti-pattern table

| ❌ Anti-pattern | ✅ Correct approach |
|---|---|
| `StateHasChanged()` from background thread | `await InvokeAsync(StateHasChanged)` |
| `@onclick="SomeAsyncMethod"` without `async Task` | Always `async Task`, never `void` |
| Injecting `DbContext` directly in component | Inject `ISender` or `IXxxService` |
| `action.Result` inside Blazor async method | `await action` |
| Missing `@key` on list items | Add `@key="item.Id"` to each item |
| `OnAfterRenderAsync` called once but firstRender ignored | Guard JS interop with `if (firstRender)` |
| No `IDisposable` on component with subscriptions | Always implement `IDisposable`/`IAsyncDisposable` |
| Using `Task.Run` in component | Use `async` event callbacks; fire-and-forget with `InvokeAsync` |
| Cascading parameter for everything | Use cascading params sparingly; prefer EventCallback |
| `@((MarkupString)userInput)` without sanitisation | Always sanitise via `HtmlEncoder` or `Ganss.Xss` [CODE-02] |
| Calling JS interop in `OnInitializedAsync` | Only in `OnAfterRenderAsync` or event handlers |
| Hard-coding route strings in `NavigationManager.NavigateTo` | Use typed route constants or `[Route]`-annotated models |

---

## 17. Component file naming conventions

```
Components/
  Auth/
    LoginPage.razor              ← routable page
    LoginPage.razor.css          ← scoped styles
    TwoFactorPage.razor
    PasswordChangePage.razor
    SsoCallback.razor

  Admin/
    UserAdmin.razor              ← page (list)
    UserAdmin.razor.cs           ← code-behind (preferred for large logic)
    UserCreateModal.razor        ← modal (non-routable)
    UserEditModal.razor
    GroupAdmin.razor
    GroupEditPanel.razor
    MenuPermTab.razor            ← tab panel sub-component
    ScreenPermTab.razor
    QueuePermTab.razor

  Shared/
    AppButton.razor              ← atom (no page, no modal)
    AppBadge.razor
    AppModal.razor               ← generic modal shell
    DataTable.razor              ← generic sortable/pageable table
    Pagination.razor
    Spinner.razor
    DualPaneSelector.razor       ← available/selected dual-pane

  Layout/
    MainLayout.razor
    NavMenu.razor
    TopBar.razor
    StatusBar.razor
```

---

## Pre-commit Blazor checklist

- [ ] `@rendermode InteractiveServer` only where interaction is required
- [ ] SSR pages use `@formname` + `<AntiforgeryToken />`
- [ ] `@attribute [Authorize(...)]` on every routable page
- [ ] All strings through `@L["Key"]` — no hardcoded text
- [ ] `EventCallback<T>` used (not `Action<T>`)
- [ ] `@key` on all list items
- [ ] `IDisposable` / `IAsyncDisposable` on components with subscriptions
- [ ] `await InvokeAsync(StateHasChanged)` for off-thread updates
- [ ] JS interop only in `OnAfterRenderAsync` or event handlers
- [ ] Modals have `role="dialog"`, `aria-modal="true"`, `aria-labelledby`
- [ ] Focus moves to modal on open, returns to trigger on close
- [ ] No raw `MarkupString` without sanitisation
- [ ] Server-side pagination — never load all records
