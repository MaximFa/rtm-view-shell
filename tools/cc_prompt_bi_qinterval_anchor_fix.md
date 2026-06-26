# CC TASK — Service-anchor fix: AggregateQueueIntervalsAsync → UpdateTime + completed-only (operator-authorized)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП ACTIVE — no-run-without-bless. Operator RE-RULED (2026-06-26T07:20) = B/UpdateTime, WITH full legacy evidence.
> CONTEXT (record so future sessions don't revert): the operator AUTHORED the legacy `GetCallDataByInterval` himself.
> Moving the queue-interval anchor from InQueueDateTime → UpdateTime is a DELIBERATE EVOLUTION by the SP's author,
> consciously superseding his own InQueueDateTime bucketing. This is OPERATOR-AUTHORIZED DIVERGENCE, NOT a defect-vs-legacy.
> Do NOT "correct" it back to InQueueDateTime. (My VERIFY finding: legacy GetCallDataByInterval RTM/H_RTM.sql L18247
> buckets floor(InQueueDateTime,30) + L18256 IsInQueue=0; operator chose UpdateTime over it on purpose.)

## Mandatory — read before starting (NORM-CUR-11 / §40)
Read: .claude/skills/role-bi/role-bi.md (§A CORE incl ⛔ЧП + §C VERIFY) ; .claude/skills/session-coord/session-coord.md (§1/§10).
Reality wins — code/schema over §A.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3 (else checkout v3)
git rev-parse HEAD ; git status --short   # each M: hash-verify WT vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
- CLAIM (file-mode): `src/CcDashboard.Infrastructure/BackgroundServices/HistoricalAggregationService.cs` + `.claude/skills/role-bi/role-bi.md` (§B). No Program.cs / no migration.
- BINDING PREAMBLE → `.coord/cc/bi.md`: `## BINDING <UTC> | spec: bi | directive: tools/cc_prompt_bi_qinterval_anchor_fix.md | status: open` + DIRECTIVE line.

## THE CHANGE — AggregateQueueIntervalsAsync ONLY (4 precise edits; do NOT touch agent method / formulas elsewhere)
Anchor object-store @ HEAD: src/CcDashboard.Infrastructure/BackgroundServices/HistoricalAggregationService.cs.

EDIT 1 — window filter (currently L130-135): anchor InQueueDateTime → **UpdateTime** + ADD **completed filter IsInQueue=false**:
```csharp
.Where(i => i.TenantId == tenantId
         && i.UpdateTime >= from              // was: i.InQueueDateTime >= from
         && i.UpdateTime < to                 // was: i.InQueueDateTime < to
         && i.IsInQueue == false               // NEW completed-only (operator #1; excludes open/unfinished)
         && i.InteractionType == "Call"
         && i.CallType == "External"
         && i.Direction == "Incoming")
```
EDIT 2 — group bucket (currently L138-140): floor by **UpdateTime**:
```csharp
var groups = interactions
    .Where(i => i.UpdateTime.HasValue)                                   // was: i.InQueueDateTime.HasValue
    .GroupBy(i => new { IntervalStart = FloorToInterval(i.UpdateTime!.Value), i.Workgroup });  // was: InQueueDateTime
```
EDIT 3 — abandoned (currently L149): align to legacy `IsAbandoned=1 AND IsCallbackRequest=0`:
```csharp
var abandoned = g.Count(i => i.IsAbandoned == true && i.IsCallbackRequest == false);   // was: i.IsAbandoned == true
```
EDIT 4 — code comment at the method head documenting the operator-authorized UpdateTime anchor + completed-only + abandoned-excl-callback (SOURCE: operator ruling 2026-06-26; GetCallDataByInterval is operator-authored; UpdateTime supersedes InQueueDateTime by design).

UNCHANGED (do NOT touch): offered=g.Count() (now = IncomingCompleted, completed incoming external in the UpdateTime bucket); answered=Count(IsAnswered); answeredInSl / sumWaitAnswered (TimeInQueue) / sumTalk (TalkTime) — per-interaction, anchor-independent; queueLookup; DeleteQueueIntervalsAsync (operates on IntervalStart, anchor-agnostic); AggregateForTenantAsync from/to flooring; SL threshold. AGENT method AggregateAgentIntervalsAsync — UNCHANGED (operator #2, StartTime correct).

## ACCEPTANCE (DoD)
1. Build clean (Soma /ops/build = 0 OR dotnet build).
2. Unit/smoke: with seeded RTSData where some rows IsInQueue=true (open, year-10000 InQueueDateTime sentinel) and some IsInQueue=false (completed) → AggregateQueueIntervalsAsync (a) buckets by UpdateTime, (b) EXCLUDES the open rows (no year-10000 IntervalStart row), (c) abandoned excludes IsCallbackRequest=true. Keep light; the functional proof is the backfill run on real 234.
3. **VC28 REFRAMED** (note in prompt + report): queue-interval data INTENTIONALLY diverges from old GetCallDataByInterval (operator-authorized UpdateTime) → acceptance = correctness per UpdateTime+completed-only, NOT byte-match to the old InQueueDateTime report. Agent side byte-unchanged.
4. NO push.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 (native CC edits directly; object-store-verify the edited lines post-commit).
- commit.lock (open "x", retry 5×60s, phantom-safe) → `bash tools/pre-commit-check.sh` → `git add src/CcDashboard.Infrastructure/BackgroundServices/HistoricalAggregationService.cs` → commit `fix: queue-interval anchor UpdateTime + completed-only (IsInQueue=0) + abandoned excl callback (operator-authorized) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT: `commit <hash> . AggregateQueueIntervalsAsync UpdateTime anchor + IsInQueue=false + abandoned&&!IsCallbackRequest . agent unchanged . build 0 . status done . verified: object-store . NO push`.
- §0.6b CAPTURE → role-bi §B (git add -f), dated SOURCE-pinned:
  `2026-06-26 · queue-interval hist anchor = UpdateTime + completed-only IsInQueue=false + abandoned(IsAbandoned&&!IsCallbackRequest). OPERATOR-AUTHORED EVOLUTION (operator authored legacy GetCallDataByInterval which buckets floor(InQueueDateTime,30)+IsInQueue=0; operator ruled UpdateTime supersedes it 2026-06-26) — do NOT revert to InQueueDateTime; VC28 intentionally diverges from the old SP. · SOURCE: RTM/H_RTM.sql GetCallDataByInterval L18247/18256/18267 + operator ruling 2026-06-26 · status: active`

## DO NOT
- Do NOT change the agent method, the per-interaction formulas (offered/answered/SL/wait/talk), Delete logic, or any other method.
- Do NOT revert the anchor to InQueueDateTime (operator-authorized UpdateTime).
- Do NOT touch Program.cs / run a migration / `git push`.

## SEQUENCE
THIS service-fix lands FIRST → then the backfill (tools/cc_prompt_bi_hist_backfill.md REV3) reuses the FIXED RunAggregationAsync → hist_* populated (UpdateTime, completed-only) → DATA-PROOF → View. DATA-PROOF stays gated.
