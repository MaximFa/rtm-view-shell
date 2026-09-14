-- =====================================================================
-- COLUMN-DRIFT PROBE · автор backend-0912 · 2026-09-13
-- Сверяет СТОЛБЦЫ реальной базы с деревом v3 = d3cbb0c1211b799989fe2dcf0147331d8a72a64b:
--   26 таблиц db/schema.sql, 255 столбцов (имя + тип).
-- Предмет: дрейф, однажды уже случившийся — «RTSGrid_Metric without CatalogCategory»
-- (шапка Migrations/App/20260712223405_DropAppOwnedBackendTables.cs). В проде его нечем поймать:
-- beDb.MigrateAsync там не зовётся (DatabaseInitializer.cs:51-56), шва проверки нет,
-- проявляется «column does not exist» на живом экране.
-- ЧИТАЮЩИЙ. В базу не пишет: единственный INSERT — в CREATE TEMP, живёт в сессии psql.
-- ЗАПУСКАТЬ С  -v ON_ERROR_STOP=1  (PR234-PROBE-01).
--
-- ЧЕМ ПОЛУЧЕН СПИСОК — список есть ИЗМЕРЕНИЕ, не данные; пере-снимается так:
--   git show v3:db/schema.sql  ->  разбор блоков  CREATE TABLE public.(<"Имя"> | <имя>) ( ... );
--   строки тела, кроме CONSTRAINT/PRIMARY KEY/UNIQUE/FOREIGN KEY/CHECK; из каждой берётся имя
--   столбца и тип ДО  NOT NULL | NULL | DEFAULT | GENERATED | COLLATE.
--   КОНТРОЛЬНЫЕ ЧИСЛА (два независимых способа, обязаны совпасть):
--     разбор блоков                                          -> 26 таблиц, 255 столбцов
--     grep -cE '^    ("[A-Za-z0-9_]+"|[a-z_][a-z0-9_]*) '     -> 255
--   ПОЗИТИВНАЯ ПОЛОВИНА СБОРЩИКА: RTSGrid_Metric|CatalogCategory найден (1) — то есть сборщик
--     умеет находить именно тот столбец, вокруг которого предмет; RTSGrid_Metric = 21 столбец;
--     таблицы БЕЗ кавычек разобраны (db_patch_history 2, metric_deploy_log 3) — REV1 табличного
--     прибора их терял, здесь проверено отдельно.
--   НЕГАТИВНАЯ ПОЛОВИНА СБОРЩИКА: ThisColumnMustNotExist -> 0.
--   Тип сравнивается в форме format_type(atttypid, atttypmod) — pg_dump и каталог печатают её
--   одинаково ('integer', 'character varying(100)', 'timestamp with time zone').
--
-- ОЖИДАНИЯ, НАЗВАННЫЕ ДО ЗАМЕРА:
--   §0  порт и имя базы печатает САМА база. 5433 = наша целевая, 5432 = старая.
--   §1  CONTROL: 4 строки — no / no / yes / yes. Не те — прибор сломан, §2-§3 НЕ ЧИТАТЬ.
--   §2  COLUMNS: in_both 255 · missing_in_db 0 · type_mismatch 0 · extra_in_db 0
--       tables_seen 26 из 26 ожидаемых — обход обязан сказать, сколько таблиц он реально прошёл.
--   §3  поимённые списки по каждому исходу — все четыре ПУСТЫ.
-- Любое другое число — расхождение: печатать как есть и докладывать, НЕ подгонять.
-- =====================================================================

\echo '=== §0 IDENTIFICATION (база называет себя сама) ==='
SELECT current_database() AS db, inet_server_port() AS port, inet_server_addr() AS server_addr,
       current_user AS usr, version() AS version;

CREATE TEMP TABLE tree_cols(tbl text, col text, typ text);
INSERT INTO tree_cols(tbl, col, typ) VALUES
  ('NGC_AgentGroups','Id','uuid CONSTRAINT "ngc_AgentGroups_Id_not_null"'),
  ('NGC_AgentGroups','TenantId','uuid CONSTRAINT "ngc_AgentGroups_TenantId_not_null"'),
  ('NGC_AgentGroups','ExternalId','character varying(100) CONSTRAINT "ngc_AgentGroups_ExternalId_not_null"'),
  ('NGC_AgentGroups','Name','character varying(200) CONSTRAINT "ngc_AgentGroups_Name_not_null"'),
  ('NGC_AgentGroups','IsActive','boolean CONSTRAINT "ngc_AgentGroups_IsActive_not_null"'),
  ('NGC_BusinessUnit','BusinessUnitId','integer'),
  ('NGC_BusinessUnit','TenantId','uuid'),
  ('NGC_BusinessUnit','BusinessUnitName','character varying(100)'),
  ('NGC_BusinessUnit','Description','text'),
  ('NGC_BusinessUnit','CreatedDatetime','timestamp with time zone'),
  ('NGC_BusinessUnit','CreatedBy','character varying(100)'),
  ('NGC_BusinessUnit','SiteId','character varying(50)'),
  ('NGC_BusinessUnitQueueClassification','BusinessUnitId','integer'),
  ('NGC_BusinessUnitQueueClassification','QueueId','character varying(100)'),
  ('NGC_BusinessUnitQueueClassification','TenantId','uuid'),
  ('NGC_BusinessUnitQueueClassification','ClassificationId','character varying(100)'),
  ('NGC_BusinessUnitQueueClassification','CreatedDatetime','timestamp with time zone'),
  ('NGC_BusinessUnitQueueClassification','CreatedBy','character varying(100)'),
  ('NGC_BusinessUnitSupergroup','BusinessUnitId','integer'),
  ('NGC_BusinessUnitSupergroup','SupergroupId','integer'),
  ('NGC_BusinessUnitSupergroup','TenantId','uuid'),
  ('NGC_BusinessUnitSupergroup','CreatedDatetime','timestamp with time zone'),
  ('NGC_BusinessUnitSupergroup','CreatedBy','character varying(100)'),
  ('NGC_Queues','Id','uuid CONSTRAINT "ngc_queues_Id_not_null"'),
  ('NGC_Queues','TenantId','uuid CONSTRAINT "ngc_queues_TenantId_not_null"'),
  ('NGC_Queues','ExternalId','character varying(100) CONSTRAINT "ngc_queues_ExternalId_not_null"'),
  ('NGC_Queues','Name','character varying(200) CONSTRAINT "ngc_queues_Name_not_null"'),
  ('NGC_Queues','IsActive','boolean CONSTRAINT "ngc_queues_IsActive_not_null"'),
  ('NGC_Site','SiteId','character varying(50) CONSTRAINT "ngc_site_SiteId_not_null"'),
  ('NGC_Site','TenantId','uuid CONSTRAINT "ngc_site_TenantId_not_null"'),
  ('NGC_Site','SiteName','character varying(200)'),
  ('NGC_Site','Description','character varying(500)'),
  ('NGC_Site','TimeZone','character varying(10)'),
  ('NGC_Site','ClearTime','character varying(5)'),
  ('NGC_Supergroup','SupergroupId','integer CONSTRAINT "ngc_supergroup_SupergroupId_not_null"'),
  ('NGC_Supergroup','TenantId','uuid CONSTRAINT "ngc_supergroup_TenantId_not_null"'),
  ('NGC_Supergroup','SupergroupName','character varying(200)'),
  ('NGC_Supergroup','Description','character varying(500)'),
  ('NGC_Supergroup','CreatedDatetime','timestamp with time zone'),
  ('NGC_Supergroup','CreatedBy','character varying(100)'),
  ('NGC_Supergroup','SupergroupIdOld','integer'),
  ('NGC_SupergroupAgentgroup','Id','integer'),
  ('NGC_SupergroupAgentgroup','SupergroupId','integer'),
  ('NGC_SupergroupAgentgroup','AgentgroupId','character varying(100)'),
  ('NGC_SupergroupAgentgroup','TenantId','uuid'),
  ('NGC_SupergroupAgentgroup','CreatedDatetime','timestamp with time zone'),
  ('NGC_SupergroupAgentgroup','CreatedBy','character varying(100)'),
  ('NGC_UserAgentgroup','Id','integer'),
  ('NGC_UserAgentgroup','UserId','character varying(100)'),
  ('NGC_UserAgentgroup','AgentgroupId','character varying(100)'),
  ('NGC_UserAgentgroup','TenantId','uuid'),
  ('NGC_UserAgentgroup','CreatedDatetime','timestamp with time zone'),
  ('NGC_UserAgentgroup','CreatedBy','character varying(100)'),
  ('RTSData_ChatMessage','MessageId','character varying(100)'),
  ('RTSData_ChatMessage','ServerId','character varying(50)'),
  ('RTSData_ChatMessage','OnDate','character varying(50)'),
  ('RTSData_ChatMessage','InteractionId','character varying(100)'),
  ('RTSData_ChatMessage','SegmentId','integer'),
  ('RTSData_ChatMessage','UserId','character varying(100)'),
  ('RTSData_ChatMessage','MsgDirection','character varying(50)'),
  ('RTSData_ChatMessage','Sender','character varying(200)'),
  ('RTSData_ChatMessage','Recipient','character varying(200)'),
  ('RTSData_ChatMessage','Body','text'),
  ('RTSData_ChatMessage','DeliveryStatus','character varying(50)'),
  ('RTSData_ChatMessage','UpdateTime','timestamp with time zone'),
  ('RTSData_ChatMessage','TimeStamp','timestamp with time zone'),
  ('RTSData_Interaction','TenantId','uuid'),
  ('RTSData_Interaction','InteractionId','character varying(50)'),
  ('RTSData_Interaction','Segment','integer'),
  ('RTSData_Interaction','OnDate','character varying(50)'),
  ('RTSData_Interaction','ServerId','character varying(50)'),
  ('RTSData_Interaction','Workgroup','character varying(100)'),
  ('RTSData_Interaction','UserId','character varying(50)'),
  ('RTSData_Interaction','ClassificationCode','text'),
  ('RTSData_Interaction','InteractionType','character varying(50)'),
  ('RTSData_Interaction','CallType','character varying(50)'),
  ('RTSData_Interaction','Direction','character varying(50)'),
  ('RTSData_Interaction','CustomCallData','text'),
  ('RTSData_Interaction','IsTransferred','boolean'),
  ('RTSData_Interaction','IsAnswered','boolean'),
  ('RTSData_Interaction','IsInQueue','boolean'),
  ('RTSData_Interaction','IsTalk','boolean'),
  ('RTSData_Interaction','IsAbandoned','boolean'),
  ('RTSData_Interaction','TimeInQueue','integer'),
  ('RTSData_Interaction','TalkTime','integer'),
  ('RTSData_Interaction','InQueueDateTime','timestamp with time zone'),
  ('RTSData_Interaction','AnsweredDateTime','timestamp with time zone'),
  ('RTSData_Interaction','UpdateTime','timestamp with time zone'),
  ('RTSData_Interaction','LastUserId','character varying(50)'),
  ('RTSData_Interaction','LastWorkgroup','character varying(100)'),
  ('RTSData_Interaction','IsMessaging','boolean'),
  ('RTSData_Interaction','RemoteAddress','character varying(50)'),
  ('RTSData_Interaction','IsCallbackRequest','boolean'),
  ('RTSData_Interaction','TimeZone','character varying(10)'),
  ('RTSData_Interaction','CustomCallData1','text'),
  ('RTSData_Interaction','CustomCallData2','text'),
  ('RTSData_Interaction','CustomCallData3','text'),
  ('RTSData_Interaction','CustomCallData4','text'),
  ('RTSData_Interaction','CustomCallData5','text'),
  ('RTSData_Interaction','CustomCallData6','text'),
  ('RTSData_Interaction','CustomCallData7','text'),
  ('RTSData_Interaction','CustomCallData8','text'),
  ('RTSData_Interaction','CustomCallData9','text'),
  ('RTSData_Interaction','CustomCallData10','text'),
  ('RTSData_Interaction','CustomCallData11','text'),
  ('RTSData_Interaction','CustomCallData12','text'),
  ('RTSData_Interaction','CustomCallData13','text'),
  ('RTSData_Interaction','CustomCallData14','text'),
  ('RTSData_Interaction','CustomCallData15','text'),
  ('RTSData_Interaction','CustomCallData16','text'),
  ('RTSData_Interaction','CustomCallData17','text'),
  ('RTSData_Interaction','CustomCallData18','text'),
  ('RTSData_Interaction','CustomCallData19','text'),
  ('RTSData_Interaction','CustomCallData20','text'),
  ('RTSData_UserStatus','TenantId','uuid'),
  ('RTSData_UserStatus','UserId','character varying(100)'),
  ('RTSData_UserStatus','StatusId','character varying(100)'),
  ('RTSData_UserStatus','ServerId','character varying(50)'),
  ('RTSData_UserStatus','OnDate','character varying(50)'),
  ('RTSData_UserStatus','StatusName','character varying(100)'),
  ('RTSData_UserStatus','StatusGroup','character varying(100)'),
  ('RTSData_UserStatus','TotalDuration','integer'),
  ('RTSData_UserStatus','MaxDuraction','integer'),
  ('RTSData_UserStatus','TotalCount','integer'),
  ('RTSData_UserStatus','UpdateTime','timestamp with time zone'),
  ('RTSData_UserStatus','DisplayName','character varying(100)'),
  ('RTSData_UserStatus','TimeZone','character varying(10)'),
  ('RTSData_UserStatusLog','Id','integer'),
  ('RTSData_UserStatusLog','TenantId','uuid'),
  ('RTSData_UserStatusLog','UserId','character varying(100)'),
  ('RTSData_UserStatusLog','StatusId','character varying(100)'),
  ('RTSData_UserStatusLog','ServerId','character varying(50)'),
  ('RTSData_UserStatusLog','OnDate','character varying(50)'),
  ('RTSData_UserStatusLog','StartTime','timestamp with time zone'),
  ('RTSData_UserStatusLog','EndTime','timestamp with time zone'),
  ('RTSData_UserStatusLog','Duration','bigint'),
  ('RTSData_UserStatusLog','UpdateTime','timestamp with time zone'),
  ('RTSData_UserStatusLog','TimeZone','character varying(10)'),
  ('RTSData_UserStatusLog','StatusGroup','character varying(50)'),
  ('RTSGrid_Cell','CellId','integer'),
  ('RTSGrid_Cell','RowId','integer'),
  ('RTSGrid_Cell','ColumnId','integer'),
  ('RTSGrid_Cell','ColNumber','integer'),
  ('RTSGrid_Cell','UnionId','integer'),
  ('RTSGrid_Cell','StyleId','integer'),
  ('RTSGrid_Cell','CellType','character varying(50)'),
  ('RTSGrid_Cell','Value','character varying(500)'),
  ('RTSGrid_Cell','Tooltip','character varying(500)'),
  ('RTSGrid_Cell','OnClick','character varying(500)'),
  ('RTSGrid_Cell','ThresholdSetId','integer'),
  ('RTSGrid_Cell','NewRowId','integer'),
  ('RTSGrid_Cell','OldRowId','integer'),
  ('RTSGrid_Column','ColumnId','integer'),
  ('RTSGrid_Column','GridId','integer'),
  ('RTSGrid_Column','ColumnNumber','integer'),
  ('RTSGrid_Column','CellTemplateId','integer'),
  ('RTSGrid_Grid','GridId','integer'),
  ('RTSGrid_Grid','UnionId','integer'),
  ('RTSGrid_Grid','StyleId','integer'),
  ('RTSGrid_Grid','Title','character varying(100)'),
  ('RTSGrid_Grid','ThresholdScript','text'),
  ('RTSGrid_Metric','MetricId','character varying(100) CONSTRAINT "rtsgrid_metric_MetricId_not_null"'),
  ('RTSGrid_Metric','Description','text'),
  ('RTSGrid_Metric','DataType','character varying(50) CONSTRAINT "rtsgrid_metric_DataType_not_null"'),
  ('RTSGrid_Metric','MetricFunction','character varying(200) CONSTRAINT "rtsgrid_metric_MetricFunction_not_null"'),
  ('RTSGrid_Metric','MetricParameter','character varying(200) CONSTRAINT "rtsgrid_metric_MetricParameter_not_null"'),
  ('RTSGrid_Metric','MetricFormat','character varying(100)'),
  ('RTSGrid_Metric','DefaultValue','character varying(100)'),
  ('RTSGrid_Metric','ValueType','character varying(20)'),
  ('RTSGrid_Metric','MetricType','character varying(20)'),
  ('RTSGrid_Metric','CatalogCategory','character varying(20)'),
  ('RTSGrid_Metric','CatalogNotes','text'),
  ('RTSGrid_Metric','CatalogStatus','character varying(20)'),
  ('RTSGrid_Metric','Channel','character varying(20)'),
  ('RTSGrid_Metric','Comparison','text'),
  ('RTSGrid_Metric','DisplayName','character varying(200)'),
  ('RTSGrid_Metric','Family','character varying(100)'),
  ('RTSGrid_Metric','LongDescription','text'),
  ('RTSGrid_Metric','ShortDescription','character varying(500)'),
  ('RTSGrid_Metric','StandardKpi','character varying(100)'),
  ('RTSGrid_Metric','StandardRef','character varying(200)'),
  ('RTSGrid_Metric','ThresholdSec','integer'),
  ('RTSGrid_MetricTranslation','MetricId','character varying(100)'),
  ('RTSGrid_MetricTranslation','Locale','character varying(10)'),
  ('RTSGrid_MetricTranslation','DisplayName','character varying(200)'),
  ('RTSGrid_MetricTranslation','ShortDescription','character varying(500)'),
  ('RTSGrid_MetricTranslation','LongDescription','text'),
  ('RTSGrid_MetricTranslation','Comparison','text'),
  ('RTSGrid_Row','RowId','integer'),
  ('RTSGrid_Row','GridId','integer'),
  ('RTSGrid_Row','RowNumber','integer'),
  ('RTSGrid_Row','UnionId','integer'),
  ('RTSGrid_Row','StyleId','integer'),
  ('RTSGrid_Row','ThresholdScript','text'),
  ('RTSGrid_Row','OldRowId','integer'),
  ('RTSGrid_Statistic','StatisticId','integer'),
  ('RTSGrid_Statistic','Category','character varying(100)'),
  ('RTSGrid_Statistic','Definition','character varying(500)'),
  ('RTSGrid_Statistic','ParamType1','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue1','character varying(500)'),
  ('RTSGrid_Statistic','ParamType2','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue2','character varying(500)'),
  ('RTSGrid_Statistic','ParamType3','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue3','character varying(500)'),
  ('RTSGrid_Statistic','ParamType4','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue4','character varying(500)'),
  ('RTSGrid_Statistic','ParamType5','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue5','character varying(500)'),
  ('RTSGrid_Statistic','ParamType6','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue6','character varying(500)'),
  ('RTSGrid_Statistic','ParamType7','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue7','character varying(500)'),
  ('RTSGrid_Statistic','ParamType8','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue8','character varying(500)'),
  ('RTSGrid_Statistic','ParamType9','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue9','character varying(500)'),
  ('RTSGrid_Statistic','ParamType10','character varying(100)'),
  ('RTSGrid_Statistic','ParamValue10','character varying(500)'),
  ('RTSGrid_UserStatus','UserId','character varying(100)'),
  ('RTSGrid_UserStatus','StatusId','character varying(100)'),
  ('RTSGrid_UserStatus','StatusName','character varying(100)'),
  ('RTSGrid_UserStatus','StatusGroup','character varying(100)'),
  ('RTSGrid_UserStatus','TotalDuration','integer'),
  ('RTSGrid_UserStatus','MaxDuraction','integer'),
  ('RTSGrid_UserStatus','TotalCount','integer'),
  ('RTSGrid_UserStatus','SourceServer','character varying(50)'),
  ('RTSGrid_UserStatus','OnDate','character varying(50)'),
  ('RTSUserGrid_Column','ColumnId','integer'),
  ('RTSUserGrid_Column','ColumnsSetId','integer'),
  ('RTSUserGrid_Column','Title','character varying(100)'),
  ('RTSUserGrid_Column','MetricId','character varying(100)'),
  ('RTSUserGrid_Column','StyleId','integer'),
  ('RTSUserGrid_Column','ColumnsOrder','integer'),
  ('RTSUserGrid_ColumnsSet','ColumnsSetId','integer'),
  ('RTSUserGrid_ColumnsSet','Title','character varying(100)'),
  ('RTSUserGrid_ColumnsSet','Description','text'),
  ('RTSUserGrid_ColumnsSet','Direction','character varying(10)'),
  ('RTSUserGrid_Grid','GridId','integer'),
  ('RTSUserGrid_Grid','UnionId','integer'),
  ('RTSUserGrid_Grid','StyleId','integer'),
  ('RTSUserGrid_Grid','Title','character varying(100)'),
  ('RTSUserGrid_Grid','RowsFilter','character varying(300)'),
  ('RTSUserGrid_Grid','PageSize','integer'),
  ('RTSUserGrid_Grid','ColumnsSetId','integer'),
  ('RTSUserGrid_Grid','ThresholdScript','text'),
  ('RTSUserGrid_Grid','RowsFilterNew','character varying(300)'),
  ('RTSUserGrid_Grid','NoRecordsText','text'),
  ('RTSUserGrid_Grid','AllowPaging','boolean'),
  ('RTSUserGrid_Grid','AllowScroll','boolean'),
  ('RTSUserGrid_Grid','TextDirection','character varying(5)'),
  ('db_patch_history','migration_name','text'),
  ('db_patch_history','applied_at','timestamp with time zone'),
  ('metric_deploy_log','MetricId','text'),
  ('metric_deploy_log','DeployedAt','timestamp with time zone'),
  ('metric_deploy_log','SourceCommit','text');

CREATE TEMP VIEW db_cols AS
SELECT c.relname::text AS tbl, a.attname::text AS col,
       format_type(a.atttypid, a.atttypmod)::text AS typ
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
WHERE c.relkind = 'r'
  AND c.relname IN (SELECT DISTINCT tbl FROM tree_cols);

\echo ''
\echo '=== §1 CONTROL — читать ПЕРВЫМ. Ожидание: no / no / yes / yes ==='
SELECT 'negative column  (ThisColumnMustNotExist_QGRID)' AS probe,
       CASE WHEN NOT EXISTS (SELECT 1 FROM db_cols WHERE col = 'ThisColumnMustNotExist_QGRID')
            THEN 'no (ok)' ELSE 'YES — ПРИБОР СЛОМАН' END AS answer
UNION ALL
SELECT 'negative table   (ThisTableMustNotExist_QGRID)',
       CASE WHEN to_regclass('public."ThisTableMustNotExist_QGRID"') IS NULL
            THEN 'no (ok)' ELSE 'YES — ПРИБОР СЛОМАН' END
UNION ALL
SELECT 'positive column  (RTSGrid_Cell.CellId должен быть)',
       CASE WHEN EXISTS (SELECT 1 FROM db_cols WHERE tbl='RTSGrid_Cell' AND col='CellId')
            THEN 'yes (ok)' ELSE 'NO — либо не та база, либо view пуст' END
UNION ALL
SELECT 'positive join    (tree_cols x db_cols > 0)',
       CASE WHEN (SELECT count(*) FROM tree_cols t JOIN db_cols d
                  ON d.tbl=t.tbl AND d.col=t.col) > 0
            THEN 'yes (ok)' ELSE 'NO — join не сработал, missing 0 ничего не значит' END;

\echo ''
\echo '=== §2 COLUMNS: дерево против базы (ожидание 255 / 0 / 0 / 0, таблиц 26 из 26) ==='
SELECT
  (SELECT count(*) FROM tree_cols t JOIN db_cols d
     ON d.tbl=t.tbl AND d.col=t.col AND d.typ=t.typ)                        AS in_both,
  (SELECT count(*) FROM tree_cols t WHERE NOT EXISTS
     (SELECT 1 FROM db_cols d WHERE d.tbl=t.tbl AND d.col=t.col))           AS missing_in_db,
  (SELECT count(*) FROM tree_cols t JOIN db_cols d
     ON d.tbl=t.tbl AND d.col=t.col WHERE d.typ <> t.typ)                   AS type_mismatch,
  (SELECT count(*) FROM db_cols d WHERE NOT EXISTS
     (SELECT 1 FROM tree_cols t WHERE t.tbl=d.tbl AND t.col=d.col))         AS extra_in_db,
  (SELECT count(DISTINCT tbl) FROM db_cols)                                 AS tables_seen,
  (SELECT count(DISTINCT tbl) FROM tree_cols)                               AS tables_expected;

\echo ''
\echo '=== §3 ПОИМЁННО — все четыре списка ожидаются ПУСТЫМИ ==='
\echo '--- (а) есть в дереве, НЕТ в базе  [это и есть класс RTSGrid_Metric без CatalogCategory]'
SELECT t.tbl, t.col, t.typ FROM tree_cols t
WHERE NOT EXISTS (SELECT 1 FROM db_cols d WHERE d.tbl=t.tbl AND d.col=t.col)
ORDER BY 1,2;

\echo '--- (б) ТИП разошёлся'
SELECT t.tbl, t.col, t.typ AS tree_type, d.typ AS db_type
FROM tree_cols t JOIN db_cols d ON d.tbl=t.tbl AND d.col=t.col
WHERE d.typ <> t.typ
ORDER BY 1,2;

\echo '--- (в) есть в БАЗЕ, нет в дереве'
SELECT d.tbl, d.col, d.typ FROM db_cols d
WHERE NOT EXISTS (SELECT 1 FROM tree_cols t WHERE t.tbl=d.tbl AND t.col=d.col)
ORDER BY 1,2;

\echo '--- (г) таблицы дерева, которых в базе нет ВООБЩЕ (тогда её столбцы не попадут в (а) как отсутствующие поштучно — смотреть сюда)'
SELECT DISTINCT t.tbl FROM tree_cols t
WHERE to_regclass(format('public.%I', t.tbl)) IS NULL
ORDER BY 1;

\echo '=== END OF PROBE ==='
