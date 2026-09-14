# CC TASK — QGRID orphan-cells: ПИН ИМЕНИ УПАВШЕГО ТЕСТА

Автор: backend-0908. Требование координатора `coordinator-0908` от 2026-09-08.
Цель одна: получить в файле ИМЯ теста, который падает на теле файла из ветки.
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`.

## ЖЁСТКИЕ ГРАНИЦЫ
- **НИЧЕГО НЕ КОММИТИТЬ. НЕ ПУШИТЬ. Ветку не двигать.**
- Из git только читающие команды (`show`, `hash-object`, `log`). НЕ `add`/`commit`/`checkout`/`stash`/`restore`.
- Ни тест, ни правку НЕ менять. Базу и сервер 234 не трогать.
- Ничего сверх шагов ниже не делать.

## ВЫВОД — В ФАЙЛ
Всё пишется в `tools\qgrid_orphan_test_name_pin.txt` (создать заново в начале).

## ШАГ 0
```
copy /Y "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" "%TEMP%\SQG.FIXED2.cs"
echo === STEP0 === > tools\qgrid_orphan_test_name_pin.txt
git hash-object "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_name_pin.txt
```
Ожидание: `fb8bc0a08b9237856c6dbe1556562cc212a58b1d` (починенное тело). Не совпало — СТОП, доложить.

## ШАГ 1 — прогон на теле из ветки, с подробным логом
```
echo === STEP1 TREE BODY, DETAILED === >> tools\qgrid_orphan_test_name_pin.txt
git show v3:src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs > "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs"
git hash-object "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_name_pin.txt
dotnet test tests\CcDashboard.Tests.Unit --logger "console;verbosity=detailed" >> tools\qgrid_orphan_test_name_pin.txt 2>&1
```
Ожидание: хеш `75487a4aae89db6ecf532fb3f157c2251e9d5758`; в логе ИМЯ упавшего теста —
`Handle_RowRemoved_DeletesCellsBeforeRow` — и итог `Failed: 1, Passed: 283, Total: 284`.

## ШАГ 2 — вернуть починенное тело (обязательно, даже если шаг 1 дал неожиданный результат)
```
echo === STEP2 RESTORE === >> tools\qgrid_orphan_test_name_pin.txt
copy /Y "%TEMP%\SQG.FIXED2.cs" "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs"
git hash-object "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_name_pin.txt
findstr /C:"DeleteQueueGridCellsByRowIdAsync" "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_name_pin.txt
echo === END === >> tools\qgrid_orphan_test_name_pin.txt
```
Ожидание: хеш снова `fb8bc0a…`, `findstr` находит вызов.

## ШАГ 3 — доклад
В чат: одна строка с именем упавшего теста и итоговая строка прогона; подтверждение, что коммита
не было и тело восстановлено. Файл `tools\qgrid_orphan_test_name_pin.txt` не удалять.
