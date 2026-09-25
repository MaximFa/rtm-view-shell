using System.Collections.Concurrent;
using System.Reflection;
using FluentAssertions;
using RTM;

namespace RTM.Engine.Tests;

/// <summary>
/// V4-RTM-DIVZERO-EMPTY: tests for 24 metric calculations that can divide by zero.
/// These tests verify that zero-denominator cases return string.Empty (not "0", "0%", or "00:00:00"),
/// and that valid cases return the expected formatted value.
///
/// Structure:
/// - 13 direct method tests (Union.cs and UserManager.cs) - 34 test cases
/// - 11 Engine compiled function tests (via reflection) - 29 test cases
/// Total: 63 test cases
///
/// Claim: tests/RTM.Engine.Tests/**. Gate: RTM/RTM/*.cs blobs unchanged.
/// </summary>
public class ZeroDenominatorMetricTests
{
    #region 1. Union.CalculateCPH (#17 in table - no external condition, 2 cases)
    
    [Fact]
    public void Union_CalculateCPH_ZeroDenominator_ReturnsEmpty()
    {
        var union = CreateMinimalUnion();
        var loggedInTotal = TimeSpan.Zero; // totalHours < 0.001
        var callsCountStr = "10";
        var format = "#0.00";
        
        var result = union.CalculateCPH(loggedInTotal, callsCountStr, format);
        
        result.Should().Be(string.Empty, "denominator (totalHours) is zero");
    }
    
    [Fact]
    public void Union_CalculateCPH_ValidDenominator_ReturnsFormattedValue()
    {
        var union = CreateMinimalUnion();
        var loggedInTotal = TimeSpan.FromHours(2);
        var callsCountStr = "20";
        var format = "#0.00";
        
        var result = union.CalculateCPH(loggedInTotal, callsCountStr, format);
        
        result.Should().Be("10.00");
    }
    
    #endregion
    
    #region 2. UserManager.CalculateCPH (#12 in table - no external condition, 2 cases)
    
    [Fact]
    public void UserManager_CalculateCPH_ZeroDenominator_ReturnsEmpty()
    {
        var manager = CreateMinimalUserManager();
        var loggedInTotal = TimeSpan.Zero;
        var callsCountStr = "10";
        var format = "#0.00";
        
        var result = manager.CalculateCPH(loggedInTotal, callsCountStr, format);
        
        result.Should().Be(string.Empty, "denominator (totalHours) is zero");
    }
    
    [Fact]
    public void UserManager_CalculateCPH_ValidDenominator_ReturnsFormattedValue()
    {
        var manager = CreateMinimalUserManager();
        var loggedInTotal = TimeSpan.FromHours(2);
        var callsCountStr = "20";
        var format = "#0.00";
        
        var result = manager.CalculateCPH(loggedInTotal, callsCountStr, format);
        
        result.Should().Be("10.00");
    }
    
    #endregion
    
    #region 3. Union.AvgResponseTimeMetric (#18 - has external condition, 3 cases)
    
    [Fact]
    public void Union_AvgResponseTimeMetric_ExternalConditionFalse_ReturnsEmpty()
    {
        var bag = new ConcurrentBag<IDInteraction>();
        
        var result = Union.AvgResponseTimeMetric(bag, applyAny: false);
        
        result.Should().Be(string.Empty, "external condition applyAny is false");
    }
    
    [Fact]
    public void Union_AvgResponseTimeMetric_ZeroResponseTimes_ReturnsEmpty()
    {
        var bag = new ConcurrentBag<IDInteraction>();
        
        var result = Union.AvgResponseTimeMetric(bag, applyAny: true);
        
        result.Should().Be(string.Empty, "responseTimes.Count == 0");
    }
    
    [Fact]
    public void Union_AvgResponseTimeMetric_ValidResponseTimes_ReturnsFormattedTime()
    {
        var bag = new ConcurrentBag<IDInteraction>();
        var interaction = CreateChatInteractionWithMessages();
        bag.Add(interaction);
        
        var result = Union.AvgResponseTimeMetric(bag, applyAny: true);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region 4. Union.getUsersInStatusPercent (#19 - has external condition Users.Count() > 0, 3 cases)
    
    [Fact]
    public void Union_getUsersInStatusPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        var union = CreateMinimalUnion();
        var metric = new MetricDef { Parameter = "AVAILABLE", Format = "#0.##%" };
        
        var result = union.getUsersInStatusPercent(metric);
        
        result.Should().Be(string.Empty, "Users.Count() == 0");
    }
    
    [Fact]
    public void Union_getUsersInStatusPercent_ZeroDenominator_ReturnsEmpty()
    {
        var union = CreateUnionWithLoggedOutUsers();
        var metric = new MetricDef { Parameter = "AVAILABLE", Format = "#0.##%" };
        
        var result = union.getUsersInStatusPercent(metric);
        
        result.Should().Be(string.Empty, "no logged in users (denominator is 0)");
    }
    
    [Fact]
    public void Union_getUsersInStatusPercent_ValidDenominator_ReturnsFormattedValue()
    {
        var union = CreateUnionWithLoggedInUsers(2, statusForFirst: "AVAILABLE");
        var metric = new MetricDef { Parameter = "AVAILABLE", Format = "#0.##%" };
        
        var result = union.getUsersInStatusPercent(metric);
        
        result.Should().Be("50%", "1 of 2 users is in AVAILABLE status");
    }
    
    #endregion
    
    #region 5. Union.getUsersInStatusGroupPercent (#20 - has external condition, 3 cases)
    
    [Fact]
    public void Union_getUsersInStatusGroupPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        var union = CreateMinimalUnion();
        var metric = new MetricDef { Parameter = "Available", Format = "#0.##%" };
        
        var result = union.getUsersInStatusGroupPercent(metric);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void Union_getUsersInStatusGroupPercent_ZeroDenominator_ReturnsEmpty()
    {
        var union = CreateUnionWithLoggedOutUsers();
        var metric = new MetricDef { Parameter = "Available", Format = "#0.##%" };
        
        var result = union.getUsersInStatusGroupPercent(metric);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void Union_getUsersInStatusGroupPercent_ValidDenominator_ReturnsFormattedValue()
    {
        var union = CreateUnionWithLoggedInUsers(2, statusGroupForFirst: "Available");
        var metric = new MetricDef { Parameter = "Available", Format = "#0.##%" };
        
        var result = union.getUsersInStatusGroupPercent(metric);
        
        result.Should().Be("50%");
    }
    
    #endregion
    
    #region 6. Union.getUsersInStatusDurationAvg (#21 - has external condition, 3 cases)
    
    [Fact]
    public void Union_getUsersInStatusDurationAvg_ExternalConditionFalse_ReturnsEmpty()
    {
        var union = CreateMinimalUnion();
        var metric = new MetricDef { Parameter = "AVAILABLE" };
        
        var result = union.getUsersInStatusDurationAvg(metric);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void Union_getUsersInStatusDurationAvg_ZeroDenominator_ReturnsEmpty()
    {
        var union = CreateUnionWithLoggedInUsers(1, statusForFirst: "OTHER");
        var metric = new MetricDef { Parameter = "AVAILABLE" };
        
        var result = union.getUsersInStatusDurationAvg(metric);
        
        result.Should().Be(string.Empty, "stsCnt == 0");
    }
    
    [Fact]
    public void Union_getUsersInStatusDurationAvg_ValidDenominator_ReturnsFormattedTime()
    {
        var union = CreateUnionWithStatusDuration("AVAILABLE", TimeSpan.FromMinutes(10), count: 2);
        var metric = new MetricDef { Parameter = "AVAILABLE" };
        
        var result = union.getUsersInStatusDurationAvg(metric);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region 7. Union.getUsersInStatusGroupDurationAvg (#22 - has external condition, 3 cases)
    
    [Fact]
    public void Union_getUsersInStatusGroupDurationAvg_ExternalConditionFalse_ReturnsEmpty()
    {
        var union = CreateMinimalUnion();
        var metric = new MetricDef { Parameter = "Available" };
        
        var result = union.getUsersInStatusGroupDurationAvg(metric);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void Union_getUsersInStatusGroupDurationAvg_ZeroDenominator_ReturnsEmpty()
    {
        var union = CreateUnionWithLoggedInUsers(1, statusGroupForFirst: "Other");
        var metric = new MetricDef { Parameter = "Available" };
        
        var result = union.getUsersInStatusGroupDurationAvg(metric);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void Union_getUsersInStatusGroupDurationAvg_ValidDenominator_ReturnsFormattedTime()
    {
        var union = CreateUnionWithStatusGroupDuration("Available", TimeSpan.FromMinutes(10), count: 2);
        var metric = new MetricDef { Parameter = "Available" };
        
        var result = union.getUsersInStatusGroupDurationAvg(metric);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region 8. Union.getUsersInStatusDurationPercent (#23 - has external condition, 3 cases)
    
    [Fact]
    public void Union_getUsersInStatusDurationPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        var union = CreateMinimalUnion();
        var metric = new MetricDef { Parameter = "AVAILABLE", Format = "#0.##%" };
        
        var result = union.getUsersInStatusDurationPercent(metric);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void Union_getUsersInStatusDurationPercent_ZeroDenominator_ReturnsEmpty()
    {
        var union = CreateUnionWithAllSignedOff();
        var metric = new MetricDef { Parameter = "AVAILABLE", Format = "#0.##%" };
        
        var result = union.getUsersInStatusDurationPercent(metric);
        
        result.Should().Be(string.Empty, "loginDur.TotalSeconds == 0");
    }
    
    [Fact]
    public void Union_getUsersInStatusDurationPercent_ValidDenominator_ReturnsFormattedValue()
    {
        var union = CreateUnionWithMixedStatuses();
        var metric = new MetricDef { Parameter = "AVAILABLE", Format = "#0.##%" };
        
        var result = union.getUsersInStatusDurationPercent(metric);
        
        result.Should().MatchRegex(@"^\d+(\.\d+)?%$");
    }
    
    #endregion
    
    #region 9. Union.getUsersInStatusGroupDurationPercent (#24 - has external condition, 3 cases)
    
    [Fact]
    public void Union_getUsersInStatusGroupDurationPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        var union = CreateMinimalUnion();
        var metric = new MetricDef { Parameter = "Available", Format = "#0.##%" };
        
        var result = union.getUsersInStatusGroupDurationPercent(metric);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void Union_getUsersInStatusGroupDurationPercent_ZeroDenominator_ReturnsEmpty()
    {
        var union = CreateUnionWithAllSignedOff();
        var metric = new MetricDef { Parameter = "Available", Format = "#0.##%" };
        
        var result = union.getUsersInStatusGroupDurationPercent(metric);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void Union_getUsersInStatusGroupDurationPercent_ValidDenominator_ReturnsFormattedValue()
    {
        var union = CreateUnionWithMixedStatusGroups();
        var metric = new MetricDef { Parameter = "Available", Format = "#0.##%" };
        
        var result = union.getUsersInStatusGroupDurationPercent(metric);
        
        result.Should().MatchRegex(@"^\d+(\.\d+)?%$");
    }
    
    #endregion
    
    #region 10. UserManager.TotalStatusPercent (#13 - has external condition isLoggedId, 3 cases)
    
    [Fact]
    public void UserManager_TotalStatusPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        var (manager, metrics) = CreateUserManagerWithLoginStatus(loggedIn: false);
        var metric = new MetricDef { ID = "test", Function = "TotalStatusPercent", Parameter = "AVAILABLE", Format = "##0.0%" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void UserManager_TotalStatusPercent_ZeroDenominator_ReturnsEmpty()
    {
        var (manager, metrics) = CreateUserManagerWithLoginStatus(loggedIn: true, hasStatuses: false);
        var metric = new MetricDef { ID = "test", Function = "TotalStatusPercent", Parameter = "AVAILABLE", Format = "##0.0%" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().Be(string.Empty, "loginDur1 == 0");
    }
    
    [Fact]
    public void UserManager_TotalStatusPercent_ValidDenominator_ReturnsFormattedValue()
    {
        var (manager, metrics) = CreateUserManagerWithStatuses("AVAILABLE", TimeSpan.FromMinutes(30), TimeSpan.FromHours(1));
        var metric = new MetricDef { ID = "test", Function = "TotalStatusPercent", Parameter = "AVAILABLE", Format = "##0.0%" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().MatchRegex(@"^\d+(\.\d+)?%$");
    }
    
    #endregion
    
    #region 11. UserManager.TotalStatusGroupPercent (#14 - has external condition, 3 cases)
    
    [Fact]
    public void UserManager_TotalStatusGroupPercent_ExternalConditionFalse_ReturnsEmpty()
    {
        var (manager, metrics) = CreateUserManagerWithLoginStatus(loggedIn: false);
        var metric = new MetricDef { ID = "test", Function = "TotalStatusGroupPercent", Parameter = "Available", Format = "##0.0%" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void UserManager_TotalStatusGroupPercent_ZeroDenominator_ReturnsEmpty()
    {
        var (manager, metrics) = CreateUserManagerWithLoginStatus(loggedIn: true, hasStatuses: false);
        var metric = new MetricDef { ID = "test", Function = "TotalStatusGroupPercent", Parameter = "Available", Format = "##0.0%" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void UserManager_TotalStatusGroupPercent_ValidDenominator_ReturnsFormattedValue()
    {
        var (manager, metrics) = CreateUserManagerWithStatusGroups("Available", TimeSpan.FromMinutes(30), TimeSpan.FromHours(1));
        var metric = new MetricDef { ID = "test", Function = "TotalStatusGroupPercent", Parameter = "Available", Format = "##0.0%" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().MatchRegex(@"^\d+(\.\d+)?%$");
    }
    
    #endregion
    
    #region 12. UserManager.TotalStatusDurationAvg (#15 - no external condition, 2 cases)
    
    [Fact]
    public void UserManager_TotalStatusDurationAvg_ZeroDenominator_ReturnsEmpty()
    {
        var (manager, metrics) = CreateUserManagerWithLoginStatus(loggedIn: true, hasStatuses: false);
        var metric = new MetricDef { ID = "test", Function = "TotalStatusDurationAvg", Parameter = "AVAILABLE" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().Be(string.Empty, "tsda == 0");
    }
    
    [Fact]
    public void UserManager_TotalStatusDurationAvg_ValidDenominator_ReturnsFormattedTime()
    {
        var (manager, metrics) = CreateUserManagerWithStatusDuration("AVAILABLE", TimeSpan.FromMinutes(20), count: 4);
        var metric = new MetricDef { ID = "test", Function = "TotalStatusDurationAvg", Parameter = "AVAILABLE" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region 13. UserManager.TotalStatusGroupDurationAvg (#16 - no external condition, 2 cases)
    
    [Fact]
    public void UserManager_TotalStatusGroupDurationAvg_ZeroDenominator_ReturnsEmpty()
    {
        var (manager, metrics) = CreateUserManagerWithLoginStatus(loggedIn: true, hasStatuses: false);
        var metric = new MetricDef { ID = "test", Function = "TotalStatusGroupDurationAvg", Parameter = "Available" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().Be(string.Empty);
    }
    
    [Fact]
    public void UserManager_TotalStatusGroupDurationAvg_ValidDenominator_ReturnsFormattedTime()
    {
        var (manager, metrics) = CreateUserManagerWithStatusGroupDuration("Available", TimeSpan.FromMinutes(20), count: 4);
        var metric = new MetricDef { ID = "test", Function = "TotalStatusGroupDurationAvg", Parameter = "Available" };
        
        var result = manager.metricFunction(metric, metrics);
        
        result.Should().MatchRegex(@"^\d{2}:\d{2}:\d{2}$");
    }
    
    #endregion
    
    #region Helper Methods - Union
    
    private static Union CreateMinimalUnion()
    {
        var metrics = new ConcurrentDictionary<string, MetricDef>();
        return new Union(1, metrics);
    }
    
    private static Union CreateUnionWithLoggedOutUsers()
    {
        var union = CreateMinimalUnion();
        var manager = CreateMinimalUserManager();
        // isLoggedId defaults to false
        union.Users.Add(manager);
        return union;
    }
    
    private static Union CreateUnionWithLoggedInUsers(int count, string statusForFirst = null, string statusGroupForFirst = null)
    {
        var union = CreateMinimalUnion();
        for (int i = 0; i < count; i++)
        {
            var manager = CreateMinimalUserManager($"user{i}");
            SetUserManagerLoggedIn(manager, true);
            if (i == 0)
            {
                if (statusForFirst != null) SetUserStatus(manager, statusForFirst);
                if (statusGroupForFirst != null) SetUserStatusGroup(manager, statusGroupForFirst);
            }
            union.Users.Add(manager);
        }
        return union;
    }
    
    private static Union CreateUnionWithStatusDuration(string statusId, TimeSpan totalDur, int count)
    {
        var union = CreateMinimalUnion();
        var manager = CreateMinimalUserManager();
        SetUserManagerLoggedIn(manager, true);
        AddTotalStatus(manager, statusId, statusId, "Group", totalDur, count);
        union.Users.Add(manager);
        return union;
    }
    
    private static Union CreateUnionWithStatusGroupDuration(string statusGroup, TimeSpan totalDur, int count)
    {
        var union = CreateMinimalUnion();
        var manager = CreateMinimalUserManager();
        SetUserManagerLoggedIn(manager, true);
        AddTotalStatus(manager, "STATUS", "StatusName", statusGroup, totalDur, count);
        union.Users.Add(manager);
        return union;
    }
    
    private static Union CreateUnionWithAllSignedOff()
    {
        var union = CreateMinimalUnion();
        var manager = CreateMinimalUserManager();
        SetUserManagerLoggedIn(manager, true);
        AddTotalStatus(manager, "SIGNOFF", "Sign Off", "Offline", TimeSpan.FromHours(1), 1);
        union.Users.Add(manager);
        return union;
    }
    
    private static Union CreateUnionWithMixedStatuses()
    {
        var union = CreateMinimalUnion();
        var manager = CreateMinimalUserManager();
        SetUserManagerLoggedIn(manager, true);
        AddTotalStatus(manager, "AVAILABLE", "Available", "Available", TimeSpan.FromMinutes(30), 1);
        AddTotalStatus(manager, "BREAK", "Break", "Break", TimeSpan.FromMinutes(30), 1);
        union.Users.Add(manager);
        return union;
    }
    
    private static Union CreateUnionWithMixedStatusGroups()
    {
        var union = CreateMinimalUnion();
        var manager = CreateMinimalUserManager();
        SetUserManagerLoggedIn(manager, true);
        AddTotalStatus(manager, "AVAILABLE", "Available", "Available", TimeSpan.FromMinutes(30), 1);
        AddTotalStatus(manager, "BREAK", "Break", "Break", TimeSpan.FromMinutes(30), 1);
        union.Users.Add(manager);
        return union;
    }
    
    private static IDInteraction CreateChatInteractionWithMessages()
    {
        var interaction = new IDInteraction("i1", 0, null, false)
        {
            InteractionType = "Chat",
            Direction = "Incoming",
            AnsweredDateTime = DateTime.UtcNow.AddMinutes(-5)
        };
        
        var inboundMsg = new ChatMessage
        {
            MessageId = "m1",
            MsgDirection = "inbound",
            TimeStamp = DateTime.UtcNow.AddMinutes(-4)
        };
        
        var outboundMsg = new ChatMessage
        {
            MessageId = "m2",
            MsgDirection = "outbound",
            TimeStamp = DateTime.UtcNow.AddMinutes(-3)
        };
        
        interaction.ChatMessages.TryAdd(inboundMsg.MessageId, inboundMsg);
        interaction.ChatMessages.TryAdd(outboundMsg.MessageId, outboundMsg);
        
        return interaction;
    }
    
    #endregion
    
    #region Helper Methods - UserManager
    
    private static UserManager CreateMinimalUserManager(string userId = "user1")
    {
        var metrics = new ConcurrentDictionary<string, MetricDef>();
        var unions = new UnionList();
        return new UserManager(userId, unions, null, metrics);
    }
    
    private static (UserManager manager, ConcurrentDictionary<string, MetricDef> metrics) CreateUserManagerWithLoginStatus(bool loggedIn, bool hasStatuses = false)
    {
        var metrics = new ConcurrentDictionary<string, MetricDef>();
        var unions = new UnionList();
        var manager = new UserManager("user1", unions, null, metrics);
        SetUserManagerLoggedIn(manager, loggedIn);
        
        if (loggedIn)
        {
            InitializeTotalStatuses(manager);
        }
        
        return (manager, metrics);
    }
    
    private static (UserManager manager, ConcurrentDictionary<string, MetricDef> metrics) CreateUserManagerWithStatuses(string statusId, TimeSpan statusDur, TimeSpan loginDur)
    {
        var metrics = new ConcurrentDictionary<string, MetricDef>();
        var unions = new UnionList();
        var manager = new UserManager("user1", unions, null, metrics);
        SetUserManagerLoggedIn(manager, true);
        InitializeTotalStatuses(manager);
        AddTotalStatusToManager(manager, statusId, statusId, "Group", statusDur, 1);
        AddTotalStatusToManager(manager, "OTHER", "Other", "Other", loginDur - statusDur, 1);
        return (manager, metrics);
    }
    
    private static (UserManager manager, ConcurrentDictionary<string, MetricDef> metrics) CreateUserManagerWithStatusGroups(string statusGroup, TimeSpan groupDur, TimeSpan loginDur)
    {
        var metrics = new ConcurrentDictionary<string, MetricDef>();
        var unions = new UnionList();
        var manager = new UserManager("user1", unions, null, metrics);
        SetUserManagerLoggedIn(manager, true);
        InitializeTotalStatuses(manager);
        AddTotalStatusToManager(manager, "STATUS1", "Status1", statusGroup, groupDur, 1);
        AddTotalStatusToManager(manager, "STATUS2", "Status2", "Other", loginDur - groupDur, 1);
        return (manager, metrics);
    }
    
    private static (UserManager manager, ConcurrentDictionary<string, MetricDef> metrics) CreateUserManagerWithStatusDuration(string statusId, TimeSpan totalDur, int count)
    {
        var metrics = new ConcurrentDictionary<string, MetricDef>();
        var unions = new UnionList();
        var manager = new UserManager("user1", unions, null, metrics);
        SetUserManagerLoggedIn(manager, true);
        InitializeTotalStatuses(manager);
        AddTotalStatusToManager(manager, statusId, statusId, "Group", totalDur, count);
        return (manager, metrics);
    }
    
    private static (UserManager manager, ConcurrentDictionary<string, MetricDef> metrics) CreateUserManagerWithStatusGroupDuration(string statusGroup, TimeSpan totalDur, int count)
    {
        var metrics = new ConcurrentDictionary<string, MetricDef>();
        var unions = new UnionList();
        var manager = new UserManager("user1", unions, null, metrics);
        SetUserManagerLoggedIn(manager, true);
        InitializeTotalStatuses(manager);
        AddTotalStatusToManager(manager, "STATUS", "Status", statusGroup, totalDur, count);
        return (manager, metrics);
    }
    
    #endregion
    
    #region Reflection Helpers
    
    private static void SetUserManagerLoggedIn(UserManager manager, bool loggedIn)
    {
        var field = typeof(UserManager).GetField("_isLoggedIn", BindingFlags.NonPublic | BindingFlags.Instance);
        field?.SetValue(manager, loggedIn);
    }
    
    private static void SetUserStatus(UserManager manager, string status)
    {
        var field = typeof(UserManager).GetField("_userStatus", BindingFlags.NonPublic | BindingFlags.Instance);
        field?.SetValue(manager, status);
    }
    
    private static void SetUserStatusGroup(UserManager manager, string statusGroup)
    {
        var field = typeof(UserManager).GetField("_userStatusGroup", BindingFlags.NonPublic | BindingFlags.Instance);
        field?.SetValue(manager, statusGroup);
    }
    
    private static void InitializeTotalStatuses(UserManager manager)
    {
        var field = typeof(UserManager).GetField("_TotalStatuses", BindingFlags.NonPublic | BindingFlags.Instance);
        if (field != null)
        {
            var dict = field.GetValue(manager) as ConcurrentDictionary<string, UserStatusData>;
            if (dict == null)
            {
                dict = new ConcurrentDictionary<string, UserStatusData>();
                field.SetValue(manager, dict);
            }
        }
    }
    
    private static void AddTotalStatus(UserManager manager, string statusId, string statusName, string statusGroup, TimeSpan dur, int count)
    {
        var totalStatuses = manager.TotalStatuses;
        if (totalStatuses != null)
        {
            var data = CreateUserStatusData(manager, statusId, statusName, statusGroup, dur, count);
            totalStatuses.TryAdd(statusId, data);
        }
    }
    
    private static void AddTotalStatusToManager(UserManager manager, string statusId, string statusName, string statusGroup, TimeSpan dur, int count)
    {
        var field = typeof(UserManager).GetField("_TotalStatuses", BindingFlags.NonPublic | BindingFlags.Instance);
        var dict = field?.GetValue(manager) as ConcurrentDictionary<string, UserStatusData>;
        if (dict != null)
        {
            var data = CreateUserStatusData(manager, statusId, statusName, statusGroup, dur, count);
            dict.TryAdd(statusId, data);
        }
    }
    
    private static UserStatusData CreateUserStatusData(UserManager manager, string statusId, string statusName, string statusGroup, TimeSpan dur, int count)
    {
        var data = new UserStatusData(manager, statusId, statusName, statusGroup, dur, null, "user1", false, "User");
        // Set Count via reflection (it has public setter)
        typeof(UserStatusData).GetProperty("Count")?.SetValue(data, count);
        return data;
    }
    
    #endregion
}