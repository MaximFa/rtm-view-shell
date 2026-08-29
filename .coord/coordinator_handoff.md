# Coordinator HANDOFF — LIVE resume state  (read FIRST on resume)

> ## ▶ КАК ПОДНЯТЬ КООРДИНАТОРА — ПУТИ, А НЕ ПАМЯТЬ
> **Стартовый промпт (его запускает оператор):**
> `D:\Claude\Projects\RTM View Shell\.coord\protocols\init-coordinator.md`
> **Этот хендоф (живое состояние, читается вторым):**
> `D:\Claude\Projects\RTM View Shell\.coord\coordinator_handoff.md`
> **Роль-скилл:** `.claude/skills/role-coordinator/role-coordinator.md` · **шина:** `.coord/`
> **Клон — только `D:\`.** Клон в `C:\Users\...\Documents\...` СТЕЙЛ (заморожен на 2026-06-09), не трогать.
> Тот же файл инита запускается и после ВНЕЗАПНОЙ АВТОКОМПАКЦИИ посреди работы — см. в нём **§5a**.
> *(Записано 2026-08-30 после вопроса оператора: путь к иниту не был зафиксирован НИГДЕ — ни здесь, ни в
> `MEMORY.md`, ни в `CLAUDE.md`, ни в `PROJECT_STATUS.md`. Он жил только в голове оператора. Не удаляй этот блок.)*

> RESUME CHECK — this marker satisfies role-coordinator §C VERIFY #3. Do not remove it.
> Line: 0817 -> 0818 -> **refreshed 2026-08-30 by coordinator-0818** (same incarnation, mid-operation).
> Truth = object store + bus, not chat (NORM-CUR-13). **A pin ages: state the date you resolved it.**

> **Norms you inherit.** (1) Anthropic-account topology is the CURATOR's beat — do not reason about it,
> do not record it, do not mention it in reports (init §3). (2) Never infer your ENVIRONMENT from the
> documents you read — there is no object-store pin for it. (3) **Run-boxes are issued by SPECIALISTS,
> not by the coordinator** (operator 2026-08-29). The coordinator blesses by §4 and accepts results.
> (4) Every report to the operator ENDS with a poke table + "who is working now" (operator 2026-08-29).

## GIT STATE — re-resolved 2026-08-30 from `.git/refs` + `.git/logs/HEAD`
- Branch **v3**. **v3 = `dae095dd546db23a1a753696e88aff0092b76bb4`**,
  **origin/v3 = `f6d5c58b71ffd98aea5b762142c185c27eb96fd5`** -> **unpushed = 20**, all curator/protocol.
- **Last PRODUCT commit = `d1982de`** (2026-07-22). Product code has NOT moved since.
- Push barrier: none open. `push/request.md` = PUSHED (CLOSED) since 2026-07-22.
- ⚠ **§C VERIFY was NOT re-run in this wake** — last full 5/5 PASS was 2026-08-18 (see the 0818 table in
  git history of this file). Refs above ARE re-resolved today. Do not claim §C as fresh; re-run it.
- ⛔ **ЧП / EMERGENCY MODE still ACTIVE** (declared 2026-06-25, never lifted).

## WHERE THE WORK IS — CONVERGE 234, mid-operation. READ THIS BEFORE TOUCHING ANYTHING.
**Goal (operator 2026-08-29):** upgrade 234 to `d1982de` FIRST, then look at bugs — "часть из них уже
закрыта актуальной версией". Bug review is QUEUED BEHIND the converge, deliberately.

**State of 234 as of 2026-08-30: the production database is UNCHANGED. Zero writes. Backup pair intact**
(`C:\RTMView-Ops\backup\rtmviewdb_20260829_1129.dump` 19 949 183 B,
SHA256 `EEA7B798F801DB13E887822885235D8FAF500BB16556A837E4681A672679F468`, +
`C:\RTMView\Backup\20260829_1129`). Package `Installations\29082026.1119.zip` (BUILD=0, unit 283/0,
tree == `d1982de`) built and unused.

**Why it is not a simple deploy:** 234 sits on the **2026-06-24** schema
(`20260624093015_AddReportEntities`). Three App migrations pending; the first,
`DropAppOwnedBackendTables`, CASCADE-drops 26 tables holding the customer's LIVE NGC topology
(BU 59 / Queues 61 / SG 41 / AG 43 / UserAG 566 / mappings) + RTSGrid user widgets + 202 917 rows of
`RTSData_UserStatusLog`. `db/data` seeds only Site+metrics+grids — **no repo path restores that data**,
and 140 passed these migrations on an EMPTY DB, so no proven transfer path existed. Hence: converge WITH
an explicit data transfer, procedure `tools/cc_prompt_converge234_transfer.md` (Rev 11+, §4-blessed).

**The rehearsal (on a restored copy of the real 234 DB, DEV) found TEN defects, each of which would have
hit 234 — most of them AFTER the drop, i.e. at the most expensive moment:**
1. `pg_restore --data-only` is all-or-nothing per table; `NGC_Queues`/`NGC_AgentGroups` carry a June
   `CreatedDatetime` the target lacks -> both would have loaded ZERO rows. Fixed: §STRUCT-DIFF + column-list copy.
2. Silent type drift `RTSData_UserStatusLog."Duration"` integer -> bigint. Widening, approved,
   MAX measured = 604 821 887 vs int4 ceiling 2 147 483 647.
3+4. TWO independent defects in the shipped `Provision-FreshDb` resync block: `deptype='a'` misses
   `GENERATED ALWAYS AS IDENTITY` (all 15 are `'i'`), and no `quote_ident` (fails on PascalCase).
   **Suspected root cause of the server-45 `23505` incident.** Own resync used instead.
5. Metric check queried `RTSGrid_Cell.MetricId` — a column that DOES NOT EXIST. Redirected to
   `RTSUserGrid_Column.MetricId`; the `Cell."Value"` half declared UNDECIDABLE, demoted to information.
6. Integrity gate expected 0 where the SOURCE already carries 21 dangling `RTSGrid_Cell` + 81 dangling
   `NGC_UserAgentgroup`. Fixed: **compare against the SOURCE BASELINE, not against zero** — more = we
   broke it, LESS = we silently "repaired" customer data, both STOP.
7. Probe (b) was defined to fire on OPEN; it fires on **SAVE**, on `/screens/{id}/edit`. Probe (a) needs a
   **UTF-16LE** search (text grep gives a false 0 on managed assemblies).
8. `DefaultTenantSlug` — tenant unresolved, nobody can log in while every DB number is green.
   Made a STEP (measure slugs+host on 234 BEFORE, write key AFTER swap BEFORE service start), not a check.
9. Parked since 2026-07-03: "local HTTPS impossible" — was a bad certificate. Fixed on DEV.
10. **PostgreSQL VERSION MISMATCH — the one that also indicts the coordinator.** The rehearsal ran on
    PG **18**; 234 production runs **15.5**. The dump preamble carries `transaction_timeout` (a 17+ GUC);
    with `ON_ERROR_STOP=1` the schema step would have aborted **after the 26-table drop**.
    `CLAUDE.md:370` claims "PostgreSQL 18 (production)" — documentation defect, contradicted by the server.

**OPEN DECISION, WITH THE OPERATOR (asked 2026-08-30, unanswered):** PG **18.4 is already installed and
running on 234**, port 5433, EMPTY. devops proposes restoring the pinned dump there, running the WHOLE
converge on 18.4 (the version the rehearsal actually validated), and at the end switching both
`appsettings` from `Port=5432` to `5433` + restart. Consequences: the live PG15 DB is never modified;
version mismatch disappears; outage shrinks to "switch port + restart"; rollback becomes "restore
Port=5432 + restart" with the untouched live DB still there (stronger than the dump pair, which remains).
**Coordinator's recommendation: YES.** But it is a STRATEGY change (prod-mirror migrates PG major as a
side effect), so it is the operator's call under §A, not a procedure tweak.
Read-only facts requested before the decision, NOT yet in: exact `version()` on all three instances;
**provenance of the empty 18 instance** (who/when/maintained — we already lost half a day to
`rtmviewdb_prodstg`, an orphan object of unknown history); **who else connects to `rtmviewdb` on 5432**
(legacy, Soma, backup jobs — after the switch they would silently keep using the OLD database);
`pg_hba.conf` of 18; `ccdashboard_user` password read on-box.

**Gate order agreed for Phase P** (each with a STOP to the coordinator): integrity+identity `tip==d1982de`
-> §DB-INTAKE-01 App+Audit -> §STRUCT-DIFF full pass, ALL drifts in ONE report -> BE §DB-INTAKE -> schema.sql
+ ownership AND privileges -> functions + data(`02`,`05` only — `03`/`04` TRUNCATE the transfer set!) +
3 named migrations -> RELOAD -> IDENTITY resync -> integrity vs SOURCE BASELINE -> slug step -> binary swap
-> **services started LAST** -> post-checks (feed-dependent only after §FEED-READY; never across local midnight).

**Left deliberately:** `rtmviewdb_reh` on DEV (rehearsal evidence, drop on coordinator's word),
`rtmviewdb_src` staging on PG15/234 (keep until the PG path is decided), new DEV cert `DF556BEF`.

## MY OWN MISSES TODAY — read these, they are the cheapest lesson in this file
Three times I asserted from plausibility instead of reading the source, and I hold the §4 gate that exists
to catch exactly that:
1. I accepted the predecessor's metric predicate on `RTSGrid_Cell.MetricId` at §4 — the column does not exist.
2. I attributed the login defect to `a261840`; devops opened the file — that commit introduces a different,
   seed-time key. `DefaultTenantSlug` is read per-request by `TenantResolutionMiddleware`.
3. I accepted a rehearsal without asking the PostgreSQL version of the target.
**My ruling survived in case 2, my argument did not — say that distinction out loud when it happens to you.**

## REGISTERS — open (CONSTITUTION: closed ONLY by the operator's explicit word)
`.coord/rejects.md` (now tracked): 🔴 R7 Export .xlsx runtime error · 🔴 REP-MENU-PG (`menu.reports` key
absent, grep=0) · 🔴 ASD-BAR-BLUR · 🔴 GARNET-FLAP · 🟡 PR234-1a (probe `c23ec1f` present in d1982de,
11 markers — diagnosis depends on the converge) · 🟡 awaiting CONFIRM: R1, R2, R9, REP-DATA-RANGE,
ASD-NORENDER, WIDGET-STICK · 🟠 REPORTS-PG-GAPS.
**Queue Grid Max Wait / F5 — SHIPPED `89feb34`+`16c6011` (2026-07-20), the register never recorded it.**
`.coord/features.md`: F-SCALE-TOGGLE 🟡 · **AI-виджет: КНОПКА на Agent Grid ПЕРВОЙ, чат вторым**
(operator 2026-08-29); product invariant — **our math computes, the model only narrates**; any number in
the answer must exist in the input contract before the API call. Open: ИБ-gate §8-14, conflict with
`avoid-paid-components`, hole #1 "what is a good recommendation".

## QUEUE
1. **Operator's decision on the PG path** — everything else waits on it.
2. Converge 234 -> then the operator shows bugs on the fresh version.
3. `[WIRE-06]` into `CLAUDE.md`: "legacy is NEVER restarted; the adapter self-reconnects" exists ONLY in the
   frozen bus-snapshot (`migration/bus-snapshot/inbox/coordinator.md:2292`, `backend.md:917`);
   `grep` in CLAUDE.md = 0. Wording + §4 are mine. Also fix `CLAUDE.md:370` PG version.
4. Five red rejects need the operator's word. 20 unpushed commits; `tools/cc_prompt_push.md` is STALE
   (pushes to `v2`) — fix before any barrier.
5. `db/tools` change: both resync defects. Pre-existing data drift 21+81 on 234: recorded, NOT repaired.

## HARD REMINDERS
Object store, not mount, not memory · no index-touching git over the mount · Python+`os.fsync` for
`.coord/`, verify bytes/BOM/NUL, never line counts · **specialists issue run-boxes, I bless and accept** ·
ONE question to the operator at a time, and every report ends with the poke table · I am a router, not a
courier and not an implementer · untracked = not saved (`.coord/` now tracks handoff/rejects/features/
backlog; inbox and sessions are still NOT) · tool success != delivery, and verify the PREDICATE ·
NO push outside `tools/cc_prompt_push.md` after the §37 quorum.


---

## ВОССТАНОВЛЕНО КУРАТОРОМ 2026-08-29 — два раздела, снесённых переписыванием

Хендоф был не ОБНОВЛЁН, а ПЕРЕПИСАН (`c46666c` 12123 B -> `984fb19` 11352 B; старое тело в новом не
содержится). Часть замен по делу. Но эти два раздела исчезли без замены, и оба — НЕГАТИВНОЕ ЗНАНИЕ:
класс, который git не хранит и который следующая сессия оплачивает заново. Возвращены дословно из
блоба `c46666c`. **Норма: хендоф ОБНОВЛЯЕТСЯ, а не переписывается; изъятие делается явно и с причиной.**

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
