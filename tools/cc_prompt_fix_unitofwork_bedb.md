# CC Task: Fix DbContext concurrency error — remove BackendEmulationDbContext from UnitOfWork

## Problem
`UnitOfWork.SaveChangesAsync()` saves both `AppDbContext` and `BackendEmulationDbContext`.
`RtsRepository` and `NgcRepositories` already call `beDb.SaveChangesAsync()` directly
after each individual operation. `UnitOfWork` calling it again at the end of every
`ITransactional` MediatR command causes concurrent or double-save on the same context
instance, leading to:
"A second operation was started on this context instance before a previous operation completed."

## Fix
Remove `await beDb.SaveChangesAsync(ct)` from `UnitOfWork`. Each repository that uses
`BackendEmulationDbContext` is responsible for saving its own changes.

## File
`src/CcDashboard.Infrastructure/Services/UnitOfWork.cs`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change — UnitOfWork.cs

Find:
```csharp
    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        var result = await db.SaveChangesAsync(ct);
        await beDb.SaveChangesAsync(ct);  // Save NGC repositories (Site, BU, Supergroup etc.)
        return result;
    }
```

Replace with:
```csharp
    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        // Only save AppDbContext here.
        // BackendEmulationDbContext (RTSGrid, NGC tables) is saved directly
        // by each repository (RtsRepository, NgcRepositories) after every operation.
        // Including it here caused concurrent SaveChangesAsync on the same instance.
        return await db.SaveChangesAsync(ct);
    }
```

Also remove the unused `beDb` constructor parameter if it's no longer needed:

Find:
```csharp
public class UnitOfWork(AppDbContext db, BackendEmulationDbContext beDb) : IUnitOfWork
```

Replace with:
```csharp
public class UnitOfWork(AppDbContext db) : IUnitOfWork
```

---

## Verification

```bash
cat src/CcDashboard.Infrastructure/Services/UnitOfWork.cs
# Must show only AppDbContext, no beDb reference
```

---

## Commit

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Infrastructure/Services/UnitOfWork.cs
# Only if exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Infrastructure/Services/UnitOfWork.cs \
  tools/cc_prompt_fix_unitofwork_bedb.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: remove BackendEmulationDbContext from UnitOfWork to prevent concurrent SaveChangesAsync"
cp /tmp/cc-idx .git/index
```

Post-commit (§0.6):
```bash
git status --short
git log --oneline -3
```

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.

---

## Re-sync from HEAD (§0.6 PD-007, mandatory last step)

```bash
for f in src/CcDashboard.Infrastructure/Services/UnitOfWork.cs \
          tools/cc_prompt_fix_unitofwork_bedb.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
