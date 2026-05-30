using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class CallStateChangedEventArgs : EventArgs
    {
        private string _state;
        private DateTime _startTime;
        private string _calculatedStatus;
        private string _calculatedStatusTime;



        public CallStateChangedEventArgs(string state, DateTime startTime, string calculatedStatus, string calculatedStatusTime)
        {
            _state = state;
            _startTime = startTime;
            _calculatedStatus = calculatedStatus;
            _calculatedStatusTime = calculatedStatusTime;
        }



        public DateTime startTime
        {
            get { return _startTime; }
        }



        public string CalculatedStatus
        {
            get { return _calculatedStatus; }
        }


        public string CalculatedStatusTime
        {
            get { return _calculatedStatusTime; }
        }
    }
}
