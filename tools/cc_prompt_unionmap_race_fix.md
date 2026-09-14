# CC TASK — `PR234-UNIONMAP-RACE-01`: второй проход по UserManager после до-загрузки маппинга

Автор: backend-0912, 2026-09-13, **rev 2** (см. DoD внизу — добавлено доказательство сборки датами
артефактов и маршрут Soma `§47`; сама правка не менялась, §4 пройден на rev 1).
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`.
Правка идёт в ОДИН общий батч, отдельного выката нет.

## НОРМЫ, КОТОРЫЕ ЭТОТ ПРОМПТ НЕСЁТ В СЕБЕ
(`CLAUDE-OVERSIZE-01`: `CLAUDE.md` не читается CC-сессией целиком — на подгрузку норм не полагаемся)
- **НЕ ПУШИТЬ.** Ветку не двигать. Коммит — отдельной командой, только по слову координатора.
- Из git только читающие команды (`show`, `hash-object`, `rev-parse`). НЕ `add`/`commit`/`checkout`/
  `stash`/`restore`/`status`/`diff` без отдельного указания.
- Правка ровно в одном файле и ровно в одном месте. Всё сверх — СТОП и доклад.
- Записи сверять байтами: хеш файла до и после печатать в файл вывода.
- Базу, 234 и 140 не трогать.

## ПРЕДМЕТ (измерено, не предположено)
`refreshUnions()` имеет **два** вызывающих во всём RTM — `UserManager.cs:669` и `:678`, оба внутри
`workgroupActivation()`. Членство агента в union вычисляется в момент прихода активации и больше
никогда: пара `supergroup -> usergroup`, легшая в `union.UserGroups` ПОЗЖЕ активации, агента уже не
догоняет. Замер: окно с 2 парами из 33 к приходу активаций -> `refreshUnions Add 36`; окно, где все
33 легли раньше -> `Add 423`; приходов в обоих 430, маппинг в БД один и тот же.

**Лечение того же класса в этом же методе уже есть.** `Engine.cs:752-758`, конец `LoadData`:
```csharp
// Force all existing UserManagers to pick up newly added column metrics.
// Without this, new metrics only appear after an agent's next workgroup event.
AsyncLogger.Info("LoadData: ForceRefreshMetrics for all UserManagers");
foreach (var userMng in _userManagerList.Values)
    userMng.ForceRefreshMetrics();
```
Цикл по всем `UserManager` стоит в нужном месте; не хватает пересчёта ЧЛЕНСТВА.

## ШАГ 0 — пины ДО правки (вывод: `tools\unionmap_race_fix.txt`, создать заново)
```
echo === STEP0 === > tools\unionmap_race_fix.txt
git rev-parse v3 >> tools\unionmap_race_fix.txt
git hash-object "RTM\RTM\Engine.cs" >> tools\unionmap_race_fix.txt
git rev-parse v3:RTM/RTM/Engine.cs >> tools\unionmap_race_fix.txt
findstr /N /C:"ForceRefreshMetrics for all UserManagers" "RTM\RTM\Engine.cs" >> tools\unionmap_race_fix.txt
findstr /C:"refreshUnions" "RTM\RTM\Engine.cs" >> tools\unionmap_race_fix.txt
```
Ожидание, названное ДО: `Engine.cs` диск == `v3:` == `ec1e0bec5061208718ca6cd519777a9bfb2e4d2a`;
`findstr` находит строку логгера; `refreshUnions` в `Engine.cs` **не встречается ни разу** (0 строк,
`findstr` вернёт errorlevel 1 — это ОЖИДАЕМО, не ошибка). Не сошлось — СТОП, не править.

## ШАГ 1 — правка, одно место
В `RTM\RTM\Engine.cs`, в конце `LoadData`, блок `foreach (var userMng in _userManagerList.Values)`.
Было:
```csharp
                AsyncLogger.Info("LoadData: ForceRefreshMetrics for all UserManagers");
                foreach (var userMng in _userManagerList.Values)
                {
                    userMng.ForceRefreshMetrics();
                }
```
Стало:
```csharp
                // Re-evaluate union membership as well: the mapping (union.UserGroups) may have been
                // loaded AFTER an agent's activation arrived, and refreshUnions() is otherwise called
                // only from workgroupActivation() - so such an agent would stay out of the union until
                // his next activation. Membership first, metrics second: refreshUnions() rebuilds
                // userUniuns, and ForceRefreshMetrics() then marks the manager changed.
                AsyncLogger.Info("LoadData: refreshUnions + ForceRefreshMetrics for all UserManagers");
                foreach (var userMng in _userManagerList.Values)
                {
                    userMng.refreshUnions();
                    userMng.ForceRefreshMetrics();
                }
```
**Ничего больше не менять.** `refreshUnions()` уже `public` (`UserManager.cs:564`) — сигнатуры не
трогать. Порядок вызовов важен и именно такой: членство -> метрики.

## ШАГ 2 — пины ПОСЛЕ правки
```
echo === STEP2 === >> tools\unionmap_race_fix.txt
git hash-object "RTM\RTM\Engine.cs" >> tools\unionmap_race_fix.txt
findstr /N /C:"userMng.refreshUnions();" "RTM\RTM\Engine.cs" >> tools\unionmap_race_fix.txt
```
Ожидание: хеш ИЗМЕНИЛСЯ относительно шага 0; `userMng.refreshUnions();` встречается **ровно один раз**.
Больше одного — СТОП и доклад.

## ШАГ 3 — сборка (см. DoD внизу: инструмент и доказательство)
```
echo === STEP3 BUILD === >> tools\unionmap_race_fix.txt
echo --- artifacts BEFORE --- >> tools\unionmap_race_fix.txt
dir "RTM\RTM\bin\Debug\net8.0\RTM.dll" >> tools\unionmap_race_fix.txt
dir "RTM\RTM\obj\Debug\net8.0\RTM.dll" >> tools\unionmap_race_fix.txt
dotnet build RTM\RTM\RTM.csproj -c Debug >> tools\unionmap_race_fix.txt 2>&1
echo --- artifacts AFTER --- >> tools\unionmap_race_fix.txt
dir "RTM\RTM\bin\Debug\net8.0\RTM.dll" >> tools\unionmap_race_fix.txt
dir "RTM\RTM\obj\Debug\net8.0\RTM.dll" >> tools\unionmap_race_fix.txt
```
Ожидание: `0 Error(s)` И сдвиг даты обоих артефактов с `2026-07-16 10:38`.
Число предупреждений печатаем, выводов из него не делаем.

## ШАГ 4 — доклад
В чат: хеш до, хеш после, число вхождений `userMng.refreshUnions();`, итог сборки И обе даты
артефактов (до/после).
Подтверждение, что коммита и пуша не было. Файл `tools\unionmap_race_fix.txt` не удалять.

## ПРЕДИКАТ ПРИЁМКИ — не зависит от трафика (для координатора, не для CC)
Живой замер «стало больше агентов» непригоден: он не различает «правка подействовала» и «в этом
запуске маппинг успел лечь первым» — ровно та гонка, которую чиним.
**Приёмка юнит-уровня, на двух телах файла:**
- Тест: `UserManager` с заданными `_workgroups` НЕ попадает в union, если пара легла в
  `union.UserGroups` ПОСЛЕ вызова `workgroupActivation`; затем `Engine.LoadData` (или прямой вызов
  того же цикла) — и он в union ПОПАДАЕТ.
- **Отрицательная половина обязательна:** на теле ИЗ ВЕТКИ (без правки) этот тест обязан УПАСТЬ.
  Не упал — тест не проверяет предмет, и зелёный на починенном теле ничего не значит.
- Порядок необратим: сперва красное на непочиненном, потом зелёное на починенном.
- Второй негативный контроль, чтобы правка не оказалась «добавляет всех подряд»: агент, чьи
  `_workgroups` НЕ покрывают ни одну пару, в union НЕ попадает и после `LoadData`.
**Замечание к объёму логов, называю сам:** `refreshUnions()` печатает `MISS` на каждую несовпавшую
пару (в последнем окне 12664 строк). Проход по всем `UserManager` на каждом `LoadData` этот объём
умножает. Поведения это не меняет; если координатор сочтёт объём проблемой — это отдельный предмет
(уровень логирования), а не повод менять правку.

## DoD — ПРОВЕРКА СБОРКИ, rev 2
> **Почему rev 2:** rev 1 не назвал, ЧЕМ доказывается сборка, и опирался на фразу прогона.
> Координатор снял своё же предупреждение «Soma недостижима» — маршрут документирован
> (`CLAUDE.md §47`), и вписывать «недостижима» значило бы тиражировать снятую ошибку.

**Порядок инструментов:**
1. Soma штатным маршрутом `§47`: вкладка хостового Chrome на `http://127.0.0.1:<PORT>/health`,
   затем same-origin `fetch('/<endpoint>')` с `Authorization: Bearer <token>`.
   Токен — в `tools/Soma/appsettings.json` (`Soma:Token`). **В вывод, в чат и в этот файл токен
   НЕ попадает.** Из bash-песочницы Soma не видна — это свойство песочницы, а не отсутствие Soma.
2. При отказе маршрута — прямой `dotnet build RTM\RTM\RTM.csproj -c Debug`.
   Нет `dotnet` — СТОП с выводом `dotnet --version`, обходных путей не искать.

**ДОКАЗАТЕЛЬСТВО — ДАТЫ АРТЕФАКТОВ, а не фраза о результате.**
Порог назван ДО прогона (снят с диска 2026-09-13):
```
RTM\RTM\bin\Debug\net8.0\RTM.dll      2026-07-16 10:38   335360 Б
RTM\RTM\obj\Debug\net8.0\RTM.dll      2026-07-16 10:38   335360 Б
```
Шаг сборки печатает `dir` этих двух файлов ДО и ПОСЛЕ:
```
dir "RTM\RTM\bin\Debug\net8.0\RTM.dll" >> <файл вывода>
dir "RTM\RTM\obj\Debug\net8.0\RTM.dll" >> <файл вывода>
```
**Если числа сборки зелёные, а дата НЕ сдвинулась с `2026-07-16 10:38` — это РАСХОЖДЕНИЕ.**
Докладывать как расхождение, а не примирять с зелёными числами и не объяснять. Ничего не пересобирать
повторно «чтобы сошлось».

**Если сессия заявляет «Task already completed in this session» — это НЕ результат.**
Задача считается выполненной только если пины шага 0 и шага 2 напечатаны В ФАЙЛ этим прогоном
и даты артефактов сдвинулись. Заявление без этих строк — СТОП и доклад.
