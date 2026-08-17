# Account Migration Runbook — RTM View Shell (+ Agent Desktop)

**Author:** curator-0611 (cross-project protocol steward)
**Date:** 2026-08-17
**Scope:** moving the project and all specialist sessions from the current Anthropic account to a new one.
**Files stay in place:** `D:\Claude\Projects\RTM View Shell` and `D:\Claude\Projects\Agent Desktop`.

---

## §0 — The one thing that matters

The project is **file-borne**. Almost everything that makes it work lives on `D:\` and in git, and a new
account picks it up the moment you connect the folder. What does **not** travel is a short, specific list of
account-bound state — and if it is not exported to disk *before* you switch, it is gone.

### 0.1 Travels automatically (on `D:\`, in git)

| Asset | Location | Status |
|---|---|---|
| Product code, DB, deploy, docs | repo root | tracked on `v3` |
| Role-skills of all specialists (37 files) | `.claude/skills/` | tracked on `v3` ✔ verified |
| Project skill-memory | `.claude/memory/` (5 files) | tracked ✔ |
| Protocol spine | `.coord/protocols/` (14 files, incl. `role-skill-standard.md` with both gates) | tracked ✔ |
| Command registries | `.coord/coordinator-commands.md`, `.coord/session-commands.md` | tracked ✔ |
| Project charter | `CLAUDE.md`, `PROJECT_STATUS.md`, `CHANGELOG.md` | tracked ✔ |
| Local permissions + plugin list | `.claude/settings.local.json` | on disk (untracked) |

### 0.2 Does NOT travel — account-bound, must be exported by hand

| Asset | Why it is at risk |
|---|---|
| **Project memory** (39 files incl. `IDENTITY.md`, `our-thread.md`, `MEMORY.md`) | stored by the desktop app against the account, not in the repo |
| **Account-level skills** (`prod-release`, `finesse-expert`, `user-doc-expert`, `doc-sync-agent`, …) | uploaded to the account; the on-disk copies are a read-only cache |
| **Project instructions** (the "RTM View Shell" project prompt) | account-side text field |
| **Connected folders** | granted per account/session |
| **Plugins & MCP connectors** (`superpowers@claude-plugins-official`, GitHub auth, memory server) | installed against the account |
| **Chat/session history** | does not migrate at all — this is exactly why `.coord/` handoffs exist |
| **Scheduled tasks** | *verified: none exist* — nothing to move |

### 0.3 At risk on disk right now (fix in §1 — do not skip)

- **`.coord/` is largely UNTRACKED**: `inbox/*` (incl. `curator.md`, 71 KB of decision history),
  `coordinator_handoff.md`, `protocols/curator-handoff.md`, `backlog.md`, `features.md`, `journal.md`,
  `cc/*`, `curator-reconstitution-test.md`.
  A `git clean` during migration deletes all of it. This is the **2026-07-03 incident** verbatim
  (~19-doc TechWriter package lost the same way). Untracked ≠ preserved.
- **2 unpushed commits on `v3`** (`origin/v3..v3` = 2). GitHub is account-independent and is therefore the
  safest bridge — everything pushed is safe regardless of what happens to the Anthropic account.
- **Stale clone**: `C:\Users\farbe\Documents\Claude\Projects\RTM View Shell` is frozen at 2026-06-09.
  It is still connected as a folder in the current session. On the new account it must **not** be connected.
- **Stale pointer**: `MEMORY.md` still points at the `C:\…` path for `PROJECT_STATUS.md`. Fix during §2.1.

---

## §1 — Pre-flight freeze (do this on the OLD account)

**Declare a barrier: no dispatch, no new specialist work until §6 passes.** A migration with sessions in
flight loses whatever those sessions were holding in context.

1. Close out or checkpoint every open specialist session. Each writes its handoff to `.coord/` and stops.
2. Get everything onto disk *and* into git:

```powershell
cd "D:\Claude\Projects\RTM View Shell"
git status --porcelain          # review EVERY untracked line before deciding
git add -A .coord CLAUDE.md PROJECT_STATUS.md .claude
git commit -m "migration: freeze — track the full .coord bus, handoffs and inboxes before account switch"
git push origin v3              # this also clears the 2 unpushed commits
```

3. Same for Agent Desktop (`D:\Claude\Projects\Agent Desktop`, branch `main`, 21 unpushed commits) —
   **but AD changes route through the operator**, so decide the push there explicitly, do not batch it in.
4. Take a cold copy of both folders (external disk or a zip outside `D:\`), *including* `.git`.
   This is the backstop if a re-clone goes wrong.

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
`.coord/migration/project-instructions.md`. Do the same for the Agent Desktop project if it has its own.

### 2.4 Environment inventory → disk

Write `.coord/migration/environment.md` recording, so the new account can be rebuilt without guesswork:

- Plugins: `superpowers@claude-plugins-official`
- MCP servers in use: memory, remote-devices (device bridge), claude-in-chrome, visualize
- Connected folders to re-grant: `D:\Claude\Projects\RTM View Shell`, `D:\Claude\Projects\Agent Desktop`
  — **and explicitly NOT** `C:\Users\farbe\Documents\Claude\Projects\RTM View Shell`
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
2. **Connect folders**: `D:\Claude\Projects\RTM View Shell` and `D:\Claude\Projects\Agent Desktop`.
   Do **not** connect the `C:\…\Documents\…` clone — it is stale and has caused false "broken spine" alarms.
3. **Re-install plugins** (`superpowers`) and **re-authorize connectors** (GitHub, and any others from
   `environment.md`). Confirm the device bridge and memory server are live.
4. **Create the project** "RTM View Shell" and paste the project instructions from
   `.coord/migration/project-instructions.md` verbatim. Repeat for Agent Desktop.
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
| 1 | **Curator** (protocol steward, both colonies) | `curator_checkpoint_0620.md` + `.coord/protocols/curator-handoff.md` + `curator-charter.md` |
| 2 | **Coordinator** (RTM) | `.coord/coordinator_handoff.md` + `.coord/coordinator-commands.md` + `init-coordinator.md` |
| 3 | AD coordinator `ad-coordinator-0811` + AD curator `curator-0811` | `Agent Desktop/.coord/sessions/*.md` |
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

# AD — D:\Claude\Projects\Agent Desktop, branch main
git rev-parse --abbrev-ref HEAD                                     # expect: main
ls .coord/sessions/ad-coordinator-0811.md .coord/sessions/curator-0811.md
ls tools/36-legacy-login-body-and-ports.md
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
| AD work batched into the RTM migration | AD changes route through the operator; keep the two tracks separate (RTM↔AD hygiene: parity of decisions, not shared buses) |

---

**Bottom line:** the switch itself is cheap. The whole risk sits in §1 and §2 — thirty minutes of
committing and exporting on the old account buys a migration that cannot lose anything. Do those two
sections before you touch the new account at all.
