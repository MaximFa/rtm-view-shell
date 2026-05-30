namespace RTM
{
    public class ChatMessage
    {
        public ChatMessage()
        {

        }

        public ChatMessage(string messageId, string eventType, string direction, string sender, string recipient, string body, string deliveryStatus,
            string interactionId, int segmentId, string userId, DateTime timeStamp) 
        {
            MessageId = messageId;
            EventType = eventType;
            MsgDirection = direction;
            Sender = sender;
            Recipient = recipient;
            Body = body;
            DeliveryStatus = deliveryStatus;
            InteractionId = interactionId;
            SegmentId = segmentId;
            UserId = userId;
            TimeStamp = timeStamp;
        }    


        public string EventType {get; set;}


        public string MessageId { get; set; }


        public string MsgDirection { get; set; }


        public string Sender { get; set; }


        public string Recipient { get; set; }


        public string Body { get; set; }


        public string DeliveryStatus { get; set; }


        public string InteractionId { get; set; }


        public int SegmentId { get; set; }


        public string UserId { get; set; }


        public DateTime TimeStamp { get; set; }

    }
}
