import os

path = r"D:\Claude\Projects\RTM View Shell\RTM\RTM\Union.cs"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add static fields after line with "public int UnionId { get; set; }"
old_field = '''public int UnionId { get; set; }


        public ConcurrentDictionary<QueueClassification, Applic> Applics'''

new_field = '''public int UnionId { get; set; }

        // Calc quarantine: track consecutive failures per metric to prevent log spam
        private static readonly ConcurrentDictionary<string, int> _calcFailures = new();
        private static readonly ConcurrentDictionary<string, int> _calcCycles = new();
        private const int CalcQuarantineThreshold = 5;

        public ConcurrentDictionary<QueueClassification, Applic> Applics'''

content = content.replace(old_field, new_field)

# 2. Replace the Calc case block
old_calc = '''case "Calc":
                    string calc1 = metric.Parameter;
                    try
                    {
                        var pattern = @"\[(.*?)\]";
                        var matches = Regex.Matches(calc1, pattern).OfType<Match>().Select(m => m.Groups[1].Value).Distinct();

                        calc1 = calc1.Replace("-", " - ");

                        foreach (string key in matches)
                        {
                            string val = "0";

                            if (AllDataMetrics.ContainsKey(key))
                            {
                                val = metricFunction(AllDataMetrics[key], false);
                            }

                            calc1 = calc1.Replace("[" + key + "]", val);
                        }

                        var expression = new CompiledExpression(calc1);
                        var result = expression.Eval();

                        retValue = result.ToString();
                        double d;
                        if (double.TryParse(retValue, out d))
                        {
                            retValue = d.ToString(metric.Format);
                        }
                    }
                    catch (Exception ex)
                    {
                        AsyncLogger.Error("Union.getData.Calc: " + calc1, ex);
                    }
                    break;'''

new_calc = '''case "Calc":
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
                        var pattern = @"\[(.*?)\]";
                        var matches = Regex.Matches(calc1, pattern).OfType<Match>().Select(m => m.Groups[1].Value).Distinct();

                        calc1 = calc1.Replace("-", " - ");

                        foreach (string key in matches)
                        {
                            string val = "0";

                            if (AllDataMetrics.ContainsKey(key))
                            {
                                val = metricFunction(AllDataMetrics[key], false);
                            }

                            calc1 = calc1.Replace("[" + key + "]", val);
                        }

                        var expression = new CompiledExpression(calc1);
                        var result = expression.Eval();

                        retValue = result.ToString();
                        double d;
                        if (double.TryParse(retValue, out d))
                        {
                            retValue = d.ToString(metric.Format);
                        }
                        
                        // Success: reset failure counter (un-quarantine if was quarantined)
                        if (failures > 0)
                        {
                            _calcFailures[metricId] = 0;
                            if (failures >= CalcQuarantineThreshold)
                            {
                                AsyncLogger.Info($"Union.getData.Calc: metric {metricId} recovered from quarantine");
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Increment failure counter
                        int newFailures = _calcFailures.AddOrUpdate(metricId, 1, (k, v) => v + 1);
                        
                        // Log only on 1st failure and every 100th thereafter
                        if (newFailures == 1 || newFailures % 100 == 0)
                        {
                            AsyncLogger.Error($"Union.getData.Calc: {calc1} (failure #{newFailures})", ex);
                        }
                        
                        // Log quarantine event once
                        if (newFailures == CalcQuarantineThreshold)
                        {
                            AsyncLogger.Warn($"Union.getData.Calc: metric {metricId} quarantined after {newFailures} consecutive failures");
                        }
                    }
                    break;'''

content = content.replace(old_calc, new_calc)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Updated: {path}")
