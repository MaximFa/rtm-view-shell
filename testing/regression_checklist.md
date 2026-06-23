# RTM View Shell — Pre-push Regression Checklist (v1)

**Purpose:** fast core-functionality + regression pass. Two uses: (a) immediate per-change QA right after a fix/feature lands; (b) a full pass before EVERY push. Owner: test (QA).
**Target time:** ~15-20 min (core paths, not exhaustive).
**How to run (tool-agnostic):** Chrome on the running Shell UI (`https://localhost:5239`) for the front end + DB cross-check via Soma `/db/query` (or `psql`). Background-service errors: read the `dotnet` console (operator) or `src/CcDashboard.Web/logs/log-<date>.txt`.
**Tooling caveat (current):** Soma `/shell/start` 500s after a restart (F-QA-3) and `/logs/serilog` path is wrong (F-QA-2); until fixed, bring the Shell up manually (`dotnet run --project src\CcDashboard.Web`) and read live archiver/aggregation errors from the dotnet console (Cowork can''t tail the live Serilog — mount-frozen, §0.5). Do NOT blanket-kill `dotnet` (kills Soma — F-QA-4).

## 0. Pre-flight
- [ ] Shell up at https://localhost:5239 ; `git rev-parse HEAD` == the commit under test.
- [ ] DB reachable (Soma `GET /health` ok; `/db/query` returns).

## 1. Auth
- [ ] Login `admin@platform.local` -> lands on /screens. (password entered by the OPERATOR, not QA — security rule.)
- [ ] Logout -> /login. Protected route (/reports) while unauthenticated -> redirects to /login.
- [ ] (Conditional) if 2FA enabled: OTP step appears. Skip when disabled to stay fast.

## 2. Dashboards (/screens)
- [ ] /screens list loads (no error), shows existing screens.
- [ ] Create a screen (name + description) -> appears in the list.
- [ ] Open viewer (/screens/{id}) -> chrome loads (topbar / nav / status bar).
- [ ] Widget Catalogue browses by category (no error).
- [ ] Delete the test screen -> confirmation -> removed (soft/hard per TenantSettings.SoftDeleteDashboards).
- [ ] UI=DB: /screens count == DB `select count(*) from dashboards where not "IsDeleted"` (Soma /db/query).

## 3. Historical Reports (/reports)  [F-QA-1 guard]
- [ ] All 4 tabs render seeded data, NOT zero: Queue Interval, Queue Wait Time, Agent Monthly, Agent Shift Detail.
- [ ] **F-QA-1 regression guard:** default range (today-7 .. today) INCLUDES the To-day''s rows (today''s data shown; not the old exclusive-To 640-style truncation). Change To and re-Apply -> count changes, no error.
- [ ] Pagination works (next page / change page size).
- [ ] UI=DB (>=2 tabs): Queue Interval UI count == DB `hist_queue_intervals` (windowed); Agent Shift Detail UI count == DB `hist_agent_intervals` (window incl To-day).

## 4. Background services  [F-QA-5 / F-QA-6 guards]
- [ ] Archiver run shows NO 42883 / 42703 / 42P07 (scan dotnet console / Serilog for ERR).
      - **F-QA-5 guard:** no `column "t.Value" does not exist` (watermark read).
      - **F-QA-6 guard:** no `column "CustomCallData1" does not exist` (interaction copy).
- [ ] Archive proceeds: `arch_watermark` gets a row and/or `arch_rtsdata_*` populate (when data older than retention exists). Soma /db/query.
- [ ] Aggregation service runs without error (`hist_*` populated for the seeded window).

## 5. Console / log
- [ ] No unexpected ERR on the smoke path (login -> dashboards -> reports). Read via dotnet console or `src/CcDashboard.Web/logs/log-<date>.txt` (note Cowork mount-lag).

## Verdict
- [ ] **PASS** — all green -> QA ack = GREEN for the push barrier.
- [ ] **HOLD: <area> — <finding>** (floor-pin: where / expected vs actual) -> route to the owning role; no push until cleared.

**Mandatory regression guards (must explicitly pass, no silent regress):** F-QA-1 (To-day shown), F-QA-5 (no t.Value 42703), F-QA-6 (no CustomCallData1 42703).

*Revision history*

| Version | Date | Summary |
|---|---|---|
| v1 | 2026-06-23 | Initial standing pre-push regression checklist (auth, dashboards, reports, background services, UI=DB, F-QA-1/5/6 guards). |