using log4net;
using log4net.Config;
using log4net.Core;
using System.Reflection;

namespace RTM.Tools
{
    public class NGCLog
    {
        private static ILog log;

        private static bool _writeInfo = false;


        static NGCLog()
        {
            //setLog("log4net.config");
        }


        public static void setLog(string path)
        {
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly());
            XmlConfigurator.Configure(logRepository, new FileInfo(path));

            //System.IO.FileInfo fileConfig = new System.IO.FileInfo(path);
            //XmlConfigurator.ConfigureAndWatch(fileConfig);
            log = LogManager.GetLogger(typeof(LoggerManager));
        }


        public static void setLog(string path, bool writeInfo)
        {
            _writeInfo = writeInfo;
            setLog(path);
        }


        public static void Info(string msg)
        {
            //Task.Run(() => log.Info(msg));
            log.Info(msg);
        }



        public static void TryInfo(string msg)
        {
            if (_writeInfo)
            {
                Info(msg);
            }
        }


        public static void Error(string msg)
        {
            //Task.Run(() => log.Error(msg));
            log.Error(msg);
        }


        public static void Error(string msg, Exception ex)
        {
            //Task.Run(() => log.Error(msg, ex));
            log.Error(msg, ex);
        }
    }
}