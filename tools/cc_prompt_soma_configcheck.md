# CC task — Soma: дружелюбная валидация конфига при старте (вместо загадочного FormatException)

> Standalone follow-up к Soma. Нативный CC, одна команда. Маленький фикс — даёт телу «чувство равновесия».

## Git push
НЕ пушить. Только commit.

## STEP 0 — INTEGRITY
`git status --short`; усечённые -> `git show HEAD:"$f" > "$f"`; `sync`. Записи — Python+`os.fsync` (§0.3); после `sync; tail -3; wc -l`.

## ПРОБЛЕМА
При незаполненном `appsettings.json` (`"Port": "<FILL>"`) Soma падает с `System.FormatException` на `int.Parse("<FILL>")`
(Program.cs:9). Загадочно. Нужна понятная диагностика.

## ЦЕЛЬ
Проверить конфиг при старте, собрать ВСЕ незаполненные/кривые поля в одно читаемое сообщение, указать путь к appsettings,
и выйти gracefully (`Environment.Exit(1)`) — БЕЗ unhandled exception/stack-trace.

## ИЗМЕНЕНИЯ в `tools/Soma/Program.cs` (минимально, ДО build app)
1. Хелпер `bool IsUnset(string? v)` -> true если `null`/пусто/начинается с `"<FILL"` (placeholder).
2. Блок валидации ПЕРЕД чтением Port/Token (заменить `int.Parse(config["Port"] ?? "5199")`). Копить в `List<string> errors`:
   - **Port** (REQUIRED): `IsUnset(config["Port"])` ИЛИ `!int.TryParse(config["Port"], out port)` -> `errors.Add("Port: должен быть числом, напр. 5199 (сейчас: '<значение>')")`.
   - **Token** (REQUIRED): `IsUnset` -> `"Token: задай длинный случайный токен (см. README)"`.
   - **ReadonlyConnectionString** (REQUIRED): `IsUnset` ИЛИ содержит `"<FILL"` -> `"ReadonlyConnectionString: впиши пароль soma_ro"`.
   - **SerilogPath** (WARNING, не фатально): `IsUnset` -> в консоль `"[warn] SerilogPath не задан — /logs/serilog вернёт ошибку, пока не заполнишь"`.
3. Если `errors` НЕ пусто:
   - вывести в `Console.Error`: заголовок `"Soma: конфиг не готов. Заполни tools/Soma/appsettings.json (секция \"Soma\"):"`,
     затем каждую ошибку с новой строки (с маркером), затем `"См. tools/Soma/README.md"`.
   - `Environment.Exit(1);` — graceful, без exception/stack-trace.
4. Port парсить через уже-проверенный `int.TryParse` (не `int.Parse`).
5. (опц.) В `/logs/serilog`: если `serilogPath` IsUnset или файл не существует -> `Results.Problem("SerilogPath not configured or file missing", statusCode:500)`, НЕ кидать исключение.

## ПРИЁМКА
1. `dotnet build tools/Soma` — чисто.
2. С `"Port": "<FILL>"` (или пустыми Token/ConnStr) -> **ЧИТАЕМОЕ сообщение со списком полей + exit 1, БЕЗ FormatException/stack-trace**.
3. С заполненным конфигом -> Soma стартует нормально на `127.0.0.1:<Port>`.

## КОММИТ (NO push)
commit.lock; `bash tools/pre-commit-check.sh`; add `tools/Soma/Program.cs`; commit `tools:` prefix — НЕ push. §0.6 verify; §0.7 re-sync.
