using System;
using System.Collections.Generic;
using System.Linq;

namespace RTM
{
    public class ChatStatsLive
    {
        public int TotalMessages { get; private set; } = 0;

        public DateTime? FirstCustomerMessageTime { get; private set; } = null;
        public DateTime? FirstAgentResponseTime { get; private set; } = null;

        private List<TimeSpan> AgentResponseTimes = new List<TimeSpan>();
        private List<TimeSpan> CustomerResponseTimes = new List<TimeSpan>();

        private DateTime? LastAgentMessageTime = null;
        private DateTime? LastCustomerMessageTime = null;
        private DateTime? LastMessageTime = null;

        public bool WarningActive { get; private set; } = false;
        private readonly TimeSpan WarningThreshold;

        public ChatStatsLive(TimeSpan? warningThreshold = null)
        {
            WarningThreshold = warningThreshold ?? TimeSpan.FromSeconds(30);
        }

        public void AddMessage(ChatMessage message)
        {
            TotalMessages++;
            LastMessageTime = message.TimeStamp;

            if (message.MsgDirection == "inbound") // מלקוח
            {
                if (FirstCustomerMessageTime == null)
                    FirstCustomerMessageTime = message.TimeStamp;

                if (LastAgentMessageTime != null)
                    CustomerResponseTimes.Add(message.TimeStamp - LastAgentMessageTime.Value);

                LastCustomerMessageTime = message.TimeStamp;
                WarningActive = true;
            }
            else if (message.MsgDirection == "outbound") // מנציג
            {
                if (FirstAgentResponseTime == null && FirstCustomerMessageTime != null)
                    FirstAgentResponseTime = message.TimeStamp;

                if (LastCustomerMessageTime != null)
                {
                    var responseTime = message.TimeStamp - LastCustomerMessageTime.Value;
                    AgentResponseTimes.Add(responseTime);

                    WarningActive = responseTime > WarningThreshold;
                }

                LastAgentMessageTime = message.TimeStamp;
            }
        }

        public TimeSpan? TimeToFirstAgentResponse =>
            (FirstCustomerMessageTime.HasValue && FirstAgentResponseTime.HasValue)
            ? FirstAgentResponseTime - FirstCustomerMessageTime
            : (TimeSpan?)null;

        public TimeSpan? AvgAgentResponseTime => AgentResponseTimes.Count > 0 ? TimeSpan.FromTicks((long)AgentResponseTimes.Average(ts => ts.Ticks)) : (TimeSpan?)null;
        public TimeSpan? MaxAgentResponseTime => AgentResponseTimes.Count > 0 ? AgentResponseTimes.Max() : (TimeSpan?)null;
        public TimeSpan? MinAgentResponseTime => AgentResponseTimes.Count > 0 ? AgentResponseTimes.Min() : (TimeSpan?)null;

        public TimeSpan? AvgCustomerResponseTime => CustomerResponseTimes.Count > 0 ? TimeSpan.FromTicks((long)CustomerResponseTimes.Average(ts => ts.Ticks)) : (TimeSpan?)null;
        public TimeSpan? MaxCustomerResponseTime => CustomerResponseTimes.Count > 0 ? CustomerResponseTimes.Max() : (TimeSpan?)null;
        public TimeSpan? MinCustomerResponseTime => CustomerResponseTimes.Count > 0 ? CustomerResponseTimes.Min() : (TimeSpan?)null;

        private TimeSpan CalculateTotalDuration()
        {
            if (FirstCustomerMessageTime.HasValue && LastMessageTime.HasValue)
                return LastMessageTime.Value - FirstCustomerMessageTime.Value;
            else
                return TimeSpan.Zero;
        }

        public InteractionStatsResult ToStatsResult(string interactionId)
        {
            return new InteractionStatsResult
            {
                InteractionId = interactionId,
                TotalMessages = this.TotalMessages,
                FirstCustomerMessageTime = this.FirstCustomerMessageTime,
                FirstAgentResponseTime = this.FirstAgentResponseTime,
                TimeToFirstAgentResponse = this.TimeToFirstAgentResponse,
                AvgAgentResponseTime = this.AvgAgentResponseTime,
                MaxAgentResponseTime = this.MaxAgentResponseTime,
                MinAgentResponseTime = this.MinAgentResponseTime,
                AvgCustomerResponseTime = this.AvgCustomerResponseTime,
                MaxCustomerResponseTime = this.MaxCustomerResponseTime,
                MinCustomerResponseTime = this.MinCustomerResponseTime,
                WarningActive = this.WarningActive,

                AgentResponseCount = this.AgentResponseTimes.Count,
                AgentResponseTicksSum = this.AgentResponseTimes.Sum(ts => ts.Ticks),
                CustomerResponseCount = this.CustomerResponseTimes.Count,
                CustomerResponseTicksSum = this.CustomerResponseTimes.Sum(ts => ts.Ticks)
            };
        }
    }
}
