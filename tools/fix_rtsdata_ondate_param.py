#!/usr/bin/env python3
"""Add OnDate parameter to RTSData_getInteractions and RTSData_getUsersStatuses functions"""

path = r"C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\RTM\sql\pgsql\02_rtsdata_functions.sql"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Fix RTSData_GetInteractions - add p_on_date parameter
old_get_interactions = '''DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"()
RETURNS TABLE('''

new_get_interactions = '''DROP FUNCTION IF EXISTS "RTSData_GetInteractions"(text);
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_on_date text DEFAULT NULL)
RETURNS TABLE('''

text = text.replace(old_get_interactions, new_get_interactions)

# Fix the WHERE clause for RTSData_GetInteractions
old_from_interaction = '''    FROM "RTSData_Interaction" i;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getInteractions")
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();

CREATE OR REPLACE FUNCTION "RTSData_getInteractions"()'''

new_from_interaction = '''    FROM "RTSData_Interaction" i
    WHERE p_on_date IS NULL OR i."OnDate" = p_on_date;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getInteractions")
DROP FUNCTION IF EXISTS "RTSData_getInteractions"(text);
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();

CREATE OR REPLACE FUNCTION "RTSData_getInteractions"(p_on_date text DEFAULT NULL)'''

text = text.replace(old_from_interaction, new_from_interaction)

# Fix the alias SELECT for getInteractions
old_alias_interaction = '''LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetInteractions"(); $$;'''

new_alias_interaction = '''LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetInteractions"(p_on_date); $$;'''

text = text.replace(old_alias_interaction, new_alias_interaction, 1)

# Fix RTSData_GetUsersStatuses - add p_on_date parameter
old_get_statuses = '''DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"()
RETURNS TABLE('''

new_get_statuses = '''DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"(text);
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"(p_on_date text DEFAULT NULL)
RETURNS TABLE('''

text = text.replace(old_get_statuses, new_get_statuses)

# Fix the WHERE clause for RTSData_GetUsersStatuses
old_from_status = '''    FROM "RTSData_UserStatus" s;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getUsersStatuses")
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();

CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"()'''

new_from_status = '''    FROM "RTSData_UserStatus" s
    WHERE p_on_date IS NULL OR s."OnDate" = p_on_date;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getUsersStatuses")
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"(text);
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();

CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"(p_on_date text DEFAULT NULL)'''

text = text.replace(old_from_status, new_from_status)

# Fix the second alias SELECT for getUsersStatuses
# Count occurrences and replace the second one
parts = text.split('LANGUAGE sql\nAS $$ SELECT * FROM "RTSData_GetUsersStatuses"(); $$;')
if len(parts) == 2:
    text = parts[0] + 'LANGUAGE sql\nAS $$ SELECT * FROM "RTSData_GetUsersStatuses"(p_on_date); $$;' + parts[1]

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print(f"Fixed {path}")
print(f"Total lines: {len(text.splitlines())}")
