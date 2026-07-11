using RTM.Types;

namespace RTM.Twilio
{
    public class LongestInteractionResult
    {
        public string Workgroup { get; set; }

        public string InteractionType { get; set; }

        public string Direction { get; set; }

        public string State { get; set; }

        public Interaction LongestInteraction { get; set; }
    }
}
