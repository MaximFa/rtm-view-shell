using RTM.Tools;
using Npgsql;
using System.Data;


namespace RTM
{
    public class BusinessUnitData
    {
        // Get Business Unit Table
        public static List<BusinessUnit> getBusinessUnitTable()
        {
            var businessUnitsList = new List<BusinessUnit>();

            AsyncLogger.Info("== Get Business Unit Table ==");

            try
            {
                var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitTable", null);

                foreach (DataRow row in dataTable.Rows)
                {
                    int businessUnitId = DBAdapter.getIntValue(row[0].ToString());
                    string name = row[1].ToString();
                    string description = row[2].ToString();
                    string timeZone = row[3].ToString();
                    TimeSpan clearTime = DBAdapter.getTimeSpanValue(row[4].ToString());

                    businessUnitsList.Add(new BusinessUnit(businessUnitId, name, description, timeZone, clearTime));

                    AsyncLogger.Info($"BusinessUnit businessUnitId={businessUnitId} name={name} description={description} clearTime={clearTime}  clearTime={clearTime}");
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getBusinessUnitTable", ex);
            }

            return businessUnitsList;
        }



        // Get Supergroup Table
        public static List<Supergroup> getSupergroupTable()
        {
            var supergroupList = new List<Supergroup>();

            AsyncLogger.Info("== Get Supergroup Table ==");

            try
            {
                var dataTable = DBAdapter.GetDataTable("NGC_GetSupergroupTable", null);

                foreach (DataRow row in dataTable.Rows)
                {
                    int supergroupId = DBAdapter.getIntValue(row[0].ToString());
                    string name = row[1].ToString();
                    string description = row[2].ToString();

                    supergroupList.Add(new Supergroup(supergroupId, name, description));

                    AsyncLogger.Info("Supergroup supergroupId=" + supergroupId + " name=" + name + " description=" + description);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getSupergroupTable", ex);
            }

            return supergroupList;
        }



        // Get BusinessUnit Queue Classification Table
        public static List<BusinessUnitQueueClassification> getBusinessUnitQueueClassificationTable()
        {
            var businessUnitQueueClassificationList = new List<BusinessUnitQueueClassification>();

            AsyncLogger.Info("== Get BusinessUnit Queue Classification Table ==");

            try
            {
                var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitQueueClassificationTable", null);

                foreach (DataRow row in dataTable.Rows)
                {
                    int businessUnitId = DBAdapter.getIntValue(row[0].ToString());
                    string queue = row[1].ToString();
                    string classificationID = row[2].ToString();

                    businessUnitQueueClassificationList.Add(new BusinessUnitQueueClassification(businessUnitId, queue, classificationID));

                    AsyncLogger.Info("BusinessUnitQueueClassification businessUnitId=" + businessUnitId + " queue=" + queue + " classificationID=" + classificationID);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getBusinessUnitQueueClassificationTable", ex);
            }

            return businessUnitQueueClassificationList;
        }




        // Get BusinessUnit Supergroup Table
        public static List<BusinessUnitSupergroup> getBusinessUnitSupergroupTable()
        {
            var businessUnitSupergroupList = new List<BusinessUnitSupergroup>();

            AsyncLogger.Info("== Get BusinessUnit Supergroup Table ==");

            try
            {
                var dataTable = DBAdapter.GetDataTable("NGC_GetBusinessUnitSupergroupTable", null);

                foreach (DataRow row in dataTable.Rows)
                {
                    int businessUnitId = DBAdapter.getIntValue(row[0].ToString());
                    int supergroupId = DBAdapter.getIntValue(row[1].ToString());

                    businessUnitSupergroupList.Add(new BusinessUnitSupergroup(businessUnitId, supergroupId));

                    //AsyncLogger.Info("BusinessUnitSupergroupTable businessUnitId=" + businessUnitId + " supergroupId=" + supergroupId);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getBusinessUnitSupergroupTable", ex);
            }

            return businessUnitSupergroupList;
        }




        // Get Supergroup Agentgroup Table
        public static List<SupergroupAgentgroup> getSupergroupAgentgroupTable()
        {
            var businessUnitSupergroupList = new List<SupergroupAgentgroup>();

            AsyncLogger.Info("== Get Supergroup Agentgroup Table ==");

            try
            {
                var dataTable = DBAdapter.GetDataTable("NGC_GetSupergroupAgentgroupTable", null);

                foreach (DataRow row in dataTable.Rows)
                {
                    int supergroupId = DBAdapter.getIntValue(row[0].ToString());
                    string agentgroupId = row[1].ToString();

                    businessUnitSupergroupList.Add(new SupergroupAgentgroup(supergroupId, agentgroupId));

                    AsyncLogger.Info("SupergroupAgentgroup supergroupId=" + supergroupId + " agentgroupId=" + agentgroupId);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getSupergroupAgentgroupTable", ex);
            }

            return businessUnitSupergroupList;
        }





        //  Create BusinessUnit
        public static int createBusinessUnit(string name, string description, string siteId,string createdBy)
        {
            int retVal = 0;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@BusinessUnitName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                parameters.Add(new NpgsqlParameter("@SiteId", siteId));
                parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                int businessUnitID = Convert.ToInt32(DBAdapter.GetScalar("NGC_CreateBusinessUnit", parameters));

                retVal = businessUnitID;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.createBusinessUnit", ex);
            }

            return retVal;
        }



        //  Delete BusinessUnit      
        public static bool deleteBusinessUnit(int businessUnitID, string deletedBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@BusinessUnitID", businessUnitID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnit", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.deleteBusinessUnit", ex);
            }

            return retVal;
        }



        //  Modify BusinessUnit      
        public static bool modifyBusinessUnit(int businessUnitID, string name, string description, string modifiedBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@BusinessUnitID", businessUnitID));
                parameters.Add(new NpgsqlParameter("@BusinessUnitName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                DBAdapter.ExecuteNonQuery("NGC_ModifyBusinessUnit", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.modifyBusinessUnit", ex);
            }

            return retVal;
        }





        //  Create Supergroup        
        public static int createSupergroup(string name, string description, string createdBy)
        {
            int supergroupId = 0;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@SupergroupName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                supergroupId = Convert.ToInt32(DBAdapter.GetScalar("NGC_CreateSupergroup", parameters));
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.createSupergroup", ex);
            }

            return supergroupId;
        }




        public static bool createSupergroup(int id, string name, string description, string createdBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@SupergroupID", id));
                parameters.Add(new NpgsqlParameter("@SupergroupName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                DBAdapter.ExecuteNonQuery("NGC_CreateSupergroup", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.createSupergroup", ex);
            }

            return retVal;
        }



        //  Delete Supergroup    
        public static bool deleteSupergroup(int supergroupID, string deletedBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteSupergroup", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.deleteSupergroup", ex);
            }

            return retVal;
        }



        //  Modify Supergroup      
        public static bool modifySupergroup(int supergroupID, string name, string description, string modifiedBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                parameters.Add(new NpgsqlParameter("@SupergroupName", name));
                parameters.Add(new NpgsqlParameter("@Description", description));
                DBAdapter.ExecuteNonQuery("NGC_ModifySupergroup", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.modifySupergroup", ex);
            }

            return retVal;
        }




        //  Create BusinessUnit Queue Classification Mapping
        public static bool createBusinessUnitQueueClassificationMapping(int businessUnitID, string queueID, string classificationID, string createdBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@BusinessUnitID", businessUnitID));
                parameters.Add(new NpgsqlParameter("@QueueID", queueID));
                parameters.Add(new NpgsqlParameter("@ClassificationID", classificationID));
                parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                DBAdapter.ExecuteNonQuery("NGC_CreateBusinessUnitQueueClassificationMapping", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.createBusinessUnitQueueClassificationMapping", ex);
            }

            return retVal;
        }



        //  Delete BusinessUnit Queue Classification Mapping    
        public static bool deleteBusinessUnitQueueClassificationMapping(int businessUnitID, string queueID, string classificationID, string deletedBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@BusinessUnitID", businessUnitID));
                parameters.Add(new NpgsqlParameter("@QueueID", queueID));
                parameters.Add(new NpgsqlParameter("@ClassificationID", classificationID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnitQueueClassificationMapping", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.deleteBusinessUnitQueueClassificationMapping", ex);
            }

            return retVal;
        }




        //  Create BusinessUnit Supergroup Mapping
        public static bool createBusinessUnitSupergroupMapping(int businessUnitID, int supergroupID, string createdBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@BusinessUnitID", businessUnitID));
                parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                DBAdapter.ExecuteNonQuery("NGC_CreateBusinessUnitSupergroupMapping", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.createBusinessUnitSupergroupMapping", ex);
            }

            return retVal;
        }



        //  Delete BusinessUnit Supergroup Mapping    
        public static bool deleteBusinessUnitSupergroupMapping(int businessUnitID, int supergroupID, string deletedBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@BusinessUnitID", businessUnitID));
                parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteBusinessUnitSupergroupMapping", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.deleteBusinessUnitSupergroupMapping", ex);
            }

            return retVal;
        }



        //  Create Supergroup AgentgroupMapping
        public static bool createSupergroupAgentgroupMapping(int supergroupID, string agentgroupID, string createdBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                parameters.Add(new NpgsqlParameter("@AgentgroupID", agentgroupID));
                parameters.Add(new NpgsqlParameter("@CreatedBy", createdBy));
                DBAdapter.ExecuteNonQuery("NGC_CreateSupergroupAgentgroupMapping", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.createSupergroupAgentgroupMapping", ex);
            }

            return retVal;
        }



        //  Delete Supergroup Agentgroup Mapping  
        public static bool deleteSupergroupAgentgroupMapping(int supergroupID, string agentgroupID, string deletedBy)
        {
            bool retVal = false;
            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@SupergroupID", supergroupID));
                parameters.Add(new NpgsqlParameter("@AgentgroupID", agentgroupID));
                DBAdapter.ExecuteNonQuery("NGC_DeleteSupergroupAgentgroupMapping", parameters);

                retVal = true;
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.deleteSupergroupAgentgroupMapping", ex);
            }

            return retVal;
        }
    }
}
