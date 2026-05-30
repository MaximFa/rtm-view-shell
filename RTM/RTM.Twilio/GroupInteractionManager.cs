using RTM.Types;
using System.Collections.Concurrent;

namespace RTM.Twilio
{
    public class GroupInteractionManager
    {
        public InteractionGroupKey GroupKey { get; private set; }

        // Priority queue to store interactions, ordered by TimeStamp
        private ConcurrentPriorityQueue<DateTime, Interaction> interactionQueue = new ConcurrentPriorityQueue<DateTime, Interaction>();

        // Dictionary to quickly access interactions by ID
        private ConcurrentDictionary<string, Interaction> interactionsById = new ConcurrentDictionary<string, Interaction>();

        public GroupInteractionManager(InteractionGroupKey groupKey)
        {
            GroupKey = groupKey;
        }

        public void AddInteraction(Interaction interaction)
        {
            if (interactionsById.TryAdd(interaction.Id, interaction))
            {
                interactionQueue.Enqueue(interaction.TimeStamp, interaction);
                ScheduleInteractionCheck(interaction);
            }
        }

        public bool RemoveInteraction(string interactionId)
        {
            if (interactionsById.TryRemove(interactionId, out var interaction))
            {
                // Interaction will be automatically removed from the queue when dequeued
                return true;
            }
            return false;
        }

        public Interaction GetLongestInteraction()
        {
            while (interactionQueue.TryPeek(out var timeStamp, out var interaction))
            {
                if (interaction.IsInDoNotCheckPeriod)
                {
                    // Skip interactions in 'do not check' period
                    interactionQueue.TryDequeue(out _, out _);
                }
                else
                {
                    return interaction;
                }
            }
            return null;
        }

        private void ScheduleInteractionCheck(Interaction interaction)
        {
            var delay = interaction.NextCheckTime > DateTime.Now
                ? interaction.NextCheckTime - DateTime.Now
                : TimeSpan.FromMinutes(1);

            Task.Delay(delay).ContinueWith(_ => CheckInteraction(interaction));
        }

        private void CheckInteraction(Interaction interaction)
        {
            // Ensure the interaction still exists
            if (!interactionsById.ContainsKey(interaction.Id))
                return;

            var now = DateTime.Now;
            if ((now - interaction.TimeStamp).TotalMinutes >= 1 && !interaction.IsInDoNotCheckPeriod)
            {
                bool isReal = IsReal(interaction);

                if (!isReal)
                {
                    // Remove interaction
                    interactionsById.TryRemove(interaction.Id, out _);
                    Console.WriteLine($"Removed Interaction ID: {interaction.Id} from group {GroupKey.Workgroup}/{GroupKey.InteractionType}/{GroupKey.Direction}");
                }
                else
                {
                    // Set 'do not check' period
                    interaction.NextCheckTime = now.AddMinutes(5);
                    interaction.IsInDoNotCheckPeriod = true;
                    Console.WriteLine($"Interaction ID: {interaction.Id} is real. Next check at {interaction.NextCheckTime}");

                    // Schedule end of 'do not check' period
                    Task.Delay(TimeSpan.FromMinutes(5)).ContinueWith(_ =>
                    {
                        interaction.IsInDoNotCheckPeriod = false;
                        ScheduleInteractionCheck(interaction);
                    });
                }
            }
            else
            {
                // Re-schedule the check
                ScheduleInteractionCheck(interaction);
            }
        }

        private bool IsReal(Interaction interaction)
        {
            // Implement your actual logic here
            // For demonstration, let's assume interactions with even IDs are real
            int id = int.Parse(interaction.Id);
            return id % 2 == 0;
        }
    }
}
