namespace RTM
{
    public class UserUnionActivationEventArgs : EventArgs
    {
        public UserUnionActivationEventArgs(AjaxDictionary<string, string> userData, int unionId)
        {
            UserData = userData;
            UnionId = unionId;
        }


        public AjaxDictionary<string, string> UserData { get; set; }


        public int UnionId { get; set; }

    }
}
