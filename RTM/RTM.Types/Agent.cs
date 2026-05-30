namespace RTM.Types
{
    using System.Runtime.Serialization;

    public class Agent
    {
        public Agent() { }

        // User ID
        [DataMember]
        public string UserId { get; set; }

        [DataMember]
        public string WorkerSid { get; set; }

        [DataMember]
        public string DisplayName { get; set; }

        [DataMember]
        public string Extension { get; set; }

        [DataMember]
        public string FirstName { get; set; }

        [DataMember]
        public string LastName { get; set; }

        [DataMember]
        public IDictionary<string, string> CustomAttributes { get; set; }

        [DataMember]
        public bool LoggedIn { get; set; }

        [DataMember]
        public string Station { get; set; }

        [DataMember]
        public bool OnPhone { get; set; }

        [DataMember]
        public DateTime OnPhoneChanged { get; set; }

        [DataMember]
        public string StatusId { get; set; }

        [DataMember]
        public string StatusName { get; set; }

        [DataMember]
        public DateTime StatusChanged { get; set; }

        [DataMember]
        public string StatusGroup { get; set; }


        [DataMember]
        public List<string> Workgroups { get; set; }


        public string LastStatus { get; set; } = string.Empty;


        public string LastStatusGroup { get; set; }


        public string BeforeHoldStatus { get; set; } = string.Empty;


        public string BeforeHoldStatusGroup { get; set; }


        public DateTime TimeStamp { get; set; } = DateTime.MinValue;
    }

}
