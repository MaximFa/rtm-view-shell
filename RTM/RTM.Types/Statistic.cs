using Newtonsoft.Json;
using System.Runtime.Serialization;
using System.Xml;
using Formatting = Newtonsoft.Json.Formatting;

namespace RTM.Types
{
    [DataContract]
    public class Statistic
    {
        public Statistic(string category, string definition)
        {
            Category = category;
            Definition = definition;
            Parameters = new List<StatisticParameter>();
        }

        [DataMember]
        public string Category { get; set; }

        [DataMember]
        public string Definition { get; set; }

        [DataMember]
        public List<StatisticParameter> Parameters { get; set; }


        public string getStatisticKey()
        {
            string statisticKey = Category + "." + Definition;

            foreach (var param in Parameters)
            {
                statisticKey += "-" + param.ParameterType + "=" + param.Value;
            }

            return statisticKey;
        }



        public static string getJsonString(Statistic statistic)
        {
            string data = string.Empty;

            try
            {
                data = JsonConvert.SerializeObject(statistic, Formatting.Indented);
            }
            catch (Exception ex)
            {
            }

            return data;
        }


        public static Statistic setJsonString(string data)
        {
            Statistic statistic = null;

            try
            {
                statistic = JsonConvert.DeserializeObject(data, typeof(Statistic)) as Statistic;
            }
            catch (Exception ex)
            {
            }

            return statistic;
        }
    }




    [DataContract]
    public class StatisticParameter
    {
        public StatisticParameter(string parameterType, string value)
        {
            ParameterType = parameterType;
            Value = value;
        }

        [DataMember]
        public string ParameterType { get; set; }

        [DataMember]
        public string Value { get; set; }
    }
}
