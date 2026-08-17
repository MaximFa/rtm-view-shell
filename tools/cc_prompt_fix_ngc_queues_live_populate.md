# CC task — RED DEFECT: NGC_Queues never populated by the LIVE adapter path (BU queue picker empty)

> Owner: backend (RTM Engine). Branch **v3 ONLY**. Commit `rtm:`. **NO push** (§37). ⛔ЧП.
> §4-REVIEW: PENDING — self-§4 PASS required; post to inbox/coordinator.md; no operator run until coordinator bless.

## ROOT (object-store @ v3 — confirmed, do NOT re-derive)
`NGC_Queues` (the queue reference table that feeds the Business Unit "Available queues" picker in the Shell) is written by EXACTLY ONE method — `BusinessUnitData.getOrCreateQueue(externalId,name)` (`RTM/RTM/BusinessUnitData.cs:227` → SQL `NGC_GetOrCreateQueue`, idempotent `ON CONFLICT DO NOTHING`).
Its ONLY call-site is `RTM/RTM/Engine.cs:477`, inside the ONE-TIME startup `LoadData` (iterates `RTSGrid_GetAllUnionQueueClassifications`, a DB config read — empty on a fresh server).
The LIVE adapter workgroup-add branch in `getOrAddWGManager` (`RTM/RTM/Engine.cs:1877-1893`) writes `createBusinessUnit` + `createBusinessUnitQueueClassificationMapping` + `union.Queues.Add(id)` + `addWorkgroup(id,...)` — but **NEVER calls `getOrCreateQueue`**. So on a running server the adapter fills `NGC_BusinessUnitQueueClassification` (confirmed populated on 140) while `NGC_Queues` stays EMPTY → BU picker shows no queues.

## FIX — single symmetric call (minimal, 1 file, 1 line)
In `RTM/RTM/Engine.cs`, inside `getOrAddWGManager`, in the block that fires on a NEW workgroup, add the `getOrCreateQueue` write symmetric to the classification write. Exact location — inside the `if (BusinessUnitData.createBusinessUnitQueueClassificationMapping(businessUnitId, id, "ALL", "admin"))` body (Engine.cs ~1890-1893), alongside `union.Queues.Add(id);`:
```csharp
if (BusinessUnitData.createBusinessUnitQueueClassificationMapping(businessUnitId, id, "ALL", "admin"))
{
    union.Queues.Add(id);
    union.addWorkgroup(id, _applicList);
    // Persist queue to NGC_Queues (symmetric with LoadData path Engine.cs:477) — idempotent
    BusinessUnitData.getOrCreateQueue(id, id);
}
```
- Use the local `id` (the workgroup/queue id) for BOTH externalId and name — identical to the working LoadData call `getOrCreateQueue(QueueId, QueueId)` at Engine.cs:477.
- `getOrCreateQueue` is idempotent (`ON CONFLICT ("ExternalId","TenantId") DO NOTHING`) → safe to call on every workgroup-add. TenantId is `AppConfig.TenantId` inside getOrCreateQueue (unchanged).
- Do NOT touch the LoadData path (Engine.cs:477) or any other line. This is the ONLY edit.

## WHY correct
The classification mapping and the queue reference must be written together for the same live workgroup event; today only the mapping is. Adding the idempotent `getOrCreateQueue(id,id)` in the same branch makes every adapter-announced workgroup register its queue row → BU picker populates. Startup LoadData behavior unchanged.

## Mandatory — read before starting (§40/§0.8)
- `.claude/skills/session-coord/session-coord.md`; `.claude/skills/role-backend/role-backend.md` §A CORE (⛔ЧП) + §C VERIFY.
- Object-store grounding: Engine.cs (1868-1896 the new-WG branch, 458-480 LoadData ALL branch incl :477), BusinessUnitData.cs (226-236 getOrCreateQueue).

## INIT / discipline (§0.6a integrity FIRST)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git rev-parse --abbrev-ref HEAD` == **v3**; `git status --short`; hash-verify claimed file vs HEAD (§0.5 false-M); restore any PD-007 truncation from HEAD before work.
- §0.3 Python+fsync; Edit BANNED. After edit: `sync` + `tail -3` + `wc -l` + NUL-check(0). Preserve file LF/no-BOM.
- §42.6 sync block: S1 `cat .coord/push/request.md` — STOP on OPEN FREEZE. Slug = **backend-<MMDD>**. **Claim (file-mode)** = `["RTM/RTM/Engine.cs"]`. NARROW-ADD (L-SC-09): `git add` ONLY Engine.cs; post-commit `git show --stat` = zero deletions + only this file, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). pre-commit-check.sh. §0.7 re-sync. **NO push.**

## STEP 1 — binding PREAMBLE (.coord/cc/backend.md, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_fix_ngc_queues_live_populate.md | status: open
### DIRECTIVE: RED — NGC_Queues empty on live path. Add BusinessUnitData.getOrCreateQueue(id,id) in getOrAddWGManager new-WG branch (Engine.cs ~1890), symmetric with classification write. Claim: RTM/RTM/Engine.cs. gate: build 0 + unit failed 0. rtm:.
```

## STEP 2 — implement the single edit above.

## STEP 3 — VERIFY (GREEN gate — PASTE)
- `dotnet build` the RTM solution/project that contains Engine.cs → 0 errors (report W count). (Soma `/ops/build` OK if it covers RTM.)
- Run the existing unit suite that applies → failed=0 (report passed/failed). If RTM has no unit project, state so; build-0 is the compile gate.
- Object-store: only `RTM/RTM/Engine.cs`; zero deletions; exactly the shown insertion.
- ⚠ DEFINITIVE acceptance is a RUNTIME check owned by coordinator/operator on 140 (NOT this prompt): after redeploy of RTMService + adapter feeding workgroups, `SELECT COUNT(*) FROM "NGC_Queues" WHERE "TenantId"='<tenant>'` > 0 and the BU Edit → Queues picker lists queues. State this for the seal.

## STEP 4 — commit (rtm:, commit.lock, NO push) — NARROW ADD
`bash tools/pre-commit-check.sh` → `git add RTM/RTM/Engine.cs` ONLY → `git status --short` (zero D) → commit `rtm: populate NGC_Queues on live workgroup-add (getOrCreateQueue in getOrAddWGManager) — BU queue picker [backend]` → §0.6 post-commit (hash==HEAD; zero-deletion; restore if PD-007) → §0.7 re-sync → sync. **NO push.**

## STEP 5 — binding POSTAMBLE / RESULT (.coord/cc/backend.md, Python+fsync)
```
### RESULT: commit <hash> . file RTM/RTM/Engine.cs (+getOrCreateQueue in new-WG branch) . build 0 . unit passed/failed <N>/<N> . only-claimed/zero-deletion . status done|failed . blockers . verified: object-store . runtime NGC_Queues>0 seal -> coordinator/140
<paste build (+unit) output>
```
Relay a 2-line digest to inbox/coordinator.md (commit + note RTMService redeploy to 140 required for the runtime seal).

## ACCEPTANCE (GREEN gate)
- `getOrCreateQueue(id,id)` added in the live new-workgroup branch of getOrAddWGManager, symmetric with the classification write; LoadData path unchanged.
- build 0 (+ unit failed 0 if a suite applies); 1 file; ZERO deletions; rtm: on v3; commit.lock; NO push. Binding PRE+POST. Runtime NGC_Queues seal flagged to coordinator/operator (needs RTMService redeploy to 140).
