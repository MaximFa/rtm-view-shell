# CC task — PR234-FILTER-L10N-01: localise the filter popup in both grid widgets

**Author:** shell-0919b · 2026-09-19 · **Branch:** `v3` (= `39463c6`) · Code/comments EN.
**Authority:** coordinator-0919b 19.09 22:3x (keys landed as `e592f8b`; markup unblocked).

## INIT / служебные части (§0.6a, §0.6b, §0.6, §0.5 — в силе; амендмент 19.09 их не трогал)
`cd "D:\Claude\Projects\RTM View Shell"` · **§0.6a** проверка целостности до первой правки:
`git status --short`, по каждому `M`-файлу сверить число строк с `git show HEAD:"$f"`, усечённый —
восстановить из HEAD и **не продолжать**, пока расхождение не снято. Инструмент `Edit` ЗАПРЕЩЁН,
после записи `fsync`. **§0.6b** биндинг: преамбула в `.coord/cc/shell.md` ДО первой правки,
постамбула `RESULT` после (обе ниже в этом файле). **`commit.lock`** обязателен (§42.4, раздел
«Коммит»). **§0.6** пост-коммитная сверка: рабочее дерево == дереву коммита. **§0.5/PD-007**
последним действием пере-синхронизировать закоммиченные файлы: `git show HEAD:"$f" > "$f"` по
каждому, затем `sync`. `pre-commit-check` — только при записи через монтирование. `journal` не
ведём (амендмент 19.09), авторство роли и сессии — строкой в сообщении коммита. `NO push`.

## БИНДИНГ — преамбула (ОТКРЫТЬ в `.coord/cc/shell.md` ДО первой правки, Python + os.fsync, не затирая)
```
## 2026-09-19 | binding: shell <-> CC | directive: tools/cc_prompt_shell_filter_l10n.md | status: open
Автор `shell-0919b`. Предмет `PR234-FILTER-L10N-01`. Основание — coordinator-0919b 19.09 22:3x.
### ЗАМЕР ДО
    v3 = 39463c6
    AgentGridWidget.razor  a10af743…  L[ = 21 · английских литералов попапа 17
    QueueGridWidget.razor  d1528c90…  L[ = 20 · английских литералов попапа 27 (ДВА попапа: колоночный и _queueName)
    ключи в SharedResources.en-US.resx: все 16 присутствуют по одному вхождению
    Widgets_Filter_NSelected в трёх .resx: 1 / 1 / 1  [измерено shell-0919b 2026-09-19T22:1xZ] — входной гейт СНЯТ
### СТАТУС: §4 — <вписать вердикт>. Прогон запущен оператором.
```

## Входной пин — СТОП при расхождении
```
git hash-object src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor -> a10af743c77fab8dbb3c562283295dcbd4cfbf25
git hash-object src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor -> d1528c9042449e5cab244877f1c21a4196f1860e
```

## Задача
Заменить английские литералы в попапе фильтра на `@L["<ключ>"]`. **Ключи уже есть в трёх `.resx`** —
новые НЕ заводить; литерал, для которого ключа нет, НЕ трогать (см. раздел «Не в этой задаче»).


## ИГЛА, которой получено число 44 — печатается рядом с числом (условие §4 coordinator-0919b)
Число без иглы — мнение, а не измерение: три разные иглы по одному телу дают 37, 40 и 44, и все три
верны каждая для своей. Рабочая игла — эта, и приёмка формулируется как **«эта игла -> 0»**, а не
«литералов ноль»:
```bash
# по каждому файлу, счёт ВХОЖДЕНИЙ (не строк), шестнадцать игл:
for lit in '>Value<' 'title="Apply"' 'title="Clear"' 'title="Close"' \
           '>Less than<' '>Less or equal<' '>Greater than<' '>Greater or equal<' \
           '>Equal<' '>Contains<' '>Starts with<' '>Ends with<' '>List<' \
           'Select values' 'Filter value...' 'e.g. 30:00'; do
  printf '%s  %s\n' "$(grep -o -F "$lit" "$F" | wc -l)" "$lit"
done
# сумма по Agent = 17, по Queue = 27, ВСЕГО 44   [измерено автором 2026-09-19 по v3:7820788; перенос попапа 0809026 литералов не трогал, пере-проверено по 39463c6]
# семнадцатая игла, добавлена этим §4:  'selected"'  -> Agent 1 · Queue 1  (литерал `{n} selected`)
# ИТОГО замен: Agent 18 · Queue 28 · ВСЕГО 46
```
**Положительный контроль обязателен рядом с нулём:** `grep -c 'L\['` обязан ВЫРАСТИ ровно на число
замен — он отличает замену от удаления. Ноль без него читается и как «локализовано», и как «вырезано».

## Таблица замен — ключ берётся ТОЛЬКО отсюда
| литерал в коде | ключ | Agent | Queue |
|---|---|---|---|
| `>Value<` (`<span class="small opacity-75">`) | `Common_Value` | 1 | 2 |
| `title="Apply"` | `Common_Apply` | 1 | 2 |
| `title="Clear"` | `Common_Clear` | 1 | 2 |
| `title="Close"` | `Common_Close` | 1 | 2 |
| `<option value="less">Less than</option>` | `Widgets_MatchType_LessThan` | 1 | 1 |
| `<option value="lessOrEqual">Less or equal</option>` | `Widgets_MatchType_LessOrEqual` | 1 | 1 |
| `<option value="greater">Greater than</option>` | `Widgets_MatchType_GreaterThan` | 1 | 1 |
| `<option value="greaterOrEqual">Greater or equal</option>` | `Widgets_MatchType_GreaterOrEqual` | 1 | 1 |
| `<option value="equal">Equal</option>` | `Widgets_MatchType_Equal` | **2** | **3** |
| `<option value="contains">Contains</option>` | `Widgets_MatchType_Contains` | 1 | 2 |
| `<option value="startsWith">Starts with</option>` | `Widgets_MatchType_StartsWith` | 1 | 2 |
| `<option value="endsWith">Ends with</option>` | `Widgets_MatchType_EndsWith` | 1 | 2 |
| `<div class="small mb-2 opacity-75">List</div>` | `Widgets_Filter_List` | 1 | 2 |
| `"Select values..."` (в `GetListButtonLabel`) | `Widgets_Filter_SelectValues` | 1 | 1 |
| `"Filter value..."` (placeholder) | `Widgets_Filter_ValuePlaceholder` | 1 | 2 |
| `"e.g. 30:00"` (placeholder) | `Widgets_Filter_TimePlaceholder` | 1 | 1 |
| `$"{n} selected"` (в `GetListButtonLabel`) | `Widgets_Filter_NSelected` | 1 | 1 |
| **ИТОГО** | | **18** | **27+1 = 28** |

**`Equal` встречается ДВАЖДЫ в одном попапе** — в числовой и в текстовой ветке `<select>`. Заменить обе.
**В Queue попап ДВА**: колоночный и `_queueName` (второй ТЕКСТОВЫЙ — без числовых операторов, без
`e.g. 30:00` и без `Select values...`). Наборы у них РАЗНЫЕ, не копировать вслепую.

## Одно место требует не только подстановки
`GetListButtonLabel(ColumnFilter filter)` объявлен **`static`** в обоих виджетах, а `L` — инжектируемый
сервис. Убрать `static` (сигнатура остаётся прежней) и внутри вернуть `L["Widgets_Filter_SelectValues"]`.
Вызовов у метода по одному на файл, поведение не меняется.

## `{n} selected` — ТЕПЕРЬ ЛОКАЛИЗУЕТСЯ. Ключ новый, термин координатора
В `GetListButtonLabel` третий возврат — `$"{filter.SelectedValues.Count} selected"`. Ключ заведён
решением coordinator-0919b:
```
Widgets_Filter_NSelected    EN: {0} selected    HE: נבחרו: {0}    RU: выбрано: {0}
```
Замена: `return L["Widgets_Filter_NSelected", filter.SelectedValues.Count];`

⛔ **ВХОДНОЙ ГЕЙТ: ключ вписывает `backend`, не ты.** Перед правкой проверить наличие во ВСЕХ трёх
`.resx` и **ОСТАНОВИТЬСЯ, если хоть в одном его нет** — подстановка без ключа даст на экране имя ключа
(`PR234-L10N-KEYLEAK-01`):
```
grep -c 'name="Widgets_Filter_NSelected"' src/CcDashboard.Web/Resources/SharedResources.en-US.resx  -> 1
grep -c 'name="Widgets_Filter_NSelected"' src/CcDashboard.Web/Resources/SharedResources.he-IL.resx  -> 1
grep -c 'name="Widgets_Filter_NSelected"' src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx  -> 1
```
**Третий возврат метода — само значение фильтра — НЕ локализуется:** это данные, а не текст интерфейса.

## Прочие запреты
Не трогать `value="..."` у `<option>` (это данные, не текст), классы, стили, обработчики, разметку.
Никаких новых ключей в `.resx`. Никакого рефакторинга и переформатирования нетронутых строк.

## Выходные счётные предикаты — сняты по ТЕКУЩЕМУ корпусу
| команда | до | после |
|---|---|---|
| `grep -c '>Value<' …/Agent…` / `…/Queue…` | 1 / 2 | **0 / 0** |
| `grep -c 'title="Apply"'` | 1 / 2 | **0 / 0** |
| `grep -c 'title="Clear"'` | 1 / 2 | **0 / 0** |
| `grep -c 'title="Close"'` | 1 / 2 | **0 / 0** |
| `grep -c '>Less than<'` | 1 / 1 | **0 / 0** |
| `grep -c '>Less or equal<'` | 1 / 1 | **0 / 0** |
| `grep -c '>Greater than<'` | 1 / 1 | **0 / 0** |
| `grep -c '>Greater or equal<'` | 1 / 1 | **0 / 0** |
| `grep -c '>Equal<'` | 2 / 3 | **0 / 0** |
| `grep -c '>Contains<'` | 1 / 2 | **0 / 0** |
| `grep -c '>Starts with<'` | 1 / 2 | **0 / 0** |
| `grep -c '>Ends with<'` | 1 / 2 | **0 / 0** |
| `grep -c '>List<'` | 1 / 2 | **0 / 0** |
| `grep -c 'Select values'` | 1 / 1 | **0 / 0** |
| `grep -c 'Filter value\.\.\.'` | 1 / 2 | **0 / 0** |
| `grep -c 'e\.g\. 30:00'` | 1 / 1 | **0 / 0** |
| `grep -c 'L\['` | 21 / 20 | **39 / 48** (21+18, 20+28) — положительный контроль |
| `grep -c 'static string GetListButtonLabel'` | 1 / 1 | **0 / 0** (сторож: `static` снят) |
| `grep -c 'selected"'` | 1 / 1 | **0 / 0** (семнадцатая игла) |
Печатать фактическое рядом с ожидаемым. Расхождение — СТОП без коммита, **корпус под число не подгонять**.

## БИНДИНГ — постамбула (ДОПИСАТЬ после прогона, в том числе если он сорвался)
```
### RESULT (CC, <дата UTC>)
- коммит: <sha> | файлы: <перечислить>
- предикаты факт/ожидание: <все строки таблицы выше>
- ключ `Widgets_Filter_NSelected` в трёх .resx перед правкой: <1/1/1> (ожидание 1/1/1, иначе STOP)
- сборка: <errors> errors | юниты: <passed>/<failed> (об ЭТОЙ правке не свидетельствуют — Tests.Unit не ссылается на Web)
- отклонения от промпта: <нет | перечислить>
### СТАТУС: <delivered | stopped: причина>
```

## Коммит
Один коммит, узкими явными путями, без `-A`. **NO push**, на боевую не выкатывать.

**`commit.lock` (§42.4) — обязателен, им гейтим.** Порядок:
1. Взять замок атомарно: Python `open(".coord/locks/commit.lock", "x")`, внутрь — роль, sha сессии, `acquired` (UTC).
   Файл существует — ретрай 5 x 60 c; не взял — **коммит не делать**, напечатать владельца замка и СТОП.
2. `acquired` старше 15 минут — напечатать содержимое и ЖДАТЬ решения оператора. **Не удалять самому.**
3. Под замком: `git add` (только заявленные пути) -> `git commit` -> §0.6 пост-коммит-сверка.
4. Отпустить: удалить `commit.lock`, `sync`. Коммит сорвался — замок всё равно отпустить.
Замок покрывает и plumbing-путь (§0.4): прямая запись в `refs/heads/v3` git-блокировок не имеет,
две записи молча уничтожают один коммит. Обойти замок нельзя ни при каком объёме правки.
