-- Update MetricType based on Description prefix
-- Agent - * → Agent
UPDATE rtsgrid_metric SET "MetricType" = 'Agent' WHERE "Description" LIKE 'Agent -%';

-- QM - * → Data
UPDATE rtsgrid_metric SET "MetricType" = 'Data' WHERE "Description" LIKE 'QM -%';

-- Agent Group - * → Data
UPDATE rtsgrid_metric SET "MetricType" = 'Data' WHERE "Description" LIKE 'Agent Group -%';

-- Special case: Change (weird description)
UPDATE rtsgrid_metric SET "MetricType" = 'Agent' WHERE "Description" LIKE 'Change -%';

-- Update ValueType based on Description content

-- Time values: Duration, Time, TimeStamp
UPDATE rtsgrid_metric SET "ValueType" = 'Time' WHERE
    "Description" ILIKE '%Duration%'
    OR "Description" ILIKE '%Time%'
    OR "Description" ILIKE '%TimeStamp%';

-- Number values: Number of, Num, Count, Percent, Pct, Avg, Average, Max, CPH
UPDATE rtsgrid_metric SET "ValueType" = 'Number' WHERE
    "Description" ILIKE '%Number of%'
    OR "Description" ILIKE '%Num %'
    OR "Description" ILIKE '%Percent%'
    OR "Description" ILIKE '%Pct %'
    OR "Description" ILIKE '%CPH%';

-- String values: Name, ID, Phone, Extension, Station, State, Status, Group, Type, Queue
-- (These override the Time/Number if they match - so run last)
UPDATE rtsgrid_metric SET "ValueType" = 'String' WHERE
    "Description" ILIKE '% Name%'
    OR "Description" ILIKE '% ID%'
    OR "Description" ILIKE '%Phone Number%'
    OR "Description" ILIKE '%Extension%'
    OR "Description" ILIKE '%Station%'
    OR ("Description" ILIKE '%State%' AND "Description" NOT ILIKE '%Duration%')
    OR ("Description" ILIKE '%Status%' AND "Description" NOT ILIKE '%Duration%')
    OR ("Description" ILIKE '%Group%' AND "Description" NOT ILIKE '%Duration%' AND "Description" NOT ILIKE '%Number%' AND "Description" NOT ILIKE '%Percent%')
    OR ("Description" ILIKE '%Type%' AND "Description" NOT ILIKE '%Data%')
    OR ("Description" ILIKE '%Queue Name%');

-- Special cases that need String but got Time/Number
UPDATE rtsgrid_metric SET "ValueType" = 'String' WHERE "MetricId" IN (
    'AgentLoginName',          -- Agent - Login Name
    'MonAgentUserId',          -- Agent - User ID
    'MonAgentStation',         -- Agent - Station ID
    'MonAgentExtension',       -- Agent - Extension ID
    'MonAgentState',           -- Agent - Current Satatus
    'MonAgentStateDesc',       -- Agent - Current Status Group
    'MonInteractionType',      -- Agent - Active Interaction Type
    'MonAgentTelState',        -- Agent - Active Interaction State
    'MonActiveCampaign',       -- Agent - Active Interaction Queue Name
    'RemotePhoneNumber',       -- Agent - Active Interaction Customer Phone Number
    'MonAgentActiveInteractionId', -- Agent - Active Interction ID
    'MonAgentTodayLogin'       -- Change - (boolean-ish)
);

-- Verify results
SELECT "MetricId", "Description", "ValueType", "MetricType" FROM rtsgrid_metric ORDER BY "MetricType", "ValueType", "MetricId";
