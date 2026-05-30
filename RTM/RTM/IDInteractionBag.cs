using RTM.Configuration;
using System.Collections.Concurrent;


namespace RTM
{
    public class IDInteractionBag
    {
        public ConcurrentBag<IDInteraction> Bag {get; private set;}


        public bool IsEmpty { get; set; }


        public string TimeZone { get; set; }


        public IDInteractionBag()
        {
            Clear();        
            TimeZone = AppConfig.DefaultTimeZone;
        }



        public void Add(IDInteraction interaction)
        {
            interaction.TimeZone = TimeZone;
            Bag.Add(interaction);
            IsEmpty = false;
        }



        public void Clear()
        {
            Bag = new ConcurrentBag<IDInteraction>();
            IsEmpty = true;    
        }



        public List<IDInteraction> ClearInactive()
        {
            var oldBag = Bag.ToList();
            var filteredBag = new ConcurrentBag<IDInteraction>(Bag.Where(item => item.IsInQueue || item.IsTalk));
            Bag = filteredBag;
            IsEmpty = Bag.IsEmpty;

            // Get the interactions that were removed
            var removedItems = oldBag.Except(filteredBag).ToList();
            return removedItems;
        }

    }
}
