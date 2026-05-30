using System.Collections.Concurrent;

namespace RTM
{
    public class QueueAcdCallsList : ConcurrentDictionary<string, AcdCall>
    {
        private DateTime _maxWaitDT = DateTime.MaxValue;


        public QueueAcdCallsList()
            : base()
        {
        }



        public DateTime MaxWaitDT
        {
            get
            {
                return _maxWaitDT;
            }
            set
            {
                _maxWaitDT = value;

                //AsyncLogger.Info("MaxWaitDT=" + MaxWaitDT);
            }
        }



        public bool Add(string key, AcdCall call)
        {
            bool retVal = false;

            base.TryAdd(key, call);

            if (call.DateTimeLastStateChange < _maxWaitDT)
            {
                MaxWaitDT = call.DateTimeLastStateChange;
                retVal = true;
            }

            return retVal;
        }



        public bool Remove(string key)
        {
            bool retVal = false;

            AcdCall acdCall = null;

            if (this.TryGetValue(key, out acdCall))
            {
                DateTime dt = acdCall.DateTimeLastStateChange;

                base.TryRemove(key, out acdCall);

                if (dt == _maxWaitDT)
                {
                    if (this.Count > 0)
                    {
                        MaxWaitDT = this.Min(t => t.Value.DateTimeLastStateChange);
                    }
                    else
                    {
                        MaxWaitDT = DateTime.MaxValue;
                    }
                    retVal = true;
                }
            }

            return retVal;
        }
    }

}
