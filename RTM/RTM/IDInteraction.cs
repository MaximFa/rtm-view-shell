using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Data.SqlTypes;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class IDInteraction
    {
        private DBMng _dbMng = null;


        public IDInteraction(string interactionId, int segment, DBMng dbMng, bool isDBInserted)
        {
            InteractionId = interactionId;
            Segment = segment;
            //Workgroup = workgroup;
            //State = State;
            //ClassificationCode = classificationCode;
            //InteractionType = interactionType;
            //CallType = callType;
            //Direction = direction;
            //CustomCallData = customCallData;
            //RemoteAddress = remoteAddress;
            IsTransferred = false;
            IsAnswered = false;
            IsMessaging = false;
            IsInQueue = false;
            IsTalk = false;
            TimeInQueue = 0;
            TalkTime = 0;
            UserId = string.Empty;
            InQueueDateTime = (DateTime)SqlDateTime.MaxValue;
            AnsweredDateTime = (DateTime)SqlDateTime.MinValue;
            LastUserId = string.Empty; 
            //LastWorkgroup = string.Empty;
            //CustomCallData1 = customCallData1;
            //CustomCallData2 = customCallData2;
            //CustomCallData3 = customCallData3;
            //CustomCallData4 = customCallData4;
            //CustomCallData5 = customCallData5;
            //CustomCallData6 = customCallData6;
            //CustomCallData7 = customCallData7;
            //CustomCallData8 = customCallData8;
            //CustomCallData9 = customCallData9;
            //CustomCallData10 = customCallData10;
            //CustomCallData11 = customCallData11;
            //CustomCallData12 = customCallData12;
            //CustomCallData13 = customCallData13;
            //CustomCallData14 = customCallData14;
            //CustomCallData15 = customCallData15;
            //CustomCallData16 = customCallData16;
            //CustomCallData17 = customCallData17;
            //CustomCallData18 = customCallData18;
            //CustomCallData19 = customCallData19;
            //CustomCallData20 = customCallData20;
            //IsCallbackRequest = isCallbackRequest;
            _dbMng = dbMng;
            IsDBInserted = isDBInserted;
        }


        private bool IsDBInserted { get; set; }


        public string InteractionId { get; set; }


        public int Segment { get; set; }


        public string Key 
        { 
            get
            {
                return Segment + InteractionId;
            }
        }


        public string Workgroup { get; set; } = "";


        public string State { get; set; } = "";


        public ConcurrentDictionary<string, ChatMessage> ChatMessages { get; set; } = new();

        public ChatStatsLive ChatStats { get; set; } = new ChatStatsLive(TimeSpan.FromSeconds(30)); // אפשר להגדיר פה גם 20 או 40 שניות


        public void addChatMessage(ChatMessage chatMessage)
        {
            ChatMessages.TryAdd(chatMessage.MessageId, chatMessage);
            ChatStats.AddMessage(chatMessage);
        }



        public string LastWorkgroup { get; set; } = "";


        public string ClassificationCode { get; set; } = "";


        public string InteractionType { get; set; } = "";


        public string CallType { get; set; } = "";


        public string Direction { get; set; } = "";


        public string CustomCallData { get; set; } = "";


        public string RemoteAddress { get; set; } = "";


        public string UserId { get; set; } = "";


        public string LastUserId { get; set; } = "";


        public bool IsTransferred { get; set; }


        public bool IsAnswered { get; set; }


        public bool IsAbandoned { get; set; }


        public bool IsMessaging { get; set; }


        public bool IsInQueue { get; set; }


        public bool IsTalk { get; set; }


        public double TimeInQueue { get; set; }


        public double TalkTime { get; set; }


        public DateTime InQueueDateTime { get; set; }


        public DateTime AnsweredDateTime { get; set; }


        public DateTime DisconnectDateTime { get; set; }



        public DateTime InQueueLocalDateTime { get; set; }


        public DateTime AnsweredLocalDateTime { get; set; }


        public DateTime DisconnectLocalDateTime { get; set; }



        // Last Message Sid
        public string LastMessageSid { get; set; } = string.Empty;



        public string CustomCallData1 { get; set; } = "";

        public string CustomCallData2 { get; set; } = "";

        public string CustomCallData3 { get; set; } = "";

        public string CustomCallData4 { get; set; } = "";

        public string CustomCallData5 { get; set; } = "";

        public string CustomCallData6 { get; set; } = "";

        public string CustomCallData7 { get; set; } = "";

        public string CustomCallData8 { get; set; } = "";

        public string CustomCallData9 { get; set; } = "";

        public string CustomCallData10 { get; set; } = "";

        public string CustomCallData11 { get; set; } = "";

        public string CustomCallData12 { get; set; } = "";

        public string CustomCallData13 { get; set; } = "";

        public string CustomCallData14 { get; set; } = "";

        public string CustomCallData15 { get; set; } = "";

        public string CustomCallData16 { get; set; } = "";

        public string CustomCallData17 { get; set; } = "";

        public string CustomCallData18 { get; set; } = "";

        public string CustomCallData19 { get; set; } = "";

        public string CustomCallData20 { get; set; } = "";


        public bool IsCallbackRequest { get; set; }


        // =============================================== 11/11/2025 =========================================
        private bool _isHeld;
        public bool IsHeld
        {
            get => _isHeld;
            set
            {
                if (_isHeld != value)
                {
                    _isHeld = value;
                    IsHeldChanged = true;
                }
            }
        }

        public bool IsHeldChanged { get; private set; }

        public void ResetHeldChangeFlag() => IsHeldChanged = false;

        //=====================================================================================================


        public string TimeZone { get; set; } = "";


        public ConcurrentDictionary<string, StateDuration> StateDuration { get; set; } = new ConcurrentDictionary<string, StateDuration>();



        public DateTime getLocalDateTime()
        {
            DateTime localTime = DateTime.UtcNow;
            
            try
            {             
                if (string.IsNullOrWhiteSpace(TimeZone)) return localTime;
                TimeSpan offset = TimeSpan.Parse(TimeZone.Replace("+", "").Replace("-", ""));
                if (TimeZone.StartsWith("-"))
                {
                    offset = offset.Negate();
                }

                localTime = localTime.Add(offset);

                AsyncLogger.Info ($"getLocalDateTime TimeZone={TimeZone} localTime={localTime}");
            }
            catch(Exception ex)
            {
                AsyncLogger.Error($"getLocalDateTime", ex);
                //AsyncLogger.Error($"IDInteraction getLocalDateTime InteractionId={InteractionId} Workgroup={Workgroup} TimeZone={TimeZone} localTime={localTime}", ex);
            }

            return localTime;
        }





        public void InQueue()
        {
            if (!IsInQueue)
            { 
                InQueueLocalDateTime = DateTime.Now;
                InQueueDateTime = getLocalDateTime();
                IsInQueue = true;

                addIntercationRequest();

                IsDBInserted = true;
            }
        }




        private void addIntercationRequest()
        {
            _dbMng.addIntercationRequest(IsDBInserted, InteractionId, Segment, Workgroup, ClassificationCode, InteractionType, CallType, Direction, CustomCallData, RemoteAddress, 
               UserId, IsTransferred, IsAnswered, IsInQueue, IsTalk, IsAbandoned, IsMessaging, TimeInQueue, TalkTime, InQueueDateTime, AnsweredDateTime, LastUserId, LastWorkgroup,
               CustomCallData1, CustomCallData2, CustomCallData3, CustomCallData4, CustomCallData5, CustomCallData6, CustomCallData7, CustomCallData8, CustomCallData9, CustomCallData10,
               CustomCallData11, CustomCallData12, CustomCallData13, CustomCallData14, CustomCallData15, CustomCallData16, CustomCallData17, CustomCallData18, CustomCallData19, CustomCallData20, 
               IsCallbackRequest, TimeZone, getLocalDateTime());

        }




        public void CallbackRequest()
        {
            IsCallbackRequest = true;
            IsAbandoned = false;

            addIntercationRequest();
        }



        public void OutQueue(bool isAbandoned)
        {
            DateTime outQueueDateTime = DateTime.Now;  //getLocalDateTime();
            double timeInQueue = outQueueDateTime.Subtract(InQueueLocalDateTime).TotalSeconds;

            OutQueue(timeInQueue, isAbandoned);
        }


        public void OutQueue(double timeInQueue, bool isAbandoned)
        {
            TimeInQueue = timeInQueue;
            IsInQueue = false;

            IsAbandoned = isAbandoned;
            if (IsCallbackRequest)
            {
                IsAbandoned = false;
            }

            addIntercationRequest();

            IsDBInserted = true;
        }



        public void Answered(string userId)
        {
            IsAnswered = true;
            IsTalk = true;
            UserId = userId;

            AnsweredLocalDateTime = DateTime.Now;
            AnsweredDateTime = getLocalDateTime();

            addIntercationRequest();

            IsDBInserted = true;
        }



        public void Messaging()
        {
            IsMessaging = true;
            AnsweredLocalDateTime = DateTime.Now;
            AnsweredDateTime = getLocalDateTime();

            addIntercationRequest();

            IsDBInserted = true;
        }



        public bool EndTalk()
        {
            bool isTalk = false;

            if (IsTalk)
            {
                isTalk = true;
                //TalkTime = getLocalDateTime().Subtract(AnsweredDateTime).TotalSeconds;
                TalkTime = DateTime.Now.Subtract(AnsweredLocalDateTime).TotalSeconds;
                IsTalk = false;

                addIntercationRequest();

                IsDBInserted = true;
            }

            return isTalk;
        }



        public bool IsDisconnected { get; private set; } = false;



        public void MarkSegmentEnded()
        {
            //if (IsDisconnected)
            //    return;

            IsDisconnected = true;
            DisconnectLocalDateTime = DateTime.Now;
            DisconnectDateTime = getLocalDateTime();

            IsTalk = false;
            IsInQueue = false;
        }



        public void Disconnected()
        {
            AsyncLogger.Info($"IDInteraction.Disconnected | interactionId={InteractionId} segment={Segment} before IsInQueue={IsInQueue} IsTalk={IsTalk} IsDisconnected={IsDisconnected}");

            IsTalk = false;
            IsInQueue = false;
            IsDisconnected = true;
            DisconnectDateTime = getLocalDateTime();

            AsyncLogger.Info($"IDInteraction.Disconnected | interactionId={InteractionId} segment={Segment} after IsInQueue={IsInQueue} IsTalk={IsTalk} IsDisconnected={IsDisconnected}");
        }




        public Dictionary<string, string> getData()
        {
            Dictionary<string, string> data = new Dictionary<string, string>();
            foreach (var prop in GetType().GetProperties())
            {
                string name = prop.Name;
                string value = prop.GetValue(this, null).ToString();

                data.Add(name, value);
            }

            return data;
        }



       

        public DateTime stateStart
        {
            get
            {
                DateTime dt = getLocalDateTime();

                if (!string.IsNullOrEmpty(State))
                {
                    dt = dt.Subtract(StateDuration[State].duration);
                }

                return dt;
            }
        }


    }
}
