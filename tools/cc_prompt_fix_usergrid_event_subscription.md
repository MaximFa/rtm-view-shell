# Task: Fix duplicate UserGridEvent subscription in Engine.cs

## Root cause

In `RTM/RTM/Engine.cs`, inside `LoadData`, the `UserGridEvent` is subscribed
inside `foreach (var uug in UnionUserGroups)`. A union with N supergroups gets
the event subscribed N times. Union 56 has 10 supergroups → 10 identical
`PUSH updateUserGrid` messages on every status change.

Confirmed in production logs (2026-06-04):
```
09:41:58,191 - PUSH updateUserGrid UnionId=56 count=1 agents=[Maxim Farber=>הפסקה]
09:41:58,195 - PUSH updateUserGrid UnionId=56 count=1 agents=[Maxim Farber=>הפסקה]
... (x10 identical)
```

## Fix — Engine.cs

Find the `LoadData: Union User Groups` section (around line 505).

Before the foreach loop, add a HashSet to track subscribed unions:
```csharp
AsyncLogger.Info("LoadData: Union User Groups");
var subscribedUnionEvents = new HashSet<int>();  // ADD THIS LINE
foreach (var uug in UnionUserGroups)
{
```

Then find the two event subscription lines inside the loop:
```csharp
    union.UserGridEvent += Union_UserGridEvent;
    union.UserUnionDeactivateEvent += _userManagerList_UserUnionDeactivateEvent;
```

Replace with:
```csharp
    if (subscribedUnionEvents.Add(unionId))  // Add() returns false if already present
    {
        union.UserGridEvent += Union_UserGridEvent;
        union.UserUnionDeactivateEvent += _userManagerList_UserUnionDeactivateEvent;
    }
```

## Verification

After deploy: one status change should produce exactly ONE
`PUSH updateUserGrid` log line, not N lines.

```bash
grep -c "PUSH updateUserGrid" <rtm_log_file>  # should be 1 per status change
```

## Commit message

```
fix: subscribe UserGridEvent once per union, not once per supergroup

LoadData iterated UnionUserGroups (one row per supergroup) and subscribed
UserGridEvent on every iteration. Union with 10 supergroups = 10 identical
updateUserGrid pushes per status change. Fix: HashSet guard, subscribe once.
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```
