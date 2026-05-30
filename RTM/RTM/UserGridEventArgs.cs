using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RTM
{
    public class UserGridEventArgs : EventArgs
    {
        public UserGridEventArgs(int unionId)
        {
            UnionId = unionId;
        }


        public int UnionId { get; set; }

    }
}
