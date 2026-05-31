using RTM.Tools;
using RTM.Configuration;
using System.Collections.Concurrent;
using Npgsql;
using System.Data;
using System;
using RTM.Types;

namespace RTM
{
    public class RealtimeData
    {
        public static List<Dictionary<string, string>> getDataCells()
        {
            List<Dictionary<string, string>> list = new List<Dictionary<string, string>>();

            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetDataCells", null);

            foreach (DataRow row in dataTable.Rows)
            {
                int cellId = DBAdapter.getIntValue(row[0].ToString());  // CellId
                int gridId = DBAdapter.getIntValue(row[2].ToString());  // GridId

                string metric = row[8].ToString();
                if (string.IsNullOrEmpty(metric))
                {
                    metric = row[9].ToString(); // ColumnMetric
                }

                int unionId = DBAdapter.getIntValue(row[5].ToString()); // UnionId                
                if (unionId == -1 || unionId == 0)
                {
                    unionId = DBAdapter.getIntValue(row[7].ToString()); // RowUnionId
                    if (unionId == -1 || unionId == 0)
                    {
                        unionId = DBAdapter.getIntValue(row[6].ToString()); // GridUnionId
                    }
                }

                if (unionId != -1 && unionId != 0 && !string.IsNullOrEmpty(metric))
                {
                    Dictionary<string, string> cellData = new Dictionary<string, string>();
                    cellData.Add("CellId", cellId.ToString());
                    cellData.Add("GridId", gridId.ToString());
                    cellData.Add("Metric", metric);
                    cellData.Add("UnionId", unionId.ToString());

                    //AsyncLogger.Info("cellData CellId=" + CellId + " GridId=" + GridId + " Metric=" + UnionMetric + " UnionId=" + UnionId);

                    list.Add(cellData);
                }
            }

            return list;
        }





        public static List<Dictionary<string, string>> getStatisticCells()
        {
            List<Dictionary<string, string>> list = new List<Dictionary<string, string>>();

            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetStatisticCells", null);

            foreach (DataRow row in dataTable.Rows)
            {
                int CellId = DBAdapter.getIntValue(row[0].ToString());  // CellId
                int GridId = DBAdapter.getIntValue(row[1].ToString());  // GridId
                int statisticId = DBAdapter.getIntValue(row[2].ToString());  // StatisticId

                Dictionary<string, string> cellData = new Dictionary<string, string>();
                cellData.Add("CellId", CellId.ToString());
                cellData.Add("GridId", GridId.ToString());
                cellData.Add("StatisticId", statisticId.ToString());

                //AsyncLogger.Info("getStatisticCells CellId=" + CellId + " GridId=" + GridId + " StatisticId=" + statisticId);

                list.Add(cellData);
            }

            return list;
        }







        // Get Site Table
        public static ConcurrentDictionary<string, Site> getSiteTable()
        {
            var siteList = new ConcurrentDictionary<string, Site>();

            AsyncLogger.Info("== Get Site Table ==");

            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
                var dataTable = DBAdapter.GetDataTable("NGC_GetSiteTable", parameters);

                foreach (DataRow row in dataTable.Rows)
                {
                    string siteId = row[0].ToString();
                    string siteName = row[1].ToString();
                    string description = row[2].ToString();
                    string timeZone = row[3].ToString();
                    TimeSpan clearTime = DBAdapter.getTimeSpanValue(row[4].ToString());

                    Site site = new Site()
                    {
                        SiteId = siteId,
                        SiteName = siteName,
                        Description = description,
                        TimeZone = timeZone,
                        ClearTime = clearTime
                    };
                    siteList.TryAdd(siteId, site);

                    AsyncLogger.Info($"Site siteId={siteId} name={siteName} description={description} TimeZone={timeZone}  clearTime={clearTime}");
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.BusinessUnitsData.getBusinessUnitTable", ex);
            }

            return siteList;
        }







        public static List<Dictionary<string, string>> GetAllUnionQueueClassifications()
        {
            List<Dictionary<string, string>> list = new List<Dictionary<string, string>>();

            var parameters = new List<NpgsqlParameter>();
            parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetAllUnionQueueClassifications", parameters);

            foreach (DataRow row in dataTable.Rows)
            {
                Dictionary<string, string> cellData = new Dictionary<string, string>();
                int UnionId = DBAdapter.getIntValue(row[0].ToString()); // UnionId
                string QueueId = row[1].ToString();                     // QueueId"
                string ClassificationId = row[2].ToString();            // ClassificationId
                string timeZone = row[3].ToString();
                TimeSpan clearTime = DBAdapter.getTimeSpanValue(row[4].ToString());

                cellData.Add("UnionId", UnionId.ToString());
                cellData.Add("QueueId", QueueId);
                cellData.Add("ClassificationId", ClassificationId);
                cellData.Add("timeZone", timeZone);
                cellData.Add("clearTime", clearTime.ToString());

                list.Add(cellData);
            }
            return list;
        }




        public static List<Dictionary<string, string>> GetAllUnionUserGroups()
        {
            List<Dictionary<string, string>> list = new List<Dictionary<string, string>>();

            var parameters = new List<NpgsqlParameter>();
            parameters.Add(new NpgsqlParameter("@TenantId", AppConfig.TenantId));
            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetAllUnionUserGroups", parameters);

            foreach (DataRow row in dataTable.Rows)
            {
                Dictionary<string, string> cellData = new Dictionary<string, string>();
                int UnionId = DBAdapter.getIntValue(row[0].ToString());      // UnionId
                int SupergroupId = DBAdapter.getIntValue(row[1].ToString()); // SupergroupId"
                string UsergroupId = row[2].ToString();                      // UsergroupId"]
                string timeZone = row[3].ToString();
                TimeSpan clearTime = DBAdapter.getTimeSpanValue(row[4].ToString());

                cellData.Add("UnionId", UnionId.ToString());
                cellData.Add("SupergroupId", SupergroupId.ToString());
                cellData.Add("UsergroupId", UsergroupId);
                cellData.Add("timeZone", timeZone);
                cellData.Add("clearTime", clearTime.ToString());

                list.Add(cellData);
            }
            return list;
        }





        public static Dictionary<string, MetricDef> GetAllMetrics()
        {
            var list = new Dictionary<string, MetricDef>();

            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetAllMetrics", null);

            foreach (DataRow row in dataTable.Rows)
            {
                MetricDef metric = new MetricDef();
                metric.ID = row[0].ToString();        //MetricId
                metric.Description = row[1].ToString(); // Description
                metric.DataType = row[2].ToString();  //DataType
                metric.Function = row[3].ToString();  //MetricFunction
                metric.Parameter = row[4].ToString(); //MetricParameter
                metric.Format = row[5].ToString();    //MetricFormat
                metric.DefaultValue = row[6].ToString();    //DefaultValue

                list.Add(metric.ID, metric);
            }

            return list;
        }





        public static Dictionary<int, Statistic> GetAllStatistics()
        {
            var list = new Dictionary<int, Statistic>();

            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetAllStatistics", null);

            foreach (DataRow row in dataTable.Rows)
            {
                int statisticId = DBAdapter.getIntValue(row[0].ToString());
                var category = row[1].ToString();
                var definition = row[2].ToString();
                var statistic = new Statistic(category, definition);

                var paramType1 = row[3].ToString();
                var paramValue1 = row[4].ToString();
                var param1 = new StatisticParameter(paramType1, paramValue1);
                if (!string.IsNullOrWhiteSpace(paramType1))
                {
                    statistic.Parameters.Add(param1);
                }

                var paramType2 = row[5].ToString();
                var paramValue2 = row[6].ToString();
                var param2 = new StatisticParameter(paramType2, paramValue2);
                if (!string.IsNullOrWhiteSpace(paramType2))
                {
                    statistic.Parameters.Add(param2);
                }

                var paramType3 = row[7].ToString();
                var paramValue3 = row[8].ToString();
                var param3 = new StatisticParameter(paramType3, paramValue3);
                if (!string.IsNullOrWhiteSpace(paramType3))
                {
                    statistic.Parameters.Add(param3);
                }

                var paramType4 = row[9].ToString();
                var paramValue4 = row[10].ToString();
                var param4 = new StatisticParameter(paramType4, paramValue4);
                if (!string.IsNullOrWhiteSpace(paramType4))
                {
                    statistic.Parameters.Add(param4);
                }

                var paramType5 = row[11].ToString();
                var paramValue5 = row[12].ToString();
                var param5 = new StatisticParameter(paramType5, paramValue5);
                if (!string.IsNullOrWhiteSpace(paramType5))
                {
                    statistic.Parameters.Add(param5);
                }


                var paramType6 = row[13].ToString();
                var paramValue6 = row[14].ToString();
                var param6 = new StatisticParameter(paramType6, paramValue6);
                if (!string.IsNullOrWhiteSpace(paramType6))
                {
                    statistic.Parameters.Add(param6);
                }

                var paramType7 = row[15].ToString();
                var paramValue7 = row[16].ToString();
                var param7 = new StatisticParameter(paramType7, paramValue7);
                if (!string.IsNullOrWhiteSpace(paramType7))
                {
                    statistic.Parameters.Add(param7);
                }

                var paramType8 = row[17].ToString();
                var paramValue8 = row[18].ToString();
                var param8 = new StatisticParameter(paramType8, paramValue8);
                if (!string.IsNullOrWhiteSpace(paramType8))
                {
                    statistic.Parameters.Add(param8);
                }

                var paramType9 = row[19].ToString();
                var paramValue9 = row[20].ToString();
                var param9 = new StatisticParameter(paramType9, paramValue9);
                if (!string.IsNullOrWhiteSpace(paramType9))
                {
                    statistic.Parameters.Add(param9);
                }

                var paramType10 = row[21].ToString();
                var paramValue10 = row[22].ToString();
                var param10 = new StatisticParameter(paramType10, paramValue10);
                if (!string.IsNullOrWhiteSpace(paramType10))
                {
                    statistic.Parameters.Add(param10);
                }

                list.Add(statisticId, statistic);
            }

            return list;
        }





        public static RealtimeDataGrid getDataGrid(int gridId)
        {
            RealtimeDataGrid dataGridList = null;

            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@GridID", gridId));

                var dataTable = DBAdapter.GetDataTable("NGC_GetDataGrid", parameters);

                foreach (DataRow row in dataTable.Rows)
                {
                    string title = row[0].ToString();
                    int businessUnitID = DBAdapter.getIntValue(row[1].ToString());
                    int cssStyleID = DBAdapter.getIntValue(row[2].ToString());
                    int thresholdID = DBAdapter.getIntValue(row[3].ToString());
                    string thresholdScript = row[4].ToString();
                    bool isToggle = DBAdapter.getBoolValue(row[5].ToString(), false);
                    bool toggleDefault = DBAdapter.getBoolValue(row[6].ToString(), false);

                    dataGridList = new RealtimeDataGrid(gridId, title, businessUnitID, cssStyleID, thresholdID, thresholdScript, isToggle, toggleDefault);

                    AsyncLogger.Info("BLA BLA Success Info");
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.RealtimeData.GetDataGrid", ex);
            }

            return dataGridList;
        }



        public static List<RealtimeDataGridCell> getCellsByDataGrid(int gridId)
        {
            var cells = new List<RealtimeDataGridCell>();

            try
            {
                var parameters = new List<NpgsqlParameter>();
                parameters.Add(new NpgsqlParameter("@GridID", gridId));

                var dataTable = DBAdapter.GetDataTable("NGC_GetCellsByDataGrid", parameters);

                foreach (DataRow row in dataTable.Rows)
                {
                    int cellID = DBAdapter.getIntValue(row[0].ToString());
                    int rowNumber = DBAdapter.getIntValue(row[2].ToString());
                    int cssStyleID = DBAdapter.getIntValue(row[4].ToString());
                    int gridStyleId = DBAdapter.getIntValue(row[5].ToString());
                    int rowStyleId = DBAdapter.getIntValue(row[6].ToString());
                    string cellType = row[7].ToString();
                    string value = row[8].ToString();
                    string tooltip = row[9].ToString();
                    string onClick = row[10].ToString();

                    cells.Add(new RealtimeDataGridCell(cellID, cellType, value, tooltip, onClick, cssStyleID, gridStyleId, rowStyleId, rowNumber));

                    AsyncLogger.Info("BLA BLA Success Info");
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.RealtimeData.getCellsByDataGrid", ex);
            }

            return cells;
        }




        public static Dictionary<int, List<string>> getUnionUsersMetrics()
        {
            var list = new Dictionary<int, List<string>>();

            var dataTable = DBAdapter.GetDataTable("RTSGrid_GetUnionUsersMetrics", null);

            foreach (DataRow row in dataTable.Rows)
            {
                int unionId = DBAdapter.getIntValue(row[0].ToString());
                string metricId = row[1].ToString();

                if (list.ContainsKey(unionId))
                {
                    var metricList = list[unionId];
                    metricList.Add(metricId);
                    list[unionId] = metricList;
                }
                else
                {
                    var metricList = new List<string>();
                    metricList.Add(metricId);
                    list.Add(unionId, metricList);
                }
            }

            return list;
        }






        public static ConcurrentDictionary<int, UserGrid> getAllUserGrid()
        {
            var grids = new ConcurrentDictionary<int, UserGrid>();

            try
            {
                var dataTable = DBAdapter.GetDataTable("RTSUserGrid_GetAllGrids", null);

                foreach (DataRow row in dataTable.Rows)
                {
                    var grid = new UserGrid();
                    grid.GridId = DBAdapter.getIntValue(row[0].ToString());
                    grid.UnionId = DBAdapter.getIntValue(row[1].ToString());
                    grid.Style = row[2].ToString();
                    grid.Title = row[3].ToString();
                    grid.RowsFilter = row[4].ToString();
                    grid.PageSize = DBAdapter.getIntValue(row[5].ToString());
                    grid.ThresholdScript = row[6].ToString();

                    grids.TryAdd(grid.GridId, grid);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.RealtimeData.getUserGrid", ex);
            }

            return grids;
        }





        public static List<string> getUserViewHtmlSettings()
        {
            var list = new List<string>();

            try
            {
                var dataTable = DBAdapter.GetDataTable("RTSUserView_GetHTMLSettings", null); ;

                foreach (DataRow row in dataTable.Rows)
                {
                    string val = row[0].ToString();

                    list.Add(val);
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("NGC.DataProvider.RealtimeData.getUserViewHtmlSettings", ex);
            }

            return list;
        }

    }
}
