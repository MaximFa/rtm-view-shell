# CC task — F-QA-1: /reports inclusive-To date boundary + CAPTURE debt (role-shell) — DRAFT for coordinator §4-review (do NOT execute pre-§4)
> Per IRON #9 / §26.8: SUBMITTED for §4-review BEFORE execution. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> QA GREEN on 9c63ba4 (zero-data fix, UI=DB verified). NEW off-by-one found in the functional gate (test-5-0607 F-QA-1): the report date range upper bound is EXCLUSIVE -> the To day's rows are DROPPED. Default range = today-7..today, so TODAY's data NEVER shows until tomorrow. Proof (Soma /db/query): hist_agent_intervals 16-23/06 = 720; 23rd = 80; UI showed 640 (= 16-22 only). 9c63ba4 fixed DateTime.Kind but not inclusivity.

## INIT — branch v3 + role-shell §A/§C + §40
- **BRANCH RULE:** reports = **v3**. FIRST `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 + `git rev-parse v3` (OBJECT-STORE, never mount `git status`). Do NOT cross to v2-backend.
- §0.2 v3 integrity: `cat .git/HEAD`=`ref: refs/heads/v3`. Mount may fail `git rev-parse HEAD` on v3 (L-SC-04) — verify natively, do NOT escalate.
- role-shell INIT §A + §C-green. POST-VERIFY by reliable floor (cat + git grep v3 + git hash-object), NOT -f/-s stat.

## §42.6 sync — slug shell-0609 (file-mode)
- S1: `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> STOP if match. (NB: a CLOSED tombstone contains the literal "No FREEZE ACTIVE" — read the FULL line; only an OPEN barrier with state:FREEZE ACTIVE counts.)
- S2 claims (coord_check_claims shell-0609 each): the 4 report pages (QueueIntervalReport / QueueWaitTimeReport / AgentMonthlyReport / AgentShiftDetailReport .razor) + ReportFilterBar.razor.
- S3 commit.lock around git add/commit (owner shell-0609). S4 cc_post_commit.sh. S5 NO push.
- §0.3 Edit BANNED — Python read/modify/write + os.fsync; verify by cat/git.
- Binding PREAMBLE/POSTAMBLE -> .coord/cc/shell.md.
- DO NOT touch repo/handler. The repo filters `IntervalStart < to` and STAYS exclusive by design — we shift the bound PASSED to it, in the .razor. If you find the bound is actually computed in handler/repo (it is not, per object-store) and can't be done in .razor, STOP and flag coordinator (bi/backend territory).

## ROOT / GROUNDING (object-store, exact anchors on v3)
Each LoadData already UTC-tags the bounds (9c63ba4). The `to` tag line is the fix site:
- QueueIntervalReport.razor:86  `to = DateTime.SpecifyKind(to, DateTimeKind.Utc);`
- QueueWaitTimeReport.razor:88  `to = DateTime.SpecifyKind(to, DateTimeKind.Utc);`
- AgentMonthlyReport.razor:92   `to = DateTime.SpecifyKind(to, DateTimeKind.Utc);`
- AgentShiftDetailReport.razor:94 `to = DateTime.SpecifyKind(to, DateTimeKind.Utc);`
ReportFilterBar.razor holds From/To via `@bind` date `<input>` (lines 7/11) — it does NOT compute the bound. So NO change needed there; the inclusivity shift is purely at the 4 LoadData. (Keep ReportFilterBar in claims only as territory; expect zero edits.)

## THE WORK — inclusive To (4 LoadData)
In each of the 4 report pages, change the `to` tag line to add one day so the query's exclusive upper covers the whole To day:
```csharp
to = DateTime.SpecifyKind(to.Date.AddDays(1), DateTimeKind.Utc);
```
(Leave `from = DateTime.SpecifyKind(from, DateTimeKind.Utc);` as-is. repo `< to` unchanged -> now includes all of the original To day.)
The UI-displayed To (ReportFilterBar bound value) is UNCHANGED — only the query bound shifts. Do nothing else.

## CAPTURE DEBT (mandatory this commit — 9c63ba4 missed it; coordinator-ordered)
Append BOTH lessons to role-shell §B (`git add -f .claude/skills/role-shell/role-shell.md`):
1. (9c63ba4 debt) "Blazor date<input>/DateTime.Today bind Kind=Local/Unspecified; Npgsql 8 THROWS writing them to a timestamptz filter; a bare catch made every report silently empty. RULE: SpecifyKind(Utc) at the query chokepoint + UtcNow.Date defaults; NEVER a bare catch in a data-load path — Logger.LogError(ex)."
2. (this) "Date-range UI 'To' is a whole-day bound but the repo filters IntervalStart < to -> exclusive upper drops the To day (default today-7..today hides TODAY). RULE: for an inclusive To against a `< to` query, pass To.Date.AddDays(1) as the exclusive upper; shift the bound passed, not the repo predicate."

## VERIFY (build-cite or honest 'not run')
- Object-store: all 4 `to` tag lines now `SpecifyKind(to.Date.AddDays(1), DateTimeKind.Utc)`; `from` lines unchanged; ReportFilterBar unchanged; no repo/handler edits (`git diff --name-only` = only the 4 report .razor + role-shell.md).
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line; else honest "BUILD: not run (no dotnet)".** No new C# member -> no @inject/@using change.

## ACCEPTANCE (functional, QA floor — NOT self-certified)
After fix, /reports default range shows TODAY's rows too: Agent Shift Detail over 16-23/06 returns 720 (was 640) — the To-day (23rd, 80 rows) now included. Build 0. test-5-0607 re-runs the gate.

## Commit (fix:, NO push) under commit.lock
pre-commit-check -> git add (4 report .razor + role-shell.md CAPTURE -f) -> commit -m "fix: /reports inclusive-To date boundary — query upper = To.Date.AddDays(1) so To-day (incl today) is shown (F-QA-1) [shell-0609]" -> §0.6 post-commit (git grep v3) -> cc_post_commit.sh shell-0609 <hash> -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; 4 LoadData to=To.Date.AddDays(1); ReportFilterBar untouched; no repo/handler; 2 §B CAPTURE lessons appended; build cite OR 'not run'; NO push. verified: object-store.

## Report (chat): commit hash; the 4 edits via git grep v3; build line OR honest not-run; CAPTURE debt settled (2 §B lessons); restate functional acceptance (720 not 640) = test-5/QA floor. NO push.
