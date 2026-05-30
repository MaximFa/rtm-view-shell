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
                        TimeSpan.Zero, timeInWorkgroupQueue, "", "", call.IdInteraction.ClassificationCode, origCallId,
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

                if (_callsList.TryGetValue(interactionId, out var call))
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
                call = _callsList.GetOrAdd(interactionId, id =>
                    new Call(id, _userManagerList, _interactionsList, _dbMng));

                await call.SetCallAsync(
                    interactionType, segmentId, callType, direction, state, stateChangedTime, _id, localUserId,
                    duration, timeInWorkgroupQueue, consultCallId, applicAtt, classificationCode, origCallId,
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
