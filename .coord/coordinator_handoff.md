# Coordinator HANDOFF — LIVE resume state  (read FIRST on resume)
> RESUME CHECK — this marker satisfies role-coordinator §C VERIFY #3. Do not remove it.
> Rewritten 2026-08-17 by **coordinator-0817**; **refreshed 2026-08-18 by coordinator-0818** (attested
> that day; every pin below re-resolved from the object store on 2026-08-18, none inherited on trust).
> Supersedes the 2026-07-03 handoff by coordinator-0703, which had rotted: it pinned v3 HEAD=6945fc0 /
> origin=1b5778a / unpushed=1 — none of that resolved by 2026-08-17.
> Truth = object store + bus, not chat (NORM-CUR-13). A pin ages: state the date you resolved it.

> **Norm you inherit (init §3, revision aa16664):** the Anthropic-account topology is the CURATOR's beat,
> exclusively. Do not reason about it, do not record it in your session file, do not mention it in reports.
> And never infer your ENVIRONMENT from the documents you are reading — there is no object-store pin for it.
> This handoff's first version violated both halves; the lines were removed, not rephrased.

## GIT STATE — pins that resolve RIGHT NOW (re-verified 2026-08-18 by coordinator-0818)
- Branch = **v3** (single working branch since the v2-backend consolidation 9bf7c11, 2026-06-26).
  `.git/HEAD` -> `ref: refs/heads/v3`.
- **v3 = `9953e60c5db5367ae3c53331d482b314f3e5e18b`**, **origin/v3 = `f6d5c58b71ffd98aea5b762142c185c27eb96fd5`**
  -> **unpushed = 2** (`git rev-list --count origin/v3..v3` = 2). Both are curator attestation commits:
  `896214d` (coordinator-0818 entrance FAIL verdict) and `9953e60` (re-sit PASS). No product code.
  No barrier is open; a push needs the §37 quorum and is the operator's call, not mine.
- **Last PRODUCT commit = `d1982de`** (2026-07-22, WFM per-BU snapshot keyed by BusinessUnitId) —
  re-verified 2026-08-18: `git rev-list --count d1982de..v3` = **39**, and
  `git log d1982de..v3 -- src CcDashboard.Web tools/Soma db deploy infra` = **EMPTY**.
  So all 39 are curator / migration / protocol work. **No product code has moved since 2026-07-22.**
  (Read that as: the whole account-migration + attestation cycle cost zero product motion. The one live
  product thread — Queue Grid Max Wait / F5 — has been parked since 2026-07-16.)
- Last push barrier: `.coord/push/request.md` = **PUSHED (CLOSED)**, `cd0e39a..d1982de`, 9 commits
  (WFM Phase 1), quorum 6/6, closed 2026-07-22T18:05Z. FREEZE lifted. `push/acks/` left in place
  (mount cannot delete); superseded by the next barrier.
- The 2026-07-03 "UNCOMMITTED role-coordinator.md" warning is **resolved**: the pre-migration freeze
  commit landed it; the §A+§B constitution is in v3 as blob `abf6b96`.

## §C VERIFY of role-coordinator (re-run 2026-08-18 against v3 objects — ALL FIVE PASS)
| # | check | result |
|---|---|---|
| 1 | `session-coord.md` `L-SC-` occurrences | 59 matches on 48 lines — **PASS** (expect >20) |
| 2 | `CLAUDE.md` `## 42. Multi-session coordination` | 1 — **PASS** |
| 3 | `coordinator_handoff.md` contains `RESUME CHECK` | 2 — **PASS**. (Was FAIL at the 0817 init: the 0703 rewrite had dropped the marker — the CHECK was stale, not the code — and 0817 restored it. Do not remove it.) |
| 4 | `CLAUDE.md` `CC<->spec binding` | 3 — **PASS** |
| 5 | `.coord/protocols/init-coordinator.md` present in v3 | blob `4ed6510` — **PASS** (was `fd55acb` at the 0817 init; the file changed in `aa16664`, the check did not) |
| + | RTM standard pin `role-skill-standard.md` (blob `6cc4c2c`): `Local-validation gate`=1, `## Test-gate`=1, `DEFAULT-DENY`=1 | **PASS** |
| + | skill/CLAUDE.md/init disk-vs-blob sha256 round-trip (`abf6b96`, `da55021`, `4b9d79e`, `4ed6510`) | all **IDENTICAL** — booted on the bytes that are in the branch, not on a drifted mount copy |

Nothing in §A was found superseded by the code. §A is in force as written, **including the ⛔ ЧП /
EMERGENCY MODE flag (declared 2026-06-25, never lifted — the operator has never answered on lifting it).**

## ⚠ TOOLING — `device_bash` IS FLAKY AT BOOT, NOT ABSENT (read before you believe you cannot verify)
`device_bash` (the Linux VM on the operator's machine) **failed for the whole 0817 session** and again
for the first ~40 minutes of 2026-08-18 ("Workspace still starting" / "Workspace unavailable", 5 calls),
then **came up mid-session and worked normally**. So: it is a slow, unreliable boot — retry it
periodically instead of writing the session off. Until it answers, this looks like
"object store unreachable" and it is NOT.
**The workaround, verified working today:** `.git/objects/pack/` is **EMPTY** — the whole object store is
LOOSE objects. So: stage `.git/refs/**`, `.git/HEAD`, `.git/logs/HEAD` and the loose object files with
`device_stage_files`, copy them into a scratch `git init` repo in the cloud container, and run
`git cat-file -p` / `git show` there. Walk commit -> tree -> subtree -> blob, staging each object as you
learn its sha. Every pin in this handoff was resolved that way — real object store, not the mount.
Cost is ~1 stage call per tree level, so pin deliberately, not decoratively.
**Consequence for writes:** Python+`os.fsync` cannot run ON the device either. Writes go: compose in the
container (Python + `os.fsync` + byte/BOM/NUL check) -> `SendUserFile` -> `device_commit_files` with
`expectedMtimeMs` -> **re-stage and compare sha256 round-trip**. That is a stronger witness than a local
byte-count, but it is a DEVIATION from the literal §3 rule — say so when you use it.

## ✅ THIS HANDOFF **IS** IN GIT (was not, until 2026-08-17 — do not re-fix this)
Closed by **`ee8633c`** ("boot-critical .coord state exempted from the runtime ignore by RULE").
`.coord/.gitignore` still opens with `*`, but now carries explicit negations for
`!coordinator_handoff.md`, `!rejects.md`, `!features.md`, `!backlog.md` alongside `!protocols/**`
and `!migration/**`. Proof, not inference:
`git rev-parse 0c4c214:.coord/coordinator_handoff.md` -> `fatal: … but not in '0c4c214'`;
`git rev-parse ee8633c:.coord/coordinator_handoff.md` -> blob `708024f`. Current content = blob `0f6beaa`.
**STILL untracked, deliberately:** `.coord/inbox/*`, `.coord/cc/*`, `.coord/sessions/*`, `journal.md` —
the FLOW. Delivery rides the disk, git carries preservation. Consequence you must plan around: an inbox
does **not** survive an account switch, which is why entrance tests and keys live in `protocols/`.
The 2026-07-03 data-loss shape (a `git clean` took the whole HELD TechWriter package) still applies to
those paths. `git add` on them is a silent no-op — untracked = not saved.

## REGISTERS — open items (CONSTITUTION: never closed by my inference, only by the operator's word)
`.coord/rejects.md` (untracked, 35 KB) — open at last write 2026-07-16/17:
- 🔴 **R7** Export -> .xlsx: runtime error on click (bi owns post-push fix).
- 🔴 **REP-MENU-PG** `menu.reports` does not exist as a permission key (grep=0 in src) — Reports cannot be
  granted to a PG at all. owner shell+bi.
- 🔴 **ASD-BAR-BLUR** (declared 2026-07-06). 🔴 **GARNET-FLAP / INC-001d** (2026-07-02).
- 🟡 **PR234-1a** config saves null — ROOT `ParseWidgetConfig` silent-catch; strategy = diagnose on 234,
  probe `c23ec1f` RETAINED in the 234 build.
- 🟡 awaiting operator CONFIRM: R1, R2, R9, REP-DATA-RANGE (backfill done), ASD-NORENDER (fixed+durable
  `9648c09`), WIDGET-STICK (live-verified 2026-07-06, `adbf5d7` pushed).
- 🟠 **REPORTS-PG-GAPS** — known-open, operator-accepted, ships.
- **Queue Grid Max Wait resets on F5** — owner PINNED = RTM/backend; widget cleared as faithful; backend
  dispatched to emit `+`-duration as now-enqueue. **This was the last live product thread (2026-07-16T23:27Z)
  and its FIX push # is still `<pending>`.** US-Queue-Grid inflation/empty tracks: RESOLVED (`01dbc2c`
  server-local date-guard, operator confirmed) + `961a979` grid on-demand SEALED, awaiting CONFIRM.

`.coord/features.md` (untracked, 21 KB):
- 🟡 **F-SCALE-TOGGLE** delivered-pushed, visual A/B not taken.
- WFM Phase 1: C2 live gate **PASSED** 2026-07-22; sub-BU "No Data" was a CONFIG gap, not a bug.
- WFM Phase 2 candidates (B2/B4 decoupled into two widgets, graph series-selection + tooltip) — all
  "рассмотрение": design/analysis only, **not approved for build**.
- Backlog: Site TimeZone wrong + not DST-aware (ITEM A, operator-deferred); DayTrend ~4h lag; broad
  BU/SG hot-reload epic.

## INBOX — what is actually waiting
`.coord/inbox/coordinator.md` (634 KB, 4269 lines). Product traffic ends 2026-07-22 (WFM). Only ONE item
is live, at the tail:
- **2026-08-17T13:55Z | from: curator (gmail, curator-0817)** — a standing OPERATIONAL constraint exists
  ONLY in the frozen bus-snapshot. Verified by me today, independently:
  `CLAUDE.md` grep `NEVER restart legacy` = **0**, `self-reconnect` = **0**, `RTMService` = **0**.
  The constraint's pins DO resolve: `bus-snapshot/inbox/coordinator.md:2292` = the
  `⛔ CORRECTION 2 (operator directive) — NEVER restart legacy; the adapter must self-reconnect` header
  (count 1), and `bus-snapshot/inbox/backend.md:917` = the wording verbatim (count 1).
  The bus-snapshot is a ONE-SHOT migration freeze, not a live mirror -> a role booted from the init prompt
  reads CLAUDE.md and the skills and never learns this. Recurrence already happened once
  (2026-07-14 adapter warm-swap `6ebd39f`, rolled back).
  **MINE to word and to §4.** Proposed home: `CLAUDE.md §48` as `[WIRE-06]` (the adapter↔RTM wire-contract
  section, which already carries the standing-validation gate). Wording drafted and PRESENTED to the
  operator 2026-08-17; **not written until the operator says go** — CLAUDE.md is a norm surface.
- Second, same class, no task attached: the curators established `journal-digest.md` in `protocols/`,
  forward-only, for "negative knowledge" (why the workaround, recurrence counter, retracted hypothesis) —
  the class git cannot hold, because a commit records what IS. Most of it is born in coordinator work.
  Write it in the moment you learn it.

`.coord/cc/*.md` — no fresh RESULT to consume (newest is `curator.md`, 2026-08-11).

## QUEUE (no parallelism; the operator sets the order)
1. **Legacy-restart norm into CLAUDE.md §48 [WIRE-06]** — wording presented, awaiting operator go.
2. **Queue Grid Max Wait / F5 re-anchor** — the one open product thread; backend owns; FIX push # pending.
3. Resume the reject sweep: R7, REP-MENU-PG, ASD-BAR-BLUR, GARNET-FLAP; collect operator CONFIRM on the
   six 🟡 items so they stop occupying the register.
4. `journal-digest.md` — start it forward-only.
5. Deferred, unchanged: `__EFMigrationsHistory` relic (DROP?) · typo-metric baseline-add · SF-SEC-001
   rotation (+ the Garnet password, same compromised secret) · db/tools vs devops/tools compare-sync ·
   QA BU∩PG live-verify · TW doc-debt (A-01/B-07/§16) · **the ЧП flag has never been lifted.**

## HARD REMINDERS (standing)
- NO `git push` except `tools/cc_prompt_push.md` after the QA+Security+TW quorum (§37). Narrow explicit
  `add` only — never `-A`, never by folder (and `add -A` is a **no-op** against the `.coord` ignore).
- All `.coord/` and `CLAUDE.md` writes: Python + `os.fsync`, Edit-tool BANNED, verify bytes/BOM/NUL —
  never line counts. Never through a PowerShell pipe (`Set-Content -Encoding utf8` injects a BOM).
- Never run an index-touching git command over the mount (`status`/`add`/`diff`) — the orphaned
  `index.lock` cannot be removed by the bridge and the operator's repo wedges.
- Tool success ≠ delivery. And verify the PREDICATE, not just the exit code: "matched" on a wrong grep is
  worse than "did not match".
- §4 gate: every specialist prompt gets my bless BEFORE it runs, by checklist, not by eye.
- ONE question to the operator at a time, by importance, plain language. A code box IS a request, not an
  attachment — the operator queue is ONE queue; hand out a run, then WAIT for its result.
- I am a router, not a courier and not an implementer. Content travels on the bus.
- Untracked = not saved (lesson 2026-07-03).
