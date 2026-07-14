using RTM.Tools;
using Microsoft.AspNetCore.SignalR;
using System.Runtime.Intrinsics.Arm;
using Newtonsoft.Json.Linq;
using static System.Collections.Specialized.BitVector32;
using Microsoft.AspNetCore.Http;
using RTM.Types;
using Newtonsoft.Json;
using RTM.Configuration;
using System.Reflection;

namespace RTM
{
    public class RTMAdapter : BackgroundService
    {
        private readonly ILogger<RTMAdapter> _logger;
        private readonly IConfiguration _configuration;

        private readonly IHubContext<RTMHub> _rtmHub;

        private static IServer server;

        private Engine _engine;


        

        public RTMAdapter(ILogger<RTMAdapter> logger, IHubContext<RTMHub> rtmHub, IConfiguration configuration)
        {
            _logger = logger;
            _rtmHub = rtmHub;
            _configuration = configuration;
        }



        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("ExecuteAsync: {Time}", DateTime.Now);

            try
            {
                //string logConfig = _configuration.GetValue<string>("RTM:LogConfig");
                //AsyncLogger.InitializeLog4Net(logConfig);

                string license = AppConfig.LicenseKey;

                //AsyncLogger.Info("Validate License");

                var validationResult = LicenseManager.ValidateLicense(license);

                if (validationResult.License == License.NotValid)
                {
                    AsyncLogger.Info("License is Not Valid");
                    return;
                }
                else if (validationResult.License == License.Expired)
                {
                    AsyncLogger.Info("License Expired");
                    return;
                }

                validationResult.LicenseKey = license;


                AsyncLogger.Info("RTM Start");

                _engine = new Engine(_configuration);
                _engine.GridEvent += Rtm_GridEvent;
                _engine.UserGridEvent += Rtm_UserGridEvent;
                _engine.UserViewEvent += Rtm_UserViewEventAsync;
                _engine.UserUnionDeactivateEvent += Rtm_UserUnionDeactivateEvent;

                await serverStartAsync();


                if (!string.IsNullOrWhiteSpace(AppConfig.AdapterServiceName))
                {
                    try
                    {
                        AsyncLogger.Info($"Restarting {AppConfig.AdapterServiceName}...");
                        WindowsServiceHelper.RestartService(
                            AppConfig.AdapterServiceName,
                            TimeSpan.FromSeconds(60),
                            message => AsyncLogger.Info(message));
                        AsyncLogger.Info($"{AppConfig.AdapterServiceName} restarted successfully.");
                    }
                    catch (InvalidOperationException ex)
                        when (ex.InnerException is System.ComponentModel.Win32Exception w32
                              && w32.NativeErrorCode == 1060)
                    {
                        AsyncLogger.Warn(
                            $"Service '{AppConfig.AdapterServiceName}' not found on this machine — skipped (non-fatal)");
                    }
                    catch (Exception ex)
                    {
                        AsyncLogger.Error($"Failed to restart {AppConfig.AdapterServiceName}", ex);
                        // Do NOT re-throw — missing service name is non-fatal in dev
                    }
                }
                else
                {
                    AsyncLogger.Info("AdapterServiceName not configured — skipping service restart.");
                }


                // Continue to run until the service is stopped
                while (!stoppingToken.IsCancellationRequested)
                {
                    await Task.Delay(10000, stoppingToken);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ExecuteAsync", ex);
            }
        }




        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            if (!string.IsNullOrWhiteSpace(AppConfig.AdapterServiceName))
            {
                try
                {
                    AsyncLogger.Info($"Stopping {AppConfig.AdapterServiceName}...");
                    WindowsServiceHelper.StopServiceIfRunning(
                        AppConfig.AdapterServiceName,
                        TimeSpan.FromSeconds(60),
                        message => AsyncLogger.Info(message));
                    AsyncLogger.Info($"{AppConfig.AdapterServiceName} stopped.");
                }
                catch (Exception ex)
                {
                    AsyncLogger.Error($"Failed to stop {AppConfig.AdapterServiceName}", ex);
                }
            }
            else
            {
                AsyncLogger.Info("AdapterServiceName not configured — skipping service stop.");
            }

            await base.StopAsync(cancellationToken);
        }




        public async Task serverStartAsync()
        {
            AsyncLogger.Info("NamedPipe Server Start");

            server = new NamedPipeServer(AppConfig.PipeName);

            server.ServerStarted += (_, args) =>
              AsyncLogger.Info("SERVER => Server started.");

            server.ClientConnected += (_, args) =>
               AsyncLogger.Info("SERVER => A client connected.");

            server.MessageReceived += Server_MessageReceived;

            server.Disconnected += (_, args) =>
               AsyncLogger.Info($"SERVER => A client disconnected.");

            await server.Start();
        }




        private async void Server_MessageReceived(object? sender, MessageReceivedEventArgs e)
        {
            try
            {
                string jsnonString = (e as MessageReceivedEventArgs).Message;
                var dic = DictionarySerializer.DeserializeFromJson(jsnonString);
                string method = DictionarySerializer.getString(dic["method"]);

                AsyncLogger.Info($"SERVER <= method={method}");

                switch(method)
                {
                    case "setStatistic":
                        setStatistic(dic, jsnonString);
                        break;
                    case "userStatusChanged":
                        userStatusChanged(dic, jsnonString);
                        break;
                    case "userWorkgroupActivation":
                        userWorkgroupActivation(dic, jsnonString);
                        break;
                    case "userConfigurationChanged":
                        userConfigurationChanged(dic, jsnonString);
                        break;
                    case "interactionChanged":
                        await interactionChanged(dic, jsnonString);
                        break;
                    case "interactionRemoved":
                        await interactionRemoved(dic, jsnonString);
                        break;
                    case "setUsers":
                        setUsers(dic, jsnonString);
                        break;
                    case "setSkills":
                        setSkills(dic, jsnonString);
                        break;
                    case "setWorkgroups":
                        setWorkgroups(dic, jsnonString);
                        break;
                    case "messageEventReceived":
                        await messageEventReceived(dic, jsnonString);
                        break;
                }
            }
            catch (Exception ex) 
            {
                AsyncLogger.Error("Server_MessageReceived", ex);
            }
        }




        private void setStatistic (Dictionary<string, object> dic, string jsnonString)
        {
            try
            {
                string statisticKey = DictionarySerializer.getString(dic["method"]);
                string value = DictionarySerializer.getString(dic["method"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                setStatistic(statisticKey, value, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setStatistic " + jsnonString, ex);
            }
        }




        private void userStatusChanged(Dictionary<string, object> dic, string jsnonString)
        {           
            try
            {             
                string userId = DictionarySerializer.getString(dic["userId"]);
                bool loggedIn = DictionarySerializer.getBool(dic["loggedIn"]);
                string statusId = DictionarySerializer.getString(dic["statusId"]);
                string statusName = DictionarySerializer.getString(dic["statusName"]);
                string statusGroup = DictionarySerializer.getString(dic["statusGroup"]);
                DateTime statusChanged = DictionarySerializer.getDateTime(dic["statusChanged"]);
                string station = DictionarySerializer.getString(dic["station"]);
                bool onPhone = DictionarySerializer.getBool(dic["onPhone"]);
                DateTime onPhoneChanged = DictionarySerializer.getDateTime(dic["onPhoneChanged"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                DateTime timeStamp = DictionarySerializer.getDateTime(dic["timeStamp"]);                 
                userStatusChanged(userId, loggedIn, statusId, statusName, statusGroup, statusChanged, station, onPhone, onPhoneChanged, timeStamp, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("userStatusChanged " + jsnonString, ex);
            }
        }


        private void userWorkgroupActivation(Dictionary<string, object> dic, string jsnonString)
        {
            try
            {      
                string workgroup = DictionarySerializer.getString(dic["workgroup"]);
                List<string> activeUsersList = DictionarySerializer.getList(dic["activeUsersList"]);
                List<string> deactiveUsersList = DictionarySerializer.getList(dic["deactiveUsersList"]);
                DateTime timeStamp = DictionarySerializer.getDateTime(dic["timeStamp"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                AsyncLogger.Info($"RECV userWorkgroupActivation workgroup={workgroup} active=[{string.Join(",", activeUsersList)}] deactive=[{string.Join(",", deactiveUsersList)}]");
                userWorkgroupActivation(workgroup, activeUsersList, deactiveUsersList, timeStamp, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("userWorkgroupActivation " + jsnonString, ex);
            }
        }


        private void userConfigurationChanged(Dictionary<string, object> dic, string jsnonString)
        {
            try
            {
                string userId = DictionarySerializer.getString(dic["userId"]);
                string displayName = DictionarySerializer.getString(dic["displayName"]);
                string extension = DictionarySerializer.getString(dic["extension"]);
                string firstName = DictionarySerializer.getString(dic["firstName"]);
                string LastName = DictionarySerializer.getString(dic["LastName"]);
                Dictionary<string, string> customAttributes = DictionarySerializer.getDictionary(dic["customAttributes"]);
                DateTime timeStamp = DictionarySerializer.getDateTime(dic["timeStamp"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                userConfigurationChanged(userId, displayName, extension, firstName, LastName, customAttributes, timeStamp, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("userConfigurationChanged " + jsnonString, ex);
            }
        }



        private async Task interactionChanged(Dictionary<string, object> dic, string jsnonString)
        {
            try
            {
                string workgroup = DictionarySerializer.getString(dic["workgroup"]);
                bool isAdded = DictionarySerializer.getBool(dic["isAdded"]);
                string interactionId = DictionarySerializer.getString(dic["interactionId"]);
                int segmentId = DictionarySerializer.getInt(dic["segmentId"]);
                bool isDisconnect = DictionarySerializer.getBool(dic["isDisconnect"]);
                string callType = DictionarySerializer.getString(dic["callType"]);
                string interactionType = DictionarySerializer.getString(dic["interactionType"]);
                string direction = DictionarySerializer.getString(dic["direction"]);
                string state = DictionarySerializer.getString(dic["state"]);
                DateTime stateChangedTime = DictionarySerializer.getDateTime(dic["stateChangedTime"]);
                TimeSpan duration = DictionarySerializer.getTimeSpan(dic["duration"]);
                TimeSpan timeInWorkgroupQueue = DictionarySerializer.getTimeSpan(dic["timeInWorkgroupQueue"]);
                bool isConsult = DictionarySerializer.getBool(dic["isConsult"]);
                string consultCallId = DictionarySerializer.getString(dic["consultCallId"]);
                string applic = DictionarySerializer.getString(dic["applic"]);
                string classificationCode = DictionarySerializer.getString(dic["classificationCode"]);
                string localUserId = DictionarySerializer.getString(dic["localUserId"]);
                string origCallId = DictionarySerializer.getString(dic["origCallId"]);
                string customCallData = DictionarySerializer.getString(dic["customCallData"]);
                string calculatedStatus = DictionarySerializer.getString(dic["calculatedStatus"]);
                string calculatedStatusTime = DictionarySerializer.getString(dic["calculatedStatusTime"]);
                string c4uState = DictionarySerializer.getString(dic["c4uState"]);
                string localName = DictionarySerializer.getString(dic["localName"]);
                List<string> changedAttributeNames = DictionarySerializer.getList(dic["changedAttributeNames"]);
                bool isHeld = DictionarySerializer.getBool(dic["isHeld"]);
                string remoteAddress = DictionarySerializer.getString(dic["remoteAddress"]);
                string lastMessageSid = DictionarySerializer.getString(dic["lastMessageSid"]);

                string customCallData1 = DictionarySerializer.getString(dic["customCallData1"]);
                string customCallData2 = DictionarySerializer.getString(dic["customCallData2"]);
                string customCallData3 = DictionarySerializer.getString(dic["customCallData3"]);
                string customCallData4 = DictionarySerializer.getString(dic["customCallData4"]);
                string customCallData5 = DictionarySerializer.getString(dic["customCallData5"]);
                string customCallData6 = DictionarySerializer.getString(dic["customCallData6"]);
                string customCallData7 = DictionarySerializer.getString(dic["customCallData7"]);
                string customCallData8 = DictionarySerializer.getString(dic["customCallData8"]);
                string customCallData9 = DictionarySerializer.getString(dic["customCallData9"]);
                string customCallData10 = DictionarySerializer.getString(dic["customCallData10"]);
                string customCallData11 = DictionarySerializer.getString(dic["customCallData11"]);
                string customCallData12 = DictionarySerializer.getString(dic["customCallData12"]);
                string customCallData13 = DictionarySerializer.getString(dic["customCallData13"]);
                string customCallData14 = DictionarySerializer.getString(dic["customCallData14"]);
                string customCallData15 = DictionarySerializer.getString(dic["customCallData15"]);
                string customCallData16 = DictionarySerializer.getString(dic["customCallData16"]);
                string customCallData17 = DictionarySerializer.getString(dic["customCallData17"]);
                string customCallData18 = DictionarySerializer.getString(dic["customCallData18"]);
                string customCallData19 = DictionarySerializer.getString(dic["customCallData19"]);
                string customCallData20 = DictionarySerializer.getString(dic["customCallData20"]);

                DateTime timeStamp = DictionarySerializer.getDateTime(dic["timeStamp"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                await interactionChanged(workgroup, isAdded, interactionId, segmentId, isDisconnect, callType, interactionType, direction, state, stateChangedTime, duration, timeInWorkgroupQueue, isConsult, consultCallId, applic, 
                    classificationCode, localUserId, origCallId, customCallData, calculatedStatus, calculatedStatusTime, c4uState, localName, changedAttributeNames, isHeld, remoteAddress, lastMessageSid,
                    customCallData1, customCallData2, customCallData3, customCallData4, customCallData5, customCallData6, customCallData7, customCallData8, customCallData9, customCallData10, 
                    customCallData11, customCallData12, customCallData13, customCallData14, customCallData15, customCallData16, customCallData17, customCallData18, customCallData19, customCallData20,
                    timeStamp, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("interactionChanged " + jsnonString, ex);
            }
        }












        private async Task interactionRemoved(Dictionary<string, object> dic, string jsnonString)
        {
            try
            {
                string workgroup = DictionarySerializer.getString(dic["workgroup"]);
                string interactionId = DictionarySerializer.getString(dic["interactionId"]);
                int segmentId = DictionarySerializer.getInt(dic["segmentId"]);
                bool isDisconnected = DictionarySerializer.getBool(dic["isDisconnected"]);
                string origCallId = DictionarySerializer.getString(dic["origCallId"]);
                string localUserId = DictionarySerializer.getString(dic["localUserId"]);
                string state = DictionarySerializer.getString(dic["state"]);
                TimeSpan timeInWorkgroupQueue = DictionarySerializer.getTimeSpan(dic["timeInWorkgroupQueue"]);
                bool isCallbackRequest = DictionarySerializer.getBool(dic["isCallbackRequest"]);             
                DateTime timeStamp = DictionarySerializer.getDateTime(dic["timeStamp"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                await interactionRemoved(workgroup, interactionId, segmentId, isDisconnected, origCallId,
                    localUserId, state, timeInWorkgroupQueue, isCallbackRequest, timeStamp, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("interactionRemoved " + jsnonString, ex);
            }
        }







        private async Task messageEventReceived(Dictionary<string, object> dic, string jsnonString)
        {
            try
            {
                string eventType = DictionarySerializer.getString(dic["eventType"]);
                string MessageId = DictionarySerializer.getString(dic["MessageId"]);
                string direction = DictionarySerializer.getString(dic["direction"]);
                string sender = DictionarySerializer.getString(dic["sender"]);
                string recipient = DictionarySerializer.getString(dic["recipient"]);
                string body = DictionarySerializer.getString(dic["body"]);
                DateTime timestamp = DictionarySerializer.getDateTime(dic["timestamp"]);
                string deliveryStatus = DictionarySerializer.getString(dic["deliveryStatus"]);
                
                string messageId = DictionarySerializer.getString(dic["messageId"]);
                await messageEventReceived(eventType, MessageId, direction, sender, recipient, body, deliveryStatus,
                    timestamp, 0);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("messageEventReceived " + jsnonString, ex);
            }
        }







        private void setUsers(Dictionary<string, object> dic, string jsnonString)
        {
            try
            {
                List<string> users = DictionarySerializer.getList(dic["users"]);
                DateTime timeStamp = DictionarySerializer.getDateTime(dic["timeStamp"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                setUsers(users, timeStamp, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setUsers " + jsnonString, ex);
            }
        }




        private void setSkills(Dictionary<string, object> dic, string jsnonString)
        {
            try
            {
                List<string> skils = DictionarySerializer.getList(dic["skills"]);
                DateTime timeStamp = DictionarySerializer.getDateTime(dic["timeStamp"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                setSkills(skils, timeStamp, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setWorkgroups " + jsnonString, ex);
            }
        }




        private void setWorkgroups(Dictionary<string, object> dic, string jsnonString)
        {
            try
            {
                List<string> workgroups = DictionarySerializer.getList(dic["workgroups"]);
                DateTime timeStamp = DictionarySerializer.getDateTime(dic["timeStamp"]);
                long messageId = DictionarySerializer.getLong(dic["messageId"]);
                AsyncLogger.Info($"RECV setWorkgroups count={workgroups.Count} names=[{string.Join(",", workgroups)}]");
                setWorkgroups(workgroups, timeStamp, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setWorkgroups " + jsnonString, ex);
            }
        }




        private void Rtm_GridEvent(object sender, GridEventArgs e)
        {
            if (AppConfig.DiagPushLogging)
            {
                try
                {
                    var cells = e.CellsValuesData;
                    var cellLog = cells != null
                        ? string.Join(", ", cells.Select(c => $"Cell{c.CellId}={c.Value}"))
                        : "null";
                    AsyncLogger.Info($"PUSH updateGridData GridId={e.GridId} cells=[{cellLog}]");
                }
                catch { }
            }
            _rtmHub.Clients.Group(e.GridId.ToString()).SendAsync("updateGridData", e.CellsValuesData);
        }




        private void Rtm_UserGridEvent(object sender, UserGridEventArgs e)
        {
            var unionRes = _engine.getUsers(e.UnionId, false);

            if (unionRes != null)
            {
                if (AppConfig.DiagPushLogging)
                {
                    try
                    {
                        var agentLog = unionRes.Data != null
                            ? string.Join(" | ", unionRes.Data.Select(d =>
                            {
                                var login = d.ContainsKey("AgentLoginName") ? d["AgentLoginName"] : "?";
                                var state = d.ContainsKey("MonAgentState") ? d["MonAgentState"]
                                          : d.ContainsKey("AgentState")    ? d["AgentState"]
                                          : "(no state field)";
                                return $"{login}=>{state}";
                            }))
                            : "null";
                        AsyncLogger.Info($"PUSH updateUserGrid UnionId={e.UnionId} count={unionRes.Count} agents=[{agentLog}]");
                    }
                    catch { }
                }
                _rtmHub.Clients.Group("u" + e.UnionId).SendAsync("updateUserGrid", DateTime.Now, e.UnionId, unionRes);
            }
        }




        private void Rtm_UserUnionDeactivateEvent(object sender, UserUnionActivationEventArgs e)
        {
            var userList = new List<AjaxDictionary<string, string>>();
            userList.Add(e.UserData);
            _rtmHub.Clients.Group("u" + e.UnionId).SendAsync("removeUser", e.UnionId, userList);
        }





        private async void Rtm_UserViewEventAsync(object sender, UserViewEventArgs e)
        {
            AsyncLogger.Info("updateUserView user=" + e.UserId);

            try
            {
                await _rtmHub.Clients.Group("a" + e.UserId).SendAsync("updateUserView", e.UserData);
            }
            catch(Exception ex) 
            {
                AsyncLogger.Error("updateUserView " + ex);
            }
            //_rtmHub.Clients.All.SendAsync("updateUserView", e.UserData);
        }


        public void OnDisconnected(string connectionId)
        {
            _engine.RemoveGridsConnection(connectionId);
        }




        public void refreshCells(string gridId)
        {
            _engine.refreshCells(Convert.ToInt32(gridId));
        }



        public void getUserData(string userId)
        {
            _engine.getUserData(userId);
        }




        public void AddGridConnection(string connectionId, string gridId)
        {
            _engine.AddGridConnection(connectionId, gridId);            
        }



        public RTUsersResult getUsers(int unionId, bool isComplete)
        {
            return _engine.getUsers(unionId, isComplete);
        }




        // userStatusChanged        
        public bool userStatusChanged(string userId, bool loggedIn, string statusId, string statusName, string statusGroup, DateTime StatusChanged, string station, bool onPhone,
            DateTime onPhoneChanged, DateTime timeStamp, long messageId)
        {
            return _engine.userStatusChanged(userId, loggedIn, statusId, statusName, statusGroup, StatusChanged, station, onPhone, onPhoneChanged, timeStamp, messageId);
        }



        // userWorkgroupActivation
        public bool userWorkgroupActivation(string workgroup, List<string> activeUsersList, List<string> deactiveUsersList, DateTime timeStamp, long messageId)
        {
            return _engine.userWorkgroupActivation(workgroup, activeUsersList, deactiveUsersList, timeStamp, messageId);
        }



        // userConfigurationChanged
        public bool userConfigurationChanged(string userId, string displayName, string extension, string firstName, string LastName,
            IDictionary<string, string> customAttributes, DateTime timeStamp, long messageId)
        {
            return _engine.userConfigurationChanged(userId, displayName, extension, firstName, LastName, customAttributes, timeStamp, messageId);
        }



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
            await _engine.interactionChanged(workgroup, isAdded, interactionId, segmentId, isDisconnect, callType, interactionType, direction, state, stateChangedTime, duration,
                timeInWorkgroupQueue, isConsult, consultCallId, applic, classificationCode, localUserId, origCallId, customCallData, calculatedStatus, calculatedStatusTime, c4uState,
                localName, changedAttributeNames, isHeld, remoteAddress, lastMessageSid, customCallData1, customCallData2, customCallData3, customCallData4, customCallData5, customCallData6,
                customCallData7, customCallData8, customCallData9, customCallData10, customCallData11, customCallData12,
                customCallData13, customCallData14, customCallData15, customCallData16, customCallData17, customCallData18,
                customCallData19, customCallData20, timeStamp, messageId);
        }



        // interactionRemoved
        public async Task interactionRemoved(string workgroup, string interactionId, int segmentId, bool isDisconnect, string origCallId, string localUserId,
            string state, TimeSpan timeInWorkgroupQueue, bool isCallbackRequest, DateTime timeStamp, long messageId)
        {
            await _engine.interactionRemoved(workgroup, interactionId, segmentId, isDisconnect, origCallId, localUserId, state,
                timeInWorkgroupQueue, isCallbackRequest, timeStamp, messageId);
        }




        // messageEventReceived
        public async Task messageEventReceived(string eventType, string MessageId, string direction, string sender, string recipient, string body, string deliveryStatus, DateTime timeStamp, long messageId)
        {
            await _engine.messageEventReceived(eventType, MessageId, direction, sender, recipient, body, deliveryStatus, timeStamp, messageId);
        }



        // SetUsers
        public bool setUsers(List<string> users, DateTime timeStamp, long messageId)
        {
            return _engine.setUsers(users, timeStamp, messageId);
        }



        // SetSkils
        public bool setSkills(List<string> skills, DateTime timeStamp, long messageId)
        {
            return _engine.setSkills(skills, timeStamp, messageId);
        }



        // SetWorkgroups
        public bool setWorkgroups(List<string> workgroups, DateTime timeStamp, long messageId)
        {
            return _engine.setWorkgroups(workgroups, timeStamp, messageId);
        }



        public List<string> getWorkgroups()
        {
            return _engine.GetAllWorkgroups();
        }



        public List<string> getAgentgroups()
        {
            return _engine.GetAllAgentgroups();
        }



        public List<string> getQueues()
        {
            return _engine.GetAllWorkgroups();
        }




        public void CompileMetrics(string[] metricIds)
        {
            _engine?.HotReloadMetrics(metricIds);
        }

        public bool LoadData()
        {
            bool retVal = false;

            try
            {
                Task t = new Task(() => _engine.LoadData(true));
                t.Start();

                retVal = true;
            }
            catch
            {
            }

            return retVal;
        }




        public bool UpdateCell(int cellId, int gridId, string metric, int statisticId, int unionId)
        {
            bool retVal = false;

            try
            {
                Task t = new Task(() => _engine.UpdateCell(cellId, gridId, metric, statisticId, unionId));
                t.Start();

                retVal = true;
            }
            catch
            {
            }

            return retVal;
        }




        public List<IDInteraction> GetCellData (int cellId)
        {
            return _engine.GetCellData(cellId);
        }




        // SetUsersStatusList
        public bool setUsersStatusList(string json)
        {
            List<Agent> usersStatusList = JsonConvert.DeserializeObject<List<Agent>>(json);

            return _engine.setUsersStatusList(usersStatusList);
        }



        public List<Statistic> getStatistics()
        {
            return _engine.getStatistics();
        }



        public bool setStatistic(string statisticKey, string value, long messageId)
        {
            return _engine.setStatistic(statisticKey, value, messageId);
        }
    }
}

