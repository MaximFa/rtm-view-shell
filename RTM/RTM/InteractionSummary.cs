namespace RTM
{
    public class InteractionSummary
    {
        public int TotalInteractions { get; set; }
        public int TotalMessages { get; set; }
        public TimeSpan? AvgAgentResponseTime { get; set; }
        public TimeSpan? AvgCustomerResponseTime { get; set; }
        public TimeSpan? AvgTimeToFirstAgentResponse { get; set; }
        public TimeSpan? AvgTotalDuration { get; set; }
        public int TotalWarningsActive { get; set; }
    }
}
