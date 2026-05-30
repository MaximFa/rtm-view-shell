using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Configuration
{
    public class EncryptConfig
    {
        public string LicenseKey { get; set; } = "defaultLicense";
        public string DatabaseUser { get; set; } = "defaultUser";
        public string DatabasePassword { get; set; } = "defaultPassword";
        public string KestrelHttpsPassword { get; set; } = "defaultPassword";
    }
}
