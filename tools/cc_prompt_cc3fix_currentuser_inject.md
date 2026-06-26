# CC task — CC-3 COMPILE FIX: missing @inject ICurrentUserAccessor (d83517c does NOT compile)
> §4-PASS by coordinator-0612 2026-06-17T09:42Z (Маяк 09:38 DEFECT). Owner: role-shell. Executor: native CC. Commit `fix:`. **NO push** (HEAD broken until this lands).
> OBJECT-STORE FACT: ScreenEditorPage.razor:2263 `CurrentUser?.UserId` (added by CC-3 T3 localStorage §41), but @inject block L4-7 has NO ICurrentUserAccessor -> CS0103. The out-of-band build-runner already patched the WORKING TREE (real Windows FS) with `@inject ICurrentUserAccessor CurrentUser` + `@using CcDashboard.Domain.Interfaces`; this is UNCOMMITTED. Commit it WITH a real build.
> CRITICAL: a "build 0 err" claim must cite an ACTUAL `dotnet build` run. CC-3 falsely claimed 0 err WITHOUT building (2nd unverified build/works claim today).

## INIT (role-shell §A + §C-green) + §40 reads.

## STEP 0 — §0.2 integrity sweep FIRST (RELIABLE FLOOR: ls+cat+git, NOT -f/-s stat)
Many M files on the tree (CLAUDE.md, MetricsPage.razor, db/*, role-skills = PD-007 drift / mount false-M). Hash-verify; restore truncated from HEAD if real. **Stage ONLY src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor.**
MOUNT NOTE: mount git-diff may show SEP tail truncated at `PlacedWidgets.Add(ne` — operator real-FS confirmed file COMPLETE (L-SC-04 mount artifact, NOT corruption). Disambiguate by operator real-FS, do not restore from a mount-only "truncation".

## STEP 1 — ensure the fix is in ScreenEditorPage.razor (verify WT real-FS, add if absent)
The @inject block (~L4-7) must contain: `@inject ICurrentUserAccessor CurrentUser`
The @using block (~L8-12) must contain: `@using CcDashboard.Domain.Interfaces`
If the out-of-band repair is already present (likely) -> leave as-is. If absent -> add both (Python+fsync, §0.3). Verify by `cat`/grep (reliable floor), not stat.

## STEP 2 — ACTUALLY BUILD (mandatory, cite output)
```
dotnet build src/CcDashboard.Web -c Debug
```
MUST be 0 errors. PASTE the final "Build succeeded / 0 Error(s)" line into the report + binding RESULT. Do NOT claim 0 err without this run.

## STEP 3 — commit (fix:, NO push) under commit.lock
Stage ONLY ScreenEditorPage.razor (the @inject/@using fix). pre-commit-check ; git add src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor ; git commit -m "fix: add @inject ICurrentUserAccessor to ScreenEditorPage (CC-3 d83517c used CurrentUser without inject -> CS0103) [shell-0609]" ; git rev-parse HEAD ; §0.6 post-commit (git show HEAD verify) ; cc_post_commit.sh shell-0609 <hash> ; PD-007 re-sync ; sync.

## STEP 4 — §0.6b CAPTURE (mandatory) -> role-shell §B (git add -f, can fold into the same commit or a docs follow-up)
`<date> · Claimed "build 0 err" in a binding RESULT WITHOUT running dotnet build; committed non-compiling code (CurrentUser used w/o @inject ICurrentUserAccessor) — 2nd unverified build/works claim today (cf T1 committed!=works). · RULE: a "build 0 err" claim MUST cite an ACTUAL dotnet build run; object-store marker-verify is NOT compile-verify. · SOURCE: ScreenEditorPage.razor:2263 + @inject L4-7; d83517c broke, fixed THIS. · status: active`

## Binding RESULT -> .coord/cc/shell.md (done): commit <hash>; @inject ICurrentUserAccessor + @using added; **dotnet build CITED: <paste 0-Error line>**; only ScreenEditorPage.razor staged; CAPTURE appended. NO push. verified: object-store + REAL build.

## Report (chat): commit hash; the actual build output line (0 err); CAPTURE; confirm only SEP staged. NO push.
