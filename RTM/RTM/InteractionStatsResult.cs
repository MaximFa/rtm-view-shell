using System;

namespace RTM
{
    public class InteractionStatsResult
    {
        public string InteractionId { get; set; }
        public int TotalMessages { get; set; }

        public DateTime? FirstCustomerMessageTime { get; set; }
        public DateTime? FirstAgentResponseTime { get; set; }
        public TimeSpan? TimeToFirstAgentResponse { get; set; }

        public TimeSpan? AvgAgentResponseTime { get; set; }
        public TimeSpan? MaxAgentResponseTime { get; set; }
        public TimeSpan? MinAgentResponseTime { get; set; }

        public TimeSpan? AvgCustomerResponseTime { get; set; }
        public TimeSpan? MaxCustomerResponseTime { get; set; }
        public TimeSpan? MinCustomerResponseTime { get; set; }

        public bool WarningActive { get; set; }

        public DateTime InteractionStartTime { get; set; }
        public TimeSpan TotalDuration { get; set; }

        public int AgentResponseCount { get; set; }
        public long AgentResponseTicksSum { get; set; }

        public int CustomerResponseCount { get; set; }
        public long CustomerResponseTicksSum { get; set; }
    }
}
