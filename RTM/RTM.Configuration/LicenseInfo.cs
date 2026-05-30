using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Configuration
{
    public enum License
    {
        Valid,
        NotValid,
        Expired
    }



    public class LicenseInfo
    {
        public LicenseInfo(string customerName, int numPorts, DateTime activationDate, DateTime expirationDate, string licenseKey, License license)
        {
            CustomerName = customerName;
            NumPorts = numPorts;
            ActivationDate = activationDate;
            ExpirationDate = expirationDate;
            LicenseKey = licenseKey;
            License = license;
        }


        public string CustomerName { get; set; }


        public int NumPorts { get; set; }


        public DateTime ActivationDate { get; set; }


        public DateTime? ExpirationDate { get; set; }


        public string LicenseKey { get; set; }


        public License License { get; set; }

    }
}
