using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class Cell
    {
        private string _value = string.Empty;

        private bool _isChanged = true;



        public Cell(int cellId, Grid grid, int unionId, string metric)
        {
            CellId = cellId;
            Grid = grid;
            UnionId = unionId;
            Metric = metric;
            Grid.Cells.TryAdd(cellId, this);
        }


        public int CellId { set; get; }


        public string CellType { set; get; }


        public Grid Grid { set; get; }


        public string Metric { set; get; }



        public int UnionId { set; get; }


        public bool IsChanged
        {
            get
            {
                return _isChanged;
            }
            set
            {
                _isChanged = value;
            }
        }


        public string Value
        {
            get { return _value; }
            set
            {
                _value = value;
                _isChanged = true;
            }
        }
    }
}
