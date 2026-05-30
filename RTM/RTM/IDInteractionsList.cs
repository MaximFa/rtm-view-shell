using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;

namespace RTM
{
    public class IDInteractionsList
    {
        private ConcurrentDictionary<string, IDInteraction> _yesterdayInteractions = null;
        private ConcurrentDictionary<string, IDInteraction> _interactions = new ConcurrentDictionary<string, IDInteraction>();

        // Active segments count by InteractionId (active == IsDisconnected == false)
        private ConcurrentDictionary<string, int> _activeCounts = new ConcurrentDictionary<string, int>();

        private readonly UnionList _unionList;

        public IDInteractionsList(UnionList unionList)
        {
            _unionList = unionList;
        }

        public void Clear()
        {
            _yesterdayInteractions = _interactions;
            _interactions = new ConcurrentDictionary<string, IDInteraction>();
            _activeCounts = new ConcurrentDictionary<string, int>();
        }

        public IDInteraction getNewInteraction(string interactionId, int segment, DBMng dbMng, bool isDBInserted)
        {
            return new IDInteraction(interactionId, segment, dbMng, isDBInserted);
        }

        public void Add(IDInteraction interaction, bool updateUnionList)
        {
            try
            {
                if (interaction.Segment > 1)
                {
                    interaction.IsTransferred = true;

                    var prevKey = (interaction.Segment - 1) + interaction.InteractionId;
                    if (_interactions.TryGetValue(prevKey, out var lastInteraction) && lastInteraction != null)
                    {
                        interaction.LastUserId = lastInteraction.UserId;
                        interaction.LastWorkgroup = lastInteraction.Workgroup;
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("IDInteractionsList.Add", ex);
            }

            if (_interactions.TryAdd(interaction.Key, interaction))
            {
                if (!interaction.IsDisconnected)
                {
                    _activeCounts.AddOrUpdate(interaction.InteractionId, 1, (_, c) => c + 1);
                }
            }

            if (updateUnionList)
            {
                _unionList.addQueueInteraction(interaction);
            }
        }

        public void Remove(string interactionKey)
        {
            if (_interactions.TryRemove(interactionKey, out var removed) && removed != null)
            {
                if (!removed.IsDisconnected)
                {
                    DecrementActiveCount(removed.InteractionId);
                }
            }
        }

        public List<IDInteraction> getList()
        {
            return _interactions.Values.ToList();
        }

        public IDInteraction getInteraction(string interactionId, int segment)
        {
            var interactionKey = segment + interactionId;
            _interactions.TryGetValue(interactionKey, out var interaction);
            return interaction;
        }

        // Meaning: has ANY ACTIVE segment
        public bool HasInteractionId(string interactionId)
        {
            return _activeCounts.ContainsKey(interactionId);
        }

        public int GetActiveCount(string interactionId)
        {
            return _activeCounts.TryGetValue(interactionId, out var c) ? c : 0;
        }

        // Bookkeeping only: does NOT touch queue/talk/abandon flags.
        public bool MarkSegmentEnded(string interactionId, int segment)
        {
            var key = segment + interactionId;

            if (!_interactions.TryGetValue(key, out var interaction) || interaction == null)
            {
                AsyncLogger.Info($"IDInteractionsList.MarkSegmentEnded | NOT_FOUND | interactionId={interactionId} seg={segment}");
                return false;
            }

            if (interaction.IsDisconnected)
            {
                AsyncLogger.Info($"IDInteractionsList.MarkSegmentEnded | ALREADY_ENDED | interactionId={interactionId} seg={segment}");
                return false;
            }

            int before = GetActiveCount(interactionId);

            interaction.MarkSegmentEnded();
            DecrementActiveCount(interactionId);

            int after = GetActiveCount(interactionId);

            AsyncLogger.Info($"IDInteractionsList.MarkSegmentEnded | OK | interactionId={interactionId} seg={segment} activeCountBefore={before} activeCountAfter={after}");
            return true;
        }

        private void DecrementActiveCount(string interactionId)
        {
            while (true)
            {
                if (!_activeCounts.TryGetValue(interactionId, out var current))
                    return;

                if (current <= 1)
                {
                    if (_activeCounts.TryRemove(interactionId, out _))
                        return;

                    continue;
                }

                if (_activeCounts.TryUpdate(interactionId, current - 1, current))
                    return;
            }
        }
    }
}
