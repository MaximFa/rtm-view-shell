using RTM.Tools;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class UserStatusData
    {
        private DBMng _dbMng = null;
        private string _userId = string.Empty;

        UserManager UserManager { get; set; }


        public UserStatusData(UserManager userManager, string statusId, string statusName, string statusGroup, TimeSpan dur, DBMng dbMng, string userId, bool isDBInserted, string displayName)
        {
            _dbMng = dbMng;
            UserManager = userManager;
            _userId = userId;
            StatusId = statusId;
            StatusName = statusName;
            StatusGroup = statusGroup;
            Dur = dur;
            Max = dur;
            Count = 0;
            IsDBInserted = isDBInserted;
            DisplayName = displayName;           
        }

        public string StatusId { get; set; }

        public string StatusName { get; set; }

        public string StatusGroup { get; set; }

        public TimeSpan Max { get; set; }

        public int Count { get; set; }

        public TimeSpan Dur { private set; get; }


        private bool IsDBInserted { get; set; }


        public string DisplayName { get; set; }



        



        public void addDur(TimeSpan dur, DateTime stratTime, DateTime endTime)
        {
            if (dur > TimeSpan.Zero)
            {
                Dur = Dur.Add(dur);

                Count++;

                if (dur > Max)
                {
                    Max = dur;
                }

                _dbMng.addUserStatusRequest(IsDBInserted, _userId, StatusId, StatusName, StatusGroup, Dur, Max, Count, DisplayName, stratTime, endTime, UserManager.TimeZone, UserManager.getLocalDateTime());

                IsDBInserted = true;
            }
        }


        public void Clear()
        {
            Dur = TimeSpan.Zero;
            Max = TimeSpan.Zero;
            Count = 0;
        }
    }

}
