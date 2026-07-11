namespace RTM.Twilio
{
    public class InteractionGroupKey : IEquatable<InteractionGroupKey>
    {
        public string Workgroup { get; set; }
        public string InteractionType { get; set; }
        public string Direction { get; set; }

        public override bool Equals(object obj)
        {
            return Equals(obj as InteractionGroupKey);
        }

        public bool Equals(InteractionGroupKey other)
        {
            return other != null &&
                   Workgroup == other.Workgroup &&
                   InteractionType == other.InteractionType &&
                   Direction == other.Direction;
        }

        public override int GetHashCode()
        {
            return HashCode.Combine(Workgroup, InteractionType, Direction);
        }
    }
}
