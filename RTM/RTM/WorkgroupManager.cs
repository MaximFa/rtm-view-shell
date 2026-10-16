using Microsoft.VisualBasic;
using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace RTM
{
    public class WorkgroupManager
    {
        private readonly string _id;
        private readonly UserManagerList _userManagerList;
        private readonly CallsList _callsList;
        private readonly ConcurrentQueue<string> _lastDisconnectedQ;
        private readonly IDInteractionsList _interactionsList;
        private readonly DBMng _dbMng;


        // [SYNC-PORT 2026-10-15 src=2026-07-15] Consult/warm-transfer (Variant A): retained-consult-leg registry.
        // On a warm (consultative) transfer the initiator stays bridged to the held customer. Her leg is kept
        // alive on its OWN Call while the transferred-to segment runs on a fresh Call; it is finalized by its own
        // terminal event or, as a backstop, by FinalizeStaleConsultLegs. Keyed by segment#interactionId.
        // Only an adapter that sends isConsult=true reaches this path; with isConsult=false nothing changes.
        private readonly ConcurrentDictionary<string, RetainedConsultLeg> _consultRetainedLegs =
            new ConcurrentDictionary<string, RetainedConsultLeg>();

        private static string RetainedKey(string interactionId, int segment) => segment + "#" + interactionId;

        private sealed class RetainedConsultLeg
        {
            public Call Call { get; }
            public string InteractionId { get; }
            public int Segment { get; }
            public string InitiatorUserId { get; }
            public DateTime RetainedAtUtc { get; }

            public RetainedConsultLeg(Call call, string interactionId, int segment, string initiatorUserId, DateTime retainedAtUtc)
            {
                Call = call;
                InteractionId = interactionId;
                Segment = segment;
                InitiatorUserId = initiatorUserId;
                RetainedAtUtc = retainedAtUtc;
            }
        }

        // Number of legs currently retained (observability and tests).
        public int RetainedConsultLegCount => _consultRetainedLegs.Count;



        public WorkgroupManager(
            string id,
            UserManagerList userManagerList,
            CallsList callsList,
            ConcurrentQueue<string> lastDisconnectedQ,
            IDInteractionsList interactionsList,
            DBMng dbMng)
        {
            try
            {
                _id = id;
                _userManagerList = userManagerList;
                _callsList = callsList;
                _lastDisconnectedQ = lastDisconnectedQ;
                _interactionsList = interactionsList;
                _dbMng = dbMng;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WorkgroupManager.WorkgroupManager", ex);
            }
        }
   




        // Legacy version (kept)
        public async Task<string> interactionRemoved1(
            string interactionId, int segmentId, bool isDisconnect, string origCallId, string localUserId,
            string state, TimeSpan timeInWorkgroupQueue, bool isCallbackRequest, long messageId)
        {
            Call call = null;
            string lastMessageSid = string.Empty;

            try
            {
                if (_callsList.TryGetValue(interactionId, out call))
                {
                    lastMessageSid = call.IdInteraction.LastMessageSid;

                    await call.SetCallAsync(
                        call.IdInteraction.InteractionType, segmentId, call.IdInteraction.CallType, call.IdInteraction.Direction, state,
                        DateTime.Now, _id, localUserId,
                        TimeSpan.Zero, timeInWorkgroupQueue, false, "", "", call.IdInteraction.ClassificationCode, origCallId,
                        "", "", new List<string>(),
                        false, "", "",
                        "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
                        isCallbackRequest, messageId);

                    _callsList.TryRemove(interactionId, out call);
                    call.IdInteraction.Disconnected();
                }
                else
                {
                    AsyncLogger.Error($"WorkgroupManager.interactionRemoved1 interactionId={interactionId} doesn't exist");
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WorkgroupManager.interactionRemoved1", ex);
            }

            return lastMessageSid;
        }


        /*
                public async Task<string> interactionRemoved2(
                 string interactionId, int segmentId, bool isDisconnect, string origCallId,
                 string localUserId, string state, TimeSpan timeInWorkgroupQueue,
                 bool isCallbackRequest, long messageId)
                {
                    Call call = null;
                    string lastMessageSid = string.Empty;

                    try
                    {
                        // Always close the segment (important even if Call is missing)
                        bool changed = _interactionsList.MarkDisconnected(interactionId, segmentId);
                        int activeCountAfter = _interactionsList.GetActiveCount(interactionId);

                        if (changed)
                        {
                            AsyncLogger.Info($"interactionRemoved: segment disconnected | interactionId={interactionId} segmentId={segmentId} activeCountAfter={activeCountAfter} state={state} isDisconnect={isDisconnect}");
                        }
                        else
                        {
                            AsyncLogger.Info($"interactionRemoved: segment not found or already disconnected | interactionId={interactionId} segmentId={segmentId} activeCountAfter={activeCountAfter} state={state} isDisconnect={isDisconnect}");
                        }

                        // If no active segments remain -> schedule deferred call removal
                        if (!_interactionsList.HasInteractionId(interactionId))
                        {
                            var due = DateTime.UtcNow.Add(CallRemovalDelay);
                            _pendingCallRemovalUtc[interactionId] = due;

                            AsyncLogger.Info($"CallCleanup SCHEDULE | interactionId={interactionId} dueUtc={due:O} delaySec={CallRemovalDelay.TotalSeconds} state={state} isDisconnect={isDisconnect}");
                        }

                        // Only if Call exists -> keep existing behavior (DB update, lastMessageSid)
                        if (_callsList.TryGetValue(interactionId, out call))
                        {
                            lastMessageSid = call.IdInteraction.LastMessageSid;

                            await call.SetCallAsync(
                                call.IdInteraction.InteractionType, segmentId, call.IdInteraction.CallType,
                                call.IdInteraction.Direction, state,
                                DateTime.Now, _id, localUserId,
                                TimeSpan.Zero, timeInWorkgroupQueue, "", "", call.IdInteraction.ClassificationCode,
                                origCallId, "", "", new List<string>(),
                                false, "", "",
                                "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
                                isCallbackRequest, messageId);
                        }
                        else
                        {
                            AsyncLogger.Info($"interactionRemoved: call not found (out-of-order or already cleaned) | interactionId={interactionId} segmentId={segmentId} state={state}");
                        }
                    }
                    catch (Exception ex)
                    {
                        AsyncLogger.Error("WorkgroupManager.interactionRemoved", ex);
                    }

                    return lastMessageSid;
                }
        */



        public async Task<string> interactionRemoved(
            string interactionId, int segmentId, bool isDisconnect, string origCallId, string localUserId,
            string state, TimeSpan timeInWorkgroupQueue, bool isCallbackRequest, long messageId)
        {
            string lastMessageSid = string.Empty;

            try
            {
                AsyncLogger.Info($"WorkgroupManager.interactionRemoved | START | interactionId={interactionId} seg={segmentId} state={state} isDisconnect={isDisconnect}");

                // [SYNC-PORT 2026-10-15 src=2026-07-15] A terminal for a retained consult leg finalizes the initiator's
                // OWN Call, not the later-segment Call that sits in _callsList, so the transferred-to agent is untouched.
                if (_consultRetainedLegs.TryRemove(RetainedKey(interactionId, segmentId), out var retained))
                {
                    return await finalizeConsultLeg(retained, state, origCallId, localUserId, timeInWorkgroupQueue, isCallbackRequest, messageId, "EVENT");
                }

                if (_callsList.TryGetValue(interactionId, out var call))
                {
                    lastMessageSid = call.IdInteraction.LastMessageSid;

                    await call.SetCallAsync(
                        call.IdInteraction.InteractionType, segmentId, call.IdInteraction.CallType,
                        call.IdInteraction.Direction, state,
                        DateTime.Now, _id, localUserId,
                        TimeSpan.Zero, timeInWorkgroupQueue, false, "", "", call.IdInteraction.ClassificationCode,
                        origCallId, "", "", new List<string>(),
                        false, "", "",
                        "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
                        isCallbackRequest, messageId);

                    bool ended = _interactionsList.MarkSegmentEnded(interactionId, segmentId);
                    int activeCount = _interactionsList.GetActiveCount(interactionId);

                    AsyncLogger.Info($"WorkgroupManager.interactionRemoved | AFTER_SET_CALL | interactionId={interactionId} seg={segmentId} ended={ended} activeCount={activeCount}");

                    if (!_interactionsList.HasInteractionId(interactionId))
                    {
                        bool removed = _callsList.TryRemove(interactionId, out _);
                        AsyncLogger.Info($"WorkgroupManager.interactionRemoved | CALL_REMOVED | interactionId={interactionId} removed={removed}");
                    }
                }
                else
                {
                    // No Call: we cannot run state machine, so we ONLY do bookkeeping.
                    bool ended = _interactionsList.MarkSegmentEnded(interactionId, segmentId);
                    int activeCount = _interactionsList.GetActiveCount(interactionId);

                    AsyncLogger.Error($"WorkgroupManager.interactionRemoved | CALL_MISSING | interactionId={interactionId} seg={segmentId} state={state} ended={ended} activeCount={activeCount}");
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WorkgroupManager.interactionRemoved", ex);
            }

            return lastMessageSid;
        }


        // [SYNC-PORT 2026-10-15 src=2026-07-15] Finalize a retained consult leg on its OWN Call (real terminal event or
        // the lifetime backstop). Runs the state machine for the retained segment, so "completed"/"wrapping" ends the
        // talk, ends the incoming call and resolves LastNoPhone for the initiator; OnPhone flips off for her only.
        private async Task<string> finalizeConsultLeg(
            RetainedConsultLeg leg, string state, string origCallId, string localUserId,
            TimeSpan timeInWorkgroupQueue, bool isCallbackRequest, long messageId, string reason)
        {
            string lastMessageSid = string.Empty;
            var call = leg.Call;

            try
            {
                lastMessageSid = call.IdInteraction.LastMessageSid;

                await call.SetCallAsync(
                    call.IdInteraction.InteractionType, leg.Segment, call.IdInteraction.CallType,
                    call.IdInteraction.Direction, state,
                    DateTime.Now, _id, localUserId,
                    TimeSpan.Zero, timeInWorkgroupQueue, false, "", "", call.IdInteraction.ClassificationCode,
                    origCallId, "", "", new List<string>(),
                    false, "", "",
                    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
                    isCallbackRequest, messageId);

                bool ended = _interactionsList.MarkSegmentEnded(leg.InteractionId, leg.Segment);
                int activeCount = _interactionsList.GetActiveCount(leg.InteractionId);

                AsyncLogger.Info($"WorkgroupManager.finalizeConsultLeg | interactionId={leg.InteractionId} seg={leg.Segment} initiator={leg.InitiatorUserId} reason={reason} state={state} ended={ended} activeCount={activeCount}");

                if (!_interactionsList.HasInteractionId(leg.InteractionId))
                {
                    bool removed = _callsList.TryRemove(leg.InteractionId, out _);
                    AsyncLogger.Info($"WorkgroupManager.finalizeConsultLeg | CALL_REMOVED | interactionId={leg.InteractionId} removed={removed}");
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WorkgroupManager.finalizeConsultLeg", ex);
            }

            return lastMessageSid;
        }


        // [SYNC-PORT 2026-10-15 src=2026-07-15] Lifetime backstop: any retained consult leg older than maxAge is finalized
        // through the same path as a real terminal. A real consult is far shorter than the default 30 min, so a genuine
        // one is never cut short; a stranded leg is cleaned within the bound. Logged at Error on every firing.
        // (Verify-before-kill, the absolute ceiling and alive re-anchoring are later rounds: 08-19, 09-07.)
        public async Task FinalizeStaleConsultLegs(TimeSpan maxAge)
        {
            await FinalizeStaleConsultLegs(maxAge, DateTime.UtcNow);
        }

        internal async Task FinalizeStaleConsultLegs(TimeSpan maxAge, DateTime nowUtc)
        {
            try
            {
                foreach (var kvp in _consultRetainedLegs)
                {
                    var leg = kvp.Value;
                    TimeSpan age = nowUtc.Subtract(leg.RetainedAtUtc);

                    if (age < maxAge)
                    {
                        continue;
                    }

                    if (_consultRetainedLegs.TryRemove(kvp.Key, out var stale))
                    {
                        AsyncLogger.Error($"WorkgroupManager.FinalizeStaleConsultLegs | TIMEOUT | wg={_id} interactionId={stale.InteractionId} seg={stale.Segment} initiator={stale.InitiatorUserId} ageSec={(int)age.TotalSeconds} maxSec={(int)maxAge.TotalSeconds}");
                        await finalizeConsultLeg(stale, "completed", "", stale.InitiatorUserId, TimeSpan.Zero, false, DateTime.UtcNow.Ticks, "TIMEOUT");
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WorkgroupManager.FinalizeStaleConsultLegs", ex);
            }
        }



        // [SYNC-PORT 2026-10-15 src=2026-07-15] Authoritative terminal helper: finalize every retained consult leg of one
        // interaction (Engine.interactionRemovedAll calls it before closing the remaining active segments).
        public async Task FinalizeConsultLegsForInteraction(string interactionId)
        {
            try
            {
                foreach (var kvp in _consultRetainedLegs)
                {
                    if (kvp.Value.InteractionId == interactionId && _consultRetainedLegs.TryRemove(kvp.Key, out var leg))
                    {
                        await finalizeConsultLeg(leg, "completed", "", leg.InitiatorUserId, TimeSpan.Zero, false, DateTime.UtcNow.Ticks, "REMOVED_ALL");
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WorkgroupManager.FinalizeConsultLegsForInteraction", ex);
            }
        }



        public async Task<Call> interactionAction(
            bool isAdded, string interactionId, int segmentId, bool isDisconnect, string callType, string interactionType,
            string direction, string state, DateTime stateChangedTime,
            TimeSpan duration, TimeSpan timeInWorkgroupQueue, bool isConsult, string consultCallId, string applicAtt,
            string classificationCode, string localUserId, string origCallId,
            string customCallData, string calculatedStatus, string calculatedStatusTime, string c4uState, string localName,
            List<string> changedAttributeNames,
            bool isHeld, string remoteAddress, string lastMessageSid,
            string customCallData1, string customCallData2, string customCallData3, string customCallData4, string customCallData5, string customCallData6,
            string customCallData7, string customCallData8, string customCallData9, string customCallData10, string customCallData11, string customCallData12,
            string customCallData13, string customCallData14, string customCallData15, string customCallData16, string customCallData17, string customCallData18,
            string customCallData19, string customCallData20, long messageId)
        {
            Call call = null;

            try
            {
                // [SYNC-PORT 2026-10-15 src=2026-07-15] Consult rotation. consultConfirmed is what Call sees: true only when
                // this event really rotated a warm transfer (isConsult from the adapter AND the initiator matches).
                bool consultConfirmed = false;

                // (1) An event addressed to an already-retained consult segment goes to that leg's OWN Call.
                if (_consultRetainedLegs.TryGetValue(RetainedKey(interactionId, segmentId), out var retainedForEvent))
                {
                    call = retainedForEvent.Call;
                    AsyncLogger.Info($"WorkgroupManager.interactionAction | CONSULT_ROUTED | interactionId={interactionId} seg={segmentId} state={state}");
                }
                // (2) Warm-transfer segment advance: retain the initiator's current leg on its own Call and give the
                //     transferred-to segment a FRESH Call, so two live agents never share one moving Call.
                else if (isConsult && segmentId > 1
                         && _callsList.TryGetValue(interactionId, out var existingCall)
                         && existingCall.IdInteraction != null
                         && existingCall.IdInteraction.Segment < segmentId
                         && !existingCall.IdInteraction.IsDisconnected)
                {
                    string initiatorUserId = existingCall.IdInteraction.UserId;

                    if (!string.IsNullOrEmpty(initiatorUserId) && initiatorUserId == consultCallId)
                    {
                        int retainedSegment = existingCall.IdInteraction.Segment;
                        _consultRetainedLegs[RetainedKey(interactionId, retainedSegment)] =
                            new RetainedConsultLeg(existingCall, interactionId, retainedSegment, initiatorUserId, DateTime.UtcNow);

                        call = new Call(interactionId, _userManagerList, _interactionsList, _dbMng);
                        _callsList[interactionId] = call;
                        consultConfirmed = true;

                        AsyncLogger.Info($"WorkgroupManager.interactionAction | CONSULT_ROTATED | interactionId={interactionId} seg={segmentId} retainedSeg={retainedSegment} initiator={initiatorUserId}");
                    }
                    else
                    {
                        // Consult requested but the initiator does not match: fall back to the ordinary path.
                        AsyncLogger.Error($"WorkgroupManager.interactionAction | CONSULT_ASSERT_FAILED | interactionId={interactionId} seg={segmentId} initiator={initiatorUserId} consultCallId={consultCallId}");
                        call = _callsList.GetOrAdd(interactionId, id => new Call(id, _userManagerList, _interactionsList, _dbMng));
                    }
                }
                else
                {
                    call = _callsList.GetOrAdd(interactionId, id =>
                        new Call(id, _userManagerList, _interactionsList, _dbMng));
                }

                await call.SetCallAsync(
                    interactionType, segmentId, callType, direction, state, stateChangedTime, _id, localUserId,
                    duration, timeInWorkgroupQueue, consultConfirmed, consultCallId, applicAtt, classificationCode, origCallId,
                    calculatedStatus, calculatedStatusTime, changedAttributeNames,
                    isHeld, remoteAddress, lastMessageSid,
                    customCallData1, customCallData2, customCallData3, customCallData4, customCallData5, customCallData6,
                    customCallData7, customCallData8, customCallData9, customCallData10, customCallData11, customCallData12,
                    customCallData13, customCallData14, customCallData15, customCallData16, customCallData17, customCallData18,
                    customCallData19, customCallData20, false, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("WorkgroupManager.interactionAction", ex);
            }

            return call;
        }
    }
}
