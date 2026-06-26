# CC TASK — R1: DateTime Kind=Utc on the report date window (timestamptz fix)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП — no-run-without-bless. SYMPTOM (operator): QueueInterval widget errors:
> "Cannot write DateTime with Kind=Unspecified to PostgreSQL type 'timestamp with time zone', only UTC is supported."
> The date-picker gives From/To with Kind=Unspecified; the handler's from/toExclusive go into LINQ vs timestamptz → Npgsql refuses.
> NOTE (object-store): this fix is NOT in HEAD yet (handler L57-58 still `query.From.Date` / `query.To.Date.AddDays(1)` — no SpecifyKind).
> It works in the operator's running binary (applied locally, uncommitted) → commit it properly.

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git rev-parse HEAD ; git status --short   # M: hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
CLAIM (file-mode): src/CcDashboard.Application/Handlers/RunReportWidgetQueryHandler.cs + .claude/skills/role-bi/role-bi.md (§B).
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## THE CHANGE — RunReportWidgetQueryHandler.cs (one point, covers all 5 widget types)
Replace (currently L57-58):
```csharp
var from = query.From.Date;
var toExclusive = query.To.Date.AddDays(1);
```
with:
```csharp
var from = DateTime.SpecifyKind(query.From.Date, DateTimeKind.Utc);
var toExclusive = DateTime.SpecifyKind(query.To.Date.AddDays(1), DateTimeKind.Utc);
```
Semantics: picker dates are date-only/no-TZ; hist data is aggregated on UTC interval boundaries → treat the chosen date as a UTC boundary. Use **SpecifyKind (NOT ToUniversalTime)** — mark Kind, do NOT shift the value. `from`/`toExclusive` are shared by all 5 types (the switch at ~L65-69) → this one fix covers QueueInterval/QueueWaitTime/AgentMonthly/AgentShiftDetail/Distribution.
VERIFY: grep this handler + HistoricalReportRepository for any OTHER `.Date`/DateTime that flows into a timestamptz comparison (IntervalStart >= / <) with Kind=Unspecified — confirm none remain unmarked.

## ACCEPTANCE (DoD)
1. Build 0. 2. Superadmin/019e03e9 opens a QueueInterval report over a date range WITH data (e.g. 14-15/06) → widget renders REAL rows, NO Kind error. 3. No other Unspecified DateTime reaches a timestamptz compare on the report path. 4. NO migration. 5. NO push.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native CC; object-store-verify the 2 lines post-commit.
- commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed) → commit `fix: report date window DateTime.SpecifyKind Utc (timestamptz) [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT (the 2 lines, build, object-store verify, status done).
- §0.6b CAPTURE → role-bi §B (git add -f): `2026-06-26 · date-picker From/To are Kind=Unspecified; before a timestamptz LINQ compare (hist IntervalStart) mark with DateTime.SpecifyKind(..., Utc) (NOT ToUniversalTime — don't shift) — else Npgsql "Cannot write DateTime with Kind=Unspecified". One fix in RunReportWidgetQueryHandler covers all 5 widget types (shared from/toExclusive). · SOURCE: RunReportWidgetQueryHandler L57-58 + coordinator 2026-06-26 · status: active`

## DO NOT
- Do NOT use ToUniversalTime (no value shift). Do NOT touch the widget dispatch / repos / other handlers. NO migration / NO push.
