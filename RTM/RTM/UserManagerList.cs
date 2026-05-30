using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class UserManagerList : ConcurrentDictionary<string, UserManager>
    {
        public delegate void UserViewEventHandler(object sender, UserViewEventArgs e);
        public event UserViewEventHandler UserViewEvent;


        public UserManager Add(string userId, UserManager userManager)
        {
            if (ContainsKey(userId))
            {
                return this[userId];
            }
            else
            {
                userManager.UserViewEvent += UserManager_UserViewEvent;
                //AsyncLogger.Info("Add User=" +  userId);
                TryAdd(userId, userManager);
            }
            return userManager;
        }


        private void UserManager_UserViewEvent(object sender, UserViewEventArgs e)
        {
            if (UserViewEvent != null)
            {
                UserViewEvent(this, e);
            }
        }
    }
}
