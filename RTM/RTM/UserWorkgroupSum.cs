using RTM.Tools;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class UserWorkgroupSum
    {
        //  T O T A L    T O D A Y
        //=========================        
        // Incoming Calls
        private CallsDurationList _incomingCalls = null;

        // Outgoing Calls
        private CallsDurationList _outGoingCalls = null;

        // Incoming Inside Calls
        private CallsDurationList _incomingInsideCalls = null;

        // Outgoing Inside Calls
        private CallsDurationList _outgoingInsideCalls = null;

        // Dialer calls
        private CallsDurationList _dialerCalls = null;

        // Incoming chat
        private CallsDurationList _incomingChat = null;

        // Incoming fax
        private CallsDurationList _incomingFax = null;

        // Workgroup
        private string _workgroup = string.Empty;



        public UserWorkgroupSum(string workgroup)
        {
            try
            {
                _workgroup = workgroup;

                _incomingCalls = new CallsDurationList("incomingCalls");
                _outGoingCalls = new CallsDurationList("outGoingCalls");
                _incomingInsideCalls = new CallsDurationList("incomingInsideCalls");
                _outgoingInsideCalls = new CallsDurationList("outgoingInsideCalls");
                _dialerCalls = new CallsDurationList("dialerCalls");
                _incomingChat = new CallsDurationList("incomingChat");
                _incomingFax = new CallsDurationList("incomingFax");
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserWorkgroupSum.UserWorkgroupSum", ex);
            }
        }




        public void startRestore(int incomingCalls, TimeSpan incomingCallsDur,
                                 int outgoingCalls, TimeSpan outgoingCallsDur,
                                 int incomingIntercomCalls, TimeSpan incomingIntercomCallsDur,
                                 int outgoingIntercomCalls, TimeSpan outgoingIntercomCallsDur,
                                 int dialerCalls, TimeSpan dialerCallsDur,
                                 int incomingFax, TimeSpan incomingFaxDur)
        {
            try
            {
                _incomingCalls.startRestore(incomingCalls, incomingCallsDur);
                _outGoingCalls.startRestore(outgoingCalls, outgoingCallsDur);
                _incomingInsideCalls.startRestore(incomingIntercomCalls, incomingIntercomCallsDur);
                _outgoingInsideCalls.startRestore(outgoingIntercomCalls, outgoingIntercomCallsDur);
                _dialerCalls.startRestore(dialerCalls, dialerCallsDur);
                _incomingChat.startRestore(0, TimeSpan.Zero);
                _incomingFax.startRestore(incomingFax, incomingFaxDur);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserWorkgroupSum.midnightClear", ex);
            }
        }




        public void midnightClear()
        {
            try
            {
                _incomingCalls.midnightClear();
                _outGoingCalls.midnightClear();
                _incomingInsideCalls.midnightClear();
                _outgoingInsideCalls.midnightClear();
                _dialerCalls.midnightClear();
                _incomingChat.midnightClear();
                _incomingFax.midnightClear();
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("UserWorkgroupSum.midnightClear", ex);
            }
        }



        public string workgroup
        {
            get { return _workgroup; }
        }




        public CallsDurationList incomingCalls
        {
            get { return _incomingCalls; }
        }



        public CallsDurationList outGoingCalls
        {
            get { return _outGoingCalls; }
        }



        public CallsDurationList incomingInsideCalls
        {
            get { return _incomingInsideCalls; }
        }



        public CallsDurationList outgoingInsideCalls
        {
            get { return _outgoingInsideCalls; }
        }



        public CallsDurationList dialerCalls
        {
            get { return _dialerCalls; }
        }


        public CallsDurationList incomingChat
        {
            get { return _incomingChat; }
        }


        public CallsDurationList incomingFax
        {
            get { return _incomingFax; }
        }



        public int incomingCallsCount
        {
            get { return _incomingCalls.Count; }
        }



        public TimeSpan incomingCallsDuration
        {
            get { return _incomingCalls.duration; }
        }



        public int outgoingCallsCount
        {
            get { return _outGoingCalls.Count; }
        }



        public TimeSpan outgoingCallsDuration
        {
            get { return _outGoingCalls.duration; }
        }



        public int incomingInsideCallsCount
        {
            get { return _incomingInsideCalls.Count; }
        }



        public TimeSpan incomingInsideCallsDuration
        {
            get { return _incomingInsideCalls.duration; }
        }



        public int outgoingInsideCallsCount
        {
            get { return _outgoingInsideCalls.Count; }
        }



        public TimeSpan outgoingInsideCallsDuration
        {
            get { return _outgoingInsideCalls.duration; }
        }


        public int dialerCallsCount
        {
            get { return _dialerCalls.Count; }
        }



        public TimeSpan dialerCallsDuration
        {
            get { return _dialerCalls.duration; }
        }


        public int incomingChatCount
        {
            get { return _incomingChat.Count; }
        }



        public TimeSpan incomingChatDuration
        {
            get { return _incomingChat.duration; }
        }



        public int incomingFaxCount
        {
            get { return _incomingFax.Count; }
        }



        public TimeSpan incomingFaxDuration
        {
            get { return _incomingFax.duration; }
        }
    }
}
