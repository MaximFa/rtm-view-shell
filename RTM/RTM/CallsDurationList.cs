using RTM.Configuration;   // [SYNC-PORT 2026-10-15 src=2026-08-06] AppConfig.SegmentDedupEnabled
using RTM.Tools;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class CallsDurationList
    {
        private Dictionary<string, DateTime> activeCalls = null;
        private TimeSpan _duration = TimeSpan.Zero;
        private int _callsCount = 0;
        private string _name = string.Empty;

        // [SYNC-PORT 2026-10-15 src=2026-08-06] Per-agent day-scoped de-dup: interactionIds already credited today. A re-cycling
        // interaction (Add -> Remove -> Add across segments) credits this agent ONCE per day; distinct calls, and two different
        // agents on a transferred interaction, each still credit. Cleared at midnight. Rides RTM:SegmentDedupEnabled (fail-open).
        private readonly HashSet<string> _countedToday = new HashSet<string>();



        public CallsDurationList(string name)
        {
            _name = name;

            try
            {
                activeCalls = new Dictionary<string, DateTime>();
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("CallsDurationList.CallsDurationList", ex);
            }
        }



        public int Count
        {
            get { return _callsCount; }
        }



        public TimeSpan duration
        {
            //get { return (_duration.Add(activeCallsDuration())); }
            get { return _duration; }
        }



        public void Add(string interactionId)
        {
            try
            {
                if (!activeCalls.ContainsKey(interactionId))
                {
                    activeCalls.Add(interactionId, DateTime.Now);

                    // [SYNC-PORT 2026-10-15 src=2026-08-06] Credit once per interaction per day; a literal false = every active period.
                    bool firstToday = _countedToday.Add(interactionId);
                    if (!AppConfig.SegmentDedupEnabled || firstToday)
                    {
                        _callsCount++;
                    }
                }
            }
            catch (Exception ex)
            {// Same interaction again to the same user
                AsyncLogger.Error("CallsDurationList.Add." + _name + ": interactionId=" + interactionId, ex);
            }
        }



        public void Remove(string interactionId)
        {
            try
            {
                if (activeCalls.ContainsKey(interactionId))
                {
                    TimeSpan callDuration = DateTime.Now.Subtract(activeCalls[interactionId]);
                    _duration = _duration.Add(callDuration);

                    activeCalls.Remove(interactionId);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("CallsDurationList.Remove", ex);
            }
        }



        public bool ContainsKey(string interactionId)
        {
            return activeCalls.ContainsKey(interactionId);
        }





        public int activeCallsCount()
        {
            return activeCalls.Count;
        }




        public DateTime activeCallsMax()
        {
            TimeSpan dur = TimeSpan.Zero;
            DateTime now = DateTime.Now;

            try
            {
                if (activeCalls.Count > 0)
                {
                    long ticks = activeCalls.Max(t => now.Subtract(t.Value).Ticks);
                    dur = new TimeSpan(ticks);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("CallsDurationList.activeCallsDuration", ex);
            }

            return now.Subtract(dur);
        }




        public DateTime activeCallsDuration()
        {
            TimeSpan dur = TimeSpan.Zero;
            DateTime now = DateTime.Now;

            try
            {
                if (activeCalls.Count > 0)
                {
                    long ticks = activeCalls.Sum(t => now.Subtract(t.Value).Ticks);
                    dur = new TimeSpan(ticks);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("CallsDurationList.activeCallsDuration", ex);
            }

            return now.Subtract(dur);
        }




        public void startRestore(int callsCount, TimeSpan duration)
        {
            _callsCount = callsCount;
            _duration = duration;
        }



        public void midnightClear()
        {
            _callsCount = 0;
            _duration = TimeSpan.Zero;
            _countedToday.Clear();   // [SYNC-PORT 2026-10-15 src=2026-08-06] reset the day-scoped de-dup set
        }

    }
}


