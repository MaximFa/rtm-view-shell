-- PR234-V4-WFM-WINDOW-TZ-01 — which clock does RTSData_Interaction keep?
-- READ ONLY: three SELECTs, no DDL, no writes, no temp objects. Safe on the live server.
-- Self-contained: tenant, workgroup and timezone all come from the table itself, so there is
-- nothing to substitute by hand and nothing to get wrong in the substitution.
--
-- The question, stated so one answer excludes the other:
--   H-WALL  the column holds LOCAL wall time of the row's timezone.
--           Then winHi = UtcNow + offset (WfmInputQueryService.cs:56-58) is right.
--   H-UTC   the column holds UTC.
--           Then winHi runs <offset> hours into the future, the newest real traffic sits BELOW
--           winLo, and lambda is averaged over an empty span. That is the suspected cause of the
--           zeros.
--
-- Expected BEFORE measuring, so the numbers cannot be read to fit either story afterwards:
--   H-WALL -> lag_vs_utc about +<offset>, lag_vs_wall near zero (seconds to minutes)
--   H-UTC  -> lag_vs_utc near zero,       lag_vs_wall about -<offset>
-- A third outcome exists and must not be dressed up as an answer: both lags far from zero, or
-- lag measured in days, means the feed is stale. That is a different defect.

\pset pager off
\timing on

-- ── 1. The timezone strings actually present, and whether they are offsets at all ──────────
-- StampWallNow first tries TimeSpan.TryParse on the string with +/- stripped, and only then
-- FindSystemTimeZoneById. A named zone ('Israel') cannot be turned into an interval in SQL, so
-- it is reported as such rather than silently treated as zero.
SELECT "TenantId",
       "TimeZone",
       count(*) AS rows,
       CASE WHEN "TimeZone" ~ '^[+-]?[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$'
            THEN 'offset-form' ELSE 'named-or-other' END AS tz_kind
FROM public."RTSData_Interaction"
WHERE "TimeZone" IS NOT NULL
GROUP BY 1, 2
ORDER BY rows DESC
LIMIT 20;

-- ── 2. Newest row per tenant, and the lag in both candidate clocks ─────────────────────────
-- The FILTER guards sentinel dates: an unparsed date lands in year 10000 and a bare max() would
-- report that instead of real traffic, answering a different question in a way that looks fine.
WITH tz AS (
    SELECT "TenantId",
           (SELECT "TimeZone" FROM public."RTSData_Interaction" i2
             WHERE i2."TenantId" = i."TenantId" AND i2."TimeZone" ~ '^[+-]?[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$'
             GROUP BY "TimeZone" ORDER BY count(*) DESC LIMIT 1) AS tz_str
    FROM public."RTSData_Interaction" i
    GROUP BY "TenantId"
)
SELECT t."TenantId",
       t.tz_str,
       max(i."InQueueDateTime") FILTER (WHERE i."InQueueDateTime" < now() + interval '1 year') AS newest_inqueue,
       (now() AT TIME ZONE 'UTC')                                                             AS utc_now,
       max(i."InQueueDateTime") FILTER (WHERE i."InQueueDateTime" < now() + interval '1 year')
         - (now() AT TIME ZONE 'UTC')                                                         AS lag_vs_utc,
       max(i."InQueueDateTime") FILTER (WHERE i."InQueueDateTime" < now() + interval '1 year')
         - (now() AT TIME ZONE 'UTC' + COALESCE(t.tz_str::interval, interval '0'))            AS lag_vs_wall
FROM tz t
JOIN public."RTSData_Interaction" i ON i."TenantId" = t."TenantId"
GROUP BY t."TenantId", t.tz_str
ORDER BY 1;

-- ── 3. The pair that proves or disproves the defect ────────────────────────────────────────
-- Rows the running window sees, against rows a UTC window would see, over the same 30 minutes,
-- under the exact filters the lambda query uses. One number proves nothing here - zero is also
-- what a blind probe returns - so both are printed side by side, with a 24h control.
WITH tz AS (
    SELECT "TenantId",
           (SELECT "TimeZone" FROM public."RTSData_Interaction" i2
             WHERE i2."TenantId" = i."TenantId" AND i2."TimeZone" ~ '^[+-]?[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$'
             GROUP BY "TimeZone" ORDER BY count(*) DESC LIMIT 1) AS tz_str
    FROM public."RTSData_Interaction" i
    GROUP BY "TenantId"
)
SELECT t."TenantId",
       t.tz_str,
       count(*) FILTER (
         WHERE i."InQueueDateTime" >= (now() AT TIME ZONE 'UTC' + COALESCE(t.tz_str::interval, interval '0')) - interval '30 minutes'
           AND i."InQueueDateTime" <  (now() AT TIME ZONE 'UTC' + COALESCE(t.tz_str::interval, interval '0'))
       ) AS rows_in_wall_window,
       count(*) FILTER (
         WHERE i."InQueueDateTime" >= (now() AT TIME ZONE 'UTC') - interval '30 minutes'
           AND i."InQueueDateTime" <  (now() AT TIME ZONE 'UTC')
       ) AS rows_in_utc_window,
       count(*) FILTER (
         WHERE i."InQueueDateTime" >= (now() AT TIME ZONE 'UTC') - interval '24 hours'
       ) AS rows_last_24h_utc
FROM tz t
JOIN public."RTSData_Interaction" i ON i."TenantId" = t."TenantId"
WHERE i."Direction" = 'Incoming'
  AND i."InteractionType" IN ('Call', 'Callback')
  AND i."CallType" = 'External'
GROUP BY t."TenantId", t.tz_str
ORDER BY 1;

-- Reading block 3:
--   wall = 0 and utc > 0   -> H-UTC. The window is the defect; winHi must not add the offset.
--   wall > 0 and utc = 0   -> H-WALL. The window is correct and the zeros come from elsewhere.
--   both 0, 24h > 0        -> neither: the filter set excludes everything, so the defect is in
--                             the filters, not in the clock.
--   24h = 0                -> no traffic for that tenant at all. The probe cannot answer. Do not
--                             guess from blocks 1-2 alone.

-- ── 4. Separating the two possible causes ──────────────────────────────────────────────────
-- devops measured on 13.10: TimeZone in the rows is '+02:00', the machine and the loop log are
-- +03:00, and the freshest rows sit +3:44 AHEAD of UTC. That matches NEITHER hypothesis above:
-- H-WALL would put the lag near +2:00, H-UTC near 0. So a third cause is on the table, and the
-- two must be told apart before anything is changed:
--   C-TZSTRING  the offset recorded in the rows is simply wrong for that site (rows are local
--               time of a +03:00 site but carry '+02:00'), so the window is short by an hour.
--   C-CLOCK     the feeding machine's clock is ahead (the extra ~0:44 on top of any offset),
--               so no offset choice makes the window line up and the fix is not in our code.
-- These produce different numbers: C-TZSTRING gives a lead clustered tightly at a whole number of
-- hours, C-CLOCK gives a lead that is not a round offset and drifts between rows.
--
-- The previous probe also measured only 86 rows, which is too small a sample to read a
-- distribution from, so the row count is printed first and every figure below is per-row, not a
-- single max().
SELECT count(*)                                                        AS rows_total,
       count(*) FILTER (WHERE "TimeZone" IS NULL)                      AS rows_without_tz,
       count(*) FILTER (WHERE "InQueueDateTime" >= now() + interval '1 year') AS rows_year_10000,
       count(*) FILTER (WHERE "InQueueDateTime" >= (now() AT TIME ZONE 'UTC') - interval '24 hours'
                          AND "InQueueDateTime" <  now() + interval '1 year')  AS rows_last_24h
FROM public."RTSData_Interaction";

-- Distribution of how far ahead of UTC the recent rows sit. A single number cannot tell a wrong
-- offset from a drifting clock; the spread is the whole point.
SELECT "TimeZone",
       count(*)                                                                      AS rows,
       min("InQueueDateTime" - (now() AT TIME ZONE 'UTC'))                           AS lead_min,
       percentile_disc(0.5) WITHIN GROUP (ORDER BY "InQueueDateTime" - (now() AT TIME ZONE 'UTC')) AS lead_median,
       max("InQueueDateTime" - (now() AT TIME ZONE 'UTC'))                           AS lead_max
FROM public."RTSData_Interaction"
WHERE "InQueueDateTime" <  now() + interval '1 year'
  AND "InQueueDateTime" >= (now() AT TIME ZONE 'UTC') - interval '24 hours'
GROUP BY "TimeZone"
ORDER BY rows DESC;

-- Reading block 4:
--   lead_min ≈ lead_median ≈ lead_max, all at a whole hour  -> C-TZSTRING. The offset in the rows
--                                                              is wrong; our window must use the
--                                                              site's real offset, and that is a
--                                                              decision about data, not a code fix
--                                                              to make blindly.
--   lead spread over minutes, not a round offset             -> C-CLOCK. The feed's clock is ahead;
--                                                              no offset choice lines the window up
--                                                              and the defect is outside our code.
--   rows_last_24h = 0 while rows_total > 0                   -> the feed is not delivering at all,
--                                                              which outranks both and must be
--                                                              reported as such, not as a timezone
--                                                              finding.
