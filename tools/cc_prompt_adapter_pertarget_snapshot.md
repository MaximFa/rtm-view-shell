# CC task — RTM.Twilio: per-target connect snapshot (fix legacy empty queues) — §4 PRE-BLESSED

> ROOT (subagent-verified): the connect snapshot (setSkills/setWorkgroups/setUsersStatusList + per-agent userConfigurationChanged+userWorkgroupActivation + FetchAndProcessAllActiveTasksAsync) is BROADCAST to ALL targets via SendToAllAsync/PostToAllAsync inside RTMAdapter_ServerConnectEvent. When one target connects, the burst also fans to co-targets whose pipe is NOT YET writable → StreamString.WriteString silently drops it (`if (CanWrite)`, no exception) → legacy never gets its workgroup-activation → agents never join a union → legacy queues show 0 connected + empty-TZ getLocalDateTime noise (symptom, not cause). FIX: send the snapshot ONLY to the target that just connected (the event already carries `RtmTargetConnectedEventArgs.Target`, currently discarded). Incremental live events stay broadcast.
> ⚠ Do NOT "send a valid TimeZone" — user TZ is derived server-side from union membership, never from adapter data; that would not fix anything.
> Owner: backend. Native CC. Work on branch **`adapters`** (worktree D:\Claude\Projects\RTMView-adapters-wt). Commit `fix:`. **NO push** (deploy+verify on 234 first, IRON RULE). §0.3 Python+fsync.

## Mandatory reads
Read: CLAUDE.md §48 [WIRE-01..05]+[WIRE-VALIDATION] (StreamString touched → re-run WIRE test); .coord/wire_contract.md; session-coord; role-backend §A.
Read the target files first: RTM.Twilio/RTMAdapter.cs, RTM.Twilio/TwilioAdapter.cs (RTMAdapter_ServerConnectEvent), RTM.Adapter.Common/StreamString.cs.

## INIT
```bash
cd "D:\Claude\Projects\RTMView-adapters-wt"      # the `adapters` worktree
git rev-parse --abbrev-ref HEAD                   # MUST be adapters
git status --short ; sync
```
If the worktree is gone: `cd "D:\Claude\Projects\RTM View Shell" && git worktree add "D:\Claude\Projects\RTMView-adapters-wt" adapters`.

## THE WORK — minimal-churn: thread an OPTIONAL target through the snapshot path

### A. RTMAdapter.cs — SendToAllAsync / PostToAllAsync: add optional `RtmTarget only = null`
- `SendToAllAsync(string jsonData, RtmTarget only = null)`: if `only != null` → send to ONLY that target (its pipe, same per-target try/catch); else the existing all-targets fan-out. 
- `PostToAllAsync(string endpoint, string data, RtmTarget only = null)`: same — if `only != null`, POST only to `only.Url`; else all.
(Existing call-sites pass nothing → unchanged broadcast behavior.)

### B. RTMAdapter.cs — thread `RtmTarget only = null` through the SNAPSHOT methods
Add an optional `RtmTarget only = null` last-parameter to each snapshot-producing method and pass it down to SendToAll/PostToAll:
- `setSkillsAsync(List<string> skills, RtmTarget only = null)` → `SendToAllAsync(jsonData, only)`
- `setWorkgroupsAsync(List<string> workgroups, RtmTarget only = null)` → `SendToAllAsync(jsonData, only)`
- `setUsersStatusList(List<Agent> usersStatusList, RtmTarget only = null)` → `PostToAllAsync("/SetUsersStatusList", data, only)`
- `userConfigurationChangedAsync(..., RtmTarget only = null)` → `SendToAllAsync(jsonData, only)`
- `userWorkgroupActivationAsync(..., RtmTarget only = null)` → `SendToAllAsync(jsonData, only)`
- `setUsersAsync(..., RtmTarget only = null)` if it is part of the connect snapshot → same.
(These already build `jsonData`/`data` once; only the send call gains the `only` arg. Incremental callers pass nothing → broadcast, unchanged.)

### C. TwilioAdapter.cs — RTMAdapter_ServerConnectEvent: use the connected target
- Change the handler to read the target from the event:
  `var target = (e as RTMAdapter.RtmTargetConnectedEventArgs)?.Target;`  (keep the SemaphoreSlim guard.)
- Route EVERY snapshot call in the handler to that one target by passing `only: target` (or positional): `setSkillsAsync(..., target)`, `setWorkgroupsAsync(..., target)`, `setUsersStatusList(..., target)`, and in the per-agent loop `userConfigurationChangedAsync(..., target)` + `userWorkgroupActivationAsync(..., target)`.
- `FetchAndProcessAllActiveTasksAsync(...)`: thread the same `RtmTarget only = null` param through it so its interactionChanged/interactionRemoved snapshot sends go to `target` only. (Its live/non-snapshot uses stay broadcast.)
- Result: each target (v3 AND legacy), on ITS OWN ConnectedToServer (pipe already writable by definition of the event), receives its complete snapshot → no broadcast-to-unwritable race, and reconnect re-delivers per target.

### D. (Secondary hardening) RTM.Adapter.Common/StreamString.cs — make dropped sends VISIBLE
Where `WriteString` no-ops on `!ioStream.CanWrite`, log a warning (AsyncLogger.Error/Info) instead of silently returning, so a lost send is visible. Do NOT change the wire framing/encoding (WIRE-04) — only add the log on the not-writable branch.
⚠ This touches RTM.Adapter.Common → the WIRE contract test MUST be re-run and stay GREEN (§48 [WIRE-VALIDATION]).

## VERIFY / DoD — REPORT NUMBERS
- **Object-store:** SendToAllAsync/PostToAllAsync have `RtmTarget only=null`; snapshot methods thread it; RTMAdapter_ServerConnectEvent reads `RtmTargetConnectedEventArgs.Target` and passes it to all snapshot calls incl. FetchAndProcessAllActiveTasksAsync; incremental live sends unchanged (broadcast). StreamString logs on !CanWrite.
- **Build:** `dotnet build "RTM.Twilio\RTM.Twilio.csproj" -c Release` = **0 errors** (report W).
- **WIRE test:** `dotnet test "RTM.Adapter.Common.Tests\RTM.Adapter.Common.Tests.csproj" -c Release` = **pass (14/14)** — StreamString change must not break the contract.
- ⛔ LIVE gate (coordinator/operator on 234, AFTER deploy): legacy real-time queues POPULATE (connected agents > 0) — the actual proof.

## COMMIT (adapters branch, in the worktree) — NO push
- `bash tools/pre-commit-check.sh` if present; else object-store verify. commit.lock if the repo shares it.
- `git add RTM.Twilio/RTMAdapter.cs RTM.Twilio/TwilioAdapter.cs RTM.Adapter.Common/StreamString.cs` → commit `fix(adapter): per-target connect snapshot (was broadcast → legacy lost workgroup-activation → empty queues) + StreamString drop-visibility [backend]`.
- §0.6 verify. **NO push** (deploy to 234 + verify legacy queues first).

## §0.6b CAPTURE → role-backend §B: "Multi-target adapter connect-snapshot MUST be per-connected-target, NOT broadcast. Broadcasting the one-shot registration (setWorkgroups/userWorkgroupActivation) on one target's connect fans it to co-targets whose pipe is not yet writable; StreamString silently drops (!CanWrite, no exception) → that target never registers agents → its queues show 0. Route snapshot to RtmTargetConnectedEventArgs.Target only; keep incremental events broadcast. Also: a silent no-op send is a debugging trap — log !CanWrite drops. SOURCE: legacy-empty-queues diagnosis 2026-07-12, RTMAdapter_ServerConnectEvent + StreamString.WriteString."
## Report → inbox/coordinator.md: commit hash, build 0/W, WIRE 14/14, files.
