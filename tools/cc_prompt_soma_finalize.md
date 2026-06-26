# CC task — Soma finalize: token-гигиена + BOM-free SQL + /db/query JSON-контракт

> Standalone, нативный CC, одна команда. Закрывает #1 (гигиена) и #2 (контракт).

## Git push
НЕ пушить. Только commit.

## STEP 0 — INTEGRITY
`git status --short`; усечённые -> `git show HEAD:"$f" > "$f"`; `sync`. Записи — Python+`os.fsync` (§0.3); после `sync; tail -3; wc -l`.

## (1) Token-гигиена + BOM-free SQL
- `git rm --cached tools/Soma/appsettings.json` — РАСтрекать (реальный токен не должен попадать в git; ранее закоммичен с `<FILL>`,
  но рабочая копия теперь с настоящим токеном — её в git быть не должно).
- Добавить в `.gitignore` строку: `tools/Soma/appsettings.json`.
- Создать `tools/Soma/appsettings.example.json` — placeholder-шаблон (Port/Token/ConnStr-Password/SerilogPath = `<FILL>`,
  Shell-секция как в рабочем), TRACKED — как образец для будущих установок. README сослать на него.
- `db/soma_readonly_role.sql`: убедиться UTF-8 **БЕЗ BOM** (Python: `open(p,encoding='utf-8-sig').read()` -> `open(p,'w',encoding='utf-8')` без BOM).
  (Оператор уже стрипнул рабочую копию — этот шаг гарантирует, что в коммит уйдёт BOM-free.)

## (2) /db/query — принять JSON `{"sql":...}` (выровнять контракт с доками)
Сейчас эндпойнт читает СЫРОЕ тело как SQL. Сделать совместимым с документированным JSON:
- Прочитать тело; попытаться распарсить как JSON-объект с полем `sql` (System.Text.Json; case-insensitive).
  Если получилось и `sql` непустой -> использовать его. ИНАЧЕ -> трактовать сырое тело как SQL (fallback, backward-compat).
- Так работают ОБА: `{"sql":"SELECT ..."}` (как в USAGE/§Soma/announce) И сырой `SELECT ...`.
- Гард (SELECT/WITH-start, forbidden keywords, multi-statement, длина, timeout, row-cap) — применять к итоговому sql, без изменений.
- Обновить `tools/Soma/USAGE.md` + `README.md`: пример `/db/query` с JSON-телом
  (`Invoke-RestMethod -Method Post -Body (@{sql="SELECT 1 AS x"}|ConvertTo-Json) -ContentType application/json -Headers $h`),
  отметить что сырой текст тоже принимается.

## ПРИЁМКА
1. `dotnet build tools/Soma` — чисто.
2. POST `/db/query` JSON `{"sql":"SELECT 1 AS x"}` -> rows `x=1`. И сырой `SELECT 1 AS x` -> тоже `x=1` (fallback).
3. `git status`: `tools/Soma/appsettings.json` БОЛЬШЕ не tracked (ignored); `appsettings.example.json` tracked.
4. `db/soma_readonly_role.sql`: первые байты НЕ `EF BB BF` (нет BOM).

## КОММИТ (NO push)
commit.lock; `bash tools/pre-commit-check.sh`; add `.gitignore tools/Soma/Program.cs tools/Soma/USAGE.md tools/Soma/README.md tools/Soma/appsettings.example.json db/soma_readonly_role.sql`;
`git rm --cached tools/Soma/appsettings.json`; commit `tools:` prefix — НЕ push. §0.6 verify; §0.7 re-sync.
