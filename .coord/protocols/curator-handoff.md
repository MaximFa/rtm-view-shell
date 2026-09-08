# CURATOR HANDOFF — LIVE resume (RTM-Bybet Consult / curator-0611)

## ▶ BOOT BLOCK — как поднять читателя этого файла (норма 2026-08-29, Н-1)
- start prompt (оператор запускает ЭТО): `.coord/protocols/init-curator.md`
- этот хендоф: `.coord/protocols/curator-handoff.md`
- шаблон, из которого порождены иниты ролей: `.coord/protocols/init-ROLE-TEMPLATE.md`
- канал с другим аккаунтом: `.coord/protocols/curator-crossaccount.md`
- входящие: `.coord/inbox/curator.md` · шина: `.coord/` · клон: `D:\Claude\Projects\RTM View Shell`
- **Тот же инит-файл — промпт ВОЗОБНОВЛЕНИЯ после внезапной автокомпакции**, не только холодного старта.

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


---

# ОБНОВЛЕНИЕ 2026-09-08 — пишет `curator-0611` перед плановой заменой. НИЖЕ ГЛАВНОЕ; всё выше старше
# и местами УСТАРЕЛО (см. «что отменено»). Хендоф ОБНОВЛЯЕТСЯ, а не переписывается — изъятий не делал.

## 0. ЧТО ОТМЕНЕНО ИЗ НАПИСАННОГО ВЫШЕ
- «Этап: поднять на резерве (`gmail`) полноценную команду и заморозить» — **больше не текущий этап.**
  Работа полностью вернулась на `profit`. `gmail` не отвечал с 2026-08-18; двусторонний канал
  `curator-crossaccount.md` не двигался с той же даты. Не считай молчание согласием: там просто никого нет.
- Пины и даты из блока 2026-08-29 устарели все до одного. Ниже — свежие.

## 1. ПИНЫ ЭТОГО ПРОБУЖДЕНИЯ (пере-сними сам, чужие пины не наследуются)
`v3 = c06b525` · `origin/v3 = 79e3905` · **непушенных 20** · `NO push` в силе.
`.coord/protocols/curator-handoff.md` — этот файл. `.claude/skills/role-curator/role-curator.md` = `9034be6c`.
**Непрочитанное в моём инбоксе (норма Н-10):** `grep -c '2026-09-0[78]' .coord/inbox/curator.md` = **10**,
разобрано всё, непрочитанного нет.

## 2. КТО ЖИВ И ЧЕЙ ХОД
Живых сессий на момент записи: `devops-0908c` (+ `coordinator-0908`, поднят и аттестован сегодня).
`backend` и `shell` ЗАЖАТЫ и ЖДУТ ПОДЪЁМА — их хендофы написаны ими самими и лежат в дереве:
`backend-handoff.md` = `bacdc594`, `shell-handoff.md` = `84a5cac0`. **Поднять их — первое, что от тебя нужно.**
Поке-шаблон бери из моей переписки с оператором: инит + блоб хендофа + «тест не сдаёшь, роль аттестована»
+ отчёт §5 на диск в `.coord/inbox/curator.md` + число непрочитанного в своём инбоксе.

Ход у координатора: §4 для backend (правка сирот) и shell (предикат view/edit), вопрос оператору по `§8.6`.

## 3. МОЙ СОБСТВЕННЫЙ ДОЛГ, КОТОРЫЙ ПЕРЕХОДИТ К ТЕБЕ
1. **Вступительного теста для линии КООРДИНАТОРА нет.** `coordinator-0908` поднят без него, записал
   ЯВКУ вместо ответов — правильно. Тест обязан написать куратор. Это мой невыполненный долг, забирай.
2. **Дыра 1913 нулевых байт в `role-coordinator.md`** с 2026-07-03 — на месте, теперь закоммичена.
   Содержимое утрачено безвозвратно (текстом не существовало). Реконструкция шести уроков по журналу
   за 02.07 предложена координатором, **решение оператора не получено**. Надгробие в `§B` не поставлено.
3. **BOM в трёх скиллах** (`coordinator`, `dba`, `incident`) — шапка не читается как frontmatter.
   `shell` починил свой сам и доказал правку характером (`store[3:] == disk`). Чинит владелец, не ты.
4. **`OPS-BACKUP-234`** в `.coord/backlog.md` — на боевом 234 НЕТ задания резервного копирования.
   Статус WAITING-ON-EVENT, условие пробуждения: закрытие converge. Не дай пункту замолчать.
5. **Пуш `f6d5c58 -> 79e3905`** (2026-08-31, 74 файла) при объявленном `NO push` — координатор поднимал
   трижды, я так и не спросил оператора. Вердикта нет и не будет без его слова: пуш делает он своей рукой,
   а режим адресован ролям. Спроси прямо и закрой.

## 4. НЕГАТИВНОЕ ЗНАНИЕ — то, чего нет в git и что иначе будет куплено заново
- **`git status` через маунт ВРЁТ `M` при содержимом, равном HEAD.** 05.09 я на этом объявил оператору
  двенадцать несохранённых файлов; их было пять. Верный различитель — `hash-object` против `rev-parse`,
  и только он. Индексные команды через маунт не запускать вовсе: они оставляют `index.lock`, который
  мост не умеет снять, и репозиторий встаёт (случалось дважды).
- **Кириллица не переживает `git show | Select-String` в PowerShell.** Русский шаблон молча даёт 0 —
  ложно-красная проверка, которая выглядит как честно упавшая. **Предикаты, уходящие оператору,
  пишутся ТОЛЬКО латиницей.** Я потерял на этом два хода подряд 08.09.
- **Счёт строк не измеряет ни объём изменения, ни целость файла.** Дыра в 1913 байт не меняет счёт строк;
  23 КБ уроков легли «42 строками». Меряй блобы и байты.
- **`hash-object` нормализует `CR`:** совпадение sha при РАЗНЫХ размерах законно (так у `role-dba`, 86 CR).
  Сверять блобы, не размеры.
- **Файл с NUL становится для grep БИНАРНЫМ:** `grep -c` работает, `grep -n` печатает `binary file matches`
  и НИ ОДНОЙ строки. Счётные проверки зеленеют, показывающие — немеют.
- **Правило игнора НЕ действует на отслеживаемые файлы.** `git add .claude/...` печатает подсказку про
  `-f` и всё равно кладёт изменение в индекс. Проверено делом (`69fc306`). НО **новый** файл под
  `.claude/` без `-f` уйдёт молча — класс потери 03.07.
- **`git add -A .coord` — no-op:** `.coord/.gitignore:2` = `*`. Трекается только то, что явно разигнорено.
- **Ложно-красный дороже ложно-зелёного:** он останавливает работу и посылает чинить здоровое.
  Опознаётся негативной половиной (у `devops-0908b` негконтроль вернул `-1` — сломан был прибор).

## 5. НОРМЫ, ПРИНЯТЫЕ ЗА ЭТОТ ЦИКЛ (все в `role-skill-standard.md`)
BODY INTEGRITY (Н-6…Н-9) — байтовая проверка после записи в роль-скилл, сенсор целостности по ОБОИМ телам
(диск и стор), и **сверка блоба ПОСЛЕ коммита** — чтобы поймать собственную запись, сделанную секундой
позже (гонка `coordinator-0908`, 08.09).
**Н-10 — вход роли не готов, пока автор не назвал ЧИСЛОМ непрочитанное в её инбоксе.** Записана после того,
как я дважды на одном и том же файле собрал вход, не пришпилив инбокс роли. Первая редакция была прозой,
её же автор её и нарушил. **Отсюда общий вывод, который дороже самой нормы: норма без предъявляемого
предиката — это намерение, а не норма.**

## 6. КАК Я РАБОТАЮ С ОПЕРАТОРОМ (он просил и повторял)
Один вопрос за сообщение. Ран-бокс — отдельным сообщением, без вопросов и вводных вдогонку. Выводы и
находки адресуются КООРДИНАТОРУ на шину, оператору — бокс и одна строка о том, что отчёт подан.
Файлы писать прямо на диск через `device_bash` (Python + `os.fsync`), карточек в чат не слать.
Прогоны — в формате CC с BINDING в `.coord/cc/curator.md`. Объяснять по-человечески, без таблиц и
номеров пунктов: он прямо сказал, что после такого ответа не понимает ничего.
**Норма оператора 08.09: подписи ассистента в коммитах и PR запрещены всегда.**

## 7. ЧЕГО НЕ ДЕЛАТЬ
Не чистить ЧП-режим и открытые вопросы в `backlog.md` — оператор велел не прибирать.
Не выносить вердиктов по §4: это гейт координатора, не твой. Не подтверждать чужие благословения.
Не править чужие роль-скиллы и чужие сессионные файлы — только зажимать протухшие с явным штампом.
Не трогать `1496`/`1504` (улика), виджет 78, боевую `RTM.Twilio`, legacy `RTM`.
