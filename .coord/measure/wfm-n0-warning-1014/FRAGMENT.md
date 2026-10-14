# N=0 Warning: only when the configured groups are absent from the TENANT's data

Target file (v4): `src/CcDashboard.Infrastructure/Wfm/WfmInputQueryService.cs`, inside
`GetServingAgentCountsAsync`, the branch added on 13.10.
Scope: that branch plus one new local above the queue loop. Nothing else in the file is touched.
Snapped 2026-10-14T05:33:01Z. Supersedes the first version of this fragment (blob `5252fdad`), which implemented the
withdrawn point 1.

## Where "before" comes from, stated plainly

The branch does not exist in the **v3** tree, which is the only tree this session's bridge mounts:
`grep -n "count == 0 && agentList" src/CcDashboard.Infrastructure/Wfm/WfmInputQueryService.cs` → no
match, while a control needle on `GetServingAgentCountsAsync` in the same file returns 1, so the file
reads fine and the miss is not blindness. v3 file blob `3e79c93a`.
"Before" is therefore quoted from my 13.10 draft `.coord/measure/wfm-statusgroups-1013/LOG_FRAGMENTS.md`
(blob `7f433546`), which shell carried into v4. Byte-identity with v4 as it stands now is **not**
claimed — shell verifies before applying.

## BEFORE

```csharp
            if (count == 0 && agentList.Length > 0)
            {
                // The agent roster is NOT empty, yet none of them is in a serving group.
                // Either the shift is genuinely idle, or the configured group names do not match
                // the values the platform reports. Print BOTH sides so the two are distinguishable.
                var actualGroups = await ctx.Database
                    .SqlQueryRaw<string>(@"
                        SELECT DISTINCT us.""StatusGroup"" AS ""Value""
                        FROM public.""RTSData_UserStatus"" us
                        WHERE us.""TenantId"" = @tenant
                          AND us.""UserId"" = ANY(@agentList)
                          AND us.""StatusGroup"" IS NOT NULL",
                        new Npgsql.NpgsqlParameter("@tenant", tenantId),
                        new Npgsql.NpgsqlParameter("@agentList", agentList))
                    .ToListAsync(ct);

                logger.LogWarning(
                    "WfmInputQueryService: N=0 for queue {Queue} while roster has {AgentCount} agents. "
                  + "Configured serving groups = [{Configured}]; actual StatusGroup values for these agents = [{Actual}]",
                    queue, agentList.Length,
                    string.Join(", ", servingGroups),
                    string.Join(", ", actualGroups));
            }
```

## AFTER

Two edits. First, one local in front of the `foreach (var queue in queues)` loop:

```csharp
        // Distinct StatusGroup values present in THIS TENANT's data. Computed at most once per call
        // and only if some queue actually reports N=0 - see the branch below for why it is needed
        // and why it must not be per-queue.
        List<string>? tenantStatusGroups = null;
```

Second, the branch body:

```csharp
            if (count == 0 && agentList.Length > 0)
            {
                // The roster is NOT empty, yet nobody counts as serving. Two different situations
                // hide behind the same zero and only one needs a human:
                //   - the configured names do not occur in this tenant's data at all -> misconfigured;
                //   - they do occur, nobody is in them right now -> an idle shift.
                // The comparison must be against the TENANT's values, not against these agents':
                // over the same agentList the count query already answers that question, so an
                // intersection taken there is empty whenever count == 0 and the test would be
                // vacuous. Measured and recorded as PR234-V4-WFM-N0-WARN-01.
                tenantStatusGroups ??= await ctx.Database
                    .SqlQueryRaw<string>(@"
                        SELECT DISTINCT us.""StatusGroup"" AS ""Value""
                        FROM public.""RTSData_UserStatus"" us
                        WHERE us.""TenantId"" = @tenant
                          AND us.""StatusGroup"" IS NOT NULL",
                        new Npgsql.NpgsqlParameter("@tenant", tenantId))
                    .ToListAsync(ct);

                // Ordinal, to match the count query's own comparison: StatusGroup = ANY(@servingGroups)
                // is exact, byte for byte. A case-insensitive test here would call the 13.10 casing
                // mismatch an overlap and silence the one Warning worth keeping.
                var configuredNamesExistInTenant = tenantStatusGroups
                    .Intersect(servingGroups, StringComparer.Ordinal)
                    .Any();

                if (!configuredNamesExistInTenant)
                {
                    logger.LogWarning(
                        "WfmInputQueryService: N=0 for queue {Queue} while roster has {AgentCount} agents, "
                      + "and NONE of the configured serving groups occurs anywhere in this tenant's data. "
                      + "Configured serving groups = [{Configured}]; StatusGroup values present for tenant = [{Actual}]",
                        queue, agentList.Length,
                        string.Join(", ", servingGroups),
                        string.Join(", ", tenantStatusGroups));
                }
                else
                {
                    // Legitimate "nobody on the line". One line, no lists: this fires on every quiet
                    // tick and must stay cheap.
                    logger.LogDebug(
                        "WfmInputQueryService: N=0 for queue {Queue}, roster {AgentCount} agents, configured groups present in tenant data",
                        queue, agentList.Length);
                }
            }
```

## The cost question, answered: once per call, and only on demand

You offered a per-tick cache or hoisting the computation to tenant level, and left the choice to me.
I took neither as stated, because `GetServingAgentCountsAsync` is already called **once per tick per
tenant** and loops over the queues inside — so the scope of one call IS the tick. The `??=` above
gives exactly that, with two properties a time-based cache does not have:

- **No extra work on a healthy tick.** The local stays `null` unless some queue reports N=0, so a
  system that is serving traffic issues zero additional queries.
- **One query per tick, not per queue.** On the bad night that produced this ticket — 21 queues all at
  N=0 — the old shape would issue 21 identical DISTINCT scans per tick; this issues one. That is
  strictly fewer queries than today, not more, even though the new one has no agent filter.
- **No invalidation to get wrong.** A per-tick cache keyed by time needs a TTL and a clock; a local
  dies with the call. There is no stale window and no shared state between ticks.

If the DISTINCT scan over the tenant's `RTSData_UserStatus` later proves heavy, the honest fix is an
index or a narrow lookup table, not a cache layered over a query nobody has measured yet. I have not
measured it: `dotnet` is absent here and the v4 tree is not mounted, so I state the shape, not a
timing.

## Why Warning at all, and why with both sides

The old branch fired on **every** N=0 with a non-empty roster, so a correctly configured system shouted
all night: 21 queues x 120 ticks is roughly 2500 Warning lines an hour, every one of them saying
nothing is wrong. A Warning that fires when nothing is wrong teaches people to ignore Warnings, and
then the real misconfiguration passes unnoticed too. Printing both sides is the whole value: "N=0" is
already visible on screen; what the log must add is WHY.

## Uniqueness check, honestly stated

`grep -c '^## BEFORE'` → 1, `grep -c '^## AFTER'` → 1. The anchor line
`if (count == 0 && agentList.Length > 0)` appears in both code blocks, so a predicate demanding one
occurrence would be stricter than the question and would go red on a correct fragment.

## Why the first run went red, and what was actually wrong

Coordinator's box of 05:39Z: Unit 445/445, Architecture 8/8, Security 338/340, both failures mine.
The trx (`.measurements/commit-28ce148-wfmgroups_Security_20261014T053941Z.trx`) says:

- `ConfiguredNameAbsentFromTenantData_WarnsWithBothSides` — no entry of level Warning;
- `HealthyTick_LogsNothingAtAll` — found a Debug entry for queue `Q-a3ce87be`.

**The code is not at fault; my tests were.** Measured cause, in the order it was found:

1. `PostgresFixture` starts one container per collection and never truncates between tests — its
   `InitializeAsync`/`DisposeAsync` only create and drop the container (searched for Respawn,
   TRUNCATE, DELETE FROM, ResetAsync: no occurrences). So rows from one test survive into the next.
2. `GetServingAgentCountsAsync` resolves and logs for **every queue of the tenant**, not only the
   queue a test seeded. With all tests sharing `postgres.TenantAId`, a test therefore sees log lines
   produced by another test's leftover queues. That is literally what the Debug line reports: queue
   `Q-a3ce87be` is not the queue the failing test created.
3. The queue id in that Debug line is the proof that the branch itself behaves as designed — it found
   a configured group present in the tenant's data and stayed at Debug, exactly as specified.

Fix: every test now runs on **its own tenant id** (`Guid.NewGuid()` per test instance), so no
leftover queue, roster or StatusGroup value from a neighbouring test can reach it. This is sound
here because `BackendEmulationDbContext` has no query filters and no foreign key to a tenants table
(measured: `HasQueryFilter` 0 occurrences, no `HasOne` on a tenant), so an arbitrary Guid is a fully
isolated tenant. The foreign-tenant test now uses a second generated id rather than `TenantBId`,
which other tests also touch, and `HealthyTick_LogsNothingAtAll` additionally asserts the tenant
holds exactly one queue, so "nothing was logged" cannot be satisfied by an empty tenant.

**My miss behind the miss:** I said all morning that v4 was invisible to me. The v4 working
*directory* is not mounted, but the v4 *branch* lives in this same repository and `git show v4:<path>`
reads it. I could have checked the real code and the real fixture before writing a single test. The
first version of these tests was built against the v3 file and guesses about the fixture; that is why
they went red on their first contact with the truth. Verified now by reading v4 directly: `countSql`
there is identical to v3 (`v4:…/WfmInputQueryService.cs:240-245`), and the 13.10 branch is **not** in
the committed v4 at all (head `28ce148`, 13.10 17:05), so the box ran against shell's uncommitted
working copy.
