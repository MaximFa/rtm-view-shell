#!/usr/bin/env python3
"""Fix Grid connection race v2 — use CancellationToken.None everywhere in subscribe flow."""

import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Infrastructure\RtmRelay\RtmRelayService.cs"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Change 1a — SubscribeGridAsync: GetHubUrlAsync and Lock.WaitAsync
# Use specific pattern with gridId and _grids to ensure correct match
old1a = '''        var hubUrl = await GetHubUrlAsync(tenantId, ct);
        var key = (tenantId, gridId);
        var state = _grids.GetOrAdd(key, _ => new GridState());

        await state.Lock.WaitAsync(ct);'''

new1a = '''        var hubUrl = await GetHubUrlAsync(tenantId, CancellationToken.None);
        var key = (tenantId, gridId);
        var state = _grids.GetOrAdd(key, _ => new GridState());

        await state.Lock.WaitAsync(CancellationToken.None);'''

if old1a not in text:
    print("ERROR: Pattern 1a (SubscribeGridAsync) not found")
    exit(1)
text = text.replace(old1a, new1a, 1)
print("Fixed: SubscribeGridAsync GetHubUrlAsync + Lock.WaitAsync")

# Change 1b — SubscribeUnionAsync: GetHubUrlAsync and Lock.WaitAsync
# Use specific pattern with unionId and _unions to ensure correct match
old1b = '''        var hubUrl = await GetHubUrlAsync(tenantId, ct);
        var key = (tenantId, unionId);
        var state = _unions.GetOrAdd(key, _ => new UnionState());

        await state.Lock.WaitAsync(ct);'''

new1b = '''        var hubUrl = await GetHubUrlAsync(tenantId, CancellationToken.None);
        var key = (tenantId, unionId);
        var state = _unions.GetOrAdd(key, _ => new UnionState());

        await state.Lock.WaitAsync(CancellationToken.None);'''

if old1b not in text:
    print("ERROR: Pattern 1b (SubscribeUnionAsync) not found")
    exit(1)
text = text.replace(old1b, new1b, 1)
print("Fixed: SubscribeUnionAsync GetHubUrlAsync + Lock.WaitAsync")

# Change 1c — GridInitAsync: InvokeAsync<string> -> SendAsync for refreshCells
old1c = '''        // refreshCells causes the server to push updateGridData with all current values.
        await state.Connection!.InvokeAsync<string>("refreshCells", gridId.ToString(), ct);'''

new1c = '''        // refreshCells causes the server to push updateGridData with all current values.
        // Use SendAsync (fire-and-forget) - refreshCells is a void Hub method.
        await state.Connection!.SendAsync("refreshCells", gridId.ToString(), CancellationToken.None);'''

if old1c not in text:
    print("ERROR: Pattern 1c (refreshCells InvokeAsync) not found")
    exit(1)
text = text.replace(old1c, new1c, 1)
print("Fixed: GridInitAsync refreshCells -> SendAsync")

# Change 1d — SubscribeGridAsync: add error logging in catch block
# Use UNIQUE pattern that includes GridInitAsync call to ensure we match Grid, not Union
old1d = '''                    await GridInitAsync(state, gridId, CancellationToken.None);
                }
                catch
                {
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate → widget catch → Failed state
                }'''

new1d = '''                    await GridInitAsync(state, gridId, CancellationToken.None);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "RtmRelayService: failed to connect grid {GridId} - {ExType}: {Msg}",
                        gridId, ex.GetType().Name, ex.Message);
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate -> widget catch -> Failed state
                }'''

if old1d not in text:
    print("ERROR: Pattern 1d (Grid catch block with GridInitAsync) not found")
    exit(1)
text = text.replace(old1d, new1d, 1)
print("Fixed: SubscribeGridAsync catch block with logging")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print("Done: RtmRelayService.cs (%d lines)" % (text.count('\n') + 1))
