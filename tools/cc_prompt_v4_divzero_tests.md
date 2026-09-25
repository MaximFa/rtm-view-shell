# CC TASK — V4-RTM-DIVZERO-EMPTY, ДОДЕЛКА: тесты на 24 расчёта. КОД НЕ ПРАВИТСЯ

> Автор: `backend-0919`. Основание: `coordinator-0924` 2026-09-25T02:23:56Z — решение (б):
> единица НЕ СДАНА, `status: done` блока `BINDING 02:19Z` снят, доделка тем же предметом.
> Правка кода уже в ветке: коммит `669bcac` на `v4`, границы приёмку прошли.
> Ветка: **v4 только**. Каталог прогона: `D:\Claude\Projects\RTM-design`. `v3` НЕ ТРОГАТЬ.
> Замер — в `D:\Claude\Projects\RTM View Shell\.coord\measure\rtm-divzero-0924\`, НЕ в коммит.

## ⛔ ГЛАВНОЕ ОГРАНИЧЕНИЕ ЭТОЙ ЕДИНИЦЫ
**Claims: только `tests/RTM.Engine.Tests/**`.**
`RTM/RTM/Engine.cs`, `RTM/RTM/UserManager.cs`, `RTM/RTM/Union.cs` — **НЕ ПРАВЯТСЯ НИ ОДНИМ СИМВОЛОМ.**
Если тест вскрыл дефект в коде — это **СТОП и письмо координатору**, а не правка. Починить то, что
сам же и проверяешь, в одной единице — значит остаться без проверки.
Приёмка содержит это предикатом: блобы трёх `.cs` до и после обязаны совпасть.

## §0.6a INTEGRITY
Проверка по object store, не по докладу инструмента. Счёт строк доказательством не является.
Каждое число — парой «до/после» и **с единицей измерения** (места или вхождения — называть, какая).
**Edit-инструмент ЗАПРЕЩЁН**: чтение файла, изменение в памяти, запись целиком + `os.fsync`.
После коммита — блоб == `git hash-object` того же файла на диске, предъявить.

### §0.6b ФОРМА ОСТАНОВКИ — ПРЕДИКАТ, А НЕ ПРОЗА
```bash
chk(){ if [ "$2" = "$3" ]; then echo "OK   $1: exp=$2 got=$3"; else echo "STOP $1: exp=$2 got=$3"; fi; }
```
**Хоть одно `STOP` — коммит НЕ делается, `status: failed`, фактическое число в `RESULT`.
Переформулировать критерий под факт ЗАПРЕЩЕНО.**

### ⛔ §0.6в ПОЧЕМУ ЭТА ЕДИНИЦА СУЩЕСТВУЕТ — ЧИТАТЬ ДО РАБОТЫ
Предыдущий прогон этой же единицы поставил `status: done`, **не напечатав ни одной обязательной
строки**: ни `STOP-предикат`, ни `самопроверка`, ни `запись в шине`, ни `dotnet test`, ни таблицы.
Тестов не создал ни одного. Форма §0.6b защищает от «увидел красное и пошёл дальше», но не защищает
от «не стал мерить вовсе». Поэтому здесь:
**`status: done` РАЗРЕШЁН только если в `RESULT` присутствуют ВСЕ строки списка §7 — каждая.
Отсутствие любой из них = `status: failed`, независимо от того, прошли ли тесты.**
Перед записью `RESULT` проверить себя же:
```bash
for S in "STOP-предикат" "самопроверка" "запись в шине" "в окне v3" "внешнее условие" "dotnet test" "тестов всего" "блоб==диск"; do
  printf "%-18s в моём RESULT: " "$S"; grep -c "$S" <<< "$RESULT_TEXT"
done
```
Любой ноль — `status: failed`, и в `RESULT` строка `самоконтроль §0.6в: не хватает <перечень>`.

## §S. Multi-session sync
binding: `V4-RTM-DIVZERO-EMPTY` (продолжение) · slug: `backend-0919`
### S1. Push barrier
```bash
PUSHREQ="/d/Claude/Projects/RTM View Shell/.coord/push/request.md"   # абсолютный путь, НЕ относительный
if [ ! -f "$PUSHREQ" ]; then echo "STOP: барьер не найден по пути $PUSHREQ — проверка не способна вернуть красное"; exit 1; fi
if grep -q "FREEZE ACTIVE" "$PUSHREQ"; then echo "PUSH BARRIER ACTIVE"; cat "$PUSHREQ"; echo "STOP"; exit 1; fi
echo "барьер прочитан: $PUSHREQ, FREEZE ACTIVE вхождений $(grep -c 'FREEZE ACTIVE' "$PUSHREQ")"
```
⚠ В `RTM-design\.coord\` каталога `push` НЕТ: относительный путь даёт молчаливый провал `cat`,
и барьер «пройден» всегда. Отсутствие файла — **`STOP`**, а не пропуск. Число вхождений печатать:
проверка обязана уметь вернуть красное.
### S2. `commit.lock` вокруг `git add`/`git commit` — форма `tools/cc_prompt_sync_block.md`.
### S3. После коммита: `bash tools/cc_post_commit.sh backend-0919 $(git log -1 --format=%h)`, затем `sync`.
### S4. НЕ `git push`.

## §B. БИНДИНГ — ШИНА ОДНА, ПУТЬ АБСОЛЮТНЫЙ
**Только `D:\Claude\Projects\RTM View Shell\.coord\cc\backend.md`.** НЕ `RTM-design\.coord\cc\`.
Python + `os.fsync`, `newline="\n"`, запись заканчивается переводом строки. Метку времени снять
`date -u`; форма с иксом — подделка. **Письмо от имени `backend-0919`**, не от имени прогона:
сессии `backend-0925` не существует, предыдущий прогон подписался ею и написал координатору мимо роли.
Координатору писать НЕ НАДО — отчёт несёт роль.
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_v4_divzero_tests.md | status: open
### DIRECTIVE: тесты на 24 расчёта V4-RTM-DIVZERO-EMPTY. Код RTM/RTM/*.cs не правится.
Claim: tests/RTM.Engine.Tests/**. gate: блобы трёх .cs до==после; в окне v3 и v4 ноль чужих правок RTM/;
случаев 63 по таблице §3 (2 на расчёт, 3 там где есть внешнее условие — 15 расчётов);
11 строк-функций — через компилятор движка; .coord/ и .claude/ — 0 путей.
```

## 1. ЗАМЕР «ДО»
```bash
chk "ветка" "v4" "$(git rev-parse --abbrev-ref HEAD)"
V3_BEFORE="$(git rev-parse v3)"; echo "v3 до: $V3_BEFORE"
V4_BEFORE="$(git rev-parse v4)"; echo "v4 до: $V4_BEFORE"
for F in RTM/RTM/Engine.cs RTM/RTM/UserManager.cs RTM/RTM/Union.cs; do
  echo "блоб ДО $F: $(git rev-parse v4:"$F")"
done
echo "файлов в tests/RTM.Engine.Tests/ ДО: $(git ls-tree -r --name-only v4 -- tests/RTM.Engine.Tests/ | wc -l)"
chk "САМОПРОВЕРКА прибора" "v4" "нет-такой-ветки"
```
Последняя строка ОБЯЗАНА дать `STOP`; объявить отдельно: `самопроверка: STOP получен`.

## 2. КАК ТЕСТИРОВАТЬ — два разных механизма, не смешивать
### 2а. 13 расчётов обычного кода — прямой вызов
```
Union.cs   : CalculateCPH · AvgResponseTimeMetric · getUsersInStatusPercent ·
             getUsersInStatusGroupPercent · getUsersInStatusDurationAvg ·
             getUsersInStatusGroupDurationAvg · getUsersInStatusDurationPercent ·
             getUsersInStatusGroupDurationPercent                                   (8)
UserManager: CalculateCPH · TotalStatusPercent · TotalStatusGroupPercent ·
             TotalStatusDurationAvg · TotalStatusGroupDurationAvg                   (5)
```
Вызывать метод/ветку `switch` напрямую, подготовив состояние объекта. Число случаев — по таблице §3.

### 2б. 11 строк-функций Engine.cs — ЧЕРЕЗ КОМПИЛЯТОР ДВИЖКА, а не пересказом
Механизм в движке [измерено `backend-0919` по v4]:
```
Engine.CompileAndSetMetricFunction(MetricDef, string functionBody)      — public, Engine.cs :2657
Engine.CompileAndSetUserMetricFunction(MetricDef, string functionBody)  — public, Engine.cs :2647
компиляция: CSharpSyntaxTree.ParseText -> CSharpCompilation.Create -> Emit -> Assembly.Load
                                       -> method.CreateDelegate(...)  -> metricDef.MetricFunction
подстановка до компиляции: functionBody.Replace("METRIC_PARAMETER", …)
                                      .Replace("METRIC_DIRECTION", …).Replace("METRIC_FORMAT", …)
```
Требование теста, дословно:
1. текст брать **из `MetricFunctionList` / `MetricUserFunctionList` живого `Engine`** — то есть ровно
   то, что ушло в `TryAdd`. **Копировать текст в тест ЗАПРЕЩЕНО**: проверялась бы копия, а не то,
   что исполняет движок;
2. подставить `METRIC_PARAMETER` / `METRIC_DIRECTION` / `METRIC_FORMAT` тем же `Replace`, что в движке;
3. скомпилировать **вызовом `CompileAndSetMetricFunction` / `CompileAndSetUserMetricFunction`**
   (они public) и взять получившийся делегат из `MetricDef`;
4. выполнить делегат на наборах `ConcurrentBag<IDInteraction>` — по числу случаев из таблицы §3
   (2 или 3 на расчёт).
Расчёты: `AnsweredPercent` · `AbandonedPercent` · `MessagesPercent` · `MessagesInteractionsPercent` ·
`WaitDurationAvg` · `TalkDurationAvg` (очередь) · `TalkDurationAvg` (агент) ·
`MessagesAvgFirstResponseTime` (очередь и агент) · `MessagesAvgResponseTime` (очередь и агент).
**Если компилятор из теста недостижим — печатать `STOP`, писать причину и останавливаться.
Подмена пересказом текста = провал единицы, даже если тесты зелёные.**

## 3. ЧТО ОБЯЗАН ПРОВЕРЯТЬ КАЖДЫЙ ТЕСТ — правило ОДНО, случаев 2 или 3
На каждый из 24 расчётов обязательны ДВА случая:
```
1) знаменатель = 0   -> пустая строка (string.Empty), НЕ "0", НЕ "0%", НЕ "00:00:00"
2) знаменатель > 0   -> то же значение и тот же формат, что ДО правки 669bcac
```
**Третий случай — «внешнее условие ложно -> пусто» — только у тех 15 расчётов, где внешнее условие
ЕСТЬ.** Таблица ниже снята по коду `669bcac` и обязательна к применению как есть.
Обнаружил условие, которого в таблице нет, или не нашёл указанного — **`STOP`**, не подгонка.
```
ИТОГО ожидается: 24 × 2 = 48 случаев  +  K3 = 15 случаев  =  63 случая
```
⚠ Внешнее условие — ОХВАТЫВАЮЩЕЕ расчёт: ложно -> расчёт не выполняется вовсе. Проверки знаменателя
(`cnt > 0`, `count > 0`, `tsda > 0`, `loginDur > 0`, `responseTimes.Count == 0`, `!responseTimes.Any()`,
`totalHours < 0.001`) и условия ВНУТРИ циклов внешними не являются.

### Таблица внешних условий — по коду `669bcac`, дословно, с номером строки
| # | расчёт | файл:строки | внешнее условие | случаев |
|---|---|---|---|---|
| 1 | `talkDurationAvg` (агент) | Engine.cs:2840-2856 | **нет** (только `cnt > 0`) | 2 |
| 2 | `MessagesAvgFirstResponseTime` (агент) | Engine.cs:2874-2908 | **нет** | 2 |
| 3 | `MessagesAvgResponseTime` (агент) | Engine.cs:2909-2977 | **нет** | 2 |
| 4 | `AnsweredPercent` | Engine.cs:3097-3115 | `if (applicAny)` :3100 | 3 |
| 5 | `AbandonedPercent` | Engine.cs:3116-3135 | `if (applicAny)` :3119 | 3 |
| 6 | `MessagesPercent` | Engine.cs:3214-3240 | `if (applicAny)` :3217 | 3 |
| 7 | `MessagesInteractionsPercent` | Engine.cs:3241-3268 | `if (applicAny)` :3244 | 3 |
| 8 | `MessagesAvgFirstResponseTime` (очередь) | Engine.cs:3330-3369 | `if (!applicAny)` :3333 — ранний выход | 3 |
| 9 | `MessagesAvgResponseTime` (очередь) | Engine.cs:3370-3434 | `if (!applicAny)` :3371 — ранний выход | 3 |
| 10 | `WaitDurationAvg` | Engine.cs:3435-3452 | **нет** (только `count > 0`) | 2 |
| 11 | `talkDurationAvg` (очередь) | Engine.cs:3472-3488 | **нет** (только `cnt > 0`) | 2 |
| 12 | `CalculateCPH` | UserManager.cs:994-1030 | **нет**: `:998` провал разбора `callsCountStr` задаёт ЧИСЛИТЕЛЬ (`totalCalls = 0`), расчёт не прекращает; `:1013` — порог знаменателя | 2 |
| 13 | `TotalStatusPercent` | UserManager.cs:1272-1289 | `if (isLoggedId)` :1274 | 3 |
| 14 | `TotalStatusGroupPercent` | UserManager.cs:1290-1322 | `if (isLoggedId)` :1292 | 3 |
| 15 | `TotalStatusDurationAvg` | UserManager.cs:1333-1345 | **нет** (только `tsda > 0`) | 2 |
| 16 | `TotalStatusGroupDurationAvg` | UserManager.cs:1346-1358 | **нет** (только `tsgda > 0`) | 2 |
| 17 | `CalculateCPH` | Union.cs:475-513 | **нет** (как #12) | 2 |
| 18 | `AvgResponseTimeMetric` | Union.cs:650-712 | `if (!applyAny)` :652 — ранний выход | 3 |
| 19 | `getUsersInStatusPercent` | Union.cs:873-891 | `if (Users.Count() > 0)` :877 | 3 |
| 20 | `getUsersInStatusGroupPercent` | Union.cs:892-911 | `if (Users.Count() > 0)` :896 | 3 |
| 21 | `getUsersInStatusDurationAvg` | Union.cs:912-940 | `if (Users.Count() > 0)` :915 | 3 |
| 22 | `getUsersInStatusGroupDurationAvg` | Union.cs:941-971 | `if (Users.Count() > 0)` :944 | 3 |
| 23 | `getUsersInStatusDurationPercent` | Union.cs:972-994 | `if (Users.Count() > 0)` :976 | 3 |
| 24 | `getUsersInStatusGroupDurationPercent` | Union.cs:995-1017 | `if (Users.Count() > 0)` :999 | 3 |

Счёт по таблице: условие ЕСТЬ у **15** (#4-9, #13-14, #18-24), НЕТ у **9** (#1-3, #10-12, #15-17).
`15 × 3 + 9 × 2 = 45 + 18 = 63`.
Ожидания для случая 2 брать из `.coord/measure/rtm-anomaly-0924/ОЖИДАНИЯ.md` — снята ДО правки.

## 4. ГРАНИЦЫ
- Ни одного символа в `RTM/RTM/*.cs`. Тест вскрыл дефект кода -> **СТОП**, письмо координатору.
- Мёртвая `MessagesPercentFunction1` (Engine.cs :3196-3209) — не тестировать и не оживлять: в `TryAdd`
  её нет, делегата не существует. Назвать в NOTED.
- `&nbsp;` (Engine 3, UserManager 19) и `Engine.cs:927` — вне предмета.
- Счётчики (`AnsweredCount`, `NumWaitings`, `InteractionsCount`, …) — настоящий ноль, не тестировать.
- Состояние агента и `AgentStateDistribution` — вне предмета.
- Ни одного `.razor`, ни одного файла в `src/`, ноль путей `.coord/` и `.claude/`.
- `NO push`.

## 5. ПРИЁМКА — предикатом, после коммита, по ВЕТКЕ
```bash
# ⚠ НЕ сверять "v3 sha до == после": в v3 колония коммитит свои протоколы и реестры, и во время
# прогона там может лечь чужой коммит — это дало бы ЛОЖНОЕ КРАСНОЕ. Запрет оператора относится к
# продуктовому коду. Верный предикат — не «ветка стоит», а «в окне нет чужой правки МОЕЙ территории»:
chk "в окне v3: коммитов, трогающих RTM/" "0" "$(git log --format= --name-only "$V3_BEFORE"..v3 | grep -c '^RTM/')"
chk "в окне v4: чужих коммитов, трогающих RTM/" "0" "$(git log --format= --name-only "$V4_BEFORE"..v4 | grep -v "^$(git show --format= --name-only HEAD | sed '/^$/d' | head -1)$" | grep -c '^RTM/')"
echo "окно v3 $V3_BEFORE..$(git rev-parse --short v3): $(git log --oneline "$V3_BEFORE"..v3 | wc -l) коммит(ов) — перечень:"
git log --oneline "$V3_BEFORE"..v3 || true
for F in RTM/RTM/Engine.cs RTM/RTM/UserManager.cs RTM/RTM/Union.cs; do
  chk "блоб $F не изменился" "<блоб ДО из §1>" "$(git rev-parse v4:"$F")"
done
chk ".coord/ в коммите"  "0" "$(git show --format= --name-only HEAD | grep -c '^\.coord/')"
chk ".claude/ в коммите" "0" "$(git show --format= --name-only HEAD | grep -c '^\.claude/')"
chk "src/ в коммите"     "0" "$(git show --format= --name-only HEAD | grep -c '^src/')"
chk "RTM/ в коммите"     "0" "$(git show --format= --name-only HEAD | grep -c '^RTM/')"
chk "все пути коммита под tests/" "0" "$(git show --format= --name-only HEAD | sed '/^$/d' | grep -cv '^tests/')"
```
Плюс числами, с единицей измерения:
```
тестов всего <N> (случаев), ожидание 63 . из них через компилятор движка <M> (случаев)
расчётов покрыто <K> из 24 (расчётов) · случаев 2 или 3 по таблице §3 · итого ожидается 63 (случаев)
внешнее условие ложно -> пусто: покрыто <K3> из 15 (расчётов с условием)
dotnet test: passed <..> failed <..> skipped <..>
файлов в tests/RTM.Engine.Tests/: до <..> -> после <..> (файлов)
блоб==диск по каждому добавленному файлу: <хэши>
```
**Годно ТОЛЬКО когда `STOP` не напечатан ни разу**, кроме объявленной самопроверки §1.
`failed > 0` — не «почти готово», а `status: failed` с перечнем упавших.

## 6. КОММИТ — явными путями, без `-A`, без каталогов
```bash
git add -- "<tests/RTM.Engine.Tests/файл1>" "<tests/RTM.Engine.Tests/файл2>" ...
git commit -m "test(rtm): cover the 24 zero-denominator metric calculations" \
           -m "<числа: расчётов 24, случаев 63, через компилятор движка M, dotnet test passed/failed/skipped>" \
           -m "Author: backend-0919 (session backend-0919), unit V4-RTM-DIVZERO-EMPTY (continuation)" \
           -- "<tests/RTM.Engine.Tests/файл1>" "<tests/RTM.Engine.Tests/файл2>" ...
```
⚠ Каждый файл — И в `git add`, И в хвосте `git commit --`: коммит с путями берёт только перечисленное.
Числа доказательства — в СООБЩЕНИЕ коммита: каталог замеров не отслеживается.

## 7. RESULT — ПОЛНЫЙ. Отсутствие любой строки = `status: failed` (§0.6в)
```
### RESULT: commit <hash> · ветка v4 · files tests/RTM.Engine.Tests/<перечень>
. в окне v3 коммитов по RTM/: <факт> (ожидание 0) . в окне v4 чужих по RTM/: <факт> (ожидание 0)
. блобы трёх .cs до==после: <да|нет> (перечислить)
. .coord/ 0 . .claude/ 0 . src/ 0 . RTM/ 0 . путей вне tests/ 0
. тестов всего <N> случаев . из них через компилятор движка <M> случаев
. расчётов покрыто <K> из 24 . случаев <N> из 63 (2 или 3 по таблице §3)
. внешнее условие ложно -> пусто: покрыто <K3> из 15
. dotnet test passed <..> failed <..> skipped <..>
. файлов в tests/: <до> -> <после> (файлов)
. блоб==диск: <перечень хэшей>
. запись в шине: есть, D:\Claude\Projects\RTM View Shell\.coord\cc\backend.md
. самопроверка: STOP получен . STOP-предикат: <N> критериев, STOP=<M>
. самоконтроль §0.6в: все строки на месте | не хватает <перечень>
. status done|failed . verified: object-store
NOTED: MessagesPercentFunction1 (Engine.cs :3196-3209) — мёртвый код, делегата нет, не тестировался.
<таблица 24 расчётов: расчёт · случай 1 · случай 2 · случай 3 · passed|failed>
<фактический вывод chk и dotnet test>
```
`NO push`.
