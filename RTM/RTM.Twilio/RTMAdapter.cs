using RTM.Tools;
using RTM.Types;
using Newtonsoft.Json;
using Formatting = Newtonsoft.Json.Formatting;
using System.Text;

namespace RTM.Twilio
{
    public class RTMAdapter
    {
        private static string RtmURL { get; set; } = "http://localhost:8080/signalr";

        private static HttpClient HttpClient;

        private static IClient client;


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


        public static async Task clientStartAsync()
        {
            client = new NamedPipeClient("rtmpipe");

            client.ClientStarted += (_, args)
               => AsyncLogger.Info("CLIENT => Client started.");

            client.ConnectedToServer += Client_ConnectedToServer;

            client.MessageReceived += (_, args) =>
               AsyncLogger.Info($"CLIENT => Message received from server: {(args as MessageReceivedEventArgs).Message}");

            client.Disconnected += (_, args) =>
               AsyncLogger.Info($"CLIENT => Server disconnected.");

            await client.Connect();
        }


        private static void Client_ConnectedToServer(object? sender, EventArgs e)
        {
            AsyncLogger.Info("CLIENT => Client connected to server.");
            ServerConnectEvent?.Invoke(null, EventArgs.Empty);
        }


        public static async Task connect(string rtmURL)
        {
            try
            {
                RtmURL = rtmURL;

                HttpClientHandler clientHandler = new HttpClientHandler();
                clientHandler.ServerCertificateCustomValidationCallback = (sender, cert, chain, sslPolicyErrors) => { return true; };

                HttpClient = new HttpClient(clientHandler);

                await clientStartAsync();
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("RTMAdapter.connect", ex);
            }
        }





        // setUsersStatusList
        public static async Task<bool> setUsersStatusList(List<Agent> usersStatusList)
        {
            bool result = false;
            string info = string.Empty;

            try
            {
                string data = JsonConvert.SerializeObject(usersStatusList, Formatting.Indented);
                info = " usersStatusList=" + data;
                var content = new StringContent(data);

                var response = await HttpClient.PostAsync(RtmURL + "/SetUsersStatusList", content);

                string responseString = await response.Content.ReadAsStringAsync();
                AsyncLogger.Info("SetUsersStatusList response=" + responseString);

                result = response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.setUsersStatusList {info}", ex);
            }

            return result;
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
                await client.Send(jsonData);
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
                await client.Send(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.userStatusChangedAsync {info}", ex);
            }
        }




        // User Workgroup Activation        
        public static async Task userWorkgroupActivationAsync(string workgroup, List<string> activeUsersList, List<string> deactiveUsersList)
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
                await client.Send(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.userWorkgroupActivationAsync {info}", ex);
            }
        }




        // userConfigurationChanged
        public static async Task userConfigurationChangedAsync(string userId, string displayName, string extension, string firstName, string LastName, IDictionary<string, string> customAttributes)
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
                await client.Send(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.userConfigurationChangedAsync {info}", ex);
            }
        }


        // Interaction Changed
        public static async Task interactionChangedAsync(string workgroup, bool isAdded, string interactionId, int segmentId,
           bool isDisconnect, string callType, string interactionType, string direction, string state, DateTime stateChangedTime,
           TimeSpan duration, TimeSpan timeInWorkgroupQueue, bool isConsult, string consultCallId, string applic, string classificationCode, string localUserId, string origCallId,
           string customCallData, string calculatedStatus, string calculatedStatusTime, string c4uState, string localName, List<string> changedAttributeNames, bool isHeld, string remoteAddress, string lastMessageSid,
           string customCallData1, string customCallData2, string customCallData3, string customCallData4, string customCallData5, string customCallData6,
           string customCallData7, string customCallData8, string customCallData9, string customCallData10, string customCallData11, string customCallData12,
           string customCallData13, string customCallData14, string customCallData15, string customCallData16, string customCallData17, string customCallData18,
           string customCallData19, string customCallData20)
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
                await client.Send(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.interactionChangedAsync {info}", ex);
            }
        }



        // Interaction Removed
        public static async Task interactionRemovedAsync(string workgroup, string interactionId, int segmentId, bool isDisconnected, string origCallId, string localUserId,
            string state, TimeSpan timeInWorkgroupQueue, bool isCallbackRequest, DateTime? eventTime = null)
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
                await client.Send(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.interactionRemovedAsync {info}", ex);
            }
        }



        // Set User
        public static async Task setUsersAsync(List<string> users, string src)
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
                await client.Send(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.setUsersAsync {info}", ex);
            }
        }




        // Set Skills
        public static async Task setSkillsAsync(List<string> skills)
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
                await client.Send(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error($"RTMAdapter.setSkillsAsync {info}", ex);
            }
        }



        // Set Workgroups
        public static async Task setWorkgroupsAsync(List<string> workgroups)
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
                await client.Send(jsonData);
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
                await client.Send(jsonData);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("RTMAdapter.messageEventReceivedAsync", ex);
            }
        }

    }
}