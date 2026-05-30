namespace RTM
{
    public class UserGrid
    {
        ///<sumery>
        /// Grid ID
        ///</sumery>
        public int GridId { get; set; }

        ///<sumery>
        /// Union ID
        ///</sumery>
        public int UnionId { get; set; }

        ///<sumery>
        /// Style ID
        ///</sumery>
        public string Style { get; set; }


        public int StyleId { get; set; }

        ///<sumery>
        /// Title
        ///</sumery>
        public string Title { get; set; }


        ///<sumery>
        /// Rows Filter
        ///</sumery>
        public string RowsFilter { get; set; }


        ///<sumery>
        /// Rows Filter
        ///</sumery>
        public int PageSize { get; set; }


        ///<sumery>
        /// Threshold Script
        ///</sumery>
        public string ThresholdScript { get; set; }



        //public ConcurrentDictionary<string, int> Connections = new ConcurrentDictionary<string, int>();


        //public bool InUse { get; set; }
    }
}
