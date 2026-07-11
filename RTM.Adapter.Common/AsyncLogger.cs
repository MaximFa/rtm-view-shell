using log4net.Config;
using log4net;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Tools
{
    public static class AsyncLogger
    {
        private static ILog log;// = LogManager.GetLogger(typeof(AsyncLogger));
        private static readonly BlockingCollection<Action> logQueue = new BlockingCollection<Action>();
        private static readonly Thread logThread;

        static AsyncLogger()
        {
            logThread = new Thread(RunLogging) { IsBackground = true };
            logThread.Start();
        }


        public static void InitializeLog4Net(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                throw new ArgumentException("Path to log4net configuration file is null or whitespace.");
            }

            var fileConfig = new System.IO.FileInfo(path);
            if (!fileConfig.Exists)
            {
                throw new FileNotFoundException($"Log4net configuration file not found at {path}.");
            }

            try
            {
                XmlConfigurator.ConfigureAndWatch(fileConfig);
                log = LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);
            }
            catch (Exception ex)
            {
                // Handle exceptions related to log4net configuration here
                // For example, log to the console or take other appropriate actions
                Console.WriteLine($"Error configuring log4net: {ex.Message}");
            }
        }



        public static void Info(string message)
        {
            EnqueueLog(() => log.Info(message));
        }


        public static void Error(string message)
        {
            EnqueueLog(() => log.Error(message));
        }



        public static void Error(string message, Exception ex)
        {
            EnqueueLog(() => log.Error(message, ex));
        }



        private static void EnqueueLog(Action logAction)
        {
            if (!logQueue.IsAddingCompleted)
            {
                logQueue.Add(logAction);
            }
        }


        private static void RunLogging()
        {
            foreach (var logAction in logQueue.GetConsumingEnumerable())
            {
                try
                {
                    logAction();
                }
                catch (Exception ex)
                {
                    // Handle logging exceptions here
                }
            }
        }


        public static void Shutdown()
        {
            logQueue.CompleteAdding();
            logThread.Join(); // Wait for the logging thread to finish processing
        }
    }
}