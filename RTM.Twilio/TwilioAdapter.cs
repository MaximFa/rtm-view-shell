using log4net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc.Formatters;
using Microsoft.IdentityModel.Tokens;
using Microsoft.VisualBasic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using RTM.Tools;
using RTM.Types;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;
using System.Linq.Expressions;
using System.Runtime.CompilerServices;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using System.Xml.Linq;
using Twilio;
using Twilio.Exceptions;
using Twilio.Rest.FlexApi.V1;
using System.Threading.Channels;

//using Twilio.Rest.Conversations.V1.Service;

//using Twilio.Rest.Conversations.V1;
using Twilio.Rest.Taskrouter.V1.Workspace;
using Twilio.Rest.Taskrouter.V1.Workspace.Task;
using Twilio.TwiML.Voice;
using Interaction = RTM.Types.Interaction;
using Task = System.Threading.Tasks.Task;


namespace RTM.Twilio
{
    public class TwilioAdapter : BackgroundService
    {
        private readonly ILogger<TwilioAdapter> _logger;
        private readonly IConfiguration _configuration;


        // _semaphore
        private static readonly SemaphoreSlim _semaphore = new SemaphoreSlim(1, 1);

        // initInteraction
        private bool initInteraction = true;

        // Agents
        //private ConcurrentDictionary<string, Agent> Agents { get; set; } = new ConcurrentDictionary<string, Agent>();
        private AgentStore Agents { get; set; } = new AgentStore();

        // Interactions
        private ConcurrentDictionary<string, Interaction> Interactions { get; set; } = new ConcurrentDictionary<string, Interaction>();
        private ConcurrentDictionary<string, DateTime> RemovedInteractions { get; set; } = new ConcurrentDictionary<string, DateTime>();


        // StatusGroups
        private Dictionary<string, string[]> StatusGroups { get; set; } = new Dictionary<string, string[]>();

        // StatusNames
        private Dictionary<string, string> StatusNames { get; set; }

        // OnCallAgentStatuses
        private Dictionary<string, string> OnCallAgentStatuses { get; set; } = new Dictionary<string, string>();

        // AvailableGroup
        private string AvailableGroup { get; set; } = "Available";

        // UnavailableGroup
        private string UnavailableGroup { get; set; } = "Unavailable";

        // WorkgroupAttName
        private string WorkgroupAttName { get; set; }


        // AgentStatusIgnoreList
        public List<string> AgentStatusIgnoreList { get; set; } = new();


        // workspaceSid
        private string WorkspaceSid { get; set; }


        // Start Set Interactions
        private bool StartSetInteractions { get; set; } = false;


        private sealed record RtDataQueueItem(string JsonString, string RequestId, DateTime ReceivedUtc);

        private readonly Channel<RtDataQueueItem> _rtDataChannel =
            Channel.CreateBounded<RtDataQueueItem>(new BoundedChannelOptions(10000)
            {
                FullMode = BoundedChannelFullMode.Wait,
                SingleReader = true,
                SingleWriter = false
            });




        // TwilioAdapter
        public TwilioAdapter(ILogger<TwilioAdapter> logger, IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;

            try
            {
                // Set Log
                string logConfig = _configuration.GetValue<string>("RTM:LogConfig");
                AsyncLogger.InitializeLog4Net(logConfig);

                var targets = _configuration.GetSection("RTM:Targets").Get<List<RtmTarget>>();
                if (targets == null || targets.Count == 0)
                {
                    string legacyUrl = _configuration.GetValue<string>("RTM:RTM_URL");   // BACKWARD-COMPAT
                    targets = string.IsNullOrWhiteSpace(legacyUrl)
                        ? new List<RtmTarget>()
                        : new List<RtmTarget> { new RtmTarget { Url = legacyUrl, Pipe = "rtmpipe" } };
                }
                RTMAdapter.ServerConnectEvent += RTMAdapter_ServerConnectEvent;
                _ = RTMAdapter.connect(targets);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("TwilioAdapter", ex);
            }
        }





        // ExecuteAsync
        protected async Task ExecuteAsync1(CancellationToken stoppingToken)
        {
            try
            {
                AsyncLogger.Info("ExecuteAsync Start");

                // Continue to run until the service is stopped
                while (!stoppingToken.IsCancellationRequested)
                {
                    AsyncLogger.Info("StartSetInteractions = " + StartSetInteractions);
                    if (StartSetInteractions)
                    {
                        await setInteractionsAsync(initInteraction);
                     
                        initInteraction = false;
                    }
                    await System.Threading.Tasks.Task.Delay(30000, stoppingToken);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ExecuteAsync", ex);
            }
        }


        //protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        //{
        //    AsyncLogger.Info("ExecuteAsync Start");

        //    var nextCleanupUtc = DateTime.UtcNow;

        //    try
        //    {
        //        while (!stoppingToken.IsCancellationRequested)
        //        {
        //            if (StartSetInteractions)
        //            {
        //                await setInteractionsAsync(initInteraction);
        //                initInteraction = false;
        //            }

        //            var now = DateTime.UtcNow;
        //            if (now >= nextCleanupUtc)
        //            {
        //                CleanupRemoved();
        //                nextCleanupUtc = now.AddMinutes(1);
        //            }

        //            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        //        }
        //    }
        //    catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        //    {
        //        AsyncLogger.Info("ExecuteAsync Stop (canceled)");
        //    }
        //    catch (Exception ex)
        //    {
        //        AsyncLogger.Error("ExecuteAsync", ex);
        //        throw;
        //    }
        //}


        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            AsyncLogger.Info("ExecuteAsync Start");

            var queueTask = ProcessRTDataQueueAsync(stoppingToken);
            var maintenanceTask = RunMaintenanceLoopAsync(stoppingToken);

            await Task.WhenAll(queueTask, maintenanceTask);
        }



        private async Task RunMaintenanceLoopAsync(CancellationToken stoppingToken)
        {
            var nextCleanupUtc = DateTime.UtcNow;

            try
            {
                while (!stoppingToken.IsCancellationRequested)
                {
                    if (StartSetInteractions)
                    {
                        await setInteractionsAsync(initInteraction);
                        initInteraction = false;
                    }

                    var now = DateTime.UtcNow;
                    if (now >= nextCleanupUtc)
                    {
                        CleanupRemoved();
                        nextCleanupUtc = now.AddMinutes(1);
                    }

                    await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                AsyncLogger.Info("RunMaintenanceLoopAsync Stop");
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("RunMaintenanceLoopAsync", ex);
                throw;
            }
        }



        public bool TryQueueRTData(string jsonString, string requestId)
        {
            var item = new RtDataQueueItem(jsonString, requestId, DateTime.UtcNow);

            var queued = _rtDataChannel.Writer.TryWrite(item);

            if (queued)
            {
                AsyncLogger.Info(
                    $"RTData queued RequestId={requestId} BodyLength={jsonString?.Length ?? 0}");
            }
            else
            {
                AsyncLogger.Error(
                    $"RTData queue full RequestId={requestId} BodyLength={jsonString?.Length ?? 0}");
            }

            return queued;
        }



        private async Task ProcessRTDataQueueAsync(CancellationToken stoppingToken)
        {
            AsyncLogger.Info("ProcessRTDataQueueAsync Start");

            try
            {
                await foreach (var item in _rtDataChannel.Reader.ReadAllAsync(stoppingToken))
                {
                    var sw = System.Diagnostics.Stopwatch.StartNew();

                    try
                    {
                        AsyncLogger.Info(
                            $"RTData dequeue RequestId={item.RequestId} QueueDelayMs={(DateTime.UtcNow - item.ReceivedUtc).TotalMilliseconds:0}");

                        await setRTDataAsync(item.JsonString, item.RequestId);

                        sw.Stop();

                        AsyncLogger.Info(
                            $"RTData queue item completed RequestId={item.RequestId} ElapsedMs={sw.ElapsedMilliseconds}");
                    }
                    catch (Exception ex)
                    {
                        sw.Stop();

                        AsyncLogger.Error(
                            $"RTData queue item failed RequestId={item.RequestId} ElapsedMs={sw.ElapsedMilliseconds}",
                            ex);
                    }
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                AsyncLogger.Info("ProcessRTDataQueueAsync Stop");
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ProcessRTDataQueueAsync", ex);
                throw;
            }
        }




        // RTMAdapter Server Connect Event
        private static readonly SemaphoreSlim _snapshotGate = new SemaphoreSlim(1, 1);
        private async void RTMAdapter_ServerConnectEvent(object sender, EventArgs e)
        {
            await _snapshotGate.WaitAsync();
            try
            {
                // Get AppSettings
                string accountSid = _configuration.GetValue<string>("Twilio:AccountSid");
                string authToken = _configuration.GetValue<string>("Twilio:AuthToken");
                WorkspaceSid = _configuration.GetValue<string>("Twilio:WorkspaceSid");
                WorkgroupAttName = _configuration.GetValue<string>("Twilio:WorkgroupAttName");
                AgentStatusIgnoreList = _configuration.GetSection("Twilio:AgentStatusIgnoreList").Get<List<string>>() ?? new List<string>();


                AsyncLogger.Info($"accountSid={accountSid}");

                StatusGroups = _configuration.GetSection("Twilio:StatusGroups").Get<Dictionary<string, string[]>>();
                Dictionary<string, string> defaultStatusGroups = _configuration.GetSection("Twilio:DefaultStatusGroups").Get<Dictionary<string, string>>();

                AvailableGroup = defaultStatusGroups["Available"];
                UnavailableGroup = defaultStatusGroups["Unavailable"];


                StatusNames = _configuration.GetSection("Twilio:StatusNames").Get<Dictionary<string, string>>();


                OnCallAgentStatuses = _configuration.GetSection("Twilio:OnCallAgentStatus").Get<Dictionary<string, string>>();


                // Init Twilio
                TwilioClient.Init(accountSid, authToken);


                // Get Skills
                var config = ConfigurationResource.Fetch();
                var skills = config.TaskrouterSkills;

                var skillNames = new List<string>();

                foreach (JObject skill in skills)
                {
                    var name = skill["name"]?.ToString();

                    if (!string.IsNullOrWhiteSpace(name))
                    {
                        skillNames.Add(name);
                    }
                }

                await RTMAdapter.setSkillsAsync(skillNames);


                // Get Queues
                var taskQueues = TaskQueueResource.Read(
                    pathWorkspaceSid: WorkspaceSid
                );

                List<string> queues = new List<string>();
                foreach (var queue in taskQueues)
                {
                    string queueId = queue.Sid;
                    string queueName = queue.FriendlyName;

                    queues.Add(queueName);
                }

                await RTMAdapter.setWorkgroupsAsync(queues);



                // Get Workers
                var workers = WorkerResource.Read(
                    pathWorkspaceSid: WorkspaceSid
                );


                foreach (var worker in workers)
                {
                    string workerId = worker.Sid;                   
                    bool? isAvailable = worker.Available;
                    DateTime dateStatusChanged = DateTime.Now;  //worker.DateStatusChanged ?? DateTime.MinValue;
                    string workerName = worker.FriendlyName;
                    string workerSid = worker.Sid;
                    var activitySid = worker.ActivitySid;
                    var activityName = worker.ActivityName;
                    string attributesStr = worker.Attributes;
                    var attributes = JsonConvert.DeserializeObject<Dictionary<string, object>>(attributesStr);

                    string fullName = workerName;
                    try
                    {
                        fullName = attributes["full_name"]?.ToString() ?? workerName;
                    }
                    catch { }

                   

                    JToken jsonToken = JToken.Parse(attributesStr);
                    JToken? WorkgroupToken = jsonToken.SelectToken(WorkgroupAttName);

                    List<string> workgroups = new List<string>();

                    try
                    {
                        string workgroupsStr = WorkgroupToken.ToString();
                        workgroups = ConvertJsonToList(workgroupsStr);
                    }
                    catch { }


                    string statusGroup = StatusGroups.FirstOrDefault(sg => sg.Value.Contains(activityName)).Key ?? (isAvailable ?? false ? AvailableGroup : UnavailableGroup);

                    string statusName;


                    bool isActive = true;
                    
                    if (!StatusNames.TryGetValue(activityName, out statusName))
                    {
                        statusName = activityName;
                    }
                    else
                    {
                        activityName = statusName;
                    }

                    isActive = statusName != "Offline";


                    var agent = new Agent()
                    {
                        UserId = workerName,
                        WorkerSid = workerSid,
                        StatusGroup = statusGroup,
                        StatusChanged = dateStatusChanged,
                        DisplayName = fullName,
                        StatusId = statusName,
                        StatusName = statusName,
                        //LoggedIn = activityName != "Offline",
                        LoggedIn = isActive,
                        Workgroups = workgroups,
                        LastName = workerName
                    };
                  
                    Agents.TryAdd(agent);
                }


                // Set Users Status List
                await RTMAdapter.setUsersStatusList(Agents.getList());


                foreach (var agent in Agents.getList())
                {
                    Dictionary<string, string> attributes = new Dictionary<string, string>();
                    await RTMAdapter.userConfigurationChangedAsync(agent.UserId, agent.DisplayName, "0", "", "", attributes);
                    foreach (var workgroup in agent.Workgroups)
                    {                                       
                        await RTMAdapter.userWorkgroupActivationAsync(workgroup, new List<string> { agent.UserId }, new List<string>());
                        AsyncLogger.Info("userWorkgroupActivation agent.UserId=" + agent.UserId + " workgroup=" + workgroup + " DisplayName=" + agent.DisplayName);
                    }
                }


                await FetchAndProcessAllActiveTasksAsync(WorkspaceSid);


                StartSetInteractions = true;
                
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("RTMAdapter_ServerConnectEvent", ex);
            }
            finally { _snapshotGate.Release(); }
        }




        // Fetch And Process All Active Tasks Async
        private async Task FetchAndProcessAllActiveTasksAsync(string workspaceSid)
        {
            // Define Assignment Statuses for Active Tasks
            var activeStatuses = new List<string> { "pending", "reserved", "assigned" };

            // Initialize parameters
            int pageSize = 1000; // Maximum allowed page size

            var options = new ReadTaskOptions(workspaceSid)
            {
                AssignmentStatus = activeStatuses,
                Limit = null, // Fetch all records
                PageSize = pageSize
            };

            // Fetch tasks
            var tasks = TaskResource.Read(options);

            int taskCount = 0;

            // Iterate over all tasks (pagination is handled automatically)
            foreach (var task in tasks)
            {
                await ProcessTaskAsync(task);

                taskCount++;
            }
        }



        // Is Real
        private async Task<bool> IsReal(Interaction interaction)
        {
            string log = string.Empty;
            bool exists = false;

            if (string.IsNullOrEmpty(interaction.InteractionId))
                return false;

            log = $"Check Interaction={interaction.InteractionId} - ";

            try
            {
                // If TaskResource still exists in Twilio, the interaction is real
                var task = TaskResource.Fetch(WorkspaceSid, interaction.InteractionId);
                log += "Found in TaskResource. State=" + task.AssignmentStatus;
                exists = true;
            }
            catch (ApiException ex) when (ex.Status == 404)
            {
                // Task no longer exists in Twilio -> we should clean it on our side
                log += "Not Exists in TaskResource. ";
                log += $" interaction.State={interaction.State} ";

                var closingEvents = new[]
                {
                    "task.canceled",
                    "task.completed",      
                    "task.deleted",
                    "reservation.completed",
                    "reservation.canceled",
                    "reservation.rejected",
                    "reservation.timeout"
                };

                var events = EventResource.Read(
                    pathWorkspaceSid: WorkspaceSid,
                    taskSid: interaction.InteractionId,
                    startDate: DateTime.Today.AddDays(-1));

                var lastEvent = events
                    .Where(e => closingEvents.Contains(e.EventType))
                    .OrderByDescending(e => e.EventDate)
                    .FirstOrDefault();

                DateTime removalTime = DateTime.Now;

                if (lastEvent != null)
                {
                    if (lastEvent.EventDate.HasValue)
                    {
                        removalTime = lastEvent.EventDate.Value.ToLocalTime();
                    }
                 
                    var eventDataJson = lastEvent.EventData?.ToString();

                    if (!string.IsNullOrEmpty(eventDataJson))
                    {
                        log += "Last Event= " + eventDataJson;

                        try
                        {
                            var jsonObject = JObject.Parse(eventDataJson);

                            // Workgroup / queue name
                            var workgroupFromEvent = jsonObject["task_queue_name"]?.ToString();
                            if (!string.IsNullOrEmpty(workgroupFromEvent))
                            {
                                interaction.Workgroup = workgroupFromEvent;
                            }

                            // Assignment status
                            var taskAssignmentStatus =
                                jsonObject["task_assignment_status"]?.ToString() ??
                                jsonObject["task"]?["assignment_status"]?.ToString();

                            if (!string.IsNullOrEmpty(taskAssignmentStatus))
                            {
                                interaction.State = taskAssignmentStatus;
                            }

                            // Callback detection for canceled tasks
                            if (string.Equals(interaction.State, "canceled", StringComparison.OrdinalIgnoreCase))
                            {
                                var taskCanceledReason =
                                    jsonObject["task_canceled_reason"]?.ToString() ??
                                    jsonObject["task"]?["reason"]?.ToString();

                                interaction.IsCallbackRequest = 
                                    string.Equals(taskCanceledReason, "Callback requested", StringComparison.OrdinalIgnoreCase);
                                    //string.Equals(taskCanceledReason, "CallBack Request", StringComparison.OrdinalIgnoreCase);
                            }
                            // Completed tasks: worker name
                            else if (string.Equals(interaction.State, "completed", StringComparison.OrdinalIgnoreCase))
                            {
                                var workerName =
                                    jsonObject["worker_name"]?.ToString() ??
                                    jsonObject["worker"]?["friendly_name"]?.ToString();

                                if (!string.IsNullOrEmpty(workerName))
                                {
                                    interaction.LocalName = workerName;
                                }
                            }
                        }
                        catch (Exception parseEx)
                        {
                            log += $" EventDataParseError={parseEx.Message}";
                            // If parsing fails, we still proceed with cleanup using whatever data we have
                        }
                    }
                }

                // Fallback state if nothing was derived from events
                if (string.IsNullOrEmpty(interaction.State))
                {
                    interaction.State = "canceled";
                }

                int reservationsCount = interaction.Reservations.Count;
                log += $" Reservations={reservationsCount}";
                if (reservationsCount > 0)
                {
                    foreach (var reserv in interaction.Reservations)
                    {
                        int sgmnt = reserv.Value.SegmentId;
                        // Single, final notification about interaction removal
                        await RTMAdapter.interactionRemovedAsync(
                        interaction.Workgroup,
                        interaction.InteractionId,
                        sgmnt,
                        true,
                        interaction.OrigCallId,
                        interaction.LocalName,
                        interaction.State,
                        interaction.TimeInWorkgroupQueue,
                        interaction.IsCallbackRequest,
                        removalTime);
                    }
                }
                else
                {
                    await RTMAdapter.interactionRemovedAsync(
                        interaction.Workgroup,
                        interaction.InteractionId,
                        interaction.SegmentId,
                        true,
                        interaction.OrigCallId,
                        interaction.LocalName,
                        interaction.State,
                        interaction.TimeInWorkgroupQueue,
                        interaction.IsCallbackRequest,
                        removalTime);
                }

                // Remove interaction from in-memory collection
                //Interactions.TryRemove(interaction.InteractionId, out _);
                removeInteraction(interaction.InteractionId);
            }
            catch (ApiException ex)
            {
                // Non-404 API errors: log but do not remove the interaction
                log += $" ApiException: Status={ex.Status}, Code={ex.Code}, Message={ex.Message}";
            }
            catch (Exception ex)
            {
                log += $" Exception: {ex.Message}";
            }

            AsyncLogger.Info(log);
            return exists;
        }



        // Set Interactions
        private async Task setInteractionsAsync(bool initInteractions)
        {
            try
            {
                var now = DateTime.Now;
                var longestInteractions = new List<LongestInteractionResult>();

                var groupedInteractions = Interactions.Values
                    .GroupBy(i => new { i.Workgroup, i.InteractionType, i.Direction, i.State });

                foreach (var group in groupedInteractions)
                {
                    // Filter interactions in the group
                    var eligibleInteractions = group
                        .Where(i => (now - i.TimeStamp).TotalMinutes >= 1) // Older than 1 minute
                        .ToList();

                    // Find interactions due for checking
                    var interactionsToCheck = eligibleInteractions
                        .Where(i => i.NextCheckTime <= now)                // Due for checking
                        .ToList();

                    // Process the longest interaction that is due for checking
                    if (interactionsToCheck.Any())
                    {
                        // Find the longest interaction (earliest TimeStamp)
                        var longestInteractionToCheck = interactionsToCheck
                            .OrderBy(i => i.StateChangedTime)
                            .First();

                        // Perform the IsReal() check
                        bool isReal = await IsReal(longestInteractionToCheck);

                        if (!isReal)
                        {
                            // Remove the interaction from Interactions
                            //Interactions.TryRemove(longestInteractionToCheck.InteractionId, out _);
                            removeInteraction(longestInteractionToCheck.InteractionId);

                            // Remove from eligible interactions
                            eligibleInteractions.Remove(longestInteractionToCheck);
                        }
                        else
                        {
                            // Do not check this interaction for the next 5 minutes
                            longestInteractionToCheck.NextCheckTime = now.AddMinutes(5);
                        }
                    }

                    // Exclude interactions in their 'do not check' period
                    var interactionsForLongest = eligibleInteractions
                        .Where(i => i.NextCheckTime <= now)
                        .ToList();

                    // Find the longest interaction in the group (excluding those in 'do not check' period)
                    if (interactionsForLongest.Any())
                    {
                        var longestInteraction = interactionsForLongest
                            .OrderBy(i => i.TimeStamp)
                            .First();

                        // Add to the list of longest interactions
                        longestInteractions.Add(new LongestInteractionResult
                        {
                            Workgroup = group.Key.Workgroup,
                            InteractionType = group.Key.InteractionType,
                            Direction = group.Key.Direction,
                            State = group.Key.State,
                            LongestInteraction = longestInteraction
                        });
                    }
                }             
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setInteractionsAsync", ex);
            }
        }




        // Convert Json To List
        static List<string> ConvertJsonToList(string json)
        {
            //AsyncLogger.Info($"ConvertJsonToList json={json}");
            try
            {
                // Try to deserialize the JSON as a List<string>
                return JsonConvert.DeserializeObject<List<string>>(json);
            }
            catch (JsonReaderException)
            {
                // If deserialization as a List<string> fails, it might be a single string
                try
                {
                    //var singleValue = JsonConvert.DeserializeObject<string>(json);
                    // Return a list containing just the single string
                    return new List<string> { json };
                }
                catch (JsonReaderException ex)
                {
                    // If it's not a valid JSON string either, handle the error (e.g., log it)
                    //Console.WriteLine($"Invalid JSON: {ex.Message}");
                    return null; // or handle as appropriate
                }
            }
        }



        // Set RT Data 
        //public async Task<bool> setRTDataAsync(string jsonString)
        //{
        //    await _semaphore.WaitAsync();

        //    bool retval = false;

        //    AsyncLogger.Info("setRTDataAsync");           

        //    var data = JArray.Parse(jsonString);

        //    var firstItem = data[0];

        //    await setRTDataAsync(firstItem);


        //    var parsedJson = JsonConvert.DeserializeObject(jsonString);
        //    string nicelyFormattedJson = JsonConvert.SerializeObject(parsedJson, Formatting.Indented);

        //    AsyncLogger.Info(nicelyFormattedJson);


        //    retval = true;

        //    _semaphore.Release();

        //    return retval;
        //}




        private void LogPrettyJsonInBackground(string jsonString, string requestId)
        {
            _ = Task.Run(() =>
            {
                try
                {
                    var parsedJson = JsonConvert.DeserializeObject(jsonString);
                    string nicelyFormattedJson = JsonConvert.SerializeObject(parsedJson, Formatting.Indented);

                    AsyncLogger.Info(
                        $"RTData full JSON RequestId={requestId}{Environment.NewLine}{nicelyFormattedJson}");
                }
                catch (Exception ex)
                {
                    AsyncLogger.Error(
                        $"RTData full JSON logging failed RequestId={requestId}",
                        ex);
                }
            });
        }



        public async Task<bool> setRTDataAsync(string jsonString, string requestId)
        {
            var totalSw = System.Diagnostics.Stopwatch.StartNew();
            var waitSw = System.Diagnostics.Stopwatch.StartNew();

            AsyncLogger.Info($"setRTDataAsync waiting for semaphore RequestId={requestId}");

            await _semaphore.WaitAsync();

            waitSw.Stop();

            AsyncLogger.Info(
                $"setRTDataAsync semaphore entered RequestId={requestId} SemaphoreWaitMs={waitSw.ElapsedMilliseconds}");

            try
            {
                AsyncLogger.Info($"setRTDataAsync started RequestId={requestId}");

                var data = JArray.Parse(jsonString);

                if (data.Count == 0)
                {
                    totalSw.Stop();

                    AsyncLogger.Error(
                        $"setRTDataAsync failed RequestId={requestId} Empty JSON array SemaphoreWaitMs={waitSw.ElapsedMilliseconds} TotalElapsedMs={totalSw.ElapsedMilliseconds}");

                    return false;
                }

                var firstItem = data[0];

                var name = firstItem["data"]?["name"]?.ToString()
                    ?? firstItem["type"]?.ToString()
                    ?? "";

                var taskSid = firstItem["data"]?["payload"]?["task_sid"]?.ToString()
                    ?? firstItem["data"]?["payload"]?["resource_sid"]?.ToString()
                    ?? firstItem["data"]?["payload"]?["sid"]?.ToString()
                    ?? "";

                var eventTimestamp = firstItem["time"]?.ToString()
                    ?? firstItem["data"]?["payload"]?["timestamp"]?.ToString()
                    ?? "";

                AsyncLogger.Info(
                    $"Twilio event received RequestId={requestId} Name={name} TaskSid={taskSid} EventTimestamp={eventTimestamp}");

                await setRTDataAsync(firstItem);

                LogPrettyJsonInBackground(jsonString, requestId);

                totalSw.Stop();

                AsyncLogger.Info(
                    $"setRTDataAsync completed RequestId={requestId} Name={name} TaskSid={taskSid} SemaphoreWaitMs={waitSw.ElapsedMilliseconds} TotalElapsedMs={totalSw.ElapsedMilliseconds}");

                return true;
            }
            catch (Exception ex)
            {
                totalSw.Stop();

                AsyncLogger.Error(
                    $"setRTDataAsync failed RequestId={requestId} BodyLength={jsonString?.Length ?? 0} SemaphoreWaitMs={waitSw.ElapsedMilliseconds} TotalElapsedMs={totalSw.ElapsedMilliseconds}",
                    ex);

                return false;
            }
            finally
            {
                _semaphore.Release();
            }
        }



        public Task<bool> setRTDataAsync(string jsonString)
        {
            return setRTDataAsync(jsonString, Guid.NewGuid().ToString("N"));
        }



        // Set RT Data 
        private async Task setRTDataAsync(JToken data)
        {
            try
            {
                DateTime timestamp = DateTime.Now;

                var name = data["data"]?["name"]?.ToString() ?? data["type"]?.ToString();

                AsyncLogger.Info($"name={name}");


                //  WorkerActivityUpdate Event             
                if (name == "WorkerActivityUpdate" || name == "WorkerAttributesUpdate")
                {
                    await workerUpdateAsync(name, data, timestamp);
                }


                //  Interactions Events              
                else if (name == "TasksCreated" ||
                          name == "TaskQueueEntered" ||
                          name == "TaskQueueMoved" ||
                          name == "TaskUpdated" ||
                          //name == "TaskWrapup" ||
                          name == "TaskCanceled" ||
                          name == "TaskCompleted" ||
                          name == "TaskTransferFailed" ||
                          name == "TaskTransferCanceled" ||
                          name == "ReservationCreated" ||
                          name == "ReservationAccepted" ||
                          name == "ReservationWrapup" ||
                          name == "ReservationCompleted" ||
                          name == "ReservationCanceled" ||
                          name == "ReservationRejected" ||
                          name == "ReservationTimeout")
                {
                    await setInteractionAsync(name, data, timestamp);
                }

                // status-callback.conference.participant.updated
                else if (name == "com.twilio.voice.status-callback.conference.participant.updated")
                {
                    await setHoldAsync(data);
                }
                // Message Events
                else if (name.StartsWith("com.twilio.messaging."))
                {
                    await setMessageEventAsync(data, timestamp);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setRTDataAsync", ex);
            }
        }





        // Set Message Event
        private async Task setMessageEventAsync(JToken data, DateTime timestamp)
        {
            try
            {
                string eventType = data["type"]?.ToString();  // דוג': com.twilio.messaging.inbound-message.received
                var messageData = data["data"];

                string messageId = messageData["messageSid"]?.ToString() ?? messageData["sid"]?.ToString() ?? "";
                string sender = messageData["from"]?.ToString() ?? "unknown";
                string recipient = messageData["to"]?.ToString() ?? "unknown";
                string body = messageData["body"]?.ToString() ?? "";
                string direction = eventType.Contains("inbound") ? "inbound" : "outbound";
                string deliveryStatus = eventType.Split('.').Last();  // לדוגמה: "received", "sent", "read"

                // אין ChannelSid באירוע, אבל ניתן לקשר דרך task או reservation
                string channelSid = "";
                string conversationId = "";
                string taskSid = "";
                string reservationSid = "";

                // ניסיון לשאוב משדות נוספים אם קיימים
                var payload = data["data"]["payload"];
                if (payload != null)
                {
                    channelSid = payload["channelSid"]?.ToString() ?? "";
                    conversationId = payload["conversations"]?["conversation_id"]?.ToString() ?? "";
                    taskSid = payload["task_sid"]?.ToString() ?? "";
                    reservationSid = payload["reservation_sid"]?.ToString() ?? "";
                }

                await RTMAdapter.messageEventReceivedAsync(
                    eventType,
                    messageId,
                    direction,
                    sender,
                    recipient,
                    body,
                    timestamp,
                    deliveryStatus,
                    channelSid,
                    conversationId,
                    taskSid,
                    reservationSid
                );
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setMessageEventAsync", ex);
            }
        }





        // Set Interaction 
        private async Task setInteractionAsync(string name, JToken data, DateTime timestamp)
        {
            try { 
                // Task Events
                bool isTaskEvent = false;
                if (name == "TasksCreated" ||
                name == "TaskQueueEntered" ||
                name == "TaskUpdated" ||
                name == "TaskWrapup" ||
                name == "TaskCanceled" ||
                name == "TaskQueueMoved" ||
                name == "TaskTransferCanceled" ||
                name == "TaskCompleted" ||
                name == "TaskTransferFailed")
                {
                    isTaskEvent = true;
                }


                // InteractionWG
                Interaction interaction;


                // Event TimeSatamp
                DateTime eventTimeSatamp = DateTime.MaxValue;
                string strEventTimeStamp = "";

                //  ============================================================== TimeStamp ==============================================================================
                //var sTimestamp = data["data"]["payload"]["timestamp"]?.ToString();
                var sTimestamp = data["data"]?["payload"]?["timestamp"]?.ToString();

                DateTime eventTimeStampUtc =
                    DateTimeOffset.TryParse(
                        sTimestamp,
                        CultureInfo.InvariantCulture,
                        DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                        out var dto)
                    ? dto.UtcDateTime
                    : DateTime.MinValue;

                try
                {
                    //strEventTimeStamp = data["data"]["payload"]["timestamp"].ToString();
                    strEventTimeStamp = data["data"]?["payload"]?["timestamp"]?.ToString() ?? "";
                    eventTimeSatamp = DateTime.ParseExact(strEventTimeStamp, "MM/dd/yyyy HH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal);
                }
                catch (Exception ex)
                {
                    AsyncLogger.Error("eventTimeSatamp strEventTimeStamp=" + strEventTimeStamp, ex);
                }

                AsyncLogger.Info($"TIMESTAMP eventTimeStampUtc={eventTimeStampUtc} eventTimeSatamp={eventTimeSatamp}");

                // ========================================================================================================================================================


                // reservation Id
                string reservationId = string.Empty;
                if (!isTaskEvent)
                {
                    //reservationId = data["data"]["payload"]["reservation_sid"].ToString();
                    reservationId = data["data"]?["payload"]?["reservation_sid"]?.ToString() ?? string.Empty;
                }


                // Workgroup
                //string workgroup = data["data"]["payload"]["task_queue_name"].ToString();
                string workgroup = data["data"]?["payload"]?["task_queue_name"]?.ToString() ?? "";

                // Interaction Id
                //string interactionId = data["data"]["payload"]["task_sid"].ToString();
                string interactionId = data["data"]?["payload"]?["task_sid"]?.ToString() ?? "";

                if (string.IsNullOrEmpty(interactionId)) return;
                if (string.IsNullOrEmpty(workgroup)) workgroup = "UNKNOWN";

                // Call Type
                string callType = "External";


                // Task Attributess
                //var taskAttributesJson = data["data"]["payload"]["task_attributes"].ToString();
                string taskAttributesJson = data["data"]?["payload"]?["task_attributes"]?.ToString() ?? "{}";


                // Interaction Type (Call/Callback/Chat)
                //string channelName = data["data"]["payload"]["task_channel_unique_name"].ToString();
                string channelName = data["data"]?["payload"]?["task_channel_unique_name"]?.ToString() ?? "";
                string interactionType = string.Empty;
                switch (channelName)
                {
                    case "voice":
                        //if (taskAttributesJson.ToLower().Contains("callback") && !taskAttributesJson.Contains("CallBack Request"))
                        if (taskAttributesJson.ToLower().Contains("callback") && !taskAttributesJson.Contains("Callback requested"))
                        {
                            interactionType = "Callback";
                        }
                        else
                        {
                            interactionType = "Call";
                        }
                        break;
                    case "callback":
                        interactionType = "Callback";
                        break;
                    case "chat":
                        interactionType = "Chat";
                        break;
                    default:
                        interactionType = channelName;
                        break;
                }
                if (string.IsNullOrEmpty(interactionType))
                {
                    AsyncLogger.Info("channelName = " + channelName);
                    return;
                }


                // Direction (Incoming/Outgoing)               
                //JObject taskAttributes = JObject.Parse(taskAttributesJson);

                JObject taskAttributes;
                try
                {
                    taskAttributes = JObject.Parse(string.IsNullOrWhiteSpace(taskAttributesJson) ? "{}" : taskAttributesJson);
                }
                catch
                {
                    taskAttributes = new JObject();
                }


                string direction = (taskAttributes["direction"]?.ToString() == "inbound") ? "Incoming" : "Outgoing";


                string customData20 = taskAttributes["conversation_id"]?.ToString() ?? string.Empty;
                AsyncLogger.Info("customData20 = " + customData20);


                //string remoteAddress = taskAttributes["caller"]?.ToString() ?? string.Empty;
                string remoteAddress = taskAttributes["from"]?.ToString() ?? string.Empty;


                // Worker Name
                string workerName = string.Empty;
                //if (!isTaskEvent)
                //{
                //    workerName = data["data"]["payload"]["worker_name"].ToString();
                //    if (string.IsNullOrEmpty(workerName))
                //    {
                //        workerName = string.Empty;
                 //   }
                //}

                // Worker Sid
                string workerSid = string.Empty;
                //if (!isTaskEvent)
                //{
                //    workerSid = data["data"]["payload"]["worker_sid"].ToString();
                 //   if (string.IsNullOrEmpty(workerSid))
                 //   {
                 //       workerSid = string.Empty;
                 //   }
                //}
               
                if (!isTaskEvent)
                {
                    workerName = data["data"]?["payload"]?["worker_name"]?.ToString() ?? string.Empty;
                    workerSid = data["data"]?["payload"]?["worker_sid"]?.ToString() ?? string.Empty;
                }


                /*string transferMode = string.Empty;
                string transferWorkerId = string.Empty;
                if (!isTaskEvent)
                {
                    transferMode = data["data"]["payload"]["transfer_mode"].ToString();
                    if (string.IsNullOrEmpty(transferMode))
                    {
                        transferWorkerId = data["data"]["payload"]["transfer_initiating_worker_sid"].ToString();
                        if (string.IsNullOrEmpty(transferWorkerId))
                        {
                            transferWorkerId = Agents.GetById(transferWorkerId)?.UserId ?? string.Empty;
                            AsyncLogger.Info($"transferWorkerId = {transferWorkerId})");
                        }
                    }
                }*/


                string transferMode = string.Empty;
                string transferWorkerId = string.Empty;

                if (!isTaskEvent)
                {
                    // שליפה בטוחה – גם אם השדה לא קיים
                    transferMode = data["data"]?["payload"]?["transfer_mode"]?.ToString() ?? string.Empty;

                    // מתייחסים רק להעברה חמה
                    if (string.Equals(transferMode, "WARM", StringComparison.OrdinalIgnoreCase))
                    {
                        var workerSid1 = data["data"]?["payload"]?["transfer_initiating_worker_sid"]?.ToString();

                        if (!string.IsNullOrEmpty(workerSid1))
                        {
                            transferWorkerId = Agents.GetById(workerSid1)?.UserId ?? string.Empty;
                        }

                        AsyncLogger.Info($"transferWorkerId = {transferWorkerId}");
                    }
                }




                // State
                //string state = string.Empty;

                //if (isTaskEvent)
                //{
                //    state = data["data"]["payload"]["task_assignment_status"].ToString();
                //}
                //else
                //{
                //    state = data["data"]["payload"]["reservation_status"].ToString();
                //}

                string state = isTaskEvent
                    ? (data["data"]?["payload"]?["task_assignment_status"]?.ToString() ?? "")
                    : (data["data"]?["payload"]?["reservation_status"]?.ToString() ?? "");

                if (string.IsNullOrEmpty(state)) state = "unknown";


                // Duration
                //TimeSpan duration = TimeSpan.FromSeconds(Convert.ToInt32(data["data"]["payload"]["task_age_in_queue"].ToString()));
                var ageStr = data["data"]?["payload"]?["task_age_in_queue"]?.ToString();
                int age = int.TryParse(ageStr, out var tmp) ? tmp : 0;
                TimeSpan duration = TimeSpan.FromSeconds(age);


                // Interaction Attributes
                bool isDisconnect = false;
                bool isConsult = false;
                string consultCallId = string.Empty;
                string applic = string.Empty;
                string classificationCode = string.Empty;
                string origCallId = string.Empty;
                string customCallData = string.Empty;
                string calculatedStatus = string.Empty;
                string calculatedStatusTime = string.Empty;
                string c4uState = string.Empty;
                List<string> changedAttributeNames = new List<string>();
                bool isHeld = false;
                

                int segmentId = 1;



                // Cencel Interaction
                if (name == "ReservationCompleted" || name == "TaskCanceled" || name == "TaskCompleted" ||
                   (name == "TaskUpdated" && state == "completed") || 
                   (name == "TaskQueueMoved") ||
                   (name == "ReservationCanceled" && transferMode != string.Empty) || 
                   (name == "ReservationRejected" && transferMode != string.Empty) ||
                   (name == "ReservationTimeout" && transferMode != string.Empty) ||
                   (name == "TaskTransferCanceled" || name == "TaskTransferFailed"))  
                   // || name == "ReservationCanceled" || name == "ReservationRejected" || name == "ReservationTimeout") // || newState == "ExternalDisconnect")
                                                                                      //TaskTransferCanceled TaskTransferAttemptFailed
                {
                    if (Interactions.TryGetValue(interactionId, out interaction))
                    {
                        interaction.TimeStamp = eventTimeSatamp;

                        if (name == "ReservationCompleted" || name == "ReservationCanceled" || name == "ReservationRejected" || name == "ReservationTimeout" || name == "TaskTransferCanceled" || name == "TaskTransferFailed")
                        {
                            //segmentId = interaction.SegmentId;
                            //if (reservationId != string.Empty)
                            //{
                            //    if (interaction.Reservations.ContainsKey(reservationId))
                            //    {
                            //        segmentId = interaction.Reservations[reservationId].SegmentId;
                            //    }
                            //}
                            segmentId = interaction.SegmentId;

                            if (reservationId != string.Empty)
                            {
                                if (interaction.Reservations.TryGetValue(reservationId, out var closingReservation))
                                {
                                    if (!closingReservation.IsActive)
                                    {
                                        AsyncLogger.Info(
                                            $"Ignoring inactive reservation close. InteractionId={interactionId}, ReservationId={reservationId}, Event={name}, SegmentId={closingReservation.SegmentId}");

                                        return;
                                    }

                                    segmentId = closingReservation.SegmentId;
                                }
                            }
                            await RTMAdapter.interactionRemovedAsync(workgroup, interactionId, segmentId, true, origCallId, workerName, state, duration, interaction.IsCallbackRequest);

                            foreach (var reservation in interaction.Reservations.Values)
                            {                             
                                if (reservation.SegmentId == segmentId)
                                {                                 
                                    reservation.IsActive = false;
                                }
                            }

                            //var keysToRemove = interaction.Reservations
                            //    .Where(pair => pair.Value.SegmentId == segmentId)
                            //    .Select(pair => pair.Key)
                            //    .ToList(); 

                            //foreach (var key in keysToRemove)
                            //{
                            //    interaction.Reservations.TryRemove(key, out _);
                            //}

                            //if (interaction.Reservations.Count(r=>r.Value.IsActive) == 0)
                            if (!interaction.Reservations.Values.Any(r=>r.IsActive))
                            {
                                //Interactions.TryRemove(interactionId, out _);
                                removeInteraction(interactionId);
                            }
                            else
                            {
                                interaction.SegmentId = interaction.Reservations.IsEmpty ? 0 : interaction.Reservations.Values.Max(r=>r.SegmentId);
                            }
                        }
                        //else if (name == "TaskCanceled")
                        else if (name == "TaskCanceled" || (name == "TaskUpdated" && state == "completed") || state == "TaskCompleted")
                        {
                            if (name == "TaskCanceled")
                            {
                                //string canceledReason = data["data"]["payload"]["task_canceled_reason"].ToString();
                                string canceledReason = data["data"]?["payload"]?["task_canceled_reason"]?.ToString() ?? "";
                                //if (!string.IsNullOrEmpty(canceledReason) && canceledReason == "CallBack Request")
                                if (!string.IsNullOrEmpty(canceledReason) && canceledReason == "Callback requested")
                                {
                                    interaction.IsCallbackRequest = true;
                                }
                            }

                            if (interaction.Reservations.Any()) 
                            { 
                                foreach(var reserv in interaction.Reservations)
                                {
                                    int sgmnt = reserv.Value.SegmentId;
                                    reserv.Value.IsActive = false;
                                    await RTMAdapter.interactionRemovedAsync(workgroup, interactionId, sgmnt, true, origCallId, workerName, state, duration, interaction.IsCallbackRequest);
                                    //Interactions.TryRemove(interactionId, out _);
                                    //removeInteraction(interactionId);
                                }    
                            }
                            else
                            {
                                await RTMAdapter.interactionRemovedAsync(workgroup, interactionId, interaction.SegmentId, true, origCallId, workerName, state, duration, interaction.IsCallbackRequest);
                                //Interactions.TryRemove(interactionId, out _);                            
                            }
                            //if (name != "TaskQueueMoved")
                            //{
                                //await RTMAdapter.interactionRemovedAsync(workgroup, interactionId, interaction.SegmentId, true, origCallId, workerName, state, duration, interaction.IsCallbackRequest);
                                //removeInteraction(interactionId);
                            //}
                        }
                        if (name == "TaskQueueMoved")
                        {
                            try
                            {
                                var task = TaskResource.Fetch(WorkspaceSid, interaction.InteractionId);
                                var assignmentStatus = task.AssignmentStatus;
                                var workgroup1 = task.TaskQueueFriendlyName;
                                //interaction.SegmentId++;
                                int newSegment = interaction.SegmentId + 1;
                                interaction.IsMoved = true;

                                AsyncLogger.Info("TaskQueueMoved " + interaction.InteractionId);

                                //if (!interaction.Reservations.Values.Any(r => r.SegmentId == newSegment))
                                if (interaction.Workgroup != workgroup1)
                                {
                                    await RTMAdapter.interactionRemovedAsync(workgroup, interactionId, interaction.SegmentId, true, origCallId, workerName, state, duration, interaction.IsCallbackRequest);

                                    interaction.Workgroup = workgroup1;


                                    var reservation = interaction.Reservations
                                        .FirstOrDefault(r => r.Value != null && r.Value.SegmentId == interaction.SegmentId)
                                        .Value;

                                    if (reservation != null)
                                    {
                                        reservation.SegmentId = newSegment;
                                        interaction.SegmentId = newSegment;
                                    }                                   

                                    await RTMAdapter.interactionChangedAsync(workgroup1, false, interactionId, newSegment, isDisconnect, callType, interactionType,
                                    direction, assignmentStatus.ToString(), timestamp, duration, duration, isConsult, consultCallId, applic, classificationCode,
                                    workerName, origCallId, customCallData, calculatedStatus, calculatedStatusTime, c4uState, workerName, changedAttributeNames,
                                    isHeld, remoteAddress, interaction.LastMessageSid, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", transferWorkerId, customData20);
                                }
                            }
                            catch { }
                        }
                    }
                    else
                    {
                        removeInteraction(interactionId);
                    }
                }
                else // Add / Update Interaction
                {
                    if (state == "canceled")
                    {
                        return;
                    }

                    if (Interactions.TryGetValue(interactionId, out interaction))
                    {                                                               
                        //if (isTaskEvent && eventTimeSatamp < interaction.TimeStamp)
                        //{
                            //AsyncLogger.Error($"Event for Interaction={interactionId} state={state} '{eventTimeSatamp}'< state={interaction.State} '{interaction.TimeStamp}'");
                            //return;
                        //}
                        //interaction.TimeStamp = eventTimeSatamp;
                        //interaction.TimeStamp = eventTimeStampUtc;                       
                    }
                    else
                    {
                        interaction = new Interaction(interactionId);
                        Interactions.TryAdd(interactionId, interaction);                    
                    }

                    if (isLateEvent(eventTimeSatamp, interactionId))
                    {
                        AsyncLogger.Info($"isLateEvent interactionId={interactionId} eventTimeSatamp={eventTimeSatamp} interaction.TimeStamp={interaction.TimeStamp}");
                        if (state != "accepted" && state != "completed")
                        {
                            return;
                        }
                    }
                    else
                    {
                        interaction.TimeStamp = eventTimeSatamp;
                    }


                    if (reservationId != string.Empty)
                    {                       
                        if (interaction.Reservations.TryGetValue(reservationId, out var reservation) && !reservation.IsActive)
                        {
                            return;
                        }
                    }


                    if (!string.IsNullOrEmpty(taskAttributesJson))
                    {
                        try
                        {
                            var taskAttrObj = JObject.Parse(taskAttributesJson);

                            string mediaSms = taskAttrObj["media_sms"]?.ToString();

                            if (!string.IsNullOrEmpty(mediaSms))
                            {
                                interaction.LastMessageSid = mediaSms;
                            }
                            else
                            {
                                mediaSms = taskAttrObj["from"]?.ToString();

                                if (!string.IsNullOrEmpty(mediaSms))
                                {
                                    interaction.LastMessageSid = mediaSms;
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                        }
                    }



                    if (isTaskEvent && interaction.State == "accepted" && name != "TaskQueueEntered")
                    {
                        return;
                    }



                    if (reservationId != string.Empty)
                    {
                        if (interaction.IsRejected)
                        {
                            interaction.IsRejected = false;

                            segmentId = interaction.SegmentId;
                            interaction.Reservations.TryAdd(reservationId, new Reservation(reservationId, segmentId));
                        }
                        // Reservation Exists
                        else if (interaction.Reservations.ContainsKey(reservationId))
                        {
                            segmentId = interaction.Reservations[reservationId].SegmentId;
                        }
                        //else // New Reservation
                        //{
                        //    if (interaction.IsAnswered)
                        //    {                              
                        //        interaction.IsAnswered = false;
                        //    }

                        //    if (interaction.IsMoved)
                        //    {
                        //        interaction.IsMoved = false;
                        //    }
                        //    else if (interaction.Reservations.Any())
                        //    {
                        //        interaction.SegmentId++;
                        //    }

                        //    segmentId = interaction.SegmentId;
                        //    interaction.Reservations.TryAdd(reservationId, new Reservation(reservationId, segmentId));
                        //}
                        else // New Reservation
                        {
                            if (interaction.IsAnswered)
                            {
                                interaction.IsAnswered = false;
                            }

                            bool wasMoved = interaction.IsMoved;

                            if (wasMoved)
                            {
                                // TaskQueueMoved כבר קידם את הסגמנט.
                                // כאן רק מנקים את הדגל ולא מקדמים שוב.
                                interaction.IsMoved = false;
                            }
                            else if (!string.IsNullOrEmpty(transferMode))
                            {
                                // העברה/התייעצות שלא טופלה דרך TaskQueueMoved
                                interaction.SegmentId++;
                            }

                            segmentId = interaction.SegmentId;

                            // Reservation חדש באותו Segment מחליף את הקודם מבחינת RT.
                            // לא משאירים יותר מ-Reservation פעיל אחד על אותו Segment.
                            foreach (var r in interaction.Reservations.Values
                                .Where(r => r.SegmentId == segmentId))
                            {
                                r.IsActive = false;
                            }

                            interaction.Reservations.TryAdd(
                                reservationId,
                                new Reservation(reservationId, segmentId)
                            );
                        }
                    }
                    else
                    {                     
                        if (interaction.State == state && interaction.Workgroup == workgroup) 
                        {
                            return;
                        }

                        if (interaction.IsAnswered && state == "pending")
                        {
                            return;
                        }

                        //if (!string.IsNullOrWhiteSpace(interaction.Workgroup) && interaction.Workgroup != workgroup)
                        //{
                        //    interaction.SegmentId++;
                        //}

                        segmentId = interaction.SegmentId;
                    }


                    interaction.State = state;
                    if (interaction.State == "accepted")
                    {
                        interaction.IsAnswered = true;
                    }
                    else if (name == "ReservationCanceled" || name == "ReservationRejected" || name == "ReservationTimeout")
                    {
                        interaction.IsAnswered = false;

                        if (name == "ReservationRejected" || name == "ReservationTimeout")
                        {
                            interaction.IsRejected = true;
                            interaction.Reservations.Remove(reservationId, out _);
                            return;
                        }
                    }                


                    await RTMAdapter.interactionChangedAsync(workgroup, false, interactionId, segmentId, isDisconnect, callType, interactionType,
                        direction, state, timestamp, duration, duration, isConsult, consultCallId, applic, classificationCode,
                        workerName, origCallId, customCallData, calculatedStatus, calculatedStatusTime, c4uState, workerName, changedAttributeNames,
                        isHeld, remoteAddress, interaction.LastMessageSid,  "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", transferWorkerId, customData20);


                    interaction.Workgroup = workgroup;
                    interaction.InteractionId = interactionId;
                    interaction.IsDisconnect = isDisconnect;
                    interaction.CallType = callType;
                    interaction.InteractionType = interactionType;
                    interaction.Direction = direction;
                    interaction.State = state;
                    interaction.StateChangedTime = timestamp;
                    interaction.Duration = duration;
                    interaction.TimeInWorkgroupQueue = duration;
                    interaction.IsConsult = isConsult;
                    interaction.ConsultCallId = consultCallId;
                    interaction.Applic = applic;
                    interaction.ClassificationCode = classificationCode;

                    if (!isTaskEvent)
                    {
                        interaction.LocalUserId = workerName;
                    }
                    interaction.OrigCallId = origCallId;
                    interaction.CustomCallData = customCallData;
                    interaction.CalculatedStatus = calculatedStatus;
                    interaction.CalculatedStatusTime = calculatedStatusTime;
                    interaction.C4uState = c4uState;

                    if (string.IsNullOrWhiteSpace(interaction.LocalName))
                    {
                        interaction.LocalName = workerName;
                    }

                    interaction.ChangedAttributeNames = changedAttributeNames;
                    interaction.IsHeld = isHeld;
                    interaction.RemoteAddress = remoteAddress;
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setInteractionAsync", ex);
            }
        }



        // Set Hold
        private async Task setHoldAsync(JToken data)
        {
            try
            {
                var parameters = data["data"]["request"]["parameters"];

                string interactionId = parameters["FriendlyName"].ToString();
                string statusCallbackEvent = parameters["StatusCallbackEvent"].ToString(); //"participant-unhold","participant-hold"
                                                                                           //DateTime timestamp = DateTime.Parse(data["data"]["timestamp"].ToString());
           
                Interaction interaction;
                if (Interactions.TryGetValue(interactionId, out interaction))
                {
                    if (statusCallbackEvent == "participant-hold")
                    {                                          
                        interaction.IsHeld = true;
                    }
                    else if (statusCallbackEvent == "participant-unhold")
                    {
                        if (interaction.IsHeld)
                        {
                            interaction.IsHeld = false;                         
                        }
                        else
                        {
                            return;
                        }
                    }
                    else
                    {
                        return;
                    }


                    await RTMAdapter.interactionChangedAsync(interaction.Workgroup, false, interaction.InteractionId, interaction.SegmentId,
                        interaction.IsDisconnect, interaction.CallType, interaction.InteractionType, interaction.Direction, interaction.State,
                        interaction.StateChangedTime, interaction.Duration, interaction.TimeInWorkgroupQueue, interaction.IsConsult,
                        interaction.ConsultCallId, interaction.Applic, interaction.ClassificationCode, interaction.LocalUserId, interaction.OrigCallId,
                        interaction.CustomCallData, interaction.CalculatedStatus, interaction.CalculatedStatusTime, interaction.C4uState,
                        interaction.LocalName, interaction.ChangedAttributeNames, interaction.IsHeld, interaction.RemoteAddress, interaction.LastMessageSid,
                        "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "");
                  
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("setHoldAsync", ex);
            }     
        }




        // Worker Activity Update 
        private async Task workerUpdateAsync(string eventName, JToken data, DateTime statusChangedTime)
        {
            try
            {
                var workerName = data["data"]["payload"]["worker_name"].ToString();
                var workerSid = data["data"]["payload"]["worker_sid"].ToString();
                var workerAvailable = Convert.ToBoolean(data["data"]["payload"]["worker_available"].ToString());
                var workerActivityName = data["data"]["payload"]["worker_activity_name"].ToString();
                string statusGroup = StatusGroups.FirstOrDefault(sg => sg.Value.Contains(workerActivityName)).Key ?? (workerAvailable ? AvailableGroup : UnavailableGroup);

                //// TimeStamp
                //var sTimestamp = data["data"]["payload"]["timestamp"]?.ToString();

                //if (!DateTimeOffset.TryParse(
                //    sTimestamp,
                //    CultureInfo.InvariantCulture,
                //    DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                //    out var dto))
                //{
                //    AsyncLogger.Info($"Invalid worker timestamp. sTimestamp={sTimestamp}");
                //    return;
                //}

                //DateTime eventTimeStampUtc = dto.UtcDateTime;

                // TimeStamp
                var timestampToken = data["data"]?["payload"]?["timestamp"];

                if (timestampToken == null)
                {
                    AsyncLogger.Info("Invalid worker timestamp. timestampToken=null");
                    return;
                }

                DateTime eventTimeStampUtc;
                string sTimestamp;

                if (timestampToken.Type == JTokenType.Date)
                {
                    var dt = timestampToken.Value<DateTime>();

                    eventTimeStampUtc = dt.Kind switch
                    {
                        DateTimeKind.Utc => dt,
                        DateTimeKind.Local => dt.ToUniversalTime(),
                        _ => DateTime.SpecifyKind(dt, DateTimeKind.Utc)
                    };

                    sTimestamp = eventTimeStampUtc.ToString("O", CultureInfo.InvariantCulture);
                }
                else
                {
                    sTimestamp = timestampToken.ToString();

                    if (!DateTimeOffset.TryParse(
                        sTimestamp,
                        CultureInfo.InvariantCulture,
                        DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                        out var dto))
                    {
                        AsyncLogger.Info($"Invalid worker timestamp. sTimestamp={sTimestamp}");
                        return;
                    }

                    eventTimeStampUtc = dto.UtcDateTime;
                }

                //AsyncLogger.Info(
                //    $"Worker timestamp parsed. " +
                //    $"worker={workerName}, " +
                //    $"activity={workerActivityName}, " +
                //    $"tokenType={timestampToken.Type}, " +
                //    $"tokenValue={timestampToken}, " +
                //    $"eventTimeStampUtc={eventTimeStampUtc.ToString("O", CultureInfo.InvariantCulture)}, " +
                //    $"eventTicks={eventTimeStampUtc.Ticks}");


                // Agent
                Agent agent;


                var workerAttributes = data["data"]["payload"]["worker_attributes"];

                List<string> workgroups = new List<string>();

                string attributesStr = workerAttributes.ToString();
                var attributes = JsonConvert.DeserializeObject<Dictionary<string, object>>(attributesStr);

                try
                {
                    JToken jsonToken = JToken.Parse(attributesStr);
                    JToken? WorkgroupToken = jsonToken.SelectToken(WorkgroupAttName);
                    //AsyncLogger.Info($"attributesStr={attributesStr}{Environment.NewLine}jsonToken={jsonToken.ToString()}{Environment.NewLine}");

                    string workgroupStr = WorkgroupToken.ToString();
                    workgroups = ConvertJsonToList(workgroupStr);
                }
                catch (Exception ex)
                {
                    AsyncLogger.Error("setRTDataAsync.WorkgroupToken", ex);
                }


                // If workerName dosn't exists in Agenst list
                agent = Agents.GetByName(workerName);

                if (agent == null)
                {                   
                    string fullName = workerName;
                    try
                    {
                        fullName = attributes["full_name"].ToString();
                    }
                    catch { }


                    agent = new Agent()
                    {
                        UserId = workerName,
                        WorkerSid = workerSid,
                        DisplayName = fullName,
                        Workgroups = workgroups,
                        LastName = workerName
                    };
                    Agents.TryAdd(agent);

                    
                    await RTMAdapter.userConfigurationChangedAsync(agent.UserId, agent.DisplayName, "0", "", "", new Dictionary<string, string>());

                    foreach (var workgroup in workgroups)
                    {
                        await RTMAdapter.userWorkgroupActivationAsync(workgroup, new List<string> { workerName }, new List<string>());
                        AsyncLogger.Info("userWorkgroupActivation agent.UserId=" + agent.UserId + " workgroup=" + workgroup);
                    }                   
                }
                else
                {
                    var existingWorkgroups = agent.Workgroups;

                    // Find workgroups to activate and deactivate
                    var workgroupsToActivate = workgroups.Except(existingWorkgroups).ToList();
                    var workgroupsToDeactivate = existingWorkgroups.Except(workgroups).ToList();

                    // Update agent's workgroups in the dictionary
                    agent.Workgroups = workgroups;

                    // Batch activate/deactivate workgroups
                    if (workgroupsToActivate.Any())
                    {
                        foreach (var workgroup in workgroupsToActivate)
                        {
                            await RTMAdapter.userWorkgroupActivationAsync(workgroup, new List<string> { agent.UserId }, new List<string>());
                        }
                    }

                    if (workgroupsToDeactivate.Any())
                    {
                        foreach (var workgroup in workgroupsToDeactivate)
                        {
                            await RTMAdapter.userWorkgroupActivationAsync(workgroup, new List<string>(), new List<string> { agent.UserId });
                        }
                    }
                }

           

                if (eventName == "WorkerActivityUpdate")
                {
                    if (AgentStatusIgnoreList.Contains(workerActivityName))
                    {
                        return;
                    }


                    if (eventTimeStampUtc == DateTime.MinValue)
                    {
                        AsyncLogger.Info($"Invalid worker timestamp. sTimestamp={sTimestamp}");
                        return;
                    }

                    if (eventTimeStampUtc <= agent.TimeStamp)
                    {
                        AsyncLogger.Info(
                            $"Skipping old worker event. " +
                            $"sTimestamp={sTimestamp}, " +
                            $"eventTimeStampUtc={eventTimeStampUtc.ToString("O", CultureInfo.InvariantCulture)}, " +
                            $"agent.TimeStamp={agent.TimeStamp.ToString("O", CultureInfo.InvariantCulture)}, " +
                            $"eventTicks={eventTimeStampUtc.Ticks}, " +
                            $"agentTicks={agent.TimeStamp.Ticks}");

                        return;
                    }

                    agent.TimeStamp = eventTimeStampUtc;


                    if (!agent.LoggedIn)
                    {
                        agent.LastStatus = "Offline";
                        agent.LastStatusGroup = UnavailableGroup;
                        agent.OnPhone = false;
                    }

                    bool isActive = true; // workerActivityName != "Offline";

                    if (agent.OnPhone)
                    {
                        agent.LastStatus = workerActivityName;
                        agent.LastStatusGroup = statusGroup;
                    }
                    else
                    {
                        string statusName;
                        agent.StatusId = workerActivityName;

                        if (!StatusNames.TryGetValue(agent.StatusId, out statusName))
                        {
                            statusName = agent.StatusId;
                        }
                        else
                        {
                            agent.StatusId = statusName;
                        }
                        agent.StatusName = statusName;

                        isActive = statusName != "Offline";

                        await userStatusChangedAsync(workerName,
                            isActive, agent.StatusId, agent.StatusName,
                           statusGroup, statusChangedTime, "", false, DateTime.MinValue);

                        agent.StatusGroup = statusGroup;
                    }

                    agent.UserId = workerName;
                    agent.StatusChanged = statusChangedTime;
                    agent.LoggedIn = isActive;
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("workerActivityUpdateAsync", ex);
            }
        }




        // User Status Changed
        public async Task userStatusChangedAsync(string userId, bool loggedIn, string statusId, string statusName, string statusGroup, DateTime statusChanged, string station, bool onPhone, DateTime onPhoneChanged)
        {
            try
            {
                if (statusId == "Offline")
                {
                    loggedIn = false;
                }

                if (statusId != "Wrapup")
                {
                    await RTMAdapter.userStatusChangedAsync(userId, loggedIn, statusId, statusName, statusGroup, statusChanged, station, onPhone, onPhoneChanged);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("userStatusChangedAsync", ex);
            }
        }





        // ProcessTaskAsync
        private async Task ProcessTaskAsync(TaskResource task)
        {
            try
            {
                // Extract necessary information from the task
                string interactionId = task.Sid;
                string workgroup = task.TaskQueueFriendlyName;
                string state = task.AssignmentStatus.ToString();
                DateTime timestamp = task.DateCreated ?? DateTime.UtcNow;

                // Call Type
                string callType = "External";

                // Task Attributes
                var taskAttributesJson = task.Attributes;
                JObject taskAttributes = JObject.Parse(taskAttributesJson);

                // Interaction Type (Call/Callback/Chat)
                string channelName = task.TaskChannelUniqueName;
                string interactionType = string.Empty;
                switch (channelName)
                {
                    case "voice":
                        //if (taskAttributesJson.ToLower().Contains("callback") && !taskAttributesJson.Contains("CallBack Request"))
                        if (taskAttributesJson.ToLower().Contains("callback") && !taskAttributesJson.Contains("Callback requested"))
                        {
                            interactionType = "Callback";
                        }
                        else
                        {
                            interactionType = "Call";
                        }
                        break;
                    case "callback":
                        interactionType = "Callback";
                        break;
                    case "chat":
                        interactionType = "Chat";
                        break;
                    default:
                        interactionType = channelName;
                        break;
                }
                if (string.IsNullOrEmpty(interactionType))
                {
                    AsyncLogger.Info("channelName = " + channelName);
                    return;
                }

                // Direction (Incoming/Outgoing)
                string direction = (taskAttributes["direction"]?.ToString() == "inbound") ? "Incoming" : "Outgoing";

                string customData20 = taskAttributes["conversation_id"]?.ToString() ?? string.Empty;
                //AsyncLogger.Info("customData20 = " + customData20);

                //string remoteAddress = taskAttributes["caller"]?.ToString() ?? string.Empty;
                string remoteAddress = taskAttributes["from"]?.ToString() ?? string.Empty;


                // Worker Name
                string workerName = string.Empty;


                if (state == "assigned")
                {
                    // Worker Full Name
                    string workerFullName = taskAttributes["worker_full_name"]?.ToString() ?? string.Empty;


                    if (!string.IsNullOrEmpty(workerFullName))
                    {
                        // Find the agent in the Agents dictionary where DisplayName matches workerFullName
                        var agent = Agents.getList().FirstOrDefault(a => a.DisplayName == workerFullName);

                        if (agent != null)
                        {
                            workerName = agent.UserId;
                        }
                        else
                        {
                            AsyncLogger.Error($"Agent with full name '{workerFullName}' not found in Agents dictionary.");
                        }
                    }
                    else
                    {
                        AsyncLogger.Error($"'worker_full_name' not found in task attributes for task {task.Sid}");
                    }
                }


                // Duration
                TimeSpan duration = TimeSpan.FromSeconds(task.Age ?? 0);

                // Interaction Attributes
                bool isDisconnect = false;
                bool isConsult = false;
                string consultCallId = string.Empty;
                string applic = string.Empty;
                string classificationCode = string.Empty;
                string origCallId = string.Empty;
                string customCallData = string.Empty;
                string calculatedStatus = string.Empty;
                string calculatedStatusTime = string.Empty;
                string c4uState = string.Empty;
                List<string> changedAttributeNames = new List<string>();
                bool isHeld = false;

                int segmentId = 1;

                // Create or Update Interaction in Interactions Dictionary
                Interaction interaction;

                if (Interactions.TryGetValue(interactionId, out interaction))
                {
                    // Update existing interaction
                    interaction.TimeStamp = timestamp;
                }
                else
                {
                    // Create new interaction
                    interaction = new Interaction(interactionId);
                    Interactions.TryAdd(interactionId, interaction);
                }

                // Update interaction properties
                interaction.Workgroup = workgroup;
                interaction.InteractionId = interactionId;
                interaction.IsDisconnect = isDisconnect;
                interaction.CallType = callType;
                interaction.InteractionType = interactionType;
                interaction.Direction = direction;
                interaction.State = state;
                interaction.StateChangedTime = timestamp;
                interaction.Duration = duration;
                interaction.TimeInWorkgroupQueue = duration;
                interaction.IsConsult = isConsult;
                interaction.ConsultCallId = consultCallId;
                interaction.Applic = applic;
                interaction.ClassificationCode = classificationCode;
                interaction.LocalUserId = workerName;
                interaction.OrigCallId = origCallId;
                interaction.CustomCallData = customCallData;
                interaction.CalculatedStatus = calculatedStatus;
                interaction.CalculatedStatusTime = calculatedStatusTime;
                interaction.C4uState = c4uState;
                interaction.LocalName = workerName;
                interaction.ChangedAttributeNames = changedAttributeNames;
                interaction.IsHeld = isHeld;
                interaction.RemoteAddress = remoteAddress;

                // Call RTMAdapter.interactionChangedAsync()
                await RTMAdapter.interactionChangedAsync(
                    workgroup,
                    false,
                    interactionId,
                    segmentId,
                    isDisconnect,
                    callType,
                    interactionType,
                    direction,
                    state,
                    timestamp,
                    duration,
                    duration,
                    isConsult,
                    consultCallId,
                    applic,
                    classificationCode,
                    workerName,
                    origCallId,
                    customCallData,
                    calculatedStatus,
                    calculatedStatusTime,
                    c4uState,
                    workerName,
                    changedAttributeNames,
                    isHeld,
                    remoteAddress, interaction.LastMessageSid,
                    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", customData20
                );
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ProcessTaskAsync", ex);
            }
        }




        private void removeInteraction(string interationId)
        {
            Interaction interaction;

            RemovedInteractions.TryAdd(interationId, DateTime.Now);

            if (Interactions.TryGetValue(interationId, out interaction))
            {             
                Interactions.TryRemove(interationId, out _);
            }
        }



        private bool isLateEvent(DateTime eventTimestamp, // new timeStamp
            string interactionId) // before set timeStamp
        {
            // If removed exists, compare against removal timestamp
            if (RemovedInteractions.TryGetValue(interactionId, out _))
            {
                AsyncLogger.Info($"isLateEvent RemovedInteractions interactionId={interactionId} eventTimestamp={eventTimestamp}");
                //return eventTimestamp <= marker.TimeStamp; // <= makes sense: removal wins ties
                return true;
            }

            // If live exists, compare against live last-known timestamp
            if (Interactions.TryGetValue(interactionId, out var live))
            {
                return eventTimestamp < live.TimeStamp;
            }

            

            // Unknown id: not late (you can choose to treat as late if you want stricter behavior)
            return false;
        }



        //private readonly TimeSpan RemovedTtl = TimeSpan.FromMinutes(5);
        private readonly TimeSpan RemovedTtl = TimeSpan.FromDays(1);



        private void CleanupRemoved()
        {
            var now = DateTime.UtcNow;
            foreach (var kvp in RemovedInteractions)
            {
                if (now - kvp.Value > RemovedTtl)
                    RemovedInteractions.TryRemove(kvp.Key, out _);
            }
        }
    }
}

