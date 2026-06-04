using Microsoft.AspNetCore.DataProtection.KeyManagement;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.Emit;
using RTM.Configuration;
using RTM.Tools;
using RTM.Types;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Data;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Timers;
using Timer = System.Timers.Timer;


namespace RTM
{
    public class Engine : IDisposable
    {
        private DBMng _dbMng = null;


        // CallsList
        private CallsList CallsList { get; set; } = new CallsList();

        public UnionList UnionList { get; set; } = new UnionList();
        private ApplicList _applicList = null;
        private CellList _cellList = new CellList();
        private GridList _gridList = new GridList();

        private WorkgroupManagerList _workgroupManagerList = new WorkgroupManagerList();
        private UserManagerList _userManagerList = new UserManagerList();

        private CollectData _collectData = null;
        

        // Timers
        private Timer midnightTimer = null;


        private Timer reloadDataTimer = null;


        private ConcurrentQueue<string> _lastDisconnectedQ = new ConcurrentQueue<string>();

        private IDInteractionsList _interactionsList = null;


      

        private static Dictionary<string, MetricDef> _metrics = null;

        private static Dictionary<int, Statistic> _statistics = null;

        private static ConcurrentDictionary<string, List<Cell>> _statisticsCells = new ConcurrentDictionary<string, List<Cell>>();

        private ConcurrentDictionary<string, MetricDef> _userGridMetrics = new ConcurrentDictionary<string, MetricDef>();

        private ConcurrentDictionary<string, MetricDef> UserViewMetrics { get; set; } = new ConcurrentDictionary<string, MetricDef>();


        public ConcurrentDictionary<int, string> CurrentDataGrids { get; set; } = new ConcurrentDictionary<int, string>();


        public ConcurrentDictionary<int, UserGrid> AgentGrids { get; set; } = new ConcurrentDictionary<int, UserGrid>();


        public ConcurrentDictionary<string, Site> SitesTable { get; set; } = new ConcurrentDictionary<string, Site>();



        private string MachineName { get; set; }



        private List<Dictionary<string, string>> UnionQueueClassifications { get; set; }

        private List<Dictionary<string, string>> UnionUserGroups { get; set; }


        private List<string> AgentWGPerfixList { get; set; } = new List<string>();




        // ====== Events ======
        public delegate void GridEventHandler(object sender, GridEventArgs e);
        public event GridEventHandler GridEvent;

        public delegate void UserGridEventHandler(object sender, UserGridEventArgs e);
        public event UserGridEventHandler UserGridEvent;

        public delegate void UserViewEventHandler(object sender, UserViewEventArgs e);
        public event UserViewEventHandler UserViewEvent;

        public delegate void UserUnionDeactivateEventHandler(object sender, UserUnionActivationEventArgs e);
        public event UserUnionDeactivateEventHandler UserUnionDeactivateEvent;







        //=================================== C O N S T R A C T O R  =========================================
        public Engine(IConfiguration configuration)
        {
            try
            {
                AsyncLogger.Info("Engine Start");

                // Set Connection String
                var connectionString = AppConfig.RTMConnectionString;
                DBAdapter.ConnectionString = connectionString;


                // Set AgentWGPerfixList
                try
                {
                    string agentWGPerfix = AppConfig.AgentWGPerfix;            
                    AgentWGPerfixList = agentWGPerfix.Split(',').ToList();
                    AsyncLogger.Info("AgentWGPerfixList = " + agentWGPerfix);
                }
                catch (Exception ex)
                {
                    AsyncLogger.Error("AgentWGPerfix", ex);
                }
                   
                // DB Mng
                MachineName = Environment.MachineName;
                _dbMng = new DBMng(MachineName);
                         
                
                // Start Lists
                _userManagerList.UserViewEvent += _userManagerList_UserViewEvent;
           
                _applicList = new ApplicList(UnionList);
             
                _interactionsList = new IDInteractionsList(UnionList);


                // Load Data
                LoadData(false);


                // Forcach Grid
                foreach (var grid in _gridList.Values)
                {
                    if (grid.Connections.Count == 0)
                    {
                        grid.InUse = false;
                        AsyncLogger.Info("Grid " + grid.GridId + " NOT in use");
                    }
                    else
                    {
                        grid.InUse = true;
                        AsyncLogger.Info("Grid " + grid.GridId + " In use");
                    }
                }


                // Restore Interactions From DB
                AsyncLogger.Info("Restore Interactions From DB");
                try
                {
                    Dictionary<string, UserManager> todayInteractionUsers = new Dictionary<string, UserManager>();

                    var dataTable = _dbMng.getIntercations();

                    foreach (DataRow row in dataTable.Rows)
                    {
                        string interactionId = row[0].ToString();
                        int segment = DBAdapter.getIntValue(row[1].ToString());
                        string workgroup = row[2].ToString();
                        string classificationCode = row[3].ToString();
                        string interactionType = row[4].ToString();
                        string callType = row[5].ToString();
                        string direction = row[6].ToString();
                        string customCallData = row[7].ToString();
                        string remoteAddress = row[8].ToString();
                        string userId = row[9].ToString();
                        bool isTransferred = DBAdapter.getBoolValue(row[10].ToString(), false);
                        bool isAnswered = DBAdapter.getBoolValue(row[11].ToString(), false);
                        bool isInQueue = false;// DBAdapter.getBoolValue(row[12].ToString(), false);
                        bool isTalk = false; // DBAdapter.getBoolValue(row[13].ToString(), false);
                        bool isAbandoned = DBAdapter.getBoolValue(row[14].ToString(), false);
                        bool isMessaging = DBAdapter.getBoolValue(row[15].ToString(), false);
                        Double timeInQueue = DBAdapter.getIntValue(row[16].ToString());
                        Double talkTime = DBAdapter.getIntValue(row[17].ToString());
                        DateTime inQueueDateTime = DBAdapter.getDateTimeValue(row[18].ToString());
                        DateTime answeredDateTime = DBAdapter.getDateTimeValue(row[19].ToString());
                        string lastUserId = row[20].ToString();
                        string lastWorkgroup = row[21].ToString();
                        string customCallData1 = row[22].ToString();
                        string customCallData2 = row[23].ToString();
                        string customCallData3 = row[24].ToString();
                        string customCallData4 = row[25].ToString();
                        string customCallData5 = row[26].ToString(); 
                        string customCallData6 = row[27].ToString();
                        string customCallData7 = row[28].ToString();
                        string customCallData8 = row[29].ToString();
                        string customCallData9 = row[30].ToString();
                        string customCallData10 = row[31].ToString();
                        string customCallData11 = row[32].ToString();
                        string customCallData12 = row[33].ToString();
                        string customCallData13 = row[34].ToString();
                        string customCallData14 = row[35].ToString();
                        string customCallData15 = row[36].ToString();
                        string customCallData16 = row[37].ToString();
                        string customCallData17 = row[38].ToString();
                        string customCallData18 = row[39].ToString();
                        string customCallData19 = row[40].ToString();
                        string customCallData20 = row[41].ToString();
                        bool isCallbackRequest = DBAdapter.getBoolValue(row[42].ToString(), false);
                        string timeZone = row[43].ToString();
                        string serverId = row[44].ToString();
                        bool isInserted = (MachineName == serverId);
                        string state = "";
                        IDInteraction idInteraction = new IDInteraction(interactionId, segment, _dbMng, isInserted) // state, classificationCode, interactionType,
                            //callType, direction, customCallData, remoteAddress, customCallData1, customCallData2, customCallData3, customCallData4,
                            //customCallData5, customCallData6, customCallData7, customCallData8, customCallData9, customCallData10,
                            //customCallData11, customCallData12, customCallData13, customCallData14, customCallData15, customCallData16,
                            //customCallData17, customCallData18, customCallData19, customCallData20, isCallbackRequest, _dbMng, isInserted)
                        {
                            State = state,
                            Workgroup = workgroup,
                            InteractionType = interactionType,
                            CallType = callType,
                            Direction = direction,
                            CustomCallData = customCallData,
                            RemoteAddress = remoteAddress,
                            ClassificationCode = classificationCode,

                            CustomCallData1 = customCallData1,
                            CustomCallData2 = customCallData2,
                            CustomCallData3 = customCallData3,
                            CustomCallData4 = customCallData4,
                            CustomCallData5 = customCallData5,
                            CustomCallData6 = customCallData6,
                            CustomCallData7 = customCallData7,
                            CustomCallData8 = customCallData8,
                            CustomCallData9 = customCallData9,
                            CustomCallData10 = customCallData10,
                            CustomCallData11 = customCallData11,
                            CustomCallData12 = customCallData12,
                            CustomCallData13 = customCallData13,
                            CustomCallData14 = customCallData14,
                            CustomCallData15 = customCallData15,
                            CustomCallData16 = customCallData16,
                            CustomCallData17 = customCallData17,
                            CustomCallData18 = customCallData18,
                            CustomCallData19 = customCallData19,
                            CustomCallData20 = customCallData20,

                            UserId = userId,
                            IsAnswered = isAnswered,
                            IsInQueue = isInQueue,
                            IsTalk = false, // isTalk,
                            IsAbandoned = isAbandoned,
                            IsMessaging = isMessaging,
                            TimeInQueue = timeInQueue,
                            TalkTime = talkTime,
                            InQueueDateTime = inQueueDateTime,
                            AnsweredDateTime = answeredDateTime,
                            LastUserId = lastUserId,
                            LastWorkgroup = lastWorkgroup,
                            IsTransferred = isTransferred,
                            IsCallbackRequest = isCallbackRequest,
                            TimeZone = timeZone
                        };

                        if (!isInQueue)
                        {
                            _interactionsList.Add(idInteraction, false);

                            var userMng = getUserManager(userId);

                            if (isAnswered)
                            {
                                userMng.TodayUserInteractions.Add(idInteraction);
                            }

                            if (!todayInteractionUsers.ContainsKey(userId))
                            {
                                todayInteractionUsers.Add(userId, userMng);
                            }
                        }

                    }

                    UnionList.addAllInteractions(_interactionsList.getList(), _applicList);


                    

                    // ===========================================================================================================================================================================


                    AsyncLogger.Info(" Restore Users Status From DB");
                    dataTable = _dbMng.getUsersStatuses();

                    foreach (DataRow row in dataTable.Rows)
                    {
                        string userId = row[0].ToString();
                        string statusId = row[1].ToString();
                        string statusName = row[2].ToString();
                        string statusGroup = row[3].ToString();
                        int totalDuration = DBAdapter.getIntValue(row[4].ToString());
                        int maxDuraction = DBAdapter.getIntValue(row[5].ToString());
                        int totalCount = DBAdapter.getIntValue(row[6].ToString());
                        string displayName = row[7].ToString();
                        string timeZone = row[8].ToString();
                        DateTime updateTime = DBAdapter.getDateTimeValue(row[9].ToString());
                        string serverId = row[10].ToString();                    

                        var userManger = getUserManager(userId);

                        bool isInserted = (MachineName == serverId);
                        UserStatusData userStatusData = new UserStatusData(userManger, statusId, statusName, statusGroup, TimeSpan.FromSeconds(Convert.ToDouble(totalDuration)), _dbMng, userId, isInserted, displayName);

                        userStatusData.Max = TimeSpan.FromSeconds(Convert.ToDouble(maxDuraction));
                        userStatusData.Count = totalCount;
                        userManger.TotalStatuses.TryAdd(statusId, userStatusData);
                        userManger.IsTodayLoggedIn = true;
                    }


                    int calcInterval = 2;

                    try
                    {
                        calcInterval = AppConfig.CalcInterval;                 
                    }
                    catch (Exception ex)
                    {
                        AsyncLogger.Error("Engine: CalcInterval is not a number", ex);
                    }

                    AsyncLogger.Info("CalcInterval = " + calcInterval);

                    _collectData = new CollectData(UnionList, _gridList, _interactionsList, _userManagerList, _userGridMetrics, calcInterval);


                }
                catch (Exception ex)
                {
                    AsyncLogger.Error("Engine.Engine.getIntercations", ex);
                }
                        
                startMidnightTimer();
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.Engine", ex);
            }
        }





        public void LoadData(bool addAllInteractions)
        {
            try
            {

                AsyncLogger.Info("LoadData: Start");

                SitesTable = RealtimeData.getSiteTable();

                List<Union> newUnions = new List<Union>();

                AsyncLogger.Info("LoadData: Read From DB");
                UnionQueueClassifications = RealtimeData.GetAllUnionQueueClassifications();
                UnionUserGroups = RealtimeData.GetAllUnionUserGroups();
                var dataCells = RealtimeData.getDataCells();
                var statisticCells = RealtimeData.getStatisticCells();
                _metrics = RealtimeData.GetAllMetrics();
                _statistics = RealtimeData.GetAllStatistics();
                var unionUsersMetrics = RealtimeData.getUnionUsersMetrics();
                AgentGrids = RealtimeData.getAllUserGrid();
                var userViewHtmlSettings = RealtimeData.getUserViewHtmlSettings();


                // Set Metric Functions
                setMetricFunctions();
                setUserMetricFunctions();


                AsyncLogger.Info("LoadData: Metrics");
                foreach (var metric in _metrics.Values)
                {
                    if (metric.DataType == "User")
                    {
                        setUserMetricFunctions(metric);

                        if (_userGridMetrics.ContainsKey(metric.ID))
                        {
                            _userGridMetrics[metric.ID] = metric;
                        }
                        else
                        {
                            _userGridMetrics.TryAdd(metric.ID, metric);
                        }
                    }
                    else
                    {
                        setMetricFunctions(metric);
                    }
                }


                //============== Union Queue Classifications ==============
                AsyncLogger.Info("LoadData: Union Queue Classifications");

                var updatedUnionsList = new Dictionary<int, List<string>>();


                foreach (var uqc in UnionQueueClassifications)
                {
                    int unionId = Convert.ToInt32(uqc["UnionId"]);
                    string QueueId = uqc["QueueId"];
                    string ClassificationId = uqc["ClassificationId"];
                    string timeZone = uqc["timeZone"];
                    TimeSpan clearTime = TimeSpan.Parse(uqc["clearTime"]);                  


                    Union union = null;
                    if (UnionList.ContainsKey(unionId))
                    {
                        union = UnionList[unionId];
                    }
                    else
                    {
                        union = new Union(unionId, _metrics);
                        UnionList.TryAdd(unionId, union);
                        newUnions.Add(union);
                    }
                    union.TimeZone = timeZone;
                    union.ClearTime = clearTime;


                    List<string> updatedUnion;
                    if (updatedUnionsList.ContainsKey(unionId))
                    {
                        updatedUnion = updatedUnionsList[unionId];
                    }
                    else
                    {
                        updatedUnion = new List<string>();
                        updatedUnionsList.Add(unionId, updatedUnion);
                    }



                    if (QueueId == "ALL")
                    {
                        if (!union.Classifications.Contains(ClassificationId))
                        {
                            union.Classifications.Add(ClassificationId);
                            union.addWorkgroup(QueueId, _applicList);
                            newUnions.Add(union);
                        }

                    }
                    else if (ClassificationId == "ALL")
                    {
                        updatedUnion.Add(QueueId);
                        if (!union.Queues.Contains(QueueId))
                        {
                            union.Queues.Add(QueueId);
                            union.addWorkgroup(QueueId, _applicList);
                            newUnions.Add(union);
                            // Persist queue to NGC_Queues
                            BusinessUnitData.getOrCreateQueue(QueueId, QueueId);
                        }
                    }
                    else
                    {
                        var applicId = new QueueClassification(QueueId, ClassificationId);

                        Applic applic = null;

                        if (_applicList.ContainsKey(applicId))
                        {
                            applic = _applicList[applicId];
                        }
                        else
                        {
                            applic = new Applic(applicId);
                            _applicList.TryAdd(applicId, applic);
                        }

                        if (union.Applics.TryAdd(applicId, applic))
                        {
                            newUnions.Add(union);
                        }
                    }
                }


                //============== Union User Groups ==============
                AsyncLogger.Info("LoadData: Union User Groups");
                var subscribedUnionEvents = new HashSet<int>();
                foreach (var uug in UnionUserGroups)
                {
                    int unionId = Convert.ToInt32(uug["UnionId"]);
                    int supergroupId = Convert.ToInt32(uug["SupergroupId"]);
                    string usergroupId = uug["UsergroupId"];
                    string timeZone = uug["timeZone"];
                    TimeSpan clearTime = TimeSpan.Parse(uug["clearTime"]);


                    Union union = null;

                    if (UnionList.ContainsKey(unionId))
                    {
                        union = UnionList[unionId];
                    }
                    else
                    {
                        union = new Union(unionId, _metrics);
                        //union.addAllInteractions(_interactionsList.getList(), _applicList);
                        UnionList.TryAdd(unionId, union);
                        newUnions.Add(union);
                    }
                    union.TimeZone = timeZone;
                    union.ClearTime = clearTime;

                    if (unionUsersMetrics.ContainsKey(unionId))
                    {
                        foreach (var m in unionUsersMetrics[unionId])
                        {
                            if (_userGridMetrics.ContainsKey(m))
                            {
                                union.UserGridMetrics.TryAdd(m, _userGridMetrics[m]);
                            }
                        }
                    }

                    if (subscribedUnionEvents.Add(unionId))
                    {
                        union.UserGridEvent += Union_UserGridEvent;
                        union.UserUnionDeactivateEvent += _userManagerList_UserUnionDeactivateEvent;
                    }


                    List<string> supergroup = union.UserGroups.GetOrAdd(supergroupId, new List<string>());

                    if (!supergroup.Contains(usergroupId))
                    {
                        supergroup.Add(usergroupId);
                    }
                }


                AsyncLogger.Info("LoadData: AgentGrids");
                foreach (var userGrid in AgentGrids.Values)
                {
                    try
                    {
                        int unionId = userGrid.UnionId;
                        Union union = UnionList[unionId];
                        union.AgentGrids.TryAdd(userGrid.GridId, userGrid);

                        string rowsFilter = userGrid.RowsFilter;

                        var pattern = @"\[(.*?)\]";
                        var matches = Regex.Matches(rowsFilter, pattern);

                        foreach (Match m in matches)
                        {
                            string metric = m.Groups[1].Value;

                            if (UnionList.ContainsKey(unionId))
                            {
                                if (!union.UserGridMetrics.ContainsKey(metric))
                                {
                                    if (_userGridMetrics.ContainsKey(metric))
                                    {
                                        union.UserGridMetrics.TryAdd(metric, _userGridMetrics[metric]);
                                    }
                                }
                            }
                        }
                    }
                    catch (Exception ex)
                    {

                    }
                }


                AsyncLogger.Info("LoadData: userViewHtmlSettings");
                foreach (var val in userViewHtmlSettings)
                {
                    var pattern = @"\[(.*?)\]";
                    var matches = Regex.Matches(val, pattern);

                    foreach (Match m in matches)
                    {
                        string metric = m.Groups[1].Value;

                        if (_userGridMetrics.ContainsKey(metric))
                        {
                            UserViewMetrics.TryAdd(metric, _userGridMetrics[metric]);
                        }
                    }
                }



                //============== Cells Metrics ==============
                AsyncLogger.Info("LoadData: DataCells");
                foreach (var cell in dataCells)
                {
                    int cellId = Convert.ToInt32(cell["CellId"]);
                    int gridId = Convert.ToInt32(cell["GridId"]);
                    string metric = cell["Metric"];
                    int unionId = Convert.ToInt32(cell["UnionId"]);

                    if (UnionList.ContainsKey(unionId))
                    {
                        Grid grid = null;

                        if (!_gridList.ContainsKey(gridId))
                        {
                            grid = new Grid(gridId);
                            grid.GridEvent += Grid_GridEvent;
                            _gridList.TryAdd(gridId, grid);
                        }
                        else
                        {
                            grid = _gridList[gridId];
                        }

                        Cell newCell = null;
                        if (!_cellList.ContainsKey(cellId))
                        {
                            newCell = new Cell(cellId, grid, unionId, metric);
                            _cellList.TryAdd(cellId, newCell);
                        }
                        else
                        {
                            newCell = _cellList[cellId];

                            if (UnionList.ContainsKey(newCell.UnionId))
                            {
                                Union oldUnion = UnionList[newCell.UnionId];

                                if (oldUnion.Metrics.ContainsKey(newCell.Metric))
                                {
                                    Metric oldUnionMetric = oldUnion.Metrics[newCell.Metric];
                                    oldUnionMetric.Cells.TryRemove(cellId, out _);
                                }
                            }

                            newCell.UnionId = unionId;
                            newCell.Metric = metric;
                        }

                        Union union = UnionList[unionId];
                        Metric unionMetric = union.Metrics.GetOrAdd(metric, new Metric(union));
                        unionMetric.Cells.TryAdd(cellId, newCell);

                        try
                        {                            
                            union.addDataMetric(_metrics[metric]);
                            unionMetric.setCellValue(newCell);
                        }
                        catch (Exception ex)
                        {
                            AsyncLogger.Error("Engine union=" + union.UnionId + " Metric=" + metric, ex);
                        }

                    }
                }



                //============== Cells Statistics ==============
                AsyncLogger.Info("LoadData: StatisticCells");
                foreach (var cell in statisticCells)
                {
                    int cellId = Convert.ToInt32(cell["CellId"]);
                    int gridId = Convert.ToInt32(cell["GridId"]);
                    int statisticId = Convert.ToInt32(cell["StatisticId"]);


                    if (!_cellList.ContainsKey(cellId))
                    {
                        Grid grid = null;

                        if (!_gridList.ContainsKey(gridId))
                        {
                            grid = new Grid(gridId);
                            grid.GridEvent += Grid_GridEvent;
                            _gridList.TryAdd(gridId, grid);
                        }
                        else
                        {
                            grid = _gridList[gridId];
                        }

                        Cell newCell = new Cell(cellId, grid, -1, string.Empty);
                        _cellList.TryAdd(cellId, newCell);

                        Statistic statistic = null;

                        if (_statistics.TryGetValue(statisticId, out statistic))
                        {
                            var listCell = _statisticsCells.GetOrAdd(Statistic.getJsonString(statistic), new List<Cell>());
                            listCell.Add(newCell);
                        }

                    }
                }

                if (addAllInteractions)
                {
                    AsyncLogger.Info("LoadData: addAllInteractions");

                    foreach (var updatedUnion in updatedUnionsList)
                    {
                        int unionId = updatedUnion.Key;
                        var oldQueues = UnionList[unionId].Queues;
                        var newQueues = updatedUnion.Value;
                        var removedQueues = oldQueues.Except(newQueues).ToList();

                        foreach (var queue in removedQueues)
                        {
                            AsyncLogger.Info("RemovedQueue unionId=" + unionId + " queue=" + queue);
                            oldQueues.Remove(queue);

                            var applicId = new QueueClassification(queue, "ALL");
                            UnionList[unionId].Applics.TryRemove(applicId, out _);

                            newUnions.Add(UnionList[unionId]);
                        }
                    }

                    foreach (var union in newUnions)
                    {
                        AsyncLogger.Info("addAllInteractions unionId=" + union.UnionId);
                        union.addAllInteractions(_interactionsList.getList(), _applicList, true);
                    }                  
                }

                // Force all existing UserManagers to pick up newly added column metrics.
                // Without this, new metrics only appear after an agent's next workgroup event.
                AsyncLogger.Info("LoadData: ForceRefreshMetrics for all UserManagers");
                foreach (var userMng in _userManagerList.Values)
                {
                    userMng.ForceRefreshMetrics();
                }

                AsyncLogger.Info("LoadData End");
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.LoadData", ex);
            }
        }





        public string GetCell(string cellId)
        {
            string retVal = "Cell not exists";

            int iCellId = Convert.ToInt32(cellId);

            if (_cellList.ContainsKey(iCellId))
            {
                Cell cell = _cellList[iCellId];

                retVal = "Value=" + cell.Value + " isChanged=" + cell.IsChanged;

                cell.IsChanged = true;
            }

            return retVal;
        }




        private void _userManagerList_UserUnionDeactivateEvent(object sender, UserUnionActivationEventArgs e)
        {
            if (UserUnionDeactivateEvent != null)
            {
                UserUnionDeactivateEvent(this, new UserUnionActivationEventArgs(e.UserData, e.UnionId));
            }
        }


        private string fixUserData(string val)
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(val) && (val[0] == '+'))
                {
                    try
                    {
                        char firstChr = val[0];
                        val = val.Substring(1);
                        DateTime signonTimeDT = DateTime.ParseExact(val, "dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
                        TimeSpan signonTimeTS = DateTime.Now.Subtract(signonTimeDT);
                        val = firstChr + signonTimeTS.ToString(@"hh\:mm\:ss");
                    }
                    catch
                    {
                        val = "&nbsp;";
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("fixUserData", ex);
            }


            return val;
        }




        private void _userManagerList_UserViewEvent(object sender, UserViewEventArgs e)
        {
            if (UserViewEvent != null)
            {
                UserViewEvent(this, e);
            }
        }



        private void Union_UserGridEvent(object sender, UserGridEventArgs e)
        {
            try
            {
                //UserDataList userDataList = new UserDataList(e.UnionId);

                /*foreach (var ud in e.UnionId)
                {
                    //UserData userData = new UserData();
                    //userData.UserId = ud.Key;

                    UserData userBroadcastData = new UserData();
                    userBroadcastData.UserId = ud.Key;

                    foreach (var u in ud.Value)
                    {
                        string val = u.Value;
                        //userData.Data.TryAdd(u.Key, val);

                        val = fixUserData(val);

                        userBroadcastData.Data.TryAdd(u.Key, val);
                    }

                    //userDataList.Users.TryAdd(ud.Key, userData);


                    if (UserViewEvent != null)
                    {
                        UserViewEvent(this, new UserViewEventArgs(userData.UserId, userBroadcastData.Data));
                    }
                }*/

                //UserGrids.setUserGrid(e.UnionId, userDataList);
                //AsyncLogger.Info("Union_UserGridEvent UnionId=" + e.UnionId);


                if (UserGridEvent != null)
                {
                    UserGridEvent(this, e);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union_UserGridEvent", ex);
            }
        }



        private AllCellsData _allCellsData = new AllCellsData();

        private void Grid_GridEvent(object sender, GridEventArgs e)
        {
            try
            {
                ConcurrentDictionary<int, CellData> cells = new ConcurrentDictionary<int, CellData>();

                foreach (var cellValue in e.CellsValuesList)
                {
                    int cellId = cellValue.Key;
                    string value = cellValue.Value;
                    CellData cell = new CellData(cellId, new GridData(e.GridId));
                    cell.Value2 = value;

                    // ================================================

                    if (!string.IsNullOrWhiteSpace(value) && (value[0] == '+'))
                    {
                        try
                        {
                            char firstChr = value[0];
                            value = value.Substring(1);
                            DateTime signonTimeDT = DateTime.ParseExact(value, "dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
                            TimeSpan signonTimeTS = DateTime.Now.Subtract(signonTimeDT);
                            value = firstChr + signonTimeTS.ToString(@"hh\:mm\:ss");
                        }
                        catch
                        {
                            value = "&nbsp;";
                        }
                    }

                    // ================================================

                    cell.Value = value;


                    cells.TryAdd(cellId, cell);
                }

                e.CellsValuesData = cells.Values;

                if (GridEvent != null)
                {
                    GridEvent(this, e);
                }

                //BroadcastGridData(e.GridId.ToString(), cells.Values);            

                _allCellsData.Add(cells);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Grid_GridEvent", ex);
            }
        }





        private void midnightTimer_Elapsed(object sender, ElapsedEventArgs e)
        {
            //_dbMng.midnightClear();

            //_interactionsList.Clear();

            //InteractionsEvents.Clear();

            //foreach (UserManager user in _userManagerList.Values)
            //{
            //    user.midnightClear();
            //}

            //UnionList.midnightClear();

            //midnightTimer.Stop();
            //startMidnightTimer();
        }



        private void startMidnightTimer()
        {
            ScheduleNextCheck();

            //double time2Midnight = DateTime.Today.AddDays(1).Subtract(DateTime.Now).TotalMilliseconds;
            //AsyncLogger.Info("============== Start MidnightTimer============== Time to Midnight = " + time2Midnight);

            //midnightTimer = new Timer(time2Midnight);
            //midnightTimer.Elapsed += midnightTimer_Elapsed;
            //midnightTimer.Start();
        }




        private System.Threading.Timer TZTimer;




        private readonly ConcurrentDictionary<string, DateOnly> _lastClearLocalDateByUnion = new();




        private void ScheduleNextCheck()
        {
            DateTime? nextClearTime = GetNextClearTime();

            if (!nextClearTime.HasValue)
            {
                AsyncLogger.Error("ScheduleNextCheck | nextClearTime is null", null);
                return;
            }

            var now = DateTime.Now;
            TimeSpan dueTime = nextClearTime.Value - now;

            if (dueTime < TimeSpan.Zero)
                dueTime = TimeSpan.Zero;

            if (dueTime < TimeSpan.FromSeconds(1))
            {
                AsyncLogger.Info(
                    $"ScheduleNextCheck | dueTime adjusted from {dueTime.TotalSeconds:F3}s to 1s");
                dueTime = TimeSpan.FromSeconds(1);
            }

            AsyncLogger.Info(
                $"ScheduleNextCheck | serverNow={now:O} utcNow={DateTime.UtcNow:O} " +
                $"nextClearTime={nextClearTime.Value:O} dueSeconds={dueTime.TotalSeconds:F1}");

            TZTimer?.Dispose();
            TZTimer = new System.Threading.Timer(_ =>
            {
                _ = Task.Run(async () =>
                {
                    AsyncLogger.Info(
                        $"TimerFired | serverNow={DateTime.Now:O} utcNow={DateTime.UtcNow:O}");

                    try
                    {
                        await CheckAndClear();
                    }
                    catch (Exception ex)
                    {
                        AsyncLogger.Error("TimerFired | CheckAndClear failed", ex);
                    }
                });
            }, null, dueTime, Timeout.InfiniteTimeSpan);
        }







        private async Task CheckAndClear()
        {
            AsyncLogger.Info($"CheckAndClear START | utcNow={DateTime.UtcNow:O} unionsCount={UnionList.Values.Count}");

            var tasks = new List<Task>();

            foreach (var union in UnionList.Values)
            {
                tasks.Add(Task.Run(() =>
                {
                    try
                    {
                        // Decision log (why yes/no)
                        if (!TryParseOffset(union.TimeZone, out var offset))
                        {
                            AsyncLogger.Error(
                                $"UnionDecision | union={union.UnionId} INVALID_OFFSET offsetStr={union.TimeZone}", null);
                            return;
                        }

                        var nowUtc = DateTimeOffset.UtcNow;
                        var nowLocal = nowUtc.ToOffset(offset);

                        var targetLocal = new DateTimeOffset(
                            nowLocal.Year, nowLocal.Month, nowLocal.Day,
                            union.ClearTime.Hours, union.ClearTime.Minutes, union.ClearTime.Seconds,
                            offset);

                        var windowEnd = targetLocal.AddMinutes(5);

                        _lastClearLocalDateByUnion.TryGetValue(union.UnionId.ToString(), out var lastClearDate);

                        var shouldClear = isUnionClearTime(union.UnionId.ToString(), union.TimeZone, union.ClearTime);

                        AsyncLogger.Info(
                            $"UnionDecision | union={union.UnionId} offset={union.TimeZone} utcNow={nowUtc:O} " +
                            $"nowLocal={nowLocal:O} clearTime={union.ClearTime} targetLocal={targetLocal:O} " +
                            $"windowEnd={windowEnd:O} lastClearLocalDate={lastClearDate} shouldClear={shouldClear}");

                        if (!shouldClear)
                            return;

                        AsyncLogger.Info($"UnionClear START | union={union.UnionId}");

                        union.midnightClear(_interactionsList);

                        AsyncLogger.Info($"UnionClear DONE | union={union.UnionId}");
                    }
                    catch (Exception ex)
                    {
                        AsyncLogger.Error($"UnionClear FAIL | union={union.UnionId}", ex);
                    }
                }));
            }

            await Task.WhenAll(tasks);

            AsyncLogger.Info("CheckAndClear END | scheduling next check");
            ScheduleNextCheck();
        }





        /*public DateTime getUnionClearTime(string offsetString, TimeSpan clearTime)
        {
            // Get the current date and time in UTC
            DateTime utcNow = DateTime.UtcNow;

            //TimeSpan offset = TimeSpan.Parse(offsetString.Replace("+", "").Replace("-", ""));
            //if (offsetString.StartsWith("-"))
            if (!TryParseOffset(offsetString, out var offset))
                throw new ArgumentException($"Invalid offset: {offsetString}");
            //{
            //    offset = offset.Negate();
            //}

            // Combine the UTC date with the clear time and apply the offset
            DateTime dateTimeInGivenTimezone = utcNow.Date.Add(clearTime).Subtract(offset);

            // Convert to local server time
            DateTime localServerTime = dateTimeInGivenTimezone.ToLocalTime();

            // Ensure the time is in the future
            while (localServerTime <= DateTime.Now)
            {
                localServerTime = localServerTime.AddDays(1);
            }

            //AsyncLogger.Info($"union = {union.UnionId}, timeZone = {union.TimeZone}, clearTime = {clearTime}, utcNow = {utcNow}, nextClearTime = {localServerTime}");

            return localServerTime;
        }*/

        public DateTime getUnionClearTime(string offsetString, TimeSpan clearTime)
        {
            if (!TryParseOffset(offsetString, out var offset))
                throw new ArgumentException($"Invalid offset: {offsetString}");

            var nowUtc = DateTimeOffset.UtcNow;
            var nowLocal = nowUtc.ToOffset(offset);

            var candidateLocal = new DateTimeOffset(
                nowLocal.Year, nowLocal.Month, nowLocal.Day,
                clearTime.Hours, clearTime.Minutes, clearTime.Seconds,
                offset);

            if (candidateLocal <= nowLocal)
                candidateLocal = candidateLocal.AddDays(1);

            return candidateLocal.UtcDateTime.ToLocalTime();
        }




        private DateTime GetNextClearTime()
        {
            DateTime nextClearTime = DateTime.MaxValue;
            string? nextUnionId = null;
            string? nextUnionOffset = null;
            TimeSpan nextUnionClearTime = default;

            foreach (var union in UnionList.Values)
            {
                try
                {
                    DateTime localServerTime = getUnionClearTime(union.TimeZone, union.ClearTime);

                    // (Optional) Log per-union only if it's a very near event (e.g. within 10 minutes)
                    // This avoids log spam while still giving you data when it matters.
                    var due = localServerTime - DateTime.Now;
                    if (due >= TimeSpan.Zero && due <= TimeSpan.FromMinutes(10))
                    {
                        AsyncLogger.Info(
                            $"NextClearCandidate | union={union.UnionId} offset={union.TimeZone} clearTime={union.ClearTime} " +
                            $"serverNow={DateTime.Now:O} utcNow={DateTime.UtcNow:O} candidateServerTime={localServerTime:O} dueSec={due.TotalSeconds:F0}");
                    }

                    if (localServerTime < nextClearTime)
                    {
                        nextClearTime = localServerTime;
                        nextUnionId = union.UnionId.ToString();
                        nextUnionOffset = union.TimeZone;
                        nextUnionClearTime = union.ClearTime;
                    }
                }
                catch (Exception ex)
                {
                    AsyncLogger.Error(
                        $"GetNextClearTime | union={union.UnionId} offset={union.TimeZone} clearTime={union.ClearTime} failed",
                        ex);
                }
            }

            AsyncLogger.Info(
                $"GetNextClearTime RESULT | serverNow={DateTime.Now:O} utcNow={DateTime.UtcNow:O} " +
                $"nextClearTime={nextClearTime:O} nextUnion={nextUnionId} offset={nextUnionOffset} clearTime={nextUnionClearTime}");

            return nextClearTime;
        }






        private static bool TryParseOffset(string offsetString, out TimeSpan offset)
        {
            offset = default;

            if (string.IsNullOrWhiteSpace(offsetString))
                return false;

            var s = offsetString.Trim();
            var negative = s.StartsWith("-");
            s = s.TrimStart('+', '-');

            if (!TimeSpan.TryParseExact(s, @"hh\:mm", null, out offset))
                return false;

            if (negative) offset = offset.Negate();
            return true;
        }


        public bool isUnionClearTime(string unionId, string offsetString, TimeSpan clearTime)
        {
            //if (!TimeSpan.TryParse(offsetString, out var offset))
            //{
            //    AsyncLogger.Error($"Invalid offset: {offsetString}", null);
            //    return false;
            //}

            if (!TryParseOffset(offsetString, out var offset))
            {
                AsyncLogger.Error($"Invalid offset: {offsetString}");
                return false;
            }


            var nowLocal = DateTimeOffset.UtcNow.ToOffset(offset);
            var todayLocal = DateOnly.FromDateTime(nowLocal.DateTime);

            // prevent double-clear same local day
            if (_lastClearLocalDateByUnion.TryGetValue(unionId, out var last) && last == todayLocal)
                return false;

            var targetLocal = new DateTimeOffset(
                nowLocal.Year, nowLocal.Month, nowLocal.Day,
                clearTime.Hours, clearTime.Minutes, clearTime.Seconds,
                offset);

            // minimal delay window (set to 5 if you want tighter)
            var windowEnd = targetLocal.AddMinutes(5);

            if (nowLocal >= targetLocal && nowLocal <= windowEnd)
            {
                _lastClearLocalDateByUnion[unionId] = todayLocal;
                return true;
            }

            return false;
        }



        public bool isUnionClearTime2(string timeZone, TimeSpan clearTime)
        {
            try
            {
                DateTime unionClearTiime = getUnionClearTime(timeZone, clearTime);


                TimeSpan time1 = unionClearTiime.TimeOfDay;
                TimeSpan time2 = DateTime.Now.TimeOfDay;

                // Calculate the difference
                TimeSpan difference = time2 - time1;

                // Check if the absolute difference is less than 5 minutes
                if (Math.Abs(difference.TotalMinutes) < 5)
                {
                    return true;
                }
            }
            catch (Exception ex)
            {
                throw new ArgumentException("Invalid time zone format.");
            }
            return false;
        }








        public RTUsersResult getUsers(int unionId, bool isComplete)
        {
            var userResult = new RTUsersResult();

            AsyncLogger.Info($"<<getUsers unionId={unionId} isComplete={isComplete}");

            //AsyncLogger.Info("getUsers unionId=" + unionId);

            try
            {
                Union union = UnionList[unionId];

               
                //if (union.RemoveUser)
                //{                   
                    //isComplete = true;
                //    union.RemoveUser = false;
                //}

                if (!union.InUse)
                {
                    AsyncLogger.Info($"<<!union.InUse unionId={unionId}");
                    return null;
                }

                if (isComplete)
                {
                    AsyncLogger.Info($"isComplete=TRUE");
                    userResult.Data = union.getUnionUserData();
                }
                else
                {
                    AsyncLogger.Info($"isComplete=FALSE");
                    userResult.Data = union.ChangedUnionUsersData;                
                }

                userResult.Count = userResult.Data.Count;

                string users = Newtonsoft.Json.JsonConvert.SerializeObject(userResult.Data);
                AsyncLogger.Info($"<<ChangedUnionUsersData count={userResult.Count} users={users}");
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("refreshCells", ex);
            }

            return userResult;
        }







        public void refreshCells(int gridId)
        {
            ConcurrentDictionary<int, CellData> cells = new ConcurrentDictionary<int, CellData>();

            try
            {
                foreach (var cellValue in _allCellsData.Get(gridId))
                {
                    int cellId = cellValue.Key;
                    string value = cellValue.Value.Value;
                    CellData cell = new CellData(cellId, new GridData(gridId));


                    // ================================================

                    if (!string.IsNullOrWhiteSpace(value) && (value[0] == '+'))
                    {
                        try
                        {
                            char firstChr = value[0];
                            value = value.Substring(1);
                            DateTime signonTimeDT = DateTime.ParseExact(value, "dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
                            TimeSpan signonTimeTS = DateTime.Now.Subtract(signonTimeDT);
                            value = firstChr + signonTimeTS.ToString(@"hh\:mm\:ss");
                        }
                        catch
                        {
                            value = "&nbsp;";
                        }
                    }

                    // ================================================


                    cell.Value = value;
                    cells.TryAdd(cellId, cell);
                }

                if (GridEvent != null)
                {
                    GridEvent(this, new GridEventArgs(gridId, null) { CellsValuesData = cells.Values });
                }

            }
            catch (Exception ex)
            {
                AsyncLogger.Error("refreshCells", ex);
            }
        }



        public void getUserData(string userId)
        {
            try
            {
                var userMng = getUserManager(userId);

                if (UserViewEvent != null)
                {
                    UserViewEvent(this, new UserViewEventArgs(userId, userMng.UserData));
                }


                /*UserData userData = new UserData();
                var origUserData = UserGrids.getUserData(userId);

                userData.UserId = userId;

                foreach (var u in origUserData.Data)
                {
                    string val = fixUserData(u.Value);
                    userData.Data.TryAdd(u.Key, val);
                }

                if (UserViewEvent != null)
                {
                    UserViewEvent(this, new UserViewEventArgs(userId, userData.Data));
                }*/
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("getUserData userId=" + userId, ex);
            }
        }






        public void Dispose()
        {
            AsyncLogger.Info("Engine.Dispose");
        }




        public List<string> getUsersIds()
        {
            return _userManagerList.Keys.ToList();
        }



        // getUserManager
        public UserManager getUserManager(string userId)
        {
            UserManager user = null;

            try
            {
                user = _userManagerList.Add(userId, new UserManager(userId, UnionList, _dbMng, UserViewMetrics));
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("getUserManager userId=" + userId, ex);
            }

            return user;
        }




        // setUsersStatusList
        public bool setUsersStatusList(List<Agent> usersStatusList)
        {
            AsyncLogger.Info("setUsersStatusList count=" + usersStatusList.Count);
            foreach (var user in usersStatusList)
            {
                userStatusChanged(user.UserId, user.LoggedIn, user.StatusId, user.StatusName, user.StatusGroup, user.StatusChanged, user.Station, user.OnPhone,
                user.OnPhoneChanged, DateTime.Now, 1);
            }
            AsyncLogger.Info("END setUsersStatusList");
            return true;
        }




        // userStatusChanged
        public bool userStatusChanged(string userId, bool loggedIn, string statusId, string statusName, string statusGroup, DateTime StatusChanged, string station, bool onPhone,
            DateTime onPhoneChanged, DateTime timeStamp, long messageId)
        {
            //AsyncLogger.Info("Engine.userStatusChanged userId=" + userId);

            UserManager user = getUserManager(userId);
            user.setStatus(loggedIn, statusId, statusName, statusGroup, StatusChanged, station, onPhone, onPhoneChanged, messageId, false);

            AsyncLogger.Info("userStatusChanged: userId=" + userId + " loggedIn=" + loggedIn + " statusId=" + statusId + " statusName=" + statusName + " statusGroup=" + statusGroup +
               " StatusChanged=" + StatusChanged.ToString("dd/MM/yyyy HH:mm:ss") + " station= " + station + " onPhone=" + onPhone + " onPhoneChanged=" + onPhoneChanged.ToString("dd/MM/yyyy HH:mm:ss") +
                " timeStamp=" + timeStamp.ToString("dd/MM/yyyy HH:mm:ss") + " messageId=" + messageId);

            return true;
        }



        public ConcurrentDictionary<string, bool> Agentgroups { get; set; } = new ConcurrentDictionary<string, bool>();
            

        // userWorkgroupActivation
        public bool userWorkgroupActivation(string workgroup, List<string> activeUsersList, List<string> deactiveUsersList, DateTime timeStamp, long messageId)
        {
            try
            {
                //var wgMng = getOrAddWGManager(workgroup, _userManagerList, CallsList, _lastDisconnectedQ, _applicList, _interactionsList, _dbMng, "userWorkgroupActivation");
                Agentgroups.TryAdd(workgroup, true);

                UserManager userManager = null;

                foreach (string userId in activeUsersList)
                {
                    userManager = getUserManager(userId);
                    userManager.workgroupActivation(workgroup, true);
                }
                foreach (string userId in deactiveUsersList)
                {
                    userManager = getUserManager(userId);
                    userManager.workgroupActivation(workgroup, false);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("userWorkgroupActivation", ex);
            }

            return true;
        }



        // userConfigurationChanged
        public bool userConfigurationChanged(string userId, string displayName, string extension, string firstName, string lastName,
            IDictionary<string, string> customAttributes, DateTime timeStamp, long messageId)
        {
            UserManager user = getUserManager(userId);
            user.DisplayName = displayName;

            user.Extension = extension;
            user.FirstName = firstName;
            user.LastName = lastName;
            user.CustomAttributes = customAttributes;

            //string customAttributesStr = string.Empty;
            //foreach (var ca in customAttributes)
            //{
            //    customAttributesStr += " " + ca.Key + "=" + ca.Value;
            //}
            //AsyncLogger.Info("userConfigurationChanged: userId=" + userId + " displayName=" + displayName + " extension=" + extension + " firstName=" + firstName + " LastName=" + LastName + customAttributesStr +
            //    " timeStamp=" + timeStamp.ToString("dd/MM/yyyy HH:mm:ss") + " messageId=" + messageId);

            return true;
        }




        private ConcurrentDictionary<string, Call> MessageInteractions = new ConcurrentDictionary<string, Call>();


        private ConcurrentDictionary<string, ChatMessage> ActiveMessages = new ConcurrentDictionary<string, ChatMessage>();



        // userWorkgroupActivation
        public async Task interactionChanged(string workgroup, bool isAdded, string interactionId, int segmentId, bool isDisconnect, string callType, string interactionType, string direction, string state, DateTime stateChangedTime,
           TimeSpan duration, TimeSpan timeInWorkgroupQueue, bool isConsult, string consultCallId, string applic, string classificationCode, string localUserId, string origCallId,
           string customCallData, string calculatedStatus, string calculatedStatusTime, string c4uState, string localName, List<string> changedAttributeNames,
           bool isHeld, string remoteAddress, string lastMessageSid,
            string customCallData1, string customCallData2, string customCallData3, string customCallData4, string customCallData5, string customCallData6,
            string customCallData7, string customCallData8, string customCallData9, string customCallData10, string customCallData11, string customCallData12,
            string customCallData13, string customCallData14, string customCallData15, string customCallData16, string customCallData17, string customCallData18,
            string customCallData19, string customCallData20, DateTime timeStamp, long messageId)
        {
            //string interactionStr = "workgroup=" + workgroup +
                                    //" interactionId= " + interactionId +
                                    //" isDisconnect=" + isDisconnect +
                                    //" callType=" + callType +
                                    //" interactionType=" + interactionType +
                                    //" direction=" + direction +
                                    //" state=" + state +
                                    //" stateChangedTime=" + stateChangedTime +
                                    //" duration=" + duration +
                                    //" timeInWorkgroupQueue=" + timeInWorkgroupQueue +
                                    //" isConsult=" + isConsult +
                                    //" consultCallId=" + consultCallId +
                                    //" applic=" + applic +
                                    //" classificationCode=" + classificationCode +
                                    //" localUserId=" + localUserId +
                                    //" origCallId=" + origCallId +
                                    //" customCallData=" + customCallData +
                                    //" calculatedStatus=" + calculatedStatus +
                                    //" calculatedStatusTime=" + calculatedStatusTime +
                                    //" c4uState=" + c4uState +
                                    //" localName=" + localName +
                                    //" isHeld=" + isHeld +
                                    //" remoteAddress=" + remoteAddress +
                                    //" timeStamp=" + timeStamp +
                                    //" messageId=" + messageId;
            //InteractionsEvents.GetOrAdd(interactionId, new List<string>()).Add(interactionStr);

            var wgMng = getOrAddWGManager(workgroup, _userManagerList, CallsList, _lastDisconnectedQ, _applicList, _interactionsList, _dbMng, "interactionChanged");
            Call call = await wgMng.interactionAction(isAdded, interactionId, segmentId, isDisconnect, callType, interactionType, direction, state, stateChangedTime, duration, timeInWorkgroupQueue, isConsult, consultCallId, applic,
                classificationCode, localUserId, origCallId, customCallData, calculatedStatus, calculatedStatusTime, c4uState, localName, changedAttributeNames, isHeld, remoteAddress, lastMessageSid, customCallData1, customCallData2, 
                customCallData3, customCallData4, customCallData5, customCallData6, customCallData7, customCallData8, customCallData9, customCallData10, customCallData11, customCallData12,
                customCallData13, customCallData14, customCallData15, customCallData16, customCallData17, customCallData18, customCallData19, customCallData20, messageId);

            //if (!string.IsNullOrEmpty(lastMessageSid) && MessageInteractions.ContainsKey(lastMessageSid))
            //{
            //    MessageInteractions.TryRemove(lastMessageSid, out _);
            //}
            if (!string.IsNullOrEmpty(lastMessageSid))
            {
                MessageInteractions.TryAdd(lastMessageSid, call);

                if (ActiveMessages.ContainsKey(lastMessageSid))
                {
                    var msg = ActiveMessages[lastMessageSid];

                    call.IdInteraction.addChatMessage(msg);
                    //call.IdInteraction.ChatMessages.TryAdd(msg.MessageId, msg);

                    _dbMng.addChatMessageRequest(msg.EventType, msg.MessageId, msg.MsgDirection, msg.Sender, msg.Recipient, msg.Body, msg.DeliveryStatus, call.IdInteraction.InteractionId, call.IdInteraction.Segment, call.IdInteraction.UserId, timeStamp, timeStamp);
                }
            }
            

            //string changedAttributeNamesStr = string.Empty;
            //if (!isAdded)
            //{
            //    changedAttributeNamesStr = " changedAttributeNames=";
            //    foreach (var can in changedAttributeNames)
            //    {
            //        changedAttributeNamesStr += can + " ";
            //    }
            //}
            AsyncLogger.Info("interactionChanged: isAdded=" + isAdded + " interactionId=" + interactionId + " segmentId=" + segmentId + " callType=" + callType + " direction=" + direction +
                " state=" + state + " timeInWorkgroupQueue=" + timeInWorkgroupQueue + " isConsult=" + isConsult + " consultCallId=" + consultCallId + " applic=" + applic +
                " ClassificationCode=" + classificationCode + " localUserId=" + localUserId + " origCallId=" + origCallId + " customCallData=" + customCallData + " calculatedStatus=" +
                calculatedStatus + " calculatedStatusTime=" + calculatedStatusTime +
                " timeStamp=" + timeStamp.ToString("dd/MM/yyyy HH:mm:ss") + " messageId=" + messageId);
        }



        // interactionRemoved
        public async Task interactionRemoved(string workgroup, string interactionId, int segmentId, bool isDisconnect, string origCallId, string localUserId,
            string state, TimeSpan timeInWorkgroupQueue, bool isCallbackRequest, DateTime timeStamp, long messageId)
        {
            var wgMng = getOrAddWGManager(workgroup, _userManagerList, CallsList, _lastDisconnectedQ, _applicList, _interactionsList, _dbMng, "interactionRemoved");
            //Call call = await wgMng.interactionRemoved(interactionId, segmentId, isDisconnect, origCallId, localUserId, state, timeInWorkgroupQueue, isCallbackRequest, messageId);

            string lastMessageSid = await wgMng.interactionRemoved(interactionId, segmentId, isDisconnect, origCallId, localUserId, state, timeInWorkgroupQueue, isCallbackRequest, messageId);

            //string lastMessageSid = call.IdInteraction.LastMessageSid;
            if (!string.IsNullOrEmpty(lastMessageSid))
            {
                MessageInteractions.TryRemove(lastMessageSid, out _);
                ActiveMessages.TryRemove(lastMessageSid, out _);
            }

            AsyncLogger.Info("interactionRemoved:  interactionId=" + interactionId + " segmentId=" + segmentId + " origCallId=" + origCallId + " isCallbackRequest=" + isCallbackRequest +
                " timeStamp=" + timeStamp.ToString("dd/MM/yyyy HH:mm:ss") + " messageId=" + messageId);
        }





        // messageEventReceived
        public async Task messageEventReceived(string eventType, string MessageId, string direction, string sender, string recipient, string body, string deliveryStatus, DateTime timeStamp, long messageId)
        {
            Call call = null;
            string interactionId =string.Empty;
            int segment = 0;
            string workgroup = string.Empty;    
            string userId = string.Empty;

            string msgKey= string.Empty;

            if (deliveryStatus == "received")
            {
                msgKey = sender;
            }
            else
            {
                msgKey = recipient;
            }
            if (!string.IsNullOrEmpty(msgKey))
            {
                if (MessageInteractions.TryGetValue(msgKey, out call))
                {
                    interactionId = call.IdInteraction.InteractionId;
                    segment = call.IdInteraction.Segment;
                    workgroup = call.IdInteraction.Workgroup;
                    userId = call.IdInteraction.UserId;

                    ChatMessage chatMessage = null;
                    if (call.IdInteraction.ChatMessages.ContainsKey(MessageId))
                    {
                        chatMessage = call.IdInteraction.ChatMessages[MessageId];
                    }
                    else
                    {
                        chatMessage = new ChatMessage();
                        chatMessage.MessageId = MessageId;
                        call.IdInteraction.addChatMessage(chatMessage);
                        //call.IdInteraction.ChatMessages.TryAdd(MessageId, chatMessage);
                    }
                    
                    chatMessage.EventType = eventType;
                    chatMessage.MsgDirection = direction;
                    chatMessage.Sender = sender;
                    chatMessage.Recipient = recipient;
                    chatMessage.Body = body;
                    chatMessage.DeliveryStatus = deliveryStatus;
                    chatMessage.InteractionId = interactionId;
                    chatMessage.SegmentId = segment;
                    chatMessage.UserId = userId;
                    chatMessage.TimeStamp = call.IdInteraction.getLocalDateTime(); //timeStamp;
                }
            }
            else
            {
                ActiveMessages.TryAdd(MessageId, new ChatMessage()
                {
                    MessageId = MessageId,
                    EventType = eventType,
                    MsgDirection = direction,
                    Sender = sender,
                    Recipient = recipient,
                    Body = body,
                    DeliveryStatus = deliveryStatus,
                    InteractionId = interactionId,
                    SegmentId = segment,
                    UserId = userId,
                    TimeStamp = timeStamp
                });
            }

            AsyncLogger.Info($"messageEventReceived: eventType={eventType} MessageId={MessageId} direction={direction} sender={sender} recipient={recipient} body={body} deliveryStatus={deliveryStatus} interactionId={interactionId} segment={segment} workgroup={workgroup} timeStamp={timeStamp.ToString("dd/MM/yyyy HH:mm:ss")} messageId={messageId}");
            
            _dbMng.addChatMessageRequest(eventType, MessageId, direction, sender, recipient, body, deliveryStatus, interactionId, segment, userId, timeStamp, timeStamp);
        }




        // SetUsers
        public bool setUsers(List<string> users, DateTime timeStamp, long messageId)
        {
            try
            {
                AsyncLogger.Info("setUsers count=" + users.Count);

                foreach (string user in users)
                {
                    var userMng = getUserManager(user);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.getUsers", ex);
            }

            return true;
        }




        public bool isAgentWGPerfix(string wg)
        {
            if (string.IsNullOrEmpty(wg) || AgentWGPerfixList == null)
                return false;

            return AgentWGPerfixList.Any(substring => wg.StartsWith(substring));
        }





        private WorkgroupManager getOrAddWGManager(string id,
                UserManagerList userManagerList,
                CallsList callsList,
                ConcurrentQueue<string> lastDisconnectedQ,
                ApplicList applicList,
                IDInteractionsList interactionsList,
                DBMng dbMng, string origin)
        {
            WorkgroupManager workgroupManager = null;

            try
            {
                if (_workgroupManagerList.ContainsKey(id))
                {
                    workgroupManager = _workgroupManagerList[id];
                }
                else
                {
                    if (id != "_SystemIvrTransferHub_")
                    {
                        try
                        {
                            AsyncLogger.Info($"Add Workgroup id={id}");

                            workgroupManager = new WorkgroupManager(id, userManagerList, callsList, lastDisconnectedQ, interactionsList, dbMng);
                            _workgroupManagerList.TryAdd(id, workgroupManager);

                            var siteId = SitesTable.Keys.FirstOrDefault(key => id.StartsWith(key));

                            AsyncLogger.Info($"WG DEBUG raw siteId from FirstOrDefault = '{siteId ?? "NULL"}'");

                            if (siteId == null) 
                            {
                                siteId = "IL";
                            }

                            AsyncLogger.Info($"WG DEBUG Add Workgroup siteId={siteId}");


                            var containsKey = SitesTable.ContainsKey(siteId);
                            var tryResult = SitesTable.TryGetValue(siteId, out var debugSite);

                            AsyncLogger.Info($"WG DEBUG ContainsKey('{siteId}') = {containsKey}, TryGetValue('{siteId}') = {tryResult}");

                            // If a matching key is found, return the corresponding value; otherwise, return null or an appropriate message
                            if (siteId != null && SitesTable.TryGetValue(siteId, out var site))
                            {
                                int businessUnitId = BusinessUnitData.createBusinessUnit(id, id, siteId, "admin");
                                    if (businessUnitId > 0)
                                    {
                                        AsyncLogger.Info("Workgroup " + id + " create Queue BU");
                                        Union union = new Union(businessUnitId, _metrics)
                                        {
                                            TimeZone = site.TimeZone,
                                            ClearTime = site.ClearTime
                                        };
                                        UnionList.TryAdd(businessUnitId, union);

                                        if (BusinessUnitData.createBusinessUnitQueueClassificationMapping(businessUnitId, id, "ALL", "admin"))
                                        {
                                            union.Queues.Add(id);
                                            union.addWorkgroup(id, _applicList);
                                        }
                                    }
                                    else
                                    {
                                        AsyncLogger.Info("businessUnitId <= 0");
                                    }
                            }
                            else
                            {
                                AsyncLogger.Info("WG DEBUG SitesTable:");
                                foreach (var key in SitesTable.Keys)
                                {
                                    AsyncLogger.Info($"  key = '{key}' (len={key.Length})");
                                }
                                
                                // default tz
                            }
                        }
                        catch (Exception ex)
                        {
                            AsyncLogger.Error("Engine.setWorkgroups", ex);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.getOrAddWGManager wg=" + id, ex);
            }

            return workgroupManager;
        }




        // SetWorkgroups
        public bool setSkills(List<string> skills, DateTime timeStamp, long messageId)
        {
            try
            {
                AsyncLogger.Info("setSkils count=" + skills.Count);

                foreach (string skill in skills)
                {
                    Agentgroups.TryAdd(skill, true);

                    // Persist to NGC_AgentGroups
                    BusinessUnitData.getOrCreateAgentGroup(skill, skill);

                    // Get or create matching Supergroup
                    int supergroupId = BusinessUnitData.getOrCreateSupergroup(skill, skill);

                    // Create Supergroup <-> AgentGroup link
                    if (supergroupId > 0)
                    {
                        BusinessUnitData.createSupergroupAgentgroupMapping(supergroupId, skill, "system");
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.setSkils", ex);
            }
            return true;
        }



        // SetWorkgroups
        public bool setWorkgroups(List<string> workgroups, DateTime timeStamp, long messageId)
        {
            try
            {
                AsyncLogger.Info("SetWorkgroups count=" + workgroups.Count);

                foreach (string workgroup in workgroups)
                {
                    var workgroupManager = getOrAddWGManager(workgroup, _userManagerList, CallsList, _lastDisconnectedQ, _applicList, _interactionsList, _dbMng, "setWorkgroups");
                }
                //AllWorkgroups = _workgroupManagerList.Keys.ToList();
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.setWorkgroups", ex);
            }
            return true;
        }




        public List<string> GetAllWorkgroups()
        {
            return _workgroupManagerList.Keys.ToList();
        }



        public List<string> GetAllAgentgroups()
        {
            return Agentgroups.Keys.ToList();
        }



        public void setWorkgroup(string workgroup)
        {
            var workgroupManager = getOrAddWGManager(workgroup, _userManagerList, CallsList, _lastDisconnectedQ, _applicList, _interactionsList, _dbMng, "setWorkgroups");
        }



        public List<Statistic> getStatistics()
        {
            return _statistics.Values.ToList();
        }


        public bool setStatistic(string statisticKey, string value, long messageId)
        {
            //AsyncLogger.Info("RTM Statistic ID = " + statisticKey + "Value=" + value);

            List<Cell> cells = null;
            if (_statisticsCells.TryGetValue(statisticKey, out cells))
            {
                foreach (var cell in cells)
                {
                    cell.Value = value;
                }
            }

            return true;
        }




        public void AddGridConnection(string connectionId, string gridId)
        {
            try
            {
                if (gridId[0] == 'u')
                {
                    int unionId = Convert.ToInt32(gridId.Substring(1));
                    Union union = UnionList[unionId];
                    union.Connections.TryAdd(connectionId, 0);
                    union.InUse = true;
                    AsyncLogger.Info("Union " + unionId + " In use");

                    //var grid = AgentGrids[Convert.ToInt32(gridId.Substring(1))];
                    //grid.Connections.TryAdd(connectionId, 0);
                    //grid.InUse = true;
                    //AsyncLogger.Info("Agent Grid " + grid.GridId + " In use");
                }
                else if (gridId[0] == 'a')
                {
                    var userMng = getUserManager(gridId.Substring(1));
                    userMng.Connections.TryAdd(connectionId, 0);
                    userMng.InUse = true;
                    AsyncLogger.Info("User " + userMng.userId + " In use");
                }
                else
                {
                    var grid = _gridList[Convert.ToInt32(gridId)];
                    grid.Connections.TryAdd(connectionId, 0);
                    grid.InUse = true;
                    AsyncLogger.Info("Data Grid " + grid.GridId + " In use");
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.AddGridConnection gridId=" + gridId, ex);
            }
        }




        public void RemoveGridsConnection(string connectionId)
        {
            try
            {
                foreach (var grid in _gridList.Values)
                {
                    if (grid.InUse)
                    {
                        int i;
                        if (grid.Connections.TryRemove(connectionId, out i))
                        {
                            if (grid.Connections.Count == 0)
                            {
                                grid.InUse = false;
                                AsyncLogger.Info("Grid " + grid.GridId + " NOT in use");
                            }
                            else
                            {
                                grid.InUse = true;
                                AsyncLogger.Info("Grid " + grid.GridId + " In use");
                            }
                        }
                    }
                }
                foreach (var union in UnionList.Values)
                {
                    if (union.InUse)
                    {
                        int i;
                        if (union.Connections.TryRemove(connectionId, out i))
                        {
                            if (union.Connections.Count == 0)
                            {
                                union.InUse = false;
                                AsyncLogger.Info("Union " + union.UnionId + " NOT in use");
                            }
                            else
                            {
                                union.InUse = true;
                                AsyncLogger.Info("Union " + union.UnionId + " In use");
                            }
                        }
                    }
                }
                foreach (var userMng in _userManagerList.Values)
                {
                    if (userMng.InUse)
                    {
                        int i;
                        if (userMng.Connections.TryRemove(connectionId, out i))
                        {
                            if (userMng.Connections.Count == 0)
                            {
                                userMng.InUse = false;
                                AsyncLogger.Info("User " + userMng.userId + " NOT In use");
                            }
                            else
                            {
                                userMng.InUse = true;
                                AsyncLogger.Info("User " + userMng.userId + " In use");
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.RemoveGridsConnection", ex);
            }
        }





        private Cell removeCell(int cellId)
        {
            Cell cell = null;
            AsyncLogger.Info("Engine.removeCell cellId=" + cellId);

            try
            {
                if (_cellList.ContainsKey(cellId))
                {
                    _cellList.TryRemove(cellId, out cell);

                    bool tryRemove = cell.Grid.Cells.TryRemove(cellId, out cell);
                    _allCellsData.removeCell(cellId);

                    foreach (var union in UnionList.Values)
                    {
                        foreach (var unionMetric in union.Metrics.Values)
                        {
                            if (unionMetric.Cells.ContainsKey(cellId))
                            {
                                tryRemove = unionMetric.Cells.TryRemove(cellId, out cell);
                                AsyncLogger.Info("Engine.removeCell cellId=" + cellId + " union=" + union.UnionId + " tryRemove=" + tryRemove);
                            }
                        }
                    }

                    //foreach (var statistic in _statistics.Values)
                    //{
                    //    var listCell = _statisticsCells[Statistic.getJsonString(statistic)];
                    //    if (listCell.Contains(cell))
                    //   {
                    //       listCell.Remove(cell);
                    //    }
                    //}*/
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.removeCell", ex);
            }

            return cell;
        }



        public bool UpdateCell(int cellId, int gridId, string metric, int statisticId, int unionId)
        {
            bool retCode = false;

            AsyncLogger.Info("Engine.UpdateCell cellId=" + cellId + " gridId=" + gridId + " metric=" + metric + " statisticId=" + statisticId + " unionId=" + unionId);

            try
            {
                Cell cell = null;

                if (!string.IsNullOrWhiteSpace(metric))
                {
                    removeCell(cellId);

                    if (_gridList.ContainsKey(gridId))
                    {
                        var grid = _gridList[gridId];
                        cell = new Cell(cellId, grid, unionId, metric);
                        cell.Grid.Cells.TryAdd(cellId, cell);
                        _allCellsData.addCell(cellId, gridId);
                        cell.IsChanged = true;
                    }

                    if (cell != null)
                    {
                        _cellList.TryAdd(cellId, cell);
                        Union union = UnionList[unionId];

                        Metric unionMetric = union.Metrics.GetOrAdd(metric, new Metric(union));
                        unionMetric.Cells.TryAdd(cellId, cell);
                       
                        union.addDataMetric(_metrics[metric]);

                        unionMetric.setCellValue(cell);

                        //union.metricFunction(_metrics[metric], true);
                    }
                }
                else if (statisticId > 0)
                {
                    cell = removeCell(cellId);

                    if (cell == null)
                    {
                        if (_gridList.ContainsKey(gridId))
                        {
                            var grid = _gridList[gridId];
                            cell = new Cell(cellId, grid, unionId, metric);
                        }
                    }

                    if (cell != null)
                    {
                        Statistic statistic = null;

                        if (_statistics.TryGetValue(statisticId, out statistic))
                        {
                            var listCell = _statisticsCells.GetOrAdd(Statistic.getJsonString(statistic), new List<Cell>());
                            listCell.Add(cell);
                        }
                    }
                }
                else
                {
                    removeCell(cellId);
                }

                retCode = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.UpdateCell", ex);
            }

            AsyncLogger.Info("Engine.UpdateCell End cellId=" + cellId);

            return retCode;
        }




        public List<IDInteraction> GetCellData (int cellId)
        {
            var Interactions = new List<IDInteraction>();

            AsyncLogger.Info("Engine.GetCellData cellId=" + cellId);

            try
            {
                Cell cell;

                if (_cellList.TryGetValue(cellId, out cell))
                {
                    var unionId = cell.UnionId;
                    Union union;

                    if (UnionList.TryGetValue(unionId, out union))
                    {
                        MetricDef metric;
                        if (_metrics.TryGetValue(cell.Metric, out metric))
                        {
                            Interactions = union.getInteractions(metric);                        
                        }
                        else
                        {
                            AsyncLogger.Error($"Engine.GetCellData Metric={cell.Metric} NOT exist");
                        }
                    }
                    else
                    {
                        AsyncLogger.Error($"Engine.GetCellData union={unionId   } NOT exist");
                    }

                }
                else
                {
                    AsyncLogger.Error($"Engine.GetCellData Cell={cellId} NOT exist");
                }
            }
            catch(Exception ex)
            {
                AsyncLogger.Error($"Engine.GetCellData Cell={cellId}", ex);
            }

            AsyncLogger.Info("Engine.GetCellData Interactions.Count = " + Interactions.Count);

            return Interactions;
        }





        private ConcurrentDictionary<string, string> MetricFunctionList { get; set; } = new ConcurrentDictionary<string, string>();


        private ConcurrentDictionary<string, string> MetricUserFunctionList { get; set; } = new ConcurrentDictionary<string, string>();



        private static string ExtractDirectionCondition(string input)
        {
            // מחפש Direction == "something"
            var match = Regex.Match(input, @"Direction\s*==\s*""[^""]+""");
            return match.Success ? match.Value.Trim() : null;
        }


        private bool IsMessageMetricFunction(string functionName)
        {
            return !string.IsNullOrWhiteSpace(functionName)
                && functionName.StartsWith("Messages", StringComparison.OrdinalIgnoreCase);
        }


        private void setUserMetricFunctions1(MetricDef metric)
        {
            string rawParam = metric.Parameter ?? "";
            string directionExpr = ExtractDirectionCondition(rawParam);
            string directionExprForFunction = !string.IsNullOrEmpty(directionExpr)
                ? Regex.Replace(directionExpr, @"\bDirection\b", "m.Direction")
                : "true";

            if (MetricUserFunctionList.ContainsKey(metric.Function))
            {
                string metricFunction = MetricUserFunctionList[metric.Function];
                string metricParam = TransformQuery(metric.Parameter);
                string functionBody = metricFunction.Replace("METRIC_PARAMETER", metricParam).Replace("METRIC_DIRECTION", directionExprForFunction);
                functionBody = functionBody.Replace("METRIC_FORMAT", metric.Format);

                CompileAndSetUserMetricFunction(metric, functionBody);
            }
        }



        private void setUserMetricFunctions(MetricDef metric)
        {
            string rawParam = metric.Parameter ?? "";
            bool isMessageMetric = IsMessageMetricFunction(metric.Function);

            string directionExprForFunction = "true";
            string paramForTransform = rawParam;

            // In user metric functions, handle Direction specially for message metrics
            if (isMessageMetric)
            {
                string directionExpr = ExtractDirectionCondition(rawParam);

                if (!string.IsNullOrEmpty(directionExpr))
                {
                    directionExprForFunction = Regex.Replace(directionExpr, @"\bDirection\b", "m.Direction");
                    paramForTransform = Regex.Replace(rawParam, Regex.Escape(directionExpr), "true");
                }
            }

            if (MetricUserFunctionList.ContainsKey(metric.Function))
            {
                string metricFunction = MetricUserFunctionList[metric.Function];
                string metricParam = TransformQuery(paramForTransform);

                string functionBody = metricFunction
                    .Replace("METRIC_PARAMETER", metricParam)
                    .Replace("METRIC_DIRECTION", directionExprForFunction)
                    .Replace("METRIC_FORMAT", metric.Format ?? "");

                CompileAndSetUserMetricFunction(metric, functionBody);
            }
        }





        private void setMetricFunctions(MetricDef metric)
        {
            if (!MetricFunctionList.TryGetValue(metric.Function, out string metricFunctionTemplate))
                return;

            string rawParam = metric.Parameter ?? "";
            bool isMessageMetric = IsMessageMetricFunction(metric.Function);

            string directionExprForFunction = "true";
            string paramForTransform = rawParam;

            // Only extract Direction for interaction-based metrics
            if (isMessageMetric)
            {
                string directionExpr = ExtractDirectionCondition(rawParam);

                if (!string.IsNullOrEmpty(directionExpr))
                {
                    directionExprForFunction = Regex.Replace(directionExpr, @"\bDirection\b", "m.Direction");
                    paramForTransform = Regex.Replace(rawParam, Regex.Escape(directionExpr), "true");
                }
            }

            string transformedParam = TransformQuery(paramForTransform);

            string functionBody = metricFunctionTemplate
                .Replace("METRIC_DIRECTION", directionExprForFunction)
                .Replace("METRIC_PARAMETER", transformedParam)
                .Replace("METRIC_FORMAT", metric.Format ?? "");

            CompileAndSetMetricFunction(metric, functionBody);
            CompileAndSetMetricInteractionsFunction(metric);
        }



        public static string TransformQuery(string queryString)
        {
            try
            {
                // Use reflection to get property names from the IDInteraction class
                //var propertyNames = typeof(IDInteraction).GetProperties(BindingFlags.Public | BindingFlags.Instance)
                //    .Select(p => p.Name)
                //    .ToList();

                var interactionProps = typeof(IDInteraction).GetProperties(BindingFlags.Public | BindingFlags.Instance);
                var messageProps = typeof(ChatMessage).GetProperties(BindingFlags.Public | BindingFlags.Instance);

                var propertyNames = interactionProps
                    .Concat(messageProps)
                    .Select(p => p.Name)
                    .Distinct()
                    .OrderByDescending(n => n.Length) // חשוב! למניעת החלפה שגויה (User vs UserId)
                    .ToList();


                // Use Regex to replace each property name in the query with "i.PropertyName"
                foreach (var propName in propertyNames)
                {
                    string pattern = $@"\b{propName}\b"; // \b is a word boundary in regex, to match whole words only
                    string replacement = $"i.{propName}";
                    queryString = Regex.Replace(queryString, pattern, replacement);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union.TransformQuery", ex);
            }

            return queryString;
        }






        public void CompileAndSetUserMetricFunction(MetricDef metricDef, string functionBody)
        {
            string codeToCompile = string.Empty;
            try
            {
                // Construct the full source code
                codeToCompile = $@"
                    using System;
                    using System.Collections.Concurrent;
                    using System.Collections.Generic;
                    using System.Linq;  
                    using RTM;

                    public class Metric{metricDef.ID}Container
                    {{
                        public static string MetricFunction(ConcurrentBag<IDInteraction> Bag, string userId)
                        {{
                            {functionBody}
                        }}
                    }}";


                // Parse the source code into a syntax tree
                var syntaxTree = CSharpSyntaxTree.ParseText(codeToCompile);

                // .NET 8: Use TRUSTED_PLATFORM_ASSEMBLIES for all runtime references
                var trustedAssemblies = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!)
                    .Split(Path.PathSeparator)
                    .Where(p => File.Exists(p))
                    .Select(p => MetadataReference.CreateFromFile(p))
                    .Cast<MetadataReference>()
                    .ToList();
                // Add RTM assembly (for IDInteraction, etc.)
                trustedAssemblies.Add(MetadataReference.CreateFromFile(typeof(IDInteraction).Assembly.Location));

                // Compile the syntax tree into an assembly
                var compilation = CSharpCompilation.Create($"Metric{metricDef.ID}Assembly",
                    options: new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary),
                    syntaxTrees: new[] { syntaxTree },
                    references: trustedAssemblies);

                using (var ms = new MemoryStream())
                {
                    EmitResult result = compilation.Emit(ms);

                    if (!result.Success)
                    {
                        // Handle compilation errors (e.g., log them or throw an exception)
                        foreach (var diagnostic in result.Diagnostics)
                        {
                            AsyncLogger.Error(diagnostic.ToString());
                        }
                        throw new InvalidOperationException("Compilation failed.");
                    }

                    ms.Seek(0, SeekOrigin.Begin);
                    Assembly assembly = Assembly.Load(ms.ToArray());

                    // Get the compiled method
                    var type = assembly.GetType($"Metric{metricDef.ID}Container");
                    var method = type.GetMethod("MetricFunction");

                    // Create a delegate pointing to the compiled method
                    metricDef.MetricUserFunction = (Func<ConcurrentBag<IDInteraction>, string, string>)
                        method.CreateDelegate(typeof(Func<ConcurrentBag<IDInteraction>, string, string>));
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.CompileAndSetUserMetricFunction " + codeToCompile, ex);
            }
        }






        public void CompileAndSetMetricFunction(MetricDef metricDef, string functionBody)
        {
            string codeToCompile = string.Empty;
            try
            {
                // Construct the full source code
                codeToCompile = $@"
                    using System;
                    using System.Collections.Concurrent;
                    using System.Collections.Generic;
                    using System.Linq;  
                    using RTM;

                    public class Metric{metricDef.ID}Container
                    {{
                        public static string MetricFunction(ConcurrentBag<IDInteraction> Bag, bool applicAny)
                        {{
                            {functionBody}
                        }}
                    }}";


                // Parse the source code into a syntax tree
                var syntaxTree = CSharpSyntaxTree.ParseText(codeToCompile);

                // .NET 8: Use TRUSTED_PLATFORM_ASSEMBLIES for all runtime references
                var trustedAssemblies = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!)
                    .Split(Path.PathSeparator)
                    .Where(p => File.Exists(p))
                    .Select(p => MetadataReference.CreateFromFile(p))
                    .Cast<MetadataReference>()
                    .ToList();
                // Add RTM assembly (for IDInteraction, etc.)
                trustedAssemblies.Add(MetadataReference.CreateFromFile(typeof(IDInteraction).Assembly.Location));

                // Compile the syntax tree into an assembly
                var compilation = CSharpCompilation.Create($"Metric{metricDef.ID}Assembly",
                    options: new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary),
                    syntaxTrees: new[] { syntaxTree },
                    references: trustedAssemblies);

                using (var ms = new MemoryStream())
                {
                    EmitResult result = compilation.Emit(ms);

                    if (!result.Success)
                    {
                        // Handle compilation errors (e.g., log them or throw an exception)
                        foreach (var diagnostic in result.Diagnostics)
                        {
                            AsyncLogger.Error(diagnostic.ToString());
                        }
                        throw new InvalidOperationException("Compilation failed.");
                    }

                    ms.Seek(0, SeekOrigin.Begin);
                    Assembly assembly = Assembly.Load(ms.ToArray());

                    // Get the compiled method
                    var type = assembly.GetType($"Metric{metricDef.ID}Container");
                    var method = type.GetMethod("MetricFunction");

                    // Create a delegate pointing to the compiled method
                    metricDef.MetricFunction = (Func<ConcurrentBag<IDInteraction>, bool, string>)
                        method.CreateDelegate(typeof(Func<ConcurrentBag<IDInteraction>, bool, string>));
                }

                AsyncLogger.Info("Engine.CompileAndSetMetricFunction " + codeToCompile);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.CompileAndSetMetricFunction " + codeToCompile, ex);
            }
        }





        public void CompileAndSetMetricInteractionsFunction(MetricDef metricDef)
        {
            string codeToCompile = string.Empty;
            try
            {
                string metricParam = TransformQuery(metricDef.Parameter);
                string functionBody = $"var interactions = Bag.Where(i => {metricParam}).ToList(); return interactions;";
               

                // Construct the full source code
                codeToCompile = $@"
                    using System;
                    using System.Collections.Concurrent;
                    using System.Collections.Generic;
                    using System.Collections;
                    using System.Linq;  
                    using RTM;

                    public class Metric{metricDef.ID}InteractionsContainer
                    {{
                        public static List<IDInteraction> MetricFunction(ConcurrentBag<IDInteraction> Bag)
                        {{
                            {functionBody}
                        }}
                    }}";


                // Parse the source code into a syntax tree
                var syntaxTree = CSharpSyntaxTree.ParseText(codeToCompile);

                // .NET 8: Use TRUSTED_PLATFORM_ASSEMBLIES for all runtime references
                var trustedAssemblies = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")!)
                    .Split(Path.PathSeparator)
                    .Where(p => File.Exists(p))
                    .Select(p => MetadataReference.CreateFromFile(p))
                    .Cast<MetadataReference>()
                    .ToList();
                // Add RTM assembly (for IDInteraction, etc.)
                trustedAssemblies.Add(MetadataReference.CreateFromFile(typeof(IDInteraction).Assembly.Location));

                // Compile the syntax tree into an assembly
                var compilation = CSharpCompilation.Create($"Metric{metricDef.ID}Assembly",
                    options: new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary),
                    syntaxTrees: new[] { syntaxTree },
                    references: trustedAssemblies);

                using (var ms = new MemoryStream())
                {
                    EmitResult result = compilation.Emit(ms);

                    if (!result.Success)
                    {
                        // Handle compilation errors (e.g., log them or throw an exception)
                        foreach (var diagnostic in result.Diagnostics)
                        {
                            AsyncLogger.Error(diagnostic.ToString());
                        }
                        throw new InvalidOperationException("Compilation failed.");
                    }

                    ms.Seek(0, SeekOrigin.Begin);
                    Assembly assembly = Assembly.Load(ms.ToArray());

                    // Get the compiled method
                    var type = assembly.GetType($"Metric{metricDef.ID}InteractionsContainer");
                    var method = type.GetMethod("MetricFunction");

                    // Create a delegate pointing to the compiled method
                    metricDef.InteractionsListFunction = (Func<ConcurrentBag<IDInteraction>, List<IDInteraction>>)
                        method.CreateDelegate(typeof(Func<ConcurrentBag<IDInteraction>, List<IDInteraction>>));
                }
                AsyncLogger.Info("Engine.CompileAndSetMetricFunction " + codeToCompile);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Engine.CompileAndSetMetricFunction " + codeToCompile, ex);
            }
        }






        private void setUserMetricFunctions()
        {
            // interactionsCountFunction
            // =========================
            string interactionsCountFunction = @"
                int cnt = Bag.Where(i => i.UserId == userId && (METRIC_PARAMETER)).Count();          
                return cnt.ToString();";
            MetricUserFunctionList.TryAdd("InteractionsCount", interactionsCountFunction);


            // CPHFunction
            // =========================
            string CPHFunction = @"
                int cnt = Bag.Where(i => i.UserId == userId && (METRIC_PARAMETER)).Count();          
                return cnt.ToString();";
            MetricUserFunctionList.TryAdd("CPH", CPHFunction);


            // talkDurationAvgFunction
            // =======================
            string talkDurationAvgFunction = @"     
                string val =  ""00:00:00"";
                var ans = Bag.Where((i => i.UserId == userId && (METRIC_PARAMETER)));
                long cnt = ans.Count();
                if (cnt > 0)
                {
                    long sum = Convert.ToInt64(ans.Select(i => i.TalkTime).Sum());
                    int tdais = Convert.ToInt32(sum / cnt);
                    TimeSpan ts = new TimeSpan(0, 0, tdais);
                    val = ts.ToString(@""hh\:mm\:ss"");                
                }
                return val;";
            MetricUserFunctionList.TryAdd("TalkDurationAvg", talkDurationAvgFunction);


            // talkDurationMaxFunction
            // =======================
            string talkDurationMaxFunction = @"   
                string val =  ""00:00:00"";
                var ans = Bag.Where((i => i.UserId == userId && (METRIC_PARAMETER)));
                long cnt = ans.Count();
                if (cnt > 0)
                {                  
                    int max = Convert.ToInt32(ans.OrderBy(i => i.TalkTime).Select(i => i.TalkTime).Last());
                    TimeSpan ts = new TimeSpan(0, 0, max);
                    val = ts.ToString(@""hh\:mm\:ss"");                
                }
                return val;";
            MetricUserFunctionList.TryAdd("TalkDurationMax", talkDurationMaxFunction);



            // MessagesAvgFirstResponseTime
            // ============================
            string MessagesAvgFirstResponseTimeFunction = @"
                List<TimeSpan> responseTimes = new();

                foreach (var interaction in Bag.Where(m =>
                    m.UserId == userId &&
                    m.InteractionType == ""Chat"" &&
                    METRIC_DIRECTION &&
                    m.ChatMessages != null &&
                    m.AnsweredDateTime != null))
                {             
                    var firstOutbound = interaction.ChatMessages.Values
                        .OrderBy(msg => msg.TimeStamp)
                        .FirstOrDefault(msg => msg.MsgDirection == ""outbound"");

                    if (firstOutbound != null && firstOutbound.TimeStamp > interaction.AnsweredDateTime)
                    {                
                        var diff = firstOutbound.TimeStamp - interaction.AnsweredDateTime;                      
                        responseTimes.Add(diff);
                    }
                }

                if (!responseTimes.Any())
                return ""00:00:00"";

                var avgSeconds = responseTimes.Average(ts => ts.TotalSeconds);
                var avg = TimeSpan.FromSeconds(avgSeconds);

                return avg.ToString(@""hh\:mm\:ss"");";

            MetricUserFunctionList.TryAdd("MessagesAvgFirstResponseTime", MessagesAvgFirstResponseTimeFunction);



            // MessagesAvgResponseTime
            // ============================
            string MessagesAvgResponseTimeFunction = @"         
            List<TimeSpan> responseTimes = new();

            foreach (var interaction in Bag.Where(m =>
                m.UserId == userId &&
                m.InteractionType == ""Chat"" &&
                METRIC_DIRECTION &&
                m.ChatMessages != null))
            {
                var messages = interaction.ChatMessages.Values
                    .OrderBy(m => m.TimeStamp)
                    .ToList();

                int index = 0;

                while (index < messages.Count)
                {
                    var inbound = messages[index];

                    if (inbound.MsgDirection != ""inbound"")
                    {
                        index++;
                        continue;
                    }

                    // חפש את הודעת הנציג הראשונה שאחריה
                    var response = messages
                        .Skip(index + 1)
                        .FirstOrDefault(m => m.MsgDirection == ""outbound"");

                    if (response != null)
                    {
                        responseTimes.Add(response.TimeStamp - inbound.TimeStamp);

                        // המשך החיפוש מההודעה שאחרי התגובה
                        index = messages.IndexOf(response) + 1;
                    }
                    else
                    {
                        // אין תגובה לנקודה הזו - מתעלמים
                        break;
                    }
                }
            }

            if (responseTimes.Count == 0)
                return ""00:00:00"";

            var avgSeconds = responseTimes.Average(ts => ts.TotalSeconds);
            var avg = TimeSpan.FromSeconds(avgSeconds);

            return avg.ToString(@""hh\:mm\:ss"");";

            MetricUserFunctionList.TryAdd("MessagesAvgResponseTime", MessagesAvgResponseTimeFunction);


        }





        private void setMetricFunctions()
        {
            // numWaitingsFunction
            // ===================
            string numWaitingsFunction = @"
                int waiting = 0;
                if (applicAny)
                {
                    waiting = Bag.Where(i => i.IsInQueue && (METRIC_PARAMETER)).Count();
                }
                return waiting.ToString();";
            MetricFunctionList.TryAdd("NumWaitings", numWaitingsFunction);


            // waitDurationCurMaxFunction
            // ==========================
            string waitDurationCurMaxFunction = @"
                string retValue = string.Empty;
                string maxWaitTIme = ""00:00:00"";
                DateTime longestWait = DateTime.MinValue;

                if (applicAny)
                {
                    var filter1 = Bag.Where(i => i.IsInQueue && (METRIC_PARAMETER));

                    if (filter1.Any())
                    {
                        longestWait = filter1.OrderBy(i => i.InQueueLocalDateTime).Select(i => i.InQueueLocalDateTime).FirstOrDefault();

                        if (longestWait > DateTime.MinValue)
                        {
                            maxWaitTIme = ""+"" + longestWait.ToString(""dd/MM/yyyy HH:mm:ss"");
                        }
                    }
                }
                retValue = longestWait.ToString();               
                return (retValue + ""-"" + maxWaitTIme);";
            MetricFunctionList.TryAdd("WaitDurationCurMax", waitDurationCurMaxFunction);


            // answeredCountFunction
            // =====================
            string answeredCountFunction = @"
                int cnt = 0;
                if (applicAny)
                {
                    cnt = Bag.Where(i => i.IsAnswered && (METRIC_PARAMETER)).Count();
                }
                return cnt.ToString();";
            MetricFunctionList.TryAdd("AnsweredCount", answeredCountFunction);


            // abandonedCountFunction
            // ======================
            string abandonedCountFunction = @"
                int cnt = 0;
                if (applicAny)
                {
                    cnt = Bag.Where(i => i.IsAbandoned && (METRIC_PARAMETER)).Count(); 
                }
                return cnt.ToString();";
            MetricFunctionList.TryAdd("AbandonedCount", abandonedCountFunction);


            // answeredPercentFunction
            // =======================
            string answeredPercentFunction = @"
                double dCalc = 0;
                if (applicAny)
                {
                    int incomingCount = Bag.Where(i => METRIC_PARAMETER).Count();
                    if (incomingCount > 0)
                    {
                        int answeredCount = Bag.Where(i => i.IsAnswered && (METRIC_PARAMETER)).Count();
                        dCalc = (double)answeredCount / incomingCount;
                    }
                }
                return dCalc.ToString(METRIC_FORMAT); // ""#0.##%""";
            MetricFunctionList.TryAdd("AnsweredPercent", answeredPercentFunction);


            // abandonedPercentFunction
            // ========================
            string abandonedPercentFunction = @"
                double dCalc = 0;
                if (applicAny)
                {
                    var ans =  Bag.Where(i => METRIC_PARAMETER);
                    int incomingCount1 = Bag.Where(i => METRIC_PARAMETER).Count();
                    if (incomingCount1 > 0)
                    {
                        int abandonCount = Bag.Where(i => i.IsAbandoned && (METRIC_PARAMETER)).Count();
                        dCalc = (double)abandonCount / incomingCount1;
                    }
                }
                return dCalc.ToString(METRIC_FORMAT); // ""#0.##%""";
            MetricFunctionList.TryAdd("AbandonedPercent", abandonedPercentFunction);


            // interactionsCountFunction
            // =========================
            string interactionsCountFunction = @"
                int cnt = Bag.Where(i => METRIC_PARAMETER).Count();          
                return cnt.ToString();";
            MetricFunctionList.TryAdd("InteractionsCount", interactionsCountFunction);



            // CPHFunctionFunction
            // =========================
            string CPHFunction = @"
                int cnt = Bag.Where(i => METRIC_PARAMETER).Count();          
                return cnt.ToString();";
            MetricFunctionList.TryAdd("CPH", CPHFunction);



            // MessagesCountFunction
            // =========================
            string messagesCountFunction1 = @"
                int cnt = Bag.Where(m => m.InteractionType==""Chat"" && METRIC_DIRECTION && (m.ChatMessages?.Any() ?? false)).Sum(m => m.ChatMessages.Values.Count(i => METRIC_PARAMETER));      
                return cnt.ToString();";
           

            string messagesCountFunction = @"
                int cnt = Bag
                    .Where(m => m.InteractionType == ""Chat"" && METRIC_DIRECTION && (m.ChatMessages?.Any() ?? false))
                    .Sum(m => m.ChatMessages.Values.Count(i => METRIC_PARAMETER));      
                return cnt.ToString();";

            MetricFunctionList.TryAdd("MessagesCount", messagesCountFunction);


            // MessagesInteractionsCountFunction
            //==================================
            string messagesInteractionsCountFunction1 = @"
                int cnt = 0;
                if (applicAny)
                {
                    cnt = Bag
                        .Where(m => m.InteractionType == ""Chat"" && m.ChatMessages?.Any() == true)
                        .Count(i => i.ChatMessages.Values.Any(msg => METRIC_PARAMETER));
                }
                return cnt.ToString();";
            


            string messagesInteractionsCountFunction = @"
                int cnt = 0;
                if (applicAny)
                {
                    cnt = Bag
                        .Where(m => m.InteractionType == ""Chat"" 
                                 && METRIC_DIRECTION
                                 && m.ChatMessages?.Any() == true
                                 && m.ChatMessages.Values.Any(i => METRIC_PARAMETER))
                        .Count();
                }
                return cnt.ToString();";

            MetricFunctionList.TryAdd("MessagesInteractionsCount", messagesInteractionsCountFunction);


            // MessagesPercentFunction
            // ========================
            string MessagesPercentFunction1 = @"
                double dCalc = 0;
                if (applicAny)
                {
                    var ans =  Bag.Where(m => m.InteractionType==""Chat"" && m.ChatMessages?.Any());
                    int totalMessages = ans.Sum(m => m.ChatMessages.Count);
                    if (totalMessages > 0)
                    {
                        int selectedMessages = ans.Sum(i => i.ChatMessages.Values.Count(i => METRIC_PARAMETER));
                        dCalc = (double)selectedMessages / totalMessages;
                    }
                }
                return dCalc.ToString(METRIC_FORMAT); // ""#0.##%""";

            string MessagesPercentFunction = @"
                double dCalc = 0;
                if (applicAny)
                {
                    var ans = Bag
                        .Where(m => m.InteractionType == ""Chat""
                                 && METRIC_DIRECTION
                                 && m.ChatMessages?.Any() == true);

                    int totalMessages = ans.Sum(m => m.ChatMessages?.Count ?? 0);

                    if (totalMessages > 0)
                    {
                        int selectedMessages = ans.Sum(m => m.ChatMessages.Values.Count(i => METRIC_PARAMETER));
                        dCalc = (double)selectedMessages / totalMessages;
                    }
                }
                return dCalc.ToString(METRIC_FORMAT);";
            MetricFunctionList.TryAdd("MessagesPercent", MessagesPercentFunction);




            // MessagesInteractionsPercentFunction
            // ===================================
            string MessagesInteractionsPercentFunction = @"
                double dCalc = 0;
                if (applicAny)
                {
                    var ans = Bag
                        .Where(m => m.InteractionType == ""Chat""
                                 && METRIC_DIRECTION
                                 && m.ChatMessages?.Any() == true);

                    int totalInteractions = ans.Count();

                    if (totalInteractions > 0)
                    {
                        int selectedInteractions = ans.Count(m => 
                            m.ChatMessages.Values.Any(i => METRIC_PARAMETER));
                        dCalc = (double)selectedInteractions / totalInteractions;
                    }
                }
                return dCalc.ToString(METRIC_FORMAT);";
            MetricFunctionList.TryAdd("MessagesInteractionsPercent", MessagesInteractionsPercentFunction);




            // MessagesMaxFirstResponseTime
            // ============================           
            string MessagesMaxFirstResponseTimeFunction1 = @"
                double maxResponse = 0;
                if (applicAny)
                {
                    foreach (var m in Bag
                        .Where(m => m.InteractionType == ""Chat""
                                 && METRIC_DIRECTION
                                 && m.ChatMessages?.Any() == true))
                    {
                        var messages = m.ChatMessages.Values.OrderBy(x => x.TimeStamp).ToList();

                        var firstOut = messages.FirstOrDefault(msg =>
                            msg.MsgDirection == ""outbound"");

                        if (firstOut != null)
                        {
                            var diff = (firstOut.TimeStamp - m.AnsweredDateTime).TotalSeconds;
                            if (diff > maxResponse)
                                maxResponse = diff;
                        }
                    }
                }
                return maxResponse.ToString(METRIC_FORMAT);";

            string MessagesMaxFirstResponseTimeFunction = @"
                TimeSpan maxResponse = TimeSpan.Zero;

                if (!applicAny)
                {              
                    return maxResponse.ToString(@""hh\:mm\:ss"");
                }

                foreach (var interaction in Bag.Where(m =>
                    m.InteractionType == ""Chat"" &&
                    METRIC_DIRECTION &&
                    m.ChatMessages != null &&
                    m.AnsweredDateTime != null))
                {             
                    var firstOutbound = interaction.ChatMessages.Values
                        .OrderBy(msg => msg.TimeStamp)
                        .FirstOrDefault(msg => msg.MsgDirection == ""outbound"");

                    if (firstOutbound != null && firstOutbound.TimeStamp > interaction.AnsweredDateTime)
                    {                
                        var diff = firstOutbound.TimeStamp - interaction.AnsweredDateTime;

                        if (diff > maxResponse)
                        {
                            maxResponse = diff;                      
                        }
                    }
                }

                return maxResponse.ToString(@""hh\:mm\:ss"");";
            MetricFunctionList.TryAdd("MessagesMaxFirstResponseTime", MessagesMaxFirstResponseTimeFunction);




            // MessagesAvgFirstResponseTime
            // ============================
            string MessagesAvgFirstResponseTimeFunction = @"
                List<TimeSpan> responseTimes = new();

                if (!applicAny)
                {              
                    return ""00:00:00"";
                }

                foreach (var interaction in Bag.Where(m =>
                    m.InteractionType == ""Chat"" &&
                    METRIC_DIRECTION &&
                    m.ChatMessages != null &&
                    m.AnsweredDateTime != null))
                {             
                    var firstOutbound = interaction.ChatMessages.Values
                        .OrderBy(msg => msg.TimeStamp)
                        .FirstOrDefault(msg => msg.MsgDirection == ""outbound"");

                    if (firstOutbound != null && firstOutbound.TimeStamp > interaction.AnsweredDateTime)
                    {                
                        var diff = firstOutbound.TimeStamp - interaction.AnsweredDateTime;                      
                        responseTimes.Add(diff);
                    }
                }

                if (!responseTimes.Any())
                return ""00:00:00"";

                var avgSeconds = responseTimes.Average(ts => ts.TotalSeconds);
                var avg = TimeSpan.FromSeconds(avgSeconds);

                return avg.ToString(@""hh\:mm\:ss"");";

            MetricFunctionList.TryAdd("MessagesAvgFirstResponseTime", MessagesAvgFirstResponseTimeFunction);



            // MessagesAvgResponseTime
            // ============================
            string MessagesAvgResponseTimeFunction = @"
            if (!applicAny)
            {
                return ""00:00:00"";
            }

            List<TimeSpan> responseTimes = new();

            foreach (var interaction in Bag.Where(m =>
                m.InteractionType == ""Chat"" &&
                METRIC_DIRECTION &&
                m.ChatMessages != null))
            {
                var messages = interaction.ChatMessages.Values
                    .OrderBy(m => m.TimeStamp)
                    .ToList();

                int index = 0;

                while (index < messages.Count)
                {
                    var inbound = messages[index];

                    if (inbound.MsgDirection != ""inbound"")
                    {
                        index++;
                        continue;
                    }

                    // חפש את הודעת הנציג הראשונה שאחריה
                    var response = messages
                        .Skip(index + 1)
                        .FirstOrDefault(m => m.MsgDirection == ""outbound"");

                    if (response != null)
                    {
                        responseTimes.Add(response.TimeStamp - inbound.TimeStamp);

                        // המשך החיפוש מההודעה שאחרי התגובה
                        index = messages.IndexOf(response) + 1;
                    }
                    else
                    {
                        // אין תגובה לנקודה הזו - מתעלמים
                        break;
                    }
                }
            }

            if (responseTimes.Count == 0)
                return ""00:00:00"";

            var avgSeconds = responseTimes.Average(ts => ts.TotalSeconds);
            var avg = TimeSpan.FromSeconds(avgSeconds);

            return avg.ToString(@""hh\:mm\:ss"");";

            MetricFunctionList.TryAdd("MessagesAvgResponseTime", MessagesAvgResponseTimeFunction);





            // waitDurationAvgFunction
            // =======================
            string waitDurationAvgFunction = @"
                string avg = ""00:00:00"";
                var ans =  Bag.Where(i => METRIC_PARAMETER);
                long count = ans.Count();
                if (count > 0)
                {
                    long sum = Convert.ToInt64(ans.Select(i => i.TimeInQueue).Sum());
                    int tdais = Convert.ToInt32(sum / count);
                    TimeSpan tsaSp = new TimeSpan(0, 0, tdais);
                    avg = tsaSp.ToString(@""hh\:mm\:ss"");
                }
                return avg;";
            MetricFunctionList.TryAdd("WaitDurationAvg", waitDurationAvgFunction);



            // waitDurationMaxFunction
            // =======================
            string waitDurationMaxFunction = @"
                string max = ""00:00:00"";
                var ans =  Bag.Where(i => METRIC_PARAMETER);
                long count = ans.Count();
                    if (count > 0)
                    {
                        int imax = Convert.ToInt32(ans.OrderBy(i => i.TimeInQueue).Select(i => i.TimeInQueue).Last());
                        TimeSpan tsaSp = new TimeSpan(0, 0, imax);
                        max = tsaSp.ToString(@""hh\:mm\:ss"");
                    }
                return max;";
            MetricFunctionList.TryAdd("WaitDurationMax", waitDurationMaxFunction);


            // ===============================================================================================================================         


            // talkDurationAvgFunction
            // =======================
            string talkDurationAvgFunction = @"
                string avg = ""00:00:00"";   
                var ans = Bag.Where(i => i.IsAnswered && (METRIC_PARAMETER));
                long cnt = ans.Count();
                if (cnt > 0)
                {
                    long sum = Convert.ToInt64(ans.Select(i => i.TalkTime).Sum());
                    int tdais = Convert.ToInt32(sum / cnt);
                    TimeSpan ts = new TimeSpan(0, 0, tdais);
                    avg = ts.ToString(@""hh\:mm\:ss"");
                }
                return avg;";
            MetricFunctionList.TryAdd("TalkDurationAvg", talkDurationAvgFunction);


            // talkDurationTotalFunction
            // =========================
            string talkDurationTotalFunction = @"
                string avg = ""00:00:00"";            
                var ans = Bag.Where(i => i.IsAnswered && (METRIC_PARAMETER));
                long cnt = ans.Count();
                if (cnt > 0)
                {
                    long sum = Convert.ToInt64(ans.Select(i => i.TalkTime).Sum());
                    TimeSpan tsaSp = new TimeSpan(0, 0, (int)sum);
                    avg = tsaSp.ToString(@""hh\:mm\:ss"");
                }
                return avg;";
            MetricFunctionList.TryAdd("TalkDurationTotal", talkDurationTotalFunction);


            // talkDurationMaxFunction
            // =======================
            string talkDurationMaxFunction = @"
                string max = ""00:00:00"";              
                var ans = Bag.Where(i => i.IsAnswered && (METRIC_PARAMETER));
                long cnt = ans.Count();
                if (cnt > 0)
                {
                    int imax = Convert.ToInt32(ans.OrderBy(i => i.TalkTime).Select(i => i.TalkTime).Last());
                    TimeSpan tsaSp = new TimeSpan(0, 0, imax);
                    max = tsaSp.ToString(@""hh\:mm\:ss"");
                }
                return max;";
            MetricFunctionList.TryAdd("TalkDurationMax", talkDurationMaxFunction);


            // talkDurationCurMaxFunction
            // ==========================
            string talkDurationCurMaxFunction = @"
                string max = ""00:00:00"";              
                var ans = Bag.Where(i => i.IsAnswered && (METRIC_PARAMETER));
                long cnt = ans.Count();
                if (cnt > 0)
                {
                    DateTime minTalk = ans.OrderBy(i => i.AnsweredLocalDateTime).Select(i => i.AnsweredLocalDateTime).First();

                    if (minTalk < DateTime.MaxValue)
                    {
                        max = ""+"" + minTalk.ToString(""dd/MM/yyyy HH:mm:ss"");
                    }
                }
                return max;";
            MetricFunctionList.TryAdd("TalkDurationCurMax", talkDurationCurMaxFunction);
        }

    }
}
