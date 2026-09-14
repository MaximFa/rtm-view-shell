# CC TASK — QGRID orphan-cells: ПРИЁМОЧНЫЕ ЧИСЛА (BUILD + UNIT) на теле `ce66691`

Автор: backend-0912. Требование `coordinator-0912` от 2026-09-12 (приёмка правки сирот открыта
после подтверждения коммита `ce66691` оператором).
Цель: получить В ФАЙЛЕ два числа — ошибок сборки и счётчики юнит-прогона — на том теле, которое
УЖЕ лежит в ветке. Ничего не чинить, ничего не подменять.
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`.

## ЖЁСТКИЕ ГРАНИЦЫ
- **НИЧЕГО НЕ КОММИТИТЬ. НЕ ПУШИТЬ. Ветку не двигать.**
- Из git только читающие команды (`show`, `hash-object`, `rev-parse`, `log`).
  НЕ `add`/`commit`/`checkout`/`stash`/`restore`/`status`/`diff`.
- Файлы исходников НЕ править и НЕ подменять. Тест не менять.
- Базу, сервер 234 и 140 не трогать. Ничего не устанавливать.
- Ничего сверх шагов ниже не делать.

## ВЫВОД — В ФАЙЛ
Всё пишется в `tools\qgrid_accept_build_unit.txt` (создать заново в начале).

## ШАГ 0 — пин тела ДО прогона
```
echo === STEP0 BODY PIN === > tools\qgrid_accept_build_unit.txt
git rev-parse v3 >> tools\qgrid_accept_build_unit.txt
git hash-object "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_accept_build_unit.txt
git rev-parse v3:src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs >> tools\qgrid_accept_build_unit.txt
findstr /C:"DeleteQueueGridCellsByRowIdAsync" "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_accept_build_unit.txt
```
Ожидание, названное ДО прогона: `v3 = ce66691f599b43208e86e27ab870fccd24203365`;
оба хеша тела = `fb8bc0a08b9237856c6dbe1556562cc212a58b1d` (диск == дерево); `findstr` находит вызов.
**Не совпало — СТОП, дальше не идти, доложить.**

## ШАГ 1 — сборка решения
```
echo === STEP1 BUILD === >> tools\qgrid_accept_build_unit.txt
dotnet build CcDashboard.sln -c Debug >> tools\qgrid_accept_build_unit.txt 2>&1
```
Ожидание: итоговая строка с `0 Error(s)`. Предупреждения не считаем — их число просто печатаем.

## ШАГ 2 — юнит-прогон
```
echo === STEP2 UNIT === >> tools\qgrid_accept_build_unit.txt
dotnet test tests\CcDashboard.Tests.Unit --no-build >> tools\qgrid_accept_build_unit.txt 2>&1
echo === END === >> tools\qgrid_accept_build_unit.txt
```
Ожидание, названное ДО прогона: `Failed: 0, Passed: 284, Total: 284` — то есть ровно то, что
предшественник получил 08.09 на этом же теле. Любое другое число (в том числе БОЛЬШИЙ `Total`) —
не «лучше», а расхождение: печатаем как есть и докладываем, не подгоняем.

## ШАГ 3 — пин тела ПОСЛЕ прогона
```
echo === STEP3 BODY PIN AFTER === >> tools\qgrid_accept_build_unit.txt
git hash-object "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_accept_build_unit.txt
```
Ожидание: снова `fb8bc0a08b9237856c6dbe1556562cc212a58b1d` — тело за прогон не изменилось.

## ШАГ 4 — доклад
В чат: три строки — итог сборки (`N Error(s)`), итог теста (`Failed/Passed/Total`), и хеш тела
из шага 3. Плюс подтверждение, что коммита и пуша не было. Файл `tools\qgrid_accept_build_unit.txt`
не удалять.
