using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Data;
using Npgsql;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static log4net.Appender.RollingFileAppender;

namespace RTM
{
    public class DBRequest
    {
        public string ServerId { get; set; }

        public string OnDate { get; set; }

        public DateTime UpdateTime { get; set; }

        public bool IsDBInserted { get; set; }
    }


    public class UserStatusDBRequest : DBRequest
    {
        public string UserId { get; set; }

        public string StatusId { get; set; }

        public string StatusName { get; set; }

        public string StatusGroup { get; set; }

        public TimeSpan TotalDuration { get; set; }

        public TimeSpan MaxDuration { get; set; }

        public int TotalCount { get; set; }

        public string DisplayName { get; set; }

        public string TimeZone { get; set; }

        public DateTime StratTime { get; set; }

        public DateTime EndTime { get; set; }
    }



    public class InteractionDBRequest : DBRequest
    {
        public string InteractionId { get; set; }

        public int Segment { get; set; }

        public string Workgroup { get; set; }

        public string ClassificationCode { get; set; }

        public string InteractionType { get; set; }

        public string CallType { get; set; }

        public string Direction { get; set; }

        public string CustomCallData { get; set; }

        public string RemoteAddress { get; set; }

        public string UserId { get; set; }

        public bool IsTransferred { get; set; }

        public bool IsAnswered { get; set; }

        public bool IsInQueue { get; set; }

        public bool IsTalk { get; set; }

        public bool IsAbandoned { get; set; }

        public bool IsMessaging { get; set; }

        public double TimeInQueue { get; set; }

        public double TalkTime { get; set; }

        public DateTime InQueueDateTime { get; set; }

        public DateTime AnsweredDateTime { get; set; }

        public string LastUserId { get; set; }

        public string LastWorkgroup { get; set; }


        public string CustomCallData1 { get; set; }

        public string CustomCallData2 { get; set; }

        public string CustomCallData3 { get; set; }

        public string CustomCallData4 { get; set; }

        public string CustomCallData5 { get; set; }

        public string CustomCallData6 { get; set; }

        public string CustomCallData7 { get; set; }

        public string CustomCallData8 { get; set; }

        public string CustomCallData9 { get; set; }

        public string CustomCallData10 { get; set; }

        public string CustomCallData11 { get; set; }

        public string CustomCallData12 { get; set; }

        public string CustomCallData13 { get; set; }

        public string CustomCallData14 { get; set; }

        public string CustomCallData15 { get; set; }

        public string CustomCallData16 { get; set; }

        public string CustomCallData17 { get; set; }

        public string CustomCallData18 { get; set; }

        public string CustomCallData19 { get; set; }

        public string CustomCallData20 { get; set; }


        public bool IsCallbackRequest { get; set; }

        public string TimeZone { get; set; }
    }





    public class ChatMessageDBRequest : DBRequest
    {
        public string EventType { get; set; }


        public string MessageId { get; set; }


        public string MsgDirection { get; set; }


        public string Sender { get; set; }


        public string Recipient { get; set; }


        public string Body { get; set; }


        public string DeliveryStatus { get; set; }


        public string InteractionId { get; set; }


        public int SegmentId { get; set; }


        public string UserId { get; set; }


        public DateTime TimeStamp { get; set; }
    }




    public class DBMng
    {
        private string _connectionString;
        private string _machineName;
        private BlockingCollection<DBRequest> _requestsQueue = new BlockingCollection<DBRequest>();

        private const string ProviderType = "data";


        public DBMng(string machineName)
        {
            AsyncLogger.Info("DBMng Start");

            _machineName = machineName; // Environment.MachineName;
            AsyncLogger.Info("DBMng _machineName = " + _machineName);

            _requestsQueue = new BlockingCollection<DBRequest>();

            Task.Factory.StartNew(async () =>
            {
                foreach (var userStatusRequest in _requestsQueue.GetConsumingEnumerable())
                {
                    await runSP(userStatusRequest);
                }
            });
        }




        public void addIntercationRequest(bool isDBInserted, string interactionId, int segment, string workgroup, string classificationCode,
            string interactionType, string callType, string direction, string customCallData, string remoteAddress, string userId, bool isTransferred,
            bool isAnswered, bool isInQueue, bool isTalk, bool isAbandoned, bool isMaessaging, double timeInQueue, double talkTime,
            DateTime inQueueDateTime, DateTime answeredDateTime, string lastUserId, string lastWorkgroup, string customCallData1, string customCallData2,
            string customCallData3, string customCallData4, string customCallData5, string customCallData6, string customCallData7, string customCallData8,
            string customCallData9, string customCallData10, string customCallData11, string customCallData12, string customCallData13, string customCallData14,
            string customCallData15, string customCallData16, string customCallData17, string customCallData18, string customCallData19, string customCallData20, 
            bool isCallbackRequest, string timeZone, DateTime updateTime)
        {
            InteractionDBRequest interactionDBRequest = new InteractionDBRequest
            {
                //IsDBInserted = isDBInserted,
                InteractionId = interactionId,
                Segment = segment,
                Workgroup = workgroup,
                LastWorkgroup = lastWorkgroup,
                ClassificationCode = classificationCode,
                InteractionType = interactionType,
                CallType = callType,
                Direction = direction,
                CustomCallData = customCallData,
                RemoteAddress = remoteAddress,
                UserId = userId,
                LastUserId = lastUserId,
                IsTransferred = isTransferred,
                IsAnswered = isAnswered,
                IsInQueue = isInQueue,
                IsTalk = isTalk,
                IsAbandoned = isAbandoned,
                IsMessaging = isMaessaging,
                TimeInQueue = timeInQueue,
                TalkTime = talkTime,
                InQueueDateTime = inQueueDateTime,
                AnsweredDateTime = answeredDateTime,
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
                IsCallbackRequest = isCallbackRequest,
                TimeZone = timeZone,
                ServerId = _machineName,
                UpdateTime = updateTime,
                OnDate = updateTime.Date.ToString("dd/MM/yyyy")
            };

            _requestsQueue.Add(interactionDBRequest);
        }




        public void addUserStatusRequest(bool isDBInserted, string userId, string statusId, string statusName, string statusGroup,
            TimeSpan totalDuration, TimeSpan maxDuration, int totalCount, string displayName, DateTime stratTime, DateTime endTime, string timeZone, DateTime updateTime)
        {
            UserStatusDBRequest userStatusRequest = new UserStatusDBRequest
            {
                //IsDBInserted = isDBInserted,
                UserId = userId,
                StatusId = statusId,
                StatusName = statusName,
                StatusGroup = statusGroup,
                TotalDuration = totalDuration,
                MaxDuration = maxDuration,
                TotalCount = totalCount,
                ServerId = _machineName,
                DisplayName = displayName,
                StratTime = stratTime,
                EndTime = endTime,
                TimeZone = timeZone,
                UpdateTime = updateTime,
                OnDate = updateTime.Date.ToString("dd/MM/yyyy")
            };

            _requestsQueue.Add(userStatusRequest);
        }





        public void addChatMessageRequest(string eventType, string messageId, string msgDirection, string sender, string recipient,
            string body, string deliveryStatus, string interactionId, int segmentId, string userId, DateTime timeStamp, DateTime updateTime)
        {
            ChatMessageDBRequest userStatusRequest = new ChatMessageDBRequest
            {
                EventType = eventType,
                MessageId = messageId,
                MsgDirection = msgDirection,
                Sender = sender,
                Recipient = recipient,
                Body = body,
                DeliveryStatus = deliveryStatus,
                InteractionId = interactionId,
                SegmentId = segmentId,
                UserId = userId,
                TimeStamp = timeStamp,
                ServerId = _machineName,
                UpdateTime = updateTime,
                OnDate = updateTime.Date.ToString("dd/MM/yyyy")
            };

            _requestsQueue.Add(userStatusRequest);
        }



        private async Task runSP(DBRequest dbRequest)
        {
            await Task.Run(() =>
            {
                try
                {
                    using (NpgsqlConnection con = new NpgsqlConnection(_connectionString))
                    {
                        if (dbRequest.GetType() == typeof(UserStatusDBRequest))
                        {
                            UserStatusDBRequest userStatusRequest = dbRequest as UserStatusDBRequest;

                            var parameters = new List<NpgsqlParameter>();
                            //parameters.Add(new NpgsqlParameter("@IsDBInserted", userStatusRequest.IsDBInserted));
                            parameters.Add(new NpgsqlParameter("@UserId", userStatusRequest.UserId));
                            parameters.Add(new NpgsqlParameter("@StatusId", userStatusRequest.StatusId));
                            parameters.Add(new NpgsqlParameter("@ServerId", userStatusRequest.ServerId));
                            parameters.Add(new NpgsqlParameter("@OnDate", userStatusRequest.OnDate));
                            parameters.Add(new NpgsqlParameter("@StatusName", userStatusRequest.StatusName));
                            parameters.Add(new NpgsqlParameter("@StatusGroup", userStatusRequest.StatusGroup));
                            parameters.Add(new NpgsqlParameter("@TotalDuration", userStatusRequest.TotalDuration.TotalSeconds));
                            parameters.Add(new NpgsqlParameter("@MaxDuration", userStatusRequest.MaxDuration.TotalSeconds));
                            parameters.Add(new NpgsqlParameter("@TotalCount", userStatusRequest.TotalCount));
                            parameters.Add(new NpgsqlParameter("@DisplayName", userStatusRequest.DisplayName ?? userStatusRequest.UserId));
                            parameters.Add(new NpgsqlParameter("@StartTime", DateTime.SpecifyKind(userStatusRequest.StratTime, DateTimeKind.Utc)));
                            parameters.Add(new NpgsqlParameter("@EndTime", DateTime.SpecifyKind(userStatusRequest.EndTime, DateTimeKind.Utc)));
                            parameters.Add(new NpgsqlParameter("@TimeZone", userStatusRequest.TimeZone));
                            parameters.Add(new NpgsqlParameter("@UpdateTime", DateTime.SpecifyKind(userStatusRequest.UpdateTime, DateTimeKind.Utc)));                           
                            DBAdapter.ExecuteNonQuery("RTSData_SetUserStatus", parameters);
                        }
                        else if (dbRequest.GetType() == typeof(InteractionDBRequest))
                        {
                            InteractionDBRequest interactionRequest = dbRequest as InteractionDBRequest;

                            var parameters = new List<NpgsqlParameter>();
                            //parameters.Add(new NpgsqlParameter("@IsDBInserted", interactionRequest.IsDBInserted));
                            parameters.Add(new NpgsqlParameter("@InteractionId", interactionRequest.InteractionId));
                            parameters.Add(new NpgsqlParameter("@Segment", interactionRequest.Segment));
                            parameters.Add(new NpgsqlParameter("@Workgroup", interactionRequest.Workgroup));
                            parameters.Add(new NpgsqlParameter("@ClassificationCode", interactionRequest.ClassificationCode));
                            parameters.Add(new NpgsqlParameter("@InteractionType", interactionRequest.InteractionType));
                            parameters.Add(new NpgsqlParameter("@CallType", interactionRequest.CallType));
                            parameters.Add(new NpgsqlParameter("@Direction", interactionRequest.Direction));
                            parameters.Add(new NpgsqlParameter("@CustomCallData", interactionRequest.CustomCallData));
                            parameters.Add(new NpgsqlParameter("@RemoteAddress", interactionRequest.RemoteAddress));
                            parameters.Add(new NpgsqlParameter("@UserId", interactionRequest.UserId));
                            parameters.Add(new NpgsqlParameter("@IsTransferred", interactionRequest.IsTransferred));
                            parameters.Add(new NpgsqlParameter("@IsAnswered", interactionRequest.IsAnswered));
                            parameters.Add(new NpgsqlParameter("@IsInQueue", interactionRequest.IsInQueue));
                            parameters.Add(new NpgsqlParameter("@IsTalk", interactionRequest.IsTalk));
                            parameters.Add(new NpgsqlParameter("@IsAbandoned", interactionRequest.IsAbandoned));
                            parameters.Add(new NpgsqlParameter("@IsMessaging", interactionRequest.IsMessaging));
                            parameters.Add(new NpgsqlParameter("@TimeInQueue", interactionRequest.TimeInQueue));
                            parameters.Add(new NpgsqlParameter("@TalkTime", interactionRequest.TalkTime));
                            parameters.Add(new NpgsqlParameter("@InQueueDateTime", DateTime.SpecifyKind(interactionRequest.InQueueDateTime, DateTimeKind.Utc)));
                            parameters.Add(new NpgsqlParameter("@AnsweredDateTime", DateTime.SpecifyKind(interactionRequest.AnsweredDateTime, DateTimeKind.Utc)));
                            parameters.Add(new NpgsqlParameter("@LastUserId", interactionRequest.LastUserId));
                            parameters.Add(new NpgsqlParameter("@LastWorkgroup", interactionRequest.LastWorkgroup));
                            parameters.Add(new NpgsqlParameter("@CustomCallData1", interactionRequest.CustomCallData1));
                            parameters.Add(new NpgsqlParameter("@CustomCallData2", interactionRequest.CustomCallData2));
                            parameters.Add(new NpgsqlParameter("@CustomCallData3", interactionRequest.CustomCallData3));
                            parameters.Add(new NpgsqlParameter("@CustomCallData4", interactionRequest.CustomCallData4));
                            parameters.Add(new NpgsqlParameter("@CustomCallData5", interactionRequest.CustomCallData5));
                            parameters.Add(new NpgsqlParameter("@CustomCallData6", interactionRequest.CustomCallData6));
                            parameters.Add(new NpgsqlParameter("@CustomCallData7", interactionRequest.CustomCallData7));
                            parameters.Add(new NpgsqlParameter("@CustomCallData8", interactionRequest.CustomCallData8));
                            parameters.Add(new NpgsqlParameter("@CustomCallData9", interactionRequest.CustomCallData9));
                            parameters.Add(new NpgsqlParameter("@CustomCallData10", interactionRequest.CustomCallData10));
                            parameters.Add(new NpgsqlParameter("@CustomCallData11", interactionRequest.CustomCallData11));
                            parameters.Add(new NpgsqlParameter("@CustomCallData12", interactionRequest.CustomCallData12));
                            parameters.Add(new NpgsqlParameter("@CustomCallData13", interactionRequest.CustomCallData13));
                            parameters.Add(new NpgsqlParameter("@CustomCallData14", interactionRequest.CustomCallData14));
                            parameters.Add(new NpgsqlParameter("@CustomCallData15", interactionRequest.CustomCallData15));
                            parameters.Add(new NpgsqlParameter("@CustomCallData16", interactionRequest.CustomCallData16));
                            parameters.Add(new NpgsqlParameter("@CustomCallData17", interactionRequest.CustomCallData17));
                            parameters.Add(new NpgsqlParameter("@CustomCallData18", interactionRequest.CustomCallData18));
                            parameters.Add(new NpgsqlParameter("@CustomCallData19", interactionRequest.CustomCallData19));
                            parameters.Add(new NpgsqlParameter("@CustomCallData20", interactionRequest.CustomCallData20));
                            parameters.Add(new NpgsqlParameter("@IsCallbackRequest", interactionRequest.IsCallbackRequest));
                            parameters.Add(new NpgsqlParameter("@TimeZone", interactionRequest.TimeZone));
                            parameters.Add(new NpgsqlParameter("@ServerId", interactionRequest.ServerId));
                            parameters.Add(new NpgsqlParameter("@UpdateTime", DateTime.SpecifyKind(interactionRequest.UpdateTime, DateTimeKind.Utc)));
                            parameters.Add(new NpgsqlParameter("@OnDate", interactionRequest.OnDate));
                            DBAdapter.ExecuteNonQuery("RTSData_SetInteraction", parameters);
                        }
                        else if (dbRequest.GetType() == typeof(ChatMessageDBRequest))
                        {
                            ChatMessageDBRequest interactionRequest = dbRequest as ChatMessageDBRequest;

                            var parameters = new List<NpgsqlParameter>();
                            parameters.Add(new NpgsqlParameter("@MessageId", interactionRequest.MessageId));
                            parameters.Add(new NpgsqlParameter("@MsgDirection", interactionRequest.MsgDirection));
                            parameters.Add(new NpgsqlParameter("@Sender", interactionRequest.Sender));
                            parameters.Add(new NpgsqlParameter("@Recipient", interactionRequest.Recipient));
                            parameters.Add(new NpgsqlParameter("@Body", interactionRequest.Body));
                            parameters.Add(new NpgsqlParameter("@DeliveryStatus", interactionRequest.DeliveryStatus));
                            parameters.Add(new NpgsqlParameter("@InteractionId", interactionRequest.InteractionId));
                            parameters.Add(new NpgsqlParameter("@SegmentId", interactionRequest.SegmentId));
                            parameters.Add(new NpgsqlParameter("@UserId", interactionRequest.UserId));                                                  
                            parameters.Add(new NpgsqlParameter("@ServerId", interactionRequest.ServerId));
                            parameters.Add(new NpgsqlParameter("@UpdateTime", DateTime.SpecifyKind(interactionRequest.UpdateTime, DateTimeKind.Utc)));
                            parameters.Add(new NpgsqlParameter("@OnDate", interactionRequest.OnDate));
                            parameters.Add(new NpgsqlParameter("@TimeStamp", interactionRequest.TimeStamp));
                            DBAdapter.ExecuteNonQuery("RTSData_SetChatMessage", parameters);
                        }
                    }
                }
                catch (Exception ex)
                {
                    AsyncLogger.Error("DBMng runSp", ex);
                }
            });
        }



        public void midnightClear()
        {
            try
            {
                DBAdapter.ExecuteNonQuery("RTSData_MidnightClear", null);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("DBMng runSp", ex);
            }
        }



        public DataTable getUsersStatuses()
        {
            string OnDate = DateTime.Today.ToString("dd/MM/yyyy");

            var parameters = new List<NpgsqlParameter>();
            parameters.Add(new NpgsqlParameter("@OnDate", OnDate));
            return DBAdapter.GetDataTable("RTSData_getUsersStatuses", parameters);
        }


        public DataTable getIntercations()
        {
            string OnDate = DateTime.Today.ToString("dd/MM/yyyy");

            var parameters = new List<NpgsqlParameter>();
            parameters.Add(new NpgsqlParameter("@OnDate", OnDate));
            return DBAdapter.GetDataTable("RTSData_getInteractions", parameters);
        }

    }
}

