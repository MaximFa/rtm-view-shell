# CC task — Reports-as-Dashboards Ф2: BuMembershipResolver (BU-scope resolution)
> Coordinator-authored per docs/Reports-AsDashboards-v1-Spec.md §4. Owner: BACKEND/BI. DBA co-reviews the NGC join SQL. SECURITY: PG-intersection preserved (SF-BI-001). Executor: native CC. Branch **v3**. Commit `feat:`. **NO push** (§37). FREE/MIT.
> Builds on Ф1 (473363c). SCOPE Ф2 = the BU→concrete-filter-set resolver ONLY (the logic that report-widgets will call). NO UI (Ф4/Ф5), NO widgets, NO export/distribution. Reuses (NO change to their filtering contract): the 4 MediatR report queries + HistoricalReportRepository + the existing ReportScopeResolver (PG scope).

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md` ; `.claude/skills/role-backend/role-backend.md` §A+§C
- `docs/Reports-AsDashboards-v1-Spec.md` §4 (canonical BU-scope membership model — authoritative)
- CLAUDE.md §46 (IDENT — agents/queues = EXTERNAL CC ids; never ApplicationUser.Id), §36 (BU→Queue ClassificationId='ALL'), §33.3 (NGC tables)

## INIT — branch v3 + integrity + sync + DISCIPLINE
- `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 AND `git rev-parse HEAD`==v3 tip SHA (object-store, NOT just --abbrev-ref — post-incident branch-by-SHA discipline). §0.2/§0.5.
- §0.3 writes Python+os.fsync on mount / native-CC editor OK; verify object-store after.
- §42.6 sync: S1 freeze-check (CLOSED tombstone → proceed). Slug = backend slug. Claims (file-mode, new + grounded): the resolver file(s) under `src/CcDashboard.Application/HistoricalReports/**` (e.g. `BuMembershipResolver.cs` + DTO) + the membership read in `src/CcDashboard.Infrastructure/**` (NGC joins) + tests under `tests/**`. GROUND the exact existing `ReportScope`/`ReportScopeResolver` + `HistoricalReportRepository` paths/signatures by object-store FIRST and integrate (do not duplicate PG-scope).
- ⚠ NARROW-ADD (L-SC-09): explicit `git add` of only your new/edited files; `git status --short` pre-commit; post-commit `git show --stat` = ZERO file-deletions + only your files, else `reset --hard HEAD~1` + STOP. commit.lock; §0.6b binding → .coord/cc/backend.md; NO push.

## THE WORK — resolve {BU(s), report-type} → concrete IN-sets (spec §4 = authoritative)
Implement a resolver (BuMembershipResolver, or extend ReportScopeResolver — your call, no PG-scope duplication) that, given a tenant + a Business Unit (or BU list) + a **report-type axis (detail | cumulative)**, returns flat sets the repo filters with `IN (...)`:

1. **QUEUE-scoped** (queue/workgroup reports): BU → its queues via `NGC_BusinessUnitQueueClassification` (ClassificationId='ALL', §36) → a **Workgroup set** → repo filters `"Workgroup" IN (set)`.
2. **AGENT DETAIL** (agent-list reports): **UNION** — all agents of ALL AgentGroups of ALL Supergroups in the BU. Path: `NGC_BusinessUnitSupergroup` (BU→SG) → `NGC_SupergroupAgentgroup` (SG→AG) → `NGC_UserAgentgroup` (AG→agent external id). Flat agent set = ∪ all members.
3. **AGENT CUMULATIVE** (aggregate reports): set = **`∪_SG ( ∩_AG members(AG) )`** — per Supergroup, INTERSECT member sets across that SG's AgentGroups; then UNION across the BU's Supergroups. (One formula covers BOTH client conventions: Conv-1 = 1 AG/SG → ∩ of one; Conv-2 = multi-AG/SG → ∩ of all. The convention is DATA = cardinality of NGC_SupergroupAgentgroup per SG, NOT a code branch.)
4. **PG-INTERSECTION (mandatory, SF-BI-001):** the BU-resolved set is INTERSECTED with the caller's PG-allowed set (the existing ReportScope: AllowedWorkgroups / AllowedAgentExternalIds). Superadmin = full. Empty PG list = DENY (PG-03). Never widen beyond PG.
5. Agents/queues keyed by EXTERNAL CC id (IDENT-01/02), never ApplicationUser.Id.
Output feeds the EXISTING HistoricalReportRepository `effectiveWorkgroups`/agent params (keep its `IN` filtering as-is). Resolve at query-build time (pre-computed flat sets; repo stays IN-based).

## TESTS (mandatory — the §4-critical correctness surface)
xUnit, covering: queue resolution (BU→queues IN); agent DETAIL union; agent CUMULATIVE `∪_SG(∩_AG)` with **Conv-1 (1 AG/SG)** AND **Conv-2 (multi-AG/SG intersection)** fixtures (assert an agent in only SOME of a multi-AG SG's groups is EXCLUDED from cumulative but INCLUDED in detail); PG-intersection (BU-set ∩ PG narrows; empty-PG = deny; Superadmin = full); external-id keying.

## VERIFY
- `dotnet build CcDashboard.sln` = 0 errors; `dotnet test` the new resolver tests GREEN.
- DBA co-reviews the NGC join SQL (correct tables/keys, TenantId-scoped). SECURITY confirms PG-intersection intact (post-commit).
- Object-store: only your claimed files; zero file-deletions.

## COMMIT (feat:, commit.lock, NO push) — NARROW ADD
`feat(reports): Ф2 — BuMembershipResolver (BU→queues IN; agent detail-union; cumulative ∪_SG(∩_AG); PG-intersect SF-BI-001) + tests [backend]` → §0.6 post-commit (git show v3:, zero-deletion) → cc_post_commit.sh → PD-007 re-sync.

## Binding RESULT → .coord/cc/backend.md: commit hash; resolver + tests; build 0 + tests green; PG-intersect preserved; only-claimed/zero-deletion; NO push. verified: object-store.
## REPORT (chat): commit hash; confirm both conventions tested; flag coordinator → security PG re-review + dba NGC-join confirm. Ф3 (shared UI layer) next.
