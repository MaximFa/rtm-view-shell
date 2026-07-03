# CC TASK — Stand up CI (GitHub Actions) — DIRECTIVE (C).1, §MAINT-05

> Owner: role-devops. Branch: **v3** (the ONLY branch — §BRANCH-NORM 2026-07-02). status: DRAFT -> coordinator §4 -> RUN on operator poke.
> WHY: CcDashboard.Tests.Unit silently drifted to 62 compile errors because the solution build+test gate was never
> reliably run on Reports backend commits (CC can't reach Soma from sandbox; operator ran Web-only; NO CI exists —
> .github/ is ABSENT). This CI is the durable safety net so manual discipline is not the only guard.
> origin = https://github.com/MaximFa/rtm-view-shell.git -> GitHub Actions.

## Mandatory reads
.claude/skills/role-devops/role-devops.md (§A + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — Integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3 (checkout v3 if not)
git status --short                  # note the pre-existing D Installations/* + any M — do NOT stage them
```
BINDING PREAMBLE -> .coord/cc/devops.md (status open, directive ref).

## STEP 1 — Author .github/workflows/ci.yml (Python+fsync, §0.3)
Create `.github/workflows/ci.yml`:
```yaml
name: CI
on:
  push:
    branches: [ v3 ]
  pull_request:
    branches: [ v3 ]
jobs:
  build-test:
    runs-on: windows-latest        # app targets win-x64 + Windows-only deps (Event Log sink); avoids ubuntu build breaks
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - name: Restore
        run: dotnet restore CcDashboard.sln
      - name: Build solution (fails on ANY project incl the 4 test projects)
        run: dotnet build CcDashboard.sln -c Release --no-restore --no-incremental
      - name: Unit tests
        run: dotnet test tests/CcDashboard.Tests.Unit -c Release --no-build
      - name: Architecture tests
        run: dotnet test tests/CcDashboard.Tests.Architecture -c Release --no-build
  # Integration + Security suites use Testcontainers/Docker — gated as a follow-up
  # (Docker-on-Windows-runner is unreliable; add a linux job with services when stabilised).
```
Rationale: `--no-incremental` on the sln build is the SAME drift-guard we add to Soma /ops/build — it force-compiles every project so a test-project compile error CANNOT be skipped by an up-to-date check. Unit + Architecture are the no-Docker suites (must be 0 failures). Integration/Security (Testcontainers) are explicitly deferred/gated (directive allows "else gate as skipped").

## STEP 2 — Validate the workflow locally (cannot run it — NO push)
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('YAML OK')"
# if actionlint is available: actionlint .github/workflows/ci.yml
```
NOTE: GitHub Actions triggers only ON PUSH. This task is NO-push, so the pipeline first RUNS after the next push-barrier pushes v3. Acceptance here = file present + valid YAML + correct triggers(v3) + steps (restore, build --no-incremental sln, test Unit + Architecture).

## STEP 3 — Commit (v3, NO push)  — pre-commit + commit.lock discipline
```bash
bash tools/pre-commit-check.sh .github/workflows/ci.yml   # exit 0 required
# commit.lock (§42.4) acquire -> narrow add ONLY .github/workflows/ci.yml (NEVER the D Installations/* deletions) ->
# git commit -m "ci: GitHub Actions — build sln (--no-incremental, incl test projects) + Unit/Architecture tests on push/PR to v3 [devops]"
# -> journal append -> release lock (§0.4 index.lock / plumbing workarounds if blocked)
```
BINDING POSTAMBLE -> .coord/cc/devops.md RESULT (commit hash, file, YAML-OK, status done). **NO `git push`** (§37, ships via barrier). §0.7 re-sync .github/workflows/ci.yml from HEAD.

## DO NOT
- NO push. Do NOT stage the D Installations/* deletions or any file outside .github/workflows/ci.yml. Do NOT commit to v2-backend. Do NOT run the pipeline locally (it runs on GitHub post-push).
