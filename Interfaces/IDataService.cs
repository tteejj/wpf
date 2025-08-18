using System.Collections.ObjectModel;

namespace PraxisWpf.Interfaces
{
    public interface IDataService
    {
        ObservableCollection<IDisplayableItem> LoadItems();
        void SaveItems(ObservableCollection<IDisplayableItem> items);
    }
}