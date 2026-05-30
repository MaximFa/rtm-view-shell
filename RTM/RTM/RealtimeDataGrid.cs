namespace RTM
{
    public class RealtimeDataGrid
    {
        /// main constructor
        public RealtimeDataGrid(int gridID, string title, int businessUnitID, int cssStyleID, int thresholdID, string thresholdScript, bool isToggle, bool toggleDefault)
        {
            GridID = gridID;
            Title = title;
            BusinessUnitID = businessUnitID;
            CssStyleID = cssStyleID;
            ThresholdID = thresholdID;
            ThresholdScript = thresholdScript;
            IsToggle = isToggle;
            ToggleDefault = toggleDefault;
        }

        /// getters and setters
        public int GridID { get; private set; }
        public string Title { get; private set; }
        public int BusinessUnitID { get; private set; }
        public int CssStyleID { get; private set; }
        public int ThresholdID { get; private set; }
        public string ThresholdScript { get; private set; }
        public bool IsToggle { get; private set; }
        public bool ToggleDefault { get; private set; }
    }
}
