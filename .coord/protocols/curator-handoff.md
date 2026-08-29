# CURATOR HANDOFF — LIVE resume (RTM-Bybet Consult / curator-0611)
> Read FIRST on a fresh curator session, THEN drift-check to object store. Companion: memory `curator_checkpoint`
> (auto-surfaced) — the full state lives there; this file carries the mechanical self-check pins.
> Updated: 2026-08-29 — слой подъёма закрыт, комплект аттестации готов, этап: верификация команды на резерве.
> ⚠ ДАТА: часть артефактов 2026-08-2x помечена автором как «2026-08-18» — сессия куратора шла по дате
> из своего окружения и не сверила её с часами устройства. Пины (sha) верны, ошибочны только подписи дат.

## Who / iron rules
PROTOCOL & DISCIPLINE STEWARD. Review-only; no code/deploy.
SCOPE — read `## Scope change` below before acting: cross-project (RTM + Agent Desktop) on the ORIGINATING
account; **RTM View Shell ONLY** on the post-migration account.
- NORM-CUR-13: object-store or nothing (git show/cat-file/hash-object, never mount/memory; local git IS the object store).
- git-mount-distrust: mount lies; writes = Python+os.fsync; verify bytes+NUL not line-count.
- RTM<->AD hygiene: parity of DECISIONS, no bus cross-posting; curator = sole bridge; any AD change via operator.
- DRIFT-WATCH: process-machinery accretion + product-freeze = the failure mode. Ship product, not process.
- Clones: RTM = D:\Claude\Projects\RTM View Shell (branch v3; NOT C:\...\Documents). AD = D:\Claude\Projects\Agent Desktop (branch main).

## Self-check pins (the reconstitution test)
**RTM pins — MANDATORY on every account, always:**
- RTM v3: `git show v3:.coord/protocols/role-skill-standard.md` grep 'Local-validation gate' == 1 AND '## Test-gate' == 1.

**AD pins — ONLY on the originating account (where the Agent Desktop clone is connected):**
- AD main: HEAD == 7909e46, unpushed == 21 (may advance as #36 lands); sessions ad-coordinator-0811 + curator-0811 present;
  tools/36-legacy-login-body-and-ports.md present.
- On the post-migration (RTM-only) account these pins are **RETIRED, not failing.** A missing Agent Desktop clone is the
  EXPECTED state there and is NOT a reconstitution failure — do NOT declare yourself un-live over it, and do NOT try to
  reconstruct AD state. Verify the RTM pins and proceed.

Confirmed resolving at update time (2026-08-11T21:29:48Z), on the originating account.

## Scope change — operator decision, 2026-08-17
RTM View Shell moves to a NEW Anthropic account; **Agent Desktop STAYS on the originating account.** Consequences:
- The cross-project bridge role ENDS. AD is not orphaned: its bless-gate was handed in full to `curator-0811`
  (2026-08-11), which is AD's own steward. Nothing to hand over, nothing to escalate.
- On the new account the curator is SINGLE-PROJECT (RTM). The `RTM<->AD hygiene` rule above becomes inert there —
  keep it as recorded history, do not act on it, do not go looking for an AD clone to bridge to.
- `curator-continuity-canon.md` stays fully in force: it is project-agnostic, and the fact that it was written after
  the AD drift is provenance, not scope.
- **Stale scope claims in the exported memory package.** `curator_checkpoint_0620.md` and
  `curator_crossproject_hygiene.md` (in `.coord/migration/project-memory/`) still define the role as
  "cross-project steward over RTM + Agent Desktop". Those exports are deliberately FAITHFUL copies and were not
  rewritten. **This section overrides them.** A curator booting on the new account that reads a cross-project scope
  from memory is reading pre-migration history, not its own mandate.

## Состояние на 2026-08-29 (заменяет прежние Live task и drill-блок)

**Пины, снятые при написании:** `v3 = 0c9926e`, `origin/v3 = f6d5c58`, **непушенных 17** — все протокольные.
Гейты стандарта 1/1. Роль-скиллов **12**, инитов **13**, вступительных тестов **12**.
Последний ПРОДУКТОВЫЙ коммит — `d1982de`, **2026-07-22**. Продукт не двигался **38 дней**: это красный сигнал
самопроверки на дрейф, объявлен вслух оператору, следующее движение обязано быть продуктовым.

**Режим работы, поставленный оператором 2026-08-29.** Два аккаунта: `profit` — рабочая сторона,
`gmail` — холодный резерв, включаемый когда лимит `profit` подходит к концу. Диск, репозиторий и шина —
общие; параллельной работы одной роли не бывает. Протокол — `.coord/protocols/switch-protocol.md`.
Межаккаунтный канал куратора — `.coord/protocols/curator-crossaccount.md`, **в git и потому пришпиливаемый,
в отличие от инбокса**. Слаги: `profit` / `gmail`, слаг за аккаунтом, не за личностью.

**ТЕКУЩИЙ ЭТАП, и дальше него не двигаться:** `gmail` поднимает и аттестует у себя **полную команду**
(10 ролей помимо себя и координатора) и убеждается, что они подхватят работу. Барьер, 17 непушенных и
возврат мяча — СЛЕДУЮЩИЙ этап. Я уже сбился на него один раз (запрос `16:40Z`, отозван записью `17:20Z`):
увидел блокер и переключился на его расшивку вместо назначенного порядка. Не повторять.

**Что построено за 2026-08-17/18 — всё в `.coord/protocols/`:**
- `switch-protocol.md` — передача мяча: инит постоянен и без состояния, хендоф это груз, гейт готовности
  МАРКИРУЕТ а не блокирует, манифест переключения — первое, что читает принимающая сторона.
- `init-ROLE-TEMPLATE.md` + `init-<роль>.md` на все роли. Правки вносить в ШАБЛОН, потом порождать.
- `entrance-test-COMMON.md` + `entrance-key-COMMON.md` — сквозная дисциплина; `entrance-{test,key}-<роль>.md`
  — тонкая роль-специфичная часть. Куратору тест НЕ заготавливается: его пишет уходящий предшественник.
- Заведены `role-security`, `role-techwriter`, `role-metrics` — их не существовало, у трёх ролей не было
  постоянного слоя вовсе.

**Нормы, принятые за эти двое суток (все в загрузчиках, наследуются всеми ролями):**
оператору по одному вопросу за раз, и **код-бокс это тоже обращение** — очередь одна и общая ·
аккаунты ведёт только куратор, роль про них не рассуждает · **среду не выводить из читаемых документов** ·
**пробуждение после паузы = инит**, критерий «проверял ли я это в текущем пробуждении» · singleton-проверка
роли · тест преемнику пишет куратор, роль пишет уроки в `§B` · **ПОСТАВКА ≠ ЗАКРЫТИЕ** (`DELIVERED` пишет
автор по object store, `CLOSED` — только оператор) · доставка идёт диском, git — сохранность, коммит на
каждую реплику это process creep.

**Открыто и ждёт:**
1. Ответ `gmail` на разделение труда (тесты пишу я, поднимает и принимает он) — запись `17:20Z`.
2. **17 непушенных коммитов на одном диске.** Барьер §37 проводит координатор; действующего координатора
   на рабочей стороне НЕТ — он на резерве. Это и есть блокер следующего этапа.
3. Продуктовый пункт — оператор ещё не назвал, вопрос висит.
4. Режим ЧП формально снят, но сохраняется намеренно как дисциплина (решение оператора). **Не прибираться**
   — вопрос в `.coord/backlog.md`.
5. `§C VERIFY` восьми ролей написаны против рабочего дерева, а не object store. Чинит владелец роли;
   вопрос заложен в их вступительные тесты.
6. Дайджест журнала (`journal-digest`) — решено «вперёд, в момент, тем кто узнал», файла ещё нет.

**Чего НЕ делать:** не лезть в барьер и пуш · не править чужие `§C` и роль-скиллы · не трогать ЧП ·
не начинать новый протокол при неподвижном продукте · не писать в `.claude` через инструмент доставки
(запрещено; только `device_bash`).

## Next
`коорд: входящие` — over BOTH colonies on the originating account; over RTM ONLY on the post-migration
account. Object-store-pin every claim. No new work unprompted.
