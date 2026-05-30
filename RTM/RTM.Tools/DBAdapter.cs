using System;
using System.Collections.Generic;
using System.Configuration;

using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Npgsql;

namespace RTM.Tools
{
    public class DBAdapter
    {
        public static string ConnectionString { get; set; }

        public static int getIntValue(string value)
        {
            int i = -1;
            if (!int.TryParse(value, out i))
            {
                i = -1;
            }
            return i;
        }

        public static double getDoubleValue(string value)
        {
            double d = -1;
            if (!double.TryParse(value, out d))
            {
                d = -1;
            }
            return d;
        }

        public static bool getBoolValue(string value, bool defaultValue)
        {
            bool b = defaultValue;
            value = value.ToUpper();
            switch (value)
            {
                case "Y":
                case "1":
                case "TRUE":
                    b = true;
                    break;
                case "N":
                case "0":
                case "FALSE":
                    b = false;
                    break;
            }
            return b;
        }

        public static DateTime getDateTimeValue(string value)
        {
            DateTime d = DateTime.MinValue;
            if (!DateTime.TryParse(value, out d))
            {
                d = DateTime.MinValue;
            }
            return d;
        }

        public static TimeSpan getTimeSpanValue(string value)
        {
            TimeSpan ts = TimeSpan.Zero;
            string[] timeSplit = value.Split(':');
            int hh = Convert.ToInt32(timeSplit[0]);
            int mm = Convert.ToInt32(timeSplit[1]);
            ts = new TimeSpan(hh, mm, 0);
            return ts;
        }

        public static string GetScalar(string spName, List<NpgsqlParameter> parameters)
        {
            return GetScalar(spName, ConnectionString, parameters);
        }

        public static string GetScalar(string spName, string connectionString, List<NpgsqlParameter> parameters)
        {
            string result = null;
            try
            {
                using (NpgsqlConnection connection = new NpgsqlConnection(connectionString))
                {
                    var command = new NpgsqlCommand();
                    command.Connection = connection;

                    // PostgreSQL: use SELECT * FROM "FunctionName"(params) syntax
                    command.CommandType = System.Data.CommandType.Text;
                    if (parameters != null && parameters.Count > 0)
                    {
                        var paramPlaceholders = string.Join(", ", parameters.Select((_, i) => $"${i + 1}"));
                        command.CommandText = $"SELECT * FROM \"{spName}\"({paramPlaceholders})";
                        foreach (var p in parameters)
                            command.Parameters.Add(new NpgsqlParameter { Value = p.Value ?? DBNull.Value });
                    }
                    else
                    {
                        command.CommandText = $"SELECT * FROM \"{spName}\"()";
                    }

                    connection.Open();
                    result = command.ExecuteScalar()?.ToString();

                    /*using (SqlDataReader sqlReader = command.ExecuteReader())
                    {
                        if (sqlReader.HasRows)
                        {
                            while (sqlReader.Read())
                            {
                                result = sqlReader.GetDecimal(0).ToString();                               
                            }
                        }
                    }*/
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("DBadaptor.GetScalar spName=" + spName, ex);
            }
            return result;
        }

        public static void ExecuteNonQuery(string spName, List<NpgsqlParameter> parameters)
        {
            ExecuteNonQuery(spName, ConnectionString, parameters);
        }

        public static void ExecuteNonQuery(string spName, string connectionString, List<NpgsqlParameter> parameters)
        {
            string strParam = string.Empty;
            try
            {
                using (NpgsqlConnection connection = new NpgsqlConnection(connectionString))
                {
                    var command = new NpgsqlCommand();
                    command.Connection = connection;

                    // PostgreSQL: use CALL "FunctionName"(params) for void functions
                    command.CommandType = System.Data.CommandType.Text;
                    if (parameters != null && parameters.Count > 0)
                    {
                        var paramPlaceholders = string.Join(", ", parameters.Select((_, i) => $"${i + 1}"));
                        command.CommandText = $"CALL \"{spName}\"({paramPlaceholders})";
                        foreach (var p in parameters)
                        {
                            command.Parameters.Add(new NpgsqlParameter { Value = p.Value ?? DBNull.Value });
                            strParam += $"[param={p.ParameterName} Value={p.Value}]";
                        }
                    }
                    else
                    {
                        command.CommandText = $"CALL \"{spName}\"()";
                    }

                    connection.Open();
                    command.ExecuteNonQuery();
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("DBadaptor.ExecuteNonQuery spName=" + spName + " Param=" + strParam, ex);
            }
        }

        public static DataTable GetDataTable(string spName, List<NpgsqlParameter> parameters)
        {
            return GetDataTable(spName, ConnectionString, parameters);
        }

        public static DataTable GetQueryDataTable(string query, string connectionString)
        {
            DataTable result = new DataTable();

            try
            {
                using (NpgsqlConnection connection = new NpgsqlConnection(connectionString))
                {
                    var command = new NpgsqlCommand(query, connection);
                    command.CommandType = System.Data.CommandType.Text;
                    connection.Open();
                    DataSet ds = new DataSet();
                    using (NpgsqlDataAdapter adapter = new NpgsqlDataAdapter(command))
                    {
                        adapter.Fill(result);
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("DBadaptor.GetQueryDataTable query=" + query, ex);
            }
            return result;
        }

        public static DataTable GetDataTable(string spName, string connectionString, List<NpgsqlParameter> parameters)
        {
            DataTable result = new DataTable();

            try
            {
                using (NpgsqlConnection connection = new NpgsqlConnection(connectionString))
                {
                    var command = new NpgsqlCommand();
                    command.Connection = connection;
                    command.CommandTimeout = 120;

                    // PostgreSQL: use SELECT * FROM "FunctionName"(params) syntax for RETURNS TABLE functions
                    command.CommandType = CommandType.Text;
                    if (parameters != null && parameters.Count > 0)
                    {
                        var paramPlaceholders = string.Join(", ", parameters.Select((_, i) => $"${i + 1}"));
                        command.CommandText = $"SELECT * FROM \"{spName}\"({paramPlaceholders})";
                        foreach (var p in parameters)
                            command.Parameters.Add(new NpgsqlParameter { Value = p.Value ?? DBNull.Value });
                    }
                    else
                    {
                        command.CommandText = $"SELECT * FROM \"{spName}\"()";
                    }

                    using (NpgsqlDataAdapter adapter = new NpgsqlDataAdapter(command))
                    {
                        adapter.Fill(result);
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("DBadaptor.GetDataTable spName=" + spName, ex);
            }
            return result;
        }
    }
}