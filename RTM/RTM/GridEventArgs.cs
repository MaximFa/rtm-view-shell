using System.Collections.Concurrent;


namespace RTM
{
    public class GridEventArgs : EventArgs
    {


        public GridEventArgs(int gridId, ConcurrentDictionary<int, string> cellsValuesList)
        {
            GridId = gridId;
            CellsValuesList = cellsValuesList;
        }


        public int GridId { get; set; }


        public ConcurrentDictionary<int, string> CellsValuesList { get; set; }


        public ICollection<CellData> CellsValuesData { get; set; }
    }
}
