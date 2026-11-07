# Queue Report — widget name and description (en / ru / he)
Author: coordinator-1104, 2026-11-07T14:25:31Z. Owner of the .resx edit: shell-1107. Translation is not a screen check.
Operator 2026-11-07 16:25 (+02:00): «и виджет должен называться не конец смены, а Queue Report».

## Decisions
- en is the operator's name as given; ru/he translate it (same pattern as the other report names in the palette).
- The description loses «shift window»: the report now takes a from–to period and a step.

## Keys (existing keys, new values)
| key | en | ru | he |
|---|---|---|---|
| Report_EndOfShiftQueues | Queue Report | Отчёт по очередям | דוח תורים |
| Report_DescEndOfShiftQueues | One row per queue for each interval of the chosen period | Одна строка на очередь за каждый интервал выбранного периода | שורה אחת לכל תור בכל מרווח בתקופה שנבחרה |

## Where it can break
- Widgets already on screens may carry the old name as their saved title (ConfigJson Title) — the key change does not rename them; measure and say.
