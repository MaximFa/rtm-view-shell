# CC TASK — два коммита движка: `PR234-UNIONMAP-RACE-01` и `PR234-METRIC-NAN-01`

Автор: backend-0912, 2026-09-13. Слово координатора на оба коммита дано.
Проект: `D:\Claude\Projects\RTM View Shell`, ветка `v3`.
**Два коммита, по одному файлу в каждом. Ничего попутного.**

## НОРМЫ ВНУТРИ ПРОМПТА (на подгрузку `CLAUDE.md` не полагаемся — `CLAUDE-OVERSIZE-01`)
- **НЕ ПУШИТЬ.** Барьер §37 — координатора. Ветку не двигать сверх этих двух коммитов.
- `git commit -- <путь>` с ЯВНЫМ pathspec. Без pathspec коммит однажды забрал посторонний файл.
- Перед каждым `add` печатать `git status --short` в файл вывода.
- НЕ `checkout`/`stash`/`restore`/`reset`/`rebase`/`merge`. Файлы не править.
- Сборку не запускать: она уже прогнана, артефакты на месте.
- **«Task already completed in this session» результатом НЕ является:** задача выполнена только
  если пины шагов ниже напечатаны в файл ЭТИМ прогоном.

## ВЫВОД — В ФАЙЛ
Всё пишется в `tools\engine_fixes_commit.txt` (создать заново в начале).

## ШАГ 0 — пины ДО
```
echo === STEP0 BEFORE === > tools\engine_fixes_commit.txt
git rev-parse v3 >> tools\engine_fixes_commit.txt
git hash-object "RTM\RTM\Engine.cs" >> tools\engine_fixes_commit.txt
git hash-object "RTM\RTM\Union.cs" >> tools\engine_fixes_commit.txt
git rev-parse v3:RTM/RTM/Engine.cs >> tools\engine_fixes_commit.txt
git rev-parse v3:RTM/RTM/Union.cs >> tools\engine_fixes_commit.txt
git status --short >> tools\engine_fixes_commit.txt
git rev-list --count origin/v3..v3 >> tools\engine_fixes_commit.txt
```
Ожидание, названное ДО прогона:
```
v3        = 531cf316e31522874c85e896c568ec59693b194a
Engine.cs диск = 841265cf7a0447fdf687c542f967097746269f05   в дереве ec1e0bec5061208718ca6cd519777a9bfb2e4d2a
Union.cs  диск = 60284943ad52cbe72468bd7532519bc8f350e0cb   в дереве 02f6f18a8c81f4b652ac1155cfd61092433bfae2
непушенных 13
```
`git status --short` печатается для сведения: в нём могут быть и другие изменённые/нетрекаемые пути
(вывод боксов в `tools\`, артефакты сборки). **Это ожидаемо и не повод останавливаться** — именно
поэтому оба коммита идут с явным pathspec и ничего кроме названного файла взять не могут.
Не сошлись ХЕШИ или `v3` — СТОП, не коммитить, доложить.

## ШАГ 1 — коммит №1: `PR234-UNIONMAP-RACE-01`
```
echo === STEP1 COMMIT Engine.cs === >> tools\engine_fixes_commit.txt
git add -- "RTM/RTM/Engine.cs"
git status --short >> tools\engine_fixes_commit.txt
git commit -- "RTM/RTM/Engine.cs" -m "fix(rtm): re-evaluate union membership after LoadData, not only on the next activation - refreshUnions had two callers, both inside workgroupActivation, so a mapping row that landed after an agent's activation never reached him" -m "PR234-UNIONMAP-RACE-01. Acceptance is NOT closed: there is no test project covering the engine (PR234-ENGINE-NOTESTS-01); this commit rests on code reading and a clean compile." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" >> tools\engine_fixes_commit.txt 2>&1
git show --name-only --format= HEAD >> tools\engine_fixes_commit.txt
```
Ожидание: `1 file changed`; в `--name-only` **ровно один** файл `RTM/RTM/Engine.cs`.
Файлов больше одного — СТОП и доклад, самостоятельно НИЧЕГО не откатывать.

## ШАГ 2 — коммит №2: `PR234-METRIC-NAN-01`
```
echo === STEP2 COMMIT Union.cs === >> tools\engine_fixes_commit.txt
git add -- "RTM/RTM/Union.cs"
git status --short >> tools\engine_fixes_commit.txt
git commit -- "RTM/RTM/Union.cs" -m "fix(rtm): guard the duration-percent metrics against a zero denominator - with every agent in SIGNOFF the sums are 0 and 0.0/0.0 produced NaN, which the widget rendered as a dash instead of a value" -m "PR234-METRIC-NAN-01. Operator's decision: show 0%. Same guard the sibling percent metrics already had; the division moved inside the guard, not duplicated." -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" >> tools\engine_fixes_commit.txt 2>&1
git show --name-only --format= HEAD >> tools\engine_fixes_commit.txt
```
Ожидание: `1 file changed`; ровно один файл `RTM/RTM/Union.cs`.

## ШАГ 3 — пины ПОСЛЕ
```
echo === STEP3 AFTER === >> tools\engine_fixes_commit.txt
git rev-parse v3 >> tools\engine_fixes_commit.txt
git rev-parse v3:RTM/RTM/Engine.cs >> tools\engine_fixes_commit.txt
git rev-parse v3:RTM/RTM/Union.cs >> tools\engine_fixes_commit.txt
git log --oneline -3 v3 >> tools\engine_fixes_commit.txt
git rev-list --count origin/v3..v3 >> tools\engine_fixes_commit.txt
echo === END === >> tools\engine_fixes_commit.txt
```
Ожидание: `v3` — НОВЫЙ sha; `v3:Engine.cs` = `841265cf…` (== диск), `v3:Union.cs` = `60284943…`
(== диск); в `git log` сверху два новых коммита; **непушенных 15**.

## ШАГ 4 — доклад
В чат: два новых sha, по одному файлу в каждом, оба блоба в дереве, число непушенных,
подтверждение что пуша НЕ было. Файл `tools\engine_fixes_commit.txt` не удалять.
