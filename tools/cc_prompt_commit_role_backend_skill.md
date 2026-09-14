# CC TASK — закоммитить `role-backend.md`: урок §B про форму CC-промпта

Автор: backend-0912. Слово `coordinator-0912` от 2026-09-12: моя территория, отдельным ходом, сейчас.
Предмет: в `§B LESSONS` дописан урок (промпт для CC — всегда ссылкой на файл, без пересказа в чат).
Файл живёт только на диске; на диске он живёт ровно до следующего обрыва сессии.
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`.

## ЖЁСТКИЕ ГРАНИЦЫ
- **НЕ ПУШИТЬ.** Коммит ровно один, файл ровно один.
- НЕ `checkout`/`stash`/`restore`/`reset`/`rebase`/`merge`. Ветку не переключать.
- Содержимое файла НЕ править — коммитится ровно то, что лежит.
- `git add` БЕЗ `-f`: файл уже отслеживается, правило игнора на отслеживаемые пути не действует.
  Если `add` потребует `-f` — значит предпосылка неверна: СТОП и доклад, `-f` не подставлять.
- Ничего сверх шагов ниже.

## ВЫВОД — В ФАЙЛ
Всё пишется в `tools\skill_backend_commit.txt` (создать заново в начале).

## ШАГ 0 — пины ДО коммита
```
echo === STEP0 BEFORE === > tools\skill_backend_commit.txt
git rev-parse v3 >> tools\skill_backend_commit.txt
git hash-object ".claude\skills\role-backend\role-backend.md" >> tools\skill_backend_commit.txt
git rev-parse v3:.claude/skills/role-backend/role-backend.md >> tools\skill_backend_commit.txt
git ls-files --error-unmatch ".claude/skills/role-backend/role-backend.md" >> tools\skill_backend_commit.txt 2>&1
```
Ожидание, названное ДО прогона: `v3 = 570e7f49312d738989d6114869030c7c04be0f25`;
диск = `ec5a0fa67b4ecc096b6969316a66ccf83ae65dcf`; дерево = `55e37e12e5b59ed11707b7b1effe310372d67770`
(разные — это предмет); `ls-files` печатает путь, то есть файл отслеживается.
**Не совпало — СТОП, не коммитить, доложить.**

## ШАГ 1 — коммит
```
echo === STEP1 COMMIT === >> tools\skill_backend_commit.txt
git add -- ".claude/skills/role-backend/role-backend.md"
git commit -m "skills(backend): record the CC-prompt form lesson - a run-box lives in its file and the operator gets a one-line reference to it, never a retelling that drifts from the file" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" >> tools\skill_backend_commit.txt 2>&1
```

## ШАГ 2 — пины ПОСЛЕ коммита
```
echo === STEP2 AFTER === >> tools\skill_backend_commit.txt
git rev-parse v3 >> tools\skill_backend_commit.txt
git rev-parse v3:.claude/skills/role-backend/role-backend.md >> tools\skill_backend_commit.txt
git hash-object ".claude\skills\role-backend\role-backend.md" >> tools\skill_backend_commit.txt
git show --name-only --format= v3 >> tools\skill_backend_commit.txt 2>&1
git rev-list --count origin/v3..v3 >> tools\skill_backend_commit.txt
echo === END === >> tools\skill_backend_commit.txt
```
Ожидание: `v3` — НОВЫЙ sha (не `570e7f4`); блоб в дереве теперь
`ec5a0fa67b4ecc096b6969316a66ccf83ae65dcf` == диск; в `--name-only` **ровно один файл**
`.claude/skills/role-backend/role-backend.md`; непушенных **3**.
Файлов больше одного — СТОП и доклад, самостоятельно ничего не откатывать.

## ШАГ 3 — доклад
В чат: новый sha `v3`, число файлов в коммите, блоб скилла в дереве, число непушенных,
подтверждение, что пуша не было. Файл `tools\skill_backend_commit.txt` не удалять.
