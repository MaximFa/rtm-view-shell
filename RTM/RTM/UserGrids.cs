
using System.Collections.Concurrent;


namespace RTM
{
    public class UserGrids
    {
        private ConcurrentDictionary<int, UserDataList> _userGrid = new ConcurrentDictionary<int, UserDataList>();


        public Dictionary<string, MetricDef> Metrics { get; set; }



        public void setUserGrid(int unionId, UserDataList addUserDataList)
        {
            UserDataList userDataList = _userGrid.GetOrAdd(unionId, new UserDataList(unionId));

            foreach (var user in addUserDataList.Users)
            {
                if (userDataList.Users.ContainsKey(user.Key)) // userid
                {
                    userDataList.Users[user.Key] = user.Value;
                }
                else
                {
                    userDataList.Users.TryAdd(user.Key, user.Value);
                }
            }
        }



        public void userUnionDeactivate(int unionId, string userId)
        {
            UserData userData = null;
            _userGrid[unionId].Users.TryRemove(userId, out userData);
        }




        public UserDataList getUserGrid(int unionId)
        {
            UserDataList userDataList = null;

            try
            {
                userDataList = _userGrid[unionId];
            }
            catch { }

            return userDataList;
        }



        public UserData getUserData(string userId)
        {
            foreach (var userDataList in _userGrid.Values)
            {
                if (userDataList.Users.ContainsKey(userId))
                {
                    return userDataList.Users[userId];
                }
            }

            return null;
        }
    }




    public class UserData
    {
        private ConcurrentDictionary<string, string> _data = new ConcurrentDictionary<string, string>();

        public string UserId { get; set; }

        public ConcurrentDictionary<string, string> Data
        {
            get
            {
                return _data;
            }
            set
            {
                _data = value;
            }
        }

    }



    public class UserDataList
    {
        private ConcurrentDictionary<string, UserData> _users = new ConcurrentDictionary<string, UserData>();

        public UserDataList(int unionId)
        {
            UnionId = unionId;
        }

        public int UnionId { get; set; }

        public ConcurrentDictionary<string, UserData> Users
        {
            get
            {
                return _users;
            }
            set
            {
                _users = value;
            }
        }
    }
}
