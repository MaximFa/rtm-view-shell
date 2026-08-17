# CC task — ASD guard recreate unit-test (shell): cover SaveQueueGridRtsCommand grid recreate/update paths — §4 PRE-BLESSED (coordinator 2026-07-06)
> Follow-up to guard 21ecb84 (coordinator greenlit the recreate-test). Mockable seam EXISTS: `SaveQueueGridRtsCommandHandler(IRtsRepository, IConfigurationApiHook)`. Add 2 NSubstitute tests covering the Step-1 guard branch. Test-only; folds into the same blur+guard barrier (no extra deploy).
> Owner: role-shell. Executor: native CC. Branch: **v3 ONLY**. Commit `test:`. **NO push** (§37). Test-scoped.

## Mandatory — read before starting
Read file: .claude/skills/role-shell/role-shell.md  (§A CORE incl ⛔ЧП block; §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + BRANCH NORM (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3; verify HEAD == v3 tip (21ecb84 or later)
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
    [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```
- ALL commits to **v3** only. §0.3 Python+fsync; Edit BANNED.

## §0.6b BINDING PREAMBLE — append to .coord/cc/shell.md (Python+fsync)
```
## BINDING 2026-07-06T12:07:17Z | spec: shell | directive: tools/cc_prompt_shell_asd_guard_test.md | status: open
### DIRECTIVE (spec->CC): ASD guard recreate unit-test — 2 NSubstitute tests for SaveQueueGridRtsCommand Step-1 (recreate on missing grid / update on existing). v3, test:, NO push, §4 pre-blessed. Report build=0 + unit failed=0 WITH COUNTS (passed +2 vs 258).
```

## §42.6 CLAIM (file-mode)
- tests/CcDashboard.Tests.Unit/Commands/SaveQueueGridRtsCommandHandlerTests.cs — NEW FILE

## GROUNDING (object-store)
- Handler: `SaveQueueGridRtsCommandHandler(IRtsRepository rtsRepository, IConfigurationApiHook apiHook)` (SaveQueueGridRtsCommand.cs:39-41).
- Step 1 (guard): `if (cmd.GridId is null or 0 || !await rtsRepository.QueueGridExistsAsync(cmd.GridId.Value, ct)) { gridId = await rtsRepository.InsertQueueGridAsync(cmd.Title, ct); } else { await rtsRepository.UpdateQueueGridAsync(cmd.GridId.Value, cmd.Title, ct); gridId = cmd.GridId.Value; }`.
- Command: `SaveQueueGridRtsCommand(int? GridId, int? HeaderRowId, string Title, List<QueueGridColumnInput> Columns, List<QueueGridRowInput> Rows, Dictionary<string,int?> ExistingHeaderCellIds)`.
- Result: `SaveQueueGridRtsResult(int GridId, int HeaderRowId, Dictionary<string,int> SavedColumnIds, Dictionary<string,int> HeaderCellIds, Dictionary<string,int> SavedRowIds, Dictionary<string,Dictionary<string,int>> SavedCellIds)`.
- Test style (mirror tests/CcDashboard.Tests.Unit/Commands/Configuration/*): `using NSubstitute; using FluentAssertions;`, `Substitute.For<IRtsRepository>()`, ctor builds handler, `[Fact]`, `_repo.Method(args).Returns(...)`, `await _repo.Received(1).MethodAsync(...)` / `await _repo.DidNotReceive().MethodAsync(...)`.
- With EMPTY Columns/Rows the handler runs to completion (loops skip; NSubstitute returns defaults for the other repo calls; apiHook.NotifyAsync → completed Task).

## THE WORK — new test file with 2 [Fact]s
```csharp
using CcDashboard.Application.Commands.Dashboards;
using CcDashboard.Application.Interfaces;   // IRtsRepository, IConfigurationApiHook (confirm namespaces)
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class SaveQueueGridRtsCommandHandlerTests
{
    private readonly IRtsRepository _repo = Substitute.For<IRtsRepository>();
    private readonly IConfigurationApiHook _hook = Substitute.For<IConfigurationApiHook>();
    private readonly SaveQueueGridRtsCommandHandler _handler;

    public SaveQueueGridRtsCommandHandlerTests() => _handler = new SaveQueueGridRtsCommandHandler(_repo, _hook);

    private static SaveQueueGridRtsCommand Cmd(int? gridId) => new(
        gridId, null, "Grid X",
        new List<QueueGridColumnInput>(),   // empty → loops skip
        new List<QueueGridRowInput>(),
        new Dictionary<string, int?>());

    [Fact]
    public async Task Handle_StaleGridId_GridMissing_RecreatesGrid()
    {
        _repo.QueueGridExistsAsync(999, Arg.Any<CancellationToken>()).Returns(false);
        _repo.InsertQueueGridAsync("Grid X", Arg.Any<CancellationToken>()).Returns(555);

        var result = await _handler.Handle(Cmd(999), CancellationToken.None);

        await _repo.Received(1).InsertQueueGridAsync("Grid X", Arg.Any<CancellationToken>());
        await _repo.DidNotReceive().UpdateQueueGridAsync(Arg.Any<int>(), Arg.Any<string>(), Arg.Any<CancellationToken>());
        result.GridId.Should().Be(555);
    }

    [Fact]
    public async Task Handle_ExistingGrid_UpdatesInPlace()
    {
        _repo.QueueGridExistsAsync(33, Arg.Any<CancellationToken>()).Returns(true);

        var result = await _handler.Handle(Cmd(33), CancellationToken.None);

        await _repo.Received(1).UpdateQueueGridAsync(33, "Grid X", Arg.Any<CancellationToken>());
        await _repo.DidNotReceive().InsertQueueGridAsync(Arg.Any<string>(), Arg.Any<CancellationToken>());
        result.GridId.Should().Be(33);
    }
}
```
- CONFIRM the exact namespaces of `IRtsRepository`/`IConfigurationApiHook`/`SaveQueueGridRtsCommand*` (adjust usings to compile). If the handler makes a repo call that NSubstitute can't default (e.g. a non-nullable list it then iterates) and it NREs, stub it to return an empty collection. Keep the tests minimal + green.

## VERIFY / DoD (role-shell §A)
- **Object-store:** new test file with the 2 [Fact]s (recreate + update), NSubstitute style, no production code changed.
- **Soma (Profile A) — REPORT NUMBERS:** /ops/build = **0 errors** (+W); /ops/test?suite=unit = **failed=0**, **passed = 260** (258 + 2). If a stub is needed to avoid an NRE, add it; do NOT touch production.

## COMMIT (commit.lock + journal + no-push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s); stage ONLY the new test file (+ role-shell.md via `git add -f` if CAPTURE). Commit `test(web): ASD guard — recreate/update unit tests for SaveQueueGridRtsCommand Step-1 [shell-0609]`.
- `bash tools/cc_post_commit.sh shell-0609 <hash>`. §0.6 verify. **NO push**. §0.7 re-sync from HEAD.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/shell.md
```
### RESULT (CC->spec): commits <hash> . build <0 err/W n> . unit <failed 0/passed 260> . files SaveQueueGridRtsCommandHandlerTests.cs (new) . status done|failed . blockers . verified: object-store + build/unit
```
