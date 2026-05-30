using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class StateDuration
    {
        string _state;
        TimeSpan _duration;
        TimeSpan _totalDuration;


        public StateDuration(string state, TimeSpan duration, TimeSpan totalDuration)
        {
            _state = state;
            _duration = duration;
            _totalDuration = totalDuration;
        }



        public string state
        {
            get { return _state; }
            set
            {
                _state = value;
            }
        }



        public TimeSpan duration
        {
            get { return _duration; }
            set
            {
                _duration = value;
            }
        }



        public TimeSpan totalDuration
        {
            get { return _totalDuration; }
            set
            {
                _totalDuration = value;
            }
        }
    }
}
