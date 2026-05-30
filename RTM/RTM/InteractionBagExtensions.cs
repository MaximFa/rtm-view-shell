namespace RTM
{
    public static class InteractionBagExtensions
    {
        public static List<InteractionStatsResult> GetChatStatsResults(this IDInteractionBag bag)
        {
            var results = new List<InteractionStatsResult>();

            foreach (var interaction in bag.Bag)
            {
                if (interaction.InteractionType != "Chat")
                    continue;

                if (!interaction.ChatMessages.Any())
                    continue;

                results.Add(interaction.ChatStats.ToStatsResult(interaction.InteractionId));
            }

            return results;
        }

        public static InteractionSummary GetChatSummary(this IDInteractionBag bag)
        {
            int totalInteractions = 0;
            int totalMessages = 0;
            int totalWarningsActive = 0;

            long agentTicksSum = 0;
            int agentCount = 0;

            long customerTicksSum = 0;
            int customerCount = 0;

            long firstAgentResponseTicksSum = 0;
            int firstAgentResponseCount = 0;

            long totalDurationTicksSum = 0;

            foreach (var interaction in bag.Bag)
            {
                if (interaction.InteractionType != "Chat")
                    continue;

                if (!interaction.ChatMessages.Any())
                    continue;

                var stats = interaction.ChatStats.ToStatsResult(interaction.InteractionId);

                totalInteractions++;
                totalMessages += stats.TotalMessages;

                if (stats.WarningActive)
                    totalWarningsActive++;

                if (stats.AgentResponseTicksSum > 0 && stats.AgentResponseCount > 0)
                {
                    agentTicksSum += stats.AgentResponseTicksSum;
                    agentCount += stats.AgentResponseCount;
                }

                if (stats.CustomerResponseTicksSum > 0 && stats.CustomerResponseCount > 0)
                {
                    customerTicksSum += stats.CustomerResponseTicksSum;
                    customerCount += stats.CustomerResponseCount;
                }

                if (stats.TimeToFirstAgentResponse.HasValue)
                {
                    firstAgentResponseTicksSum += stats.TimeToFirstAgentResponse.Value.Ticks;
                    firstAgentResponseCount++;
                }

                totalDurationTicksSum += stats.TotalDuration.Ticks;
            }

            if (totalInteractions == 0)
                return new InteractionSummary();

            TimeSpan? avgAgentResponseTime = (agentCount > 0) ? TimeSpan.FromTicks(agentTicksSum / agentCount) : (TimeSpan?)null;
            TimeSpan? avgCustomerResponseTime = (customerCount > 0) ? TimeSpan.FromTicks(customerTicksSum / customerCount) : (TimeSpan?)null;
            TimeSpan? avgTimeToFirstAgentResponse = (firstAgentResponseCount > 0) ? TimeSpan.FromTicks(firstAgentResponseTicksSum / firstAgentResponseCount) : (TimeSpan?)null;
            TimeSpan? avgTotalDuration = TimeSpan.FromTicks(totalDurationTicksSum / totalInteractions);

            return new InteractionSummary
            {
                TotalInteractions = totalInteractions,
                TotalMessages = totalMessages,
                TotalWarningsActive = totalWarningsActive,
                AvgAgentResponseTime = avgAgentResponseTime,
                AvgCustomerResponseTime = avgCustomerResponseTime,
                AvgTimeToFirstAgentResponse = avgTimeToFirstAgentResponse,
                AvgTotalDuration = avgTotalDuration
            };
        }
    }
}
