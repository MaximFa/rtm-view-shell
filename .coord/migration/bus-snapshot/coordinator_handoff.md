# Coordinator HANDOFF — LIVE resume state  (read FIRST on resume)
> Written 2026-07-03T18:10:00Z by coordinator-0703. Truth = object store + bus, not chat (NORM-CUR-13).

## GIT STATE
- Local v3 HEAD = **6945fc0** (db: reconcile_efmig_234.sql + role-dba §B). origin/v3 = **1b5778a**. Unpushed = 1 (6945fc0 — безвредный no-op артефакт, бил в таблицу-реликт; судьба — решение при следующем пуше/чистке).
- ⚠ UNCOMMITTED в WT (следующим docs/CC-коммитом, беречь от PD-007/clean): `.claude/skills/role-coordinator/role-coordinator.md` (КОНСТИТУЦИЯ §A+§B 2026-07-03).
- ⚠ `.coord/rejects.md` + `.coord/features.md` = конституционные реестры, лежат в gitignored .coord → НЕ переживут `git clean -x`. ОТКРЫТЫЙ ВОПРОС оператору: дать им git-дом (например docs/registers/) — предложить.

## 234 CONVERGE-DEPLOY — DONE (сервисная/DB-часть GREEN 2026-07-03)
- 234 = v3-пакет 0941 (c28291e бинарно == 1b5778a), Garnet (мигрирован с Memurai, пароль = старый скомпрометированный SF-SEC-001!), 3 сервиса Running/Automatic, HTTPS жив (cert insightense.com сохранён preserve'ом).
- DB: real EF history (**public."__ef_migrations_history"** — snake_case! НЕ "__EFMigrationsHistory"-реликт) = 27 (+4 reports); report_screens/user_reports/hist_*/arch_* live; SlThresholdSeconds есть; ix_rtsdata_interaction_tenant_updatetime valid; ownership app-схем у ccdashboard_user; audit-history baseline ('20260507135314_InitialCreate').
- Бэкапы 234: C:\RTMView-Ops\backup\rtmviewdb_pre_converge_03072026_1200.dump (9.7MB/96MB, валиден) + C:\RTMView\Backup\03072026_1218\ (app+db, скриптовый).
- ГЛАВНЫЕ ГРАБЛИ ДНЯ (уроки — в §B role-coordinator и у dba в очереди): (1) App EF history = public.__ef_migrations_history из InfrastructureServiceExtensions.cs:41 — ВСЕГДА читать имя из кода контекста (3 разных: App/Audit/BE); из-за реликта мы дропнули таблицы ПРИМЕНЁННОЙ 20260621 (спасла пустота таблиц). (2) probe-паттерны сверять с фактическими именами (fn_hist_* vs LIKE 'hist_%'). (3) ALTER SEQUENCE OWNER падает на linked-сиквенсах — исключать deptype a/i. (4) Схемные GRANT (01_init_db:33-41) — отдельный слой от ownership. (5) DB-INTAKE-01/§38.6 нуждается в doc-fix: reconcile обязан читать configured history-table names.

## СТАТУС ОПЕРАТОРА ПО 234: «визуально поднимается, ПО ФАКТУ — РЕДЖЕКТЫ»
**ПЕРВОЕ ДЕЙСТВИЕ нового координатора: продолжить приём списка реджектов оператора по 234.**
Принят пока ОДИН новый: **REP-MENU-PG** 🔴 (menu.reports отсутствует как класс: нет ключа в src (grep=0), нет в PG-редакторе/сидах, NavMenu без гейта; owner shell+bi). Остальные — оператор диктует.
Реестры (КОНСТИТУЦИЯ, см. ниже): .coord/rejects.md (полный статус: R7 Export .xlsx 🔴; PR234-1a config-null 🔴 probe c23ec1f в билде 234 — теперь можно ловить вживую; R1/R2/R9 🟡 ждут подтверждения; REPORTS-PG-GAPS 🟠) + .coord/features.md (F-SCALE-TOGGLE 🟡).

## КОНСТИТУЦИЯ КООРДИНАТОРА (operator 2026-07-03 — в role-coordinator §A)
Два реестра В ДОКУМЕНТАХ, не по памяти: rejects (.coord/rejects.md) + features (.coord/features.md). Каждый пункт: дата-время заявления · подтверждающие факты (скрин/проба/визуал — выбор координатора) · номер пуша подтверждённого закрытия. Закрытие — ТОЛЬКО словом оператора.

## ОЧЕРЕДИ (без параллели; оператор задаёт порядок)
1. Приём реджект-листа 234 (ТЕКУЩЕЕ) → триаж → стратегия → операторский ОК → диспатч.
2. dba: итоговый staging/fix_owner_and_reset_20260621_234.sql + §B-уроки + §38.6 doc-fix (CC-коммит, §4) — директива в его инбоксе 17:10Z.
3. QA smoke на 234 (после реджект-листа — оператор решит порядок).
4. Отложенное: реликт __EFMigrationsHistory (DROP?) · typo-метрики baseline-add (оператор ДА 13:15Z, post-deploy) · SF-SEC-001 ротация (+Garnet-пароль!) · Compare-копии db/tools vs devops/tools sync (devops) · QA BU∩PG live-verify · Export .xlsx (R7) · doc-debt TW (A-01/B-07/§16) · ЧП-флаг в §A не снят (оператор не отвечал).

## ПРАВИЛА ВЗАИМОДЕЙСТВИЯ С ОПЕРАТОРОМ (сегодняшние, поверх стандартных)
- ОДИН шаг = ОДИН run-box; НИЧЕГО впрок («не выдавай то, что не нужно сейчас запускать»).
- PS-квотинг: psql-запросы с "кавычками" — ТОЛЬКО через Set-Content файл + psql -f (одинарные @'...'@).
- Пароли в чат не вставлять (и мягко пресекать паст конфигов с секретами).
- Поки-луп + компакт-борд (узкий вид): fenced run-box текущего шага + короткий нумерованный список остального.

## HARD REMINDERS (стандарт)
- NO git push кроме tools/cc_prompt_push.md после кворума QA+Security+TW (§37). Все .coord/ записи Python+os.fsync; Edit tool BANNED. Верификация object-store, не mount git-status (§0.5). Все код-изменения через CC-промпты + §4 (§0.7). Не закрывать реджекты своим выводом — только словом оператора. Data-semantics → эскалация оператору. Rebuild-требующие правки батчить (validation = services-only).
