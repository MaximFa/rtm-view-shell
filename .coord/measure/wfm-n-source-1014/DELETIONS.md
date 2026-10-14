# Paths removed in this leg — path by path

Snapped 2026-10-14T10:24:57Z. Every line was measured against the **v4 branch** just now, not recalled. The box
commits the deletions explicitly, so nothing here is "and anything else that looks unused".

## 1. Whole files to delete

```
src/CcDashboard.Application/Queries/TenantSettings/GetTenantStatusGroupsQuery.cs
tests/CcDashboard.Tests.Security/Authorization/GetTenantStatusGroupsQueryHandlerTests.cs
tests/CcDashboard.Tests.Security/Wfm/WfmN0WarningTests.cs
```

Why each one, and what the measurement was:

**`GetTenantStatusGroupsQuery.cs`** — the old candidate list, built from `RTSData_UserStatus`. Under
source (A) the names must come from the metric suffixes, so keeping this would leave two directories
of group names that disagree with each other. Consumers of the type across `src/**` and `tests/**`:
its own file (declaration, handler, interface line), `src/CcDashboard.Web/Components/Admin/TenantsPage.razor:1198`,
and its own test file — nothing else. shell's reading ("only TenantsPage:1198") matches mine exactly.

**`GetTenantStatusGroupsQueryHandlerTests.cs`** (blob `75a31f29`, the 8 `[Fact]` I wrote this morning) —
goes with the query it tests. The tenant gate it pinned is not lost: the same five shapes are
re-pinned against the new query in `GetWfmServingGroupCandidatesQueryHandlerTests.cs` (blob below),
including the refusal, the Superadmin half and the missing-tenant-context branch.

**`WfmN0WarningTests.cs`** (blob `ab4347ad`) — its subject ceases to exist: there is no roster query
to report N=0 against. The replacement lives in the loop fragment (Warning on **unknown** N, naming
the BU and the missing groups) and in the provider tests, where "present and zero" versus "absent"
is pinned directly.

## 2. Members to remove inside files that stay

`src/CcDashboard.Application/Interfaces/IWfmInputQueryService.cs`
- `Task<IReadOnlyDictionary<string, int>> GetServingAgentCountsAsync(...)` — the whole member with its
  doc comment;
- `Task<int> GetBuServingAgentCountAsync(...)` — the whole member with its doc comment.

`src/CcDashboard.Infrastructure/Wfm/WfmInputQueryService.cs`
- `GetServingAgentCountsAsync` — implementation, `:128` to the end of the method;
- `GetBuServingAgentCountAsync` — implementation, from `:316`;
- `GetOrRefreshBuAgentPoolsAsync` — private, from `:392`;
- the `_buAgentPoolCache` field and its `BuAgentPoolCacheTtl` constant — they exist only for the
  method above.

**Kept on purpose** in the same file: `GetLambdaAndAhtAsync`, `GetActiveBusAsync`, `StampWallNow`,
`GetOrRefreshTzMapAsync` and `_tzCache`. λ and AHT stay per queue — that is the other half of the
operator's rule — and the timezone map is what the mixed-TimeZone gate hangs on.

## 3. Call sites that must change in the same commit, or the build breaks

`src/CcDashboard.Infrastructure/Wfm/WfmRealtimeLoop.cs`
- `:105` — `GetServingAgentCountsAsync` call → replaced per `FRAGMENT_LOOP.md` Edit 1;
- `:199` — `GetBuServingAgentCountAsync` call → replaced per Edit 2.

`src/CcDashboard.Web/Components/Admin/TenantsPage.razor`
- `:1198` — `new GetTenantStatusGroupsQuery(tenantId)` → `new GetWfmServingGroupCandidatesQuery(tenantId)`.
  **This line is shell's**, not mine: it is the settings page, and the same leg changes how the list
  is rendered (values no longer found among the suffixes must show as "not found in data"). I name
  the line so the deletion does not land without it.

## 4. What is NOT deleted, though it may look unused after this

- the `NGC_*` tables and every entity over them — other code reads them; this leg removes two
  methods, not a data model;
- `RTSData_UserStatus` and its entity — still read elsewhere (the status-log side), and λ/AHT are
  untouched;
- the §36a chain as a concept — it stops serving N, but I measured only the three methods above.
  Call sites, measured just now across `src/**`: `GetServingAgentCountsAsync` → one
  (`WfmRealtimeLoop.cs:105`); `GetBuServingAgentCountAsync` → one (`:199`);
  `GetOrRefreshBuAgentPoolsAsync` → one, internal (`:328`). Anything else that walks BU→SG→AG→user
  elsewhere stays where it is.

## 5. Blobs of the files that replace what is deleted

- `GetWfmServingGroupCandidatesQuery.cs` — `7bfd98cb396c0ef88560f155d346cf34743da43c`, 4033 B
  → `src/CcDashboard.Application/Queries/TenantSettings/`
- `GetWfmServingGroupCandidatesQueryHandlerTests.cs` — `815aba79fa6a42209e94629f0de70dba4999297c`, 8896 B,
  7 `[Fact]`, CR 0 → `tests/CcDashboard.Tests.Security/Authorization/`
- `WfmEngineAgentCountProvider.cs` — `67dcfec5722756588defc56501954a2a06768cf2`
- `WfmEngineAgentCountProviderTests.cs` — `907e54242e1a455f75ec1c87911cc69f47afb291`, 12 `[Fact]`

## 6. Counts, measured against v4 just now

Blobs in v4 match the ones the coordinator named, so the files to delete are the files we mean:

- `tests/.../GetTenantStatusGroupsQueryHandlerTests.cs` → `75a31f29bbf806d196d46187b900ce0fa359cbf6`,
  **8** `[Fact]`;
- `tests/.../WfmN0WarningTests.cs` → `ab4347adb25976eace96b18081c50588460bdfe0`, **5** `[Fact]`.

Out: 13 tests. In: 7 (candidates query) + 12 (provider) + 5 (TZ gate) = 24. Both figures counted with
`grep -c '[Fact]'` over the v4 blobs and over the delivered files, not recalled.

Nothing compiled or run here — no `dotnet`, v4 working directory not mounted. The box decides.
