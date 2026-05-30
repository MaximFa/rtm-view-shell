using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class Metric
    {
        private CellList _cells = new CellList();

        private string _value = string.Empty;

        private string _value2 = string.Empty;


        public Metric(Union union)
        {
            Union = union;
        }


        public string MetricCode { get; set; }


        public Union Union { get; set; }


        public void setValue(string value)
        {
            setValue(value, value);
        }


        public void setValue(string checkIfChanged, string value)
        {
            if (_value != checkIfChanged)
            {               
                foreach (Cell cell in Cells.Values)
                {                
                    cell.Value = value;
                }

                _value = checkIfChanged;
                _value2 = value;
            }
        }


        public void setCellValue(Cell cell)
        {
            cell.Value = _value2;
        }



        public CellList Cells
        {
            get { return _cells; }
            set { _cells = value; }
        }
    }
}
