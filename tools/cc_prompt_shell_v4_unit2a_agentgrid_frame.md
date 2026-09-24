# CC task — V4-UNIT2-A: AgentGridWidget — panel frame, header, indicator removal

**Author:** shell-0919b · 2026-09-24 · **Branch:** `v4` (= `5c37d4b`) · **Worktree:** `D:\Claude\Projects\RTM-design` · Code/comments EN.
**Authority:** coordinator-0919b 24.09 21:55Z — ЕДИНИЦА 1 зелёная; ЕДИНИЦА 2 = `AgentGrid`, затем
`DataSlot`, двумя подъединицами. Эта подъединица — **каркас**, зеркало принятой правки `QueueGrid`.
**Цвета состояний агента (`badge-*`, `avatar-*`) в НЕЁ НЕ ВХОДЯТ** — они живые, их сведение требует
решения по семантике и пойдёт подъединицей 2A-2.

## INIT / служебные части (§0.6a, §0.6b, §0.6, §0.5 — в силе)
`cd "D:\Claude\Projects\RTM-design"` · `v3` не трогать ничем. **§0.6a** целостность до первой правки.
`Edit` ЗАПРЕЩЁН, после записи `fsync`. **§0.6b** биндинг. **`commit.lock`** обязателен (§42.4).
**§0.6** пост-коммитная сверка блоба с `git hash-object` на диске. **§0.5/PD-007** ре-синк последним
действием, затем `sync`. Размер в `RESULT` читается как «до ре-синка», сверка — только по блобу.
Коммит узкими явными путями, без `-A`. Строк `Co-Authored-By` и `Claude-Session` в сообщении коммита
быть НЕ должно [со слов оператора 2026-09-24]. `NO push`.

## Правило, которое старше задания
**МЕНЯЕТСЯ ТОЛЬКО ВНЕШНИЙ ВИД. Не удаляем, не переименовываем, не переносим, не упрощаем — ни поля,
ни ключи, ни классы, ни настройки, ни поведение.** Единственное изъятие, заказанное оператором
явно, — надпись `LIVE` и её точка.

## Урок принятой единицы, без которого эта правка будет мёртвой
Вид этих виджетов задаётся **встроенным атрибутом `style`**, собираемым в C#. Встроенный стиль
сильнее правила из файла. В `QueueGrid` из-за этого пять объявлений легли в коммит и не красили
ничего: три правила пилюль (класса не было в разметке) и `color`/`font-size` у шапки.
**Здесь так же: не пиши в `.razor.css` то, за что спорит встроенный стиль.** Цвет и кегль шапки
задаются только в C#; в CSS — то, чего встроенный стиль не трогает.

## Файлы — ровно два
```
src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor       -> a2c71a7a976274b307bb5af70a859d2c5d0f6f6e
src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor.css   -> 8193518210ee233086b0d4fb467edd5ec9fad367
```
СТОП при расхождении пина.

## Что делаем

### 1. Включить слой
На корневой `<div class="agent-grid-widget" …>` (строка 17) добавить класс `wb-skin`.
Словарь `--wb-*` объявлен на этом классе в `wwwroot/css/widgets/wallboard-skin.css` — файл НЕ трогать.

### 2. Каркас панели — `AgentGridWidget.razor.css`, только живые свойства
Добавить блоки под `.agent-grid-widget.wb-skin`, по образцу принятого `QueueGridWidget.razor.css`:
- корень — фон `var(--wb-card)`, рамка `1px solid var(--wb-line)`, радиус `var(--wb-radius)`;
- `.agent-grid-table` (или таблица внутри `.agent-grid-body`) — `table-layout: fixed`;
- шапка — только `border-bottom: 1px solid var(--wb-line)`; **`color` и `font-size` НЕ писать**;
- строки — `border-bottom: 1px solid var(--wb-line2)`, чётные `background: #fcfdff`;
- футер — `border-top: 1px solid var(--wb-line)`.
⛔ `display:inline-block` на `td` не писать: ячейка выпадает из табличного контекста, строка молча
становится трёхэтажной, разметка валидна и ошибки нет (`references/pitfalls.md`, пункт первый).

### 3. Снять индикатор — надпись и точку
Строки 183–199, блок `@* Live indicator *@` в футере: убрать `<span class="live-dot …">` и соседний
`<span class="text-muted small">` с `@L["Widget_Live"]` / `@L["Widget_Disconnected"]`.
Из `.razor.css` убрать `.live-dot`, `.live-dot.connected`, `.live-dot.disconnected`,
`@keyframes pulse-green` и относящийся к ней `@media (prefers-reduced-motion)`.

⛔ **Надпись приходит КЛЮЧОМ СЛОВАРЯ.** Поиск слова `LIVE` по файлу даст 0 при любом положении дел —
это слепой предикат, на нём уже обожглись. Считать по ключам: `Widget_Live"` 1 → 0.
⛔ **Ключи из `.resx` НЕ УДАЛЯТЬ**, `.resx` не трогать ни одним символом [coordinator 21:55Z].
⛔ **`ConnectionState` не трогать** — он нужен логике переподключения, а не индикатору. Сторож —
**разность**: 13 → **11**, потому что два вхождения живут внутри удаляемого блока. НЕ ноль.
⛔ **`aria-live` 2 → 2.** Обёртку `<div … aria-label="@L["Widget_LiveDataUpdating"]">` оставить.

### 4. Белое по белому
`GetTheadCellStyle()` (строка 1357) и `GetFilterButtonStyle()` (1365) подставляют `#ffffff`, когда
цвет в настройке пуст. На белой карточке шапка и кнопки фильтра стали бы невидимыми при полностью
зелёных предикатах. Заменить запасное значение: в `GetTheadCellStyle()` на **`var(--wb-muted)`**
(подписи колонок приглушённые), в `GetFilterButtonStyle()` на **`var(--wb-ink)`** — как в принятом
`QueueGrid`.
⛔ Менять ТОЛЬКО запасную ветку тернарного оператора. Настройку, `EffectiveFontColor`, `DarkMode`-пары
не трогать.
⛔ **`#ffffff` 7 → 5, а НЕ ноль.** Пять из семи чужие:
```
247  _darkFontColor   = "#FFFFFF";                      <- тёмная тема, НЕ ТРОГАТЬ
286  _avatarFontColor = "#FFFFFF";                      <- аватар, НЕ ТРОГАТЬ
444  _darkFontColor   = Config.DarkFontColor ?? …       <- тёмная тема, НЕ ТРОГАТЬ
459  _avatarFontColor = Config.AvatarFontColor ?? …     <- аватар, НЕ ТРОГАТЬ
1357 ... : "#ffffff";                                   <- ЦЕЛЬ -> var(--wb-muted)
1365 ... : "#ffffff";                                   <- ЦЕЛЬ -> var(--wb-ink)
1394 ... : "#ffffff";  GetBadgeInvertStyle              <- НЕ ТРОГАТЬ
```

## Чего делать НЕЛЬЗЯ
- **`badge-*` и `avatar-*` не трогать в этой подъединице.** Семь классов состояний агента и шесть
  цветов аватара заданы в CSS хардкодом, разметка их выдаёт — они ЖИВЫЕ и покрасятся. Но свести их
  к слою — решение о семантике цвета (у нас «доступен» зелёный и «в разговоре» синий, у эталона
  «в разговоре» зелёный), и оно за координатором. Смешав это сюда, мы смешаем в одной приёмке
  каркас и семантику.
- **Колонки, их состав и порядок — данные, а не вид.** Не трогать [coordinator 21:55Z].
- Не трогать: `tokens.css`, `wallboard-skin.css`, `App.razor`, `.resx`, другие виджеты, `--thr-*`,
  логику фильтров, сортировки, пагинации, SignalR.
- **Движок эталона не переносить**: `scripts/engine.js` и генерация `Math.random` — для демонстраций.
  Виджет с выдуманными числами — не редизайн, а красивая ложь на стене у заказчика.
- **Тёмную тему не сочинять** — в эталоне её нет; `DarkMode` остаётся работоспособен.
- Показалось, что «надо бы заодно убрать» — не убирать, назвать в `NOTED`. Чужой старый мёртвый код —
  принести списком, не сносить.

## ПРЕДИКАТЫ — единица и область названы у каждого
| предикат | область | единица | ДО | ПОСЛЕ |
|---|---|---|---|---|
| `wb-skin` | `.razor` | вхождения | 0 | **1** |
| `live-dot` | `.razor` | вхождения | 1 | **0** |
| `live-dot` | `.razor.css` | вхождения | 4 | **0** |
| `pulse-green` | `.razor.css` | вхождения | 2 | **0** |
| `Widget_Live"` | `.razor` | вхождения | 1 | **0** |
| `Widget_Disconnected` | `.razor` | вхождения | 1 | **0** |
| `Widget_LiveDataUpdating` | `.razor` | вхождения | 1 | **1** |
| `ConnectionState` | `.razor` | вхождения | 13 | **11** (разность −2) |
| `aria-live` | `.razor` | вхождения | 2 | **2** |
| `#ffffff` (без регистра) | `.razor` | вхождения | 7 | **5** |
| `var(--wb-muted)` | `.razor` | вхождения | 0 | **1** |
| `var(--wb-ink)` | `.razor` | вхождения | 0 | **1** |
| `--wb-` уникальных | `.razor.css` | имена | 0 | **4** (`card`,`line`,`line2`,`radius`) |
| `badge-` | `.razor.css` | вхождения | 8 | **8 — не изменилось** |
| `avatar-` | `.razor.css` | вхождения | 6 | **6 — не изменилось** |
| `color:` в блоке `wb-skin` шапки | `.razor.css` | вхождения | 0 | **0** |
| `.resx` изменено | `git diff --name-only 5c37d4b HEAD -- '*.resx'` | файлы | — | **0** |
| файлов кроме двух AgentGrid | тот же diff | файлы | — | **0** |

**Отрицательная половина обязательна:** каждый нулевой предикат — с положительным контролем в той же
области (например `threshold-badge` или `agent-grid-body`, которые остаются). Ноль даёт и слепой
поиск; в этой единице слепых нулей было уже два.

## Сборка
`dotnet build src/CcDashboard.Web` — 0 ошибок. Предупреждения предъявить с **названной областью**
(проект или решение): в прошлых прогонах приходило 26 и 52 «pre-existing» — одно из чисел про другую
область.

## Коммит
```
git add "src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor" "src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor.css"
git commit -m "style(v4): AgentGridWidget panel frame and indicator removal ..."
```
Числа доказательства — в сообщение коммита: wb-skin 0->1 · live-dot 1->0 / 4->0 · pulse-green 2->0 ·
Widget_Live 1->0 · Widget_Disconnected 1->0 · ConnectionState 13->11 · aria-live 2->2 ·
hash-ffffff 7->5 · wb- uniq in css 0->4 · badge- 8->8, avatar- 6->6 · resx 0 · build errors before/after.
Авторство роли — строкой.

## RESULT — ОБЛАСТЬ и ЕДИНИЦА у каждого числа
```
PINS      razor a2c71a7a OK/FAIL · css 81935182 OK/FAIL
FILES     <путь> <blob> <bytes до ре-синка> (disk==blob YES/NO) — по каждому
SKIN      wb-skin 0->1 · --wb- uniq css 0->4 · td inline-block 0 · color в блоке шапки 0
LIVE      live-dot 1->0 / 4->0 · pulse-green 2->0 · Widget_Live" 1->0 · Widget_Disconnected 1->0
KEEP      ConnectionState 13->11 (разность −2, НЕ ноль) · aria-live 2->2 · Widget_LiveDataUpdating 1->1
          badge- 8->8 · avatar- 6->6
COLOR     #ffffff 7->5 · var(--wb-muted) 0->1 · var(--wb-ink) 0->1
          НЕ тронуты: 247, 286, 444, 459, 1394 · pos.control: <что искал> = N
GUARDS    resx 0 · other files 0 · neg.control того же diff: >0
BUILD     область (проект|решение) · errors before/after · warnings before/after
COMMIT    <sha> · post-commit blob vs disk: MATCH/MISMATCH
RESYNC    §0.5 выполнен: YES/NO
NOTED     чужой старый мёртвый код, если нашёлся, — списком, НЕ трогая; или «нет»
```
Любое DIFFER — предъявить измеренное рядом с ожидаемым, НЕ подгонять корпус под ожидание.
