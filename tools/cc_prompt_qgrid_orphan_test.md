# CC TASK — QGRID orphan-cells: ОТРИЦАТЕЛЬНЫЙ КОНТРОЛЬ (повторный заход)

Автор: backend-0908. Прошлый прогон выполнен ЧАСТИЧНО: тест добавлен и собран, но шаг подмены файла
на версию из ветки не выполнялся (`SaveQueueGridRtsCommand.cs` сохранил дату 2026-09-06, то есть его
никто не переписывал). Без этого шага зелёный прогон ничего не доказывает.
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`.

## ЖЁСТКИЕ ГРАНИЦЫ
- **НИЧЕГО НЕ КОММИТИТЬ. НЕ ПУШИТЬ. Ветку не двигать.**
- Из git разрешены только читающие команды (`git show`, `git rev-parse`, `git hash-object`).
  НЕ использовать `add`, `commit`, `checkout`, `stash`, `restore`.
- Базу и сервер 234 не трогать.
- Тест `Handle_RowRemoved_DeletesCellsBeforeRow` уже добавлен — НЕ переписывать и НЕ править.
- Правку в `SaveQueueGridRtsCommand.cs` не улучшать.

## ВЕСЬ ВЫВОД — В ФАЙЛ
Каждый шаг дописывает результат в `tools\qgrid_orphan_test_result.txt` (создать заново в начале).
Итог я читаю из этого файла, а не из чата.

## ШАГ 0 — страховка и опорные факты
```
copy /Y "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" "%TEMP%\SQG.FIXED.cs"
git hash-object "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_result.txt
```
Ожидание хеша диска: `fb8bc0a08b9237856c6dbe1556562cc212a58b1d` (это ПОЧИНЕННАЯ версия).
Не совпало — ОСТАНОВИСЬ и доложи.

## ШАГ 1 — ОТРИЦАТЕЛЬНЫЙ КОНТРОЛЬ на непочиненном коде
```
echo === STEP1 NEGATIVE CONTROL === >> tools\qgrid_orphan_test_result.txt
git show v3:src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs > "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs"
git hash-object "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_result.txt
findstr /C:"DeleteQueueGridCellsByRowIdAsync" "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_result.txt
dotnet build >> tools\qgrid_orphan_test_result.txt 2>&1
dotnet test tests\CcDashboard.Tests.Unit >> tools\qgrid_orphan_test_result.txt 2>&1
```
Ожидание: хеш = `75487a4aae89db6ecf532fb3f157c2251e9d5758`; `findstr` НИЧЕГО не находит;
build 0 ошибок; **ровно 1 failed** — `Handle_RowRemoved_DeletesCellsBeforeRow`.
⛔ Если failed = 0 — выполни ШАГ 2 (восстановление) и ОСТАНОВИСЬ с докладом: тест не умеет падать.

## ШАГ 2 — вернуть правку и прогнать зелёным
```
echo === STEP2 FIXED === >> tools\qgrid_orphan_test_result.txt
copy /Y "%TEMP%\SQG.FIXED.cs" "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs"
git hash-object "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_result.txt
findstr /C:"DeleteQueueGridCellsByRowIdAsync" "src\CcDashboard.Application\Commands\Dashboards\SaveQueueGridRtsCommand.cs" >> tools\qgrid_orphan_test_result.txt
dotnet build >> tools\qgrid_orphan_test_result.txt 2>&1
dotnet test tests\CcDashboard.Tests.Unit >> tools\qgrid_orphan_test_result.txt 2>&1
```
Ожидание: хеш снова `fb8bc0a…`; `findstr` находит строку; build 0 ошибок; **0 failed**.

## ШАГ 3 — доклад
В чат вернуть: обе итоговые строки прогонов дословно, подтверждение что коммита не было и что файл
восстановлен. Файл `tools\qgrid_orphan_test_result.txt` оставить на месте, не удалять.
