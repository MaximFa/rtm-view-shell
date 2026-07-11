using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace RTM.Tools
{
    public static class DictionarySerializer
    {
        public static string SerializeToJson(Dictionary<string, object> dict)
        {
            JsonSerializerSettings settings = new JsonSerializerSettings
            {
                DateFormatString = "yyyy-MM-ddTHH:mm:ss.fffffffK"
            };

            return JsonConvert.SerializeObject(dict, settings);
        }


        public static Dictionary<string, object> DeserializeFromJson(string jsonString)
        {
            JsonSerializerSettings settings = new JsonSerializerSettings
            {
                DateFormatString = "yyyy-MM-ddTHH:mm:ss.fffffffK"
            };

            return JsonConvert.DeserializeObject<Dictionary<string, object>>(jsonString, settings);
        }




        public static string getString(object obj)
        {
            return obj?.ToString() ?? string.Empty;
        }



        public static DateTime getDateTime(object obj)
        {
            DateTime dt = default;

            try
            {
                if (obj is DateTime dateTimeValue)
                {
                    dt = dateTimeValue;
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("getDateTime", ex);
            }

            //AsyncLogger.Info("getDateTime " + obj.ToString() + " " + dt);

            return dt;
        }


        
       


        public static long getLong(object obj) 
        {
            long long1 = default;

            try
            {
                long1 = obj is JsonElement elemant
                        ? elemant.GetInt64()
                        : Convert.ToInt64(obj);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("getLong", ex);
            }

            //AsyncLogger.Info("getLong " + long1);

            return long1;
        }



        public static int getInt(object obj)
        {
            int int1 = default;

            try
            {
                int1 = obj is JsonElement elemant
                        ? elemant.GetInt32()
                        : Convert.ToInt32(obj);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("getInt", ex);
            }

            //AsyncLogger.Info("getInt " + int1);

            return int1;
        }



        public static bool getBool(object obj)
        {
            bool b = default;

            try
            {
                b = obj is JsonElement elemant
                        ? elemant.GetBoolean()
                        : Convert.ToBoolean(obj);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("getBool", ex);
            }

            //AsyncLogger.Info("getBool " + b);

            return b;
        }



        public static TimeSpan getTimeSpan(object obj)
        {
            TimeSpan ts = default;
           
            try
            {
                if (obj is string timeSpanString)
                {
                    if (TimeSpan.TryParse(timeSpanString, out TimeSpan parsedTimeSpan))
                    {
                        ts = parsedTimeSpan;
                    }
                    else
                    {
                        AsyncLogger.Info($"Unable to parse '{timeSpanString}' as TimeSpan.");
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("GetTimeSpan", ex);
            }

            //AsyncLogger.Info("GetTimeSpan: " + ts);

            return ts;
        }




        public static List<string> getList(object obj)
        {
            List<string> list = new List<string>();

            try
            {
                //AsyncLogger.Info("GetList received object type: " + obj.GetType().FullName);
                //AsyncLogger.Info("GetList received object: " + obj.ToString());

                if (obj is JArray jArray)
                {
                    foreach (var item in jArray)
                    {
                        if (item.Type == JTokenType.String)
                        {
                            list.Add(item.ToString());
                        }
                        else
                        {
                            AsyncLogger.Info("Non-string item encountered: " + item.ToString());
                        }
                    }
                }
                else
                {
                    AsyncLogger.Info("Object is not a JArray: " + obj.ToString());
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("GetList " + obj.ToString(), ex);
            }

            //AsyncLogger.Info("GetList count=" + list.Count);

            return list;
        }



        public static Dictionary<string, string> getDictionary(object obj)
        {
            Dictionary<string, string> dictionary = new Dictionary<string, string>();

            try
            {               
                if (obj is JObject jObject)
                {
                    foreach (var pair in jObject)
                    {
                        // Convert the JToken to a string value
                        dictionary[pair.Key] = pair.Value.ToString();
                    }
                }
                else
                {
                    AsyncLogger.Info("Object is not a JObject: " + obj.ToString());
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("GetDictionary " + obj.ToString(), ex);
            }

            return dictionary;
        }


    }

}
