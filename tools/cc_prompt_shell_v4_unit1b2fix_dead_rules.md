# CC task — V4-UNIT1-B2-FIX: remove the dead style rules, move header colour to the one place that wins

**Author:** shell-0919b · 2026-09-24 · **Branch:** `v4` (= `a87e0d6`) · **Worktree:** `D:\Claude\Projects\RTM-design` · Code/comments EN.
**Authority:** coordinator-0919b 24.09 21:05Z — «СНОСИ»: три правила пилюль написаны в ЭТОЙ ЖЕ единице
три часа назад и не работают; доделать свою правку до верного состояния — это единица, а не «снос заодно».
⛔ Разрешение узкое: **только правила, написанные коммитом `a87e0d6`.** Старые чужие правила в тех же
файлах — не трогать, назвать в `NOTED`.

## INIT / служебные части (§0.6a, §0.6b, §0.6, §0.5 — в силе)
`cd "D:\Claude\Projects\RTM-design"` · `v3` не трогать ничем. **§0.6a** целостность до первой правки.
`Edit` ЗАПРЕЩЁН, после записи `fsync`. **§0.6b** биндинг. **`commit.lock`** обязателен (§42.4).
**§0.6** пост-коммитная сверка блоба с `git hash-object` на диске. **§0.5/PD-007** ре-синк последним
действием, затем `sync`. Размер в `RESULT` читается как «до ре-синка», сверка — только по блобу.
Коммит узкими явными путями, без `-A`. Строк `Co-Authored-By` и `Claude-Session` в сообщении коммита
быть НЕ должно [со слов оператора 2026-09-24]. `NO push`.

## Дефект: правила есть, а вида нет — «счёт по написанному вместо счёта по действующему»
Вид этого виджета задаётся **встроенным атрибутом `style`**, который собирается в C#. Встроенный
стиль сильнее любого правила из файла. Поэтому правило, конкурирующее с ним за то же свойство,
мертво — оно пишется, проходит все предикаты и не красит ничего.

**Доказано двумя способами.**
1. Чтением: классов `thr-ok` / `thr-warn` / `thr-bad` в разметке **0 вхождений**
   [измерено автором и пере-снято coordinator-0919b, область `src/` без `obj`/`bin`, единица —
   вхождения; положительный контроль `threshold-badge` = 2, отрицательный `thr-zzz` = 0].
   Пилюля рождается одна, строка 157: `<span class="threshold-badge" style="@GetBadgeStyle(...)">`.
2. Глазами: автор собрал макет из НАСТОЯЩИХ `wallboard-skin.css` и `QueueGridWidget.razor.css`
   и отрисовал его. На картинке шапка таблицы — **тёмная и крупнее тела**, хотя правило
   `.queue-grid-thead th { color: var(--wb-muted); font-size: 0.72rem }` требует серую и мельче.
   Причина та же: `GetTheadCellStyle()` подставляет `color` и `font-size` встроенным стилем.

## Правки — ровно два файла

### 1. `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css`
Убрать правила, добавленные коммитом `a87e0d6` и не действующие:
- три блока `.queue-grid-widget.wb-skin .threshold-badge.thr-ok|.thr-warn|.thr-bad` — целиком
  (класса нет в разметке, и встроенный стиль всё равно сильнее);
- в блоке `.queue-grid-widget.wb-skin .queue-grid-thead th` убрать **объявления `color` и
  `font-size`** — оба перебиваются встроенным стилем. Объявление `border-bottom` **оставить**:
  границу встроенный стиль не задаёт, она работает.

⛔ **Остальное в этом файле не трогать.** `.queue-grid-widget.wb-skin` (фон, рамка, радиус),
`.queue-grid-table` (`table-layout`), `tbody tr` (разделители, чередование), `.threshold-badge`
(размер шрифта), `.queue-grid-footer` (верхняя граница) — работают, они остаются.
Старые правила выше по файлу (`.queue-grid-widget`, `.queue-grid-body table th|td`,
`.threshold-badge`, `.queue-grid-pagination`, `.pagination-btn`) — **чужие и старые, не трогать.**

### 2. `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor`
Единственное место, где цвет шапки можно задать так, чтобы он подействовал, — C#.
В `GetTheadCellStyle()` запасное значение сменить с `var(--wb-ink)` на **`var(--wb-muted)`**:
подписи колонок в эталоне приглушённые, а не чернильные.
В `GetFilterButtonStyle()` оставить `var(--wb-ink)` **как есть** — это кнопка, а не подпись.

⛔ Менять ТОЛЬКО запасную ветку `!string.IsNullOrEmpty(EffectiveFontColor) ? EffectiveFontColor : …`.
Настройку цвета, `EffectiveFontColor`, `_fontColor`, `DarkMode`-пары не трогать.
⛔ `#ffffff` на строках 222, 409 (тёмная тема) и 1231 (`GetBadgeInvertStyle`) — **чужие, не трогать.**

## Чего делать НЕЛЬЗЯ
- Пилюли порогов красить слоем — **нет.** Их цвет приходит из настроенных порогов (`--thr-*`,
  включая «нет данных»), и эту семантику не упрощаем: потеря состояния «нет данных» на стене у
  заказчика читается как «всё хорошо» — ложное зелёное на экране.
- Дописывать классы `thr-*` в разметку, чтобы «оживить» правила — **нет.** Встроенный стиль всё
  равно сильнее; получится второй мёртвый слой и уверенность, что «не попали в цвет».
- Трогать `tokens.css`, `wallboard-skin.css`, `App.razor`, `.resx`, другие виджеты, `--thr-*`,
  `ConnectionState`, `aria-live`, логику фильтров, сортировки и пагинации.
- Движок эталона не переносить: `scripts/engine.js` и генерация `Math.random` — для демонстраций.
  Виджет с выдуманными числами — не редизайн, а красивая ложь на стене у заказчика.

## Входные пины — СТОП при расхождении
```
src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor       -> de6e710f39f4c8e5f0a1eaeca7104dba42132dea
src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css   -> 93f3d6d31cf0a6142df8ffca546b7a13917441ad
```

## ПРЕДИКАТЫ — единица и область названы у каждого
| предикат | область | единица | ДО | ПОСЛЕ |
|---|---|---|---|---|
| `thr-ok` / `thr-warn` / `thr-bad` | `.razor.css` | вхождения | 3 | **0** |
| `threshold-badge` | `.razor.css` | вхождения | 5 | **2** |
| `var(--wb-muted)` | `.razor.css` | вхождения | 1 | **0** |
| `var(--wb-muted)` | `.razor` | вхождения | 0 | **1** |
| `var(--wb-ink)` | `.razor` | вхождения | 2 | **1** |
| `--wb-` уникальных | `.razor.css` | имена | 11 | **8** |
| `queue-grid-thead` | `.razor.css` | вхождения | 2 | **2** (блок остаётся) |
| `border-bottom` в блоке `thead th` | `.razor.css` | вхождения | 1 | **1** (остаётся) |
| `#ffffff` (без регистра) | `.razor` | вхождения | 3 | **3** (не трогаем) |
| `ConnectionState` | `.razor` | вхождения | 9 | **9** |
| `aria-live` | `.razor` | вхождения | 2 | **2** |
| `.resx` изменено | `git diff --name-only a87e0d6 HEAD -- '*.resx'` | файлы | — | **0** |
| файлов изменено кроме двух QueueGrid | тот же diff | файлы | — | **0** |

⛔ **`threshold-badge` 5 → 2 — изменение, не ноль.** Из пяти вхождений два живут в СТАРОМ правиле
`.threshold-badge { display:inline-block; padding; border-radius; font-weight; white-space }` и в
нашем `.wb-skin .threshold-badge { font-size }` — оба остаются. Кто «приведёт к нулю», снимет с
пилюли форму, и она станет обычным текстом.
⛔ **`--wb-muted` переезжает, а не исчезает:** `1 → 0` в css и `0 → 1` в razor. Сумма по предмету
неизменна. Проверять обе половины, иначе «ноль в css» прочтётся как потеря.
**Отрицательная половина обязательна:** каждый нулевой предикат — с положительным контролем в той
же области. Ноль даёт и слепой поиск; в этой единице слепых нулей было уже два.

## Сборка
`dotnet build src/CcDashboard.Web` — 0 ошибок. Предупреждения предъявить с **названной областью**
(проект или решение): в прошлых двух прогонах пришло 26 и 52 «pre-existing», и одно из чисел про
другую область.

## Коммит
```
git add "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor" "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor.css"
git commit -m "style(v4): drop the dead QueueGrid rules, move header colour into the inline builder ..."
```
Числа доказательства — в сообщение коммита: thr-* 3->0 · threshold-badge 5->2 · --wb- uniq 11->8 ·
--wb-muted css 1->0 / razor 0->1 · --wb-ink razor 2->1 · ConnectionState 9->9 · aria-live 2->2 ·
resx 0 · build errors before/after. Авторство роли — строкой.

## RESULT — ОБЛАСТЬ и ЕДИНИЦА у каждого числа
```
PINS      razor de6e710f OK/FAIL · css 93f3d6d3 OK/FAIL
FILES     <путь> <blob> <bytes до ре-синка> (disk==blob YES/NO) — по каждому
DEAD      thr-* 3->0 · threshold-badge 5->2 · --wb- uniq 11->8
          pos.control: <что искал в той же области> = N
MOVE      --wb-muted css 1->0 · razor 0->1 · --wb-ink razor 2->1
KEEP      thead border-bottom 1->1 · ConnectionState 9->9 · aria-live 2->2 · #ffffff 3->3
GUARDS    resx 0 · other files 0 · neg.control того же diff: >0
BUILD     область (проект|решение) · errors before/after · warnings before/after
COMMIT    <sha> · post-commit blob vs disk: MATCH/MISMATCH
RESYNC    §0.5 выполнен: YES/NO
NOTED     старые чужие мёртвые правила, если нашлись, — списком, НЕ трогая; или «нет»
```
Любое DIFFER — предъявить измеренное рядом с ожидаемым, НЕ подгонять корпус под ожидание.
