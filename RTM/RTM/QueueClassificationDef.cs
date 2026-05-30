using Newtonsoft.Json;
using System.Collections.Concurrent;

namespace RTM
{
    public class QueueClassificationDef
    {
        public QueueClassificationDef(string qeueID, string classificationID)
        {
            QueueID = qeueID;
            ClassificationID = classificationID;

            BusinessUnits = new ConcurrentDictionary<int, BusinessUnit>();
        }


        public string QueueID { get; private set; }

        public string ClassificationID { get; private set; }


        [JsonIgnore]
        public ConcurrentDictionary<int, BusinessUnit> BusinessUnits { get; private set; }


        public string Key
        {
            get
            {
                return QueueID + "-" + ClassificationID;
            }
        }
    }
}