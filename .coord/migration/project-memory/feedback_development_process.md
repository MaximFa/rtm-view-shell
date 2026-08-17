---
name: RTM View Shell — процессная дисциплина (по DevelopmentProcessExample)
description: Уровень ведения проекта, который пользователь ожидает в RTM View Shell — формальные ADR, sprint briefs, slash-команды, маркер-дисциплина, traceability, verification discipline для status docs
type: feedback
originSessionId: e7fc5936-9b58-407e-b6f6-f191c0570f6e
---

## ⚠ Verification discipline (top-of-file priority — lesson 2026-05-25)

**Перед написанием любого status doc, session-close summary, sprint report,
PROJECT_STATUS обновления или memory entry который утверждает что
deliverable существует:**

1. **Verify в том же действии записи** через `ls -la <path>`, `git log --oneline -- <path>`,
   или `Read <path>`. Tool success return (Write / Edit) — **НЕ доказательство
   доставки**. Cowork sandbox sync, partial writes, session boundaries могут
   возвращать success без реально сохранённого state.
2. **Status tables — by walking repo**, не по chat history.
3. **Лейблы explicit:** *Intended* / *Drafted* (tool success) / *Delivered (verified)* /
   *Committed (hash)*. Не conflate.
4. **Не уверен — ⚠ Unverified**, не ✅.
5. **Это правило overrides default "don't re-read after Edit"** token-saving
   guidance из system prompt — для status / handoff artefacts token economy неправильна.
6. **Memory держит patterns / decisions / preferences** — НЕ "X delivered" claims.
   Delivery state живёт в git, не в memory.

**Why:** 2026-05-25 sanity check показал 6 из 9 заявленных v1.3
deliverables (TS docx, 8 ADR файлов, CHANGELOG, stakeholder summary,
widget architecture, CLAUDE.md frontmatter bump) **никогда не существовали
в репозитории**, несмотря на session summaries с ✅. Tool success returns
were mistaken for persisted state. Stale claims пропагировались через memory
в новую сессию и заражали T2 brief.

**How to apply:**
- При любом обновлении PROJECT_STATUS — сначала filesystem audit, потом запись.
- При закрытии sprint — gap-analysis после verified file/commit listing.
- При сохранении в memory — никогда не записывать "X delivered" / "X complete"
  без `git log` reference и checked path.
- Если попадаешь в сессию где предыдущая сессия писала summary — **первым
  делом** verify его claims через `ls` + `git log --since="last session"`.

См. также: PROJECT_STATUS.md в корне проекта (sanity-checked таблица 2026-05-25).

---

## Ожидаемый уровень ведения проекта

Пользователь дал референс — документ `contact-center-director/DevelopmentProcessExample.docx`
(180 KB, диалог по проекту редизайна ACE Agent Desktop). Это эталон. Применять везде.

**Why:** Пользователь явно сказал «такой же уровень ведения проекта». Подтверждено выбором "Вплести ADR в работу над v1.3" + "Развернуть инфраструктуру сразу".

**How to apply:** При любой нетривиальной задаче — следовать структуре ниже, не упрощать.

---

## Артефакты, которые должны быть в репозитории

```
analysis/             — reverse-engineering, gap analysis, findings
  v1.2-vs-impl-gaps.md   с маркерами NEW-XX / CHG-XX / TGT-XX / CLR-XX
  hidden-requirements.md   H1..HN из неявных правил CLAUDE.md
  wireframes-inventory.md  screen → wireframe → routes → roles → status
decisions/            — ADR на каждое значимое решение
  _template.md           обязательный шаблон
  _index.md              реестр ADR
  ADR-001-*.md           формальная нумерация, никогда не переиспользовать ID
docs/sprints/         — брифы спринтов по шаблону
  _template.md
  _gap-analysis-template.md
docs/skills-roadmap.md   план активации скиллов «когда какой»
docs/traceability-matrix.md   Requirement ID | ADR | Test File | Implementation
.claude/commands/     — slash-команды как quality gates
  architecture-check.md
  check-hidden-requirements.md
  security-pre-merge.md
```

---

## Маркер-дисциплина (всегда уникальные ID)

| Маркер | Назначение | Пример |
|---|---|---|
| `[ARCH-NN]`, `[CODE-NN]`, `[PWD-NN]` | Требования CLAUDE.md (уже есть) | `[ARCH-01]` |
| `NEW-NN` | Новое требование (не было в v1.2) | gap audit |
| `CHG-NN` | Изменённое требование | gap audit |
| `TGT-NN` | Tightened (security/architecture) | gap audit |
| `CLR-NN` | Clarified (формулировка строже) | gap audit |
| `ADR-NNN` | Architecture Decision Record | трёхзначное, монотонное |
| `OQ-N` | Open Question внутри ADR | `OQ-1 ✅ закрыт` |
| `R1..RN` | Риски (например, миграции) | analysis |
| `H1..HN` | Hidden requirements | analysis |
| `DoD-N` | Definition of Done в спринте | бриф |
| `TBD-NN` | To-be-decided | ТЗ |

---

## Шаблон ADR (по образцу из примера)

```markdown
# ADR-NNN: <короткий заголовок решения>

**Статус:** Предложено | Утверждено | Заменён ADR-XXX | Отозван
**Дата:** YYYY-MM-DD
**Контекст:** <проблема, ограничения, история>
**Рассмотренные варианты:**
  - A. <вариант>  — pros / cons
  - B. <вариант>  — pros / cons
  - C. <вариант>  — pros / cons
**Решение:** <выбранный вариант>
**Обоснование:** <2-4 ключевых аргумента>
**Привязка к требованиям ТЗ:** [ARCH-XX], [PWD-XX], NEW-XX
**Привязка к целям:** Ц-1..Ц-N (если применимо)
**Open Questions:**
  - OQ-1: <вопрос> — статус
  - OQ-2: <вопрос> — статус
**Последствия:** <что меняет, что блокирует, миграция>
```

---

## Шаблон брифа спринта (по образцу)

```markdown
# Sprint NN: <название>

## Scope
**В скоупе:** ...
**Явно вне скоупа:** ...

## Архитектурные микро-выборы (gate перед стартом)
1. <вопрос 1> — варианты A/B, рекомендация
2. <вопрос 2> ...
**Согласовать до старта.**

## Definition of Done
- DoD-1: <проверяемый критерий>
- DoD-2: ...
- (7-11 пунктов)

## Известные ограничения
- ...

## Открытые вопросы
- OQ-1: ...
```

---

## Gap-анализ перед закрытием спринта (обязательный)

| DoD | Требовалось | Фактически | Статус |
|---|---|---|---|
| DoD-1 | ... | ... | ✅/❌/⚠ |

**Why:** В примере (Sprint 04a) Claude Code отчитал 160 тестов вместо 350 без gap-checка. Это «accept too easily» проблема. Дисциплина — обязательный сверочный шаг.

---

## Принципы работы

1. **Микро-выборы как gate перед стартом** — 3-7 архитектурных вопросов на согласование ДО реализации.
2. **Phase split для больших спринтов** — Phase A / Phase B с промежуточным коммитом и явным «стоп до подтверждения».
3. **Не реплицировать legacy 1-в-1** — баги из legacy НЕ копируются.
4. **Skills roadmap with triggers** — скиллы создаются just-in-time, не превентивно.
5. **Diagnostics first, fix later** — при падении теста: expected vs actual + гипотеза root cause ДО правки кода.
6. **Atomic commits** — отделять "проектный контекст" от "первый код" для чистоты git bisect.
7. **Memory-ноты для критических нетривиальных инвариантов** — то, что нельзя вывести из кода.

---

## Slash-команды как quality gates

Применять перед merge:
- `/architecture-check` — dependency rules CLAUDE.md §3 + ARCH-01..12 + ADR conformance
- `/check-hidden-requirements` — прогон по [CODE-XX], [BFP-XX], [DATA-XX], [PWD-XX]
- `/security-pre-merge` — checklist из CLAUDE.md §25

Вывод в форматированной таблице с колонкой Status (OK / N/A / ❌) и Summary + Action Items.

---

## Что НЕ упрощать

- Не объединять ADR в один файл.
- Не пропускать gap-анализ перед закрытием спринта.
- Не отчитываться о готовности без сверки с DoD.
- Не создавать ADR без секции «Альтернативы».
- Не использовать вольные ID — только формат NEW-NN / ADR-NNN / DoD-N.
- Не пропускать «архитектурные микро-выборы» — даже если кажется, что выбор очевиден.

---

## Sprint test patterns (закреплены в T1 2026-05-17)

При подготовке test-coverage спринтов (T1..T5 и далее) применять
**единый набор технических решений** — каждая микро-выбор'ка в новых
брифах либо наследует от T1, либо обосновывает явное отклонение в
brief'е.

| Аспект | Pattern (T1 baseline) | Где меняется |
|---|---|---|
| **Integration DB** | Testcontainers PostgreSQL 16 | Не меняется. EF In-Memory запрещён (ломает GQF). |
| **Identity stack** | Real `UserManager` / `SignInManager` для auth-flow; Moq для license-gate | Каждый sprint определяет где он находится по этой оси. |
| **Audit assertion** | Hybrid: Moq spy в `Tests.Unit`; real DB read в `Tests.Security` | Не меняется. |
| **Test naming** | `MethodName_Scenario_ExpectedBehaviour` + **обязательный** `[Trait("Req", "ARCH-04")]` | Не меняется. Traceability matrix auto-greppable через trait. |
| **Phase split** | Большой sprint (≥30 тестов) — Phase A + B с промежуточным коммитом и architect gate. Маленький (<25 тестов) — single phase. | Per-sprint решение. |
| **Shared fixtures** | `ICollectionFixture<PostgresFixture>` + transactional rollback per test | Не меняется. Reuse T1's `PostgresFixture`, `IdentityFixture`, `TenantContextFactory`, `RedisFixture`. |
| **`IConfigurationApiHook`** | Moq spy для тестов, проверяющих payload; real `NoOpConfigurationApiHook` для E2E lifecycle | T1 — Moq; T5 — hybrid. |
| **`IDateTimeProvider`** | Moq, time-warped per test | Любые тесты с временными окнами (lockout, refresh, expiry). |
| **Backend tables** | После B1 (#11) использовать `BackendEmulationDbContext`; до B1 — backend tables в `AppDbContext` | T3 / T5 Phase B блокированы пока #11 в main. |

**How to apply:** новые брифы (T6+, любые) копируют §2 структуру T1
и в первой строке каждого MC явно ссылаются "inherited from T1" или
"deviation, justification: ...".

---

## Hand-off format Claude Code (закреплён в T1)

Каждый sprint brief заканчивается **§7 (или §8) Hand-off to Claude
Code** с готовым copy-paste промптом. Промпт обязан включать:

1. Reference на бриф-файл (`Read: docs/sprints/TN-name.md`).
2. Подтверждение что §2 micro-choices подписаны.
3. Specific DoD items для исполнения в этой фазе.
4. Working agreement (4-5 пунктов):
   - `[Trait("Req", "...")]` на каждом тесте.
   - Diagnostics first, fix later (expected-vs-actual + root cause до правки кода).
   - Запрет на fallback при отсутствии Testcontainers (abort, не EF In-Memory).
   - Не трогать тесты вне scope этого спринта.
5. On-completion обязательства: gap-analysis, traceability update,
   commit message в брифе.

**Why:** претензия к claude-code в DevelopmentProcessExample —
"accept too easily". Working agreement выправляет это.

**How to apply:** ровно эта структура для всех будущих sprint
hand-off'ов.

---

## Sprint inventory (обновлено 2026-05-25, после D1 закрытия)

| Sprint | Title | Status |
|---|---|---|
| **T1** | Security & cross-tenant isolation | **✅ CLOSED** — 79 tests, 4 SF, 2 PD |
| **T2** | Licensing enforcement | **✅ CLOSED** — 20 tests, SF-006/007 |
| **T3** | Multi-tenancy integration | **✅ CLOSED** — 36 tests, commit `7b85269` |
| **T4** | PG authorization semantics | **✅ CLOSED** — 46 tests, SF-005 Critical |
| **T5** | Widget framework | **✅ CLOSED** — 28 tests, commit `fbf89fd`, 313 total |
| **D1** | Documentation catch-up | **✅ CLOSED** — commit `b16d2e5`, 1378 insertions, 13 files |

**Все T1..T5 + D1 + #13 закрыты. Следующее:** T6 (TBD) — все backlogs закрыты.

**code follow-on задачи в backlog:**

| ID | Task | Status |
|---|---|---|
| **B1** (#11) | BackendEmulationDbContext | **✅ CLOSED** commit `80974b0` |
| **#12** | Widget-creator MetricType drift | **✅ CLOSED** commit `5eab846` |
| **#13** | DatabaseInitializer → IDatabaseInitializer | **✅ CLOSED** commit `80645f1` (2026-05-25) |
| **#14** | WebFixture rate-limit clear | **✅ CLOSED** |
| **D1** | Docs catch-up: TS v1.3 EN docx, CHANGELOG, ADR-001..008 files, CLAUDE.md v1.3 bump | **✅ CLOSED** commit `b16d2e5` (2026-05-25) |

**How to apply:** при возвращении к проекту — start with PROJECT_STATUS.md,
не дублировать уже зафиксированное.

---

## PROJECT_STATUS sanity check (lesson от 2026-05-25)

**Правило:** Перед началом нового полноценного sprint'а **обязательно**
делать filesystem sanity-check всех "✅" track'ов в PROJECT_STATUS
против реального состояния файлов и `git log --all -- <path>`.

**Why:** 2026-05-25 при разведке для T2 brief обнаружено: PROJECT_STATUS
заявлял "v1.3 ✅ DELIVERED" с 9 ✅ track'ов, но 6 из 9 **никогда не
существовали в git history** (TS v1.3 EN docx, CHANGELOG, 8 ADR-NNN
файлов, stakeholder summary, widget architecture, CLAUDE.md v1.3 bump).
Ложная картина propagated через memory + я унаследовал её и шёл с ней.
Это backlog D1 теперь.

**How to apply:**
- При старте нового sprint'а — `git log --all -- <file>` на каждый
  заявленный artefact в PROJECT_STATUS "Current state" таблице.
- Если есть несоответствие — корректировать PROJECT_STATUS **до**
  написания brief'а. Brief, ссылающийся на несуществующие ADR'ы /
  документы — невалиден по основанию.
- Это **не PD** (нет violation of working agreement) — это data
  hygiene. Просто фиксировать факт, не накапливать через memory.

---

## Session-resume working-tree integrity check (lesson от 2026-05-25, PD-005)

**Правило:** при возобновлении работы после потери / прерывания
Cowork сессии — **перед любым новым действием** проверять не только
PROJECT_STATUS, но и **integrity dirty working tree**.

**Why:** 2026-05-25 при resume сессии после потери файлов: `git status`
показал 13 dirty файлов. **8 из 13** оказались truncated (обрезаны
на середине statement / комментария, незакрытые `}`). Это включало
production code (`AuthorizationBehavior.cs`,
`InfrastructureServiceExtensions.cs`, `UserManagementService.cs`),
test infra (`PostgresFixture.cs`, `WebFixture.cs`), и docs (CLAUDE.md
и др.). Проект не сбилдился бы в таком состоянии. Если бы я начал
писать новый T2 brief / hand-off без проверки, мог бы закоммитить
broken state.

**Сигнатура truncation:**
- Файл заканчивается на середине statement / комментария.
- `tail -3 <file>` показывает unclosed braces, half-written comment,
  dangling identifier.
- `wc -c <file>` показывает размер ~256-5000 байт меньше HEAD'овой
  версии.

**Recovery procedure:**
- Для truncated файлов **НЕ работает** `git checkout HEAD -- <file>`
  в Cowork shell — fails с `unable to unlink: Operation not
  permitted` (mount запрещает unlink/rename).
- **Работает** `git show HEAD:<file> > <file>` — truncate-in-place
  без unlink. Восстанавливает к HEAD состоянию.

**How to apply:**
1. `git status` сразу при resume.
2. Для каждого `M` файла: `tail -3 <path>` — проверить closing.
3. Если truncated — `git show HEAD:<path> > <path>`.
4. Verify: `tail -3 <path>` снова — должно заканчиваться чисто.
5. Untracked файлы (`??`) проверять отдельно `tail`-ом — они могут
   быть intact (single-write) или тоже truncated.
6. **Только потом** браться за новую работу.

**Pattern:** этот check дополняет PROJECT_STATUS sanity-check (long-term
documentation drift) — они **разные** failures. PD-005 это про
working-tree corruption from interruption; PROJECT_STATUS sanity-check
про долгосрочный data drift. Оба обязательны при resume.

---

## Process deviations pattern (PD-NNN) — введён в T1 Phase C

Параллельно паттерну SF-NNN для security findings, в проекте теперь
живёт `analysis/process-deviations.md` с PD-NNN записями. PD — это
**нарушения working agreement** в hand-off prompt'е (а не баги в коде).

**Когда писать PD-NNN:**
- Claude Code (или другой executor) сделал что-то, что hand-off
  agreement явно запрещал, **и** изменение либо принято, либо
  откатывается. Любая ситуация "agreement broken + outcome" — PD.
- Architect постфактум одобрил исключение, но хочет, чтобы паттерн
  виден был в будущих hand-off prompt'ах.

**Структура PD-NNN записи** (см. PD-001 / PD-002 как baseline):
- Detection context (sprint, commit)
- Severity (обычно Low для accept-friendly, Medium если revert,
  High если повторяющийся pattern)
- Agreement clause violated (точная цитата из hand-off prompt'а)
- What happened (что executor сделал реально)
- Disposition (accept / revert / refactor + backlog item)
- Lesson (как должен измениться будущий hand-off prompt)

**Когда возникает PD:**
- При просмотре результата Claude Code сверять с working agreement
  каждого hand-off prompt'а — не только DoD.
- Если есть deviation: документировать сразу, до закрытия спринта.

**Как фиксить:**
- PD обычно НЕ требует code revert — типично accept с фиксацией.
- PD-NNN с Disposition "Refactor" должен породить backlog item с
  ссылкой на PD (как #13 порожден из PD-002).
- Hand-off prompts будущих sprint'ов должны учитывать lesson из
  каждого PD — обновление в начале нового sprint при подготовке §7.

**Why:** Без формальной фиксации PD каждый sprint будет повторять
те же deviation'ы. Уже выявлено: working-agreement clause "no
production code changes" слишком общая — в T1 Phase C она ловит
и идиоматический `partial class Program {}` (false positive,
нужно whitelist), и `virtual` для тестируемости (true positive,
нужно сохранить gate). Без PD-NNN эта nuance теряется.

**How to apply:**
- При каждом sprint close-out проверять, нужно ли PD-NNN.
- Перед запуском следующего sprint hand-off promprt обновлять
  working-agreement section с учётом lesson'ов из PD-NNN.

---

## Cowork mount file-write reliability (lesson от 2026-05-25, PD-005 incidents #2/#3)

### Edit tool ненадёжен на Cowork mount'е для многошаговых правок

**Правило:** никогда не делать несколько `Edit` вызовов подряд на один и тот же файл
в проектной папке (`C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\`).
Вместо этого — один атомарный Python-скрипт: read → modify all changes → write.

**Why:** PD-005 incident #3 (2026-05-25): Edit tool вернул success, но `tail -3` показал
файл truncated на середине добавленного текста. `wc -c` подтвердил: размер не изменился
относительно до-edit состояния. Tool acknowledgement и filesystem persistence
**decoupled** на этом mount'е. Каждый Edit-вызов — отдельная операция write-to-mount
с ненулевой вероятностью truncation.

**How to apply:**
- Для любого файла в проекте с ≥2 правками за раз — Python `open(path).read()` →
  все `str.replace()` / вставки → `open(path, 'w').write(result)`.
- **После каждого `python3 /tmp/write_*.py` — NO EXCEPTIONS — сразу же:**
  ```bash
  tail -3 <path>   # должен заканчиваться корректной закрывающей строкой
  wc -l <path>     # сравнить с ожидаемым числом строк
  ```
  Рекомендуемый шаблон — объединить write + verify в одном bash-блоке:
  ```bash
  python3 /tmp/write_x.py && \
  tail -3 <path> && wc -l <path>
  ```
- Edit tool допустим для single-точечных мелких правок (1 строка), но всё равно
  верифицировать через `tail -3` после.
- **Это правило overrides token-saving "don't re-read after Edit"** guidance.
- **Не переходить к git staging или следующим правкам пока `tail -3` не покажет
  правильную закрывающую строку.** Truncated файл — restore из HEAD, retry Python.

**Pattern:** всегда применять совместно с PD-005 session-resume integrity check.

---

### Git stale `index.lock` на Cowork mount — workaround через `GIT_INDEX_FILE`

**Правило:** если `git add` / `git commit` падают с
`fatal: Unable to create '.git/index.lock': File exists`, и `rm` / `os.unlink` /
`git checkout` возвращают `Operation not permitted` — использовать обходной путь
через temp-копию index в `/tmp`.

```bash
cp .git/index /tmp/cc-git-index
GIT_INDEX_FILE=/tmp/cc-git-index git add <files>
GIT_INDEX_FILE=/tmp/cc-git-index git commit -m "..."
cp /tmp/cc-git-index .git/index
```

**Why:** Cowork mount блокирует `unlink` и `rename` системные вызовы — это мешает
`git` удалять собственные temp-файлы и lock-файлы. Однако `cp` из /tmp обратно в
`.git/index` работает (overwrite существующего файла без unlink). Валидировано
2026-05-25 — коммит `8e1f12a` создан именно этим способом. Warnings
`unable to unlink '.git/objects/XX/tmp_obj_*'` в output — benign (git убирает
свои tmp objects после write, fails harmlessly).

**Сигнатура проблемы:**
- `git commit` → `fatal: Unable to create '.git/index.lock': File exists`
- `rm -f .git/index.lock` → `cannot remove: Operation not permitted`
- `python3 -c "os.unlink(...)"` → `PermissionError: [Errno 1] Operation not permitted`

**How to apply:**
- При любом `index.lock` блоке — сразу этот workaround, не тратить время на
  другие подходы (`git gc`, `git fsck`, etc.).
- После успешного commit через workaround — `cp /tmp/cc-git-index .git/index`
  обязателен, иначе `.git/index` останется на pre-add состоянии.
- Проверить результат: `git log --oneline -1` + `git status --short`.

---

## Test-coverage sprint ROI — validated by T1 Phase A (2026-05-25)

T1 Phase A закрылся с **3 production security bugs найденными и пофикшенными**:

- **SF-001 (Critical):** `ApplicationUser` missing GQF — cross-tenant data leak
- **SF-002 (High):** TenantMismatch detection broken — wrong audit subtype
- **SF-003 (High):** Deleted tenant didn't block login — GDPR violation risk

См. полный отчёт: `analysis/security-findings.md`.

**Why:** Это **прямое экономическое обоснование** test-coverage программы
для разговоров со стейкхолдерами / клиентом. 20 часов разработки тестов
поймали 3 реальные security gap'а до production. Если возникнет
вопрос "зачем тесты, и так работает" — ссылка на этот результат
закрывает разговор.

**How to apply:**
- При планировании T2..T5 ожидать находки similar character — каждый
  sprint должен иметь графу "production bugs found" в gap analysis.
- При написании stakeholder summaries / status reports — упоминать
  SF-XXX счётчик как concrete value metric.
- При architect review каждого sprint'а — особое внимание production
  code fixes (1-3 баги per sprint = healthy signal; 0 = подозрительно
  good or shallow tests; 10+ = significant tech debt в области).

**Pattern для документации каждого нового SF-XXX:**
- Detection context (какой тест и какой commit)
- Severity (Critical / High / Medium / Low)
- Requirement violated (ID из TS)
- Root cause
- Impact had this gone to production
- Resolution + commit hash
- Lesson / pattern (как избежать в будущем — часто Tests.Architecture
  rule)

---

## Pre/post-commit file integrity (lesson от 2026-05-26, #14 incident)

**Правило:** `tail -3` + `wc -l` обязательны ДО staging И ПОСЛЕ commit — без исключений.
Зафиксировано в CLAUDE.md §0.5 и §0.6 (commit `0953828`, 2026-05-26).

**Why:** В ходе #14 (separate NGC_*/RTS_* tables):
1. Plumbing-коммиты (`git commit-tree` + `GIT_INDEX_FILE=/tmp/...`) строили tree из
   временного индекса, в который не попали все изменённые файлы.
2. В итоге HEAD не совпадал с working tree — 21 M-файл.
3. Claude Code при session-resume обнаружил "corrupted files" и откатился к T6 (`git reset --hard 3443524`).
4. Потеряно ~30 минут работы + пришлось переделывать #14 с нуля.

**Root causes:**
- Plumbing-коммиты не включали все staged файлы (неполный temp index).
- Отсутствие §0.6 post-commit check (`git status --short` must be empty).
- `cp "$IDX" .git/index` в конце plumbing-сессии часто пропускалось.

**Критическое правило для plumbing-коммитов:**
После каждого `git commit-tree` + `python3 ... update ref`:
```bash
# Обязательно:
GIT_INDEX_FILE="$IDX" git status --short   # должно быть пусто
GIT_INDEX_FILE="$IDX" git diff HEAD -- <key_files>  # должно быть пусто
python3 -c "import shutil; shutil.copy('$IDX', '.git/index')"  # sync index
```

**How to apply:**
- Всегда проверять `git status --short` (без флага) ПОСЛЕ каждого коммита — 0 строк.
- Если `git status` показывает M-файлы после commit — commit неполный. Не продолжать.
- Для plumbing-коммитов: в temp index добавлять ВСЕ файлы из `git status --short` перед `write-tree`.
- После plumbing-коммита: `cp "$IDX" .git/index` — обязательно, не пропускать.
