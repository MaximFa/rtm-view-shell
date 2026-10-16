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



        // [SYNC-PORT 2026-10-16 src=2026-07-20] U2 backdated terminal (legacy, unmarked): remove one interaction by key (rebuild-filter, like ClearInactive).
        public void RemoveKey(string key)
        {
            Bag = new ConcurrentBag<IDInteraction>(Bag.Where(item => item.Key != key));
            IsEmpty = Bag.IsEmpty;
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
