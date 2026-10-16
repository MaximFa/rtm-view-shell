using RTM.Tools;
using System.Collections.Concurrent;


namespace RTM
{
    public class Call
    {
        private IDInteractionsList InteractionsList { get; set; }

        
        // Interaction Id
        public string InteractionId { get; set; }


        // Segment
        //public int Segment { get; set; } = 1;


        // IDInteraction
        public IDInteraction IdInteraction { get; private set; }
 

        private DateTime StateStart { get; set; } = DateTime.Now;

        public string State { get; set; } = string.Empty;


        


        public string CalculatedStatus { get; set; } = string.Empty;

        public string CalculatedStatusTime { get; set; } = string.Empty;

        public TimeSpan TimeInQueue { get; set; } = TimeSpan.Zero;

        // [SYNC-PORT 2026-10-15 src=2026-07-30] Ringing round-2: the worker THIS interaction currently shows calc
        // "Ringing" for (empty otherwise). Held on the interaction so every clearer erases exactly the user this ring
        // was asserted for, independent of the triggering event's userId (unreliable on re-queue / cancel events).
        public string TaggedRingingUserId { get; set; } = string.Empty;

        // [SYNC-PORT 2026-10-15 src=2026-08-05] Wall-clock of the last engine event for this call (stamped at the top of every
        // SetCall). The max-live backstop measures silence as now - LastEventUtc; an orphan gets no events after accept.
        public DateTime LastEventUtc { get; internal set; } = DateTime.Now;


        //public List<string> Users { get; set; } = new List<string>();


        private UserManagerList UserManagerList { get; set; } = null;

        private ConcurrentDictionary<string, StateDuration> StateDurationList { get; set; } = new ConcurrentDictionary<string, StateDuration>();


        private DBMng DBMng = null;


        public delegate void CallStateChangedEventHandler(object sender, CallStateChangedEventArgs e);
        public event CallStateChangedEventHandler CallStateChangedEvent;


        private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(1, 1);



        // Call
        public Call(string interactionId, UserManagerList userManagerList, IDInteractionsList interactionsList, DBMng dbMng)
        {
            try
            {
                InteractionId = interactionId;

                DBMng = dbMng;
                InteractionsList = interactionsList;             
                UserManagerList = userManagerList;
               
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Call.Call", ex);
            }
        }




        // Set Call Async
        // [SYNC-PORT 2026-10-15 src=2026-07-15] isConsult: true only when WorkgroupManager actually rotated a warm transfer.
        public async Task SetCallAsync(string interactionType, int segmantId, string callType, string direction, string state, DateTime stateChangedTime, string workgroup, string userId,
          TimeSpan duration, TimeSpan timeInWorkgroupQueue, bool isConsult, string consultCallId, string applicAtt, string classificationCode, string origCallId,
          string calculatedStatus, string calculatedStatusTime, List<string> changedAttributeNames,
          bool isHeld, string remoteAddress, string lastMessageSid, 
           string customCallData1, string customCallData2, string customCallData3, string customCallData4, string customCallData5, string customCallData6,
           string customCallData7, string customCallData8, string customCallData9, string customCallData10, string customCallData11, string customCallData12,
           string customCallData13, string customCallData14, string customCallData15, string customCallData16, string customCallData17, string customCallData18,
           string customCallData19, string customCallData20, bool isCallbackRequest, long messageId)
        {
            // Wait for access to the semaphore
            await _semaphore.WaitAsync();
            try
            {
                // Critical section: only one execution per Call instance at a time
                SetCall(interactionType, segmantId, callType, direction, state, stateChangedTime, workgroup, userId,
                  duration, timeInWorkgroupQueue, isConsult, consultCallId, applicAtt, classificationCode, origCallId,
                  calculatedStatus, calculatedStatusTime, changedAttributeNames,
                  isHeld, remoteAddress, lastMessageSid, customCallData1, customCallData2, customCallData3, customCallData4, customCallData5, customCallData6,
                   customCallData7, customCallData8, customCallData9, customCallData10, customCallData11, customCallData12,
                   customCallData13, customCallData14, customCallData15, customCallData16, customCallData17, customCallData18,
                   customCallData19, customCallData20, isCallbackRequest, messageId);
            }
            finally
            {
                // Release the semaphore for the next waiting task (if any)
                _semaphore.Release();
            }
        }





        // Set Call
        public void SetCall(string interactionType, int segmantId, string callType, string direction, string state, DateTime stateChangedTime, string workgroup, string userId,
          TimeSpan duration, TimeSpan timeInWorkgroupQueue, bool isConsult, string consultCallId, string applicAtt, string classificationCode, string origCallId,
          string calculatedStatus, string calculatedStatusTime, List<string> changedAttributeNames,
          bool isHeld, string remoteAddress, string lastMessageSid, 
           string customCallData1, string customCallData2, string customCallData3, string customCallData4, string customCallData5, string customCallData6,
           string customCallData7, string customCallData8, string customCallData9, string customCallData10, string customCallData11, string customCallData12,
           string customCallData13, string customCallData14, string customCallData15, string customCallData16, string customCallData17, string customCallData18,
           string customCallData19, string customCallData20, bool isCallbackRequest, long messageId)
        {
            try
            {
                // [SYNC-PORT 2026-10-15 src=2026-08-05] Any engine event for this call counts as activity for the orphan backstop.
                LastEventUtc = DateTime.Now;

                AsyncLogger.Info($"SetCall InteractionId={InteractionId} SegmentId={segmantId} interactionType={interactionType} callType={callType} direction={direction} state={state} " +
                    $"stateChangedTime={stateChangedTime} workgroup={workgroup} userId={userId} isCallbackRequest={isCallbackRequest} remoteAddress={remoteAddress} customCallData19={customCallData19} customCallData20={customCallData20}");

                string LastState = string.Empty;

                IdInteraction = InteractionsList.getInteraction(InteractionId, segmantId);

                // New Interaction
                if (IdInteraction == null)
                {                   
                    IdInteraction = InteractionsList.getNewInteraction(InteractionId, segmantId, DBMng, false);
                    IdInteraction.Workgroup = workgroup;
                    IdInteraction.InteractionType = interactionType;

                    InteractionsList.Add(IdInteraction, true);


                    if (segmantId > 1)
                    {
                        var LastIdInteraction = InteractionsList.getInteraction(InteractionId, segmantId-1);

                        if (LastIdInteraction != null && isConsult)
                        {
                            // [SYNC-PORT 2026-10-15 src=2026-07-15] Warm transfer: the initiator stays bridged to the held
                            // customer. Do NOT OutQueue / EndTalk / release her here: her leg is retained on its own Call
                            // (WorkgroupManager) and finalized by its own terminal or the lifetime backstop.
                            AsyncLogger.Info($"SetCall CONSULT_RETAINED interactionId={InteractionId} retainedSeg={segmantId - 1} initiator={LastIdInteraction.UserId}");

                            // A prior source status (the reserved "waiting" token arrives with onPhone=false) may have
                            // switched her OnPhone off while she still holds the customer. Re-assert the on-phone calc
                            // status ONLY in that case, so the later corrective status restores via _isWaitForCall.
                            if (LastIdInteraction.IsHeld
                                && !string.IsNullOrEmpty(LastIdInteraction.UserId)
                                && UserManagerList.ContainsKey(LastIdInteraction.UserId))
                            {
                                UserManager initiatorMng = UserManagerList[LastIdInteraction.UserId];
                                if (!initiatorMng.OnPhone)
                                {
                                    AsyncLogger.Info($"SetCall CONSULT_ONPHONE_REASSERT interactionId={InteractionId} initiator={LastIdInteraction.UserId}");
                                    initiatorMng.setStatus(true, "Hold", "Hold", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                                }
                            }
                        }
                        else if (LastIdInteraction != null)
                        {
                            if (LastIdInteraction.IsInQueue)
                            {
                                LastIdInteraction.OutQueue(false);
                            }

                            bool isTalk = LastIdInteraction.EndTalk();

                            if (!string.IsNullOrEmpty(LastIdInteraction.UserId) && UserManagerList.ContainsKey(LastIdInteraction.UserId))
                            {
                                UserManager userMng1 = UserManagerList[LastIdInteraction.UserId];                             

                                if (isTalk)
                                {
                                    if (LastIdInteraction.Direction == "Incoming")
                                    {
                                        userMng1.endIncomingCall(this, LastIdInteraction.Workgroup);
                                    }
                                    if (direction == "Outgoing")
                                    {
                                        userMng1.endOutgoingCall(this, LastIdInteraction.Workgroup);
                                    }
                                }

                                // [SYNC-PORT 2026-10-15 src=2026-07-15] Guard kept on purpose (legacy retired it): the adapter in
                                // production still sends the transfer initiator in customCallData19 and never isConsult, so this
                                // guard is what keeps her on the call today. A new adapter sends "" here, which makes the guard
                                // a no-op and the release unconditional, exactly as in the legacy fix.
                                if (LastIdInteraction.UserId != customCallData19)
                                {
                                    userMng1.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                                }                               
                            }
                        }
                    }
                }
                // Exists Interaction
                else
                {             
                   if (IdInteraction.IsDisconnected)
                   {
                        return; 
                   } 
                   LastState = IdInteraction.State;

                   // [SYNC-PORT 2026-10-15 src=2026-07-28] Import-race self-heal: re-route this already-registered
                   // interaction so a union whose bag lost it (concurrent-attach import) re-adds it now. Idempotent and
                   // O(1)-guarded per union (Union.addQueueInteraction / InteractionKeys); a no-op when nothing was lost.
                   InteractionsList.EnsureRouted(IdInteraction);
                }
                
                IdInteraction.ClassificationCode = classificationCode;
                IdInteraction.CustomCallData = string.Empty;
                IdInteraction.RemoteAddress = remoteAddress;


                IdInteraction.LastMessageSid = lastMessageSid;


                // set params
                IdInteraction.Workgroup = workgroup;
                //IdInteraction.InteractionType = interactionType;
                IdInteraction.CallType = callType;
                IdInteraction.Direction = direction;

                
                // CustomCallData 1-20
                IdInteraction.CustomCallData1 = !string.IsNullOrEmpty(customCallData1) ? customCallData1 : IdInteraction.CustomCallData1;
                IdInteraction.CustomCallData2 = !string.IsNullOrEmpty(customCallData2) ? customCallData2 : IdInteraction.CustomCallData2;
                IdInteraction.CustomCallData3 = !string.IsNullOrEmpty(customCallData3) ? customCallData3 : IdInteraction.CustomCallData3;
                IdInteraction.CustomCallData4 = !string.IsNullOrEmpty(customCallData4) ? customCallData4 : IdInteraction.CustomCallData4;
                IdInteraction.CustomCallData5 = !string.IsNullOrEmpty(customCallData5) ? customCallData5 : IdInteraction.CustomCallData5;
                IdInteraction.CustomCallData6 = !string.IsNullOrEmpty(customCallData6) ? customCallData6 : IdInteraction.CustomCallData6;
                IdInteraction.CustomCallData7 = !string.IsNullOrEmpty(customCallData7) ? customCallData7 : IdInteraction.CustomCallData7;
                IdInteraction.CustomCallData8 = !string.IsNullOrEmpty(customCallData8) ? customCallData8 : IdInteraction.CustomCallData8;
                IdInteraction.CustomCallData9 = !string.IsNullOrEmpty(customCallData9) ? customCallData9 : IdInteraction.CustomCallData9;
                IdInteraction.CustomCallData10 = !string.IsNullOrEmpty(customCallData10) ? customCallData10 : IdInteraction.CustomCallData10;
                IdInteraction.CustomCallData11 = !string.IsNullOrEmpty(customCallData11) ? customCallData11 : IdInteraction.CustomCallData11;
                IdInteraction.CustomCallData12 = !string.IsNullOrEmpty(customCallData12) ? customCallData12 : IdInteraction.CustomCallData12;
                IdInteraction.CustomCallData13 = !string.IsNullOrEmpty(customCallData13) ? customCallData13 : IdInteraction.CustomCallData13;
                IdInteraction.CustomCallData14 = !string.IsNullOrEmpty(customCallData14) ? customCallData14 : IdInteraction.CustomCallData14;
                IdInteraction.CustomCallData15 = !string.IsNullOrEmpty(customCallData15) ? customCallData15 : IdInteraction.CustomCallData15;
                IdInteraction.CustomCallData16 = !string.IsNullOrEmpty(customCallData16) ? customCallData16 : IdInteraction.CustomCallData16;
                IdInteraction.CustomCallData17 = !string.IsNullOrEmpty(customCallData17) ? customCallData17 : IdInteraction.CustomCallData17;
                IdInteraction.CustomCallData18 = !string.IsNullOrEmpty(customCallData18) ? customCallData18 : IdInteraction.CustomCallData18;
                IdInteraction.CustomCallData19 = !string.IsNullOrEmpty(customCallData19) ? customCallData19 : IdInteraction.CustomCallData19;
                IdInteraction.CustomCallData20 = !string.IsNullOrEmpty(customCallData20) ? customCallData20 : IdInteraction.CustomCallData20;

                IdInteraction.IsHeld = isHeld;

                // =============================================== 11/11/2025 =========================================
                // User Id
                IdInteraction.UserId = !string.IsNullOrEmpty(userId) ? userId : IdInteraction.UserId;

                UserManager userMng = null;
                if (!string.IsNullOrEmpty(IdInteraction.UserId) && UserManagerList.ContainsKey(IdInteraction.UserId))
                {
                    userMng = UserManagerList[IdInteraction.UserId];

                    if (IdInteraction.IsHeldChanged)
                    {
                        if (userMng.isHold())
                        {
                            userMng.setStatus(true, "Hold", "Hold", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);                         
                        }
                        else
                        {
                            userMng.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", true, DateTime.MinValue, messageId, true);
                        }
                    }
                }
                //=====================================================================================================



                //IsCallbackRequest = isCallbackRequest;             

                //if (userMng != null && LastState == state)
                //{
                //    if (userMng.isHold())
                //    {
                //        userMng.setStatus(true, "Hold", "Hold", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                //        return;
                //    }
                //}
                //else if (LastState == state)
                //{                   
                //    return;
                //}

                //else if (userMng != null && LastState == state)
                //{
                //    if (userMng.isHold())
                //    {
                //        userMng.setStatus(true, "Hold", "Hold", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                //    }
                //}


                // If State havn't change
                //else if (LastState == state)
                //{
                //if (userMng != null)
                //{
                //    if (userMng.isHold())
                //   {
                //        userMng.setStatus(true, "Hold", "Hold", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                //    }
                //}
                //   return;
                //}


                AsyncLogger.Info($"!!!!SetCall LastState={LastState} state={state}");

                // If State havn't change
                if (LastState == state)
                {
                    return;
                }

                IdInteraction.State = state;

                // Set State
                setState(state, stateChangedTime);


                // =============================================== 11/11/2025 =========================================
                // User Id
                //IdInteraction.UserId = !string.IsNullOrEmpty(userId) ? userId : IdInteraction.UserId;

                //UserManager userMng = null;
                //if (!string.IsNullOrEmpty(IdInteraction.UserId) && UserManagerList.ContainsKey(IdInteraction.UserId))
                //{
                //    userMng = UserManagerList[IdInteraction.UserId];
                //}
                //=====================================================================================================


                // Switch State
                switch (state)
                {
                    case "pending":
                        if (!IdInteraction.IsAnswered)
                        {
                            IdInteraction.InQueue();

                            // [SYNC-PORT 2026-10-15 src=2026-07-30] Ringing round-2: a reservation is created "pending" WITH its
                            // worker, so a pending with a worker is the ring (assert + tag); a pending with an EMPTY userId is a
                            // task-level queue event or a re-queue after the offered reservation ended (clear the tagged ring).
                            if (!string.IsNullOrEmpty(userId))
                            {
                                clearTaggedRinging(stateChangedTime, messageId);
                                if (userMng != null)
                                {
                                    if (IdInteraction.Direction == "Incoming")
                                    {
                                        userMng.setStatus(true, "Ringing", "Ringing", "ONPHONE", stateChangedTime, "", false, stateChangedTime, messageId, true);
                                        userMng.TagCalcRinging(InteractionId);
                                        TaggedRingingUserId = userId;
                                    }
                                    else if (direction == "Outgoing")
                                    {
                                        //userMng.startOutgoingCall(this, IdInteraction.Workgroup);
                                        userMng.setStatus(true, "Calling Out", "Calling Out", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                                    }
                                }
                            }
                            else
                            {
                                clearTaggedRinging(stateChangedTime, messageId);
                            }
                        }
                        break;
                    case "reserved":
                        if (!IdInteraction.IsAnswered)
                        {
                            IdInteraction.InQueue();
                        }
                        break;
                    case "assigned":
                        if (!IdInteraction.IsAnswered)
                        {
                            IdInteraction.InQueue();
                        }
                        break; 

                    case "accepted":
                        if (IdInteraction.IsInQueue)
                        {
                            IdInteraction.OutQueue(false);
                        }
                        IdInteraction.Answered(userId);
                        if (userMng != null)
                        {
                            if (IdInteraction.InteractionType == "Callback")
                            {
                                if (IdInteraction.Direction == "Incoming")
                                {
                                    userMng.startIncomingCall(this, IdInteraction.Workgroup);
                                    userMng.setStatus(true, "Callback Incoming", "Callback Incoming", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                                }
                                else if (direction == "Outgoing")
                                {
                                    userMng.startOutgoingCall(this, IdInteraction.Workgroup);
                                    userMng.setStatus(true, "Callback Outgoing", "Callback Outgoing", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                                }
                            }
                            else
                            {
                                // [SYNC-PORT 2026-10-15 src=2026-08-05] Single-voice-line eviction: a NEW primary voice acceptance
                                // proves any OTHER live voice call still registered for this agent has ended (its terminal was
                                // lost -> orphan); finalize it first through the normal completed path. Consult legs are excluded.
                                // FAIL-SAFE: a no-op unless RTM:OrphanReapEnabled is a literal true.
                                if (!isConsult) userMng.EvictStalePrimaryVoiceCalls(this, stateChangedTime, messageId);

                                if (IdInteraction.Direction == "Incoming")
                                {
                                    userMng.startIncomingCall(this, IdInteraction.Workgroup);
                                    if (callType == "External")
                                    {
                                        userMng.setStatus(true, "Incoming Ext Call", "Incoming Ext Call", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                                    }
                                    else if (callType == "Intercom")
                                    {
                                        userMng.setStatus(true, "Incoming Int Call", "Incoming Int Call", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                                    }
                                }
                                else if (direction == "Outgoing")
                                {
                                    userMng.startOutgoingCall(this, IdInteraction.Workgroup);
                                    if (callType == "External")
                                    {
                                        userMng.setStatus(true, "Out Ext Call", "Out Ext Call", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                                    }
                                    else if (callType == "Intercom")
                                    {
                                        userMng.setStatus(true, "Out Int Call", "Out Int Call", "ONPHONE", stateChangedTime, "", true, stateChangedTime, messageId, true);
                                    }
                                }
                            }
                        }                      
                        break;

                    case "rejected":
                        //if (IdInteraction.IsInQueue)
                        //{
                        //    IdInteraction.OutQueue(false);
                        //}
                        IdInteraction.EndTalk();
                        if (userMng != null)
                        {
                            if (IdInteraction.Direction == "Incoming")
                            {
                                userMng.endIncomingCall(this, IdInteraction.Workgroup);
                                userMng.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                                //userMng.setStatus(true, "Missed Call", "Missed Call", "Missed Call", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                            }
                            if (direction == "Outgoing")
                            {
                                userMng.endOutgoingCall(this, IdInteraction.Workgroup);
                                userMng.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                            }

                            IdInteraction.UserId = string.Empty;
                        }
                        break;

                    case "timeout":
                        //if (IdInteraction.IsInQueue)
                        //{
                        //    IdInteraction.OutQueue(false);
                        //}
                        IdInteraction.EndTalk();
                        if (userMng != null)
                        {
                            if (IdInteraction.Direction == "Incoming")
                            {
                                userMng.endIncomingCall(this, IdInteraction.Workgroup);
                                userMng.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                                //userMng.setStatus(true, "Missed Call", "Missed Call", "Missed Call", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                            }
                            if (direction == "Outgoing")
                            {
                                userMng.endOutgoingCall(this, IdInteraction.Workgroup);
                                userMng.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                            }

                            IdInteraction.UserId = string.Empty;
                        }
                        break;

                    case "canceled":
                        AsyncLogger.Info(
                          $"SetCall CANCELED BEFORE | interactionId={InteractionId} segment={segmantId} " +
                          $"isInQueue={IdInteraction.IsInQueue} state={state}");                       

                        if (isCallbackRequest)
                        {
                            IdInteraction.CallbackRequest();
                        }
                        if (IdInteraction.IsInQueue)
                        {
                            IdInteraction.OutQueue(true);
                        }
                        IdInteraction.EndTalk();
                        if (userMng != null)
                        {
                            if (IdInteraction.Direction == "Incoming")
                            {
                                userMng.endIncomingCall(this, IdInteraction.Workgroup);
                            }
                            if (direction == "Outgoing")
                            {
                                userMng.endOutgoingCall(this, IdInteraction.Workgroup);
                            }
                            userMng.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", false, DateTime.MinValue, messageId, true);

                            IdInteraction.UserId = string.Empty;
                        }

                        // [SYNC-PORT 2026-10-15 src=2026-07-30] A reservation that cancels before accept is a ring death:
                        // clear THIS interaction's tagged ring for its offered worker (userMng may already be null here).
                        clearTaggedRinging(stateChangedTime, messageId);

                        AsyncLogger.Info(
                          $"SetCall CANCELED AFTER | interactionId={InteractionId} segment={segmantId} " +
                          $"isInQueue={IdInteraction.IsInQueue}");

                        break;

                    case "rescinded":
                        if (IdInteraction.IsInQueue)
                        {
                            IdInteraction.OutQueue(false);
                        }
                        IdInteraction.EndTalk();
                        if (userMng != null)
                        {
                            if (IdInteraction.Direction == "Incoming")
                            {
                                userMng.endIncomingCall(this, IdInteraction.Workgroup);
                            }
                            if (direction == "Outgoing")
                            {
                                userMng.endOutgoingCall(this, IdInteraction.Workgroup);
                            }

                            IdInteraction.UserId = string.Empty;
                        }
                        break;

                    case "wrapping":                      
                        if (IdInteraction.IsInQueue)
                        {
                            IdInteraction.OutQueue(false);                         
                        }
                        if (!IdInteraction.IsAnswered)
                        {
                            IdInteraction.Answered(userId);
                        }
                        IdInteraction.EndTalk();
                        if (userMng != null)
                        {
                            if (IdInteraction.Direction == "Incoming")
                            {
                                userMng.endIncomingCall(this, IdInteraction.Workgroup);
                            }
                            if (direction == "Outgoing")
                            {
                                userMng.endOutgoingCall(this, IdInteraction.Workgroup);
                            }
                        }
                        if (userMng != null)
                        {
                            userMng.setStatus(true, "Wrap Up", "Wrap Up", "ONPHONE", stateChangedTime, "", false, stateChangedTime, messageId, true);
                        }
                        break;

                    case "completed":
                        if (IdInteraction.IsInQueue)
                        {
                            IdInteraction.OutQueue(false);
                        }
                        if (!IdInteraction.IsAnswered)
                        {
                            IdInteraction.Answered(userId);
                        }
                        IdInteraction.EndTalk();
                        if (userMng != null)
                        {
                            if (IdInteraction.Direction == "Incoming")
                            {
                                userMng.endIncomingCall(this, IdInteraction.Workgroup);
                            }
                            if (direction == "Outgoing")
                            {
                                userMng.endOutgoingCall(this, IdInteraction.Workgroup);
                            }
                            userMng.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                        }
                        break;

                    // [SYNC-PORT 2026-10-15 src=2026-07-15] B2 terminal case for Engine.interactionRemovedAll ([src=2026-07-20] the
                    // forceCloseAbandoned label comes with the cause threading). Still queued: dequeue - "forceClose" (cause completed)
                    // is NOT abandoned (a phantom queued segment), "forceCloseAbandoned" (cause canceled) IS, except callback requests.
                    // End talk and release the agent only if actually talking; never fabricates an answered record.
                    case "forceClose":
                    case "forceCloseAbandoned":
                        // [SYNC-PORT 2026-10-15 src=2026-08-06] Item-4: a callback opt-out cancel carries isCallbackRequest; mark the
                        // interaction a callback BEFORE OutQueue so its guard keeps IsAbandoned=false. Abandoning terminal only.
                        if (state == "forceCloseAbandoned" && isCallbackRequest && !IdInteraction.IsCallbackRequest)
                        {
                            IdInteraction.CallbackRequest();
                        }
                        if (IdInteraction.IsInQueue)
                        {
                            IdInteraction.OutQueue(state == "forceCloseAbandoned");
                        }
                        if (IdInteraction.IsTalk)
                        {
                            IdInteraction.EndTalk();
                            if (userMng != null)
                            {
                                if (IdInteraction.Direction == "Incoming")
                                {
                                    userMng.endIncomingCall(this, IdInteraction.Workgroup);
                                }
                                if (direction == "Outgoing")
                                {
                                    userMng.endOutgoingCall(this, IdInteraction.Workgroup);
                                }
                                userMng.setStatus(true, "LastNoPhone", "", "", stateChangedTime, "", false, DateTime.MinValue, messageId, true);
                            }
                        }
                        else
                        {
                            // [SYNC-PORT 2026-10-15 src=2026-07-30] Ring-only terminal (never answered): clear THIS interaction's
                            // tagged ring, then evict any dead _calls entry so it cannot surface via LongestInteraction.
                            clearTaggedRinging(stateChangedTime, messageId);
                            if (userMng != null) userMng.removeCall(this);
                        }
                        AsyncLogger.Info($"SetCall {state} interactionId={InteractionId} seg={segmantId} isAbandoned={IdInteraction.IsAbandoned} isCallbackRequest={IdInteraction.IsCallbackRequest}");
                        break;

                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Call.SetCall", ex);
            }
        }


        // [SYNC-PORT 2026-10-15 src=2026-08-05] Shared finalize primitive for the eviction and the max-live backstop: runs THIS
        // call through the normal "completed" terminal, the same as a real ReservationCompleted (OutQueue/answered guard, end
        // talk, LastNoPhone with onPhone false, DB close). Idempotent: a no-op once disconnected or already completed.
        // Empty CustomCallData keeps the stored customer values.
        public void FinalizeOrphan(string path, DateTime endTime, long messageId)
        {
            try
            {
                var it = IdInteraction;
                if (it == null || it.IsDisconnected || State == "completed") return;

                double silentSec = Math.Max(0, (DateTime.Now - LastEventUtc).TotalSeconds);
                AsyncLogger.Info($"Call.FinalizeOrphan interactionId={InteractionId} seg={it.Segment} userId={it.UserId} path={path} priorState={State} silentSec={(int)silentSec} endTime={endTime:dd/MM/yyyy HH:mm:ss}");

                SetCall(it.InteractionType, it.Segment, it.CallType, it.Direction, "completed", endTime, it.Workgroup, it.UserId,
                    TimeSpan.Zero, TimeSpan.Zero, false, "", "", it.ClassificationCode, "",
                    "", "", new List<string>(), false, it.RemoteAddress, it.LastMessageSid,
                    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
                    false, messageId);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Call.FinalizeOrphan", ex);
            }
        }


        

  

        public void setState(string state, DateTime newStateStart)
        {
            try
            {
                if (IdInteraction.StateDuration.ContainsKey(State))
                {
                    StateDuration stateDuration = IdInteraction.StateDuration[State];
                    TimeSpan spEx = stateDuration.totalDuration;
                    stateDuration.duration = newStateStart.Subtract(StateStart);
                    stateDuration.totalDuration = spEx.Add(stateDuration.duration);
                }

                State = state;
                StateDuration stateDuration1 = IdInteraction.StateDuration.GetOrAdd(State, new StateDuration(State, TimeSpan.Zero, TimeSpan.Zero));
                StateStart = newStateStart;

                if (CallStateChangedEvent != null)
                {
                    CallStateChangedEvent(this, new CallStateChangedEventArgs(State, StateStart, CalculatedStatus, CalculatedStatusTime));
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Call.state", ex);
            }
        }



        // [SYNC-PORT 2026-10-15 src=2026-07-30] Ringing round-2: the universal ring-death eraser. Restores the tagged
        // worker's last real status only if he is STILL showing the Ringing this interaction asserted
        // (UserManager.ClearCalcRingingIfTaggedTo is guarded), so a stale tag is a safe no-op. Always resets the tag.
        private void clearTaggedRinging(DateTime statusChanged, long messageId)
        {
            if (!string.IsNullOrEmpty(TaggedRingingUserId)
                && UserManagerList != null
                && UserManagerList.ContainsKey(TaggedRingingUserId))
            {
                UserManagerList[TaggedRingingUserId].ClearCalcRingingIfTaggedTo(InteractionId, statusChanged, messageId);
            }
            TaggedRingingUserId = string.Empty;
        }
    }
}
