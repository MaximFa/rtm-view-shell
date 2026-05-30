using System.Collections.Concurrent;
using System.Text.Json.Serialization;

namespace RTM
{
    public class BusinessUnit
    {
        // BusinessUnit
        public BusinessUnit(int businessUnitID, string name, string description, string timeZone, TimeSpan clearTime)
        {
            BusinessUnitID = businessUnitID;
            Name = name;
            Description = description;
            TimeZone = timeZone;
            ClearTime = clearTime;
        }


        // BusinessUnitID
        public int BusinessUnitID { get; set; }


        // Name
        public string Name { get; set; }


        // Description
        public string Description { get; set; }


        // TimeZone
        public string TimeZone { get; set; }


        // ClearTime
        public TimeSpan ClearTime { get; set; }



        [JsonIgnore]
        public ConcurrentDictionary<string, QueueClassificationDef> QueueClassificationList { get; set; } = new ConcurrentDictionary<string, QueueClassificationDef>();



        [JsonIgnore]
        public ConcurrentDictionary<int, Supergroup> Supergroups { get; set; } = new ConcurrentDictionary<int, Supergroup>();



        public List<string> Queues
        {
            get
            {
                return QueueClassificationList.Values.Select(x => x.QueueID).ToList();
            }
            set
            {
                foreach (var queue in value)
                {
                    var queueClassification = new QueueClassificationDef(queue, "ALL");
                    QueueClassificationList.TryAdd(queueClassification.Key, queueClassification);
                }
            }
        }


        public List<string> AgentGroups
        {
            get
            {
                List<string> ag = new List<string>();
                try
                {
                    ag = Supergroups.FirstOrDefault().Value.AgentGroupList.Select(x => x.Key).ToList();
                }
                catch { }
                return ag;
            }
            set
            {
                if (Supergroups.Count == 0)
                {
                    Supergroups.TryAdd(0, new Supergroup(0, "Default", "Default"));
                }
                if (value != null)
                {
                    foreach (var ag in value)
                    {
                        Supergroups.FirstOrDefault().Value.AgentGroupList.TryAdd(ag, new Agentgroup(ag));
                    }
                }
            }
        }



        [JsonIgnore]
        public QueueAcdCallsList AcdCallsList { get; set; } = new QueueAcdCallsList();



        [JsonIgnore]
        public List<string> Agents { get; set; } = new List<string>();

    }
}
