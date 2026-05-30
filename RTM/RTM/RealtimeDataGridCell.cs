namespace RTM
{
    public class RealtimeDataGridCell
    {
        /// main constructor
        public RealtimeDataGridCell(int cellID, string cellType, string value, string tooltip, string onClick, int cssStyleID, int gridStyleId, int rowStyleId, int rowNumber)
        {
            CellID = cellID;
            CellType = cellType;
            Value = value;
            Tooltip = tooltip;
            OnClick = onClick;
            CssStyleID = cssStyleID;
            GridStyleId = gridStyleId;
            RowStyleId = rowStyleId;
            RowNumber = rowNumber;
        }

        /// getters and setters
        public int CellID { get; private set; }
        public int ColumnID { get; private set; }
        public int RowID { get; private set; }
        public int RowNumber { get; private set; }
        public int BusinessUnitID { get; private set; }
        public int CssStyleID { get; private set; }
        public int GridStyleId { get; private set; }
        public int RowStyleId { get; private set; }
        public string CellType { get; private set; }
        public string Value { get; private set; }
        public string Tooltip { get; private set; }
        public string OnClick { get; private set; }
    }
}
