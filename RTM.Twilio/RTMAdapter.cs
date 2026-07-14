using RTM.Tools;
using RTM.Types;
using Newtonsoft.Json;
using Formatting = Newtonsoft.Json.Formatting;
using System.Text;
using System.Threading;

namespace RTM.Twilio
{
    public class RTMAdapter
    {
        private static HttpClient HttpClient;                                       // shared, reused across URLs
        private static IReadOnlyList<RtmTarget> Targets = Array.Empty<RtmTarget>();  // set once in connect()
        private static CancellationTokenSource _cts;                                 // supervisor clean stop


        // Msg ID
        private static long msgId = 1;
        private static readonly object msgIdLock = new object();
        public static long MsgId
        {
            get
            {
                lock (msgIdLock)
                {
                    return msgId++;
                }
            }
        }




        public delegate void ServerConnectEventHandler(object sender, EventArgs e);
        public static event ServerConnectEventHandler ServerConnectEvent;


        // Event args subclass for target-aware connect event
        public sealed class RtmTargetConnectedEventArgs : EventArgs
        {
            public RtmTarget Target { get; }
            public RtmTargetConnectedEventArgs(RtmTarget target) => Target = target;
        }


        public static async Task connect(IReadOnlyList<RtmTarget> targets)
        {
            try
            {
                _cts?.Cancel();
                _cts = new CancellationTokenSource();
                Targets = targets;
                var h = new HttpClientHandler();
                h.ServerCertificateCustomValidationCallback = (s, c, ch, e) => true;
                HttpClient = new HttpClient(h);
                // Launch one supervisor per target (fire-and-forget; each loops until cancelled)
                foreach (var t in Targets)
                    _ = SuperviseAsync(t, _cts.Token);
                await Task.CompletedTask;
            }
            catch (Exception ex) { AsyncLogger.Error("RTMAdapter.connect", ex); }
        }

        public static void Stop()
        {
            _cts?.Cancel();
        }


        private static async Task SuperviseAsync(RtmTarget target, CancellationToken ct)
        {
            while (!ct.IsCancellationRequested)
            {
                try
                {
                    await ConnectAndReadAsync(target, ct);
                }
                catch (OperationCanceledException) { break; }
                catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.SuperviseAsync pipe={target.Pipe}", ex); }
                if (ct.IsCancellationRequested) break;
                AsyncLogger.Info($"CLIENT[{target.Pipe}] => disconnected; reconnecting in {target.Backoff.TotalSeconds:0}s");
                try { await Task.Delay(target.Backoff, ct); } catch (OperationCanceledException) { break; }
                target.Backoff = TimeSpan.FromSeconds(Math.Min(target.Backoff.TotalSeconds * 2, 30));
            }
            AsyncLogger.Info($"CLIENT[{target.Pipe}] => supervisor stopped.");
        }

        private static async Task ConnectAndReadAsync(RtmTarget target, CancellationToken ct)
        {
            ct.ThrowIfCancellationRequested();
            var pipe = new NamedPipeClient(target.Pipe);
            target.Client = pipe;
            pipe.ClientStarted     += (_, __) => AsyncLogger.Info($"CLIENT[{target.Pipe}] => started.");
            pipe.ConnectedToServer += (_, __) => Client_ConnectedToServer(target);
            pipe.MessageReceived   += (_, a)  => AsyncLogger.Info($"CLIENT[{target.Pipe}] => msg: {(a as MessageReceivedEventArgs)?.Message}");
            pipe.Disconnected      += (_, __) => AsyncLogger.Info($"CLIENT[{target.Pipe}] => disconnected.");
            await pipe.Connect(ct);
        }


        private static void Client_ConnectedToServer(RtmTarget target)
        {
            target.Backoff = TimeSpan.FromSeconds(1);   // reset backoff on successful connect
            AsyncLogger.Info($"CLIENT[{target.Pipe}] => connected to server.");
            ServerConnectEvent?.Invoke(null, new RtmTargetConnectedEventArgs(target));
        }


        // Pipe fan-out helper (optional single-target for connect snapshot)
        private static async Task SendToAllAsync(string jsonData, RtmTarget only = null)
        {
            if (only != null)
            {
                try { if (only.Client != null) await only.Client.Send(jsonData); }
                catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.SendToAllAsync pipe={only.Pipe}", ex); }
                return;
            }
            var targets = Targets;
            await Task.WhenAll(targets.Select(async t =>
            {
                try { if (t.Client != null) await t.Client.Send(jsonData); }
                catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.SendToAllAsync pipe={t.Pipe}", ex); }
            }));
        }


        // REST fan-out helper (optional single-target for connect snapshot)
        private static async Task<bool> PostToAllAsync(string endpoint, string data, RtmTarget only = null)
        {
            if (only != null)
            {
                try
                {
                    var content = new StringContent(data);
                    var response = await HttpClient.PostAsync(only.Url + endpoint, content);
                    string body = await response.Content.ReadAsStringAsync();
                    AsyncLogger.Info($"POST {endpoint} -> {only.Url} response={body}");
                    return response.IsSuccessStatusCode;
                }
                catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.PostToAllAsync url={only.Url}{endpoint}", ex); return false; }
            }
            var targets = Targets;
            var results = await Task.WhenAll(targets.Select(async t =>
            {
                try
                {
                    var content = new StringContent(data);   // per-target; cannot reuse one HttpContent
                    var response = await HttpClient.PostAsync(t.Url + endpoint, content);
                    string body = await response.Content.ReadAsStringAsync();
                    AsyncLogger.Info($"POST {endpoint} -> {t.Url} response={body}");
                    return response.IsSuccessStatusCode;
                }
                catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.PostToAllAsync url={t.Url}{endpoint}", ex); return false; }
            }));
            return results.Length > 0 && results.All(r => r);
        }




        // setUsersStatusList (optional single-target for connect snapshot)
        public static async Task<bool> setUsersStatusList(List<Agent> usersStatusList, RtmTarget only = null)
        {
            try
            {
                string data = JsonConvert.SerializeObject(usersStatusList, Formatting.Indented);
                return await PostToAllAsync("/SetUsersStatusList", data, only);
            }
            catch (Exception ex) { AsyncLogger.Error("RTMAdapter.setUsersStatusList", ex); return false; }
        }




        // Set Statistic
        public static async Task setStatisticAsync(string statisticKey, string value)
        {
            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "setStatistic");
                data.Add("statisticKey", statisticKey);
                data.Add("value", value);
                data.Add("messageId", messageId);
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.setStatisticAsync {info}", ex);
            }
        }



        // User Status Changed
        public static async Task userStatusChangedAsync(string userId, bool loggedIn, string statusId, string statusName, string statusGroup, DateTime statusChanged, string station, bool onPhone, DateTime onPhoneChanged)
        {
            AsyncLogger.Info($"<<< RTMAdapter.userStatusChangedAsync >>> userId={userId} statusId={statusId} statusGroup={statusGroup} statusChanged={statusChanged}");

            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "userStatusChanged");
                data.Add("userId", userId);
                data.Add("loggedIn", loggedIn);
                data.Add("statusId", statusId);
                data.Add("statusName", statusName);
                data.Add("statusGroup", statusGroup);
                data.Add("statusChanged", statusChanged);
                data.Add("station", station);
                data.Add("onPhone", onPhone);
                data.Add("onPhoneChanged", onPhoneChanged);
                data.Add("messageId", messageId.ToString());
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.userStatusChangedAsync {info}", ex);
            }
        }




        // User Workgroup Activation (optional single-target for connect snapshot)
        public static async Task userWorkgroupActivationAsync(string workgroup, List<string> activeUsersList, List<string> deactiveUsersList, RtmTarget only = null)
        {
            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "userWorkgroupActivation");
                data.Add("workgroup", workgroup);
                data.Add("activeUsersList", activeUsersList);
                data.Add("deactiveUsersList", deactiveUsersList);
                data.Add("messageId", messageId);
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData, only);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.userWorkgroupActivationAsync {info}", ex);
            }
        }




        // userConfigurationChanged (optional single-target for connect snapshot)
        public static async Task userConfigurationChangedAsync(string userId, string displayName, string extension, string firstName, string LastName, IDictionary<string, string> customAttributes, RtmTarget only = null)
        {
            AsyncLogger.Info($"userConfigurationChangedAsync userId={userId} displayName={displayName}");

            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "userConfigurationChanged");
                data.Add("userId", userId);
                data.Add("displayName", displayName);
                data.Add("extension", extension);
                data.Add("firstName", firstName ?? displayName);
                data.Add("LastName", LastName ?? string.Empty);
                data.Add("customAttributes", customAttributes);
                data.Add("messageId", messageId);
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData, only);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.userConfigurationChangedAsync {info}", ex);
            }
        }


        // Interaction Changed (optional single-target for connect snapshot)
        public static async Task interactionChangedAsync(string workgroup, bool isAdded, string interactionId, int segmentId,
           bool isDisconnect, string callType, string interactionType, string direction, string state, DateTime stateChangedTime,
           TimeSpan duration, TimeSpan timeInWorkgroupQueue, bool isConsult, string consultCallId, string applic, string classificationCode, string localUserId, string origCallId,
           string customCallData, string calculatedStatus, string calculatedStatusTime, string c4uState, string localName, List<string> changedAttributeNames, bool isHeld, string remoteAddress, string lastMessageSid,
           string customCallData1, string customCallData2, string customCallData3, string customCallData4, string customCallData5, string customCallData6,
           string customCallData7, string customCallData8, string customCallData9, string customCallData10, string customCallData11, string customCallData12,
           string customCallData13, string customCallData14, string customCallData15, string customCallData16, string customCallData17, string customCallData18,
           string customCallData19, string customCallData20, RtmTarget only = null)
        {
            AsyncLogger.Info($"<<< interactionChanged >>> workgroup={workgroup} isAdded={isAdded} interactionId={interactionId} segmentId={segmentId} " +
                $"state={state} callType={callType} direction={direction} " +
                $"isDisconnect={isDisconnect} localUserId={localUserId} isHeld={isHeld} remoteAddress={remoteAddress} lastMessageSid={lastMessageSid}");
            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "interactionChanged");
                data.Add("workgroup", workgroup);
                data.Add("isAdded", isAdded);
                data.Add("interactionId", interactionId);
                data.Add("segmentId", segmentId);
                data.Add("isDisconnect", isDisconnect);
                data.Add("callType", callType);
                data.Add("interactionType", interactionType);
                data.Add("direction", direction);
                data.Add("state", state);
                data.Add("stateChangedTime", stateChangedTime);
                data.Add("duration", duration);
                data.Add("timeInWorkgroupQueue", timeInWorkgroupQueue);
                data.Add("isConsult", isConsult);
                data.Add("consultCallId", consultCallId);
                data.Add("applic", applic);
                data.Add("classificationCode", classificationCode);
                data.Add("localUserId", localUserId);
                data.Add("origCallId", origCallId);
                data.Add("customCallData", customCallData);
                data.Add("calculatedStatus", calculatedStatus);
                data.Add("calculatedStatusTime", calculatedStatusTime);
                data.Add("c4uState", c4uState);
                data.Add("localName", localName);
                data.Add("changedAttributeNames", changedAttributeNames);
                data.Add("isHeld", isHeld);
                data.Add("remoteAddress", remoteAddress);
                data.Add("lastMessageSid", lastMessageSid);

                data.Add("customCallData1", customCallData1);
                data.Add("customCallData2", customCallData2);
                data.Add("customCallData3", customCallData3);
                data.Add("customCallData4", customCallData4);
                data.Add("customCallData5", customCallData5);
                data.Add("customCallData6", customCallData6);
                data.Add("customCallData7", customCallData7);
                data.Add("customCallData8", customCallData8);
                data.Add("customCallData9", customCallData9);
                data.Add("customCallData10", customCallData10);
                data.Add("customCallData11", customCallData11);
                data.Add("customCallData12", customCallData12);
                data.Add("customCallData13", customCallData13);
                data.Add("customCallData14", customCallData14);
                data.Add("customCallData15", customCallData15);
                data.Add("customCallData16", customCallData16);
                data.Add("customCallData17", customCallData17);
                data.Add("customCallData18", customCallData18);
                data.Add("customCallData19", customCallData19);
                data.Add("customCallData20", customCallData20);

                data.Add("messageId", messageId.ToString());
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData, only);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.interactionChangedAsync {info}", ex);
            }
        }



        // Interaction Removed (optional single-target for connect snapshot)
        public static async Task interactionRemovedAsync(string workgroup, string interactionId, int segmentId, bool isDisconnected, string origCallId, string localUserId,
            string state, TimeSpan timeInWorkgroupQueue, bool isCallbackRequest, DateTime? eventTime = null, RtmTarget only = null)
        {
            AsyncLogger.Info($"<<< interactionRemoved >>> workgroup={workgroup} interactionId={interactionId} segmentId={segmentId} " +
                $"state={state} localUserId={localUserId} isCallbackRequest={isCallbackRequest}");

            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = eventTime ?? DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "interactionRemoved");
                data.Add("workgroup", workgroup);
                data.Add("interactionId", interactionId);
                data.Add("segmentId", segmentId);
                data.Add("isDisconnected", isDisconnected);
                data.Add("origCallId", origCallId);
                data.Add("localUserId", localUserId);
                data.Add("state", state);
                data.Add("timeInWorkgroupQueue", timeInWorkgroupQueue);

                data.Add("isCallbackRequest", isCallbackRequest);

                data.Add("messageId", messageId.ToString());
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData, only);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.interactionRemovedAsync {info}", ex);
            }
        }



        // Set User (optional single-target for connect snapshot)
        public static async Task setUsersAsync(List<string> users, string src, RtmTarget only = null)
        {
            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "setUsers");
                data.Add("users", "users");
                data.Add("messageId", messageId);
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData, only);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.setUsersAsync {info}", ex);
            }
        }




        // Set Skills (optional single-target for connect snapshot)
        public static async Task setSkillsAsync(List<string> skills, RtmTarget only = null)
        {
            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "setSkills");
                data.Add("skills", skills);
                data.Add("messageId", messageId);
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData, only);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.setSkillsAsync {info}", ex);
            }
        }



        // Set Workgroups (optional single-target for connect snapshot)
        public static async Task setWorkgroupsAsync(List<string> workgroups, RtmTarget only = null)
        {
            string info = string.Empty;
            try
            {
                long messageId = MsgId;
                DateTime timeStamp = DateTime.Now;

                var data = new Dictionary<string, object>();
                data.Add("method", "setWorkgroups");
                data.Add("workgroups", workgroups);
                data.Add("messageId", messageId);
                data.Add("timeStamp", timeStamp);

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData, only);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.setWorkgroupsAsync {info}", ex);
            }
        }




        public static async Task messageEventReceivedAsync(
            string eventType,
            string messageId,
            string direction,
            string sender,
            string recipient,
            string body,
            DateTime timestamp,
            string deliveryStatus,
            string channelSid = null,
            string conversationId = null,
            string taskSid = null,
            string reservationSid = null
)
        {
            AsyncLogger.Info($"<<< messageEventReceivedAsync >>> type={eventType}, id={messageId}, direction={direction}, sender={sender}");

            try
            {
                long internalMsgId = MsgId;
                DateTime timeStampNow = DateTime.Now;

                var data = new Dictionary<string, object>
                {
                    { "method", "messageEventReceived" },
                    { "eventType", eventType },
                    { "MessageId", messageId },
                    { "direction", direction },
                    { "sender", sender },
                    { "recipient", recipient },
                    { "body", body },
                    { "timestamp", timestamp },
                    { "deliveryStatus", deliveryStatus },
                    { "channelSid", channelSid },
                    { "conversationId", conversationId },
                    { "taskSid", taskSid },
                    { "reservationSid", reservationSid },
                    { "internalMsgId", internalMsgId },
                    { "receivedAt", timeStampNow },
                    { "messageId", messageId }
                };

                string jsonData = DictionarySerializer.SerializeToJson(data);
                await SendToAllAsync(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("RTMAdapter.messageEventReceivedAsync", ex);
            }
        }

    }
}
