# ПЕРЕВОДЫ 82 КЛЮЧЕЙ `he-IL` — СДЕЛАНЫ КООРДИНАТОРОМ

> [со слов оператора: 2026-09-19, дословно] **«все переводы делаешь ты»**. Значит слова даю я,
> а вписывает их `backend-0912`: авторство термина моё, правка файла — его.
> Источник: список `backend-0912` `.coord/l10n_he_missing_terms.md`, 82 ключа без прецедента.

## РЕШЕНИЯ ПО ТЕРМИНАМ — принимаю вслух, потому что они задают язык всей функции

| понятие | выбрано | почему не иначе |
|---|---|---|
| Info Slot | **לוח מידע** (мн. `לוחות מידע`) | «слот» на иврите не читается; по сути это доска объявлений на экране. Отвергнуто `חלון מידע` — это «окно», а элемент не окно. |
| Ticker | **סרט נע** | принятый ивритский термин для бегущей строки. Транслитерация `טיקר` не употребима вне биржи. |
| Sequential (режим) | **ברצף** | противопоставлен `סרט נע`: сообщения идут по очереди, а не ползут. |
| Scroll | **גלילה** | стандарт. Направление `כיוון גלילה`, скорость `מהירות גלילה`, поведение `אופן גלילה`. |
| Priority | **עדיפות**, High `גבוהה`, Normal `רגילה` | согласовано в роде с `עדיפות`. |
| Trash | **סל מיחזור** | `אשפה` — мусор как вещество; здесь корзина, из которой восстанавливают. |
| Dashboard | **מסך** | НЕ моё решение, а уже зафиксированное в словаре (`Screens_New`, `Screens_Edit`). Соблюдаю. |
| Widget | **ווידג'ט** | моё решение от 19.09 по находке `backend-0912`. |
| Away (сост. сотрудника) | **נעדר** | `לא זמין` заняло бы место «Unavailable», а это разные состояния. |

## InfoSlots — 41

| ключ | английский | иврит |
|---|---|---|
| `InfoSlot_BottomToTop` | Bottom → Top | מלמטה למעלה |
| `InfoSlot_NoMessages` | No messages to display. | אין הודעות להצגה. |
| `InfoSlot_PriorityHighBackground` | High Priority Background | רקע עדיפות גבוהה |
| `InfoSlot_PriorityHighText` | High Priority Text | טקסט עדיפות גבוהה |
| `InfoSlot_ScrollBehaviour` | Scroll Behaviour | אופן גלילה |
| `InfoSlot_ScrollDirection` | Scroll Direction | כיוון גלילה |
| `InfoSlot_ScrollSpeed` | Scroll Speed | מהירות גלילה |
| `InfoSlot_SecondsPerMessage` | Seconds per message | שניות להודעה |
| `InfoSlot_Sequential` | Sequential | ברצף |
| `InfoSlot_ShowAuthor` | Show Author | הצג מחבר |
| `InfoSlot_ShowTimestamp` | Show Timestamp | הצג חותמת זמן |
| `InfoSlot_SpeedFast` | Fast | מהירה |
| `InfoSlot_SpeedMedium` | Medium | בינונית |
| `InfoSlot_SpeedSlow` | Slow | איטית |
| `InfoSlot_Ticker` | Ticker | סרט נע |
| `InfoSlot_TopToBottom` | Top → Bottom | מלמעלה למטה |
| `InfoSlots_AccessNote` | Select permission groups whose members can write messages to this Info Slot. | בחר קבוצות הרשאות שחבריהן רשאים לכתוב הודעות ללוח מידע זה. |
| `InfoSlots_ActiveMessages` | Active Messages | הודעות פעילות |
| `InfoSlots_AddMessage` | Add Message | הוסף הודעה |
| `InfoSlots_AddMessageBtn` | Add Message → | הוסף הודעה |
| `InfoSlots_DeleteSlot` | Delete Info Slot | מחק לוח מידע |
| `InfoSlots_EditSlot` | Edit Info Slot | ערוך לוח מידע |
| `InfoSlots_ExpiresAt` | Expires At | תפוגה |
| `InfoSlots_ManageMessages` | Manage Messages | נהל הודעות |
| `InfoSlots_Messages` | messages | הודעות |
| `InfoSlots_ModeSequential` | Sequential | ברצף |
| `InfoSlots_ModeTicker` | Ticker | סרט נע |
| `InfoSlots_MsgContent` | Message Content | תוכן ההודעה |
| `InfoSlots_NeverExpires` | Never expires | ללא תפוגה |
| `InfoSlots_NewSlot` | + New Info Slot | + לוח מידע חדש |
| `InfoSlots_NoSlots` | No info slots configured. | לא הוגדרו לוחות מידע. |
| `InfoSlots_NoSlotsViewer` | No info slots available. | אין לוחות מידע זמינים. |
| `InfoSlots_PgCount` | PGs | קבוצות הרשאות |
| `InfoSlots_PlacedOn` | Placed on | ממוקם ב |
| `InfoSlots_Priority` | Priority | עדיפות |
| `InfoSlots_PriorityHigh` | High | גבוהה |
| `InfoSlots_PriorityNormal` | Normal | רגילה |
| `InfoSlots_SecondsHelp` | Time to display each message (5-120 seconds) | משך הצגת כל הודעה (5-120 שניות) |
| `InfoSlots_SecondsPerMessage` | Seconds per Message | שניות להודעה |
| `InfoSlots_Title` | Info Slots | לוחות מידע |
| `InfoSlots_ViewerTitle` | Info Slots | לוחות מידע |

⚠ `InfoSlots_AddMessageBtn` — стрелку `→` НЕ переношу: в RTL она указывала бы назад. Если кнопке
нужен значок направления, его ставит разметка с логическим свойством, а не текст перевода.

## Экраны — 9

| ключ | английский | иврит |
|---|---|---|
| `Screens_Connected` | Blazor Server · SignalR connected | Blazor Server · SignalR מחובר |
| `Screens_DaysRemaining` | Days remaining | ימים שנותרו |
| `Screens_ExitFullscreen` | Exit Fullscreen | יציאה ממסך מלא |
| `Screens_FullScreen` | Full Screen | מסך מלא |
| `Screens_Publish` | Publish | פרסם |
| `Screens_Trash` | Trash | סל מיחזור |
| `Screens_TrashEmpty` | Trash is empty | סל המיחזור ריק |
| `Screens_TrashInfo` | Deleted dashboards are permanently removed after {0} days. | מסכים שנמחקו יוסרו לצמיתות לאחר {0} ימים. |
| `Screens_Unpublish` | Unpublish | בטל פרסום |

⚠ `Screens_Connected` — `Blazor Server` и `SignalR` это ИМЕНА ПРОДУКТОВ, они не переводятся;
переведено только слово «connected».
⚠ `Screens_TrashInfo` — **`{0}` обязан остаться ровно таким**: это подстановка числа дней.

## Виджеты — 25

| ключ | английский | иврит |
|---|---|---|
| `Widget_AvgWait` | Avg Wait | המתנה ממוצעת |
| `Widget_Away` | Away | נעדר |
| `Widget_ComingSoon` | Available in next version | יהיה זמין בגרסה הבאה |
| `Widget_DayTrend_AgentMetricsHelp` | Enable agent status metrics. Shown as dashed lines. | אפשר מדדי סטטוס סוכנים. מוצגים כקווים מקווקווים. |
| `Widget_DayTrend_AgentMetricsNote` | If no agent metrics are enabled, the agent status query is skipped for better performance. | אם לא הופעלו מדדי סוכנים, שאילתת סטטוס הסוכנים מדולגת לשיפור הביצועים. |
| `Widget_DayTrend_AgentNote` | Agent metrics shown as dashed lines | מדדי סוכנים מוצגים כקווים מקווקווים |
| `Widget_DayTrend_CallMetricsHelp` | Enable metrics to display in the chart. Drag to reorder. | אפשר מדדים להצגה בתרשים. גרור לשינוי הסדר. |
| `Widget_DayTrend_Manual` | Manual only | ידני בלבד |
| `Widget_DayTrend_Refresh1` | Every 1 minute | כל דקה |
| `Widget_DayTrend_RefreshManual` | Manual only | ידני בלבד |
| `Widget_DeleteRtsWarning` | This will also delete the associated grid configuration. | פעולה זו תמחק גם את תצורת הטבלה המשויכת. |
| `Widget_EventTicker` | Event Ticker | סרט אירועים |
| `Widget_LastUpdated` | Last updated | עודכן לאחרונה |
| `Widget_NoDataToday` | No interactions recorded today | לא נרשמו אינטראקציות היום |
| `Widget_SlaGauge` | SLA Gauge | מד SLA |
| `Widgets_DragHere` | Drag widgets here to build your dashboard | גרור ווידג'טים לכאן כדי לבנות את המסך |
| `Widgets_FontSize_Large` | Large | גדול |
| `Widgets_FontSize_Normal` | Normal | רגיל |
| `Widgets_FontSize_Small` | Small | קטן |
| `Widgets_FontSize_XLarge` | Extra Large | גדול מאוד |
| `Widgets_FontSize_XXLarge` | Huge | ענק |
| `Widgets_From` | From | מ- |
| `Widgets_NoWidgetsPlaced` | No widgets placed on this dashboard | לא הוצבו ווידג'טים במסך זה |
| `Widgets_ThresholdCritical` | Critical | קריטי |
| `Widgets_To` | To | עד |

⚠ `Widgets_FontSize_*` в мужском роде — они определяют `גופן` (шрифт, м.р.), а НЕ `עדיפות` (ж.р.).
Это не описка и не расхождение с блоком InfoSlots: род ведёт определяемое слово.
⚠ `Widget_SlaGauge` — `SLA` остаётся латиницей: аббревиатура уже так стоит в словаре
(`TenantSettings_WfmSlThresholdSec` не переведён вовсе).
⚠ `Widgets_From` / `Widgets_To` — пара границ диапазона. Если в разметке они стоят по краям одного
поля, при RTL их порядок меняет разметка, а не перевод.

## Остальное — 7

| ключ | английский | иврит |
|---|---|---|
| `Common_Updated` | Updated | עודכן |
| `Common_UpdatedBy` | Updated By | עודכן על ידי |
| `Login_OrCredentials` | or sign in with credentials | או התחברות עם שם משתמש וסיסמה |
| `Nav_InfoSlots` | Info Slots | לוחות מידע |
| `Nav_InfoSlotsAdmin` | Info Slots | לוחות מידע |
| `PG_InfoSlotsNote` | Select info slots this permission group can write messages to. | בחר לוחות מידע שקבוצת הרשאות זו רשאית לכתוב אליהם הודעות. |
| `PG_TabInfoSlots` | Info Slots | לוחות מידע |

⚠ `Nav_InfoSlots` и `Nav_InfoSlotsAdmin` несут ОДИН И ТОТ ЖЕ текст на двух разных пунктах меню —
пользовательском и административном. Перевод одинаковый, потому что и оригинал одинаковый.
**Это возможный дефект ИСХОДНИКА, а не перевода:** два разных пункта, неотличимых по названию.
Заведено отдельным наблюдением, правку не делаю.

## ЧТО Я ЗДЕСЬ НЕ СДЕЛАЛ И ЧЕГО НЕ УТВЕРЖДАЮ

- **Это перевод, а не проверка на живом экране.** Длина ивритской строки отличается от английской;
  где текст стоит в узкой кнопке или в колонке таблицы, он может не поместиться. Проверяется только
  глазами на 234 после выката, в Chrome.
- **Род и число я выводил из смысла ключа, а не видел в разметке.** Где я ошибся родом, это видно
  только на экране; исправляется одной строкой.
- `ru-RU` здесь НЕТ. Русский делаю отдельной пачкой, чтобы не смешивать два языка в одной сверке.

— `coordinator-0917`, 2026-09-19
