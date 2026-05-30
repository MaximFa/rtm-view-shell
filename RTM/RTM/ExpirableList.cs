using RTM.Tools;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Timers;
using Timer = System.Timers.Timer;

namespace RTM
{
    public class ExpirableList : IList<Call>
    {
        private volatile List<Tuple<DateTime, Call>> collection = new List<Tuple<DateTime, Call>>();

        private Timer timer;

        public double Interval
        {
            get { return timer.Interval; }
            set { timer.Interval = value; }
        }

        private TimeSpan expiration;

        public TimeSpan Expiration
        {
            get { return expiration; }
            set { expiration = value; }
        }

        private TimeSpan waitingTime = TimeSpan.Zero;

        public TimeSpan WaitingTime
        {
            get { return waitingTime; }
        }

        /// <summary>
        /// Define a list that automaticly remove expired objects.
        /// </summary>
        /// <param name="_interval"></param>
        /// The interval at which the list test for old objects.
        /// <param name="_expiration"></param>
        /// The TimeSpan an object stay valid inside the list.
        public ExpirableList(int _interval, TimeSpan _expiration)
        {
            try
            {
                timer = new Timer();
                timer.Interval = _interval;
                timer.Elapsed += timer_Elapsed;
                timer.Start();

                expiration = _expiration;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ExpirableList.ExpirableList", ex);
            }
        }


        private void timer_Elapsed(object sender, ElapsedEventArgs e)
        {
            try
            {
                for (int i = collection.Count - 1; i >= 0; i--)
                {
                    if ((DateTime.Now - collection[i].Item1) >= expiration)
                    {
                        RemoveAt(i);
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ExpirableList.timer_Elapsed", ex);
            }
        }

        #region IList Implementation
        public Call this[int index]
        {
            get { return collection[index].Item2; }
            set { collection[index] = new Tuple<DateTime, Call>(DateTime.Now, value); }
        }

        public IEnumerator<Call> GetEnumerator()
        {
            return collection.Select(x => x.Item2).GetEnumerator();
        }

        IEnumerator IEnumerable.GetEnumerator()
        {
            return collection.Select(x => x.Item2).GetEnumerator();
        }

        public void Add(Call item)
        {
            collection.Add(new Tuple<DateTime, Call>(DateTime.Now, item));
            waitingTime = waitingTime.Add(item.TimeInQueue);
        }

        public int Count
        {
            get { return collection.Count; }
        }

        public bool IsSynchronized
        {
            get { return false; }
        }

        public bool IsReadOnly
        {
            get { return false; }
        }

        public void CopyTo(Call[] array, int index)
        {
            for (int i = 0; i < collection.Count; i++)
                array[i + index] = collection[i].Item2;
        }

        public bool Remove(Call item)
        {
            bool contained = Contains(item);
            for (int i = collection.Count - 1; i >= 0; i--)
            {
                if ((object)collection[i].Item2 == (object)item)
                    RemoveAt(i);
            }
            return contained;
        }

        public void RemoveAt(int i)
        {
            Call call = collection[i].Item2;
            waitingTime = waitingTime.Subtract(call.TimeInQueue);
            collection.RemoveAt(i);
        }

        public bool Contains(Call item)
        {
            for (int i = 0; i < collection.Count; i++)
            {
                if ((object)collection[i].Item2 == (object)item)
                    return true;
            }

            return false;
        }

        public void Insert(int index, Call item)
        {
            collection.Insert(index, new Tuple<DateTime, Call>(DateTime.Now, item));
        }

        public int IndexOf(Call item)
        {
            for (int i = 0; i < collection.Count; i++)
            {
                if ((object)collection[i].Item2 == (object)item)
                    return i;
            }

            return -1;
        }

        public void Clear()
        {
            collection.Clear();
        }
        #endregion
    }
}
