# Report step window, cut-edge mark, error texts, range caption (en / ru / he)
Author: coordinator-1104, 2026-11-07T11:22:59Z. Owner of the .resx edit: shell-1107 (v4, D:\Claude\Projects\RTM-design). Translation is not a screen check.

## Decisions
- Step window label follows DayTrend (operator: «тем же способом, как в виджете дейтренд»): DayTrend_TimeInterval is «Интервал» / «מרווח זמן» — same words here; en «Step» → «Interval» for the same reason.
- Cut-edge mark uses the existing «с … по …» pair of the date fields (ru) and «מ-… עד …» (he); dates stay numeric dd.MM in all three.
- Error texts: impersonal, statement + where to look, same register as Report_DateRangeInverted; he uses «יש ל…» for instructions.
- Report_ShownForRange mirrors Report_ShownForDate «Данные за {0}» / «נתונים עבור {0}».

## Keys
| key | en | ru | he |
|---|---|---|---|
| Report_Step | Interval | Интервал | מרווח זמן |
| Report_StepHalfHour | Half hour | Полчаса | חצי שעה |
| Report_StepHour | Hour | Час | שעה |
| Report_StepDay | Day | День | יום |
| Report_StepMonth | Month | Месяц | חודש |
| Report_StepYear | Year | Год | שנה |
| Report_IntervalFrom | (from {0}) | (с {0}) | (מ-{0}) |
| Report_IntervalTo | (to {0}) | (по {0}) | (עד {0}) |
| Report_IntervalFromTo | (from {0} to {1}) | (с {0} по {1}) | (מ-{0} עד {1}) |
| Report_ErrorNoData | There is no data for the selected period. | Нет данных за выбранный период. | אין נתונים לתקופה שנבחרה. |
| Report_ErrorInvalidConfig | This report's settings cannot be used. Open its settings and check them. | Настройки этого отчёта нельзя использовать. Откройте настройки и проверьте их. | לא ניתן להשתמש בהגדרות של דוח זה. יש לפתוח את ההגדרות ולבדוק אותן. |
| Report_ErrorShiftHours | The shift hours are not set, or do not fit the selected date. | Часы смены не заданы или не подходят к выбранной дате. | שעות המשמרת לא הוגדרו או אינן מתאימות לתאריך שנבחר. |
| Report_ErrorRetired | This report has been retired and is no longer built. | Этот отчёт снят и больше не строится. | דוח זה הוסר ואינו מופק עוד. |
| Report_ErrorUnknown | The report could not be built. | Не удалось построить отчёт. | לא ניתן היה להפיק את הדוח. |
| Report_ShownForRange | Data for {0} – {1} | Данные за {0} – {1} | נתונים עבור {0} – {1} |

## Where it can break (named before insertion)
- he «(מ-{0})»: the maqaf joins the prefix to a Latin-digit date; RTL/LTR order inside parentheses — screen check on 234.
- en Report_Step changes from «Step» to «Interval» — change en too.
