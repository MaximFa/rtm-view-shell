# CC TASK — коммит хендофа backend и уроков `§B`

Автор: backend-0912, 2026-09-13. Обязанность §4 перед преемником: хендоф обновлён, пять уроков
дописаны в `§B LESSONS` роль-скилла. **Два файла, ОДИН коммит** — это одна единица работы
(«что я оставляю преемнику»).
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`.

## НОРМЫ ВНУТРИ ПРОМПТА (на подгрузку `CLAUDE.md` не полагаемся — `CLAUDE-OVERSIZE-01`)
- **НЕ ПУШИТЬ.** Барьер §37 у координатора, непушенных сейчас 16, станет 17.
- **Это rev 2.** Первый заход оборвался: в `tools\backend_handoff_commit.txt` напечатался только
  заголовок `=== STEP1 COMMIT ===` и ничего после — ни `git add`, ни `git status`, ни коммита.
  Причина неизвестна и НЕ выдумывается. Файл вывода перезаписывается с нуля этим прогоном.
- **Форма коммита: `git commit -m "..." -m "..." -- "<путь>" "<путь>"` — pathspec ПОСЛЕДНИМ.**
  НЕ `git commit -- "<путь>" -m "..."`: после `--` git считает pathspec всё остальное, включая
  `-m` и тексты сообщений (проверено сегодня, заход упал четырьмя `pathspec did not match`).
- `git add` БЕЗ `-f`: оба пути уже отслеживаются (`ls-files --error-unmatch` проходит,
  `check-ignore` пуст). Если `add` потребует `-f` — предпосылка неверна: СТОП и доклад.
- Перед `add` печатать `git status --short` в файл вывода. В нём будут и другие пути (вывод боксов
  в `tools\`, артефакты сборки, чужие файлы) — **это ожидаемо**, именно поэтому pathspec явный.
- Файлы НЕ править. НЕ `checkout`/`stash`/`restore`/`reset`. Сборку не запускать.
- **«Task already completed in this session» результатом НЕ является:** задача выполнена, только
  если пины шагов 0 и 2 напечатаны в файл ЭТИМ прогоном.

## ВЫВОД — В ФАЙЛ `tools\backend_handoff_commit.txt` (создать заново)

## ШАГ 0 — пины ДО
```
echo === STEP0 BEFORE === > tools\backend_handoff_commit.txt
git rev-parse v3 >> tools\backend_handoff_commit.txt
git hash-object ".coord\protocols\backend-handoff.md" >> tools\backend_handoff_commit.txt
git hash-object ".claude\skills\role-backend\role-backend.md" >> tools\backend_handoff_commit.txt
git rev-parse v3:.coord/protocols/backend-handoff.md >> tools\backend_handoff_commit.txt
git rev-parse v3:.claude/skills/role-backend/role-backend.md >> tools\backend_handoff_commit.txt
git status --short >> tools\backend_handoff_commit.txt
git rev-list --count origin/v3..v3 >> tools\backend_handoff_commit.txt
```
Ожидание, названное ДО прогона (**rev 2**, пере-снято 2026-09-13 после того, как ветка ушла
на чужой коммит `3d55673` devops(probes)):
```
v3 = 3d55673eafbe21233b895e1abf386fcc8ae6b097
handoff  диск 3d7e00b729c375e9800245d31b1b7d91af6eefde   в дереве d6b8d1c92a750f22e03258801e1e8aa37f5985ca
skill    диск c1312b4476c3b647f25322206e43e2f3329031a8   в дереве ec5a0fa67b4ecc096b6969316a66ccf83ae65dcf
непушенных 16
```
**ХЕШИ ДВУХ МОИХ ФАЙЛОВ — гейт. `v3` — нет:** ветка может уйти вперёд чужими руками между
написанием этого бокса и прогоном, это норма колонии, а не отказ. Разошлись хеши файлов — СТОП и
доклад. Ушёл только `v3` — продолжать, и НОВЫЙ sha печатать как есть.

## ШАГ 1 — коммит (два файла, один коммит)
```
echo === STEP1 COMMIT === >> tools\backend_handoff_commit.txt
git add -- ".coord/protocols/backend-handoff.md" ".claude/skills/role-backend/role-backend.md"
git status --short >> tools\backend_handoff_commit.txt
git commit -m "docs(backend): hand the role over - live state, what is open and why, and the negative knowledge that is not in git" -m "Handoff section for 2026-09-13 plus five lessons in the role skill: a guard clause must itself be checked for executability (git commit -- path -m failed); a threshold handed down by a senior belongs to HIS artifacts, not mine; the list a predicate stands on is a measurement too; an acceptance that cannot be run is named out loud and rides in the commit message; and a live measurement cannot accept a race fix because it measures the same race." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" -- ".coord/protocols/backend-handoff.md" ".claude/skills/role-backend/role-backend.md" >> tools\backend_handoff_commit.txt 2>&1
git show --name-only --format= HEAD >> tools\backend_handoff_commit.txt
```
Ожидание: `2 files changed`; в `--name-only` **ровно два** файла, и это именно они.
Файлов больше двух — СТОП и доклад, самостоятельно НИЧЕГО не откатывать.

## ШАГ 2 — пины ПОСЛЕ
```
echo === STEP2 AFTER === >> tools\backend_handoff_commit.txt
git rev-parse v3 >> tools\backend_handoff_commit.txt
git rev-parse v3:.coord/protocols/backend-handoff.md >> tools\backend_handoff_commit.txt
git rev-parse v3:.claude/skills/role-backend/role-backend.md >> tools\backend_handoff_commit.txt
git log --oneline -2 v3 >> tools\backend_handoff_commit.txt
git rev-list --count origin/v3..v3 >> tools\backend_handoff_commit.txt
echo === END === >> tools\backend_handoff_commit.txt
```
Ожидание: `v3` — НОВЫЙ sha; `v3:backend-handoff.md` = `3d7e00b7…` (== диск);
`v3:role-backend.md` = `c1312b44…` (== диск); **непушенных 17**.
Блобы в дереве не совпали с диском — СТОП и доклад: значит коммит взял не то тело.

## ШАГ 3 — доклад
В чат: новый sha, число файлов в коммите, оба блоба в дереве, число непушенных,
подтверждение, что пуша не было. Файл `tools\backend_handoff_commit.txt` не удалять.
