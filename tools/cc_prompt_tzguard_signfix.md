# CC task — TZ-guard SIGN FIX: numeric offsets must use INTERVAL (AT TIME ZONE inverts bare offset strings)
> §4-PASS (coordinator 2026-07-16) — CASE offset->::interval (sign-correct) / name->bare (Israel-safe), logic verified vs Postgres semantics. CONDITION: PROBE the CASE on 140 real rows per zone (+02 near-midnight, -04, Israel, empty) = ours_local_date correct, BEFORE apply/seal (self-§4 missed 2 prior 140 bugs). RUN-CLEARED.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-backend/role-backend.md
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
Only after all: proceed.

## Step 0 — INTEGRITY
cd "D:\Claude\Projects\RTM View Shell"; git status --short
Every M file: if HEAD line-count > working → `git show HEAD:"$f" > "$f"`. sync.

## Git push — do NOT push.

## BINDING preamble
Append to `.coord/cc/backend.md`:
`## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_tzguard_signfix.md | status: open`
`### DIRECTIVE: fix TZ sign bug in RTSData_GetInteractions load-guard — offset strings via INTERVAL, names bare. Claim: db/functions/02_rtsdata_functions.sql. prefix db.`

## ROOT (data-proven, 140)
The prior guard (0b07651) filters by `("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone",''),'UTC'))::date`. Postgres `AT TIME ZONE '<numeric-offset-text>'` (e.g. '+02:00','-04:00') INVERTS the sign → a +02:00 row at 00:00 UTC maps to the PREVIOUS local day. Evidence: UpdateTime 2026-07-16 00:00 UTC, TimeZone +02:00 → agent-local should be 02:00 (16/07) but the expression yields 15/07. Net: undercount (ours_today=1899 vs legacy 3371); +02:00 rows near midnight wrongly excluded. TimeZone column on 140 = mixed offsets (+02:00,-04:00,-01:00,+00:00) + a few names ('Israel') + NULL/empty.

## FIX (correct sign for offsets, keep names working)
For offset-format values (`^[+-]\d{2}:\d{2}$`) apply as an INTERVAL (does NOT invert). For named zones ('Israel','UTC',...) apply the value as a zone name. NULL/empty → 'UTC'.

## CLAIM (touch ONLY this)
- db/functions/02_rtsdata_functions.sql

## CHANGE — RTSData_GetInteractions(p_on_date text, p_tenant_id uuid) WHERE
Replace the current WHERE (the `("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone",''),'UTC'))::date = (now() AT TIME ZONE ...)::date` block) with:
```
    FROM "RTSData_Interaction"
    WHERE "TenantId" = p_tenant_id
      AND (
            (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
                  THEN ("UpdateTime" AT TIME ZONE (("TimeZone")::interval))
                  ELSE ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
             END)::date
          = (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
                  THEN (now()        AT TIME ZONE (("TimeZone")::interval))
                  ELSE (now()        AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
             END)::date
          )
    ORDER BY "Segment", "UpdateTime" DESC;
```
Notes:
- `'+02:00'::interval` = +2h; `AT TIME ZONE INTERVAL '+02:00'` = UTC+2 (correct, no inversion). Offsets go through the interval branch.
- Named zones ('Israel','UTC') go through the bare-text branch (DST-correct for 'Israel'); NULL/'' → 'UTC'.
- Keep the SELECT column list, function signature (p_on_date unused), RETURNS TABLE, and ORDER BY unchanged. FUNCTION kind preserved (CREATE OR REPLACE FUNCTION, §33.8). Do NOT touch any other function.

## CONSTRAINTS
- db/functions/02_rtsdata_functions.sql ONLY. No C#/legacy/adapter/Shell. No push. §0.3 Python+fsync. After write: sync; tail -3; wc -l.

## ACCEPTANCE
- WHERE now uses the CASE (offset→interval, else→bare zone). Signature/RETURNS/ORDER BY/SELECT unchanged.
- Regex `^[+-][0-9]{2}:[0-9]{2}$` matches '+02:00'/'-04:00' etc.
- SQL parse-valid (careful review; DBA applies).
- pre-commit-check.sh green.

## COMMIT (commit.lock)
`bash tools/pre-commit-check.sh` → if exit 1 restore+retry.
prefix: `db: fix TZ sign bug in interaction load-guard — offset strings via INTERVAL (AT TIME ZONE inverts bare offsets), names bare`
NO push. Journal + lock release + §0.7 re-sync.

## BINDING postamble
Append RESULT to `.coord/cc/backend.md`: commit hash, new WHERE quoted, verified: object-store.

## NOTE (coordinator/DBA)
- Apply on 140 (CREATE OR REPLACE, body-only) → re-verify counts match legacy for +02:00 near-midnight rows.
- Same sign fix will be needed for the RTSData_getUsersStatuses TZ-guard when that follow-up lands.
- Mirrors reconcile via Export-All.
