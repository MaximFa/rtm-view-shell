# CC TASK — hist_* one-time BACKFILL from loaded RTSData_* (Route 1a — reuse RunAggregationAsync)

> Owner: role-bi (bi-0626). Branch: v3. status: REV3 (UpdateTime anchor — operator re-rule 2026-06-26T07:20; supersedes REV2 sentinel-cap) — self-§4 PASS (bi) → AWAITS coordinator re-§4-bless.
> DEPENDS ON: the service-anchor fix (tools/cc_prompt_bi_qinterval_anchor_fix.md) landing FIRST — this backfill REUSES the FIXED RunAggregationAsync (UpdateTime + completed-only IsInQueue=0). Do NOT run the backfill before the service-fix is committed.
> ⛔ ЧП ACTIVE — no-run-without-bless. Coordinator RULED Route 1a (inbox 2026-06-26T01:35).
> PROBLEM: HistoricalAggregationService only aggregates [UtcNow-24h,UtcNow] on startup + [UtcNow-2h,UtcNow] every 2h
> (object-store: L27/39-40, L53-54). The 234 prod-mirror loads RAW RTSData_* with HISTORICAL timestamps → those are
> NEVER aggregated into hist_* by app start → the DATA-PROOF (reads hist_*, ABORT-if-empty) would clean-abort.
> GOAL: a ONE-TIME, guarded, idempotent BACKFILL that REUSES the EXISTING `RunAggregationAsync(from,to)` over the loaded
> data's full historical [min,max] range, so hist_queue_intervals/hist_agent_intervals get populated — seed==service BY
> CONSTRUCTION (no formula duplication; role-bi §A#8). After it runs once, normal 24h/2h behavior resumes UNCHANGED.

## Mandatory — read before starting (NORM-CUR-11 / §40)
Read file: .claude/skills/role-bi/role-bi.md   (§A CORE incl ⛔ЧП block + §C VERIFY vs current code)
Read file: .claude/skills/session-coord/session-coord.md   (§1 runbook, §10 commands)
Reality wins — if §A disagrees with code, the code is right.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim (§0.6a/§0.6b)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD          # MUST be v3 (else git checkout v3)
git rev-parse HEAD                        # record base SHA (object-store, §0.5)
git status --short                        # for each M: hash-verify WT vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
- CLAIM (file-mode): `src/CcDashboard.Infrastructure/BackgroundServices/HistoricalAggregationService.cs` (mine, inherited)
  + `.claude/skills/role-bi/role-bi.md` (§B lesson). NO Program.cs (this design AVOIDS it → no overlap with shell [web]).
- BINDING PREAMBLE → append to `.coord/cc/bi.md` (Python+fsync):
  `## BINDING <UTC> | spec: bi | directive: tools/cc_prompt_bi_hist_backfill.md | status: open`
  `### DIRECTIVE: one-time guarded hist_* backfill reusing RunAggregationAsync over loaded RTSData_* [min,max]. claim HistoricalAggregationService.cs. gate: coordinator §4-bless. fix:/feat: commit, commit.lock, NO push.`

## THE CHANGE (single file: HistoricalAggregationService.cs) — REUSE, do NOT reinvent
**Constraint:** do NOT alter the existing aggregation formulas/methods (RunAggregationAsync / AggregateForTenantAsync /
AggregateQueueIntervalsAsync / AggregateAgentIntervalsAsync) — REUSE them verbatim. Only ADD a guarded one-time pre-pass.

1. **Inject IConfiguration** into the primary constructor:
   `public class HistoricalAggregationService(IServiceScopeFactory scopeFactory, ILogger<HistoricalAggregationService> logger, IConfiguration config) : BackgroundService`
   (the only ctor change; add `using Microsoft.Extensions.Configuration;` if needed).

2. **Guarded one-time backfill in ExecuteAsync, AFTER the 30s delay and BEFORE the startup-24h `RunAggregationAsync(startupFrom, startupTo, ...)`:**
   - Read guard: `var doBackfill = config.GetValue<bool>("Historical:BackfillOnStartup");` (absent → false → ZERO behavior change in normal/prod boots).
   - If `doBackfill`:
     a. Derive the loaded data window across the emulation source tables (new private helper, its own DI scope like RunAggregationAsync):
        - **ANCHOR = UpdateTime (operator re-rule 2026-06-26T07:20).** Derive the loop range from the SAME columns the FIXED service now uses: queue side = `min/max` of `beDb.RtsDataInteractions.UpdateTime` over COMPLETED rows (`IsInQueue == false`); agent side = `min/max` of `beDb.RtsDataUserStatusLogs.StartTime`. Over ALL tenants. Take overall MIN/MAX of the non-null values across BOTH.
        - **No sentinel cap (REV2 DROPPED, moot):** UpdateTime is clean — dba Inspect: no year-10000 sentinel; real completed range = 2026-06-02 .. 2026-06-26 = single month June 2026. The year-10000 sentinel lived in InQueueDateTime which is NO LONGER the anchor; `IsInQueue == false` (completed) also excludes those rows. Keep a sane lower guard `>= '2000-01-01'` defensively.
        - If no completed rows (both null) → log WARNING "backfill: no completed RTSData rows, skipping" and continue to normal startup (no abort).
     b. Log `logger.LogWarning("HistoricalAggregationService: ONE-TIME BACKFILL {From:O}..{To:O} (Historical:BackfillOnStartup=true)", min, max);`
     c. **Iterate MONTH-by-MONTH** from `new DateTime(min.Year, min.Month, 1, 0,0,0, DateTimeKind.Utc)` to `> loopEnd`, calling the EXISTING `await RunAggregationAsync(monthStart, monthStart.AddMonths(1), stoppingToken);` for each month. **Belt-and-suspenders ceiling (defense-in-depth on top of the SQL cap):** `var loopEnd = max < DateTime.UtcNow.AddMonths(1) ? max : DateTime.UtcNow.AddMonths(1);` — so even if a sentinel ever slipped past the SQL cap, the loop can NEVER run past ~now. (Month chunking bounds memory — the aggregation pulls a window into memory — and aligns with the monthly RANGE partitions. RunAggregationAsync already loops all tenants + does idempotent DELETE+INSERT per window.)
     d. Log `LogInformation("HistoricalAggregationService: BACKFILL complete ({Months} monthly windows). Clear Historical:BackfillOnStartup to avoid re-running on next boot.", n);`
   - Then proceed to the EXISTING normal startup-24h aggregation + the periodic loop, UNCHANGED.

3. **Guard semantics (one-time):** runs ONLY when `Historical:BackfillOnStartup=true` (operator sets it in the mirror
   env's appsettings/env for ONE boot, then clears it). It is IDEMPOTENT (DELETE+INSERT per window), so a stray re-run
   is CORRECT (just recomputes — harmless). Document this in an XML/code comment. NO sentinel/watermark needed for v1.
   This is NOT 1b (it does NOT widen the permanent startup window; absent flag = today's behavior exactly).

4. **Partitions:** do NOT add partition logic. Historical-month rows land in the hist_* DEFAULT partitions
   (dba-confirmed they exist). `fn_hist_ensure_partitions` is now-relative and cannot create arbitrary old months → DEFAULT
   is the intended sink for historical backfill. (Caveat — flagged to dba: a later monthly `CREATE ... PARTITION OF` for a
   month that already has DEFAULT rows would error; acceptable for a one-time mirror proof.)

## ACCEPTANCE (DoD)
1. Builds clean (Soma /ops/build = 0 OR dotnet build).
2. **Flag ABSENT/false → ZERO behavior change**: startup log + 24h/2h windows identical to today (no backfill runs).
2b. **Range sane**: derived from UpdateTime over completed rows → loop covers June 2026 (single month, 2026-06-02..2026-06-26) — verify the backfill log shows a sane From..To, no year-10000 endpoint (UpdateTime clean; sentinel was in InQueueDateTime, no longer the anchor).
3. **Flag true on a DB with historical RTSData_*** → on boot, the one-time backfill runs month-by-month over [min,max];
   afterward `SELECT COUNT(*) FROM hist_queue_intervals WHERE "TenantId"=<t>` > 0 AND `... hist_agent_intervals ...` > 0
   for the loaded tenant (cite counts). Idempotent: a second boot-with-flag yields the SAME counts.
4. Unit/smoke: a focused test that the guard is OFF by default (no backfill call when flag absent) — keep it light; the
   functional proof is the live mirror boot (QA floor; coordinator visual-verifies downstream).
5. NO push (bundled barrier HELD).

## SEQUENCE (this is the missing seam)
backend seeder-gate (RUN FIRST) → dba Load (RTSData_* + structure) → **service-anchor fix** (tools/cc_prompt_bi_qinterval_anchor_fix.md — UpdateTime+completed-only, lands FIRST) → **THIS backfill** (operator sets
`Historical:BackfillOnStartup=true`, boots Shell once → hist_* populated → clears flag) → app running normally → DATA-PROOF
seed (tools/cc_prompt_bi_dataproof_seed.md, blessed) → operator opens in View → 5 widgets render REAL data.

## CROSS-DEPS / flags to coordinator
- dba: UpdateTime CLEAN on 234 (no sentinel; completed range 2026-06-02..2026-06-26 = single month). The year-10000 sentinel is in InQueueDateTime (no longer anchor) + excluded by IsInQueue=false. DEFAULT-partition coverage
  for historical months (rows sink to DEFAULT). If timestamps were re-stamped to recent, the span shrinks (still correct).
- backend: NOT required (no Program.cs — design is contained in HistoricalAggregationService.cs). Flag if §4 prefers a CLI
  subcommand instead (that WOULD touch Program.cs = shell [web] claim → needs queue/coordination).
- NO new migration (hist_* + fn_* already exist from 20260621080000).

## STEP 5 — COMMIT + binding RESULT + re-sync
- §0.3 write discipline (native CC on Windows edits directly; object-store-verify the edited region post-commit).
- commit.lock (atomic open "x", retry 5×60s, content-based phantom check) → `bash tools/pre-commit-check.sh`
  → `git add src/CcDashboard.Infrastructure/BackgroundServices/HistoricalAggregationService.cs`
  → commit `feat: one-time guarded hist_* backfill reusing RunAggregationAsync (Route 1a) [bi]`
  → §0.6 post-commit verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync from HEAD.
- BINDING POSTAMBLE → append RESULT to `.coord/cc/bi.md`:
  `### RESULT: commit <hash> . file HistoricalAggregationService.cs (+IConfiguration ctor + guarded month-loop backfill) . build <0> . flag-off no-change verified . status done|failed . verified: object-store . NO push`
  status: done.
- §0.6b CAPTURE → role-bi §B: dated SOURCE-pinned lesson (24h-startup-window means loaded historical RTSData_* needs an
  explicit one-time backfill; reuse RunAggregationAsync, never duplicate formulas). git add -f.

## DO NOT
- Do NOT change the existing aggregation formulas/methods (REUSE verbatim).
- Do NOT touch Program.cs (shell [web] claim) — keep the change inside HistoricalAggregationService.cs.
- Do NOT widen the permanent StartupLookback (rejected 1b — every-boot full re-aggregation).
- Do NOT run any migration / `git push`.
