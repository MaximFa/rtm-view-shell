# CC TASK — V4-RTM-DIVZERO-EMPTY: при нулевом знаменателе движок отдаёт ПУСТО

> Автор: `backend-0919`. §4 `coordinator-0924`: развилка снята 01:19:10Z (вариант «а», `string.Empty`),
> предмет подтверждён числом 01:37:42Z — **24 живых расчёта**.
> Ветка: **v4 только**. Рабочий каталог прогона: `D:\Claude\Projects\RTM-design`.
> **Сам этот промпт коммитится в v4, из `RTM-design\tools\`** — прецедент `fbe1531 docs(v4): CC prompt…`.
> Копия в `RTM View Shell\tools\` (рабочий каталог v3) остаётся НЕОТСЛЕЖИВАЕМОЙ и в v3 не коммитится:
> оператор сказал «НЕ ТРОГАЕМ ВЕТКУ V3», и гейт §5 `v3 sha до == после` это же и проверяет.
> `v3` НЕ ТРОГАТЬ (слово оператора). Замер — в `D:\Claude\Projects\RTM View Shell\.coord\measure\rtm-divzero-0924\`, НЕ в коммит.
> Основание: [со слов оператора 2026-09-24] «В любом случае деления на ноль — показываем пусто…
> особенно если речь идет о начале смены агента и отвеченных у него ровно ноль».

## §0.6a INTEGRITY
Проверка по object store, не по докладу инструмента. Счёт строк доказательством не является.
Каждое число — парой «до/после». **Edit-инструмент ЗАПРЕЩЁН**: чтение файла, изменение в памяти,
запись целиком + `os.fsync`. После коммита — блоб == `git hash-object` того же файла на диске, предъявить.

### §0.6b ФОРМА ОСТАНОВКИ — ПРЕДИКАТ, А НЕ ПРОЗА
```bash
chk(){ if [ "$2" = "$3" ]; then echo "OK   $1: exp=$2 got=$3"; else echo "STOP $1: exp=$2 got=$3"; fi; }
```
**Хоть одно `STOP` — правка и коммит НЕ делаются, `status: failed`, фактическое число в `RESULT`.
Переформулировать критерий под факт ЗАПРЕЩЕНО.** В `RESULT` обязательна строка
`STOP-предикат: <N> критериев, STOP=<M>`; нет строки — единица не сдана.
Форма проверена мишенью `tools/cc_prompt_selftest_stop.md`: на красном прогон останавливается.

## §S. Multi-session sync — MANDATORY
binding: `V4-RTM-DIVZERO-EMPTY` · slug: `backend-0919`
Claims: `RTM/RTM/Engine.cs` · `RTM/RTM/UserManager.cs` · `RTM/RTM/Union.cs` · `tests/RTM.Engine.Tests/**` — и НИЧЕГО больше.
### S1. Push barrier
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1; fi
```
### S2. commit.lock вокруг `git add`/`git commit` — форма `tools/cc_prompt_sync_block.md`.
### S3. После коммита: `bash tools/cc_post_commit.sh backend-0919 $(git log -1 --format=%h)`, затем `sync`.
### S4. НЕ `git push` (§37).

## §B. БИНДИНГ — ШИНА ОДНА, ПУТЬ АБСОЛЮТНЫЙ
**Писать ТОЛЬКО в `D:\Claude\Projects\RTM View Shell\.coord\cc\backend.md`.**
НЕ в `RTM-design\.coord\cc\` — прогоны shell четырежды подряд писали во вторую шину, отчитываясь
правильным путём. Python + `os.fsync`, `newline="\n"`, запись заканчивается переводом строки.
Метку времени снять `date -u`; форма «01:4xZ» с иксом — подделка.
В `RESULT` — строка `запись в шине: есть, D:\Claude\Projects\RTM View Shell\.coord\cc\backend.md`.
⚠ Эту строку координатор проверяет своим `grep`; твой отчёт о ней не засчитывается.
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_v4_divzero_empty.md | status: open
### DIRECTIVE: при нулевом знаменателе 24 живых расчёта метрик отдают string.Empty вместо "0"/"0%"/"00:00:00".
Claim: RTM/RTM/{Engine,UserManager,Union}.cs + tests. gate: ветка v4; v3 sha до==после;
знаменатель>0 не меняется ни в одном символе; .coord/ и .claude/ — 0 путей в коммите.
```

## 1. ЗАМЕР «ДО» — через предикат §0.6b
```bash
chk "ветка" "v4" "$(git rev-parse --abbrev-ref HEAD)"
V3_BEFORE="$(git rev-parse v3)"; echo "v3 до: $V3_BEFORE"
for F in RTM/RTM/Engine.cs RTM/RTM/UserManager.cs RTM/RTM/Union.cs; do
  echo -n "блоб ДО $F: "; git rev-parse v4:"$F"
done
chk "САМОПРОВЕРКА прибора" "v4" "нет-такой-ветки"
```
Последняя строка ОБЯЗАНА напечатать `STOP` — отрицательная половина прибора; объявить отдельно:
`самопроверка: STOP получен`. Прибор, не умеющий вернуть красное, проверкой не является.

## 2. ⛔ ГЕЙТ — ДО правки
```bash
chk "мёртвая MessagesPercentFunction1 на месте" "1" "$(git show v4:RTM/RTM/Engine.cs | grep -c 'MessagesPercentFunction1')"
chk "Engine.cs:927 &nbsp; на месте"            "3" "$(git show v4:RTM/RTM/Engine.cs | grep -c 'nbsp')"
chk "UserManager &nbsp; на месте"             "19" "$(git show v4:RTM/RTM/UserManager.cs | grep -c 'nbsp')"
chk "string.Empty ещё не введён в Union"       "0" "$(git show v4:RTM/RTM/Union.cs | grep -c 'return string.Empty')"
```
Не сошлось — **СТОП**: файл не тот, что размечен таблицей ожиданий.

## 3. ПРАВКА — 24 места, пять форм. Место НЕ выбирать самому, форму НЕ изобретать
Общее правило: **меняется ТОЛЬКО то, что возвращается, когда знаменатель равен нулю.
Ветка «знаменатель > 0» не меняется ни в одном символе, включая строку формата.**

### ⚠ ОТДЕЛЬНАЯ СТРОКА ОЖИДАНИЯ: внешнее условие ложно -> тоже ПУСТО
Формы A, B и C возвращают дефолт не только при нулевом знаменателе, но и когда не выполнено
ВНЕШНЕЕ условие — `if (applicAny)` (Engine.cs :3099 и соседи), `if (Users.Count() > 0)` (Union.cs),
`if (isLoggedId)` (UserManager.cs). Сегодня в этих случаях уходит «0» / «0%» / «00:00:00»;
после правки уйдёт пусто.
**Это ожидаемое расширение, а не побочный эффект:** по правилу оператора «нет данных по метрике —
показываем пусто» отсутствие применимых данных — то же «нечем», что и нулевой знаменатель.
Принято `coordinator-0924` 2026-09-25T01:47:39Z, оператору несёт координатор фактом.
В приёмке (§5) эта строка печатается ОТДЕЛЬНО: `внешнее условие ложно -> пусто: <да|нет>` по каждой
из форм A, B, C. Выяснить это на приёмке вместо объявления заранее — считается дефектом единицы.
В Engine.cs расчёты живут внутри verbatim-строк (`@"..."`), где кавычки удвоены: `""00:00:00""`.
`string.Empty` пишется БЕЗ кавычек и потому в удвоении не участвует.

### Форма A — 8 мест: `double dCalc = 0;` + `return dCalc.ToString(<формат>)`
```
Engine.cs :3097-3113 AnsweredPercent        · :3114-3131 AbandonedPercent
Engine.cs :3210-3234 MessagesPercent        · :3235-3260 MessagesInteractionsPercent
Union.cs  :873-889  getUsersInStatusPercent · :890-907  getUsersInStatusGroupPercent
Union.cs  :968-988  getUsersInStatusDurationPercent · :989-1009 getUsersInStatusGroupDurationPercent
```
Правка ровно в три шага, без иных изменений:
1. рядом с объявлением `double dCalc… = 0;` добавить `bool hasValue = false;`
2. в той же строке, где присваивается `dCalc… = …;` ВНУТРИ ветки ненулевого знаменателя,
   следующей строкой добавить `hasValue = true;`
3. `return dCalc….ToString(<формат>);` заменить на
   `return hasValue ? dCalc….ToString(<формат>) : string.Empty;`
Имя переменной брать из файла (`dCalc`, `dCalc1`, `dCalc2`), не переименовывать.

### Форма B — 7 мест: дефолт `"00:00:00"` в переменной
```
Engine.cs :2840-2856 TalkDurationAvg (user) · :3426-3443 WaitDurationAvg · :3463-3479 TalkDurationAvg
Union.cs  :908-936  getUsersInStatusDurationAvg · :937-967 getUsersInStatusGroupDurationAvg
UserManager.cs :1327-1339 TotalStatusDurationAvg · :1340-1352 TotalStatusGroupDurationAvg
```
Заменить ТОЛЬКО инициализацию: `= ""00:00:00"";` -> `= string.Empty;` (в UserManager/Union: `= "00:00:00";` -> `= string.Empty;`).
Присваивание внутри ветки ненулевого знаменателя не трогать.

### Форма C — 5 мест: ранний `return "00:00:00";` при пустом наборе
```
Engine.cs :2874-2908 MessagesAvgFirstResponseTime (user) · :2909-2977 MessagesAvgResponseTime (user)
Engine.cs :3322-3360 MessagesAvgFirstResponseTime · :3361-3425 MessagesAvgResponseTime
Union.cs  :650-712  AvgResponseTimeMetric
```
Заменить ТОЛЬКО возвращаемое значение раннего выхода: `return ""00:00:00"";` -> `return string.Empty;`
(в Union: `return "00:00:00";` -> `return string.Empty;`). Само условие (`!responseTimes.Any()` /
`responseTimes.Count == 0`) не трогать.

### Форма D — 2 места: `return 0.ToString(format);` на пороге
```
Union.cs :475-513 CalculateCPH (порог `totalHours < 0.001`) · UserManager.cs :994-1030 CalculateCPH (тот же порог)
```
`return 0.ToString(format);` -> `return string.Empty;`. Порог и его значение `0.001` не трогать.

### Форма E — 2 места, `switch (metric.Function)` в UserManager.cs
**E1. `case "TotalStatusPercent"` :1272-1283 — ЕДИНСТВЕННОЕ место, где защиты нет вовсе.**
Сейчас: `val = "0";` затем `dCalc1 = (double)statusGrpDur1 / (double)loginDur1;` без проверки знаменателя.
Стало: `val = string.Empty;`, а деление обернуть ТАК ЖЕ, как в соседнем `case "TotalStatusGroupPercent"`:
```csharp
val = string.Empty;
if (isLoggedId)
{
    long loginDur1 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
    if (loginDur1 > 0)
    {
        long statusGrpDur1 = _TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter).Sum(r => r.Dur.Ticks);
        double dCalc1 = (double)statusGrpDur1 / (double)loginDur1;
        if (!double.IsNaN(dCalc1) && !double.IsInfinity(dCalc1))
        {
            var fmt1 = string.IsNullOrEmpty(metric.Format) ? "##0.0%" : metric.Format;
            val = dCalc1.ToString(fmt1);
        }
    }
}
break;
```
Зажим `[0,1]` соседа сюда НЕ переносить: он меняет значения, а не поведение при нуле.
**E2. `case "TotalStatusGroupPercent"` :1284-1316** — защита уже есть; заменить ТОЛЬКО `val = "0";` на
`val = string.Empty;`. Внутренности не трогать.

### ⛔ ЧЕГО НЕ ДЕЛАТЬ В ПРАВКЕ
- `Engine.cs :3196-3209 MessagesPercentFunction1` — мёртвый код (объявлена, в `TryAdd` не передана). **НЕ трогать, не оживлять.** Назвать в NOTED.
- `&nbsp;` — 3 вхождения в Engine.cs, 19 в UserManager.cs — **не трогать ни одно**, включая `Engine.cs:927` (подмена при отказе разбора даты).
- Счётчики (`AnsweredCount`, `NumWaitings`, `InteractionsCount`, `MessagesCount`, …) — настоящий ноль, не «нечем». **Не трогать.**
- Состояние агента и его группы, `AgentStateDistribution`, `UsersInStatusGroupCount_*` — **вне предмета** (поправка координатора 18:38:52Z). Если какой-то из 24 окажется частью выдачи самого состояния — **СТОП и вопрос координатору**.
- `Engine.cs :3062` и `:3522` — там `""dd/MM/yyyy HH:mm:ss""`, деления НЕТ. **Не трогать.**
- Ни одного `.razor`, ни одного файла в `src/`. Экран правит `shell` (`V4-FIX-TEXT-THRESHOLD`).
- `§48` (контракт адаптер <-> движок) не задевается. Если задевается — **СТОП**.

## 4. ТЕСТЫ — `tests/RTM.Engine.Tests/`
Проект в v4 есть. На КАЖДЫЙ изменённый расчёт — два случая: знаменатель 0 и знаменатель > 0.
- **Достижимые напрямую** (обычный код): `Union.cs` 8 методов, `UserManager.cs` 5 (4 case + CalculateCPH) — тесты обычные.
- **Недостижимые** (11 строк-функций Engine.cs компилируются в рантайме через `CompileAndSetMetricFunction`):
  доказывать **прогоном самой строки-функции через тот же компилятор, что использует движок**.
  Тест обязан брать ТЕКСТ из `MetricFunctionList`/`MetricUserFunctionList` (то, что реально ушло в
  `TryAdd`), подставить `METRIC_PARAMETER`/`METRIC_FORMAT`/`METRIC_DIRECTION` как движок, скомпилировать
  и выполнить на двух наборах. **Пересказ текста в тесте не годится: проверяется тот же объект,
  который исполняет движок.** Если компилятор из теста недостижим — **СТОП, доложить, не подменять пересказом.**
В `RESULT` — число случаев: `тестов всего <N>, из них через компилятор <M>`, и прогон с числами
(`dotnet test` — passed/failed/skipped).

## 5. ПРИЁМКА — через предикат §0.6b, после коммита, по ВЕТКЕ v4
```bash
chk "v3 не изменился" "$V3_BEFORE" "$(git rev-parse v3)"
chk "файлов в коммите" "4" "$(git show --format= --name-only HEAD | sed '/^$/d' | wc -l)"   # 3 .cs + тесты; если тестовых файлов больше — назвать фактическое число и перечень
chk ".coord/ в коммите" "0" "$(git show --format= --name-only HEAD | grep -c '^\.coord/')"
chk ".claude/ в коммите" "0" "$(git show --format= --name-only HEAD | grep -c '^\.claude/')"
chk "src/ в коммите"    "0" "$(git show --format= --name-only HEAD | grep -c '^src/')"
chk ".razor в коммите"  "0" "$(git show --format= --name-only HEAD | grep -c 'razor')"
chk "&nbsp; Engine"     "3" "$(git show v4:RTM/RTM/Engine.cs | grep -c 'nbsp')"
chk "&nbsp; UserManager" "19" "$(git show v4:RTM/RTM/UserManager.cs | grep -c 'nbsp')"
chk "MessagesPercentFunction1 не тронут" "1" "$(git show v4:RTM/RTM/Engine.cs | grep -c 'MessagesPercentFunction1')"
chk "NaN-защита у TotalStatusPercent" "2" "$(git show v4:RTM/RTM/UserManager.cs | grep -c 'IsNaN')"
```
**Построчно по таблице** `.coord/measure/rtm-anomaly-0924/ОЖИДАНИЯ.md`: для каждого из 24 —
`ДО (знам.=0)` -> `string.Empty`, `знам.>0` = как ДО. Печатать ЦЕЛИКОМ, 24 строки.
Плюс обязательное:
```
внешнее условие ложно -> пусто : формы A / B / C, по каждой <да|нет>
число изменённых мест  : 24  (ни одного вне таблицы)
изменённых методов/строк-функций ВНЕ списка 24 : 0
сборка RTM             : область (какие .csproj), errors 0, warnings <до>/<после>
dotnet test            : passed/failed/skipped числами
```
**Годно ТОЛЬКО когда `STOP` не напечатан ни разу**, кроме объявленной самопроверки §1.

## 6. КОММИТ — узкими явными путями, без `-A`, без каталогов
```bash
git add -- "RTM/RTM/Engine.cs" "RTM/RTM/UserManager.cs" "RTM/RTM/Union.cs" \
           "<путь тестового файла 1>" "<путь тестового файла 2>" ...
git commit -m "fix(rtm): return empty instead of zero when a metric has nothing to divide by" \
           -m "<числа доказательства: 24 расчёта, до/после по каждой форме, тесты, сборка>" \
           -m "Author: backend-0919 (session backend-0919), unit V4-RTM-DIVZERO-EMPTY" \
           -- "RTM/RTM/Engine.cs" "RTM/RTM/UserManager.cs" "RTM/RTM/Union.cs" \
           "<путь тестового файла 1>" "<путь тестового файла 2>" ...
```
⚠ **Коммит с путями берёт ТОЛЬКО перечисленные пути.** Каждый тестовый файл обязан стоять И в
`git add`, И в хвосте `git commit --`; иначе проиндексированные тесты в коммит не попадут, а
проверка «файлов в коммите» даст `STOP` уже ПОСЛЕ сделанного коммита. Перечень путей — фактический,
подставить до запуска, не оставлять угловые скобки.
Числа доказательства — В СООБЩЕНИЕ коммита: каталог замеров не отслеживается и переживёт уборку только так.
Авторство — строкой в сообщении (журнала больше нет, решение оператора 2026-09-19).

## 7. RESULT — последним действием, в `D:\Claude\Projects\RTM View Shell\.coord\cc\backend.md`
```
### RESULT: commit <hash> · ветка v4 · files RTM/RTM/{Engine,UserManager,Union}.cs + tests
. v3 sha до==после: <да|нет> . .coord/ 0 . .claude/ 0 . src/ 0 . .razor 0
. изменённых мест 24 . вне таблицы 0 . &nbsp; 3/19 не тронуты . MessagesPercentFunction1 не тронут
. NaN-защита добавлена в TotalStatusPercent: <да|нет>
. тестов всего <N>, из них через компилятор движка <M> . dotnet test passed <..> failed <..> skipped <..>
. сборка: область <..>, errors 0, warnings <до>/<после>
. блоб==диск по трём файлам: <хэши>
. запись в шине: есть, D:\Claude\Projects\RTM View Shell\.coord\cc\backend.md
. самопроверка: STOP получен . STOP-предикат: <N> критериев, STOP=<M>
. status done|failed . verified: object-store
NOTED: MessagesPercentFunction1 (Engine.cs :3196-3209) — мёртвый код, не тронут, не оживлён.
<таблица 24 строк ПОСЛЕ + фактический вывод chk>
```
Затем двухстрочный дайджест в `.coord/inbox/coordinator.md` тем же способом, с `\n` в конце.
`NO push`.

> Пункта «подписей ассистента 0» здесь НЕТ намеренно: коммит делает прогон, среда прогона
> дописывает подпись сама, и такая проверка пройти не может. [со слов оператора 2026-09-24] по 46
> коммитам с подписями: «оставляем как есть».
