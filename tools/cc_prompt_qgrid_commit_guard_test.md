# CC TASK — QGRID orphan-cells: ЗАКОММИТИТЬ ТЕСТ-СТОРОЖ, отставший от правки `ce66691`

Автор: backend-0912. Требование `coordinator-0912` от 2026-09-12.
Предмет: коммит `ce66691` взял правку `SaveQueueGridRtsCommand.cs` и НЕ взял её регрессионный
сторож — тест живёт только на диске. Один файл, один коммит.
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`.

## ЖЁСТКИЕ ГРАНИЦЫ
- **НЕ ПУШИТЬ.** Коммит — ровно один, ровно один файл, командой из ШАГА 2 и ничем иным.
- НЕ `checkout`/`stash`/`restore`/`reset`/`rebase`/`merge`. Ветку не переключать.
- Исходники и тест НЕ править — файл коммитится ровно в том виде, в каком лежит.
- Базу, 234 и 140 не трогать. Ничего не устанавливать.
- Ничего сверх шагов ниже не делать.

## ВЫВОД — В ФАЙЛ
Всё пишется в `tools\qgrid_guard_commit.txt` (создать заново в начале).

## ШАГ 0 — пины ДО коммита
```
echo === STEP0 BEFORE === > tools\qgrid_guard_commit.txt
git rev-parse v3 >> tools\qgrid_guard_commit.txt
git hash-object "tests\CcDashboard.Tests.Unit\Commands\SaveQueueGridRtsCommandHandlerTests.cs" >> tools\qgrid_guard_commit.txt
git rev-parse ce66691:tests/CcDashboard.Tests.Unit/Commands/SaveQueueGridRtsCommandHandlerTests.cs >> tools\qgrid_guard_commit.txt
findstr /C:"Handle_RowRemoved_DeletesCellsBeforeRow" "tests\CcDashboard.Tests.Unit\Commands\SaveQueueGridRtsCommandHandlerTests.cs" >> tools\qgrid_guard_commit.txt
```
Ожидание, названное ДО прогона: `v3 = ce66691f599b43208e86e27ab870fccd24203365`;
диск теста = `db93cc6b14bf5d63cd90a993408275fd1225dada`; в дереве =
`42c0097ea9c3d783455997183945d0b0eafcb6da` (они РАЗНЫЕ — это и есть предмет);
`findstr` находит имя теста на диске.
**Не совпало — СТОП, не коммитить, доложить.**

## ШАГ 1 — что именно коммитим
Один файл: `tests\CcDashboard.Tests.Unit\Commands\SaveQueueGridRtsCommandHandlerTests.cs`.
Ничего больше в этот коммит не попадает. Если `git` попытается захватить что-то ещё — СТОП и доклад.

## ШАГ 2 — коммит
```
echo === STEP2 COMMIT === >> tools\qgrid_guard_commit.txt
git add -- "tests/CcDashboard.Tests.Unit/Commands/SaveQueueGridRtsCommandHandlerTests.cs"
git commit -m "test(web): add the regression guard for the Queue Grid orphan-cell fix - the test lagged one commit behind ce66691, so the branch could not go red if the cascade comment came back" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" >> tools\qgrid_guard_commit.txt 2>&1
```

## ШАГ 3 — пины ПОСЛЕ коммита
```
echo === STEP3 AFTER === >> tools\qgrid_guard_commit.txt
git rev-parse v3 >> tools\qgrid_guard_commit.txt
git rev-parse v3:tests/CcDashboard.Tests.Unit/Commands/SaveQueueGridRtsCommandHandlerTests.cs >> tools\qgrid_guard_commit.txt
git hash-object "tests\CcDashboard.Tests.Unit\Commands\SaveQueueGridRtsCommandHandlerTests.cs" >> tools\qgrid_guard_commit.txt
git show --stat --oneline v3 >> tools\qgrid_guard_commit.txt 2>&1
git rev-list --count origin/v3..v3 >> tools\qgrid_guard_commit.txt
```
Ожидание: `v3` — НОВЫЙ sha (не `ce66691`); блоб теста в дереве теперь
`db93cc6b14bf5d63cd90a993408275fd1225dada` == диск; в `--stat` **ровно один файл**;
непушенных **2**.
Файлов в коммите больше одного — СТОП и доклад, ничего не откатывать самостоятельно.

## ШАГ 4 — прогон из состояния ветки
```
echo === STEP4 UNIT === >> tools\qgrid_guard_commit.txt
dotnet test tests\CcDashboard.Tests.Unit >> tools\qgrid_guard_commit.txt 2>&1
echo === END === >> tools\qgrid_guard_commit.txt
```
Ожидание, названное ДО прогона: `Failed: 0, Passed: 284, Skipped: 0, Total: 284`.
Смысл числа: до этого коммита чистый клон дал бы **283** — сторожа в ветке не было.
Любое другое число — расхождение, печатать как есть и докладывать, не подгонять.

## ШАГ 5 — доклад
В чат: новый sha `v3`, число файлов в коммите, блоб теста в дереве, итоговая строка прогона,
число непушенных. Плюс подтверждение, что пуша не было.
Файл `tools\qgrid_guard_commit.txt` не удалять.
