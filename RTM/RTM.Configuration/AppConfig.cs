using System.Net.Sockets;
using System.Net;
using System.Reflection;
using RTM.Tools;
using Microsoft.Extensions.Configuration;

namespace RTM.Configuration
{
   
    public static class AppConfig
    {
        private static IConfigurationRoot _configuration;

        // Kestrel properties
        //public static KestrelOptions Kestrel { get; private set; }

        // Other properties
        public static string RTMConnectionString { get; private set; }
       
        public static string DefaultTimeZone { get; private set; }

        public static string AgentWGPerfix { get; private set; }

        public static int CalcInterval { get; private set; }


        public static string AdapterServiceName { get; set; }


        public static string LicenseKey { get; private set; }
        public static string DatabaseUser { get; private set; }
        public static string DatabasePassword { get; private set; }
        public static string KestrelHttpsPassword { get; private set; }
        public static string LocalIPAddress { get; private set; }
        public static string Version { get; private set; }



        public static void Initialize(IConfiguration configuration, string dataFilePath)
        {
            try
            {
                _configuration = (IConfigurationRoot)configuration;

                // Load other values from appsettings.json and app.dat
                RTMConnectionString = configuration["ConnectionStrings:RTMConnectionString"];
                AgentWGPerfix = configuration["RTM:AgentWGPerfixList"];
                CalcInterval = int.Parse(configuration["RTM:CalcInterval"]);
                DefaultTimeZone = configuration["RTM:DefaultTimeZone"];

                AdapterServiceName = configuration["RTM:AdaptorServiceName"];


                // Load and decrypt sensitive values from data.sys
                // encryptedData = File.ReadAllText("data.sys");
                string encryptedData = File.ReadAllText(dataFilePath);
                //EncryptConfig decryptedConfig = EncryptionHelper.DecryptConfiguration(encryptedData);
                EncryptConfig decryptedConfig = EncryptionHelper.DecryptConfiguration<EncryptConfig>(encryptedData);


                LicenseKey = decryptedConfig.LicenseKey;
                DatabaseUser = decryptedConfig.DatabaseUser;
                DatabasePassword = decryptedConfig.DatabasePassword;
                KestrelHttpsPassword = decryptedConfig.KestrelHttpsPassword;

                // Update the connection string with the decrypted database user and password
                var builder = new System.Data.Common.DbConnectionStringBuilder
                {
                    ConnectionString = RTMConnectionString
                };
                builder["Username"] = DatabaseUser;
                builder["Password"] = DatabasePassword;
                RTMConnectionString = builder.ConnectionString;


                // Load LocalIPAddress or find it programmatically
                LocalIPAddress = configuration["LocalIPAddress"] ?? GetLocalIPAddress();

                // Load version from the entry assembly
                Version = GetAssemblyVersion();

                // Validate critical configuration values
                ValidateConfiguration();
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.Initialize", ex);
            }
        }


        public static void ReloadConfiguration(string dataFilePath)
        {
            try
            {
                _configuration.Reload();
                Initialize(_configuration, dataFilePath); // Re-initialize to refresh values
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.ReloadConfiguration", ex);
            }
        }


        private static void ValidateConfiguration()
        {
            try
            {
                if (string.IsNullOrEmpty(DatabaseUser))
                {
                    throw new InvalidOperationException("DatabaseUser configuration is missing or empty.");
                }

                if (string.IsNullOrEmpty(DatabasePassword))
                {
                    throw new InvalidOperationException("DatabasePassword configuration is missing or empty.");
                }

                if (string.IsNullOrEmpty(LicenseKey))
                {
                    throw new InvalidOperationException("LicenseKey configuration is missing or empty.");
                }

                // Add additional validation as necessary
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.ValidateConfiguration", ex);
            }
        }



        private static string GetLocalIPAddress()
        {
            try
            {
                var host = Dns.GetHostEntry(Dns.GetHostName());
                foreach (var ip in host.AddressList)
                {
                    if (ip.AddressFamily == AddressFamily.InterNetwork)
                    {
                        return ip.ToString();
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.GetLocalIPAddress", ex);
            }
            return string.Empty;
        }



        private static string GetAssemblyVersion()
        {
            try
            {
                var entryAssembly = Assembly.GetEntryAssembly();
                return entryAssembly?.GetName().Version?.ToString() ?? "Version not found";
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("AppConfig.GetAssemblyVersion", ex);
            }
            return string.Empty;
        }
    }
}
