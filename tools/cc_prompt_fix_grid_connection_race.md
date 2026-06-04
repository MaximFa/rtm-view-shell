# CC Task: Fix Grid connection race condition — "Connection failed" on page refresh with 2+ QueueGrid widgets

## Problem
When a dashboard has 2+ QueueGrid/DataSlot widgets, on page refresh one widget
consistently shows "Connection failed" and only recovers on user "Retry".

Root cause: `SubscribeGridAsync` passes the Blazor component's `CancellationToken`
to `conn.StartAsync(ct)` and `GridInitAsync(state, gridId, ct)`. During page
initialization, Blazor may trigger `StateHasChanged` causing component
re-initialization → the component's `_cts` is cancelled → `OperationCanceledException`
is thrown mid-connection → caught → widget enters Failed state.

Fix: use `CancellationToken.None` for the connection phase (StartAsync + GridInitAsync).
The component CT should only guard subscribe registration, not the Hub connection itself.
Same fix applies to the Union (AgentGrid) path.

## File
`src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change 1 — SubscribeGridAsync connection phase (around line 459)

Find:
```csharp
            if (state.Connection == null)
            {
                var conn = BuildGridConnection(key, state, hubUrl);
                try
                {
                    await conn.StartAsync(ct);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} grid {GridId}",
                        tenantId, gridId);
                    await GridInitAsync(state, gridId, ct);
                }
                catch
                {
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate → widget catch → Failed state
                }
            }
```

Replace with:
```csharp
            if (state.Connection == null)
            {
                var conn = BuildGridConnection(key, state, hubUrl);
                try
                {
                    // Use CancellationToken.None for the connection phase.
                    // The component CT must not cancel the Hub connection itself —
                    // Blazor may call StateHasChanged during init causing CT cancellation,
                    // which would incorrectly fail the connection for other widgets sharing
                    // the same page refresh cycle.
                    await conn.StartAsync(CancellationToken.None);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} grid {GridId}",
                        tenantId, gridId);
                    await GridInitAsync(state, gridId, CancellationToken.None);
                }
                catch
                {
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate → widget catch → Failed state
                }
            }
```

## Change 2 — SubscribeUnionAsync connection phase (around line 115, similar pattern)

Find:
```csharp
                    await conn.StartAsync(ct);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} union {UnionId}",
                        tenantId, unionId);
                    await InitUnionAsync(state, unionId, ct);
```

Replace with:
```csharp
                    await conn.StartAsync(CancellationToken.None);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} union {UnionId}",
                        tenantId, unionId);
                    await InitUnionAsync(state, unionId, CancellationToken.None);
```

---

## Verification

```bash
grep -n "StartAsync(CancellationToken.None)" \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Must return 2 lines (one for Grid, one for Union)
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs \
  tools/cc_prompt_fix_grid_connection_race.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: use CancellationToken.None for Grid/Union hub connection phase to prevent race on page refresh"
cp /tmp/cc-idx .git/index
```

Post-commit (§0.6):
```bash
git status --short
git log --oneline -3
```

## Git push
Do NOT run `git push` automatically.

---

## Re-sync from HEAD (§0.6 PD-007)

```bash
for f in src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs \
          tools/cc_prompt_fix_grid_connection_race.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
