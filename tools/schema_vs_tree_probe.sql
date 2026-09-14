-- =====================================================================
-- SCHEMA-VS-TREE PROBE · автор backend-0912 · REV2 2026-09-13
-- Сверяет РЕАЛЬНУЮ базу с деревом v3 = d3cbb0c1211b799989fe2dcf0147331d8a72a64b:
--   26 таблиц db/schema.sql · 53 routines db/functions/*.sql (имя + вид + арность)
-- ЧИТАЮЩИЙ. Ни одного INSERT/UPDATE/DELETE в БАЗУ; два INSERT ниже — в CREATE TEMP,
-- они живут в сессии psql и исчезают с ней. DO-блок в §4 только печатает (RAISE NOTICE).
-- ЗАПУСКАТЬ С  -v ON_ERROR_STOP=1  (PR234-PROBE-01: иначе psql вернёт 0 на упавших запросах).
--
-- ЧЕМ ПОЛУЧЕНЫ СПИСКИ НИЖЕ — пере-снимается этими командами, список есть ИЗМЕРЕНИЕ, не данные:
--   таблицы (26):
--     git show v3:db/schema.sql | grep -oE 'CREATE TABLE public\.("[^"]+"|[A-Za-z0-9_]+)' \
--       | sed 's/CREATE TABLE public\.//;s/"//g' | sort -u
--     контроль: grep -c 'CREATE TABLE public\.' = 26 · в кавычках 24 · без кавычек 2
--       (:732 db_patch_history, :746 metric_deploy_log — REV1 их ТЕРЯЛ)
--     негативная половина предиката: grep -c 'CREATE TABLE public."ThisMustNotExist"' = 0
--   routines (53):
--     regex CREATE (OR REPLACE )?(FUNCTION|PROCEDURE) (public.)?"?имя"? с подсчётом
--     аргументов по верхнему уровню скобок; контроль:
--     grep -cE 'CREATE (OR REPLACE )?(FUNCTION|PROCEDURE)' = 53 (REV1 давал 51 — терял
--     public.fn_daytrendagentstatus и public.fn_daytrendinteractions)
--
-- ОЖИДАНИЯ, НАЗВАННЫЕ ДО ЗАМЕРА:
--   §0  порт печатает САМА база. 5433 = наша целевая, 5432 = старая. Руками не подставлять.
--   §1  TABLES:   in_both 26 · missing_in_db 0 · extra_in_db 0
--   §2  ROUTINES: in_both 53 · missing_in_db 0 · kind_mismatch 0
--                 (extra_in_db печатается, отказом НЕ является)
--   §3  CONTROL:  четыре строки. Две отрицательные обязаны сказать «нет», две положительные —
--                 «да». Хоть одна не та — прибор сломан, §1-§2 НЕ ЧИТАТЬ.
--   §4  SEQ:      по каждой последовательности last_value >= max(id).
--                 Нецелочисленный ключ печатается как SKIPPED, а не пропускается молча.
-- Любое другое число — расхождение: печатать как есть и докладывать, НЕ подгонять.
-- =====================================================================

\echo '=== §0 IDENTIFICATION (база называет себя сама) ==='
SELECT current_database()    AS db,
       inet_server_port()    AS port,
       inet_server_addr()    AS server_addr,
       current_user          AS usr,
       current_schemas(true) AS schemas,
       version()             AS version;

CREATE TEMP TABLE tree_tables(name text PRIMARY KEY);
INSERT INTO tree_tables(name) VALUES
  ('NGC_AgentGroups'),
  ('NGC_BusinessUnit'),
  ('NGC_BusinessUnitQueueClassification'),
  ('NGC_BusinessUnitSupergroup'),
  ('NGC_Queues'),
  ('NGC_Site'),
  ('NGC_Supergroup'),
  ('NGC_SupergroupAgentgroup'),
  ('NGC_UserAgentgroup'),
  ('RTSData_ChatMessage'),
  ('RTSData_Interaction'),
  ('RTSData_UserStatus'),
  ('RTSData_UserStatusLog'),
  ('RTSGrid_Cell'),
  ('RTSGrid_Column'),
  ('RTSGrid_Grid'),
  ('RTSGrid_Metric'),
  ('RTSGrid_MetricTranslation'),
  ('RTSGrid_Row'),
  ('RTSGrid_Statistic'),
  ('RTSGrid_UserStatus'),
  ('RTSUserGrid_Column'),
  ('RTSUserGrid_ColumnsSet'),
  ('RTSUserGrid_Grid'),
  ('db_patch_history'),
  ('metric_deploy_log');

CREATE TEMP TABLE tree_routines(name text, kind "char", nargs int);
INSERT INTO tree_routines(name, kind, nargs) VALUES
  ('NGC_CreateBusinessUnit','f',3),
  ('NGC_CreateBusinessUnit','f',5),
  ('NGC_CreateBusinessUnitQueueClassificationMapping','p',5),
  ('NGC_CreateBusinessUnitSupergroupMapping','p',4),
  ('NGC_CreateSupergroup','f',3),
  ('NGC_CreateSupergroup','f',4),
  ('NGC_CreateSupergroup','p',5),
  ('NGC_CreateSupergroupAgentgroupMapping','p',4),
  ('NGC_DeleteBusinessUnit','p',2),
  ('NGC_DeleteBusinessUnitQueueClassificationMapping','f',3),
  ('NGC_DeleteBusinessUnitQueueClassificationMapping','p',4),
  ('NGC_DeleteBusinessUnitSupergroupMapping','p',3),
  ('NGC_DeleteSupergroup','p',2),
  ('NGC_DeleteSupergroupAgentgroupMapping','p',3),
  ('NGC_DeleteUserAgentgroup','p',3),
  ('NGC_GetBusinessUnitIdByName','f',2),
  ('NGC_GetBusinessUnitQueueClassificationTable','f',1),
  ('NGC_GetBusinessUnitSupergroupTable','f',1),
  ('NGC_GetBusinessUnitTable','f',1),
  ('NGC_GetCellsByDataGrid','f',1),
  ('NGC_GetDataGrid','f',1),
  ('NGC_GetOrCreateAgentGroup','p',3),
  ('NGC_GetOrCreateQueue','p',3),
  ('NGC_GetSiteTable','f',1),
  ('NGC_GetSupergroupAgentgroupTable','f',1),
  ('NGC_GetSupergroupIdByName','f',2),
  ('NGC_GetSupergroupTable','f',1),
  ('NGC_ModifyBusinessUnit','p',4),
  ('NGC_ModifySupergroup','p',4),
  ('NGC_SetUserAgentgroup','p',3),
  ('RTSData_GetInteractions','f',1),
  ('RTSData_GetInteractions','f',2),
  ('RTSData_GetUsersStatuses','f',1),
  ('RTSData_GetUsersStatuses','f',2),
  ('RTSData_MidnightClear','f',1),
  ('RTSData_SetChatMessage','p',14),
  ('RTSData_SetInteraction','p',48),
  ('RTSData_SetUserStatus','p',15),
  ('RTSData_getInteractions','f',1),
  ('RTSData_getInteractions','f',2),
  ('RTSData_getUsersStatuses','f',1),
  ('RTSData_getUsersStatuses','f',2),
  ('RTSGrid_GetAllMetrics','f',0),
  ('RTSGrid_GetAllStatistics','f',0),
  ('RTSGrid_GetAllUnionQueueClassifications','f',1),
  ('RTSGrid_GetAllUnionUserGroups','f',1),
  ('RTSGrid_GetDataCells','f',0),
  ('RTSGrid_GetStatisticCells','f',0),
  ('RTSGrid_GetUnionUsersMetrics','f',0),
  ('RTSUserGrid_GetAllGrids','f',0),
  ('RTSUserView_GetHTMLSettings','f',0),
  ('fn_daytrendagentstatus','f',4),
  ('fn_daytrendinteractions','f',4);

\echo ''
\echo '=== §3 CONTROL — читать ПЕРВЫМ. Ожидание: no / no / yes / yes ==='
SELECT 'negative table   (ThisTableMustNotExist_QGRID)' AS probe,
       CASE WHEN to_regclass('public."ThisTableMustNotExist_QGRID"') IS NULL
            THEN 'no (ok)' ELSE 'YES — ПРИБОР СЛОМАН' END AS answer
UNION ALL
SELECT 'negative routine (ThisRoutineMustNotExist_QGRID)',
       CASE WHEN NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                             WHERE n.nspname='public' AND p.proname='ThisRoutineMustNotExist_QGRID')
            THEN 'no (ok)' ELSE 'YES — ПРИБОР СЛОМАН' END
UNION ALL
SELECT 'positive table   (RTSGrid_Cell должна быть)',
       CASE WHEN to_regclass('public."RTSGrid_Cell"') IS NOT NULL
            THEN 'yes (ok)' ELSE 'NO — либо не та база, либо join не работает' END
UNION ALL
SELECT 'positive join    (tree_tables x pg_class > 0)',
       CASE WHEN (SELECT count(*) FROM tree_tables t
                  JOIN pg_class c ON c.relname = t.name
                  JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public') > 0
            THEN 'yes (ok)' ELSE 'NO — join не сработал, missing 0 ничего не значит' END;

\echo ''
\echo '=== §1 TABLES: дерево против базы (ожидание 26 / 0 / 0) ==='
WITH db_t AS (
  SELECT c.relname::text AS name
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
)
SELECT
  (SELECT count(*) FROM tree_tables t JOIN db_t d ON d.name = t.name)             AS in_both,
  (SELECT count(*) FROM tree_tables t WHERE NOT EXISTS
     (SELECT 1 FROM db_t d WHERE d.name = t.name))                                AS missing_in_db,
  (SELECT count(*) FROM db_t d
     WHERE d.name ~ '^(NGC_|RTSGrid_|RTSData_|RTSUserGrid_|db_patch_|metric_deploy_)'
       AND d.name NOT IN (SELECT name FROM tree_tables))                          AS extra_in_db;

\echo '--- поимённо: есть в дереве, НЕТ в базе (ожидание: пусто)'
SELECT t.name FROM tree_tables t
WHERE NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='public' AND c.relkind='r' AND c.relname = t.name)
ORDER BY 1;

\echo '--- поимённо: backend-таблица есть в БАЗЕ, нет в дереве (ожидание: пусто)'
SELECT c.relname AS name FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r'
  AND c.relname ~ '^(NGC_|RTSGrid_|RTSData_|RTSUserGrid_|db_patch_|metric_deploy_)'
  AND c.relname NOT IN (SELECT name FROM tree_tables)
ORDER BY 1;

\echo ''
\echo '=== §2 ROUTINES: дерево против базы (ожидание 53 / 0 / 0) ==='
WITH db_r AS (
  SELECT p.proname::text AS name, p.prokind AS kind, p.pronargs AS nargs
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
)
SELECT
  (SELECT count(*) FROM tree_routines t JOIN db_r d
     ON d.name=t.name AND d.kind=t.kind AND d.nargs=t.nargs)                      AS in_both,
  (SELECT count(*) FROM tree_routines t WHERE NOT EXISTS
     (SELECT 1 FROM db_r d WHERE d.name=t.name AND d.kind=t.kind AND d.nargs=t.nargs))
                                                                                  AS missing_in_db,
  (SELECT count(*) FROM tree_routines t JOIN db_r d
     ON d.name=t.name AND d.nargs=t.nargs WHERE d.kind <> t.kind)                 AS kind_mismatch,
  (SELECT count(*) FROM db_r d
     WHERE d.name ~ '^(NGC_|RTSData_|RTSGrid_|fn_)' AND NOT EXISTS
       (SELECT 1 FROM tree_routines t
        WHERE t.name=d.name AND t.kind=d.kind AND t.nargs=d.nargs))               AS extra_in_db;

\echo '--- поимённо: есть в дереве, НЕТ в базе (ожидание: пусто)'
SELECT t.name, t.kind, t.nargs FROM tree_routines t
WHERE NOT EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname=t.name AND p.prokind=t.kind AND p.pronargs=t.nargs)
ORDER BY 1,3;

\echo '--- ⚠ имя и арность совпали, ВИД другой: FUNCTION вместо PROCEDURE = RTM-SEC-002, 42809 на КАЖДОМ событии RTM'
SELECT t.name, t.nargs, t.kind AS tree_kind, p.prokind AS db_kind
FROM tree_routines t
JOIN pg_proc p ON p.proname = t.name AND p.pronargs = t.nargs
JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
WHERE p.prokind <> t.kind
ORDER BY 1,2;

\echo '--- поимённо: routine есть в БАЗЕ, нет в дереве (печать, НЕ отказ)'
SELECT p.proname AS name, p.prokind AS kind, p.pronargs AS nargs
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname ~ '^(NGC_|RTSData_|RTSGrid_|fn_)'
  AND NOT EXISTS (SELECT 1 FROM tree_routines t
    WHERE t.name=p.proname AND t.kind=p.prokind AND t.nargs=p.pronargs)
ORDER BY 1,3;

\echo ''
\echo '=== §4 SEQUENCES: last_value против max(id), ключ и ТИП берутся из information_schema ==='
\echo '    (нецелочисленный ключ -> SKIPPED явной строкой; обход НЕ прерывается)'
DO $$
DECLARE
  r         record;
  v_seq     text;
  v_last    bigint;
  v_called  boolean;
  v_max     bigint;
  n_ok      int := 0;
  n_behind  int := 0;
  n_skipped int := 0;
BEGIN
  FOR r IN
    SELECT c.relname AS tbl, a.attname AS col, format_type(a.atttypid, a.atttypmod) AS coltype
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    JOIN pg_constraint k ON k.conrelid = c.oid AND k.contype = 'p' AND a.attnum = ANY (k.conkey)
    WHERE c.relkind = 'r'
      AND c.relname ~ '^(RTSGrid_|RTSUserGrid_|RTSData_|NGC_)'
      AND array_length(k.conkey, 1) = 1
    ORDER BY c.relname
  LOOP
    IF r.coltype NOT IN ('integer','bigint','smallint') THEN
      RAISE NOTICE 'SKIPPED  % .% type=% — предикат last_value>=max не применим к нецелочисленному ключу',
                   r.tbl, r.col, r.coltype;
      n_skipped := n_skipped + 1;
      CONTINUE;
    END IF;

    v_seq := pg_get_serial_sequence(format('public.%I', r.tbl), r.col);
    IF v_seq IS NULL THEN
      RAISE NOTICE 'SKIPPED  % .% — целочисленный ключ БЕЗ последовательности (не identity/serial)',
                   r.tbl, r.col;
      n_skipped := n_skipped + 1;
      CONTINUE;
    END IF;

    EXECUTE format('SELECT last_value, is_called FROM %s', v_seq) INTO v_last, v_called;
    EXECUTE format('SELECT max(%I) FROM public.%I', r.col, r.tbl) INTO v_max;

    IF v_max IS NULL THEN
      RAISE NOTICE 'EMPTY    % .% last_value=% is_called=% — строк нет, предикат неприменим',
                   r.tbl, r.col, v_last, v_called;
      n_skipped := n_skipped + 1;
    ELSIF v_last >= v_max THEN
      RAISE NOTICE 'OK       % .% last_value=% is_called=% max=%', r.tbl, r.col, v_last, v_called, v_max;
      n_ok := n_ok + 1;
    ELSE
      RAISE NOTICE 'BEHIND   % .% last_value=% is_called=% max=%  <-- 23505 ЖДЁТ ЗДЕСЬ',
                   r.tbl, r.col, v_last, v_called, v_max;
      n_behind := n_behind + 1;
    END IF;
  END LOOP;

  RAISE NOTICE '--- SEQ ИТОГ: ok=% behind=% skipped=%  (ожидание: behind=0)', n_ok, n_behind, n_skipped;
END $$;

\echo '=== END OF PROBE ==='
