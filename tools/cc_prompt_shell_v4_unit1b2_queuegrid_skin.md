# CC task — V4-UNIT1-B2: QueueGridWidget in the new look

**Author:** shell-0919b · 2026-09-24 · **Branch:** `v4` (= `6d9b89c`) · **Worktree:** `D:\Claude\Projects\RTM-design` · Code/comments EN.
**Authority:** coordinator-0919b 24.09 18:40Z (ЕДИНИЦА 1, пункт 3), 19:15Z (слой `--wb-*`), 19:50Z
(меняется только внешний вид), 20:20Z (семнадцать ролей приняты; три остальных `live-dot` — НЕ брать).

## INIT / служебные части (§0.6a, §0.6b, §0.6, §0.5 — в силе)
`cd "D:\Claude\Projects\RTM-design"` — **не тот каталог, где v3.** `v3` не трогать ничем.
**§0.6a** целостность до первой правки: `git status --short`, по каждому `M`-файлу сверить строки с
`git show HEAD:"$f"`, усечённый — восстановить и НЕ продолжать.
`Edit` ЗАПРЕЩЁН, после записи `fsync`. **§0.6b** биндинг: преамбула в `.coord/cc/shell.md` ДО правки,
постамбула `RESULT` после. **`commit.lock`** обязателен (§42.4). **§0.6** пост-коммитная сверка блоба
с `git hash-object` файла на диске. **§0.5/PD-007** последним действием `git show HEAD:"$f" > "$f"` по
каждому файлу, затем `sync`. Коммит — узкими явными путями, без `-A` и без каталогов. `NO push`.
Размер в `RESULT` снимается ДО ре-синка и после него не совпадёт — **сверка только по блобу.**

## Правило, которое старше задания
**МЕНЯЕТСЯ ТОЛЬКО ВНЕШНИЙ ВИД. Не удаляем, не переименовываем, не переносим, не упрощаем — ни поля,
ни ключи, ни классы, ни настройки, ни поведение.** Единственное изъятие, заказанное оператором
явно, — надпись `LIVE` и её точка, и только в этом виджете.

## Файлы — ровно два
```
src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor       -> bacc131e295edae161b6c49cb9cc91201f1f2930
src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css   -> daf9022136ab1c1006d3198cb48098d7b6a6ce7e
```
СТОП при расхождении пина.

## Что делаем

### 1. Включить слой
На корневой `<div class="queue-grid-widget" …>` (строка 17) добавить класс `wb-skin`. Словарь
`--wb-*` уже объявлен на этом классе в `wwwroot/css/widgets/wallboard-skin.css` (коммит `6d9b89c`,
17 переменных). Больше нигде класс не ставить.

### 2. Одеть панель — правим ТОЛЬКО `QueueGridWidget.razor.css`
По `.claude/skills/rtm-wallboard/assets/wallboard.css`:
- корень виджета — фон `var(--wb-card)`, рамка `1px solid var(--wb-line)`, радиус `var(--wb-radius)`;
- шапка таблицы — фон `#f7f9fc`, нижняя граница `var(--wb-line)`, подписи `var(--wb-muted)`,
  размер на 1–2px меньше тела;
- строки — разделитель `var(--wb-line2)`, чётные `#fcfdff`;
- пилюли порогов (`.threshold-badge`) — пары фон/текст из `--wb-okbg/--wb-ok`,
  `--wb-warnbg/--wb-warn`, `--wb-badbg/--wb-bad`;
- таблица — `table-layout: fixed`.
⛔ **`display:inline-block` на `td` не писать.** Первый пункт `references/pitfalls.md`: ячейка
выпадает из табличного контекста, строка молча становится трёхэтажной, разметка валидна, ошибки нет.

### 3. Снять индикатор LIVE — и надпись, и точку
Строки 171–187, блок `@* Live indicator *@` в футере: убрать `<span class="live-dot …">` и соседний
`<span class="small">` с `@L["Widget_Live"]` / `@L["Widget_Disconnected"]`. Из `.razor.css` убрать
`.live-dot`, `.live-dot.connected`, `.live-dot.disconnected`, `@keyframes pulse-green` и
`@media (prefers-reduced-motion)` для неё.

⛔ **Надпись здесь приходит КЛЮЧОМ СЛОВАРЯ, а не литералом.** Поиск по слову `LIVE` в этом файле даёт
**0** — и это ноль по построению, слепой предикат: надпись рисуется через `@L["Widget_Live"]`, а в
словарях лежит `Live` / `חי` / `Live`. Кто проверит «LIVE = 0» и объявит зелёное, оставит надпись на
экране. Считать по КЛЮЧАМ.
⛔ **Ключи `Widget_Live` и `Widget_Disconnected` из `.resx` НЕ УДАЛЯТЬ.** `.resx` не трогать ни одним
символом. Ключ `Widget_Live` зовётся из 7 мест корпуса; здесь снимается одно отображение, а не ключ.
⛔ **`ConnectionState`, `_connectionState`, `aria-live`, баннеры Reconnecting / Connecting / Failed и
`aria-label="@L["Widget_LiveDataUpdating"]"` на обёртке — НЕ ТРОГАТЬ.** Состояние подключения
остаётся и остаётся видимым через свои баннеры; снимается только зелёная точка и слово рядом с ней.
Обёртку `<div class="d-flex align-items-center gap-1" aria-label=…>` оставить на месте пустой либо
сохранить её `aria-label` — доступность не уменьшать.

### 4. Починить белое на белом — два жёстких `#ffffff`
`GetTheadCellStyle()` (строка 1206) и `GetFilterButtonStyle()` (строка 1214) подставляют
`#ffffff`, когда цвет в настройке виджета пуст. На тёмном фоне старого вида это читалось; на белой
карточке эталона шапка таблицы и кнопки фильтра станут **белым по белому** — невидимыми.
Заменить запасное значение с `"#ffffff"` на `"var(--wb-ink)"` в обоих методах.
⛔ Менять ТОЛЬКО запасную ветку. Условие `!string.IsNullOrEmpty(EffectiveFontColor) ? EffectiveFontColor : …`
остаётся: если цвет в настройке задан, побеждает он. Настройку не трогаем, `EffectiveFontColor`,
`_fontColor`, `DarkMode`-пары не трогаем.

## Чего делать НЕЛЬЗЯ
- **`tokens.css`, `wallboard-skin.css`, `App.razor` не менять** — они приняты в B1.
- **Три остальных `live-dot`** (`AgentGridWidget`, `AgentStateDistributionWidget`, `WfmWidget`) —
  **не трогать**. [coordinator-0919b 20:20Z] Смешав их сюда, мы смешаем в одной приёмке «попали в
  дизайн» и «сняли индикатор», и на красном не разберём, что не сошлось. Пойдут своей единицей.
- **`--thr-*` не трогать и не упрощать.** Состояние «нет данных» остаётся отдельной ролью: его
  потеря на стене у заказчика читается как «всё хорошо» — ложное зелёное на экране.
- **Логику не трогать:** сортировку, фильтры, пагинацию, SignalR, `IFilterPopupCoordinator`,
  `GetFilteredRows`/`GetPagedRows`, обработчики клавиш. Это правка вида.
- **Движок эталона не переносить.** `scripts/engine.js` и генерация `Math.random` — для демонстраций
  с синтетикой. Виджет, получивший выдуманные числа, это не редизайн, а красивая ложь на стене у
  заказчика. Ни одного скрипта не добавлять.
- **Тёмную тему не сочинять** — в эталоне её нет (0/0/0 при положительном контроле `--ok` = 56).
  `DarkMode` остаётся работоспособен и не трогается.
- **`HeaderBackgroundColor` / `HeaderFontColor`, `.gitattributes`, `info-slot.css`** — не трогать.
- Показалось, что «надо бы заодно убрать» — не убирать, назвать в `RESULT` строкой `NOTED`.

## ПРЕДИКАТЫ — единица и область названы у каждого
| предикат | область | единица | ДО | ПОСЛЕ |
|---|---|---|---|---|
| `wb-skin` | `QueueGridWidget.razor` | вхождения | 0 | **1** |
| `live-dot` | `QueueGridWidget.razor` | вхождения | 1 | **0** |
| `live-dot` | `QueueGridWidget.razor.css` | вхождения | 4 | **0** |
| `pulse-green` | `QueueGridWidget.razor.css` | вхождения | 2 | **0** |
| `Widget_Live"` (ключ, с кавычкой) | `QueueGridWidget.razor` | вхождения | 1 | **0** |
| `Widget_LiveDataUpdating` | `QueueGridWidget.razor` | вхождения | 1 | **1** (не трогать) |
| `Widget_Disconnected` | `QueueGridWidget.razor` | вхождения | 1 | **0** |
| `ConnectionState` | `QueueGridWidget.razor` | вхождения | 11 | **11 — не изменилось** |
| `aria-live` | `QueueGridWidget.razor` | вхождения | 2 | **2** |
| `#ffffff` (без учёта регистра) | `QueueGridWidget.razor` | вхождения | 5 | **3** |
| `#ffffff` на строках 1206 и 1214 | те же строки | вхождения | 2 | **0** |
| `var(--wb-ink)` | `QueueGridWidget.razor` | вхождения | 0 | **2** |
| `--wb-` | `QueueGridWidget.razor.css` | уникальные имена | 0 | ≥ 8 |
| `td` с `inline-block` | `QueueGridWidget.razor.css` | вхождения | 0 | **0** |
| `.resx` изменено | `git diff --name-only 6d9b89c HEAD -- '*.resx'` | файлы | — | **0** |
| файлов изменено под `Widgets/` кроме двух QueueGrid | тот же diff | файлы | — | **0** |

⛔ **`ConnectionState` — сторож НЕИЗМЕНЕНИЯ, а не ноль.** В файле 11 вхождений: поле, `enum`,
четыре ветки разметки, присваивания в обработчиках. Ожидание `11 -> 11`. Кто прочтёт как «ноль»,
снесёт состояние подключения и погасит баннеры переподключения.

⛔ **`#ffffff` — тоже ИЗМЕНЕНИЕ, `5 -> 3`, а НЕ ноль.** В файле их пять, и три из них чужие:
```
234   private string _darkFontColor = "#FFFFFF";          <- тёмная тема, НЕ ТРОГАТЬ
421   _darkFontColor = Config.DarkFontColor ?? "#FFFFFF"; <- тёмная тема, НЕ ТРОГАТЬ
1206  ... : "#ffffff";                                    <- ЦЕЛЬ
1214  ... : "#ffffff";                                    <- ЦЕЛЬ
1243  var bg = !string.IsNullOrEmpty(fg) ? fg : "#ffffff"; <- GetBadgeInvertStyle, НЕ ТРОГАТЬ
```
Первые два — запасной цвет текста в тёмной теме; `DarkMode` остаётся работоспособен, и белый там
на месте. Строка 1243 — инверсия бейджа; её трогать в этой единице нельзя, иначе пилюли поедут
сразу с двух сторон — из CSS и из C#, — и на красном не разобрать, чьё. Если она окажется видимой
проблемой на экране, назвать её в `NOTED`, а не править. Кто «приведёт `#ffffff` к нулю», сломает
тёмную тему и бейджи.
**Отрицательная половина обязательна:** каждый нулевой предикат сопроводить поиском заведомо
присутствующей строки в той же области. Ноль даёт и слепой поиск — а один слепой ноль в этой задаче
уже был: `LIVE` как литерал.

## Сборка и глаза
`dotnet build` проекта `src/CcDashboard.Web` — 0 ошибок; предупреждения «до/после» в `RESULT`.
Сборки мало: правка визуальная. Если в окружении есть возможность открыть экран с этим виджетом —
открыть и посмотреть, читается ли шапка таблицы и не осталось ли точки. Не получилось — так и
написать в `RESULT` (`VISUAL: not checked`), не выдавая сборку за проверку вида.

## Коммит
```
git add "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor" "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css"
git commit -m "style(v4): QueueGridWidget in the wallboard look ..."
```
Числа доказательства — В СООБЩЕНИЕ КОММИТА: wb-skin 0->1 · live-dot 1->0 / 4->0 · pulse-green 2->0 ·
Widget_Live 1->0 · Widget_Disconnected 1->0 · aria-live 2->2 · ConnectionState 11->11 · #ffffff 5->3 (только строки 1206, 1214) ·
resx files changed 0 · build errors before/after.
Авторство роли — строкой в сообщении коммита. Строк `Co-Authored-By` и `Claude-Session` в сообщении
коммита быть НЕ должно [со слов оператора 2026-09-24]. `NO push`.

## RESULT — обязательная форма, ОБЛАСТЬ и ЕДИНИЦА у каждого числа
```
PINS      QueueGridWidget.razor bacc131e… OK/FAIL · .razor.css daf90221… OK/FAIL
FILES     <путь> <blob> <bytes до ре-синка> (disk==blob YES/NO) — по каждому из двух
SKIN      wb-skin 0->1 · --wb- uniq in css: N · td inline-block: 0
LIVE      live-dot razor 1->0 · css 4->0 · pulse-green 2->0 · Widget_Live" 1->0 · Widget_Disconnected 1->0
KEEP      ConnectionState 11->11 · aria-live 2->2 · Widget_LiveDataUpdating 1->1
COLOR     #ffffff 5->3 (только строки 1206, 1214) · var(--wb-ink) 0->2
          pos.control (та же область, заведомо присутствующая строка): <что искал> = N
GUARDS    resx changed: 0 · other widget files changed: 0 · tokens/skin/App.razor changed: 0
          neg.control того же diff по изменённым путям: >0
BUILD     errors before/after · warnings before/after
VISUAL    смотрел/не смотрел; что видно на шапке таблицы и в футере
COMMIT    <sha> · post-commit blob vs disk: MATCH/MISMATCH
RESYNC    §0.5 выполнен: YES/NO
NOTED     что просилось «убрать заодно» и НЕ было убрано — списком, или «нет»
```
Любое DIFFER — предъявить измеренное рядом с ожидаемым, НЕ подгонять корпус под ожидание.
