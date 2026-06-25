# EMERGENCY / Пике — operator debrief log (2026-06-25)
> Operator dictation, recorded verbatim by coordinator-0624 for later разбор полёта + lessons. Append-only. Operator signals end with "я - все".

## [op 1]
Мы в состоянии пике — версия релиза полна багов в дэшбордах, а версия с отчётами, блокирующая её фиксы, в катастрофическом состоянии. Поэтому, до выравнивания курса и высоты, я ввожу чрезвычайное положение.

## [op 2]
Пункты чрезвычайного положения ты сформулируешь после окончания моей речи, дашь мне на ревью и запишешь в параграф A всех спецов и свой (role-skills §A). По завершении ЧП мы его снимем.

## [op 3]
Перед продолжением работ в режиме ЧП мы сделаем всем хендоф, включая твою (координаторскую) сессию.

## [op 4]
Спецы под хендоф: Shell, BI, DB, Backend, Devops, QA.
Перед хендофом координатор разложит им в инбоксы максимально эффективные инструкции по составлению INIT-промпта.
Затем оператор пройдётся по всем (`коорд: входящие`); каждый спец готовит хендоф (БЕЗ лишних вопросов; всё, что уже лежит в инбоксах — разбирается ПОСЛЕ инита) и выдаёт INIT-промпт.

## [op 5] — protocol shorthand (ЧП only)
On time of ЧП the coordination protocol gains shorthands:
- `.` (dot) = `коорд: входящие` (process inbox).
- `..` = "проверь результат / check the result" (NOT a protocol verb, but all specs know it).

## [op 6] — no-run-without-bless (ЧП rule for all specs)
Specs: to prevent UNSANCTIONED CC runs, a spec must NOT hand the operator a chat code-box with the CC run-prompt (`Выполни задачу из файла ...`) UNTIL it has received the coordinator's §4 BLESS. (Author the prompt → submit for §4 → only after bless, surface the run-command.)

## [op 7] — prod-data mirror for verification
Operator will bring a DB backup from 234 with PROD data. In it, the `RTSData_*` tables hold REAL prod data. ALL verification will be done on this real data.
For our "шарманка" to spin up correctly we must assume the CLIENT's prod shape — all BU, Agents, AgentGroups, Permission Groups, etc.
Our environment on THIS machine must be a MIRRORED, FROZEN copy of prod — but ONLY by DATA; the full MIGRATION package for the reports version = OUR migrated DB.
Operator's proposal: a ONE-TIME seed of our DB with the necessary data from the backup he'll bring.

## [op 8] — ЧП discipline for all specs
In ЧП mode: NO corner-cutting ("округление углов"); NO decisions made around the coordinator (every decision goes through coordinator); ANY small thing (ESPECIALLY in the visual) = critically RED (treat every detail as a blocker, not a minor).

## [op 9] — command + coordinator personally visual-verifies
You (coordinator) and I steer the situation to pull it out of the dive ASAP.
The coordinator PERSONALLY visually verifies EVERY closed gap (not just object-store / spec report — coordinator's own visual confirmation per closed gap).

## [op 10] — questions to operator
All questions and forks → to the operator STRICTLY ONE at a time, in order of importance, phrased as accessibly as possible (no jargon dumps).

