using System.Collections.Concurrent;

namespace RTM
{
    public class AllCellsData
    {
        private ConcurrentDictionary<int, CellData> _cells = new ConcurrentDictionary<int, CellData>();

        public void Add(ConcurrentDictionary<int, CellData> changedCells)
        {
            try
            {
                foreach (var cell in changedCells)
                {
                    cell.Value.Value = cell.Value.Value2;

                    if (_cells.ContainsKey(cell.Key))
                    {
                        _cells[cell.Key] = cell.Value;
                    }
                    else
                    {
                        _cells.TryAdd(cell.Key, cell.Value);
                        //Log.Info("AllCellsData.Add changedCell key=" + cell.Key + " value=" + cell.Value.Value + " grid=" + cell.Value.Grid.GridId);
                    }
                }
            }
            catch (Exception ex)
            {
                //Log.Error("AllCellsData.Add", ex);
            }
        }



        public IEnumerable<KeyValuePair<int, CellData>> Get(int gridId)
        {
            return _cells.Where(x => x.Value.Grid.GridId == gridId);
        }


        public void removeCell(int cellId)
        {
            CellData cell;
            _cells.TryRemove(cellId, out cell);
        }



        public void addCell(int cellId, int gridId)
        {
            CellData cell = new CellData(cellId, new GridData(gridId));
        }
    }
}

