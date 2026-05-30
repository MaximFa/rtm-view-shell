using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Types
{
    public class Site
    {
        public string SiteId { get; set; }
         

        public string SiteName { get; set; }


        public string Description { get; set; }


        public string TimeZone { get; set; }


        public TimeSpan ClearTime { get; set; }
    }
}
