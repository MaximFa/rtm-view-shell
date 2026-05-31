using ExpressionEvaluator;
using log4net;
using RTM.Tools;
using System.Collections.Concurrent;
using System.Text.RegularExpressions;


namespace RTM
{
    public class UserManager
    {
        private bool _isActive = false;
        private bool _isLoggedIn = false;
        private bool _isHoldChanged = true;

        private DateTime _loggedInStart;
        private DateTime _firstLoggedInStart = DateTime.MinValue;
        private TimeSpan _loggedInTotal = TimeSpan.Zero;

        public TimeSpan LoggedInTotal
        {
            get { return _loggedInTotal; }
        }

        public bool IsTodayLoggedIn { get; set; } = false;

        private string _userStatus = string.Empty;
        private string _statusName = string.Empty;
        private string _userStatusGroup = string.Empty;

        private DBMng _dbMng = null;


        private List<Union> userUniuns = new List<Union>();



        public AjaxDictionary<string, string> UserData = new AjaxDictionary<string, string>();


        public string UserStatusGroup
        {
            get
            {
                return _userStatusGroup;
            }
        }

        private DateTime _userStatusStart;
        private DateTime _userStatusGroupStart;

        private string _calculatedStatus = string.Empty;
        private DateTime _calculatedStatusTime = DateTime.MinValue;

        private ConcurrentDictionary<string, UserStatusData> _TotalStatuses = null;


        public ConcurrentDictionary<string, UserStatusData> TotalStatuses
        {
            get
            {
                return _TotalStatuses;
            }
        }


        private string _userId;
        private string _firstName;
        private string _lastNAme;
        private string _displayName;
        private List<string> _workgroups = null;


        private long lastStatusMsgId = 0;


        // Current Interactions       
        private ConcurrentDictionary<Call, DateTime> _calls = null;

        //  all Interactions (Today)       
        private UserWorkgroupSumList _userWorkgroupSumList = null;
        private IDInteractionBag _todayUserInteractions = new IDInteractionBag();


        private string userSql = string.Empty;
        private string _workgroupTeamList = string.Empty;

      
        private UnionList _unionList = null;


        public List<string> TodayLog { get; set; }

        public List<string> YesterdayLog { get; set; }


        public IDictionary<string, string> CustomAttributes { private get; set; }


        public ConcurrentDictionary<string, MetricDef> Metrics = new ConcurrentDictionary<string, MetricDef>();


        private string getCustomAttribute(string attributeName)
        {
            string retVal = string.Empty;

            try
            {
                if (CustomAttributes.ContainsKey(attributeName))
                {
                    retVal = CustomAttributes[attributeName];
                }
            }
            catch (Exception ex)
            {
                //Log.Error("UserManager.getCustomAttribute", ex);
            }

            return retVal;
        }



        public ConcurrentDictionary<string, int> Connections = new ConcurrentDictionary<string, int>();


        public bool InUse { get; set; }


        public string TimeZone { get; set; } = "";



        public delegate void UserViewEventHandler(object sender, UserViewEventArgs e);
        public event UserViewEventHandler UserViewEvent;




        private ConcurrentDictionary<string, MetricDef> UserViewMetrics { get; set; } = new ConcurrentDictionary<string, MetricDef>();


      

        // User Manager
        public UserManager(string userId, UnionList unionList, DBMng dbMng, ConcurrentDictionary<string, MetricDef> userViewMetrics)
        {
            try
            {
                _dbMng = dbMng;
                IsChanged = false; // true;
                _unionList = unionList;
                _userId = userId;
                _workgroups = new List<string>();
                _TotalStatuses = new ConcurrentDictionary<string, UserStatusData>();
                _calls = new ConcurrentDictionary<Call, DateTime>();
                _userWorkgroupSumList = new UserWorkgroupSumList();
                _userStatusStart = DateTime.MinValue;
                _userStatusGroupStart = DateTime.Now;
                TodayLog = new List<string>();
                YesterdayLog = new List<string>();
                UserViewMetrics = userViewMetrics;

                IsTodayLoggedIn = false;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.UserManager", ex);
            }
        }




        public DateTime getLocalDateTime()
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




        // Set LoggedIn
        private bool setLoggedIn(bool loggedIn, DateTime statusChanged)
        {
            try
            {
                // Connect
                if (loggedIn && (!_isLoggedIn || _loggedInStart < DateTime.Today))
                {
                    _loggedInStart = statusChanged; 
                    _firstLoggedInStart = _loggedInStart;
                    _isLoggedIn = loggedIn;
                    IsChanged = true;
                    IsTodayLoggedIn = true;
                }
                // Disconnect
                else if (_isLoggedIn && !loggedIn)
                {
                    TimeSpan ts = DateTime.Now.Subtract(_loggedInStart);
                    _loggedInTotal = _loggedInTotal.Add(ts);
                    _isLoggedIn = loggedIn;
                    _loggedInStart = DateTime.MinValue;
                    IsChanged = true;
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.setLoggedIn", ex);
            }

            return loggedIn;
        }





        private string LastNoPhoneStatusId;
        private string LastNoPhoneStatusName;
        private string LastNoPhoneStatusGroup;


        // =============================================== 11/11/2025 =========================================
        private string LastPhoneStatusId;
        private string LastPhoneStatusName;
        private string LastPhoneStatusGroup;
        //=====================================================================================================



        //public bool isHold()
        //{
        //    return (_calls.Where(c => c.Key.IdInteraction.IsHeld && c.Key.IdInteraction.InteractionType == "Call").Any());
        //}

        // =============================================== 11/11/2025 =========================================
        public bool isHold()
        {
            bool hasHeldCall = false;

            foreach (var item in _calls)
            {
                var interaction = item.Key.IdInteraction;

                // Reset via method, since setter is private
                interaction.ResetHeldChangeFlag();

                if (!hasHeldCall && interaction.InteractionType == "Call" && interaction.IsHeld)
                    hasHeldCall = true;
            }

            return hasHeldCall;
        }
        //=====================================================================================================


        //public bool isLastNoPhone = false;

       
        // Set Status
        public void setStatus(bool isLoggedIn, string newStatus, string statusName, string statusGroup, DateTime statusChanged, string station, bool onPhone, DateTime oOnPhoneChanged, long messageId, bool isCalcStatus)
        {
            string log = string.Empty;
            try
            {
                log = "isLoggedIn=" + isLoggedIn + " newStatus=" + newStatus + " statusName=" + statusName + " statusGroup=" + statusGroup +
                    " statusChanged=" + statusChanged.ToString("dd/MM/yyyy HH:mm:ss") + " station=" + station + " onPhone=" + onPhone +
                    " oOnPhoneChanged=" + oOnPhoneChanged.ToString("dd/MM/yyyy HH:mm:ss") + " messageId=" + messageId;// + " isLastNoPhone=" + isLastNoPhone;
                TodayLog.Add(log);

                AsyncLogger.Info($"SetStatus userId={userId} " + log);

                //if (newStatus == "LastNoPhone")    
                //{
                //    if (!isLastNoPhone)
                //    {
                //        isLastNoPhone = true;
                //    }
                //    else
                //   {
                //       return;
                //    }
                //}                          

                if (!_isLoggedIn && isCalcStatus)
                {
                    AsyncLogger.Error("!_isLoggedIn && isCalcStatus");
                    return;
                }
              

                if (_userStatusStart > statusChanged)
                {
                    AsyncLogger.Error("_userStatusStart > statusChanged");
                    return;                
                }
                else if (_userStatusStart == statusChanged)
                {
                    if (lastStatusMsgId > messageId)
                    {
                        AsyncLogger.Error("lastStatusMsgId > messageId");
                        return;
                    }
                }


                if (newStatus == "Log_off")
                {
                    isLoggedIn = false;
                }


                //if (OnPhone && !isCalcStatus)
                //{
                //    AsyncLogger.Error("(OnPhone && !isCalcStatus");
                //    return;
                //}


                //lastStatusMsgId = messageId;              


                if (setLoggedIn(isLoggedIn, statusChanged))
                {
                    Station = station;
                  
                    if (!isCalcStatus) // Status from CallCenter
                    {
                        LastNoPhoneStatusId = newStatus;
                        LastNoPhoneStatusName = statusName;
                        LastNoPhoneStatusGroup = statusGroup;
                        AsyncLogger.Info($"LastNoPhoneStatusId = {newStatus}");

                        if (OnPhone)
                        {
                            AsyncLogger.Error("(OnPhone && !isCalcStatus");
                            return;
                        }
                    }
                    
                    if (onPhone != OnPhone)
                    {
                        OnPhoneChanged = oOnPhoneChanged;
                    }

                    OnPhone = onPhone;
                  
                    IsChanged = true;
                }
                else
                {
                    newStatus = "SIGNOFF";
                    statusGroup = "SIGNOFF";
                    statusName = "SIGNOFF";
                }


                lastStatusMsgId = messageId;


                if (newStatus == "LastNoPhone") // Like Unhold
                {
                    // =============================================== 11/11/2025 =========================================
                    //newStatus = LastNoPhoneStatusId;
                    //statusName = LastNoPhoneStatusName;
                    //statusGroup = LastNoPhoneStatusGroup;
                    //AsyncLogger.Info($"statusName = {LastNoPhoneStatusId}");


                    if (_calls.Any() || (_userStatus == "Hold" && LastPhoneStatusId != string.Empty))
                    {
                        newStatus = LastPhoneStatusId;
                        statusName = LastPhoneStatusName;
                        statusGroup = LastPhoneStatusGroup;
                        AsyncLogger.Info($"1statusName = {LastPhoneStatusId}");
                        LastPhoneStatusId = string.Empty;                      
                    }
                    else
                    {
                        newStatus = LastNoPhoneStatusId;
                        statusName = LastNoPhoneStatusName;
                        statusGroup = LastNoPhoneStatusGroup;
                        AsyncLogger.Info($"2statusName = {LastNoPhoneStatusId}");
                    }


                    //if (!_calls.Any() && _userStatus != "Hold")
                    //{
                    //    newStatus = LastNoPhoneStatusId;
                    //    statusName = LastNoPhoneStatusName;
                    //    statusGroup = LastNoPhoneStatusGroup;
                    //    AsyncLogger.Info($"statusName = {LastNoPhoneStatusId}");
                    //}
                    //else
                    //{
                    //    newStatus = LastPhoneStatusId;
                    //    statusName = LastPhoneStatusName;
                    //    statusGroup = LastPhoneStatusGroup;
                    //    AsyncLogger.Info($"statusName = {LastPhoneStatusId}");
                    //    LastPhoneStatusId = string.Empty;
                    //}

                    //======================================================================================================
                }

                // =============================================== 11/11/2025 =========================================
                else if (isCalcStatus && newStatus != "Hold" && newStatus != "Wrap Up")
                {
                    LastPhoneStatusId = newStatus;
                    LastPhoneStatusName = statusName;
                    LastPhoneStatusGroup = statusGroup;
                    AsyncLogger.Info($"LastPhoneStatusId = {newStatus}");
                }
                //======================================================================================================


                if (_userStatus != newStatus)
                {
                    //if (_userStatus != string.Empty)
                    if (!string.IsNullOrWhiteSpace(_userStatus))
                    {
                        TimeSpan ts = statusChanged.Subtract(_userStatusStart);

                        if (_TotalStatuses.ContainsKey(_userStatus))
                        {
                            _TotalStatuses[_userStatus].addDur(ts, _userStatusStart, statusChanged);// = statusTs;                                                             
                        }
                        else
                        {
                            _TotalStatuses.TryAdd(_userStatus, new UserStatusData(this, _userStatus, statusName, statusGroup, ts, _dbMng, userId, false, DisplayName));
                        }
                    }

                    _userStatus = newStatus;
                    _statusName = statusName;

                    if (!_calls.Any())
                    {
                        _calculatedStatus = _userStatus;
                        _calculatedStatusTime = _userStatusStart;
                    }

                    if (_userStatusGroup != statusGroup)
                    {
                        _userStatusGroupStart = statusChanged;
                    }

                    _userStatusGroup = statusGroup;

                    _userStatusStart = statusChanged;


                    if (!_TotalStatuses.ContainsKey(newStatus))
                    {
                        _TotalStatuses.TryAdd(newStatus, new UserStatusData(this, _userStatus, statusName, statusGroup, TimeSpan.Zero, _dbMng, userId, false, DisplayName));
                    }
                }
                IsChanged = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.setStatus " + log, ex);
            }
        }




        // ContainsAllItems
        private bool ContainsAllItems(List<string> a, List<string> b)
        {
            return !b.Except(a).Any();
        }


       

        // Refresh Unions
        public void refreshUnions()
        {
            try { 
                    foreach (Union union in _unionList.Values)
                    {               
                        bool containsInUnion = false;
                        foreach (List<string> wgArr in union.UserGroups.Values)
                        {                 
                            if (ContainsAllItems(_workgroups, wgArr))
                            {
                                containsInUnion = true;                      

                                if (!union.Users.Contains(this))
                                {
                                    try
                                    {
                                        TimeZone = union.TimeZone;                          
                                        union.Users.Add(this);
                                        userUniuns.Add(union);
                                        AsyncLogger.Info($"refreshUnions Add User={this.userId} to Union={union.UnionId}");
                                    }
                                    catch (Exception ex)
                                    {
                                        AsyncLogger.Error($"refreshUnions Add User={this.userId} to Union={union.UnionId}");
                                    }
                                }
                            }
                        }
                        if (!containsInUnion && union.Users.Contains(this))
                        {
                            union.UsersToRemove.Add(this);

                            userUniuns.Remove(union);
                            union.Users.Remove(this);
                            AsyncLogger.Info($"refreshUnions Remove User={this.userId} from Union={union.UnionId}");
                        }
                    }

                    refreshMetrics();
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("refreshMetrics", ex);
            }
}



        
        // Refresh Metrics
        private void refreshMetrics()
        {      
            try
            { 
                Metrics = new ConcurrentDictionary<string, MetricDef>(UserViewMetrics);

                AsyncLogger.Info($"refreshMetrics UserId={userId} userUniuns.Count={userUniuns.Count()}");

                foreach (var union in userUniuns)
                {              
                    union.UserGridMetrics.ToList().ForEach(x => Metrics.TryAdd(x.Key, x.Value));
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("refreshMetrics", ex);
            }
        }

        /// <summary>
        /// Public entry point called by Engine.LoadData() after union metrics are updated.
        /// Rebuilds this UserManager's metric dictionary and marks it as changed so that
        /// the next CollectData cycle recomputes all metrics (including newly added columns).
        /// </summary>
        public void ForceRefreshMetrics()
        {
            try
            {
                refreshMetrics();
                IsChanged = true;
                AsyncLogger.Info($"ForceRefreshMetrics UserId={userId}");
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ForceRefreshMetrics", ex);
            }
        }

        // Workgroup Activation
        public void workgroupActivation(string workgroup, bool isActive)
        {
            try
            {
                AsyncLogger.Info($"workgroupActivation UserId={userId} workgroup={workgroup} isActive={isActive}");

                if (_workgroups.Contains(workgroup))
                {
                    if (!isActive)
                    {
                        _workgroups.Remove(workgroup);
                        refreshUnions();
                    }
                }
                else
                {
                    if (isActive)
                    {
                        _workgroups.Add(workgroup);
                        refreshUnions();
                    }
                }

                if (_workgroups.Count > 0)
                {
                    _isActive = true;
                }
                else
                {
                    _isActive = false;
                }

                IsChanged = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.workgroupActivation", ex);
            }
        }





        // Set Calculated Status
        private void setCalulatedStatus(string calculatedStatus, string calculatedStatusTime)
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(calculatedStatus) && !string.IsNullOrWhiteSpace(calculatedStatusTime))
                {
                    _calculatedStatus = calculatedStatus;
                    _calculatedStatusTime = DateTime.ParseExact(calculatedStatusTime, "yyyy-MM-dd HH:mm:ss", null);
                    IsChanged = true;
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.setCalulatedStatus", ex);
            }
        }



        // Call_CallStateChangedEvent
        private void call_CallStateChangedEvent(object sender, CallStateChangedEventArgs e)
        {
            try
            {
                setCalulatedStatus(e.CalculatedStatus, e.CalculatedStatusTime);
                IsChanged = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.call_CallStateChangedEvent", ex);
            }
        }




        // Start Call
        private void startCall(Call call, string workGroup)
        {
            _todayUserInteractions.Add(call.IdInteraction);
            foreach (Union union in userUniuns)
            {
                union.addUsersInteraction(call.IdInteraction);
            }
            _calls.TryAdd(call, DateTime.Now);

            if (!string.IsNullOrWhiteSpace(call.IdInteraction.RemoteAddress))
            {
                AsyncLogger.Info($"UserManager.startCall UserId={_userId} DisplayName={DisplayName} CallId={call.IdInteraction.InteractionId} RemoteAddress={call.IdInteraction.RemoteAddress}");
            }

            call.CallStateChangedEvent += call_CallStateChangedEvent;
            setCalulatedStatus(call.CalculatedStatus, call.CalculatedStatusTime);
        }




        // Start Incoming Call
        public void startIncomingCall(Call call, string workGroup)
        {
            try
            {
                string interactionType = call.IdInteraction.InteractionType;
                string callType = call.IdInteraction.CallType;
                string interactionId = call.InteractionId;

                startCall(call, workGroup);

                UserWorkgroupSum userWorkgroupSum = _userWorkgroupSumList.GetOrAdd(workGroup, new UserWorkgroupSum(workGroup));

                switch (interactionType)
                {
                    case "Call":
                        if (callType == "External")
                        {
                            userWorkgroupSum.incomingCalls.Add(interactionId);
                        }
                        else if (callType == "Intercom")
                        {
                            userWorkgroupSum.incomingInsideCalls.Add(interactionId);
                        }
                        break;

                    case "Chat":
                        userWorkgroupSum.incomingChat.Add(interactionId);
                        break;

                    case "Email":
                        userWorkgroupSum.incomingFax.Add(interactionId);
                        break;

                    case "Dialer":
                        userWorkgroupSum.dialerCalls.Add(interactionId);
                        break;
                }

                IsChanged = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.startIncomingCall", ex);
            }
        }



        // End Incoming Call
        public void endIncomingCall(Call call, string workGroup)
        {
            try
            {
                string interactionType = call.IdInteraction.InteractionType;
                string callType = call.IdInteraction.CallType;
                string interactionId = call.InteractionId;

                _calls.TryRemove(call, out _);
                //_heldCalls.Remove(call.interactionId);
                _isHoldChanged = true;
                call.CallStateChangedEvent -= call_CallStateChangedEvent;

                if (!_calls.Any())
                {
                    _calculatedStatus = _userStatus;
                    _calculatedStatusTime = _userStatusStart;
                }

                UserWorkgroupSum userWorkgroupSum = _userWorkgroupSumList.GetOrAdd(workGroup, new UserWorkgroupSum(workGroup));

                switch (interactionType)
                {
                    case "Call":
                        if (callType == "External")
                        {
                            userWorkgroupSum.incomingCalls.Remove(interactionId);
                        }
                        else if (callType == "Intercom")
                        {
                            userWorkgroupSum.incomingInsideCalls.Remove(interactionId);
                        }
                        break;

                    case "Chat":
                        userWorkgroupSum.incomingChat.Remove(interactionId);
                        break;

                    case "Email":
                        userWorkgroupSum.incomingFax.Remove(interactionId);
                        break;

                    case "Dialer":
                        userWorkgroupSum.dialerCalls.Remove(interactionId);
                        break;
                }
                IsChanged = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.endIncomingCall", ex);
            }
        }



        // Start Outgoing Call
        public void startOutgoingCall(Call call, string workGroup)
        {
            try
            {
                string interactionType = call.IdInteraction.InteractionType;
                string callType = call.IdInteraction.CallType;
                string interactionId = call.InteractionId;

                startCall(call, workGroup);

                UserWorkgroupSum userWorkgroupSum = _userWorkgroupSumList.GetOrAdd(workGroup, new UserWorkgroupSum(workGroup));

                if (interactionType == "Call")
                {
                    if (callType == "External")
                    {
                        userWorkgroupSum.outGoingCalls.Add(interactionId);
                    }
                    else if (callType == "Intercom")
                    {
                        userWorkgroupSum.outgoingInsideCalls.Add(interactionId);
                    }
                }
                IsChanged = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.startOutgoingCall", ex);
            }
        }



        // End Outgoing Call
        public void endOutgoingCall(Call call, string workGroup)
        {
            try
            {
                string interactionType = call.IdInteraction.InteractionType;
                string callType = call.IdInteraction.CallType;
                string interactionId = call.InteractionId;

                _calls.Remove(call, out _);
                //_heldCalls.Remove(call.interactionId);
                _isHoldChanged = true;

                call.CallStateChangedEvent -= call_CallStateChangedEvent;

                if (!_calls.Any())
                {
                    _calculatedStatus = _userStatus;
                    _calculatedStatusTime = _userStatusStart;

                }

                UserWorkgroupSum userWorkgroupSum = _userWorkgroupSumList.GetOrAdd(workGroup, new UserWorkgroupSum(workGroup));

                if (interactionType == "Call")
                {
                    if (callType == "External")
                    {
                        userWorkgroupSum.outGoingCalls.Remove(interactionId);
                    }
                    else if (callType == "Intercom")
                    {
                        userWorkgroupSum.outgoingInsideCalls.Remove(interactionId);
                    }
                }

                IsChanged = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.endOutgoingCall", ex);
            }
        }




        // Get InteractionsCount
        public string getInteractionsCount(MetricDef metric)
        {
            string val = "0";
            try
            {
                if (!_todayUserInteractions.IsEmpty)
                {
                    val = metric.MetricUserFunction(_todayUserInteractions.Bag, userId);
                }
            }
            catch { }
            return val;
        }




        // Get CPH
        public string getCPH(MetricDef metric)
        {          
            string val = 0.ToString(metric.Format);
            //AsyncLogger.Info("USer getCPH Start");
            try
            {                
                if (!_todayUserInteractions.IsEmpty)
                {
                    //AsyncLogger.Info("USer getCPH _todayUserInteractions Is NOT Empty");
                    string callsCount = metric.MetricUserFunction(_todayUserInteractions.Bag, userId);
                    //AsyncLogger.Info($"USer getCPH callsCount={callsCount}");

                    long nowTicks = DateTime.Now.Ticks;
                    long totalTicks = (nowTicks - loggedInStart.Ticks) + LoggedInTotal.Ticks;
                    TimeSpan loggedInTotal = new TimeSpan(totalTicks);

                    val = CalculateCPH(loggedInTotal, callsCount, metric.Format);
                    //AsyncLogger.Info($"USer getCPH val={val}");
                }
            }
            catch { }
            return val;
        }



        public string CalculateCPH(TimeSpan loggedInTotal, string callsCountStr, string format)
        {
            //AsyncLogger.Info($"USer CalculateCPH loggedInTotal={loggedInTotal} callsCountStr={callsCountStr} format={format}");
            // 1. חילוץ מספר השיחות (טיפול ב-NULL או ערך לא חוקי)
            if (string.IsNullOrWhiteSpace(callsCountStr) || !int.TryParse(callsCountStr, out int totalCalls))
            {
                //AsyncLogger.Info($"USer CalculateCPH (string.IsNullOrWhiteSpace(callsCountStr) || !int.TryParse(callsCountStr, out int totalCalls))");
                totalCalls = 0;
            }

            // 2. שליפת סך השעות מתוך ה-TimeSpan
            // TotalHours מחזיר את כל הזמן ביחידות של שעות (כולל שברים עשרוניים)
            // דוגמה: שעה וחצי יחזירו 1.5
            double totalHours = loggedInTotal.TotalHours;
            //AsyncLogger.Info($"USer CalculateCPH totalHours={totalHours}");

            // 3. הגנה מחלוקה באפס
            // אם הנציג טרם צבר זמן עבודה (או שהזמן אפסי/שלילי בגלל באג)
            // נשתמש בערך סף נמוך מאוד (למשל אלפית השעה)
            if (totalHours < 0.001)
            {
                //AsyncLogger.Info($"(totalHours < 0.001)");
                return 0.ToString(format);
            }

            // 4. חישוב המדד
            double cph = totalCalls / totalHours;
            //AsyncLogger.Info($"USer CalculateCPH cph={cph}");

            // 5. החזרה בפורמט המבוקש
            return cph.ToString(format);
        }




        // Get TalkDurationAvg
        public string getTalkDurationAvg(MetricDef metric)
        {
            string val = "00:00:00";
            try
            {
                val =  metric.MetricUserFunction(_todayUserInteractions.Bag, userId);
            }
            catch { }
            return val;
        }



        // Get TalkDurationMax
        public string getTalkDurationMax(MetricDef metric)
        {
            string val = "00:00:00";
            try
            {
                val = metric.MetricUserFunction(_todayUserInteractions.Bag, userId);
            }
            catch { }
            return val;
        }


        // Get TalkDurationMax
        public string getMessagesAvgFirstResponseTimeFunction(MetricDef metric)
        {
            string val = "00:00:00";
            AsyncLogger.Info($"getMessagesAvgFirstResponseTimeFunction userId={userId} metric={metric.ID}");
            try
            {
                val = metric.MetricUserFunction(_todayUserInteractions.Bag, userId);
            }
            catch(Exception ex)
            {
                AsyncLogger.Error($"getMessagesAvgFirstResponseTimeFunction", ex);
            }
            return val;
        }


        // Get TalkDurationMax
        public string getMessagesAvgResponseTimeFunction(MetricDef metric)
        {
            string val = "00:00:00";
            try
            {
                val = metric.MetricUserFunction(_todayUserInteractions.Bag, userId);
            }
            catch { }
            return val;
        }



        // Metric Function
        public string metricFunction(MetricDef metric, ConcurrentDictionary<string, MetricDef> metrics)
        {
            string val = string.Empty;
            string logStr = string.Empty;

            try
            {
                switch (metric.Function)
                {
                    // Details
                    case "UserID":
                        val = userId;
                        break;

                    case "FirstName":
                        val = FirstName;
                        break;

                    case "LastName":
                        val = LastName;
                        break;

                    case "DisplayName":
                        if (string.IsNullOrWhiteSpace(DisplayName))
                        {
                            val = userId;
                        }
                        else
                        {
                            val = DisplayName;
                        }
                        break;

                    case "UserExtension":
                        val = Extension;
                        break;

                    case "Station":
                        val = Station;
                        break;

                    case "OnPhoneDuration":  // < T / B >
                        val = "&nbsp;";
                        if (OnPhone)
                        {
                            val = "+" + OnPhoneChanged.ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        break;

                    case "UserCustomAttribute": // AttributeName                        
                        val = getCustomAttribute(metric.Parameter);
                        break;


                    case "IsTodayLogin":
                        val = "false";
                        if (IsTodayLoggedIn)
                        {
                            val = "true";
                        }
                        break;

                    // Current Status                     
                    case "CurLoginDuration":  // < T / B >
                        val = "&nbsp;";
                        if (isLoggedId)
                        {
                            val = "+" + loggedInStart.ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        break;

                    // לא מתאפס בחצות
                    // כנל ללוגין
                    case "CurLoginDurationReal":  // < T / B >
                        val = "&nbsp;";
                        if (isLoggedId)
                        {
                            val = "+" + loggedInStart.ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        break;

                    case "CurLoginTimestamp":  // < T / B >
                        val = "&nbsp;";
                        if (isLoggedId)
                        {
                            val = loggedInStart.ToString("HH:mm");
                        }
                        break;

                    case "FirstLoginTimestamp":  // < T / B >
                        val = "&nbsp;";
                        if (FirstLoggedInStart != DateTime.MinValue)
                        {
                            val = FirstLoggedInStart.ToString("HH:mm");
                        }
                        break;

                    case "CurStatus":
                        val = UserStatus;
                        AsyncLogger.Info($"userId={_userId} CurStatus={val}");
                        break;

                    case "CurStatusTitle":
                        val = StatusName;
                        if (string.IsNullOrEmpty(val))
                        {
                            val = UserStatus;
                        }
                        AsyncLogger.Info($"userId={_userId} CurStatusTitle={val}");
                        break;

                    case "CurStatusGroup":
                        val = _userStatusGroup;
                        break;

                    case "CurStatusDuration":  // < T / B >
                        val = "+" + TimeInStatus.ToString("dd/MM/yyyy HH:mm:ss");
                        break;

                    case "CurStatusGroupDuration":  // < T / B >
                        val = "+" + TimeInStatusGroup.ToString("dd/MM/yyyy HH:mm:ss");
                        break;

                    // Calculated Status
                    case "CalculatedStatus":
                        val = "&nbsp;";
                        if (_calculatedStatus != UserStatus)
                        {
                            val = _calculatedStatus;
                        }
                        break;

                    case "CalculatedStatusTime":  // < T / B >
                        val = "&nbsp;";
                        if (_calculatedStatus != UserStatus)
                        {
                            val = "+" + _calculatedStatusTime.ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        break;

                    // Total Status
                    case "TotalLoginDuration":  // < T / B > 
                        val = "&nbsp;";
                        if (isLoggedId)
                        {
                            TimeSpan loginDur = new TimeSpan(_TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks));
                            val = "+" + DateTime.Now.Subtract(loginDur).ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        break;

                   
                    case "TotalStatusDuration": // Parameter = StatusId   < T / B > 
                        TimeSpan statusDur = new TimeSpan(_TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter).Sum(r => r.Dur.Ticks));
                        val = "-00:00:00";// "&nbsp;";
                        DateTime st = DateTime.Now;

                        if (metric.Parameter == UserStatus)
                        {
                            st = TimeInStatus;
                            val = "+" + st.Subtract(statusDur).ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        else if (statusDur != TimeSpan.Zero)
                        {
                            val = "-" + statusDur.ToString(@"hh\:mm\:ss");
                        }
                        break;

                    case "TotalStatusGroupDuration": // StatusGroupId   < T / B > 
                        TimeSpan statusGrpDur = new TimeSpan(_TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter).Sum(r => r.Dur.Ticks));
                        val = "-00:00:00";// "&nbsp;";
                        DateTime st1 = DateTime.Now;

                        if (metric.Parameter == UserStatusGroup)
                        {
                            st = TimeInStatus;
                            val = "+" + st1.Subtract(statusGrpDur).ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        else if (statusGrpDur != TimeSpan.Zero)
                        {
                            val = "-" + statusGrpDur.ToString(@"hh\:mm\:ss");
                        }
                        break;

                    case "TotalStatusPercent":
                        val = "0";
                        if (isLoggedId)
                        {
                            long loginDur1 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
                            long statusGrpDur1 = _TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter).Sum(r => r.Dur.Ticks);
                            double dCalc1 = (double)statusGrpDur1 / (double)loginDur1;
                            val = dCalc1.ToString(metric.Format); // "#0.##%"
                        }
                        break;

                    case "TotalStatusGroupPercent":
                        val = "0";
                        if (isLoggedId)
                        {
                            long loginDur2 = _TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks);
                            long statusGrpDur2 = _TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter).Sum(r => r.Dur.Ticks);
                            double dCalc2 = (double)statusGrpDur2 / (double)loginDur2;
                            val = dCalc2.ToString(metric.Format); // "#0.##%"
                        }
                        break;

                    //==============================================================================================================================

                    case "TotalStatusCount": // StatusId                                                      
                        val = _TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter).Sum(y => y.Count).ToString();
                        break;


                    case "TotalStatusGroupCount": // StatusGroupId                            
                        val = _TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter).Sum(y => y.Count).ToString();
                        break;


                    case "TotalStatusDurationAvg": // StatusId   
                        var v121 = _TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter);
                        int tsda = v121.Sum(y => y.Count);
                        val = "00:00:00";
                        if (tsda > 0)
                        {
                            double tsdDur = v121.Sum(r => r.Dur.Ticks);
                            TimeSpan statusAvg = new TimeSpan(Convert.ToInt64(tsdDur / tsda));
                            val = statusAvg.ToString(@"hh\:mm\:ss");
                        }
                        break;


                    case "TotalStatusGroupDurationAvg":
                        var v122 = _TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter);
                        int tsgda = v122.Sum(y => y.Count);
                        val = "00:00:00";
                        if (tsgda > 0)
                        {
                            double tsdDur = v122.Sum(r => r.Dur.Ticks);
                            TimeSpan statusGrpMax = new TimeSpan(Convert.ToInt64(tsdDur / tsgda));
                            val = statusGrpMax.ToString(@"hh\:mm\:ss");
                        }
                        break;


                    case "TotalStatusDurationMax": // StatusId                           
                        var ddd1 = _TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter);
                        val = "00:00:00";
                        if (ddd1.Any())
                        {
                            TimeSpan statusMax = new TimeSpan(ddd1.Max(r => r.Dur.Ticks));
                            val = statusMax.ToString(@"hh\:mm\:ss");
                        }
                        break;


                    case "TotalStatusGroupDurationMax": // StatusGroupId                              
                        var ddd = _TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter);
                        val = "00:00:00";
                        if (ddd.Any())
                        {
                            TimeSpan statusGrpMax = new TimeSpan(ddd.Max(r => r.Dur.Ticks));
                            val = statusGrpMax.ToString(@"hh\:mm\:ss");
                        }
                        break;


                    //==============================================================================================================================


                    // Longest Interaction Details
                    case "LongestInteractionId":
                        val = "&nbsp;";
                        if (LongestInteraction != null && OnPhone)
                        {
                            val = LongestInteraction.IdInteraction.InteractionId;
                        }
                        break;

                    case "LongestInteractionWorkgroup":
                        val = "&nbsp;";
                        if (LongestInteraction != null && OnPhone)
                        {
                            val = LongestInteraction.IdInteraction.Workgroup;
                        }
                        break;

                    case "LongestInteractionType":
                        val = "&nbsp;";
                        if (LongestInteraction != null && OnPhone)
                        {
                            val = LongestInteraction.IdInteraction.InteractionType;
                        }
                        break;

                    case "LongestInteractionRemoteAddress":
                        val = "&nbsp;";
                        if (LongestInteraction != null && OnPhone)
                        {
                            val = LongestInteraction.IdInteraction.RemoteAddress;
                            val = val.TrimStart('+');
                        }
                        break;

                    case "LongestInteractionCustomCallData":
                        val = LongestInteraction.IdInteraction.CustomCallData;
                        break;

                    case "LongestInteractionDuration": // < T / B >
                        DateTime longDur = LongestInteractionDuration;
                        val = "&nbsp;";
                        if (longDur != DateTime.MinValue)
                        {
                            val = "+" + longDur.ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        break;

                    case "LongestInteractionState":
                        val = "&nbsp;";
                        if (LongestInteraction != null && OnPhone)
                        {
                            val = LongestInteraction.IdInteraction.State;
                        }
                        break;

                    case "LongestInteractionStateDuration":  // < T / B >
                        val = "&nbsp;";
                        if (LongestInteraction != null && OnPhone)
                        {
                            val = "+" + LongestInteraction.IdInteraction.stateStart.ToString("dd/MM/yyyy HH:mm:ss");
                        }
                        break;

                    // Today Interactions
                    case "InteractionsCount":
                        val = getInteractionsCount(metric);                       
                        break;

                    case "CPH":
                        val = getCPH(metric);
                        break;

                    case "TalkDurationAvg":                       
                        val = getTalkDurationAvg(metric);
                        break;

                    case "TalkDurationMax":                      
                        val = getTalkDurationMax(metric);
                        break;

                    // Other
                    case "Productivity":
                        val = "0";
                        break;

                    case "Efficiency":
                        val = "0";
                        break;

                    case "MessagesAvgFirstResponseTime":
                        val = getMessagesAvgFirstResponseTimeFunction(metric);
                        break;

                    case "MessagesAvgResponseTime":
                        val = getMessagesAvgResponseTimeFunction(metric);
                        break;

                    // Calc
                    case "Calc":
                        string calc1 = metric.Parameter;
                        var pattern = @"\[(.*?)\]";
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
                        break;
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.metricFunction Metric=" + metric.ID + " Info=" + logStr, ex);
            }

            return val;
        }



        // Get Javascript TimeStamp
        private Int64 GetJavascriptTimeStamp(DateTime dt)
        {
            var nineteenseventy = new DateTime(1970, 1, 1);
            var timeElapsed = (dt.ToUniversalTime() - nineteenseventy);
            return (Int64)(timeElapsed.TotalMilliseconds + 0.5);
        }



        // Fix Data
        private string fixData(string val)
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(val))
                {
                    char firstChr = val[0];

                    if (firstChr == '+')
                    {
                        try
                        {
                            val = val.Substring(1);
                            DateTime dt = DateTime.ParseExact(val, "dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
                            TimeSpan ts = DateTime.Now.Subtract(dt);
                            //val = firstChr + ts.ToString(@"hh\:mm\:ss");
                            val = firstChr + GetJavascriptTimeStamp(dt).ToString();
                        }
                        catch
                        {
                            val = "&nbsp;";
                        }
                    }
                    else if (firstChr == '-')
                    {
                        val = val.Substring(1);
                    }
                }
                else
                {
                    val = "&nbsp;";
                }

            }
            catch (Exception ex)
            {
                AsyncLogger.Error("fixUserData", ex);
            }


            return val;
        }



        // Add Metric Val
        private void addMetricVal(string metricId, string val)
        {
            if (UserData.ContainsKey(metricId))
            {
                UserData[metricId] = fixData(val);
            }
            else
            {
                UserData.Add(metricId, fixData(val));
            }
        }




        // Get User Data
        public void getUserData()
        {
            try
            {
                //if (userId.ToLower() == "twilio2")
                //{
                //    AsyncLogger.Info($"twilio2 DisplayName={DisplayName}");
                //}

                foreach (MetricDef metric in Metrics.Values)
                {
                    string val = metricFunction(metric, Metrics);

                    if (userId.ToLower() == "twilio2")
                    {
                        AsyncLogger.Info($"getUserData metric.ID={metric.ID} metric.Function={metric.Function} val={val}");
                    }

                    addMetricVal(metric.ID, val);
                }

                addMetricVal("USERID", userId);
                addMetricVal("AgentLoginName", DisplayName);

                if (InUse)
                {
                    if (UserViewEvent != null)
                    {
                        UserViewEvent(this, new UserViewEventArgs(userId, UserData));
                    }
                }              
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.getUserData" + ex);
            }
        }




        // Midnight Clear
        public void midnightClear()
        {
            try
            {
                _firstLoggedInStart = DateTime.MinValue;

                _loggedInTotal = TimeSpan.Zero;

                if (!isLoggedId)
                {
                    IsTodayLoggedIn = false;
                }

                _userStatusStart = DateTime.Now;
                _userStatusGroupStart = DateTime.Now;

                _todayUserInteractions.Clear();

                _calls.Clear();
                //ClearInactiveCalls();

                foreach (var key in _TotalStatuses.Keys.ToArray())
                {
                    _TotalStatuses[key].Clear();
                }

                foreach (var key in _userWorkgroupSumList.Keys.ToArray())
                {
                    _userWorkgroupSumList[key].midnightClear();
                }

                YesterdayLog = TodayLog;
                TodayLog = new List<string>();

                IsChanged = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.midnightClear", ex);
            }
        }




        public void ClearInactiveCalls()
        {
            try
            {
                var filteredCalls = new ConcurrentDictionary<Call, DateTime>(_calls.Where(item => item.Key.IdInteraction.IsTalk));

                _calls = filteredCalls;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserManager.ClearInactiveCalls", ex);
            }
        }




        // First Name
        public string FirstName
        {
            get { return _firstName; }
            set
            {
                _firstName = value;
                IsChanged = true;
            }
        }



        // Last Name
        public string LastName
        {
            get { return _lastNAme; }
            set
            {
                _lastNAme = value;
                IsChanged = true;
            }
        }



        // Extension
        public string Extension { get; set; }



        // Display Name
        public string DisplayName
        {
            get { return _displayName; }
            set
            {
                _displayName = value;
                //AsyncLogger.Info("DisplayName for user=" + userId + " is " + _displayName);
                IsChanged = true;
            }
        }



        // User Id
        public string userId
        {
            get { return _userId; }
        }




        // Is Changed
        public bool IsChanged
        {
            get; set;
        }



        // Is LoggedId
        public bool isLoggedId
        {
            get { return _isLoggedIn; }
        }



        // LoggedIn Start
        public DateTime loggedInStart
        {
            get { return _loggedInStart; }
        }



        // First LoggedIn Start
        public DateTime FirstLoggedInStart
        {
            get { return _firstLoggedInStart; }
        }



        // UserStatus
        public string UserStatus
        {
            get { return _userStatus; }
        }



        // Station
        public string Station
        {
            get; set;
        }


        // OnPhone
        public bool OnPhone
        {
            get; set;
        }


        // OnPhoneChanged
        public DateTime OnPhoneChanged
        {
            get; set;
        }



        public IDInteractionBag TodayUserInteractions
        {
            get { return _todayUserInteractions; }
        }


        // Status Name
        public string StatusName
        {
            get { return _statusName; }
        }



        // Time In Status
        public DateTime TimeInStatus
        {
            get { return _userStatusStart; }
        }



        // Time In Status Group
        public DateTime TimeInStatusGroup
        {
            get { return _userStatusGroupStart; }
        }



        // Longest Interaction
        public Call LongestInteraction
        {
            get
            {
                DateTime dt = DateTime.MaxValue;
                Call call = null;

                //if (_calls.Where(c=>c.Key.State == "pending" || c.Key.State == "accepted" || c.Key.State == "wrapping").Any())
                if (_calls.Where(c => c.Key.IdInteraction.IsTalk).Any())
                {
                    foreach (var cl in _calls)
                    {
                        if (cl.Value < dt)
                        {
                            dt = cl.Value;
                            call = cl.Key;
                        }
                    }
                }
                return call;
            }
        }



        // Longest Interaction Duration
        public DateTime LongestInteractionDuration
        {
            get
            {
                DateTime dt = DateTime.MinValue;
                if (_calls.Any())
                {
                    dt = _calls.Min(d => d.Value);
                }
                return dt;
            }
        }

    }
}
