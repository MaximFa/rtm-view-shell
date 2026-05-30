using RTM.Types;
using System.Collections.Concurrent;

namespace RTM.Twilio
{
    public class InteractionManager
    {
        // A concurrent dictionary to store groups of interactions
        private ConcurrentDictionary<InteractionGroupKey, GroupInteractionManager> groupManagers = new ConcurrentDictionary<InteractionGroupKey, GroupInteractionManager>();

        public void AddInteraction(Interaction interaction)
        {
            var groupKey = new InteractionGroupKey
            {
                Workgroup = interaction.Workgroup,
                InteractionType = interaction.InteractionType,
                Direction = interaction.Direction
            };

            var groupManager = groupManagers.GetOrAdd(groupKey, key => new GroupInteractionManager(key));
            groupManager.AddInteraction(interaction);
        }

        public void RemoveInteraction(string interactionId)
        {
            foreach (var groupManager in groupManagers.Values)
            {
                if (groupManager.RemoveInteraction(interactionId))
                    break;
            }
        }

        // For demonstration purposes, output the longest interaction per group
        public void OutputLongestInteractions()
        {
            foreach (var groupManager in groupManagers.Values)
            {
                var longestInteraction = groupManager.GetLongestInteraction();
                if (longestInteraction != null)
                {
                    var now = DateTime.Now;
                    Console.WriteLine($"Workgroup: {groupManager.GroupKey.Workgroup}");
                    Console.WriteLine($"InteractionType: {groupManager.GroupKey.InteractionType}");
                    Console.WriteLine($"Direction: {groupManager.GroupKey.Direction}");
                    Console.WriteLine($"Longest Interaction ID: {longestInteraction.Id}");
                    Console.WriteLine($"TimeStamp: {longestInteraction.TimeStamp}");
                    Console.WriteLine($"Duration in System: {(now - longestInteraction.TimeStamp).TotalMinutes} minutes");
                    Console.WriteLine(new string('-', 50));
                }
            }
        }
    }
}
