using Microsoft.AspNetCore.Identity;
using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace RTM
{
    public class CollectData
    {
        private UnionList _unionList = null;
        private GridList _gridList = null;
        private IDInteractionsList _interactionsList = null;
        private UserManagerList _userManagerList = null;

        private ConcurrentDictionary<string, MetricDef> _userGridMetrics = new ConcurrentDictionary<string, MetricDef>();

        private bool isFirstTime = true;

        private int CalcInterval { get; set; } = 2;



        public CollectData(UnionList unionList, GridList gridList, IDInteractionsList interactionsList,
            UserManagerList userManagerList, ConcurrentDictionary<string, MetricDef> userGridMetrics, int calcInterval)
        {
            try
            {
                CalcInterval = calcInterval;

                _unionList = unionList;
                _gridList = gridList;
                _interactionsList = interactionsList;
                _userManagerList = userManagerList;
                _userGridMetrics = userGridMetrics;

                //midnightClear();
                var cancellationTokenSource = new CancellationTokenSource();
                var task = Repeat.Interval(TimeSpan.FromSeconds(CalcInterval), () => getData(), cancellationTokenSource.Token);
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("CollectData.CollectData", ex);
            }
        }



        internal static class Repeat
        {
            public static Task Interval(TimeSpan pollInterval, Action action, CancellationToken token)
            {
                return Task.Factory.StartNew(
                    () =>
                    {
                        for (; ; )
                        {
                            if (token.WaitHandle.WaitOne(pollInterval))
                                break;

                            action();
                        }
                    }, token, TaskCreationOptions.LongRunning, TaskScheduler.Default);
            }
        }



        long longestAction = 0;
        int cnt = 0;





        public void getUnionData(Union union, List<UserManager> changedUsersData)
        {
            if (!union.IsGettingData)
            {
                union.getData(changedUsersData);
            }
        }



        public void getData()
        {
            try
            {
                DateTime now = DateTime.Now;
                var watch = System.Diagnostics.Stopwatch.StartNew();

                var ChangedUsersData = new List<UserManager>();

                List<Task> tasks1 = new List<Task>();
                foreach (UserManager user in _userManagerList.Values)
                {
                    if (user.IsChanged)
                    {
                        user.IsChanged = false;
                        ChangedUsersData.Add(user);
                        Task t = new Task(() => user.getUserData());
                        tasks1.Add(t);
                        t.Start();
                    }
                }
                try
                {
                    Task.WaitAll(tasks1.ToArray());
                }
                catch { }

                var elapsedMs1 = watch.ElapsedMilliseconds;


                List<Task> tasks2 = new List<Task>();
                foreach (Union union in _unionList.Values)
                {
                    //Task t = new Task(() => union.getData(ChangedUsersData));
                    Task t = new Task(() => getUnionData(union, ChangedUsersData));
                    tasks2.Add(t);
                    t.Start();
                }
                try
                {
                    if (!Task.WaitAll(tasks2.ToArray(), (CalcInterval * 1000)))
                    {
                        AsyncLogger.Info("CollectData.getData !Task.WaitAll");
                    }
                }
                catch { }

                var elapsedMs2 = watch.ElapsedMilliseconds - elapsedMs1;

                foreach (Grid grid in _gridList.Values)
                {
                    grid.report();
                }

                watch.Stop();
                var elapsedMs = watch.ElapsedMilliseconds;

                if (isFirstTime)
                {
                    isFirstTime = false;
                    //AsyncLogger.Info("CollectData.getData LongestAction(1st time) = " + elapsedMs);
                }
                else
                {
                    //if (elapsedMs > longestAction)
                    cnt++;
                    if (cnt == 100)
                    {
                        cnt = 0;
                        longestAction = elapsedMs;
                        AsyncLogger.Info("CollectData.getData Now=" + now + " LongestAction = " + longestAction + " (" + elapsedMs1 + "," + elapsedMs2 + ")");
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("CollectData.getData", ex);
            }
        }
    }
}
