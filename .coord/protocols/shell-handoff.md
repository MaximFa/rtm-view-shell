# Shell role — migration handoff & resume anchor

## ▶ BOOT BLOCK — как поднять читателя этого файла (норма Н-1, 2026-08-29; здесь исполнена 2026-09-05)
- start prompt (оператор запускает ЭТО): `.coord/protocols/init-shell.md`
- этот хендоф: `.coord/protocols/shell-handoff.md`
- роль-скилл: `.claude/skills/role-shell/role-shell.md` (v0.2)
- шина: `.coord/` · входящие: `.coord/inbox/shell.md` · CC-канал: `.coord/cc/shell.md`
- клон — ТОЛЬКО `D:\Claude\Projects\RTM View Shell`
- **Тот же инит — промпт ВОЗОБНОВЛЕНИЯ после внезапной автокомпакции, не только холодного старта.**
- ⚠ **Дефект твоего роль-скилла, снят куратором 2026-09-05:** файл начинается с BOM (`EF BB BF`),
  поэтому YAML-шапка НЕ читается как frontmatter. Тело цело (NUL=0, диск==стор), но шапка мертва.
  Скилл — твоя территория, чинишь ты: снять BOM, записать байтами (Python+fsync), проверить
  первые три байта и NUL по обоим телам. Благословения координатора на правку своего скилла не нужно.

---

## ВХОД ДЛЯ ИНКАРНАЦИИ 2026-09-05 — записано куратором

**Пины на момент записи (пере-сними сам, чужие пины не наследуются):** `v3 = 18c61a0`,
`origin/v3 = 79e3905`, непушенных 7. Версия продукта на 234: Shell/RTM `d1982de`, адаптер `8abd19a`.
БД на 5433 (PG18), старая на 5432 не тронута.

### ПРЕДМЕТ: `PR234-VIEWEDIT-01` (реестр реджектов, OPEN)
Экран `01a04c39-caac-7107-8d59-d40fb48a94fa` («בזק - ניהול משמרת פרטי»), `platform.insightense.com:8444`.
Заявлен оператором, **проверен координатором лично**, оба режима подряд, одно окно:
- **view** (`/screens/{id}`): содержимое вписано целиком, ничего не обрезано.
- **edit** (`/screens/{id}/edit`): слева пустое поле разметки в клетку, содержимое сдвинуто,
  **правый край обрезан** — крайняя правая плитка срезана. Есть обе прокрутки холста.
- **Данные в обоих режимах ИДЕНТИЧНЫ** — те же строки, те же значения. Расходится только раскладка.

### ⛔ ЧТО ТЕБЕ ЗАПРЕЩЕНО ПРИНИМАТЬ КАК ФАКТ
Координатор назвал это сам, и я передаю дословно, потому что вход пишет он и может отравить его
собственной догадкой. Известно: экран правосторонний (RTL, иврит), и в продукте есть переключатель
масштаба просмотра (`viewerScale`, «Actual size 1:1», заведён в PR234-1c). Напрашивается, что
просмотр вписывает содержимое масштабированием, а редактор — нет, и в RTL обрезается начало строки.
**Это НЕ предикат и НЕ версия координатора. Это контекст, который может оказаться ни при чём.**
Твой первый замер — измерение ФАКТИЧЕСКОЙ раскладки в обоих режимах: какой контейнер, какие ширины,
есть ли трансформация масштаба, где именно происходит обрезка. Не проверка чужой догадки.
Предикат координатор зафиксирует ДО прогона, после того как ты назовёшь, что собираешься мерить.

### ГРАНИЦЫ
Только чтение. На 234 ничего не менять. Не трогать: боевую `RTM.Twilio`, legacy `RTM`, `C:\IceDash\`,
виджет 78. `QGRID-78` ведёт `devops-0905` — туда не лезть. NO push.

### ГЕЙТ ГОДНОСТИ ЗАМЕРОВ (куплен дорого, применяется без исключений)
`stderr` условием, а не напечатанной величиной · маркер завершения при `ON_ERROR_STOP=1` ·
негативный контроль, **подобранный под ту ошибку, которую предикат реально может совершить**, а не
формальный · вывод замера ФАЙЛОМ, в консоль только путь (норма оператора 2026-09-05).

### КТО ЧТО ВЕДЁТ
`§4` ведёт координатор, не куратор. Ран-бокс авторства специалиста, благословение координатора,
оператору бокс несёшь ты сам. Вступительный тест не сдаёшь — роль аттестована 2026-08-31.


**Author:** shell-0609 · **Date:** 2026-08-31 · **Branch:** v3 · **For:** the incoming Shell on the NEW account
**Amended:** shell-0831, 2026-08-31 — §4 resume point re-pinned (see the warning there); attested by the curator this day.
**Read alongside:** `.claude/skills/role-shell/role-shell.md` (§A CORE every boot + §B LESSONS + §C VERIFY) ·
`CLAUDE.md` (§0 discipline, §21 screens, §34 relay, §41 localStorage, §42/§26 coordination) ·
`.coord/protocols/account-migration-runbook.md` (§4/§5 reconstitution + gate) ·
`.coord/inbox/shell.md` (your mailbox — the step-by-step resume is appended there).

---

## 1. Who you are
- **Role:** Shell — the Blazor Server UI/UX specialist for RTM View Shell (CcDashboard). Old-account slug was
  `shell-0609`; pick a fresh MMDD slug on boot (e.g. `shell-0901`) and write `.coord/sessions/<slug>.md`.
- **Territory (`web` claim):** `src/CcDashboard.Web/**` + the Contracts/Application/Infrastructure DTO/command/query
  surface you touch for a UI feature (use file-mode claims where you overlap backend). You render/configure widgets
  and admin screens. You do NOT own the RTM engine, DB functions, or deploy.
- **You NEVER edit code directly.** Every code change is authored as a CC prompt in `tools/<name>.md`, self-§4-reviewed,
  submitted to the coordinator for §4-bless, then run by native CC / the operator. You (Cowork) analyse, author,
  review, verify, reconcile, and flush to the bus.

## 2. Iron rules (load-bearing — each was learned from a real loss or false alarm)
- **§0.3 WRITES:** the Edit tool is BANNED on this mount. All writes via **Python + `os.fsync`**, then verify `tail`+`wc`.
  `tools/*.md` and `.coord/**` are Cowork-allowed direct writes (still Python+fsync). **NEVER a PowerShell pipe** for
  `.coord` files (PS 5.1 injects a UTF-8 BOM / mojibakes — § → — runbook §7).
- **§0.5 VERIFY BY OBJECT STORE, not the mount.** `git status` / line-counts LIE here (false `M`). Prove state with
  `git hash-object` vs `git rev-parse HEAD:<f>`, `git cat-file -e`, `git show`. Do NOT escalate "corruption" from a mount read.
- **PD-007:** after any commit the Cowork cache can re-truncate committed files. Hash-verify claimed files `==HEAD`;
  restore with `git show HEAD:<f> > <f>`.
- **L-SC-04:** the mount drops journal/binding lines. If a CC RESULT is missing but the commit exists, RECONCILE from
  the object store and write the reconciled RESULT to `.coord/cc/shell.md` yourself.
- **§0.6 / §37 — NO PUSH, EVER, by you.** Push runs only via the dedicated push prompt after a full push-barrier
  quorum, operator-executed. From the mount you cannot push reliably anyway (L-SC-20).
- **§26.8 §4-GATE:** self-§4-review every prompt, then submit to the coordinator for §4-bless. Do NOT run before bless.
  Fold any §4 condition INTO the prompt before it runs (pin facts by reading code — never defer to "verify later").
- **§22 CC-only:** no inline code; the canonical run form is exactly `Выполни задачу из файла tools/<name>.md`.

## 3. Operator working style (from memory)
- `.` = process your inbox (`.coord/inbox/shell.md`) + act on coordinator directives now.
- `..` (or `.` / `,`) = VERIFY the last CC result NOW by object store, reconcile, report — NOT "I am waiting".
- Give the operator/devops steps as **complete copy-paste commands** (full paths, real service names), never prose.
  140/prod layout: InstallRoot `C:\RTMView`; Shell dir `C:\RTMView\Shell`; appsettings `C:\RTMView\Shell\appsettings.json`;
  Windows service `RTMViewShell`; Serilog `C:\RTMView\Shell\logs\log-<date>.txt`; Kestrel orphan-exe (not IIS); server UTC+3.
  Per §43 CC has no external-server access → the OPERATOR runs them.
- Ask clarifying questions as **TEXT ONLY** (the AskUserQuestion tool hangs). Concise answers; dialog RU, docs/code EN.
- Build/unit via **Soma** (§47) over host-Chrome (mount sandbox can't reach host loopback); token from
  `tools/Soma/appsettings.json` (never print/commit). No `build0` claim without evidence; if Soma down, route to devops.

## 4. CURRENT RESUME POINT (re-pinned by shell-0831, 2026-08-31T11:xxZ)
- **Branch v3.** Pin taken THIS awakening: `HEAD = 9628551`, `origin/v3 = 79e3905`,
  `git rev-list --count origin/v3..v3` = **3** — none are shell/web (curator/coordinator work).
  Do not touch or push them (§0.6/§37).
  **⚠ THE UNPUSHED COUNT IS THE ONE FACT IN THIS FILE THAT ROTS FASTEST — RE-PIN IT, DO NOT READ IT.**
  History of this very line: shell-0609 wrote "HEAD = 26ecfcb, origin/v3 = f6d5c58, 24 unpushed" and it was
  true when written; the operator pushed everything at ~09:0xZ (`f6d5c58` -> `79e3905`, 27 commits), so the
  incoming shell-0831 measured **0**; by 11:xxZ it was **3** again. Three different true values in one day.
  A mismatch here is NOT an alarm and NOT a reason to stop — it is work done between the write and your boot.
  What is invariant and IS load-bearing: **none of the unpushed commits are ever yours to push.**
- **THE SHELL ROLE IS IDLE.** No open CC task, no open ack, no push obligation.
- **Last shell delivery = WFM Phase 1 UI — PUSHED + CLOSED** (barrier cd0e39a..d1982de, 9 commits, quorum 6/6,
  2026-07-22T18:05Z; C2 live gate PASSED on 140 with real data: State OK, λ 40/hr, AHT 4:57, N 14, A 3.30 Erl,
  SL 100%, Occ 23.6% — percents NOT double-scaled). Commits: `e84e654` (3c-config: 8 Wfm* fields end-to-end + Tenant
  modal WFM tab) + `30225d6` (3c-widget: WfmWidget reads Singleton `IWfmSnapshotStore` on a 5s PeriodicTimer per
  §34.7 — no hub, no localStorage; renders the §4 contract). Both in origin.
  - **Percentage-scaling pin (permanent):** WfmWidget `FormatPct` renders `*Pct` AS-IS (already 0..100 from the loop);
    `FormatPWait` ×100 the 0..1 `PWaitC`. Never double-scale (the 80%→8000% bug).
  - **Sub-BU "No Data" in WFM = customer CONFIG gap** (BUs without SuperGroups), NOT a shell defect — do not chase.
- The stale `.coord/push/request.md` on disk is the CLOSED WFM barrier (acks left in place — the mount forbids delete).
  Not an open obligation.

## 5. HELD / BACKLOG register (shell) — resume ONLY when the coordinator/operator re-prioritises
1. **TZ Edit-Site IANA UI** — operator BACKLOGGED (stand-down 2026-07-20T16:12Z). Draft preserved; design in
   `docs/design/RTM-Timezone-Coherence-Design.md` + decisions in `.coord/features.md` ITEM A. Do NOT resume unless re-opened.
2. **Agent States Activate/Delete UI** (`tools/cc_prompt_shell_agentstates_activate_delete.md`) — HELD: needs backend to
   add 4 commands (Activate/Delete for State + Group) first.
3. **AgentGrid Duration F5-reset** — separate follow-up: AgentGrid duration comes via the AgentSnapshot path (no
   Value2/enqueue instant); relay/AgentSnapshot must carry the enqueue instant before the QueueGrid-style anchor fix applies.
4. **EDIT-500 InfoSlot concurrent-context co-review** — bi-led; pending.
5. **T3 AUDIT matrix** — enumerate every UI config-change action vs RTM live-pickup (does a saved config change reflect
   live without a restart). In progress / interleaved.

## 6. Boot sequence on the new account (in order — mirrors runbook §4/§5)
1. Read THIS file + `.claude/skills/role-shell/role-shell.md` (§A every boot; run §C VERIFY against current code/CLAUDE.md
   by object store — the artifact wins on mismatch).
2. Mechanical self-check (object store only):
   `git rev-parse --abbrev-ref HEAD` (expect `v3`) ·
   `git merge-base --is-ancestor 30225d6 origin/v3 && echo WFM-in-origin` (expect it) ·
   `git rev-list --count origin/v3..v3` (note the number; none are yours).
3. Write `.coord/sessions/<your-slug>.md` (status active, cc_task none, claims [] — you are idle).
4. Read `.coord/inbox/shell.md` fully; there is NO open shell task as of this handoff.
5. Report a one-line bus summary to the operator and GO IDLE. Wait for a `.` poke. Never start work off memory.

## 7. Anchors
- role-skill: `.claude/skills/role-shell/role-shell.md`
- widget conventions: `.claude/skills/widget-creator/` + `widget-planner/`
- coordination: `.claude/skills/session-coord/` (§10 command registry), `CLAUDE.md` §42/§26
- your mailbox: `.coord/inbox/shell.md` · your CC binding channel: `.coord/cc/shell.md`
- migration: `.coord/protocols/account-migration-runbook.md`
