# CC task — /reports zero-data fix: DateTime.Kind/UTC + un-swallow LoadData catch (role-shell) — DRAFT for coordinator §4-review (do NOT execute pre-§4)
> Per IRON #9 / §26.8: SUBMITTED for §4-review BEFORE execution. Owner: role-shell. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37).
> ROOT (DBA, object-store conclusive): /reports renders 4 tabs but ZERO data. Data is present + correct-tenant + scope=Full + range overlaps. Report .razor pages pass `DateTime.Today` (Kind=Local/Unspecified) as From/To; HistoricalReportRepository filters `IntervalStart` (timestamptz) -> Npgsql 8 THROWS "Cannot write DateTime with Kind=Local to timestamp with time zone"; a BARE `catch { _rows=null; _totalCount=0; }` in LoadData SWALLOWS it -> every tab shows zero, silently, all session.

## INIT — branch v3 + role-shell §A/§C + §40
- **BRANCH RULE:** reports line = **v3**. FIRST `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 + `git rev-parse v3` (OBJECT-STORE, never mount `git status`). Do NOT cross to v2-backend.
- §0.2 v3 integrity: `cat .git/HEAD`=`ref: refs/heads/v3`; `cat .git/refs/heads/v3` resolves. Mount may fail `git rev-parse HEAD` on v3 (L-SC-04) — verify natively, do NOT escalate as corruption.
- role-shell INIT §A + §C-green. POST-VERIFY by reliable floor (cat + git show v3:<f> + git hash-object), NOT -f/-s stat.

## §42.6 sync — slug shell-0609 (file-mode, my territory)
- S1: `cat .coord/push/request.md | grep -q "FREEZE ACTIVE"` -> STOP if match.
- S2 claims (coord_check_claims shell-0609 each):
  - src/CcDashboard.Web/Components/Reports/QueueIntervalReport.razor
  - src/CcDashboard.Web/Components/Reports/QueueWaitTimeReport.razor
  - src/CcDashboard.Web/Components/Reports/AgentMonthlyReport.razor
  - src/CcDashboard.Web/Components/Reports/AgentShiftDetailReport.razor
  - src/CcDashboard.Web/Components/Reports/ReportFilterBar.razor
- S3 commit.lock around git add/commit (owner shell-0609). S4 cc_post_commit.sh. S5 NO push.
- §0.3 Edit BANNED — Python read/modify/write + os.fsync; verify by cat/git.
- Binding PREAMBLE/POSTAMBLE -> .coord/cc/shell.md.
- DO NOT touch handlers/repo (HistoricalReportRepository / HistoricalReportHandlers) — that is bi/backend territory. If razor-level UTC normalization proves insufficient, STOP and flag coordinator BEFORE editing app/infra.

## GROUNDING (object-store — exact anchors)
All 4 report pages inject `@inject IMediator Mediator` + `@inject IStringLocalizer<SharedResources> L` (NO ILogger yet). Each has a LoadData with a `DateTime.Today` default and a bare catch:
- QueueIntervalReport.razor: default@72 `LoadData(DateTime.Today.AddDays(-7), DateTime.Today, 50,1,null)`; LoadData@80; `Mediator.Send`@87; bare `catch { _rows=null; _totalCount=0; }`@91-94.
- QueueWaitTimeReport.razor: default@74 (AddDays(-7)); same LoadData+catch shape.
- AgentShiftDetailReport.razor: default@80 (AddDays(-7)); same.
- AgentMonthlyReport.razor: default@78 (AddMonths(-3)); same.
- ReportFilterBar.razor: `[Parameter] public DateTime From {get;set;} = DateTime.Today.AddDays(-7);`@65; `To = DateTime.Today;`@66.

## THE WORK — two fixes, all 5 files

### FIX (a) — UTC-normalize date bounds (belt + suspenders)
1. **Defaults:** replace every `DateTime.Today` with `DateTime.UtcNow.Date` (KEEP the offsets: `.AddDays(-7)` / `.AddMonths(-3)`). Applies to the 4 LoadData defaults + ReportFilterBar From/To (@65/@66).
2. **Chokepoint normalize in each LoadData** (handles filter-bar-supplied dates too — date `<input>` binds Kind=Unspecified): at the TOP of LoadData, before `Mediator.Send`, force UTC kind:
   ```csharp
   from = DateTime.SpecifyKind(from, DateTimeKind.Utc);
   to   = DateTime.SpecifyKind(to,   DateTimeKind.Utc);
   ```
   (SpecifyKind, not ToUniversalTime — the dates are date-only bounds, we tag them UTC, not shift them.)

### FIX (b) — un-swallow the LoadData catch (NON-NEGOTIABLE: must LOG)
In each of the 4 report pages:
1. Add `@using Microsoft.Extensions.Logging` and `@inject ILogger<TPage> Logger` (TPage = the page's component type, e.g. `ILogger<QueueIntervalReport>`). **CS0246 guard:** confirm the using + the generic type name match the .razor component name (the @code partial class), else build breaks.
2. Replace the bare `catch { _rows=null; _totalCount=0; }` with:
   ```csharp
   catch (Exception ex)
   {
       Logger.LogError(ex, "Report load failed ({Report})", nameof(<ThisReport>));
       _rows = null; _totalCount = 0;
       // optional: set a private _error string to surface a friendly message in the UI empty-state
   }
   ```
   Never swallow silently again — this is what hid the bug all session.

## VERIFY (build-cite or honest 'not run')
- Object-store: zero `DateTime.Today` left under Components/Reports (`grep -rn "DateTime.Today" src/CcDashboard.Web/Components/Reports` = empty); each LoadData has the SpecifyKind(Utc) pair before Mediator.Send; each of the 4 pages injects ILogger and the catch calls Logger.LogError(ex,...); ReportFilterBar From/To default = UtcNow.Date.
- **Run `dotnet build src/CcDashboard.Web` if available -> PASTE 0-Error line; else honest "BUILD: not run (no dotnet)".** @inject ILogger<TPage>/@using guard (CS0246).
- NO edits outside the 5 claimed razor files (`git diff --name-only` confirms).

## ACCEPTANCE (FUNCTIONAL — v3 gate; operator/QA floor)
On a fresh-DB dev run with the seed, env != Development is NOT required here (this is a query path, not the backplane) — open /reports and each tab MUST show data: 378 queue rows (Q1/Q5 over the default range) + 640 agent rows (A4/A5). No silent zeros. Build 0 errors. Idempotent.

## §0.6b CAPTURE -> role-shell §B (git add -f) — real lesson:
"Blazor date `<input>` / DateTime.Today bind Kind=Local/Unspecified; Npgsql 8 THROWS writing them to a timestamptz filter -> a bare catch made every report silently empty all session. RULE: normalize date bounds to DateTimeKind.Utc (SpecifyKind) at the query chokepoint + default to UtcNow.Date; NEVER write a bare catch in a data-load path — always Logger.LogError(ex)."

## Commit (fix:, NO push) under commit.lock
pre-commit-check -> git add (the 5 razor + role-shell.md CAPTURE -f) -> commit -m "fix: /reports zero-data — UTC-normalize date bounds (Npgsql timestamptz Kind=Local throw) + log LoadData catch (was silent) [shell-0609]" -> §0.6 post-commit (git show v3:<f>) -> cc_post_commit.sh shell-0609 <hash> -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; 5 razor (4 LoadData UTC+ILogger-catch + ReportFilterBar defaults); zero DateTime.Today left; build cite OR 'not run'; CAPTURE; NO push. verified: object-store.

## Report (chat): commit hash; the edits via git show v3; build line OR honest not-run; restate FUNCTIONAL acceptance (378 queue + 640 agent rows on seed) = operator/QA floor; v3-unblocking. NO push.
