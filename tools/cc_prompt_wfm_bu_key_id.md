# CC Task — WFM per-BU snapshot key: BusinessUnitName -> BusinessUnitId (fix "Waiting for data")

> C2#2 root (backend-confirmed static): the WFM widget config stores/sends the BU **ID** (ScreenEditorPage.razor:349/4158/4494
> Config.BusinessUnit = BusinessUnitId.ToString(); WfmWidget.razor:181 Get(<id>)), but the loop Sets per-BU keyed by
> BusinessUnitName (WfmRealtimeLoop:199) -> id != name -> Get null -> "Waiting for data". Fix = key per-BU by the ID
> (what the widget already sends). BONUS: a numeric BU-id key cannot collide with a Workgroup NAME -> the ~20 real
> collisions vanish. Loop-only, NO widget change. Territory: **web**. NO push. Prefix `fix:`.

## STEP 0 — §0.6a integrity (v3). §40 reads + role-backend §A/§C. §37 NO push. §0.3 Python+fsync (Edit BANNED). commit.lock.
## STEP 1 — Sync slug backend-0626. Claims:
##   - src/CcDashboard.Infrastructure/Wfm/WfmRealtimeLoop.cs   (MODIFY: BU key -> id, in ProcessBuAggregatesAsync)
## STEP 2 — BINDING preamble to .coord/cc/backend.md.

## THE FIX — WfmRealtimeLoop.ProcessBuAggregatesAsync (~lines 166-213)
Introduce a `buKey` = the BU IDENTIFIER string the widget Gets, and use it for BOTH the collision check and the snapshot key:
1. Near the top of the `foreach (var bu in bus)` body, add:
   `var buKey = bu.BusinessUnitId.ToString();`
2. Collision check (currently `if (queueKeys.Contains(bu.BusinessUnitName))` @ ~:171): change the CHECK to the actual key:
   `if (queueKeys.Contains(buKey))` — (with a numeric id this will effectively never fire; that is correct — BU-id and
   Workgroup-name are disjoint namespaces; the ~20 BU-name==Workgroup-name collisions are eliminated). Keep the WARN
   message text but it now reflects the real key.
3. Snapshot key (currently `BuildSnapshot(tenantId, bu.BusinessUnitName, ...)` @ ~:199): change the 2nd arg to `buKey`:
   `BuildSnapshot(tenantId, buKey, asOfUtc, windowMin, pooledLambda, pooledAht, pooledN, ...)`.
- KEEP the human-readable LOG messages using `bu.BusinessUnitName` (e.g. the per-BU error log :210-211) for readability —
  only the KEY (collision check + snapshot QueueId) changes to the id. Do NOT change per-queue keys (Workgroup) — untouched.

## STEP 3 — build0
`dotnet build src/CcDashboard.Web` — Build succeeded, 0 errors.

## STEP 4 — pre-commit + commit (commit.lock) — ONE commit:
`fix: WFM per-BU snapshot keyed by BusinessUnitId (matches widget Get) — fixes "Waiting for data" + kills BU/Workgroup key collisions [wfm]`
§0.6 verify -> journal -> lock release -> §0.7 re-sync. NO push.

## STEP 5 — BINDING RESULT: commit hash, the buKey change (BU snapshot key = BusinessUnitId.ToString()), confirm per-queue keys untouched + collision guard now on the id, build result, status.
## NOTE: after commit -> devops redeploy -> live re-check: BU widget "US All" (id) shows data; collision WARNs stop.

## Acceptance
- [ ] Per-BU snapshot keyed by bu.BusinessUnitId.ToString() (both the collision check and BuildSnapshot 2nd arg). Per-queue keys (Workgroup) untouched. Log messages keep BusinessUnitName.
- [ ] build green. Prefix fix:. NO push. No widget/shell change.

## Git push: do NOT run git push. Commit only.
