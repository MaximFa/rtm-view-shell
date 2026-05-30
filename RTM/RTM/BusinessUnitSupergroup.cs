namespace RTM
{
    public class BusinessUnitSupergroup
    {
        public BusinessUnitSupergroup(int businessUnitID, int supergroupID)
        {
            BusinessUnitID = businessUnitID;
            SupergroupID = supergroupID;
        }


        public int BusinessUnitID { get; private set; }

        public int SupergroupID { get; private set; }
    }

}