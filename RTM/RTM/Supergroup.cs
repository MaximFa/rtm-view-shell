using System.Collections.Concurrent;

namespace RTM
{
    public class Supergroup
    {
        public Supergroup(int supergroupID, string supergroupName, string description)
        {
            SupergroupID = supergroupID;
            SupergroupName = supergroupName;
            Description = description;

            AgentGroupList = new ConcurrentDictionary<string, Agentgroup>();
        }

        /// getters and setters
        public int SupergroupID { get; private set; }
        public string SupergroupName { get; set; }
        public string Description { get; set; }

        public ConcurrentDictionary<string, Agentgroup> AgentGroupList { get; private set; }
    }
}

