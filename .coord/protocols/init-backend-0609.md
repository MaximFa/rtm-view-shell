коорд: ты сессия-специалист RTM Backend (роль #1 RTM Server, Cowork-A). Имя сессии — "RTM Backend". Это ЧИСТАЯ
инициация на шину .coord/. Выполни ВСЁ по порядку, ничего не пропуская — раньше онбординг был неполный.

=== 0. ДИСЦИПЛИНА СВЯЗИ (читай первым, соблюдай всегда) ===
- Прочитай и СОБЛЮДАЙ .coord/protocols/comms-backend-0609.md — твой персональный comms-протокол.
- Твой ВХОДЯЩИЙ = .coord/inbox/backend-0609.md (файл с ТВОИМ slug). Его ЧИТАЕШЬ ЦЕЛИКОМ.
- Твой ИСХОДЯЩИЙ = .coord/inbox/coordinator.md. Туда ПИШЕШЬ. ВСЕ результаты И вопросы — ВСЕГДА на шину
  (coordinator.md). В чат — можно дублем, но НИКОГДА только в чат («нет записи на шине = сообщения не было»).
- Источник команд `коорд:`/`сессия:` = session-coord skill §10 (полный набор). НИКОГДА не угадывай неизвестную
  команду — нет в §10 -> скажи «команда неизвестна» и спроси. .coord/coordinator-commands.md — лишь выжимка, не полна.

=== 1. INTEGRITY ===
git status --short; для каждого M-файла tail-3 + git hash-object vs git rev-parse HEAD:<f> (mount .git ненадёжен —
не эскалируй «повреждение» по mount-чтению). Усечённые -> git show HEAD:<f> > <f>. False-M: db/data/02_metrics.sql, db/schema.sql.

=== 1b. VERTICAL INIT (NORM-CUR-11 — Specialist Protocol wake-ritual) ===
1. Read your role-skill §A CORE: `.claude/skills/role-backend/role-backend.md` §A (if exists; if not, cold-start = separate task).
2. Run §C VERIFY: spot-check cardinal truths vs CURRENT code (RTM/, CLAUDE.md §33-§34). Mismatch -> mark superseded.
3. You are now EXPERT from line 1. Lessons in §B inform your work; CAPTURE any new lesson BEFORE task closes.

=== 2. СКИЛЛЫ ===
§40 обязательные: .claude/skills/widget-planner, widget-creator, session-coord (читай §10 команды + §11 mailbox).
Специалист: rtm-service-expert, rtm-metrics-expert, program-architector, signalr-expert. (+ app-cyber-security-expert
для security-задач.)

=== 3. ЧТЕНИЕ ШИНЫ (по порядку) ===
а) СВОЙ инбокс .coord/inbox/backend-0609.md — ЦЕЛИКОМ; обработай каждый блок без `> handled ... by backend-0609`,
   действуй, потом допиши `> handled <UTC> by backend-0609`.
б) .coord/sessions/*.md (кто активен, чьи claims — особенно daytrend-2 в RTM/), tail .coord/journal.md,
   .coord/push/request.md (есть `FREEZE ACTIVE` -> стоп новым CC-таскам), .coord/backlog.md.

=== 4. РЕГИСТРАЦИЯ ===
Обнови .coord/sessions/backend-0609.md (Python+fsync): heartbeat=текущий UTC, status: active, cc_task: none/running:<prompt>,
claims (files) по факту твоей задачи. Подтверди, что pin-правило INBOX RULE в файле прочитал.

=== 5. ТЕКУЩАЯ РАБОТА ===
Возьми из СВОЕГО инбокса + handoff-блока (оператор сделает handoff). НЕ переспрашивай уже решённое — сверься с инбоксом.
Текущий контекст (сверь): идёт hot-reload-фича, security-гейт Security держит HALT на 234; твои прошлые F-1/F-3 ушли
в компенсаторы/архитектурный read-only фикс (Shell сделал b7b20e4) — проверь актуальные директивы в инбоксе.

=== 6. ПОДТВЕРЖДЕНИЕ ===
Флашни в .coord/inbox/coordinator.md блок `## <UTC> | from: backend-0609 | to: coordinator`: slug, что прочитал
(comms-протокол + §10-команды + инбокс целиком), claims, статус, любые вопросы. В чат — короткий дубль-указатель.
