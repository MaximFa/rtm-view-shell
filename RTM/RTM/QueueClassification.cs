using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public struct QueueClassification
    {
        public QueueClassification(string queueId) : this(queueId, "ALL")
        {
        }


        public QueueClassification(string queueId, string classificationId)           
        {
            QueueId = queueId;
            ClassificationId = classificationId;
        }


        public string QueueId { get; set; }


        public string ClassificationId { get; set; }
    }
}
