using System.Collections.Concurrent;

namespace RTM
{
    public class MetricDef
    {
        public MetricDef(string id, string function, string parameter, string format)
        {
            ID = id;
            Function = function;
            Parameter = parameter;
            Format = format;
        }

        public MetricDef()
        {
        }

        public string ID { get; set; }

        public string DataType { get; set; }

        public string Function { get; set; }

        public string Parameter { get; set; }

        public string Format { get; set; }

        public string Description { get; set; }

        public string DefaultValue { get; set; }


        public Func<ConcurrentBag<IDInteraction>, bool, string> MetricFunction { get; set; }


        public Func<ConcurrentBag<IDInteraction>, string, string> MetricUserFunction { get; set; }


        public Func<ConcurrentBag<IDInteraction>, List<IDInteraction>> InteractionsListFunction { get; set; }
    }
}
