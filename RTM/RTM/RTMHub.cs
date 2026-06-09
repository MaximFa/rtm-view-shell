using Microsoft.AspNetCore.SignalR;
using RTM.Tools;

namespace RTM
{
    public class RTMHub : Hub
    {
        private RTMAdapter _hubAdapter;


        public RTMHub(RTMAdapter hubAdapter)
        {
            _hubAdapter = hubAdapter;
        }


        public override async Task OnConnectedAsync()
        {
            string connectionId = Context.ConnectionId;
            AsyncLogger.Info("OnConnected ConnectionId=" + connectionId);
            await base.OnConnectedAsync();
        }



        public override async Task OnDisconnectedAsync(Exception exception)
        {
            string connectionId = Context.ConnectionId;
            AsyncLogger.Info("OnDisconnected ConnectionId=" + connectionId);
            _hubAdapter.OnDisconnected(connectionId);
            await base.OnDisconnectedAsync(exception);
        }



        private void Engine_DialEvent(object sender, EventArgs e)
        {
            //Clients.All.addMessage("Event", "Arived");
        }



        public void Send(string name, string message)
        {
            //AsyncLogger.Info("RTMHub Send message=" + message);
            //Clients.All.addMessage(name, message);
        }


        public bool startInteraction(
           string intercationType,
           string interactionClass,
           string interactionState,
           string idrUuid,
           int sequence,
           string interactionId,
           string interactionInfo1,
           string interactionInfo2,
           string interactionNode,
           string interactionUnique,
           string originatorParty,
           string destinationParty)
        {
            return true; // Bridge.Engine.startInteraction(intercationType, interactionClass, interactionState, idrUuid, sequence,
                         //interactionId, interactionInfo1, interactionInfo2, interactionNode, interactionUnique, originatorParty, destinationParty);
        }





        public void refreshCells(string gridId)
        {
            _hubAdapter.refreshCells(gridId);
        }



        public void getUserData(string userId)
        {
            _hubAdapter.getUserData(userId);
        }




        public void AddGridConnection(string connectionId, string gridId)
        {
            if (gridId[0] == 'u')
            {                
                int unionId = Convert.ToInt32(gridId.Substring(1));

                Groups.AddToGroupAsync(connectionId, gridId);

                AsyncLogger.Info("Groups.Add UnionId = " + gridId);

                _hubAdapter.AddGridConnection(connectionId, gridId);
              
                RTUsersResult res = _hubAdapter.getUsers(Convert.ToInt32(gridId.Substring(1)), true);
               
                Clients.Group(gridId).SendAsync("updateUserGrid", DateTime.Now, unionId, res);
            }
            else
            {
                Groups.AddToGroupAsync(connectionId, gridId);
                _hubAdapter.AddGridConnection(connectionId, gridId);
            }
        }





        public DateTime init(string gridId)
        {
            try
            {
                string connectionId = Context.ConnectionId;
               
                AddGridConnection(connectionId, gridId);             

                AsyncLogger.Info("init GridId=" + gridId + " ConnectionId=" + connectionId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Init", ex);
            }

            return DateTime.Now;
        }




        public string getStr(string gridId)
        {
            try
            {              
                string connectionId = Context.ConnectionId;

                AddGridConnection(connectionId, gridId);

                AsyncLogger.Info("getStr GridId=" + gridId + " ConnectionId=" + connectionId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("getStr", ex);
            }

            return "OK" + gridId;
        }




        // userStatusChanged        
        public bool userStatusChanged(string userId, bool loggedIn, string statusId, string statusName, string statusGroup, DateTime StatusChanged, string station, bool onPhone,
            DateTime onPhoneChanged, DateTime timeStamp, long messageId)
        {
            return _hubAdapter.userStatusChanged(userId, loggedIn, statusId, statusName, statusGroup, StatusChanged, station, onPhone, onPhoneChanged, timeStamp, messageId);
        }



        // userWorkgroupActivation
        public bool userWorkgroupActivation(string workgroup, List<string> activeUsersList, List<string> deactiveUsersList, DateTime timeStamp, long messageId)
        {
            AsyncLogger.Info("userWorkgroupActivation");
            return _hubAdapter.userWorkgroupActivation(workgroup, activeUsersList, deactiveUsersList, timeStamp, messageId);
        }



        // userConfigurationChanged
        public bool userConfigurationChanged(string userId, string displayName, string extension, string firstName, string LastName,
            IDictionary<string, string> customAttributes, DateTime timeStamp, long messageId)
        {
            AsyncLogger.Info("userConfigurationChanged");
            return _hubAdapter.userConfigurationChanged(userId, displayName, extension, firstName, LastName, customAttributes, timeStamp, messageId);
        }



        //// interactionChanged
        //public bool interactionChanged(string workgroup, bool isAdded, string interactionId, int segmentId, bool isDisconnect, string callType, string interactionType, string direction, string state, DateTime stateChangedTime,
        //   TimeSpan duration, TimeSpan timeInWorkgroupQueue, bool isConsult, string consultCallId, string applic, string classificationCode, string localUserId, string origCallId,
        //   string customCallData, string calculatedStatus, string calculatedStatusTime, string c4uState, string localName, List<string> changedAttributeNames,
        //   bool isHeld, string remoteAddress, DateTime timeStamp, long messageId)
        //{
        //    AsyncLogger.Info("interactionChanged");
        //    return _hubAdapter.interactionChanged(workgroup, isAdded, interactionId, segmentId, isDisconnect, callType, interactionType, direction, state, stateChangedTime, duration,
        //        timeInWorkgroupQueue, isConsult, consultCallId, applic, classificationCode, localUserId, origCallId, customCallData, calculatedStatus, calculatedStatusTime, c4uState,
        //        localName, changedAttributeNames, isHeld, remoteAddress, "","","","","","","","","","","","","","","","","","","","", timeStamp, messageId);
        //}



        //// interactionRemoved
        //public bool interactionRemoved(string workgroup, string interactionId, int segmentId, bool isDisconnect, string origCallId, string localUserId,
        //    string state, TimeSpan timeInWorkgroupQueue, DateTime timeStamp, long messageId)
        //{
        //    AsyncLogger.Info("interactionRemoved");
        //    return _hubAdapter.interactionRemoved(workgroup, interactionId, segmentId, isDisconnect, origCallId, localUserId, state,
        //        timeInWorkgroupQueue, false, timeStamp, messageId);

        //}



        // SetUsers
        public bool setUsers(List<string> users, DateTime timeStamp, long messageId)
        {
            AsyncLogger.Info("setUsers");
            return _hubAdapter.setUsers(users, timeStamp, messageId);
        }



        // SetWorkgroups
        public bool setWorkgroups(List<string> workgroups, DateTime timeStamp, long messageId)
        {
            AsyncLogger.Info("setWorkgroups");
            return _hubAdapter.setWorkgroups(workgroups, timeStamp, messageId);
        }




        public List<string> getWorkgroups()
        {
            AsyncLogger.Info("getWorkgroups");
            return _hubAdapter.getWorkgroups();
        }




        // SetUsersStatusList
        public bool setUsersStatusList(string json, DateTime timeStamp, long messageId)
        {
            //List<Agent> usersStatusList = JsonConvert.DeserializeObject<List<Agent>>(json);

            //return _hubAdapter.setUsersStatusList(usersStatusList, timeStamp, messageId);

            return true;
        }



        public List<Statistic> getStatistics()
        {
            return _hubAdapter.getStatistics();
        }



        public bool setStatistic(string statisticKey, string value, long messageId)
        {
            return _hubAdapter.setStatistic(statisticKey, value, messageId);
        }
        /// <summary>
        /// Triggered by Shell after successful metric deploy (Option A, metrics-hot-reload-contract.md §6).
        /// Fire-and-forget: failure is non-fatal; Shell Recompile affordance handles recovery (R2).
        /// Idempotent: same MetricId set can be re-fired without re-apply (skip-if-ContainsKey in Engine).
        /// Tenant-scope: this RTM instance is 1:1 with tenant (CLAUDE.md §33.1) — no TenantId param.
        /// </summary>
        public void compileMetrics(string[] metricIds)
        {
            if (metricIds == null || metricIds.Length == 0) return;
            AsyncLogger.Info($"RTMHub.compileMetrics: received {metricIds.Length} MetricId(s): {string.Join(", ", metricIds)}");
            // Fire-and-forget — failure logged; Shell offers Recompile for recovery (R2)
            Task.Run(() => _hubAdapter.CompileMetrics(metricIds))
                .ContinueWith(
                    t => AsyncLogger.Error("RTMHub.compileMetrics: unhandled exception", t.Exception!.InnerException),
                    TaskContinuationOptions.OnlyOnFaulted);
        }


    }
}

