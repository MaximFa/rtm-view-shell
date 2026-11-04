# Export — skipped widgets: terms (en / ru / he)
Author: coordinator-1104, 2026-11-04T08:06:31Z. Owner of the .resx edit: shell-0919b. Translation is not a screen check.

## Decisions (read before inserting)
- Word for "export": **Экспорт / ייצוא** (`Reports_Export`). «Выгрузка» REJECTED — not in any locale's resources; two words for one thing.
- Word for "widget": **виджет / ווידג'ט** (`Widgets_*`, `Common_Widgets`). Masculine in both languages — the possessive below agrees («его», «שלו»).
- Tone: a WARNING, not an error — the file was downloaded, part of it is missing. REJECTED «Не экспортировано» / «ייצוא נכשל» (read as failure). Chosen: «не вошло в экспорт» / «לא נכלל בייצוא».
- Code `invalid-window` RENAMED to `shift-hours` (contract not yet written, backend gets the same word): the only real cause is the shift hours, and the text names it precisely. A future different cause gets a NEW code; until it has a text it falls to the generic line, visibly.

## Keys
| key | en | ru | he |
|---|---|---|---|
| Reports_ExportSkipped | Not exported | Не вошло в экспорт | לא נכלל בייצוא |
| Reports_ExportSkippedItem | {0} — {1} | {0} — {1} | {0} — {1} |
| Reports_ExportSkippedItemNoReason | {0} | {0} | {0} |
| Reports_ExportSkippedDenied | no access to its data | нет доступа к его данным | אין גישה לנתונים שלו |
| Reports_ExportSkippedNoData | no data for the selected period | нет данных за выбранный период | אין נתונים לתקופה שנבחרה |
| Reports_ExportSkippedShiftHours | the shift hours are not set, or do not fit the selected date | часы смены не заданы или не подходят к выбранной дате | שעות המשמרת לא הוגדרו או אינן מתאימות לתאריך שנבחר |

## Where mechanical insertion breaks (named before insertion)
- `{0} — {1}` in **he**: {0} is the widget Title, often Latin. In an RTL line a Latin title next to the dash can be reordered by bidi, and the dash may appear on the wrong side. Visible only on 234 in Chrome with a Latin-titled widget — part of the screen check.
- Reasons start lower-case in en/ru on purpose: they continue the line after the dash.
- Key `Reports_ExportSkippedInvalidWindow` from shell's list is replaced by `Reports_ExportSkippedShiftHours` (code renamed).
