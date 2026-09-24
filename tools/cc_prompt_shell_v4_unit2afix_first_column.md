# CC task — V4-UNIT2-A-FIX: fixed layout without column widths clips the first column

**Author:** shell-0919b · 2026-09-24 · **Branch:** `v4` (= `6141aa1`) · **Worktree:** `D:\Claude\Projects\RTM-design` · Code/comments EN.
**Authority:** правка своей же единицы до верного состояния [coordinator-0919b 21:05Z].
Область задаётся **предметом, а не файлом**: тот же дефект во втором экземпляре — часть той же
работы, поэтому правятся **оба** виджета, `AgentGrid` и принятый `QueueGrid`.

## INIT / служебные части (§0.6a, §0.6b, §0.6, §0.5 — в силе)
`cd "D:\Claude\Projects\RTM-design"` · `v3` не трогать ничем. **§0.6a** целостность до первой правки.
`Edit` ЗАПРЕЩЁН, после записи `fsync`. **§0.6b** биндинг. **`commit.lock`** обязателен (§42.4).
**§0.6** пост-коммитная сверка блоба с диском. **§0.5/PD-007** ре-синк последним действием, `sync`.
Размер в `RESULT` — «до ре-синка», сверка только по блобу. Коммит узкими явными путями, без `-A`.
Строк `Co-Authored-By` и `Claude-Session` в сообщении коммита быть НЕ должно. `NO push`.

## Дефект — найден глазами, ни один числовой предикат его не видит
Мы добавили в оба виджета `table-layout: fixed`, но **не задали ширины колонок**. При фиксированной
раскладке браузер делит ширину между колонками поровну, поэтому в `AgentGrid` (15 колонок) первая
колонка получает ту же долю, что колонка под число «12», — и имена агентов обрезаются
многоточием: `Dana K…`, `Marek R…`, `Tomer V…`. Справа при этом пустого места достаточно.

Это ровно второй пункт `references/pitfalls.md` эталона: **`table-layout:fixed` работает только
вместе с явными ширинами**; «fixed плюс узкие колонки — содержимое переполняется, заголовки
обрезаются». Эталон в `## Agent grid` требует `<colgroup>`, чьи ширины дают в сумме 100, и отводит
первой колонке ~10.5%. Мы взяли половину рецепта.

⛔ **В `QueueGrid` дефект тот же, хотя на макете не проявился:** там 7 колонок, имена очередей
короткие и пока влезают. Колонки настраиваются пользователем, и на длинном имени или широком
наборе колонок обрежет так же. Чиним оба — иначе через неделю починим «новый» дефект.

## Почему не `<colgroup>` и не откат на `auto`
- **`<colgroup>` не пишем:** колонки в обоих виджетах динамические (`_columnDefs`, 12 обращений в
  `AgentGrid`), их состав задаёт пользователь. Генерировать `colgroup` — это правка разметки под
  данные, а **колонки, их состав и порядок — данные, а не вид** [coordinator-0919b 21:55Z].
- **Откат на `auto` не делаем:** это первая половина того же пункта `pitfalls.md` — при автоматической
  раскладке избыток ширины сваливается в одну колонку, и таблица выглядит обрывающейся на трети
  панели. Меняли бы одно уродство на другое.
Остаётся то, что относится к виду и ничего не знает о составе колонок: **доля первой колонки**.

## Правки — ровно два файла, по одному правилу в каждый
```
src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor.css -> 62c5a5a5f658349febe1f5014a48b2e917ae7a00
src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css -> 7aef35a4d9bb56c168311e859ed215812c884afa
```
СТОП при расхождении пина.

В каждый файл добавить одно правило рядом с тем, где стоит `table-layout: fixed`:
```
.agent-grid-widget.wb-skin .agent-grid-table th:first-child,
.agent-grid-widget.wb-skin .agent-grid-table td:first-child { width: 14%; }
```
```
.queue-grid-widget.wb-skin .queue-grid-table th:first-child,
.queue-grid-widget.wb-skin .queue-grid-table td:first-child { width: 19%; }
```
14% для `AgentGrid` — имя с аватаром при 15 колонках; 19% для `QueueGrid` — доля `q1` эталона.
Селектор должен совпадать с тем, которым в этих файлах уже адресуется таблица; если имя класса
таблицы в разметке иное — взять фактическое из `.razor` и написать в `RESULT`, какое.

⛔ Ширины остальным колонкам **не задавать**: их число переменное, и всякая фиксация превратится
в ложь при другой настройке. Остаток браузер делит поровну — это и нужно.
⛔ `table-layout: fixed` **не убирать** ни в одном файле.

## Чего делать НЕЛЬЗЯ
- Трогать разметку `.razor` обоих виджетов — правка только в двух `.razor.css`.
- Трогать `_columnDefs`, состав и порядок колонок, `colgroup` не добавлять.
- Трогать `tokens.css`, `wallboard-skin.css`, `App.razor`, `.resx`, другие виджеты, `--thr-*`,
  `badge-*`, `avatar-*`, `ConnectionState`, `aria-live`.
- Движок эталона не переносить: `scripts/engine.js` и генерация `Math.random` — для демонстраций;
  виджет с выдуманными числами это не редизайн, а красивая ложь на стене у заказчика.
- Показалось, что «надо бы заодно» — не делать, назвать в `NOTED`.

## ПРЕДИКАТЫ — единица и область названы у каждого
| предикат | область | единица | ДО | ПОСЛЕ |
|---|---|---|---|---|
| `first-child` | `AgentGridWidget.razor.css` | вхождения | 0 | **2** |
| `first-child` | `QueueGridWidget.razor.css` | вхождения | 0 | **2** |
| `table-layout` | каждый из двух | вхождения | 1 | **1** (не убирать) |
| `width` | `AgentGridWidget.razor.css` | вхождения | 3 | **4** |
| `width` | `QueueGridWidget.razor.css` | вхождения | 1 | **2** |
| `colgroup` | оба `.razor` | вхождения | 0 | **0** |
| файлов изменено `.razor` | `git diff --name-only 6141aa1 HEAD -- '*.razor'` | файлы | — | **0** |
| `.resx` изменено | тот же diff | файлы | — | **0** |
| файлов кроме двух `.razor.css` | тот же diff | файлы | — | **0** |

⛔ **`width` — изменение, не абсолют.** В `AgentGrid` три вхождения уже есть (аватар и элементы
управления), в `QueueGrid` одно. Ожидание `3 -> 4` и `1 -> 2`. Кто прочтёт как «должно быть одно»,
снесёт размеры аватара и кнопок.
**Отрицательная половина обязательна:** нулевые предикаты — с положительным контролем в той же
области (`table-layout`, `badge-status`), иначе ноль ничего не значит.

## Сборка
`dotnet build src/CcDashboard.Web` — 0 ошибок; предупреждения с **названной областью** (проект или
решение).

## Коммит
```
git add "src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor.css" "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css"
git commit -m "style(v4): give the first column an explicit width under fixed layout ..."
```
Числа доказательства — в сообщение коммита: first-child 0->2 в каждом · width 3->4 и 1->2 ·
table-layout 1->1 · colgroup 0 · razor files changed 0 · resx 0 · build errors before/after.
Авторство роли — строкой.

## RESULT — ОБЛАСТЬ и ЕДИНИЦА у каждого числа
```
PINS      agent css 62c5a5a5 OK/FAIL · queue css 7aef35a4 OK/FAIL
FILES     <путь> <blob> <bytes до ре-синка> (disk==blob YES/NO) — по каждому
FIX       first-child 0->2 / 0->2 · width 3->4 / 1->2 · table-layout 1->1 / 1->1
SELECTOR  фактические имена классов таблиц, взятые из .razor
GUARDS    razor changed 0 · resx 0 · other files 0 · neg.control того же diff: >0
          pos.control: <что искал в той же области> = N
BUILD     область (проект|решение) · errors before/after · warnings before/after
COMMIT    <sha> · post-commit blob vs disk: MATCH/MISMATCH
RESYNC    §0.5 выполнен: YES/NO
NOTED     что просилось «заодно» и НЕ сделано — списком, или «нет»
```
Любое DIFFER — предъявить измеренное рядом с ожидаемым, НЕ подгонять корпус под ожидание.
