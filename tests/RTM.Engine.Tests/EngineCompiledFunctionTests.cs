#nullable enable
using System.Collections.Concurrent;
using System.Reflection;
using System.Runtime.Serialization;
using FluentAssertions;
using RTM;

namespace RTM.Engine.Tests;

/// <summary>
/// V4-RTM-DIVZERO-EMPTY: tests for 11 Engine compiled metric functions.
/// </summary>
public class EngineCompiledFunctionTests
{
    private static readonly Type EngineType = Type.GetType("RTM.Engine, RTM")!;
    private static readonly object EngineLock = new object();
    private static ConcurrentDictionary<string, string>? _metricFunctionList;
    private static ConcurrentDictionary<string, string>? _metricUserFunctionList;
    private static Exception? _initException;
    
    static EngineCompiledFunctionTests()
    {
        try
        {
            InitializeFunctionLists();
        }
        catch (Exception ex)
        {
            _initException = ex;
        }
    }
    
    private static void InitializeFunctionLists()
    {
        if (EngineType == null)
            throw new InvalidOperationException("Could not resolve RTM.Engine type from RTM assembly");
            
#pragma warning disable SYSLIB0050
        var engine = FormatterServices.GetUninitializedObject(EngineType);
#pragma warning restore SYSLIB0050
        
        var metricListProp = EngineType.GetProperty("MetricFunctionList", BindingFlags.NonPublic | BindingFlags.Instance);
        var userMetricListProp = EngineType.GetProperty("MetricUserFunctionList", BindingFlags.NonPublic | BindingFlags.Instance);
        
        _metricFunctionList = new ConcurrentDictionary<string, string>();
        _metricUserFunctionList = new ConcurrentDictionary<string, string>();
        
        metricListProp?.SetValue(engine, _metricFunctionList);
        userMetricListProp?.SetValue(engine, _metricUserFunctionList);
        
        var setMetricFuncs = EngineType.GetMethod("setMetricFunctions", 
            BindingFlags.NonPublic | BindingFlags.Instance,
            null,
            Type.EmptyTypes,  // no parameters - parameterless overload
            null);
        var setUserMetricFuncs = EngineType.GetMethod("setUserMetricFunctions", 
            BindingFlags.NonPublic | BindingFlags.Instance,
            null,
            Type.EmptyTypes,  // no parameters - parameterless overload
            null);
        
        setMetricFuncs?.Invoke(engine, null);
        setUserMetricFuncs?.Invoke(engine, null);
    }
    
    [Fact]
    public void EngineCompiler_IsAccessible_FromTests()
    {
        if (_initException != null)
        {
            Assert.Fail($"STOP: Engine compiler not accessible: {_initException.Message}");
        }
        
        _metricFunctionList.Should().NotBeNull();
        _metricUserFunctionList.Should().NotBeNull();
        _metricFunctionList.Should().NotBeEmpty("setMetricFunctions should have added functions");
        _metricUserFunctionList.Should().NotBeEmpty("setUserMetricFunctions should have added functions");
    }
    
    #region Queue Functions
    
    #region AnsweredPercent (#4 - has external condition, 3 cases)
    
    [Fact]
    public void AnsweredPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("AnsweredPercent", "true", "#0.##%");
        bag.Add(CreateAnsweredInteraction());
        
        var result = metricDef.MetricFunction(bag, false);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void AnsweredPercent_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("AnsweredPercent", "true", "#0.##%");
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void AnsweredPercent_ValidDenominator_ReturnsFormattedValue()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("AnsweredPercent", "true", "#0.##%");
        bag.Add(CreateAnsweredInteraction());
        bag.Add(CreateAnsweredInteraction());
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().MatchRegex(@"^\d+(\.\d+)?%$");
    }
    
    #endregion
    
    #region AbandonedPercent (#5 - has external condition, 3 cases)
    
    [Fact]
    public void AbandonedPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("AbandonedPercent", "true", "#0.##%");
        bag.Add(CreateAbandonedInteraction());
        
        var result = metricDef.MetricFunction(bag, false);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void AbandonedPercent_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("AbandonedPercent", "true", "#0.##%");
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void AbandonedPercent_ValidDenominator_ReturnsFormattedValue()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("AbandonedPercent", "true", "#0.##%");
        bag.Add(CreateAbandonedInteraction());
        bag.Add(CreateAnsweredInteraction());
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().MatchRegex(@"^\d+(\.\d+)?%$");
    }
    
    #endregion
    
    #region MessagesPercent (#6 - has external condition, 3 cases)
    
    [Fact]
    public void MessagesPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesPercent", "true", "#0.##%", "true");
        bag.Add(CreateChatInteractionWithMessages());
        
        var result = metricDef.MetricFunction(bag, false);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesPercent_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesPercent", "true", "#0.##%", "true");
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesPercent_ValidDenominator_ReturnsFormattedValue()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesPercent", "true", "#0.##%", "true");
        bag.Add(CreateChatInteractionWithMessages());
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().MatchRegex(@"^\d+(\.\d+)?%$");
    }
    
    #endregion
    
    #region MessagesInteractionsPercent (#7 - has external condition, 3 cases)
    
    [Fact]
    public void MessagesInteractionsPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesInteractionsPercent", "true", "#0.##%", "true");
        bag.Add(CreateChatInteractionWithMessages());
        
        var result = metricDef.MetricFunction(bag, false);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesInteractionsPercent_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesInteractionsPercent", "true", "#0.##%", "true");
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesInteractionsPercent_ValidDenominator_ReturnsFormattedValue()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesInteractionsPercent", "true", "#0.##%", "true");
        bag.Add(CreateChatInteractionWithMessages());
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().MatchRegex(@"^\d+(\.\d+)?%$");
    }
    
    #endregion
    
    #region MessagesAvgFirstResponseTime queue (#8 - has external condition, 3 cases)
    
    [Fact]
    public void MessagesAvgFirstResponseTime_Queue_ExternalConditionFalse_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesAvgFirstResponseTime", "true", null, "true");
        bag.Add(CreateChatInteractionWithMessages());
        
        var result = metricDef.MetricFunction(bag, false);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesAvgFirstResponseTime_Queue_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesAvgFirstResponseTime", "true", null, "true");
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesAvgFirstResponseTime_Queue_ValidDenominator_ReturnsFormattedTime()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesAvgFirstResponseTime", "true", null, "true");
        bag.Add(CreateChatInteractionWithResponseTime());
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region MessagesAvgResponseTime queue (#9 - has external condition, 3 cases)
    
    [Fact]
    public void MessagesAvgResponseTime_Queue_ExternalConditionFalse_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesAvgResponseTime", "true", null, "true");
        bag.Add(CreateChatInteractionWithMessages());
        
        var result = metricDef.MetricFunction(bag, false);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesAvgResponseTime_Queue_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesAvgResponseTime", "true", null, "true");
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesAvgResponseTime_Queue_ValidDenominator_ReturnsFormattedTime()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("MessagesAvgResponseTime", "true", null, "true");
        bag.Add(CreateChatInteractionWithResponseTime());
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region WaitDurationAvg (#10 - no external condition, 2 cases)
    
    [Fact]
    public void WaitDurationAvg_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("WaitDurationAvg", "true", null);
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void WaitDurationAvg_ValidDenominator_ReturnsFormattedTime()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("WaitDurationAvg", "true", null);
        bag.Add(CreateInteractionWithWaitTime(60));
        bag.Add(CreateInteractionWithWaitTime(120));
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region TalkDurationAvg queue (#11 - no external condition, 2 cases)
    
    [Fact]
    public void TalkDurationAvg_Queue_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("TalkDurationAvg", "true", null);
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void TalkDurationAvg_Queue_ValidDenominator_ReturnsFormattedTime()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeQueueFunction("TalkDurationAvg", "true", null);
        bag.Add(CreateAnsweredInteractionWithTalkTime(60));
        bag.Add(CreateAnsweredInteractionWithTalkTime(120));
        
        var result = metricDef.MetricFunction(bag, true);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #endregion
    
    #region Agent Functions
    
    #region TalkDurationAvg agent (#1 - no external condition, 2 cases)
    
    [Fact]
    public void TalkDurationAvg_Agent_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeUserFunction("TalkDurationAvg", "true");
        
        var result = metricDef.MetricUserFunction(bag, "user1");
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void TalkDurationAvg_Agent_ValidDenominator_ReturnsFormattedTime()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeUserFunction("TalkDurationAvg", "true");
        bag.Add(CreateAnsweredInteractionWithTalkTime(60, "user1"));
        bag.Add(CreateAnsweredInteractionWithTalkTime(120, "user1"));
        
        var result = metricDef.MetricUserFunction(bag, "user1");
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region MessagesAvgFirstResponseTime agent (#2 - no external condition, 2 cases)
    
    [Fact]
    public void MessagesAvgFirstResponseTime_Agent_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeUserFunction("MessagesAvgFirstResponseTime", "true", "true");
        
        var result = metricDef.MetricUserFunction(bag, "user1");
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesAvgFirstResponseTime_Agent_ValidDenominator_ReturnsFormattedTime()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeUserFunction("MessagesAvgFirstResponseTime", "true", "true");
        bag.Add(CreateChatInteractionWithResponseTime("user1"));
        
        var result = metricDef.MetricUserFunction(bag, "user1");
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region MessagesAvgResponseTime agent (#3 - no external condition, 2 cases)
    
    [Fact]
    public void MessagesAvgResponseTime_Agent_ZeroDenominator_ReturnsEmpty()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeUserFunction("MessagesAvgResponseTime", "true", "true");
        
        var result = metricDef.MetricUserFunction(bag, "user1");
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void MessagesAvgResponseTime_Agent_ValidDenominator_ReturnsFormattedTime()
    {
        SkipIfInitFailed();
        var (metricDef, bag) = ArrangeUserFunction("MessagesAvgResponseTime", "true", "true");
        bag.Add(CreateChatInteractionWithResponseTime("user1"));
        
        var result = metricDef.MetricUserFunction(bag, "user1");
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #endregion
    
    #region Helpers
    
    private void SkipIfInitFailed()
    {
        if (_initException != null)
        {
            Assert.Fail($"STOP: Engine compiler initialization failed: {_initException.Message}");
        }
    }
    
    private (MetricDef metricDef, ConcurrentBag<IDInteraction> bag) ArrangeQueueFunction(
        string functionName, string parameter, string? format, string? direction = null)
    {
        string functionBody;
        if (_metricFunctionList == null || !_metricFunctionList.TryGetValue(functionName, out functionBody!))
        {
            throw new InvalidOperationException($"Function {functionName} not found in MetricFunctionList");
        }
        
        var processedBody = functionBody
            .Replace("METRIC_PARAMETER", parameter)
            .Replace("METRIC_DIRECTION", direction ?? "true")
            .Replace("METRIC_FORMAT", format != null ? $"\"{format}\"" : @"""#0.##%""");
        
        var metricDef = new MetricDef
        {
            ID = $"Test_{functionName}_{Guid.NewGuid():N}",
            Function = functionName,
            Parameter = parameter,
            Format = format ?? "#0.##%"
        };
        
#pragma warning disable SYSLIB0050
        var engine = FormatterServices.GetUninitializedObject(EngineType);
#pragma warning restore SYSLIB0050

        var compileMethod = EngineType.GetMethod("CompileAndSetMetricFunction");
        compileMethod?.Invoke(engine, new object[] { metricDef, processedBody });
        
        var bag = new ConcurrentBag<IDInteraction>();
        return (metricDef, bag);
    }
    
    private (MetricDef metricDef, ConcurrentBag<IDInteraction> bag) ArrangeUserFunction(
        string functionName, string parameter, string? direction = null)
    {
        string functionBody;
        if (_metricUserFunctionList == null || !_metricUserFunctionList.TryGetValue(functionName, out functionBody!))
        {
            throw new InvalidOperationException($"Function {functionName} not found in MetricUserFunctionList");
        }
        
        var processedBody = functionBody
            .Replace("METRIC_PARAMETER", parameter)
            .Replace("METRIC_DIRECTION", direction ?? "true")
            .Replace("METRIC_FORMAT", @"""#0.##%""");
        
        var metricDef = new MetricDef
        {
            ID = $"Test_{functionName}_User_{Guid.NewGuid():N}",
            Function = functionName,
            Parameter = parameter,
            Format = "#0.##%"
        };
        
#pragma warning disable SYSLIB0050
        var engine = FormatterServices.GetUninitializedObject(EngineType);
#pragma warning restore SYSLIB0050

        var compileMethod = EngineType.GetMethod("CompileAndSetUserMetricFunction");
        compileMethod?.Invoke(engine, new object[] { metricDef, processedBody });
        
        var bag = new ConcurrentBag<IDInteraction>();
        return (metricDef, bag);
    }
    
    private static IDInteraction CreateAnsweredInteraction()
    {
        return new IDInteraction("i" + Guid.NewGuid().ToString("N")[..8], 0, null, false) { IsAnswered = true };
    }
    
    private static IDInteraction CreateAbandonedInteraction()
    {
        return new IDInteraction("i" + Guid.NewGuid().ToString("N")[..8], 0, null, false) { IsAbandoned = true };
    }
    
    private static IDInteraction CreateInteractionWithWaitTime(double seconds)
    {
        return new IDInteraction("i" + Guid.NewGuid().ToString("N")[..8], 0, null, false) { TimeInQueue = seconds };
    }
    
    private static IDInteraction CreateAnsweredInteractionWithTalkTime(double seconds, string? userId = null)
    {
        var i = new IDInteraction("i" + Guid.NewGuid().ToString("N")[..8], 0, null, false) { IsAnswered = true, TalkTime = seconds };
        if (userId != null) i.UserId = userId;
        return i;
    }
    
    private static IDInteraction CreateChatInteractionWithMessages()
    {
        var i = new IDInteraction("i" + Guid.NewGuid().ToString("N")[..8], 0, null, false) { InteractionType = "Chat", Direction = "Incoming" };
        var msg = new ChatMessage { MessageId = "m1", MsgDirection = "outbound", TimeStamp = DateTime.UtcNow };
        i.ChatMessages.TryAdd(msg.MessageId, msg);
        return i;
    }
    
    private static IDInteraction CreateChatInteractionWithResponseTime(string? userId = null)
    {
        var i = new IDInteraction("i" + Guid.NewGuid().ToString("N")[..8], 0, null, false)
        {
            InteractionType = "Chat",
            Direction = "Incoming",
            AnsweredDateTime = DateTime.UtcNow.AddMinutes(-5)
        };
        if (userId != null) i.UserId = userId;
        
        var inbound = new ChatMessage { MessageId = "m1", MsgDirection = "inbound", TimeStamp = DateTime.UtcNow.AddMinutes(-4) };
        var outbound = new ChatMessage { MessageId = "m2", MsgDirection = "outbound", TimeStamp = DateTime.UtcNow.AddMinutes(-3) };
        i.ChatMessages.TryAdd(inbound.MessageId, inbound);
        i.ChatMessages.TryAdd(outbound.MessageId, outbound);
        return i;
    }
    
    #endregion
}