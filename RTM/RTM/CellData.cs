namespace RTM
{
    public class CellData
    {
        public CellData(int cellId, GridData grid)
        {
            CellId = cellId;
            Grid = grid;
        }

        public int CellId { get; set; }


        public string Value { get; set; }


        public string Value2 { get; set; }


        public GridData Grid { get; set; }

    }
}
