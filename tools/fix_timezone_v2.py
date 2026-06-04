import os

path = r'RTM\RTM\IDInteraction.cs'

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# New method lines
new_method_lines = '''        public DateTime getLocalDateTime()
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
        }
'''

# Find start and end of the old method
start_line = None
end_line = None

for i, line in enumerate(lines):
    if 'public DateTime getLocalDateTime()' in line and start_line is None:
        start_line = i
    # Find the closing brace that ends the method (after "return localTime;")
    if start_line is not None and 'return localTime;' in line:
        # The closing brace is on the next line (or a few lines after)
        for j in range(i+1, min(i+5, len(lines))):
            if lines[j].strip() == '}':
                end_line = j
                break
        if end_line:
            break

if start_line is not None and end_line is not None:
    print(f'Found method at lines {start_line+1} to {end_line+1}')
    new_lines = lines[:start_line] + [new_method_lines] + lines[end_line+1:]

    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
        f.flush()
        os.fsync(f.fileno())
    print('IDInteraction.cs: method replaced')
else:
    print(f'Start: {start_line}, End: {end_line}')
    print('WARNING: Could not find method boundaries')
