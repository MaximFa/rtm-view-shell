# ПЕРЕВОДЫ — редактор экранов (`PR234-L10N-KEYLEAK-01`, шаг 1 из 2)

> Автор переводов: `coordinator-0919b`, 2026-09-19. Основание — `§A` п.3f: переводы делает координатор.
> Список имён и английский текст — `shell-0919b`, `.coord/l10n_screeneditor_terms.md`
> (блоб `3691a233bfedc21206bb1592dcde70616b38581b`, пере-снят мной по `git hash-object`, сошёлся).
> Здесь **19 НОВЫХ ключей**. Четыре существующих (`Widgets_BusinessUnit`, `WidgetCfg_Colors`,
> `Common_Cancel`, `Common_Delete`) не трогаются: они уже в трёх словарях.
> `en` — не мой перевод, а то, что стоит на экране сейчас; перенесён из списка shell без изменений.

| ключ | en | he | ru |
|---|---|---|---|
| `Common_Auto` | Auto | אוטומטי | Авто |
| `Common_MoveUp` | Move up | הזז למעלה | Переместить вверх |
| `Common_MoveDown` | Move down | הזז למטה | Переместить вниз |
| `Common_Default` | Default | ברירת מחדל | По умолчанию |
| `Common_NoMatches` | No matches | אין התאמות | Нет совпадений |
| `Screens_SaveAsTemplate` | Save as Template | שמור כתבנית | Сохранить как шаблон |
| `Screens_DeleteTemplate` | Delete Template | מחק תבנית | Удалить шаблон |
| `Screens_TemplateName` | Template Name | שם התבנית | Название шаблона |
| `Screens_TemplateNamePlaceholder` | Enter template name... | הזן שם תבנית... | Введите название шаблона... |
| `Screens_NoBusinessUnits` | No Business Units available | אין יחידות עסקיות זמינות | Нет доступных подразделений |
| `Screens_SelectBusinessUnitPlaceholder` | Select Business Unit... | בחר יחידה עסקית... | Выберите подразделение... |
| `Screens_ValuePlaceholder` | Value... | ערך... | Значение... |
| `Screens_ColumnQueueName` | Queue Name | שם התור | Название очереди |
| `Screens_RemoveColumn` | Remove column | הסר עמודה | Удалить столбец |
| `Screens_RemoveRow` | Remove row | הסר שורה | Удалить строку |
| `Screens_NoColumnsYet` | No columns defined yet. | לא הוגדרו עמודות עדיין. | Столбцы ещё не заданы. |
| `Screens_NoRowsYet` | No rows defined yet. | לא הוגדרו שורות עדיין. | Строки ещё не заданы. |
| `Screens_NoFilterConditions` | No filter conditions defined. | לא הוגדרו תנאי סינון. | Условия фильтра не заданы. |
| `Screens_NoFilterConditionsHint` | Add conditions to filter rows before display. | הוסף תנאים לסינון שורות לפני התצוגה. | Добавьте условия, чтобы отфильтровать строки перед показом. |

## Согласованность с уже живущими значениями
- `Business Unit` в словаре — `Подразделение` / `יחידה עסקית`. Поэтому `Screens_NoBusinessUnits` и
  `Screens_SelectBusinessUnitPlaceholder` набраны теми же словами, а не синонимами.
- Многоточие плейсхолдеров сохранено во всех трёх языках — оно часть вида поля, а не пунктуация.
- Точка в конце сохранена там, где она есть в английском: это целые предложения-пустышки,
  а не подписи.

## Чего здесь НЕТ
Правки словарей и правки разметки. Это список значений; заводит их владелец `.resx`.
