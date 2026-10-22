using RTM.Tools;
// [SYNC-PORT 2026-10-16 src=2026-07-20] U2 backdated terminal (legacy, unmarked): AppConfig.BackdatedTerminalEnabled.
using RTM.Configuration;
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
            // [SYNC-PORT 2026-10-16 src=2026-07-20] U2 backdated terminal (legacy, unmarked): origin fallback if neither InQueue nor Answered ever fires.
            CreatedUtc = DateTime.UtcNow;
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

        // BL-234-INTERACTION-TIME-AHEAD-01: the TRUE UTC instant of each stamp, taken at the moment of stamping.
        // The row's TimeZone is overwritten every time the interaction is added to a bag (queue bag = site zone,
        // agent bag = RTM:DefaultTimeZone, possibly empty), so the local stamp cannot be converted back reliably with
        // the zone in force at WRITE time. These carry the instant itself; null = not stamped in this process (DBMng
        // then falls back to converting the local value with the row's zone - see DbTime.ToDbUtc).
        internal DateTime? InQueueUtc { get; set; }
        internal DateTime? AnsweredUtc { get; set; }


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



        // [SYNC-PORT 2026-10-16 src=2026-07-20] U2 backdated terminal (legacy, unmarked): the UTC->local step is shared by getLocalDateTime and the origin day, so both
        // localize identically. Our semantics kept: empty TimeZone => UTC; offset string or Windows/IANA id; unknown => UTC.
        public DateTime getLocalDateTime() => toLocal(DateTime.UtcNow);

        internal DateTime toLocal(DateTime utc)
        {
            DateTime localTime = utc;

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
                    offset = tzi.GetUtcOffset(utc);
                }

                localTime = localTime.Add(offset);
            }
            catch
            {
                // Unknown timezone format — return UTC silently
            }

            return localTime;
        }

        // [SYNC-PORT 2026-10-16 src=2026-07-20] U2 backdated terminal (legacy, unmarked): wall clock (UTC) at construction - the last-resort origin.
        public DateTime CreatedUtc { get; private set; }

        // ORIGIN day: the local day the interaction entered the queue / was answered, never the write day.
        public DateTime OriginLocalDate()
        {
            if (InQueueDateTime != (DateTime)SqlDateTime.MaxValue)
            {
                return InQueueDateTime.Date;
            }
            if (AnsweredDateTime != (DateTime)SqlDateTime.MinValue)
            {
                return AnsweredDateTime.Date;
            }
            return toLocal(CreatedUtc).Date;
        }

        // True when the origin day is earlier than the current local day (this interaction's own TimeZone).
        public bool IsBackdated() => IsBackdated(DateTime.UtcNow);

        internal bool IsBackdated(DateTime nowUtc) => OriginLocalDate() < toLocal(nowUtc).Date;





        public void InQueue()
        {
            if (!IsInQueue)
            { 
                InQueueLocalDateTime = DateTime.Now;
                var inQueueUtc = DateTime.UtcNow;
                InQueueUtc = inQueueUtc;
                InQueueDateTime = toLocal(inQueueUtc);
                IsInQueue = true;

                addIntercationRequest();

                IsDBInserted = true;
            }
        }




        // [SYNC-PORT 2026-10-16 src=2026-07-20] U2 backdated terminal (legacy, unmarked): the DB row day. ON: the origin day, so an after-midnight terminal closes the
        // prior day's row. OFF: the write day (today's behaviour).
        internal DateTime RowDate() => AppConfig.BackdatedTerminalEnabled ? OriginLocalDate() : getLocalDateTime();

        private void addIntercationRequest()
        {
            _dbMng.addIntercationRequest(IsDBInserted, InteractionId, Segment, Workgroup, ClassificationCode, InteractionType, CallType, Direction, CustomCallData, RemoteAddress, 
               UserId, IsTransferred, IsAnswered, IsInQueue, IsTalk, IsAbandoned, IsMessaging, TimeInQueue, TalkTime,
               InQueueUtc ?? InQueueDateTime, AnsweredUtc ?? AnsweredDateTime, LastUserId, LastWorkgroup, // UTC instants when known (Kind=Utc), else the local stamp
               CustomCallData1, CustomCallData2, CustomCallData3, CustomCallData4, CustomCallData5, CustomCallData6, CustomCallData7, CustomCallData8, CustomCallData9, CustomCallData10,
               CustomCallData11, CustomCallData12, CustomCallData13, CustomCallData14, CustomCallData15, CustomCallData16, CustomCallData17, CustomCallData18, CustomCallData19, CustomCallData20, 
               IsCallbackRequest, TimeZone, getLocalDateTime(), RowDate());

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
            var answeredUtc = DateTime.UtcNow;
            AnsweredUtc = answeredUtc;
            AnsweredDateTime = toLocal(answeredUtc);

            addIntercationRequest();

            IsDBInserted = true;
        }



        public void Messaging()
        {
            IsMessaging = true;
            AnsweredLocalDateTime = DateTime.Now;
            var answeredUtc = DateTime.UtcNow;
            AnsweredUtc = answeredUtc;
            AnsweredDateTime = toLocal(answeredUtc);

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
