using RTM.Tools;
using System.Diagnostics;
using System.Globalization;
using System.Management;
using System.Net;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace RTM.Configuration
{
    public class LicenseManager
    {
        public static string GenerateLicense(string macAddress, string vmUuid, string hostName, string companyName, int numberOfPorts, DateTime startDate, DateTime? expirationDate = null)
        {
            string id = GetLicenseId(macAddress, vmUuid, hostName);
            string licenseContent = expirationDate.HasValue ? $"{id}|{companyName}|{numberOfPorts}|{startDate:dd/MM/yyyy}|{expirationDate.Value:dd/MM/yyyy}" : $"{id}|{companyName}|{numberOfPorts}|PERMANENT";

            string license = string.Empty;

            do
            {
                license = EncryptString(Configuration.Password, licenseContent);
            }
            while (license.Contains('/'));

            return license;
        }






        public static LicenseInfo ValidateLicense(string encryptedLicense)
        {
            LicenseInfo licenseInfo = new LicenseInfo(string.Empty, 0, DateTime.MinValue, DateTime.MinValue, string.Empty, License.NotValid);

            try
            {
                string vmUuid = GetVMUuid();
                string hostName = GetHostName();
                string macAddress = GetMacAddress();

                AsyncLogger.Info("MacAddress = " + macAddress);
                AsyncLogger.Info("HostName = " + hostName);
                AsyncLogger.Info("VM UUID = " + vmUuid);


                string decryptedLicense = DecryptString(Configuration.Password, encryptedLicense);
                string[] parts = decryptedLicense.Split('|');
                if (parts.Length != 5) return licenseInfo;

                string licenseId = parts[0];
                string customerName = parts[1];
                if (!int.TryParse(parts[2], out int numberOfPorts)) return licenseInfo;
                string startDate = parts[3];
                string expiration = parts[4];

                string id = GetLicenseId(macAddress, vmUuid, hostName);

                //AsyncLogger.Info("licenseId=" + licenseId + " expiration=" + expiration + " id=" + id);

                if (licenseId != id) return licenseInfo;

                if (expiration == "PERMANENT")
                {
                    licenseInfo.License = License.Valid;
                    licenseInfo.CustomerName = customerName;
                    licenseInfo.ActivationDate = DateTime.ParseExact(startDate, "dd/MM/yyyy", CultureInfo.InvariantCulture);
                    licenseInfo.ExpirationDate = DateTime.MaxValue;
                    licenseInfo.NumPorts = numberOfPorts;
                    return licenseInfo;
                }


                if (DateTime.TryParseExact(expiration, "dd/MM/yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, out DateTime expirationDate))
                {
                    if (DateTime.Now > expirationDate)
                    {
                        licenseInfo.License = License.Expired;
                        return licenseInfo;
                    }
                    else
                    {
                        licenseInfo.License = License.Valid;
                        licenseInfo.CustomerName = customerName;
                        licenseInfo.ActivationDate = DateTime.ParseExact(startDate, "dd/MM/yyyy", CultureInfo.InvariantCulture);
                        licenseInfo.ExpirationDate = DateTime.ParseExact(expiration, "dd/MM/yyyy", CultureInfo.InvariantCulture);
                        licenseInfo.NumPorts = numberOfPorts;
                        return licenseInfo;
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("ValidateLicense", ex);
            }

            return licenseInfo;
        }




        public static string GetLicenseId(string mac, string uuid, string hostname)
        {
            // Ensure the inputs are normalized: no leading/trailing whitespace, and in the same case
            string normalizedMac = mac.Trim().ToUpperInvariant();
            string normalizedUuid = uuid.Trim().ToUpperInvariant();
            string normalizedHostname = hostname.Trim().ToUpperInvariant();

            // Combine the inputs
            string combined = $"{normalizedMac}-{normalizedUuid}-{normalizedHostname}";

            // Display the combined string for debugging purposes
            //Console.WriteLine($"Combined input: {combined}");

            // Create a SHA256 hash
            using (SHA256 sha256Hash = SHA256.Create())
            {
                // ComputeHash - returns byte array
                byte[] bytes = sha256Hash.ComputeHash(Encoding.UTF8.GetBytes(combined));

                // Convert byte array to a string representation (for debugging)
                string hashAsString = BitConverter.ToString(bytes).Replace("-", string.Empty).ToUpperInvariant();
                //Console.WriteLine($"Full SHA256 Hash: {hashAsString}");

                // Take the first 12 characters of the hash
                return hashAsString.Substring(0, 12);
            }
        }



        public static string GetMacAddress1()
        {
            foreach (NetworkInterface nic in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (nic.OperationalStatus == OperationalStatus.Up)
                {
                    return nic.GetPhysicalAddress().ToString();
                }
            }
            return string.Empty;
        }



        public static string GetMacAddress()
        {
            string macAddress = string.Empty;

            try
            {
                foreach (NetworkInterface nic in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (nic.OperationalStatus == OperationalStatus.Up && nic.NetworkInterfaceType != NetworkInterfaceType.Loopback)
                    {
                        macAddress = nic.GetPhysicalAddress().ToString();
                        break;
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("GetMacAddress", ex);
            }


            return macAddress;
        }





        public static string GetLinuxMacAddress()
        {
            try
            {
                ProcessStartInfo startInfo = new ProcessStartInfo
                {
                    FileName = "/bin/bash",
                    Arguments = "-c \"ip link\"",
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                };

                using (Process process = Process.Start(startInfo))
                using (StreamReader reader = process.StandardOutput)
                {
                    string result = reader.ReadToEnd();
                    Match match = Regex.Match(result, @"link/ether (\S+)");
                    if (match.Success)
                    {
                        return match.Groups[1].Value;
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("GetLinuxMacAddress", ex);
            }

            return string.Empty;
        }






        public static string GetHostName()
        {
            string hostName = Dns.GetHostName();
            return hostName;
        }




        public static string GetVMUuid()
        {
            string uuid = "";

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                // Use WMI for Windows
                uuid = GetWindowsVMUuid();
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                // Use /sys/class/dmi/id/product_uuid for Linux
                uuid = GetLinuxVMUuid();
            }

            return uuid;
        }



        private static string GetWindowsVMUuid()
        {
            string uuid = string.Empty;
            var scope = new ManagementScope(@"\\.\root\cimv2");
            var query = new ObjectQuery("SELECT * FROM Win32_ComputerSystemProduct");

            using (var searcher = new ManagementObjectSearcher(scope, query))
            {
                foreach (ManagementObject queryObj in searcher.Get())
                {
                    uuid = queryObj["UUID"].ToString();
                    break;
                }
            }

            return uuid;
        }



        private static string GetLinuxVMUuid()
        {
            string uuid = "";
            try
            {
                uuid = File.ReadAllText("/sys/class/dmi/id/product_uuid");
            }
            catch (IOException e)
            {
                AsyncLogger.Error("An I/O error occurred while trying to read the UUID", e);
            }
            return uuid;
        }






        public static string EncryptString(string password, string plainText)
        {
            byte[] encrypted;

            using (Aes aes = Aes.Create())
            {
                var key = new Rfc2898DeriveBytes(password, new byte[] { 1, 2, 3, 4, 5, 6, 7, 8 }); // Salt can be random too
                aes.Key = key.GetBytes(32); // Use 256-bit key
                aes.GenerateIV();

                ICryptoTransform encryptor = aes.CreateEncryptor(aes.Key, aes.IV);

                using (MemoryStream memoryStream = new MemoryStream())
                {
                    memoryStream.Write(aes.IV, 0, aes.IV.Length);

                    using (CryptoStream cryptoStream = new CryptoStream(memoryStream, encryptor, CryptoStreamMode.Write))
                    {
                        using (StreamWriter streamWriter = new StreamWriter(cryptoStream))
                        {
                            streamWriter.Write(plainText);
                        }
                    }

                    encrypted = memoryStream.ToArray();
                }
            }

            return Convert.ToBase64String(encrypted);
        }





        public static string DecryptString(string password, string cipherText)
        {
            byte[] bytes = Convert.FromBase64String(cipherText);
            byte[] iv = new byte[16];
            Array.Copy(bytes, 0, iv, 0, iv.Length);

            using (Aes aes = Aes.Create())
            {
                var key = new Rfc2898DeriveBytes(password, new byte[] { 1, 2, 3, 4, 5, 6, 7, 8 });
                aes.Key = key.GetBytes(32); // Use 256-bit key
                aes.IV = iv;

                ICryptoTransform decryptor = aes.CreateDecryptor(aes.Key, aes.IV);

                using (MemoryStream memoryStream = new MemoryStream(bytes, iv.Length, bytes.Length - iv.Length))
                {
                    using (CryptoStream cryptoStream = new CryptoStream(memoryStream, decryptor, CryptoStreamMode.Read))
                    {
                        using (StreamReader streamReader = new StreamReader(cryptoStream))
                        {
                            return streamReader.ReadToEnd();// System.Security.Cryptography.CryptographicException: 'Padding is invalid and cannot be removed.'
                        }
                    }
                }
            }
        }
    }
}
