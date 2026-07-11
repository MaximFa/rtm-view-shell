using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM.Types
{
    public class Reservation
    {
        public Reservation(string id, int segmentId)
        {
            Id = id;
            SegmentId = segmentId;
        }

        public string Id { get; set; }


        public int SegmentId { get; set; } = 1;


        public bool IsActive { get; set; } = true;
    }
}
