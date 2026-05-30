using Microsoft.VisualBasic;
using RTM.Tools;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class Applic
    {
        public QueueClassification ApplicId { get; private set; }
       
      
        public Applic(QueueClassification applicId)
        {
            ApplicId = applicId;
        }

    }
}
