import os
import re

path = r'RTM\RTM\IDInteraction.cs'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# New implementation for getLocalDateTime
new_method = '''public DateTime getLocalDateTime()
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

# Use regex to find and replace the method
# Pattern matches from "public DateTime getLocalDateTime()" to closing brace
pattern = r'public DateTime getLocalDateTime\(\)\s*\{[^}]+try\s*\{[^}]+\}[^}]+catch\s*\([^)]+\)\s*\{[^}]+\}[^}]+return localTime;\s*\}'

match = re.search(pattern, text)
if match:
    text = text[:match.start()] + new_method + text[match.end():]
    print(f'IDInteraction.cs: method replaced via regex')
else:
    print(f'IDInteraction.cs: WARNING - pattern not found')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print('Done')
