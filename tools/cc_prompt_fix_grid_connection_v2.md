# CC Task: Fix Grid "Connection failed" on page refresh — comprehensive fix

## Problem
With 2+ Grid widgets (QueueGrid/DataSlot) on a dashboard, one widget consistently
shows "Connection failed" on page refresh. Previous fix (StartAsync/GridInitAsync
with CancellationToken.None) didn't help.

## Root cause investigation
Need to find exactly where exception is thrown. Two candidates:
1. `GetHubUrlAsync(tenantId, ct)` — still uses component CT
2. `state.Lock.WaitAsync(ct)` — still uses component CT

Also: `InvokeAsync<string>("refreshCells", ...)` calls a `void` Hub method with
a string return type — may cause issues.

## Changes

### File 1: RtmRelayService.cs

**Change 1a — SubscribeGridAsync: use CancellationToken.None everywhere in connection phase**

Find (line ~442):
```csharp
        var hubUrl = await GetHubUrlAsync(tenantId, ct);
        var key = (tenantId, gridId);
        var state = _grids.GetOrAdd(key, _ => new GridState());

        await state.Lock.WaitAsync(ct);
```

Replace with:
```csharp
        var hubUrl = await GetHubUrlAsync(tenantId, CancellationToken.None);
        var key = (tenantId, gridId);
        var state = _grids.GetOrAdd(key, _ => new GridState());

        await state.Lock.WaitAsync(CancellationToken.None);
```

**Change 1b — SubscribeUnionAsync: same fix for Union path**

Find (line ~93):
```csharp
        var hubUrl = await GetHubUrlAsync(tenantId, ct);
```
(the one in SubscribeUnionAsync — check context)

And:
```csharp
        await state.Lock.WaitAsync(ct);
```
(the one inside SubscribeUnionAsync)

Replace both with `CancellationToken.None`.

**Change 1c — GridInitAsync: use InvokeAsync<object> for refreshCells (void method)**

Find:
```csharp
        await state.Connection!.InvokeAsync<string>("refreshCells", gridId.ToString(), ct);
```

Replace with:
```csharp
        await state.Connection!.SendAsync("refreshCells", gridId.ToString(), CancellationToken.None);
```

Note: Use `SendAsync` instead of `InvokeAsync<string>` for `refreshCells` which is a
`void` Hub method. `SendAsync` fire-and-forget matches the void return type correctly.
`InvokeAsync<string>` on a void method may cause protocol mismatch.

**Change 1d — Add error logging in catch block of SubscribeGridAsync**

Find:
```csharp
                catch
                {
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate → widget catch → Failed state
                }
```

Replace with:
```csharp
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "RtmRelayService: failed to connect grid {GridId} — {ExType}: {Msg}",
                        gridId, ex.GetType().Name, ex.Message);
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate → widget catch → Failed state
                }
```

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Verification

```bash
grep -n "CancellationToken.None" \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | wc -l
# Should be at least 6 lines

grep -n "SendAsync.*refreshCells" \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Must return 1 line
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs \
  tools/cc_prompt_fix_grid_connection_v2.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: use CancellationToken.None for all Grid/Union subscribe steps; SendAsync for void refreshCells"
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
          tools/cc_prompt_fix_grid_connection_v2.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
