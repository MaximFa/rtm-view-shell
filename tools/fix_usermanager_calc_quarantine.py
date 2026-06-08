import os

path = r"D:\Claude\Projects\RTM View Shell\RTM\RTM\UserManager.cs"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add static fields after the private fields at top of class
old_fields = '''private bool _isActive = false;
        private bool _isLoggedIn = false;
        private bool _isHoldChanged = true;'''

new_fields = '''private bool _isActive = false;
        private bool _isLoggedIn = false;
        private bool _isHoldChanged = true;
        
        // Calc quarantine: track consecutive failures per metric to prevent log spam
        private static readonly ConcurrentDictionary<string, int> _calcFailures = new();
        private static readonly ConcurrentDictionary<string, int> _calcCycles = new();
        private const int CalcQuarantineThreshold = 5;'''

content = content.replace(old_fields, new_fields)

# 2. Replace the Calc case block - note the different structure (no internal try-catch)
old_calc = '''// Calc
                    case "Calc":
                        string calc1 = metric.Parameter;
                        var pattern = @"\\[(.*?)\\]";
                        var matches = Regex.Matches(calc1, pattern).OfType<Match>().Select(m => m.Groups[1].Value).Distinct();

                        foreach (string key in matches)
                        {
                            string val1 = "0";

                            val1 = metricFunction(metrics[key], metrics);
                            calc1 = calc1.Replace("[" + key + "]", val1);
                        }

                        logStr = calc1;

                        var expression = new CompiledExpression(calc1);
                        var result = expression.Eval();

                        val = result.ToString();
                        break;'''

new_calc = '''// Calc
                    case "Calc":
                        string calc1 = metric.Parameter;
                        string metricId = metric.ID;
                        
                        // Quarantine check: skip if quarantined, but probe every 100 cycles
                        int failures = _calcFailures.GetValueOrDefault(metricId, 0);
                        int cycles = _calcCycles.AddOrUpdate(metricId, 1, (k, v) => v + 1);
                        
                        if (failures >= CalcQuarantineThreshold && cycles % 100 != 0)
                        {
                            // Quarantined: return existing value without eval
                            break;
                        }
                        
                        try
                        {
                            var pattern = @"\\[(.*?)\\]";
                            var matches = Regex.Matches(calc1, pattern).OfType<Match>().Select(m => m.Groups[1].Value).Distinct();

                            foreach (string key in matches)
                            {
                                string val1 = "0";
                                val1 = metricFunction(metrics[key], metrics);
                                calc1 = calc1.Replace("[" + key + "]", val1);
                            }

                            logStr = calc1;

                            var expression = new CompiledExpression(calc1);
                            var result = expression.Eval();

                            val = result.ToString();
                            
                            // Success: reset failure counter (un-quarantine if was quarantined)
                            if (failures > 0)
                            {
                                _calcFailures[metricId] = 0;
                                if (failures >= CalcQuarantineThreshold)
                                {
                                    AsyncLogger.Info($"UserManager.metricFunction: metric {metricId} recovered from quarantine");
                                }
                            }
                        }
                        catch (Exception calcEx)
                        {
                            // Increment failure counter
                            int newFailures = _calcFailures.AddOrUpdate(metricId, 1, (k, v) => v + 1);
                            
                            // Log only on 1st failure and every 100th thereafter
                            if (newFailures == 1 || newFailures % 100 == 0)
                            {
                                AsyncLogger.Error($"UserManager.metricFunction.Calc: {calc1} (failure #{newFailures})", calcEx);
                            }
                            
                            // Log quarantine event once
                            if (newFailures == CalcQuarantineThreshold)
                            {
                                AsyncLogger.Warn($"UserManager.metricFunction: metric {metricId} quarantined after {newFailures} consecutive failures");
                            }
                        }
                        break;'''

content = content.replace(old_calc, new_calc)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Updated: {path}")
