namespace RTM
{
    public class BusinessUnitQueueClassification
    {
        public BusinessUnitQueueClassification(int businessUnitID, string qeueID, string classificationID)
        {
            BusinessUnitID = businessUnitID;
            QueueID = qeueID;
            ClassificationID = classificationID;
        }

        /// getters and setters
        public int BusinessUnitID { get; private set; }
        public string QueueID { get; private set; }
        public string ClassificationID { get; private set; }
    }
}

