using System.Collections.Concurrent;
using System.Runtime.Serialization;

namespace RTM
{
    [Serializable]
    public class AjaxDictionary<TKey, TValue> : ISerializable
    {
        private ConcurrentDictionary<TKey, TValue> _Dictionary;
        public AjaxDictionary()
        {
            _Dictionary = new ConcurrentDictionary<TKey, TValue>();
        }
        public AjaxDictionary(SerializationInfo info, StreamingContext context)
        {
            _Dictionary = new ConcurrentDictionary<TKey, TValue>();
        }
        public TValue this[TKey key]
        {
            get { return _Dictionary[key]; }
            set { _Dictionary[key] = value; }
        }
        public void Add(TKey key, TValue value)
        {
            _Dictionary.TryAdd(key, value);
        }
        public bool ContainsKey(TKey key)
        {
            return _Dictionary.ContainsKey(key);
        }
        public void GetObjectData(SerializationInfo info, StreamingContext context)
        {
            foreach (TKey key in _Dictionary.Keys.ToList())
                info.AddValue(key.ToString(), _Dictionary[key]);
        }
    }



    public class RTUsersResult
    {
        public List<AjaxDictionary<string, string>> Data { get; set; }

        public int Count { get; set; }
    }
}
