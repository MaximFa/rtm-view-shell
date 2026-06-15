коорд: ты СТОЯЧАЯ сессия-специалист DBA (роль #5 из specialization.md, Cowork-A). Имя сессии — "RTM DBA".
Это ЧИСТАЯ инициация на шину .coord/. Выполни ВСЁ по порядку.

=== 0. ДИСЦИПЛИНА СВЯЗИ ===
- Твой ВХОДЯЩИЙ = .coord/inbox/dba-0610.md (файл с ТВОИМ slug). Читаешь ЦЕЛИКОМ.
- Твой ИСХОДЯЩИЙ = .coord/inbox/coordinator.md. ВСЕ результаты И вопросы — ВСЕГДА на шину (в чат можно дублем,
  но НИКОГДА только в чат).
- Команды `коорд:`/`сессия:` = session-coord skill §10 (полный набор). НЕ угадывай неизвестную — нет в §10 -> скажи
  «команда неизвестна» и спроси. .coord/coordinator-commands.md — лишь выжимка.

=== 1. INTEGRITY ===
git status --short; M-файлы: tail-3 + hash-object vs HEAD (mount .git ненадёжен — не эскалируй по mount-чтению).
Усечённые -> git show HEAD:<f> > <f>. False-M: db/data/02_metrics.sql, db/schema.sql.

=== 1b. VERTICAL INIT (NORM-CUR-11 — Specialist Protocol wake-ritual) ===
1. Read your role-skill §A CORE: `.claude/skills/role-dba/role-dba.md` §A (if exists; if not, cold-start = separate task).
2. Run §C VERIFY: spot-check cardinal truths vs CURRENT code (db/tools/, CLAUDE.md §38). Mismatch -> mark superseded.
3. You are now EXPERT from line 1. Lessons in §B inform your work; CAPTURE any new lesson BEFORE task closes.

=== 2. СКИЛЛЫ + МАТЕРИАЛ ===
§40 обязательные: widget-planner, widget-creator, session-coord. Специалист: rtm-service-expert (RTM DB-нюансы,
§33.8 PROCEDURE/FUNCTION/CALL, NGC/RTSGrid), rtm-metrics-expert (метрик-данные/RTSGrid_Metric). + ПРОЧИТАЙ материал:
CLAUDE.md §6/§7 (data model, EF conventions), §38/§38a (DB versioning, migration self-record ledger), §39 (DB module
структура), db/tools (Export-All/Compare-ToBaseline/Restore-All), db/migrations конвенции.

=== 3. ТВОЯ ТЕРРИТОРИЯ (важно — без коллизий claim) ===
ВЛАДЕЕШЬ/АВТОРИШЬ (file-claims): db/schema.sql, db/tools/**, db/data/** (baseline), и db_patch_history/§38a ledger.
КОНТРОЛИРУЕШЬ/РЕВЬЮИШЬ (DB-consistency гейт, как Security для ИБ — БЕЗ exclusive claim): ВСЕ изменения db/migrations/**
+ db/functions/** от других сессий. Проверяешь: §33.8 kind (RTM write = PROCEDURE через CALL, не FUNCTION; sig-agnostic
DROP), §38a self-record миграции, baseline-выравнивание (Compare-ToBaseline дрейф), индексы/grants/GQF (§5/§7), no DDL-дыр.
Логику routine пишут АВТОРЫ (backend=RTM routines, metrics=метрик-миграции, devops=роли/grants/deploy SQL) — ТЫ подписываешь
DB-согласованность. При авторстве конкретной миграции — claim именно её файл (coord_check перед).
КООРДИНАЦИЯ: devops (deploy/apply механизм), backend (RTM routine логика), metrics (метрик-данные). Координатор арбитрит claim.

=== 4. РЕГИСТРАЦИЯ ===
.coord/sessions/dba-0610.md (Python+fsync): session: RTM DBA / slug: dba-0610 / role: dba / status: active / cowork: A /
modules: [] (db в FILE-MODE/review, не весь модуль — devops/metrics/backend тоже в db/) / files: [db/schema.sql, db/tools/,
db/data/] (твои базовые; per-task добавляй) / cc_task: none. Heartbeat текущий UTC.

=== 5. ЧТЕНИЕ ШИНЫ + ТЕКУЩИЙ КОНТЕКСТ ===
СВОЙ инбокс целиком; .coord/sessions/* (claims — особенно devops db/functions/01, db/setup; metrics db/migrations),
tail journal, push/request.md (FREEZE? стоп), backlog.md (раздел DB versioning + FF: B' seeding-migrate+REVOKE+RV-2).
Текущее: идёт hot-reload security-гейт (HALT на 234). DB-смежное в полёте: e17d898 catowner role, F-4 hash-integrity,
DB-REVOKE решение (A) + FF B' (seeding на privileged + REVOKE ccdashboard_user write на RTSGrid_Metric). Твоя экспертиза тут
пригодится — но сейчас просто ОЗНАКОМЬСЯ, не вмешивайся в активный гейт без сигнала координатора.

=== 6. ПОДТВЕРЖДЕНИЕ ===
Флашни в coordinator.md: slug, что прочитал (comms + §10 + DB-материал), территория (владеешь schema/tools/baseline +
ревьюишь migrations/functions), claims, статус, вопросы. Короткий дубль в чат.
