using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class UnionList : ConcurrentDictionary<int, Union>
    {
        public void addQueueInteraction(IDInteraction interaction)
        {
            //AsyncLogger.Info($"addQueueInteraction interactionId={interaction.InteractionId}" );
            foreach (var union in Values)
            {
                union.addQueueInteraction(interaction);
            }
        }


        public void addAllInteractions(List<IDInteraction> interactionsList, ApplicList applicList)
        {
            foreach (var union in Values)
            {
                union.addAllInteractions(interactionsList, applicList, false);
            }
        }
    }
}
