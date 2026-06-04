import os

# New implementation for getLocalDateTime
new_method_body = '''public DateTime getLocalDateTime()
        {
            DateTime localTime = DateTime.UtcNow;

            if (string.IsNullOrWhiteSpace(TimeZone))
                return localTime;

            try
            {
                TimeSpan offset;

                // Try offset format first: "+03:00", "-05:00", "03:00"
                string cleaned = TimeZone.Trim();
                bool negative = cleaned.StartsWith("-");
                string stripped = cleaned.TrimStart('+').TrimStart('-');

                if (TimeSpan.TryParse(stripped, out offset))
                {
                    if (negative) offset = offset.Negate();
                }
                else
                {
                    // Fallback: Windows / IANA timezone ID (e.g. "Israel", "UTC")
                    var tzi = TimeZoneInfo.FindSystemTimeZoneById(TimeZone);
                    offset = tzi.GetUtcOffset(DateTime.UtcNow);
                }

                localTime = localTime.Add(offset);
            }
            catch
            {
                // Unknown timezone format — return UTC silently
            }

            return localTime;
        }'''

# ============================================================================
# Fix IDInteraction.cs
# ============================================================================
path1 = r'RTM\RTM\IDInteraction.cs'

with open(path1, 'r', encoding='utf-8') as f:
    text = f.read()

# Old method to replace (lines 253-277)
old_method1 = '''public DateTime getLocalDateTime()
        {
            DateTime localTime = DateTime.UtcNow;

            try
            {
                if (string.IsNullOrWhiteSpace(TimeZone)) return localTime;
                TimeSpan offset = TimeSpan.Parse(TimeZone.Replace("+", "").Replace("-", ""));
                if (TimeZone.StartsWith("-"))
                {
                    offset = offset.Negate();
                }

                localTime = localTime.Add(offset);

                AsyncLogger.Info ($"getLocalDateTime TimeZone={TimeZone} localTime={localTime}");
            }
            catch(Exception ex)
            {
                AsyncLogger.Error($"getLocalDateTime", ex);
                //AsyncLogger.Error($"IDInteraction getLocalDateTime InteractionId={InteractionId} Workgroup={Workgroup} TimeZone={TimeZone} localTime={localTime}", ex);
            }

            return localTime;
        }'''

if old_method1 in text:
    text = text.replace(old_method1, new_method_body)
    print(f'IDInteraction.cs: method replaced')
else:
    print(f'IDInteraction.cs: WARNING - old method not found exactly')

with open(path1, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

# ============================================================================
# Fix UserManager.cs
# ============================================================================
path2 = r'RTM\RTM\UserManager.cs'

with open(path2, 'r', encoding='utf-8') as f:
    text = f.read()

# Old method to replace (lines 175-196)
old_method2 = '''public DateTime getLocalDateTime()
        {
            DateTime localTime = DateTime.UtcNow;
            try
            {
                if (string.IsNullOrWhiteSpace(TimeZone)) return localTime;
                TimeSpan offset = TimeSpan.Parse(TimeZone.Replace("+", "").Replace("-", ""));
                if (TimeZone.StartsWith("-"))
                {
                    offset = offset.Negate();
                }

                localTime = localTime.Add(offset);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"getLocalDateTime userId={userId}", ex);
                //AsyncLogger.Error($"UserManager getLocalDateTime UserId={_userId} Workgroups={_workgroups} TimeZone={TimeZone} localTime={localTime}", ex);
            }

            return localTime;
        }'''

if old_method2 in text:
    text = text.replace(old_method2, new_method_body)
    print(f'UserManager.cs: method replaced')
else:
    print(f'UserManager.cs: WARNING - old method not found exactly')

with open(path2, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print('Done')
