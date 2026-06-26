# CC Task — fix(soma): /db/dashboards 500 — Npgsql NO-MARS reader leak (F-QA-8 residual)

> Branch: **v3** · Role: **devops** · Commit prefix: **fix:** · NO push (§37)
> Author: devops-0624 · **§4-REVIEW: PASS** (coordinator-0624 2026-06-24T23:58Z — root cause verified vs object-store L519-533: outer cmd/rdr live through foreach, inner wcmd/wrdr on same conn = NO-MARS 500; nested-scope fix correct, foreach untouched, SF-SOMA-001 guardrails, narrow 1-file, NO push). Minor: STEP 0c freeze-check prefer `-s`+cat over `test -f` (L-SC-10 phantom) — non-blocking. CLEARED TO RUN (v3 window, non-urgent).

---

## STEP 0 — MANDATORY (do not skip even if task seems unrelated)

### 0a. Mandatory reads (NORM-CUR-11 / §40 / §0.8)
Read before any work:
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-devops/role-devops.md` (§A CORE + §C VERIFY)

### 0b. Branch + integrity (object-store, NOT mount git status)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git checkout v3
git rev-parse v3                 # expect aa544d05b52d19eac8bb94d298aec59a107441c2 (or later if v3 advanced)
git cat-file -t HEAD             # expect commit
# Verify the target file matches HEAD (do NOT trust mount line counts):
git hash-object tools/Soma/Program.cs
git rev-parse HEAD:tools/Soma/Program.cs
# If the two hashes differ -> re-sync from HEAD before editing:
#   git show HEAD:tools/Soma/Program.cs > tools/Soma/Program.cs
```

### 0c. Freeze check
```bash
[ -s .coord/push/request.md ] && { echo "PUSH BARRIER ACTIVE — STOP, do not start"; exit 1; } || echo "no freeze, proceed"   # -s (not -f): ignore phantom zero-byte dirents (L-SC-10)
```

### 0d. Binding PREAMBLE — append to `.coord/cc/devops.md` (Python + os.fsync)
```
## <UTC> | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_dashboards_mars.md | status: open
### DIRECTIVE: fix /db/dashboards 500 (Npgsql NO-MARS). Dispose outer dashboards reader BEFORE per-dashboard widget loop. Claims: tools/Soma/Program.cs. Prefix: fix:.
```

---

## ROOT CAUSE (confirmed QA + coord, devops-0619 handoff)

In the `app.MapGet("/db/dashboards", ...)` handler, the outer dashboards reader
(`await using var rdr = await cmd.ExecuteReaderAsync();`) stays in scope for the entire
`foreach (var db in dashboards)` loop. Inside that loop a **widget** command/reader
(`wcmd`/`wrdr`) executes on the **same** `NpgsqlConnection conn`. Npgsql has **no MARS** —
a connection allows only one open reader at a time. With **>=1** dashboard row the widget
query throws -> handler returns **500**. (0 rows = loop never runs = false "pass".)

## THE FIX (narrow, single file: `tools/Soma/Program.cs`)

Wrap the dashboards `cmd` + `rdr` + materialization `while`-loop in a **nested `{}` scope**
so both the command and the reader are disposed BEFORE the `foreach` widget loop opens its
own reader on `conn`. Keep the `dashboards` list declared OUTSIDE the nested scope so it
survives.

Current (between `await conn.OpenAsync();` and `var results = new List<object>();`):
```csharp
    var sql = @"SELECT d.""Id"", d.""Name"", d.""Description"", d.""IsPublic"", d.""IsDeleted"", d.""CreatedAt"", d.""TenantId"" FROM public.dashboards d WHERE d.""TenantId"" = @t ORDER BY d.""Name""";
    await using var cmd = new NpgsqlCommand(sql, conn); cmd.Parameters.AddWithValue("t", tenant.Value);
    await using var rdr = await cmd.ExecuteReaderAsync();
    var dashboards = new List<(Guid Id, string Name, string? Desc, bool Public, bool Deleted, DateTime Created)>();
    while (await rdr.ReadAsync()) { dashboards.Add((rdr.GetGuid(0), rdr.GetString(1), rdr.IsDBNull(2) ? null : rdr.GetString(2), rdr.GetBoolean(3), rdr.GetBoolean(4), rdr.GetDateTime(5))); }
```

Replace with (note: `dashboards` declared first, then a nested block that disposes cmd+rdr):
```csharp
    var sql = @"SELECT d.""Id"", d.""Name"", d.""Description"", d.""IsPublic"", d.""IsDeleted"", d.""CreatedAt"", d.""TenantId"" FROM public.dashboards d WHERE d.""TenantId"" = @t ORDER BY d.""Name""";
    var dashboards = new List<(Guid Id, string Name, string? Desc, bool Public, bool Deleted, DateTime Created)>();
    await using (var cmd = new NpgsqlCommand(sql, conn))
    {
        cmd.Parameters.AddWithValue("t", tenant.Value);
        await using var rdr = await cmd.ExecuteReaderAsync();
        while (await rdr.ReadAsync()) { dashboards.Add((rdr.GetGuid(0), rdr.GetString(1), rdr.IsDBNull(2) ? null : rdr.GetString(2), rdr.GetBoolean(3), rdr.GetBoolean(4), rdr.GetDateTime(5))); }
    }
```

The `foreach (var db in dashboards)` block and everything after it stay UNCHANGED.
(The widget `wcmd`/`wrdr` are now the only open reader on `conn` at any moment.)

**Write discipline (§0.3):** use Python read->replace->write with `os.fsync`; the Edit tool
is BANNED on this mount. After write: `tail -3` + `wc -l` to confirm proper closing.

## SF-SOMA-001 guardrails — DO NOT TOUCH
soma_ro role, `*_safe` views, secret-table REVOKEs are out of scope. No connection-string,
auth, or query-whitelist changes. Only the reader-scoping fix above.

---

## BUILD / VERIFY
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build tools/Soma
```
- Build must succeed. (If output-copy fails because Soma.exe is running/locked, that is a
  file lock, NOT a compile error — compilation success is the gate. Operator restarts Soma
  to pick up the fix.)
- Confirm via grep that the nested scope exists and the foreach is untouched:
```bash
grep -n "await using (var cmd = new NpgsqlCommand(sql, conn))" tools/Soma/Program.cs   # = 1
grep -n "foreach (var db in dashboards)" tools/Soma/Program.cs                          # = 1
```

## COMMIT (native CC, commit.lock serialized)
```bash
# 1. acquire commit.lock (Python open(path,"x"); retry on busy; never auto-delete a stale lock)
# 2. pre-commit check
bash tools/pre-commit-check.sh tools/Soma/Program.cs
# 3. NARROW-ADD — by name only, NO -A, NO git add .
git add tools/Soma/Program.cs
git commit -m "fix(soma): /db/dashboards — dispose outer reader before widget loop (Npgsql NO-MARS, F-QA-8) [devops]"
# 4. post-commit zero-deletion verify (object-store):
git show --stat HEAD            # exactly 1 file changed, 0 files deleted
git diff HEAD~1 HEAD --stat
# 5. journal append + release commit.lock (Python+fsync)
```

**NO `git push` (§37).** Push happens only via the dedicated push prompt after the barrier.

## §0.6b Binding POSTAMBLE — write RESULT into `.coord/cc/devops.md`
```
### RESULT:
- commit: <hash> fix(soma): /db/dashboards ...
- files: tools/Soma/Program.cs (1 file, 0 deletions)
- build/test: dotnet build tools/Soma -> <pass/lock-only>
- blockers: <none | ...>
- object-store verify: yes — <hash> in git log HEAD; nested scope grep=1; foreach grep=1
- status: done
- NO push
```

## §0.7 re-sync (LAST action before session end)
```bash
git show HEAD:tools/Soma/Program.cs > tools/Soma/Program.cs
sync
```

---

## Acceptance criteria
- [ ] STEP-0 reads done; branch v3; file hash-verified vs HEAD before edit
- [ ] Exactly ONE file changed: `tools/Soma/Program.cs`; zero file deletions
- [ ] Outer dashboards `cmd`+`rdr` wrapped in nested `{}`; disposed before `foreach` widget loop
- [ ] `foreach (var db in dashboards)` widget block UNCHANGED
- [ ] No SF-SOMA-001 / connStr / auth / whitelist changes
- [ ] `dotnet build tools/Soma` compiles
- [ ] commit `fix(soma): ...` on v3; binding RESULT written; journal appended; commit.lock released
- [ ] NO push
- [ ] LIVE confirm (operator/QA, after Soma redeploy): GET /db/dashboards?tenant=<guid> -> 200 with >=1 dashboard (Trash present)
