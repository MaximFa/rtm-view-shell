namespace RTM
{
    public class GridData
    {
        private List<CellData> _cells = new List<CellData>();
        private List<string> _connections = new List<string>();


        public GridData(int gridId)
        {
            GridId = gridId;
        }


        public int GridId { get; set; }


        public List<CellData> Cells
        {
            get
            {
                return _cells;
            }
            set
            {
                _cells = value;
            }
        }



        public void addConnection(string ConnectionId)
        {
            _connections.Add(ConnectionId);
        }


        public void removeConnection(string ConnectionId)
        {
            _connections.Remove(ConnectionId);
        }

    }
}
