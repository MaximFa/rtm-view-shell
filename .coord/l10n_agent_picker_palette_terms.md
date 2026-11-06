# Agent picker + palette descriptions (en / ru / he)
Author: coordinator-1104, 2026-11-06T14:58:46Z. Owner of the .resx edit: shell-0919b (v4, D:\Claude\Projects\RTM-design). Translation is not a screen check.

## Decisions
- «agent»: ru **Оператор/Операторы** (Report_Agent = «Оператор»), he **נציג/נציגים** (Report_Agent, screen column). REJECTED ru «Агенты» — a second word for the same thing on the same screen.
- «business unit»: ru **бизнес-юниты** (WidgetCfg_BusinessUnits, same dialog), he **יחידות עסקיות**. Note: ru resources ALSO use «подразделение» elsewhere (5 values) — an existing split, not fixed here; this dialog follows its own label.
- «in scope»: ru «в вашем доступе», he «שבהרשאתך». REJECTED he «הזמינים» — «זמין» is the AVAILABLE status column on the same report.
- «Showing {0} of {1}»: he follows the pager «מציג … מתוך …» (Report_Showing «מציג», «מתוך»).
- AgentsClear is NOT «clear»: it returns to «all agents». ru «Показать всех операторов», he «הצג את כל הנציגים».

## Agent picker keys
| key | en | ru | he |
|---|---|---|---|
| ReportWidget_Agents | Agents | Операторы | נציגים |
| ReportWidget_AgentsAll | All agents in scope | Все операторы в вашем доступе | כל הנציגים שבהרשאתך |
| ReportWidget_AgentsChosen | {0} chosen | Выбрано: {0} | נבחרו: {0} |
| ReportWidget_AgentsPickBuFirst | Choose the business units first. | Сначала выберите бизнес-юниты. | בחרו תחילה יחידות עסקיות. |
| ReportWidget_AgentsTruncated | Showing {0} of {1}; narrow the business units to see the rest. | Показано {0} из {1}; сузьте выбор бизнес-юнитов, чтобы увидеть остальных. | מציג {0} מתוך {1}; צמצמו את היחידות העסקיות כדי לראות את השאר. |
| ReportWidget_AgentsClear | Show all agents | Показать всех операторов | הצג את כל הנציגים |

## Palette descriptions (8 types; key names — shell's)
| type | en | ru | he |
|---|---|---|---|
| QueueInterval | Calls and service levels by time interval | Звонки и уровень обслуживания по интервалам | שיחות ורמת שירות לפי מרווחי זמן |
| QueueWaitTime | Wait time distribution analysis | Распределение времени ожидания | ניתוח התפלגות זמני המתנה |
| AgentMonthly | Monthly agent performance summary | Месячная сводка по операторам | סיכום ביצועי נציגים חודשי |
| AgentShiftDetail | Detailed shift-by-shift agent metrics | Показатели операторов по сменам | מדדי נציגים מפורטים לפי משמרת |
| Distribution | Call distribution charts | Диаграммы распределения звонков | תרשימי התפלגות שיחות |
| EndOfShiftQueues | One row per queue for the shift window | Одна строка на очередь за окно смены | שורה אחת לכל תור בחלון המשמרת |
| EndOfShiftAgents | One row per agent for the shift window | Одна строка на оператора за окно смены | שורה אחת לכל נציג בחלון המשמרת |
| AgentPerformance | Agent figures for the period: one row per agent, or one per agent per date | Показатели операторов за период: строка на оператора или на оператора и дату | נתוני נציגים לתקופה: שורה לכל נציג, או לכל נציג לפי תאריך |

## Where insertion breaks
- {0}/{1} are numbers: in he, digits keep LTR order inside RTL — still a screen check on 234.
- «Выбрано: {0}» / «נבחרו: {0}» — the count after the colon, so no plural agreement is needed (en «chosen» has none either).
