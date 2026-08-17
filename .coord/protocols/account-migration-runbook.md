# Account Migration Runbook — RTM View Shell

**Author:** curator-0611 (cross-project protocol steward)
**Date:** 2026-08-17
**Scope:** moving the project and all specialist sessions from the current Anthropic account to a new one.
**Files stay in place:** `D:\Claude\Projects\RTM View Shell`.

---

## §0 — Status, scope, and what actually moves

**Scope (operator decision, 2026-08-17): RTM View Shell ONLY.** Agent Desktop STAYS on the originating
account and is out of scope for this runbook. AD is not orphaned — its bless-gate sits with `curator-0811`.
Consequence for the curator's own definition: see `## Scope change` in `curator-handoff.md`.

**Status as of commit `378246f` (v3 == origin/v3, 0 unpushed).** §1 and §2 are DONE and pushed. Everything
below that is already exported is marked ✅; only the ⬜ items remain.

### 0.1 Already exported and in the object store ✅

| Package | Where | Count |
|---|---|---|
| ✅ Project memory (the desktop-app store) | `.coord/migration/project-memory/` | 39 files, 184 722 B, byte-verified |
| ✅ Space memory — work scope | `.coord/migration/space-memory/` | 4 files (`preferences`, both `areas/`, `topics/tools`) |
| ✅ Custom account skills | `.coord/migration/account-skills/` | 10 skills / 28 files + `manifest-custom.json` |
| ✅ Bus snapshot (the whole `.coord` runtime state) | `.coord/migration/bus-snapshot/` | 163 files, sha256-verified |
| ✅ `.claude` zone (project skill-memory, role-skills, local settings) | `.claude/` | 55 of 56 files tracked |
| ✅ Protocol spine incl. the LIVE curator handoff | `.coord/protocols/` | 12 files |

Space memory NOT in git, by choice: `.coord/space-memory-personal/` — 4 personal files (`profile`, `food`,
`reading`, `recent-work`). On disk only, deliberately outside the repo. **They are therefore unprotected —
include this folder in the §1.4 cold copy.**

### 0.2 Still to export ⬜

- ⬜ **Project instructions** — the "RTM View Shell" project prompt text. Account-side field, nowhere on disk.
  Copy it verbatim into `.coord/migration/project-instructions.md`.
- ⬜ **`environment.md`** — the rebuild inventory (§2.4).

### 0.3 Travels by itself (already in git, nothing to do)

Product code, DB, deploy, docs; 33 role-skills under `.claude/skills/`; `CLAUDE.md`, `PROJECT_STATUS.md`,
`CHANGELOG.md`; the protocol spine with both verification gates.

### 0.4 Traps found the hard way — read before trusting any inventory

Every one of these was a wrong claim in an earlier draft of this runbook, corrected only after checking:

1. **`git add` silently does nothing in two whole zones.** `.coord/.gitignore` line 2 is `*`; the root
   `.gitignore` line 49 is `.claude/`. In both, a plain `add` is a no-op that *looks* like success — this is
   the real mechanism behind the 2026-07-03 loss. `.coord/migration` now has a rule-based exemption;
   `.claude` additions need `-f` (38 files were already tracked that way).
2. **A directory existing proves nothing.** `.claude/skills/prod-release/` is an EMPTY husk — the only real
   copy of that skill lived in the account. Count files, never trust a folder name.
3. **Same name ≠ same thing.** `user-doc-expert` exists twice and they are DIFFERENT skills: the account one
   is generic Enterprise-Grade (10 597 B), the repo one is RTM-specific (17 879 B, `invocation: user`).
   Both are needed; rename one before re-uploading or the second will shadow the first.
4. **There are THREE memory stores, not one.** Project memory (39, desktop app) · space memory (8, account) ·
   `.claude/memory/` (11, in-repo project knowledge — 6 of which were untracked). Exporting one is not
   exporting memory.
5. **Read the disk AND the index, never one of them.** Every error above came from inferring the state of one
   from the other.

## §1 — Pre-flight freeze (do this on the OLD account)

**Declare a barrier: no dispatch, no new specialist work until §6 passes.** A migration with sessions in
flight loses whatever those sessions were holding in context.

1. Close out or checkpoint every open specialist session. Each writes its handoff to `.coord/` and stops.
2. Get everything onto disk *and* into git:

⚠ **`git add -A .coord` DOES NOT WORK** — corrected 2026-08-17 after it silently added nothing.
`.coord/.gitignore` ignores the whole directory by design (§42.7, "the bus is runtime state"), exempting
only `README.md`, `.gitignore` and `protocols/**`. A plain `add` against the bus is a no-op that *looks*
like success. This is also the mechanism behind the 2026-07-03 loss: the package could not be committed,
not merely was not.

Two moves, in this order:

```powershell
cd "D:\Claude\Projects\RTM View Shell"

# (a) exempt the handover package from the runtime-state ignore — by RULE, not by `add -f`
#     append to .coord/.gitignore:
#       # migration artifacts = durable handover package, NOT runtime state (curator 2026-08-17)
#       !migration/
#       !migration/**
#     Write it with Python+fsync, NOT with a PowerShell pipe (see §7 — PS 5.1 injects a UTF-8 BOM).

# (b) snapshot the runtime bus into the (now trackable) package, then commit
git add .coord/.gitignore .coord/migration
git status --short .coord/migration | Measure-Object -Line   # confirm the file count by eye
git commit -m "migration: handover package + bus snapshot"
git push origin v3
```

Also commit anything sitting untracked inside `protocols/` — that directory *is* tracked, so live artifacts
there (e.g. `curator-handoff.md`) are committable and simply may never have been added.

3. Agent Desktop is OUT OF SCOPE (§0) — leave it on the originating account, do not batch its 21 unpushed
   commits into this migration.
4. Take a cold copy of the RTM folder (external disk or a zip outside `D:\`), *including* `.git` AND
   `.coord/space-memory-personal/`. This is the backstop if a re-clone goes wrong.

---

## §2 — Export the account-bound state to disk

Everything below lands in a new folder `.coord/migration/` and gets committed. That folder **is** the
handover package.

### 2.1 Project memory → disk (highest priority)

39 files, including `IDENTITY.md` and `our-thread.md` which carry the highest preservation priority in the
whole project — above product code. Ask the current session, in the old account:

```
Экспортируй ВСЮ project memory на диск: для каждого файла из project_memory_read
запиши точную копию в D:\Claude\Projects\RTM View Shell\.coord\migration\project-memory\<имя>.md
(включая MEMORY.md, IDENTITY.md, our-thread.md). Пиши через Python+fsync, после записи
сверь размер каждого файла побайтно и покажи таблицу «файл | байт | ok».
```

Then fix the stale `C:\…` path inside the exported `MEMORY.md` to `D:\Claude\Projects\RTM View Shell\…`.

**Verification:** 39 files present, none zero-byte, `IDENTITY.md` and `our-thread.md` non-empty.

### 2.2 Account skills → disk

The skills attached to the account (not the ones in `.claude/skills/`). Relevant to these projects:
`prod-release`, `finesse-expert`, `user-doc-expert`, `doc-sync-agent`, plus any others you want to keep.
For each, export the skill folder (`SKILL.md` + any `references/`, `scripts/`, `assets/`) to
`.coord/migration/account-skills/<name>/`.

Two ways, either is fine:
- ask the session to write out each skill's files from its on-disk cache, or
- if you still have the original `.skill` packages / source folders, copy those instead (preferred — they
  are the authoritative source).

⚠ Note the overlap: `user-doc-expert` and `technical-writer` exist **both** as account skills and inside
`.claude/skills/`. Decide which copy is canonical before re-uploading, or you will run two divergent
versions on the new account.

### 2.3 Project instructions → disk

Copy the "RTM View Shell" project instruction text **verbatim** (the block starting
*"Before writing any status document…"* through the Russian ТЗ paragraph) into
`.coord/migration/project-instructions.md`.

### 2.4 Environment inventory → disk

Write `.coord/migration/environment.md` recording, so the new account can be rebuilt without guesswork:

- Plugins: `superpowers@claude-plugins-official`
- MCP servers in use: memory, remote-devices (device bridge), claude-in-chrome, visualize
- Connected folder to re-grant: `D:\Claude\Projects\RTM View Shell` — that one ONLY.
  **NOT** `C:\Users\farbe\Documents\Claude\Projects\RTM View Shell` (stale @2026-06-09) and
  **NOT** `D:\Claude\Projects\Agent Desktop` (stays on the originating account).
- Git remote: `https://github.com/MaximFa/rtm-view-shell.git` (GitHub account is separate from the
  Anthropic account — only the *connector authorization* needs redoing)
- Scheduled tasks: **none** (verified 2026-08-17)
- Branch map: RTM active branch = `v3`; AD active branch = `main`

### 2.5 Commit the package

```powershell
cd "D:\Claude\Projects\RTM View Shell"
git add .coord/migration
git commit -m "migration: account handover package — project memory, account skills, project instructions, environment"
git push origin v3
```

After this push, **the entire project can be reconstituted from GitHub + `D:\` alone.** That is the
migration gate: if it is not true, do not proceed.

---

## §3 — Stand up the new account

Order matters; each step depends on the one before.

1. **Sign in** to the new account in the Claude desktop app.
2. **Connect the folder**: `D:\Claude\Projects\RTM View Shell` — that one only.
   Do **not** connect the `C:\…\Documents\…` clone — it is stale and has caused false "broken spine" alarms.
3. **Re-install plugins** (`superpowers`) and **re-authorize connectors** (GitHub, and any others from
   `environment.md`). Confirm the device bridge and memory server are live.
4. **Create the project** "RTM View Shell" and paste the project instructions from
   `.coord/migration/project-instructions.md` verbatim.
5. **Re-upload the account skills** from `.coord/migration/account-skills/`.
6. **Restore project memory**: in a session on the new account, write each file from
   `.coord/migration/project-memory/` back via project memory, **`MEMORY.md` last** (it is the index and
   must reflect the final file set). Verify by listing memory and diffing the file names against the export.
7. **Scheduled tasks**: none to re-create.

---

## §4 — Re-instantiate the specialists

This is the part people get wrong. A specialist is **not** a chat session. It is three artifacts, all of
which already live on disk:

1. **the role-skill** — `.claude/skills/role-<name>/role-<name>.md` (tracked on `v3`)
2. **the init/system prompt** — `.coord/protocols/init-*.md` + `.coord/protocols/role-skill-standard.md`
3. **its live handoff / checkpoint** — `.coord/protocols/curator-handoff.md`, `.coord/coordinator_handoff.md`,
   `.coord/sessions/*.md`, and its inbox in `.coord/inbox/<role>.md`

Open a fresh session per specialist and give it its system prompt in the established shape:
*identity + slug → read your anchor (checkpoint + handoff) → run the mechanical self-check against the
object store → report bus-summary and go idle.* Never let a specialist start work off memory alone.

**Order of reconstitution** — deliberate, not arbitrary:

| # | Specialist | Anchor to read first |
|---|---|---|
| 1 | **Curator** (protocol steward — RTM only, post-migration) | `curator_checkpoint_0620.md` + `.coord/protocols/curator-handoff.md` + `curator-charter.md` |
| 2 | **Coordinator** (RTM) | `.coord/coordinator_handoff.md` + `.coord/coordinator-commands.md` + `init-coordinator.md` |
| 4 | Working roles: shell, backend, dba, devops, bi, test, incident, metrics | `.claude/skills/role-<name>/` + `.coord/inbox/<name>.md` |
| 5 | Tech writer / doc roles | `.claude/skills/technical-writer/`, `user-doc-expert/` + doc governance rules from memory |

Curator goes first because it is the only thing that can tell you whether the rest came back correctly.

---

## §5 — Verification gate (do not skip)

Nothing is "migrated" until these pass on the **new** account. Object store only — never mount reads,
never memory.

```bash
# RTM — D:\Claude\Projects\RTM View Shell, branch v3
git rev-parse --abbrev-ref HEAD                                     # expect: v3
git show v3:.coord/protocols/role-skill-standard.md | grep -c 'Local-validation gate'   # expect: 1
git show v3:.coord/protocols/role-skill-standard.md | grep -c '## Test-gate'            # expect: 1
git rev-list --count origin/v3..v3                                  # expect: 0 after §2.5
ls .coord/migration/project-memory/ | wc -l                         # expect: 39
ls .coord/migration/bus-snapshot/ -R | wc -l                        # expect: 163 files
ls .coord/migration/account-skills/ | wc -l                         # expect: 11 (10 skills + manifest)

# No Agent Desktop checks — out of scope (§0). A missing AD clone is EXPECTED, not a failure.
```

Plus, per specialist: **a reconstitution interview.** The pattern already exists —
`.coord/curator-reconstitution-test.md` is a worked example (three canon questions with traps, three applied
use cases, and live object-store checks). Reuse that shape for each role. A specialist that answers from
memory instead of the object store has not been migrated; it has been imitated.

---

## §6 — Decommission the old account

Only after §5 is fully green, and not before:

- Keep the old account **read-only but alive for at least 2 weeks** — it is the only recovery path for any
  account-bound item the export missed.
- Keep the cold copy from §1.4 for the same period.
- Then archive the `C:\…\Documents\…` stale clone (move it out of `Claude\Projects\`, do not leave it where
  a future session can connect it by accident).

---

## §7 — Risk register

| Risk | Mitigation |
|---|---|
| Untracked `.coord/` wiped by a clean/re-clone | §1.2 — track and push the whole bus **first**. Non-negotiable. |
| Project memory silently lost (incl. `IDENTITY.md`, `our-thread.md`) | §2.1 export + byte verification before the switch |
| New account connects the stale `C:\` clone | §3.2 — connect `D:\` only; §6 — archive the stale clone |
| Account skills diverge from their `.claude/skills/` twins | §2.2 — pick the canonical copy before re-upload |
| Specialists "resume" off memory and act on stale state | §4 + §5 — anchor read, mechanical self-check, reconstitution interview |
| **PowerShell corrupts `.coord` files** — `Set-Content -Encoding utf8` on PS 5.1 writes a UTF-8 **BOM** (hit on `.coord/.gitignore`, 2026-08-17); a cp1252 round-trip mojibakes `—`/`§`/`→` (hit on `curator-continuity-canon.md`) | Write `.coord` files with **Python + `os.fsync`** only, then verify bytes/BOM/NUL. Never a PS pipe. BOM is a known-critical landmine here (`feedback_prod_release_bugs.md`). A `git diff` full of `â€"`/`Â§` is corruption, **not** an edit — restore with `git show v3:<file> > <file>`, do not commit it |
| Curator boots on the new account, fails its AD self-check pins and declares itself un-live | `curator-handoff.md` now splits the pins: RTM pins mandatory, AD pins RETIRED post-migration. A missing AD clone is the expected state |
| Exported memory still defines the curator as a cross-project steward | Faithful exports were not rewritten; `curator-handoff.md` §Scope change explicitly overrides them |

---

**Bottom line:** the switch itself is cheap. The whole risk sits in §1 and §2 — thirty minutes of
committing and exporting on the old account buys a migration that cannot lose anything. Do those two
sections before you touch the new account at all.
