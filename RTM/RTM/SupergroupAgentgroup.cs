namespace RTM
{
    public class SupergroupAgentgroup
    {
        public SupergroupAgentgroup(int supergroupID, string agentgropupID)
        {
            SupergroupID = supergroupID;
            AgentgropupID = agentgropupID;
        }


        public int SupergroupID { get; private set; }


        public string AgentgropupID { get; private set; }
    }
}
