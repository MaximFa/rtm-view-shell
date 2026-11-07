# Report column funnels — operator names and input hints (en / ru / he)
Author: coordinator-1104, 2026-11-07T08:07:43Z. Owner of the .resx edit: shell-0919b (v4, D:\Claude\Projects\RTM-design). Translation is not a screen check.

## Decisions
- «Between» is capitalised in en to match the existing comparison names in the same window family (Widgets_MatchType_GreaterThan «Greater Than», LessThan «Less Than»); ru/he follow the existing «Больше / Меньше», «גדול מ / קטן מ» — one word, capital in ru.
- Duration hint: he spells out the units in words — the letter abbreviations ש:דד:שש would use ש for both hours and seconds.
- Unreadable value: a statement of what is wrong + where to look, impersonal in he («יש לבדוק»), polite plural in ru — same register as Report_DateRangeInverted. Em dash in all three (en value from shell had a hyphen).

## Keys
| key | en | ru | he |
|---|---|---|---|
| Report_Between | Between | Между | בין |
| Report_DurationHint | Time as h:mm:ss | Время в формате ч:мм:сс | זמן בתבנית שעות:דקות:שניות |
| Report_FilterValueNotUnderstood | This value cannot be read — check the format. | Не удаётся прочитать значение — проверьте формат. | לא ניתן לקרוא את הערך — יש לבדוק את הפורמט. |

## Where it can break (named before insertion)
- he: «שעות:דקות:שניות» sits next to an LTR input; colons between Hebrew words keep RTL order — screen check on 234.
- en value for Report_Between and Report_FilterValueNotUnderstood differs from what shell wrote — change en too.
