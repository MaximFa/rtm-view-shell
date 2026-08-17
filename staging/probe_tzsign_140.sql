-- MANDATORY per-zone SIGN PROBE (read-only) for RTSData_GetInteractions guard on 140.
-- For each distinct TimeZone, pick the row CLOSEST to local midnight (max sign-risk) and assert
-- the e58cac8 CASE local-date == an INDEPENDENT reference date.
--   offsets: independent ref = (UTC-wall + tz::interval)::date  [manual, does NOT use AT TIME ZONE]
--   names/empty: ref = (UpdateTime AT TIME ZONE COALESCE(NULLIF(tz,''),'UTC'))::date  [IANA unambiguous]
-- Also shows the OLD bare-text date (0329bf0) to prove where the sign-fix flips a row.

WITH ref AS (
  SELECT
    "TimeZone" AS tz,
    "UpdateTime" AS update_utc,
    (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
          THEN ("UpdateTime" AT TIME ZONE (("TimeZone")::interval))
          ELSE ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
     END)::date AS case_date,
    (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
          THEN (("UpdateTime" AT TIME ZONE 'UTC') + ("TimeZone")::interval)
          ELSE ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
     END)::date AS ref_date,
    ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))::date AS bare_old_date,
    (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
          THEN (("UpdateTime" AT TIME ZONE 'UTC') + ("TimeZone")::interval)
          ELSE ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
     END)::time AS local_tod
  FROM "RTSData_Interaction"
  WHERE "UpdateTime" IS NOT NULL
)
SELECT DISTINCT ON (tz)
    tz,
    update_utc,
    local_tod,
    case_date,
    ref_date,
    bare_old_date,
    (case_date = ref_date)      AS case_correct,          -- MUST be true for every zone
    (case_date <> bare_old_date) AS signfix_flips_this_row  -- true = e58cac8 corrected the old bug here
FROM ref
ORDER BY tz, LEAST(EXTRACT(EPOCH FROM local_tod), 86400 - EXTRACT(EPOCH FROM local_tod));

-- Population assertion: CASE must match the independent ref on EVERY row (mismatch = 0).
WITH ref AS (
  SELECT
    (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
          THEN ("UpdateTime" AT TIME ZONE (("TimeZone")::interval))
          ELSE ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
     END)::date AS case_date,
    (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
          THEN (("UpdateTime" AT TIME ZONE 'UTC') + ("TimeZone")::interval)
          ELSE ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
     END)::date AS ref_date,
    ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))::date AS bare_old_date
  FROM "RTSData_Interaction" WHERE "UpdateTime" IS NOT NULL
)
SELECT
    count(*)                                          AS total_rows,
    count(*) FILTER (WHERE case_date <> ref_date)     AS case_mismatch_ref,     -- MUST be 0
    count(*) FILTER (WHERE case_date <> bare_old_date) AS rows_signfix_flips;    -- >0 proves the fix is load-bearing
