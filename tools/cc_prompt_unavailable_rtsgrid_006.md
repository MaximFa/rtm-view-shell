# CC Task _006: UNAVAILABLE real-time RTSGrid metrics (6th status group)

> Adds the paired real-time RTSGrid_Metric rows for the UNAVAILABLE status group (the 6th group beyond
> the canonical AVAILABLE/ONPHONE/BREAK/PAPERWORK/TRAINING). Pairs the history metrics from _005
> (statuslog.unavailable_agents / _time_ms, committed 68e3c3f). UNBLOCKS daytrend P3 (_008), which pairs
> these RT metrics with the history outputs. THIS migration (_006) MUST land before P3's _008.
> Source spec: coordinator bus 2026-06-06 (UNAVAILABLE 6th-group plan).

## Mandatory — read before starting
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (§3 status groups, §4 add-metric rules, §10.2 functions)
Read file: .claude/skills/session-coord/session-coord.md
Only after reading: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP (known phantom may linger on mount; trust Windows/CC FS).

## Claims (file-mode, metrics-0605) — ALL my domain; NO ScreenEditorPage, NO EF migration (data only -> no BE-snapshot contention)
- db: db/migrations/20260606_006_unavailable_rtsgrid_metrics.sql (NEW), db/data/02_metrics.sql, db/data/05_metric_translations.sql
- docs: docs/metrics-catalog.ru-RU.json, docs/metrics-catalog.he-IL.json, docs/metrics-catalog.json
- tools: tools/gen_translation_backfill.py (reuse), tools/lint_metrics.py
- .claude: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (canonical groups 5->6; `git add -f`)

## Step 0 — §0.6a integrity + sync (§42.7.6) + coord sync block. Known false-M: db/data/*.sql, large .cs.

## Step 1 — Migration (NEW file, Python+fsync; named-column INSERT, idempotent)
`db/migrations/20260606_006_unavailable_rtsgrid_metrics.sql`:
```sql
-- 20260606_006_unavailable_rtsgrid_metrics: real-time RTSGrid metrics for the UNAVAILABLE status group.
-- Mirrors the BREAK-group metrics. Pairs _005 history (statuslog.unavailable_*). Idempotent.
INSERT INTO "RTSGrid_Metric"
 ("MetricId","Description","DataType","MetricFunction","MetricParameter","MetricFormat","DefaultValue","ValueType","MetricType",
  "CatalogCategory","CatalogStatus","Comparison","DisplayName","Family","LongDescription","ShortDescription","StandardKpi")
VALUES
 ('QueueLoginDataNumUnavailableUsers','Agent Group - Number of Agents in Unavailable State Group','UsersSummary','UsersInStatusGroupCount','UNAVAILABLE',NULL,NULL,'number','Data',
  'AgentGroup','active','Pairs the historical statuslog.unavailable_agents. State-level counters target specific states.','Agents in Unavailable Group','group.state_group_count','Real-time count of agents whose current status belongs to the UNAVAILABLE group (logged in but not available for interactions).','Number of agents currently in the UNAVAILABLE status group.','Shrinkage (real-time)'),
 ('MonAgentUnavailableDuration','Agent - Cumulative Unavailable Group Duration','User','TotalStatusGroupDuration','UNAVAILABLE',NULL,NULL,'time','Agent',
  'Agent','active','Percent-of-login counterpart: % Unavailable Time of Login. State-level (status "Unavailable") is MonAgentUnavailableStateDuration.','Cumulative Unavailable Duration','agent.duration','Cumulative time today in statuses of the UNAVAILABLE group. Pairs the historical statuslog.unavailable_time_ms.','Total time the agent spent in UNAVAILABLE-group states today.','Shrinkage (agent)'),
 ('MonAgentUnavailableDurationPct','Agent - Cumulative Unavailable Duration Percent','User','TotalStatusGroupPercent','UNAVAILABLE',NULL,NULL,'number','Agent',
  'Agent','active','Companions: % Available, % Break, % Paperwork, % Training, % Talk of login.','% Unavailable Time of Login','agent.percent','Cumulative UNAVAILABLE-group time divided by total login time.','Share of the agent''s login time spent in UNAVAILABLE-group states today.','Shrinkage % (agent)'),
 ('MonSumAgentsUnavailableDurationPercent','Agent Group - Percent of Agents in Unavailable State Group','UsersInteraction','UsersInStatusGroupDurationPercent','UNAVAILABLE','##0.00%',NULL,'number','Data',
  'AgentGroup','active','Per-agent counterpart: MonAgentUnavailableDurationPct.','% Time in Unavailable Group (group)','group.duration','Cumulative percentage for today: total UNAVAILABLE-group time divided by total logged-in time of the group.','Share of the group''s logged-in time spent in UNAVAILABLE-group states.','Shrinkage %')
ON CONFLICT ("MetricId") DO NOTHING;

SELECT "MetricId","MetricFunction","MetricParameter","MetricType" FROM "RTSGrid_Metric" WHERE "MetricParameter"='UNAVAILABLE' ORDER BY "MetricId";
```
Apply: `psql -U ccdashboard_user -d rtmviewdb -f db\migrations\20260606_006_unavailable_rtsgrid_metrics.sql` -> 4 rows added (200 vs 196 prior live... expect count = prior+4).

## Step 2 — Add EN cards to docs/metrics-catalog.json (keep the catalogue source complete)
Append the 4 new metrics to docs/metrics-catalog.json `metrics` (status active, fields matching the migration:
metricId, displayName, shortDescription, longDescription, comparison, category, family, standardKpi,
metricFunction, metricParameter, valueType, metricType, channel=null, thresholdSec=null, catalogStatus=active).
Keep metricCount accurate.

## Step 3 — Add ru/he translations for the 4 (then regen 05)
Append to docs/metrics-catalog.ru-RU.json and docs/metrics-catalog.he-IL.json (metrics array) these entries
(CC-terms English in parentheses; he is RTL):
RU:
 QueueLoginDataNumUnavailableUsers: displayName "Агенты в группе Unavailable", short "Число агентов, находящихся сейчас в статус-группе UNAVAILABLE.", long "Подсчёт в реальном времени агентов, чей текущий статус принадлежит группе UNAVAILABLE (в системе, но недоступны для обращений).", comparison "Парная к history-метрике statuslog.unavailable_agents."
 MonAgentUnavailableDuration: "Суммарная длительность Unavailable", "Суммарное время в статусах группы UNAVAILABLE за день.", "Накопленное за день время в статусах группы UNAVAILABLE. Парная к statuslog.unavailable_time_ms.", "Процентный аналог: «% времени Unavailable от логина»."
 MonAgentUnavailableDurationPct: "% времени Unavailable от логина", "Доля времени логина агента в статусах группы UNAVAILABLE за день.", "Накопленное время группы UNAVAILABLE, делённое на общее время логина.", "Аналоги: % Available, % Break, % Paperwork, % Training."
 MonSumAgentsUnavailableDurationPercent: "% времени в группе Unavailable (группа)", "Доля залогиненного времени группы в статусах группы UNAVAILABLE.", "Накопленный процент за день: суммарное время группы UNAVAILABLE / общее залогиненное время группы.", "Пер-агентский аналог: MonAgentUnavailableDurationPct."
HE:
 QueueLoginDataNumUnavailableUsers: "סוכנים בקבוצת Unavailable", "מספר הסוכנים הנמצאים כעת בקבוצת הסטטוס UNAVAILABLE.", "ספירה בזמן אמת של סוכנים שהסטטוס הנוכחי שלהם שייך לקבוצת UNAVAILABLE (מחוברים אך אינם זמינים לאינטראקציות).", "מקבילה למדד ההיסטורי statuslog.unavailable_agents."
 MonAgentUnavailableDuration: "משך Unavailable מצטבר", "סך הזמן שהסוכן שהה במצבי קבוצת UNAVAILABLE היום.", "זמן מצטבר היום במצבי קבוצת UNAVAILABLE. מקביל ל-statuslog.unavailable_time_ms.", "מקבילה באחוזים: % זמן Unavailable מתוך זמן ההתחברות."
 MonAgentUnavailableDurationPct: "% זמן Unavailable מתוך התחברות", "חלק מזמן ההתחברות של הסוכן ששהה במצבי קבוצת UNAVAILABLE היום.", "זמן קבוצת UNAVAILABLE המצטבר חלקי סך זמן ההתחברות.", "מקבילות: % Available, % Break, % Paperwork, % Training."
 MonSumAgentsUnavailableDurationPercent: "% זמן בקבוצת Unavailable (קבוצה)", "חלק מזמן ההתחברות של הקבוצה ששהה במצבי קבוצת UNAVAILABLE.", "אחוז מצטבר להיום: סך זמן קבוצת UNAVAILABLE חלקי סך זמן ההתחברות של הקבוצה.", "מקבילה ברמת הסוכן: MonAgentUnavailableDurationPct."
Then regenerate: `python3 tools/gen_translation_backfill.py --out db/data/05_metric_translations.sql` (now 402 rows = 201x2) and re-apply to dev DB.

## Step 4 — Export + skill update
- `db/tools/Export-All.ps1 -Password "!@#qweASDzxc" -CommitMessage "db: UNAVAILABLE RT RTSGrid metrics (_006)"` -> regenerates db/data/02_metrics.sql WITH the 4 new rows.
- Update `.claude/skills/rtm-metrics-expert/rtm-metrics-expert.md`: canonical status groups 5 -> 6 (add UNAVAILABLE) in §3 + §4 StatusGroup list + §10.2 notes; remove/adjust the old "TRAINING has no RT count" style note if it implied 5 groups.
- `python3 tools/lint_metrics.py` -> 0 errors (new functions exist; no dup; cards present). `--ignore-known` -> 0.

## Step 5 — Verify
- `SELECT count(*) FROM "RTSGrid_Metric" WHERE "MetricParameter"='UNAVAILABLE';` -> 4 (the new GROUP metrics) + note MonAgentUnavailableStateDuration is a separate STATE metric (param "Unavailable", not "UNAVAILABLE").
- `SELECT count(*) FROM "RTSGrid_MetricTranslation";` -> 402 (201 ru + 201 he).
- 02_metrics.sql re-exported with 4 new rows; linter green.

## Commits (lock §42.4; §39.3) — split
- `db: UNAVAILABLE RT RTSGrid metrics _006 + translations regen` (migration + db/data/02_metrics.sql + db/data/05_metric_translations.sql)
- `docs: UNAVAILABLE catalogue cards (en/ru/he) + rtm-metrics-expert 6th group` (3 metrics-catalog json + skill via `git add -f`)
Each: pre-commit-check -> §0.6 verify -> journal -> S4b post-commit flush to coordinator -> release lock -> PD-007 re-sync. No push.

## Acceptance criteria
1. 4 UNAVAILABLE GROUP metrics in RTSGrid_Metric (UsersInStatusGroupCount / TotalStatusGroupDuration / TotalStatusGroupPercent / UsersInStatusGroupDurationPercent), all param UNAVAILABLE, correct DataType/ValueType/MetricType mirroring BREAK.
2. 02_metrics.sql re-exported; linter 0 errors (--ignore-known 0).
3. Translations: 402 rows; the 4 new metrics have ru + he cards.
4. Skill updated to 6 canonical groups.
5. No EF migration (data only); no ScreenEditorPage; commits per module; tree clean (ignore false-M); journal + S4b; lock released; no push.
6. Coordinator: signal daytrend P3 _008 is now unblocked (the 4 RT metrics exist).


---

## ADDENDUM (coordinator §4 NOTE 1 — DURABILITY, mandatory): seed the 4 into ALL metric paths
RTSGrid_Metric lives in THREE authoritative seed paths (verified): (a) db/data/02_metrics.sql [Export-All],
(b) DatabaseInitializer.SeedRtsGridMetricsAsync [hardcoded 191-metric list, runs every Shell startup all envs],
(c) db/baseline.sql [COPY, 196 rows]. The typo-metric bug was caused by living in SOME paths not all
(fix needed both 82fff52 seeder + d66a45d baseline). So add the 4 UNAVAILABLE metrics to (b) and (c) too.

EXTRA CLAIMS for this: src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs (web, free, no chokepoint),
db/baseline.sql (db).

- (b) DatabaseInitializer.cs: in the `SeedRtsGridMetricsAsync` `new List<RtsGridMetric>{...}` add 4 entries in the
  EXISTING style (9 operational fields ONLY — the seeder does not set catalogue fields; that is consistent with the
  other 191). Match the BREAK analogs' field values, MetricParameter="UNAVAILABLE":
    QueueLoginDataNumUnavailableUsers (UsersSummary, UsersInStatusGroupCount, number, Data, DefaultValue "0"),
    MonAgentUnavailableDuration (User, TotalStatusGroupDuration, time, Agent),
    MonAgentUnavailableDurationPct (User, TotalStatusGroupPercent, number, Agent),
    MonSumAgentsUnavailableDurationPercent (UsersInteraction, UsersInStatusGroupDurationPercent, number, Data, MetricFormat "##0.00%").
  The seeder is idempotent (existingIds check) — safe.
- (c) db/baseline.sql: add 4 rows to the `COPY "RTSGrid_Metric" FROM stdin;` block. FIRST inspect the block's
  ACTUAL column count/order (it may be 9-col or 21-col depending on when it was last exported) and match it EXACTLY
  (tab-separated, \N for nulls). If 21-col, include the catalogue fields (same EN values as the migration); if 9-col,
  operational only.

## ADDENDUM (coordinator §4 NOTE 2 — schema.sql contention, mandatory): SERIALIZE Export-All
Both this _006 Export-All AND devops _009 (FUNCTION->PROCEDURE fix) regenerate db/schema.sql in the working tree.
Do NOT run Export-All while devops _009 is running. ORDER: devops _009 lands FIRST (prod hotfix; repo catches up),
THEN this _006 runs Export-All so it captures the corrected (procedure) schema. BEFORE running Export-All, check the
bus/journal that devops _009 is committed; if not, WAIT and coordinate via .coord. (Your commit still stages ONLY
db/data, never db/schema.sql — but avoid the concurrent working-tree stomp.)

## Updated acceptance additions
7. The 4 UNAVAILABLE metrics present in ALL THREE paths: 02_metrics.sql (Export-All), DatabaseInitializer seeder list, db/baseline.sql.
8. Export-All run only AFTER devops _009 committed (no concurrent schema.sql stomp).
