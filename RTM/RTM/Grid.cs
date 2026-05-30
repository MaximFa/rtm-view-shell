using RTM.Tools;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class Grid
    {
        public delegate void GridEventHandler(object sender, GridEventArgs e);
        public event GridEventHandler GridEvent;


        public Grid(int gridId)
        {
            GridId = gridId;
        }

        public int GridId { set; get; }


        public CellList Cells { get; } = new CellList();



        public ConcurrentDictionary<string, int> Connections = new ConcurrentDictionary<string, int>();



        public bool InUse { get; set; }



        public void report()
        {
            try
            {
                ConcurrentDictionary<int, string> cellsValuesList = null;

                var changedCells = from cell in Cells.Values
                                   where cell.IsChanged
                                   select cell;

                if (changedCells.Count() > 0)
                {
                    //AsyncLogger.Info("Grid.report changedCells.Count() > 0");

                    cellsValuesList = new ConcurrentDictionary<int, string>();

                    foreach (Cell cell in changedCells)
                    {
                        cellsValuesList.TryAdd(cell.CellId, cell.Value);
                        cell.IsChanged = false;
                    }

                    if (GridEvent != null)
                    {
                        GridEvent(this, new GridEventArgs(GridId, cellsValuesList));
                    }
                }
            }
            catch (Exception ex)
            {
                AsyncLogger.Error("Grid.report", ex);
            }
        }
    }
}
