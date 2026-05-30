
namespace RTM
{
    public class UserViewEventArgs
    {
        public UserViewEventArgs(string userId, AjaxDictionary<string, string> userData)
        {
            UserId = userId;
            UserData = userData;

        }


        public string UserId { get; set; }


        public AjaxDictionary<string, string> UserData { get; set; }
        //public IEnumerable<KeyValuePair<string, string>> UserData { get; set; }
    }
}
