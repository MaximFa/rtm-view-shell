# CC Task: Fix phantom RefCount decrement in Unsubscribe methods

## Root Cause

In RtmRelayService, both UnsubscribeGridAsync and UnsubscribeUnionAsync always
decrement RefCount regardless of whether the handler was actually in the list:

```csharp
state.Handlers.Remove(handler);                     // bool — was handler found?
state.RefCount = Math.Max(0, state.RefCount - 1);   // ALWAYS decrements!
```

If Remove() returns false (handler was null, or was never subscribed), RefCount
is still decremented → goes to 0 → grace timer fires → connection killed after 30s.

This explains why Queue Grid "loses data" after certain actions:
- SSR pre-render dispose (if any path leads here with null handler)
- Double-unsubscribe from reconnect/dispose race conditions
- Any caller that calls Unsubscribe without a prior Subscribe

## File to modify

src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs

### Change 1: UnsubscribeUnionAsync (~line 147)

Find:
```csharp
            state.Handlers.Remove(handler);
            state.RefCount = Math.Max(0, state.RefCount - 1);
```
(inside UnsubscribeUnionAsync, in the lock block)

Replace with:
```csharp
            var removed = state.Handlers.Remove(handler);
            if (removed)
                state.RefCount = Math.Max(0, state.RefCount - 1);
            else
                _logger.LogWarning(
                    "RtmRelayService: UnsubscribeUnionAsync — handler not found in list for union {UnionId} (RefCount={RefCount}), skipping decrement",
                    unionId, state.RefCount);
```

### Change 2: UnsubscribeGridAsync (~line 485)

Find:
```csharp
            state.Handlers.Remove(handler);
            state.RefCount = Math.Max(0, state.RefCount - 1);
```
(inside UnsubscribeGridAsync, in the lock block)

Replace with:
```csharp
            var removed = state.Handlers.Remove(handler);
            if (removed)
                state.RefCount = Math.Max(0, state.RefCount - 1);
            else
                _logger.LogWarning(
                    "RtmRelayService: UnsubscribeGridAsync — handler not found in list for grid {GridId} (RefCount={RefCount}), skipping decrement",
                    gridId, state.RefCount);
```

## Build and commit

```bash
dotnet build src/CcDashboard.Infrastructure/CcDashboard.Infrastructure.csproj
bash tools/pre-commit-check.sh src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
git add src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
git commit -m "fix: prevent phantom RefCount decrement in Unsubscribe when handler not found

UnsubscribeGridAsync and UnsubscribeUnionAsync were always decrementing
RefCount even when the handler was not in the Handlers list (Remove returned false).
This caused spurious grace timer starts when null handlers or duplicate
unsubscribes occurred, killing the relay connection after 30 seconds.

Now only decrements if the handler was actually found and removed.
Adds LogWarning for diagnostic visibility when unexpected unsubscribes occur.
"
```

```bash
git show HEAD:src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs > \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
echo "Re-synced"
sync
```
