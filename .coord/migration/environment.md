# Environment inventory — rebuild sheet for the new account

Written by curator-0611, 2026-08-17. Every figure below was read from the object store or the disk at the
time of writing, not from memory. Companion to `.coord/protocols/account-migration-runbook.md`.

**Scope: RTM View Shell only.** Agent Desktop stays on the originating account (operator decision).

---

## 1. Account-side things to recreate by hand

| What | Value | Notes |
|---|---|---|
| Plugins | `superpowers@claude-plugins-official` | from `.claude/settings.local.json` |
| MCP servers in use | memory · remote-devices (device bridge) · claude-in-chrome · visualize | re-authorize each |
| Connected folder | `D:\Claude\Projects\RTM View Shell` — **this one only** | see §4 for what must NOT be connected |
| Project instructions | `.coord/migration/project-instructions.md` | ⬜ NOT YET EXPORTED — account-side field, nowhere on disk |
| Scheduled tasks | **none** | verified 2026-08-17: the account has zero |
| Local permissions | 10 allow-entries in `.claude/settings.local.json` | tracked in git, re-applied by connecting the folder |

## 2. Git

- Remote: `https://github.com/MaximFa/rtm-view-shell.git` — **the GitHub account is separate from the
  Anthropic account.** Only the connector authorization needs redoing; the repository itself does not move.
- Working branch: **`v3`** (single active branch).
- Other branches present: `adapters`, `coord`, `lab`, `main`, `v2`, `v2-backend`, `v2-frontend` — historical.
- The migration package (§3) is on `v3` and pushed. **After a push, the whole project is reconstitutable
  from GitHub + `D:\` alone.** That is the migration gate.

## 3. What the handover package contains (`.coord/migration/`)

| Package | Count |
|---|---|
| `project-memory/` — the desktop-app memory store | 39 files, 184 722 B, byte-verified |
| `space-memory/` — account memory, work scope | 4 files |
| `account-skills/` — the operator's own custom skills | 10 skills / 28 files + `manifest-custom.json` |
| `bus-snapshot/` — the entire `.coord` runtime state at handover | 163 files, sha256-verified |

**Three separate memory stores exist — restoring one is not restoring memory:**

1. **Project memory** — 39 files, desktop-app store, account-bound → `migration/project-memory/`
2. **Space memory** — 8 files, account-bound → 4 work files in `migration/space-memory/`,
   4 personal files in `.coord/space-memory-personal/` (**outside git by choice — see §4**)
3. **`.claude/memory/`** — 11 files of in-repo project knowledge, travels in git by itself

**Skills:** 37 project/role skill folders in `.claude/skills/` (travel in git) + 10 custom account skills in
the package. Anthropic's own skills (`docx`, `pdf`, `pptx`, `xlsx`, `doc-coauthoring`, `morning`,
`skill-creator`) come with the new account — do not migrate them.

⚠ **Name collision to resolve BEFORE re-uploading:** `user-doc-expert` exists twice and they are DIFFERENT
skills — the account one is generic Enterprise-Grade (10 597 B), the repo one is RTM-specific (17 879 B,
`invocation: user`). Rename one, or the second will shadow the first.

## 4. Not in git — protected only by the cold copy

These live on disk and will NOT arrive via GitHub. Include them in the §1.4 cold copy or lose them:

- `.coord/space-memory-personal/` — 4 personal memory files (deliberately kept out of the repo)
- `10072026/` — 170 files, 1.3 MB (operator decision 2026-08-17: stays on disk, not committed)

Deliberately excluded and **not** worth preserving — regenerable:

- `tools/cache/` — 61 MB of Garnet + nssm binaries (now gitignored)
- `db/data.zip`, `.claude/skills.zip` (a superseded 2026-06-08 snapshot), `.coord/migration/*.tar.gz`

**Do NOT connect** `C:\Users\farbe\Documents\Claude\Projects\RTM View Shell` — a stale clone frozen at
2026-06-09 that has already caused false "broken spine" alarms. Archive it (§6).
**Do NOT connect** `D:\Claude\Projects\Agent Desktop` — stays on the originating account.

## 5. Order of restore

1. Sign in → connect the one folder → install the plugin → re-authorize the MCP servers.
2. Create the project, paste the project instructions verbatim.
3. Re-upload the 10 custom skills (resolve the `user-doc-expert` collision first).
4. Restore project memory from `migration/project-memory/`, **`MEMORY.md` last** — it is the index and must
   reflect the final file set. Then space memory from `migration/space-memory/`.
5. Re-instantiate the specialists, curator first (runbook §4).
6. Run the verification gate (runbook §5) before declaring the migration done.

## 6. Traps recorded during the export — read these before trusting any inventory

1. `git add` is a silent no-op in two whole zones: `.coord/.gitignore` line 2 is `*`, root `.gitignore`
   line 49 is `.claude/`. It *looks* like success. This is the mechanism behind the 2026-07-03 data loss.
   (Gitignore never applies to already-tracked files — a warning about an ignored path does not mean a
   tracked modification inside it was skipped. Verify with `git hash-object` before declaring loss.)
2. A directory existing proves nothing — `.claude/skills/prod-release/` was an empty husk; the only real
   copy of that skill lived in the account.
3. Same name ≠ same thing (see the `user-doc-expert` collision above).
4. `git status` showing `M` can be pure line-ending noise — 8 of 13 "modified" files were byte-identical to
   `v3` under `git hash-object`.
5. Never write `.coord` files through a PowerShell pipe: PS 5.1 `Set-Content -Encoding utf8` injects a UTF-8
   BOM, and a cp1252 round-trip mojibakes `—`/`§`/`→`. Use Python + `os.fsync`, then verify bytes.
6. Read the disk AND the index — never infer one from the other. Every mistake above came from doing that.
