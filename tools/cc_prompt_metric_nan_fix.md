# CC TASK — `PR234-METRIC-NAN-01`: делить только при ненулевом знаменателе (решение оператора: `0%`)

Автор: backend-0912, 2026-09-13, **rev 2** (см. DoD внизу — добавлено доказательство сборки датами
артефактов и маршрут Soma `§47`; сама правка не менялась, §4 пройден на rev 1).
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`. Идёт в ТОТ ЖЕ батч, что `PR234-UNIONMAP-RACE-01`.

## НОРМЫ, КОТОРЫЕ ЭТОТ ПРОМПТ НЕСЁТ В СЕБЕ
(`CLAUDE-OVERSIZE-01`: на подгрузку `CLAUDE.md` не полагаемся)
- **НЕ ПУШИТЬ.** Ветку не двигать. Коммит — только по слову координатора, отдельной командой.
- Из git только читающие команды. Правка ровно в одном файле, ровно в двух названных методах.
- Хеш файла до и после — в файл вывода. Базу, 234 и 140 не трогать.

## ПРЕДМЕТ (измерено)
`v3:RTM/RTM/Union.cs` (blob `02f6f18a8c81f4b652ac1155cfd61092433bfae2`):
`getUsersInStatusDurationPercent` (:968) и `getUsersInStatusGroupDurationPercent` (:983) считают
`dCalc = stsDur.TotalSeconds / loginDur.TotalSeconds`, где `loginDur` — сумма длительностей со
`StatusId != "SIGNOFF"`. Единственный охранник — `Users.Count() > 0`. Все агенты в SIGNOFF ->
`loginDur = 0`, `stsDur = 0`, `0.0/0.0` = `NaN` (double, без исключения) -> `NaN.ToString("#0.##%")`
= `"NaN"` -> Shell рисует прочерк (`QueueGridWidget.razor:1372`).
**Почему дефект, а не задумка:** соседи того же семейства охранника ИМЕЮТ — `:873
getUsersInStatusPercent` и `:890 getUsersInStatusGroupPercent` проверяют `numSignon1 > 0` перед
делением. Правка не вводит новое поведение, а доводит два duration-варианта до нормы файла.
Сеть безопасности Shell (`NaN` -> `-`) НЕ трогаем: её снятие заменило бы видимый отказ видимой ложью.

## ШАГ 0 — пины ДО правки (вывод: `tools\metric_nan_fix.txt`, создать заново)
```
echo === STEP0 === > tools\metric_nan_fix.txt
git rev-parse v3 >> tools\metric_nan_fix.txt
git hash-object "RTM\RTM\Union.cs" >> tools\metric_nan_fix.txt
git rev-parse v3:RTM/RTM/Union.cs >> tools\metric_nan_fix.txt
findstr /N /C:"dCalc = stsDur.TotalSeconds / loginDur.TotalSeconds" "RTM\RTM\Union.cs" >> tools\metric_nan_fix.txt
```
Ожидание, названное ДО: диск == `v3:` == `02f6f18a8c81f4b652ac1155cfd61092433bfae2`;
`findstr` находит **ровно две** строки (в `getUsersInStatusDurationPercent` и
`getUsersInStatusGroupDurationPercent`). Не две — СТОП, не править: значит место не то, что описано.

## ШАГ 1 — правка, два места, обе одинаковые
В `RTM\RTM\Union.cs`, в обоих методах строку
```csharp
                dCalc = stsDur.TotalSeconds / loginDur.TotalSeconds;
```
заменить на
```csharp
                // Divide only when the denominator is non-zero: with every agent in SIGNOFF both
                // sums are 0 and 0.0/0.0 yields NaN, which renders as a dash instead of a value.
                // Same guard as getUsersInStatusPercent / getUsersInStatusGroupPercent; dCalc stays 0 -> "0%".
                if (loginDur.TotalSeconds > 0)
                {
                    dCalc = stsDur.TotalSeconds / loginDur.TotalSeconds;
                }
```
Больше ничего не менять: `Users.Count() > 0` оставить, `return dCalc.ToString(metric.Format);`
не трогать, форматы не трогать, другие методы не трогать.

## ШАГ 2 — пины ПОСЛЕ правки
```
echo === STEP2 === >> tools\metric_nan_fix.txt
git hash-object "RTM\RTM\Union.cs" >> tools\metric_nan_fix.txt
findstr /N /C:"if (loginDur.TotalSeconds > 0)" "RTM\RTM\Union.cs" >> tools\metric_nan_fix.txt
findstr /N /C:"dCalc = stsDur.TotalSeconds / loginDur.TotalSeconds" "RTM\RTM\Union.cs" >> tools\metric_nan_fix.txt
```
Ожидание: хеш изменился; `if (loginDur.TotalSeconds > 0)` — **ровно два** вхождения;
делений по-прежнему **ровно два** (их не должно стать больше или меньше — деление перенесено внутрь
охранника, а не продублировано). Любое другое число — СТОП и доклад.

## ШАГ 3 — сборка (см. DoD внизу: инструмент и доказательство)
```
echo === STEP3 BUILD === >> tools\metric_nan_fix.txt
echo --- artifacts BEFORE --- >> tools\metric_nan_fix.txt
dir "RTM\RTM\bin\Debug\net8.0\RTM.dll" >> tools\metric_nan_fix.txt
dir "RTM\RTM\obj\Debug\net8.0\RTM.dll" >> tools\metric_nan_fix.txt
dotnet build RTM\RTM\RTM.csproj -c Debug >> tools\metric_nan_fix.txt 2>&1
echo --- artifacts AFTER --- >> tools\metric_nan_fix.txt
dir "RTM\RTM\bin\Debug\net8.0\RTM.dll" >> tools\metric_nan_fix.txt
dir "RTM\RTM\obj\Debug\net8.0\RTM.dll" >> tools\metric_nan_fix.txt
```
Ожидание: `0 Error(s)` И сдвиг даты обоих артефактов с `2026-07-16 10:38`.

## ШАГ 4 — доклад
В чат: хеш до, хеш после, два числа из шага 2, итог сборки, обе даты артефактов (до/после),
подтверждение об отсутствии коммита и пуша. Файл `tools\metric_nan_fix.txt` не удалять.

## ПРЕДИКАТ ПРИЁМКИ (для координатора, не для CC)
- **Положительная половина:** `loginDur = 0` (все агенты в SIGNOFF) -> метод возвращает `0%`,
  счётчики остаются `0`, `NaN` в payload отсутствует.
- **ОТРИЦАТЕЛЬНАЯ ПОЛОВИНА, обязательна:** при НЕнулевом `loginDur` процент считается ровно как
  раньше — то есть тест с `stsDur > 0, loginDur > 0` даёт то же число на обоих телах файла.
  Без неё правка может лечить прочерк, ломая рабочий случай, и мы этого не увидим.
- Юнит-уровень, живой базы не требует. На теле ИЗ ВЕТКИ тест на первую половину обязан УПАСТЬ
  (вернуть `NaN`) — иначе он не проверяет предмет.
- **Не измерено и не выдаётся за измеренное:** привязка конкретных колонок экрана
  `01a08063-…` к этим двум функциям — это `[вывод]` по совпадению displayName с каталогом
  (затронутых метрик в каталоге 6). Проверяется чтением конфигурации экрана, и к правке кода
  отношения не имеет.

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
