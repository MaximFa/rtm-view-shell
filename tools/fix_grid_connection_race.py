#!/usr/bin/env python3
"""Fix Grid connection race condition — use CancellationToken.None for connection phase."""

import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Infrastructure\RtmRelay\RtmRelayService.cs"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Change 1 — SubscribeGridAsync
old1 = '''            if (state.Connection == null)
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
            }'''

new1 = '''            if (state.Connection == null)
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
            }'''

if old1 not in text:
    print("ERROR: Pattern 1 (Grid) not found")
    exit(1)
text = text.replace(old1, new1, 1)
print("Fixed: SubscribeGridAsync")

# Change 2 — SubscribeUnionAsync
old2 = '''                    await conn.StartAsync(ct);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} union {UnionId}",
                        tenantId, unionId);
                    await InitUnionAsync(state, unionId, ct);'''

new2 = '''                    await conn.StartAsync(CancellationToken.None);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} union {UnionId}",
                        tenantId, unionId);
                    await InitUnionAsync(state, unionId, CancellationToken.None);'''

if old2 not in text:
    print("ERROR: Pattern 2 (Union) not found")
    exit(1)
text = text.replace(old2, new2, 1)
print("Fixed: SubscribeUnionAsync")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Done: RtmRelayService.cs ({text.count(chr(10)) + 1} lines)")
