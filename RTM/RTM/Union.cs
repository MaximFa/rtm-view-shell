using ExpressionEvaluator;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.Identity.Client;
using Microsoft.SqlServer.Server;
using RTM.Configuration;
using RTM.Tools;
using RTM.Types;
using System;
using System.Collections.Concurrent;
using System.Text.RegularExpressions;



namespace RTM
{
    public class Union
    {
        public int UnionId { get; set; }

        // Calc quarantine: track consecutive failures per metric to prevent log spam
        private static readonly ConcurrentDictionary<string, int> _calcFailures = new();
        private static readonly ConcurrentDictionary<string, int> _calcCycles = new();
        private const int CalcQuarantineThreshold = 5;

        public ConcurrentDictionary<QueueClassification, Applic> Applics { get; set; } = new ConcurrentDictionary<QueueClassification, Applic>();


        private IDInteractionBag QueueInteractions { get; set; } = new IDInteractionBag();
        private IDInteractionBag UsersInteractions { get; set; } = new IDInteractionBag();


        private ConcurrentDictionary<string, string> InteractionKeys { get; set; } = new ConcurrentDictionary<string, string>();


        public ConcurrentDictionary<string, int> Connections = new ConcurrentDictionary<string, int>();


        public bool InUse { get; set; }


        public  List<string> Queues { get; private set; } = new List<string>(); //  // With ALL Classifications


        public List<UserManager> Users = new List<UserManager>();

        public List<string> Classifications { get; set; } = new List<string>();


        public ConcurrentDictionary<string, Metric> Metrics { get; set; } = new ConcurrentDictionary<string, Metric>();


        private ConcurrentDictionary<string, MetricDef> DataMetrics { get; set; } = new ConcurrentDictionary<string, MetricDef>();


        private ConcurrentDictionary<string, MetricDef> AllDataMetrics { get; set; } = new ConcurrentDictionary<string, MetricDef>();


        public ConcurrentDictionary<int, List<string>> UserGroups { get; set; } = new ConcurrentDictionary<int, List<string>>();


        public List<UserManager> UsersToRemove { get; set; } = new List<UserManager>();



        public ConcurrentDictionary<string, MetricDef> UserGridMetrics { get; set; } = new ConcurrentDictionary<string, MetricDef>();


        public ConcurrentDictionary<int, UserGrid> AgentGrids { get; set; } = new ConcurrentDictionary<int, UserGrid>();



        // TimeZone
        private string _timeZone;
        public string TimeZone 
        {
            get
            {
                return _timeZone;
            }

            set
            {
                _timeZone = value;
                QueueInteractions.TimeZone = _timeZone;
                UsersInteractions.TimeZone = _timeZone;
            }
        }



        // ClearTime
        public TimeSpan ClearTime { get; set; }




        public delegate void UserGridEventHandler(object sender, UserGridEventArgs e);
        public event UserGridEventHandler UserGridEvent;


        public delegate void UserUnionDeactivateEventHandler(object sender, UserUnionActivationEventArgs e);
        public event UserUnionDeactivateEventHandler UserUnionDeactivateEvent;



        // Union
        public Union(int unionId, ConcurrentDictionary<string, MetricDef> allDataMetrics)
        {
            try
            {           
                UnionId = unionId;

                AllDataMetrics = allDataMetrics;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union.Union", ex);
            }
        }




        public void addWorkgroup(string workgroup, ApplicList allApplicList)
        {
            try
            {
                AsyncLogger.Info($"addWorkgroup Union={UnionId} workgroup={workgroup}");

                var queueClassification = new QueueClassification(workgroup, "ALL");

                Applic applic = null;
                if (allApplicList.ContainsKey(queueClassification))
                {
                    applic = allApplicList[queueClassification];
                }
                else
                {
                    applic = new Applic(queueClassification);
                    allApplicList.TryAdd(queueClassification, applic);
                }

                Applics.TryAdd(queueClassification, applic);
            }
            catch(Exception ex) 
            {
                AsyncLogger.Error("Union.addWorkgroup workgroup" + workgroup, ex);
            }
        }




        public void addAllInteractions(List<IDInteraction> interactionsList, ApplicList allApplicList, bool isLog)
        {
            try
            {
                QueueInteractions.Clear();
                UsersInteractions.Clear();

                foreach (var interaction in interactionsList)
                {
                    if (Queues.Contains(interaction.Workgroup) || Classifications.Contains(interaction.ClassificationCode))
                    {
                        var queueClassification = new QueueClassification(interaction.Workgroup, "ALL"); // interaction.ClassificationCode);

                        Applic applic = null;
                        if (allApplicList.ContainsKey(queueClassification))
                        {
                            applic = allApplicList[queueClassification];
                        }
                        else
                        {
                            applic = new Applic(queueClassification);
                            allApplicList.TryAdd(queueClassification, applic);
                        }

                        Applics.TryAdd(queueClassification, applic);
                    }


                    var applicId = new QueueClassification(interaction.Workgroup, "ALL");

                    if (Applics.Keys.Contains(applicId))
                    {
                        QueueInteractions.Add(interaction);
                        InteractionKeys.TryAdd(interaction.Key, string.Empty);

                        if (isLog)
                        {
                            AsyncLogger.Info("addQueueInteraction " + interaction.InteractionId + " Workgroup=" + interaction.Workgroup + " ClassificationCode=" + interaction.ClassificationCode);
                        }
                    }




                    if (Users.Any(u => u.userId == interaction.UserId))
                    {
                        UsersInteractions.Add(interaction);
                        InteractionKeys.TryAdd(interaction.Key, string.Empty);
                    }
                }              
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union.addAllInteractions", ex);
            }

        }




        public void addQueueInteraction(IDInteraction interaction)
        {
            try
            {
                var applicId = new QueueClassification(interaction.Workgroup, "ALL");

                //string allApplics = "{";
                //foreach (var applic in Applics)
                //{
                //    allApplics += applic.Key.QueueId + "/" + applic.Key.ClassificationId + ",";
                //}
                //allApplics += "}";


                //AsyncLogger.Info($"AddQueueInteraction Union={UnionId} applicId={applicId.QueueId}/{applicId.ClassificationId} interactionId={interaction.InteractionId} Applics.Count={Applics.Count} AllApplics={allApplics}");

                if (Applics.Keys.Contains(applicId))
                {
                    //AsyncLogger.Info($"AddQueueInteraction Contains Union={UnionId} interactionId={interaction.InteractionId}");
                    QueueInteractions.Add(interaction);
                    InteractionKeys.TryAdd(interaction.Key, string.Empty);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union.addQueueInteraction", ex);
            }
        }




        public void addUsersInteraction(IDInteraction interaction)
        {
            try
            {
                UsersInteractions.Add(interaction);
                InteractionKeys.TryAdd(interaction.Key, string.Empty);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union.addUsersInteraction", ex);
            }
        }



        public void midnightClear(IDInteractionsList interactionsList)
        {
            try
            { 
                AsyncLogger.Info("midnightClear BU=" + UnionId);

                // Clear inactive interactions and get the removed ones
                var removedFromQueue = QueueInteractions.ClearInactive();
                var removedFromUsers = UsersInteractions.ClearInactive();

                // Combine the removed interactions
                var removedInteractions = removedFromQueue.Concat(removedFromUsers);

                foreach (var interaction in removedInteractions)
                {
                    // Remove from InteractionKeys
                    InteractionKeys.TryRemove(interaction.Key, out _);

                    // Remove from InteractionsList
                    interactionsList.Remove(interaction.Key);
                }

                foreach (var user in Users)
                {
                    user.midnightClear();
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union.midnightClear", ex);
            }
        }



        public void midnightClear2(IDInteractionsList interactionsList)
        {
            try
            {
                AsyncLogger.Info("midnightClear BU=" + UnionId);

                foreach (var key in InteractionKeys.Keys)
                {
                    interactionsList.Remove(key);
                }
                QueueInteractions.ClearInactive();
                UsersInteractions.ClearInactive();
                InteractionKeys = new ConcurrentDictionary<string, string>();

                foreach (var user in Users)
                {
                    user.midnightClear();
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union.midnightClear", ex);
            }
        }



 
    


        public void addDataMetric(MetricDef metric)
        {
            try
            {              
                DataMetrics.TryAdd(metric.ID, metric);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Union.addDataMetric", ex);
            }
        }





        private IDInteractionBag getInteractionBag(string metricType)
        {
            if (metricType == "UsersInteraction")
            {
                return UsersInteractions;
            }
            else
            {
                return QueueInteractions;
            }
        }




        //=================================================================================================================================================


        public List<IDInteraction> getInteractions(MetricDef metric)
        {
            AsyncLogger.Info("Union.getInteractions Union=" + UnionId + " metric=" + metric.ID);
            return metric.InteractionsListFunction(QueueInteractions.Bag);
        }


        //=================================================================================================================================================


        // get NumWaitings
        private string getNumWaitings(MetricDef metric)
        {
            return metric.MetricFunction(QueueInteractions.Bag, Applics.Any());
        }


        // get WaitDurationCurMax
        private string getWaitDurationCurMax(MetricDef metric, bool toSetValue)
        {
            string result = metric.MetricFunction(QueueInteractions.Bag, Applics.Any());
            try {
                AsyncLogger.Info($"MAXWAIT-RECOMPUTE union={UnionId} metric={metric.ID} bagCount={QueueInteractions.Bag.Count} result=[{result}]");
            } catch { }
            string retValue = string.Empty;
            string maxWaitTIme = string.Empty;
            if (toSetValue)
            {
                var arr = result.Split('-');
                retValue = arr[0];
                maxWaitTIme = arr[1];
                Metrics[metric.ID].setValue(retValue, maxWaitTIme);
            }
            return retValue;
        }


        // get AnsweredCount
        private string getAnsweredCount(MetricDef metric)
        {
            return metric.MetricFunction(QueueInteractions.Bag, Applics.Any());           
        }


        // get AbandonedCount
        private string getAbandonedCount(MetricDef metric)
        {
            return metric.MetricFunction(QueueInteractions.Bag, Applics.Any());         
        }


        // get AnsweredPercent
        private string getAnsweredPercent(MetricDef metric)
        {
            return metric.MetricFunction(QueueInteractions.Bag, Applics.Any());           
        }


        // get AbandonedPercent
        private string AbandonedPercent(MetricDef metric)
        {
            return metric.MetricFunction(QueueInteractions.Bag, Applics.Any());
        }


        // get InteractionsCount
        public string getInteractionsCount(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);           
            if (interactionBag.IsEmpty) 
            {
                return "0";
            }
            return metric.MetricFunction(interactionBag.Bag, false);        
        }





        // Get CPH
        public string getCPH(MetricDef metric)
        {
            //AsyncLogger.Info("getCPH Start");
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                //AsyncLogger.Info("getCPH interactionBag.IsEmpty");
                return 0.ToString(metric.Format);
            }
            string callsCount = metric.MetricFunction(interactionBag.Bag, false);
            //AsyncLogger.Info("getCPH callsCount = " + callsCount);

            long totalTicks = 0;
            long nowTicks = DateTime.Now.Ticks;
            int count = Users.Count; // שמירת ה-Count במשתנה כדי לא לגשת לנכס כל איטרציה
            //AsyncLogger.Info("getCPH count = " + count);

            for (int i = 0; i < count; i++)
            {
                if (Users[i].isLoggedId)
                {
                    totalTicks += (nowTicks - Users[i].loggedInStart.Ticks) + Users[i].LoggedInTotal.Ticks;
                }
                //totalTicks += Users[i].LoggedInTotal.Ticks;
            }
            AsyncLogger.Info("getCPH totalTicks = " + totalTicks);

            TimeSpan loggedInTotal = new TimeSpan(totalTicks);

            return CalculateCPH(loggedInTotal, callsCount, metric.Format);
        }



        public string CalculateCPH(TimeSpan loggedInTotal, string callsCountStr, string format)
        {
            //AsyncLogger.Info($"CalculateCPH loggedInTotal={loggedInTotal} callsCountStr={callsCountStr} format={format}");
            // 1. חילוץ מספר השיחות (טיפול ב-NULL או ערך לא חוקי)
            if (string.IsNullOrWhiteSpace(callsCountStr) || !int.TryParse(callsCountStr, out int totalCalls))
            {
                //AsyncLogger.Info("CalculateCPH 1");
                totalCalls = 0;
            }

            // 2. שליפת סך השעות מתוך ה-TimeSpan
            // TotalHours מחזיר את כל הזמן ביחידות של שעות (כולל שברים עשרוניים)
            // דוגמה: שעה וחצי יחזירו 1.5
            double totalHours = loggedInTotal.TotalHours;
            //AsyncLogger.Info("CalculateCPH totalHours = " + totalHours);

            // 3. הגנה מחלוקה באפס
            // אם הנציג טרם צבר זמן עבודה (או שהזמן אפסי/שלילי בגלל באג)
            // נשתמש בערך סף נמוך מאוד (למשל אלפית השעה)
            if (totalHours < 0.001)
            {
                return 0.ToString(format);
            }

            // 4. חישוב המדד
            double cph = totalCalls / totalHours;
            //AsyncLogger.Info("CalculateCPH cph = " + cph);

            // 5. החזרה בפורמט המבוקש
            return cph.ToString(format);
        }






        //=============================================
        // get Messages Count
        public string getMessagesCount(MetricDef metric)
        {
            AsyncLogger.Info($"getMessagesCount UnionId={UnionId}");
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                //AsyncLogger.Info($"getMessagesCount interactionBag.IsEmpty");
                return "0";
            }

            try
            {
                int i = interactionBag.GetChatSummary().TotalMessages;

                //AsyncLogger.Info($"getMessagesCount TotalMessages={i}");
                //int cnt1 = interactionBag.Bag
                //               .Where(m => m.InteractionType == "Chat" && (m.ChatMessages?.Any() ?? false))
                //               .Sum(m => m.ChatMessages.Values.Count(i => i.Direction == "outbound"));
            
                int cnt = interactionBag.Bag
                    .Where(m => m.InteractionType == "Chat" && (m.ChatMessages?.Any() ?? false))
                    .Sum(m => m.ChatMessages.Values.Count(i => i.MsgDirection == "outbound"));

                AsyncLogger.Info($"getMessagesCount TotalMessages={i} outbound={cnt}");
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("getMessagesCount", ex);
            }
            //int cnt = interactionBag.Bag
            //    .Where(m => m.InteractionType == "Chat" && (m.ChatMessages?.Any() ?? false))
            //    .Sum(m => m.ChatMessages?.Values?.Count(i => i.Direction == "outbound") ?? 0);
            var v = metric.MetricFunction(interactionBag.Bag, false);
            AsyncLogger.Info($"getMessagesCount MetricFunction={v}");

            return v;
        }



        public string getMessagesInteractionsCount(MetricDef metric)
        {        
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {               
                return "0";
            }
           
            var v = metric.MetricFunction(interactionBag.Bag, false);

            return v;
        }


        public string getMessagesPercent(MetricDef metric)
        {
            return metric.MetricFunction(QueueInteractions.Bag, Applics.Any());
        }



        public string getMessagesInteractionsPercent(MetricDef metric)
        {
            return metric.MetricFunction(QueueInteractions.Bag, Applics.Any());
        }



        public static string MetricFunction1(ConcurrentBag<IDInteraction> Bag, bool applicAny)
        {

            double maxResponse = 0;
            if (applicAny)
            {
                foreach (var m in Bag
                    .Where(m => m.InteractionType == "Chat"
                             && m.Direction == "Incoming"
                             && m.ChatMessages?.Any() == true))
                {
                    var messages = m.ChatMessages.Values.OrderBy(x => x.TimeStamp).ToList();

                    var firstOut = messages.FirstOrDefault(msg =>
                        msg.MsgDirection == "outbound");

                    if (firstOut != null)
                    {
                        var diff = (firstOut.TimeStamp - m.AnsweredDateTime).TotalSeconds;
                        if (diff > maxResponse)
                        {
                            maxResponse = diff;
                        }
                    }
                }
            }
            TimeSpan tsaSp = new TimeSpan(0, 0, Convert.ToInt32(maxResponse));
            return tsaSp.ToString(@"hh\:mm\:ss"); 
        }


        //public static string MetricFunction(ConcurrentBag<IDInteraction> bag, bool applyAny)
        //{
        //    TimeSpan maxResponse = TimeSpan.Zero;

        //    if (!applyAny)
        //    {              
        //        return maxResponse.ToString(@"hh\:mm\:ss");
        //    }

        //    foreach (var interaction in bag.Where(m =>
        //        m.InteractionType == "Chat" &&
        //        m.Direction == "Incoming" &&
        //        m.ChatMessages != null &&
        //        m.AnsweredDateTime != null))
        //    {             
        //        var firstOutbound = interaction.ChatMessages.Values
        //            .OrderBy(msg => msg.TimeStamp)
        //            .FirstOrDefault(msg => msg.MsgDirection == "outbound");

        //        if (firstOutbound != null && firstOutbound.TimeStamp > interaction.AnsweredDateTime)
        //        {                
        //            var diff = firstOutbound.TimeStamp - interaction.AnsweredDateTime;
        //            AsyncLogger.Info($"firstOutbound.TimeStamp({firstOutbound.TimeStamp}) - interaction.AnsweredDateTime({interaction.AnsweredDateTime}) = diff({diff})");

        //            if (diff > maxResponse)
        //            {
        //                maxResponse = diff;                      
        //            }
        //        }
        //    }

        //    return maxResponse.ToString(@"hh\:mm\:ss");
        //}




        public static string AvgResponseTimeMetric(ConcurrentBag<IDInteraction> bag, bool applyAny)
        {
            if (!applyAny)
            {
                return "00:00:00";
            }

            List<TimeSpan> responseTimes = new();

            foreach (var interaction in bag.Where(i =>
                i.InteractionType == "Chat" &&
                i.Direction == "Incoming" &&
                i.ChatMessages != null))
            {
                var messages = interaction.ChatMessages.Values
                    .OrderBy(m => m.TimeStamp)
                    .ToList();

                int index = 0;

                while (index < messages.Count)
                {
                    var inbound = messages[index];

                    if (inbound.MsgDirection != "inbound")
                    {
                        index++;
                        continue;
                    }

                    // חפש את הודעת הנציג הראשונה שאחריה
                    var response = messages
                        .Skip(index + 1)
                        .FirstOrDefault(m => m.MsgDirection == "outbound");

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
                return "00:00:00";

            var avgSeconds = responseTimes.Average(ts => ts.TotalSeconds);
            var avg = TimeSpan.FromSeconds(avgSeconds);

            return avg.ToString(@"hh\:mm\:ss");
        }





        public string getMessagesMaxFirstResponseTime(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }

            var v = metric.MetricFunction(interactionBag.Bag, Applics.Any());
            //var v = MetricFunction(interactionBag.Bag, Applics.Any());

            return v;
        }


        public string getMessagesAvgFirstResponseTime(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }

            var v = metric.MetricFunction(interactionBag.Bag, Applics.Any());

            return v;
        }


        public string getMessagesAvgResponseTime(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }

            var v = metric.MetricFunction(interactionBag.Bag, Applics.Any());
            //var v = AvgResponseTimeMetric(interactionBag.Bag, Applics.Any());

            return v;
        }



        // get WaitDurationAvg
        public string getWaitDurationAvg(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }
            return metric.MetricFunction(interactionBag.Bag, false);           
        }


        // get WaitDurationMax
        public string getWaitDurationMax(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }
            return metric.MetricFunction(interactionBag.Bag, false);
        }


        // get TalkDurationAvg
        public string getTalkDurationAvg(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }
            return metric.MetricFunction(interactionBag.Bag, false);
        }


        // get TalkDurationTotal
        public string getTalkDurationTotal(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }
            return metric.MetricFunction(interactionBag.Bag, false);
        }



        // get TalkDurationMax
        public string getTalkDurationMax(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }
            return metric.MetricFunction(interactionBag.Bag, false);
        }


        // get TalkDurationCurMax
        public string getTalkDurationCurMax(MetricDef metric)
        {
            var interactionBag = getInteractionBag(metric.DataType);
            if (interactionBag.IsEmpty)
            {
                return "00:00:00";
            }
            return metric.MetricFunction(interactionBag.Bag, false);
        }



        // get LogedInUsersCount
        public string getLogedInUsersCount()
        {
            int numSignon = 0;
            if (Users.Count() > 0)
            {
                numSignon = Users.Count(x => x.isLoggedId);
            }
            return numSignon.ToString();
        }



        // get UsersInStatusCount
        public string getUsersInStatusCount(MetricDef metric)
        {
            int count = 0;
            if (Users.Count() > 0)
            {
                count = Users.Count(t => t.UserStatus == metric.Parameter);
            }
            return count.ToString();        
        }



        // get UsersInStatusGroupCount
        public string getUsersInStatusGroupCount(MetricDef metric)
        {
            int count = 0;
            if (Users.Count() > 0)
            {
                count = Users.Count(t => t.UserStatusGroup == metric.Parameter);
            }
            return count.ToString();
        }




        // get UsersInStatusPercent
        public string getUsersInStatusPercent(MetricDef metric)
        {
            double dCalc = 0;
            if (Users.Count() > 0)
            {
                int numSignon1 = Users.Count(x => x.isLoggedId);
                if (numSignon1 > 0)
                {
                    int count11 = Users.Count(t => t.UserStatus == metric.Parameter);
                    dCalc = (double)count11 / numSignon1;
                }
            }
            return dCalc.ToString(metric.Format); // "#0.##%"
        }


        // get UsersInStatusGroupPercent
        public string getUsersInStatusGroupPercent(MetricDef metric)
        {
            double dCalc = 0;
            if (Users.Count() > 0)
            {
                int numSignong1 = Users.Count(x => x.isLoggedId);
                if (numSignong1 > 0)
                {
                    int count11 = Users.Count(t => t.UserStatusGroup == metric.Parameter);
                    dCalc = (double)count11 / numSignong1;
                }
            }
            return dCalc.ToString(metric.Format); // "#0.##%"
        }



        // get UsersInStatusDurationAvg
        public string getUsersInStatusDurationAvg(MetricDef metric)
        {
            string avg = "00:00:00";
            if (Users.Count() > 0)
            {
                TimeSpan stsDur = TimeSpan.Zero;
                int stsCnt = 0;
                foreach (var user in Users)
                {
                    if (user.TotalStatuses.ContainsKey(metric.Parameter))
                    {
                        var usrStsData = user.TotalStatuses[metric.Parameter];
                        stsDur += usrStsData.Dur;
                        stsCnt += usrStsData.Count;
                    }
                }
                TimeSpan ts = TimeSpan.Zero;
                if (stsCnt > 0)
                {
                    ts = new TimeSpan(stsDur.Ticks / stsCnt);
                    avg = ts.ToString(@"hh\:mm\:ss");
                }
            }
            return avg;
        }



        // Get UsersInStatusGroupDurationAvg
        public string getUsersInStatusGroupDurationAvg(MetricDef metric)
        {
            string avg = "00:00:00";
            if (Users.Count() > 0)
            {
                TimeSpan stsGrpDur = TimeSpan.Zero;
                int stsGrpCnt = 0;
                foreach (var user in Users)
                {
                    foreach (var usd in user.TotalStatuses.Values)
                    {
                        if (usd.StatusGroup == metric.Parameter)
                        {
                            stsGrpDur += usd.Dur;
                            stsGrpCnt += usd.Count;
                        }
                    }
                }
                TimeSpan ts = TimeSpan.Zero;
                if (stsGrpCnt > 0)
                {
                    ts = new TimeSpan(stsGrpDur.Ticks / stsGrpCnt);
                    avg = ts.ToString(@"hh\:mm\:ss");
                }
            }
            return avg;
        }



        // Get UsersInStatusDurationPercent
        public string getUsersInStatusDurationPercent(MetricDef metric)
        {
            double dCalc = 0;
            if (Users.Count() > 0)
            {
                TimeSpan stsDur = new TimeSpan(Users.Sum(t => t.TotalStatuses.Values.Where(x => x.StatusId == metric.Parameter).Sum(r => r.Dur.Ticks)));
                TimeSpan loginDur = new TimeSpan(Users.Sum(t => t.TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks)));
                dCalc = stsDur.TotalSeconds / loginDur.TotalSeconds;
            }
            return dCalc.ToString(metric.Format); // "#0.##%"
        }



        // Get UsersInStatusGroupDurationPercent
        public string getUsersInStatusGroupDurationPercent(MetricDef metric)
        {
            double dCalc = 0;
            if (Users.Count() > 0)
            {
                TimeSpan stsDur = new TimeSpan(Users.Sum(t => t.TotalStatuses.Values.Where(x => x.StatusGroup == metric.Parameter).Sum(r => r.Dur.Ticks)));
                TimeSpan loginDur = new TimeSpan(Users.Sum(t => t.TotalStatuses.Values.Where(x => x.StatusId != "SIGNOFF").Sum(r => r.Dur.Ticks)));
                dCalc = stsDur.TotalSeconds / loginDur.TotalSeconds;
            }
            return dCalc.ToString(metric.Format); // "#0.##%"   
        }



        // Get UsersInStatusDurationCurMax
        public string getUsersInStatusDurationCurMax(MetricDef metric, bool toSetValue)
        {
            string maxStsDur = "00:00:00";
            DateTime minLongestWait = DateTime.MaxValue;

            if (Users.Count() > 0)
            {
                int usetInStsCnt = Users.Count(t => t.UserStatus == metric.Parameter);

                if (usetInStsCnt > 0)
                {
                    minLongestWait = Users.Where(u => u.UserStatus == metric.Parameter).Select(t => t.TimeInStatus).Min();

                    if (minLongestWait < DateTime.MaxValue)
                    {
                        maxStsDur = "+" + minLongestWait.ToString("dd/MM/yyyy HH:mm:ss");
                    }
                }
            }
          
            if (toSetValue)
            {
                Metrics[metric.ID].setValue(maxStsDur, maxStsDur);              
            }
            return maxStsDur;
        }


        // UsersInStatusGroupDurationCurMax
        public string getUsersInStatusGroupDurationCurMax(MetricDef metric, bool toSetValue)
        {
            string maxStsDur = "00:00:00";
            DateTime minLongestWait = DateTime.MaxValue;

            if (Users.Count() > 0)
            {
                int usetInStsCnt = Users.Count(t => t.UserStatusGroup == metric.Parameter);

                if (usetInStsCnt > 0)
                {
                    minLongestWait = Users.Where(u => u.UserStatusGroup == metric.Parameter).Select(t => t.TimeInStatusGroup).Min();

                    if (minLongestWait < DateTime.MaxValue)
                    {
                        maxStsDur = "+" + minLongestWait.ToString("dd/MM/yyyy HH:mm:ss");
                    }
                }
            }

            if (toSetValue)
            {
                Metrics[metric.ID].setValue(maxStsDur, maxStsDur);               
            }
            return maxStsDur;
        }


        // Get UsersInStatusDurationMax
        public string getUsersInStatusDurationMax(MetricDef metric)
        {
            TimeSpan maxStsDur = TimeSpan.Zero;
            if (Users.Count() > 0)
            {
                foreach (var user in Users)
                {
                    if (user.TotalStatuses.ContainsKey(metric.Parameter))
                    {
                        var usrStsData = user.TotalStatuses[metric.Parameter];
                        if (usrStsData.Max > maxStsDur)
                        {
                            maxStsDur = usrStsData.Max;
                        }
                    }
                }
            }
            return DateTime.Now.Subtract(maxStsDur).ToString("dd/MM/yyyy HH:mm:ss");
        }



        // Get UsersInStatusGroupDurationMax
        public string getUsersInStatusGroupDurationMax(MetricDef metric)
        {
            TimeSpan maxStsgrpDur = TimeSpan.Zero;
            if (Users.Count() > 0)
            {
                foreach (var user in Users)
                {
                    foreach (var usd in user.TotalStatuses.Values)
                    {
                        if (usd.StatusGroup == metric.Parameter && usd.Max > maxStsgrpDur)
                        {
                            maxStsgrpDur = usd.Max;
                        }
                    }
                }
            }
            return DateTime.Now.Subtract(maxStsgrpDur).ToString("dd/MM/yyyy HH:mm:ss");
        }



        // Metric Function
        private string metricFunction(MetricDef metric, bool toSetValue)
        {
            string retValue = "";
            string query = string.Empty;
            int calc = 0;
            double dCalc = 0;

            switch (metric.Function)
            {
                case "NumWaitings":
                    retValue = getNumWaitings(metric);
                    break;

                case "WaitDurationCurMax":
                    retValue = getWaitDurationCurMax(metric, toSetValue);
                    toSetValue = false;
                    break;

                // QueueInteractions 
                // =================

                case "AnsweredCount":                  
                    retValue = getAnsweredCount(metric);
                    break;

                case "AbandonedCount":                 
                    retValue = retValue = getAbandonedCount(metric);
                    break;


                case "AnsweredPercent":                   
                    retValue = getAnsweredPercent(metric); 
                    break;


                case "AbandonedPercent":                  
                    retValue = AbandonedPercent(metric);
                    break;


                // QueueInteractions + UsersInteraction 
                // ====================================

                case "InteractionsCount":
                    retValue = getInteractionsCount(metric);
                    break;

                case "CPH":
                    retValue = getCPH(metric);
                    break;

                // Messages
                // ====================================
                case "MessagesCount":
                    retValue = getMessagesCount(metric);
                    break;

                case "MessagesInteractionsCount":
                    retValue = getMessagesInteractionsCount(metric);
                    break;

                case "MessagesPercent":
                    retValue = getMessagesPercent(metric);
                    break;

                case "MessagesInteractionsPercent":
                    retValue = getMessagesInteractionsPercent(metric);
                    break;

                case "MessagesMaxFirstResponseTime":
                    retValue = getMessagesMaxFirstResponseTime(metric);
                    break;

                case "MessagesAvgFirstResponseTime":
                    retValue = getMessagesAvgFirstResponseTime(metric);
                    break;

                case "MessagesAvgResponseTime":
                    retValue = getMessagesAvgResponseTime(metric);
                    break;

                    
                // ====================================


                case "WaitDurationAvg":                
                    retValue = getWaitDurationAvg(metric);
                    break;


                case "WaitDurationMax":                  
                    retValue = getWaitDurationMax(metric);
                    break;


                case "TalkDurationAvg":                  
                    retValue = getTalkDurationAvg(metric);
                    break;


                case "TalkDurationTotal":
                    retValue = getTalkDurationTotal(metric);
                    break;


                case "TalkDurationMax":
                    retValue = getTalkDurationMax(metric);
                    break;


                case "TalkDurationCurMax":
                    retValue = getTalkDurationCurMax(metric);
                    break;


                // UsersSummary
                // ============

                case "LogedInUsersCount":
                    retValue = getLogedInUsersCount();
                    break;


                case "UsersInStatusCount":
                    retValue = getUsersInStatusCount(metric);
                    break;

                case "UsersInStatusGroupCount":
                    retValue = getUsersInStatusGroupCount(metric);
                    break;


                case "UsersInStatusPercent":
                    retValue = getUsersInStatusPercent(metric);
                    break;


                case "UsersInStatusGroupPercent":
                    retValue = getUsersInStatusGroupPercent(metric);
                    break;


                case "UsersInStatusDurationAvg":
                    retValue = getUsersInStatusDurationAvg(metric);
                    break;


                case "UsersInStatusGroupDurationAvg":
                    retValue = getUsersInStatusGroupDurationAvg(metric);
                    break;


                case "UsersInStatusDurationPercent":
                    retValue = getUsersInStatusDurationPercent(metric);
                    break;


                case "UsersInStatusGroupDurationPercent":
                    retValue = getUsersInStatusGroupDurationPercent(metric);
                    break;


                case "UsersInStatusDurationCurMax":
                    retValue = getUsersInStatusDurationCurMax(metric, toSetValue);
                    toSetValue = false;
                    break;


                case "UsersInStatusGroupDurationCurMax":
                    retValue = getUsersInStatusGroupDurationCurMax(metric, toSetValue);
                    toSetValue = false;
                    break;


                case "UsersInStatusDurationMax":
                    retValue = getUsersInStatusDurationMax(metric);
                    break;


                case "UsersInStatusGroupDurationMax":
                    retValue = getUsersInStatusGroupDurationMax(metric);
                    break;


                // Calc
                // ====
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
                    break;
            }


            if (toSetValue)
            {
                Metrics[metric.ID].setValue(retValue);
            }

            return retValue;
        }



        public List<AjaxDictionary<string, string>> ChangedUnionUsersData { get; set; }


        public List<AjaxDictionary<string, string>> getUnionUserData()
        {
            var retList = new List<AjaxDictionary<string, string>>();
        
            foreach (var userMng in Users.ToList())
            {
                retList.Add(userMng.UserData);           
            }

            return retList;
        }



        public bool IsGettingData { get; set; } = false;


        //public bool RemoveUser { get; set; } = false;


        public void getData(List<UserManager> changedUsersData)
        {
            bool isLog = false;

            IsGettingData = true;

            try
            {
                foreach (MetricDef metric in DataMetrics.Values)
                {
                    if (Metrics[metric.ID].Cells.Any(c => c.Value.Grid.InUse))
                    {
                        string errPos = "0";
                        try
                        {
                            metricFunction(metric, true);
                        }
                        catch (Exception ex)
                        {
                            AsyncLogger.Error("Union.getData.Data: " + errPos, ex);
                        }
                    }
                }

                //AsyncLogger.Info("getData bU=" + UnionId + " InUse=" + InUse + " Users.Count=" + Users.Count);
                if (InUse && Users.Count > 0)
                {
                    try
                    {
                        bool isRemoveUsers = false;



                        if (UsersToRemove.Count > 0)
                        {
                            foreach (var user in UsersToRemove)
                            {
                                if (UserUnionDeactivateEvent != null)
                                {
                                    UserUnionDeactivateEvent(this, new UserUnionActivationEventArgs(user.UserData, UnionId));
                                }
                                //Users.Remove(user);
                                isRemoveUsers = true;
                            }

                            UsersToRemove.Clear();
                        }


                        ChangedUnionUsersData = new List<AjaxDictionary<string, string>>();

                        if (isRemoveUsers)
                        {
                            ChangedUnionUsersData = getUnionUserData();
                        }
                        else
                        {
                            foreach (var userMng in changedUsersData)
                            {
                                if (Users.Contains(userMng))
                                {
                                    ChangedUnionUsersData.Add(userMng.UserData);
                                }
                            }
                        }                        
                        

                        if (ChangedUnionUsersData.Count > 0)
                        {
                            AsyncLogger.Info("UserGridEvent UnionId=" + UnionId + " ChangedUnionUsersData.Count=" + ChangedUnionUsersData.Count);
                            if (UserGridEvent != null)
                            {
                                AsyncLogger.Info("UserGridEvent UnionId=" + UnionId + " UserGridEvent != null");
                                UserGridEvent(this, new UserGridEventArgs(UnionId));
                            }
                        }

                    }
                    catch (Exception ex)
                    {
                        AsyncLogger.Error("Union.getData.Users", ex);
                    }
                }
            }
            catch { }


            IsGettingData = false;
        }

    }
}
