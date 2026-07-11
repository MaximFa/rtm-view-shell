using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Types
{
    public class Interaction
    {
        public Interaction(string id) 
        { 
            Id = id;    
        }


        public string Id { get; set; }



        public DateTime LastEventTime { get; set; } 



        public string Workgroup { get; set; }

        public bool IsAdded { get; set; }

        public string InteractionId { get; set; }

        public int SegmentId { get; set; } = 1;


        //public ConcurrentDictionary<string, int> Reservations { get; set; } = new ConcurrentDictionary<string, int>();

        public ConcurrentDictionary<string, Reservation> Reservations { get; set; } = new ConcurrentDictionary<string, Reservation>();


        //public string LastReservation { get; set; } = string.Empty;
        public bool IsRejected { get; set; } = false;
       
        public bool IsAnswered { get; set; } = false;

        public bool IsMoved { get; set; } = false;

        public bool IsDisconnect { get; set; }


        public bool IsCallbackRequest { get; set; }

        public string CallType { get; set; }

        public string InteractionType { get; set; }

        public string Direction { get; set; }

        public string State { get; set; }

        public string LastState { get; set; } = string.Empty;

        public DateTime StateChangedTime { get; set; }

        public TimeSpan Duration { get; set; }

        public TimeSpan TimeInWorkgroupQueue { get; set; }

        public bool IsConsult { get; set; }

        public string ConsultCallId { get; set; }

        public string Applic { get; set; }

        public string ClassificationCode { get; set; }
   
        public string LocalUserId { get; set; }

        public string OrigCallId { get; set; }

        public string CustomCallData { get; set; }

        public string CalculatedStatus { get; set; }

        public string CalculatedStatusTime { get; set; }

        public string C4uState { get; set; }

        public string LocalName { get; set; }

        public List<string> ChangedAttributeNames { get; set; }

        public bool IsHeld { get; set; }

        public string RemoteAddress { get; set; }

        public DateTime TimeStamp { get; set; }



        // Property to determine when the interaction should be checked next
        public DateTime NextCheckTime { get; set; } = DateTime.Now.AddMinutes(5);

        // Indicates whether the interaction is in the 'do not check' period
        public bool IsInDoNotCheckPeriod { get; set; } = false;



        // Last Message Sid
        public string LastMessageSid { get; set; } = string.Empty;




    }
}
