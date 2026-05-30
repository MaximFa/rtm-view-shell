using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class ApplicList : ConcurrentDictionary<QueueClassification, Applic>
    {
        private UnionList _unionList = new UnionList();


        public ApplicList(UnionList unionList) : base()
        {
            _unionList = unionList;
        }


        public new bool TryAdd(QueueClassification key, Applic value)
        {
            try
            {
                foreach (var union in _unionList)
                {
                    if (union.Value.Queues.Contains(key.QueueId) || union.Value.Classifications.Contains(key.ClassificationId))
                    {
                        union.Value.Applics.TryAdd(key, value);                      
                    }
                }
            }
            catch (Exception ex)
            {

            }

            return base.TryAdd(key, value);
        }

    }
}