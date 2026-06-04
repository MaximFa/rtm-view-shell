-- 03_rtsgrid.sql: RTSGrid and RTSUserGrid widget definitions
SET session_replication_role = replica;

-- RTSGrid_Grid
TRUNCATE TABLE "RTSGrid_Grid" RESTART IDENTITY CASCADE;

-- RTSGrid_Row
TRUNCATE TABLE "RTSGrid_Row" RESTART IDENTITY CASCADE;

-- RTSGrid_Column
TRUNCATE TABLE "RTSGrid_Column" RESTART IDENTITY CASCADE;

-- RTSGrid_Cell
TRUNCATE TABLE "RTSGrid_Cell" RESTART IDENTITY CASCADE;

-- RTSUserGrid_ColumnsSet
TRUNCATE TABLE "RTSUserGrid_ColumnsSet" RESTART IDENTITY CASCADE;

-- RTSUserGrid_Grid
TRUNCATE TABLE "RTSUserGrid_Grid" RESTART IDENTITY CASCADE;

-- RTSUserGrid_Column
TRUNCATE TABLE "RTSUserGrid_Column" RESTART IDENTITY CASCADE;

SET session_replication_role = DEFAULT;