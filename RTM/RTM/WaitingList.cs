using RTM.Tools;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class WaitingList : Dictionary<string, IDInteraction>
    {
        public string maxWaitInteractionId()
        {
            string interactionId = string.Empty;

            if (Count > 0)
            {
                interactionId = this.Aggregate((c, d) => c.Value.InQueueDateTime < d.Value.InQueueDateTime ? c : d).Key;
            }

            return interactionId;
        }



        public DateTime maxWaitingTime()
        {
            DateTime oldest = DateTime.Now;

            try
            {
                if (Count > 0)
                {
                    oldest = this.Min(t => t.Value.InQueueDateTime);
                }
                else
                {
                    oldest = DateTime.MaxValue;
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WaitingList.maxWaitingTime", ex);
            }

            return oldest;
        }


        public string longestInteractionId()
        {
            string interactionId = string.Empty;
            try
            {
                if (Count > 0)
                {
                    DateTime oldest = this.Min(t => t.Value.InQueueDateTime);
                    var v = this.First(x => x.Value.InQueueDateTime == oldest).Value.InteractionId;
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WaitingList.longestInteractionId", ex);
            }

            return interactionId;
        }
    }
}
