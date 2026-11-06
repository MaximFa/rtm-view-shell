# Report screen — date caption, inverted range, agent caveat (en / ru / he)
Author: coordinator-1104, 2026-11-05T05:34:35Z. Owner of the .resx edit: shell-0919b (v4, D:\Claude\Projects\RTM-design). Translation is not a screen check.

## Decisions
- Caption tone: neutral explanation, not a warning. «Data for …» chosen over «Shown for …» in ru/he: «Показано за» reads as UI jargon; «Данные за» / «נתונים עבור» is how the page already speaks about periods.
- Inverted range: a refusal the user sees instead of the update — says WHAT is wrong in the page's own terms (start/end date), no instruction verb. REJECTED «Неверный диапазон» / «טווח לא תקין»: does not say which date is wrong.
- Caveat key name proposed: `Report_CaveatStatusStartBucket` for code `status-start-bucket` (backend-1015, ReportCaveatCodes.StatusStartBucket). An unknown caveat code -> no caveat line + log, never the raw code on screen.

## Keys
| key | en | ru | he |
|---|---|---|---|
| Report_ShownForShift | Data for {0}, {1}–{2} | Данные за {0}, {1}–{2} | נתונים עבור {0}, {1}–{2} |
| Report_ShownForDate | Data for {0} | Данные за {0} | נתונים עבור {0} |
| Report_DateRangeInverted | The start date is later than the end date. | Начальная дата позже конечной. | תאריך ההתחלה מאוחר מתאריך הסיום. |
| Report_CaveatStatusStartBucket | Status time is counted in the half-hour in which the status started: at the edges of the window, a status that began before the start is not included, and one that began inside is counted in full. | Время статуса учитывается в том получасе, когда статус начался: на краях окна статус, начавшийся до начала, не учитывается, а начавшийся внутри — учитывается целиком. | זמן הסטטוס נספר בחצי השעה שבה הסטטוס התחיל: בקצוות החלון סטטוס שהתחיל לפני ההתחלה אינו נכלל, וסטטוס שהתחיל בתוכו נספר במלואו. |

## Where insertion breaks (named before insertion)
- {1}–{2} are HOURS. Format them as `HH:00` on the screen (09:00–18:00), not bare numbers: «9–18» next to a date reads as a day range. Same format in all three locales.
- {0} is the date: format with the page culture (dd/MM/yyyy in he-IL, as the date fields show), not ISO.
- In he the en dash between two Latin-digit times stays in order (digits are weak LTR runs inside RTL) — still a screen check on 234.
- English text was changed from shell's «Shown for …» to «Data for …» to match ru/he meaning; change the en value too.
