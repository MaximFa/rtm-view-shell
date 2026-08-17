# CC Task — WFM N-query 42703 fix (EF scalar-column convention) — 1-line

> C2 live gate (140) caught: WfmRealtimeLoop tick errors every 30s with `42703: column t.Value does not exist`.
> Root (dba, object-store): the N query is `SqlQueryRaw<int>` (SCALAR) — EF wraps it `FROM (<sql>) AS t` and selects
> `t."Value"`, but the scalar is aliased `AS N` → `t.Value` absent → 42703. Not schema drift; a query-shape bug
> that fires on ANY server once real agents make the path execute (dev short-circuits at agents.Count==0 before the SQL).
> Territory: **web**. NO push. Prefix `fix:`.

## STEP 0 — §0.6a integrity (branch v3). §40 reads + role-backend §A/§C. §37 NO push. §0.3 Python+fsync (Edit BANNED). commit.lock.
## STEP 1 — Sync slug backend-0626. Claims:
##   - src/CcDashboard.Infrastructure/Wfm/WfmInputQueryService.cs   (MODIFY: 1 line)
## STEP 2 — BINDING preamble to .coord/cc/backend.md.

## THE FIX — WfmInputQueryService.cs, the N countSql (~line 237)
Change the scalar alias to EF's scalar-column convention `"Value"` (the column EF's wrapper projects for `SqlQueryRaw<int>`):
- OLD: `SELECT COUNT(DISTINCT us.""UserId"")::int AS N`
- NEW: `SELECT COUNT(DISTINCT us.""UserId"")::int AS ""Value""`
(Only this ONE line. Do NOT touch lambdaSql/ahtSql — they use typed records LambdaRow/AhtRow (SqlQueryRaw<LambdaRow>/<AhtRow>, lines ~72/97), which are property-mapped and UNAFFECTED, per dba.)

## Scan confirmation (state in RESULT)
Confirm (object-store) the WFM loop path has NO OTHER scalar `SqlQueryRaw<primitive>` with a non-`Value` alias:
verified — only 3 SqlQueryRaw in WfmInputQueryService.cs: lambda (<LambdaRow>), aht (<AhtRow>) = typed records (fine),
and this N (<int>) = the only scalar, now aliased `AS "Value"`. No others to fix.

## STEP 3 — build0
`dotnet build src/CcDashboard.Web` — Build succeeded, 0 errors.

## STEP 4 — pre-commit + commit (commit.lock) — ONE commit:
`fix: WFM N-query 42703 — alias scalar AS "Value" for EF SqlQueryRaw<int> convention [wfm]`
§0.6 verify -> journal -> lock release -> §0.7 re-sync. NO push.

## STEP 5 — BINDING RESULT: commit hash, the 1-line change, scan confirmation (only N affected), build result, status.
## NOTE: after commit -> devops redeploys to 140; C2 live re-check (loop tick no longer 42703; N populates; store readable) = QA/operator gate.

## Acceptance
- [ ] Exactly ONE line changed: N countSql alias `AS N` -> `AS "Value"`. lambdaSql/ahtSql untouched.
- [ ] RESULT confirms no other scalar SqlQueryRaw<primitive> non-Value alias in the WFM path.
- [ ] build green. Prefix fix:. NO push.

## Git push: do NOT run git push. Commit only.
