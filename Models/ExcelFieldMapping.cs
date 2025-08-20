using System.ComponentModel;

namespace PraxisWpf.Models
{
    public class ExcelFieldMapping : INotifyPropertyChanged
    {
        private string _fieldName = string.Empty;
        private string _sourceCell = string.Empty;
        private string _destinationCell = string.Empty;
        private bool _useInT2020;
        private string _currentValue = string.Empty;

        public string FieldName
        {
            get => _fieldName;
            set
            {
                _fieldName = value;
                OnPropertyChanged(nameof(FieldName));
            }
        }

        public string SourceCell
        {
            get => _sourceCell;
            set
            {
                _sourceCell = value;
                OnPropertyChanged(nameof(SourceCell));
            }
        }

        public string DestinationCell
        {
            get => _destinationCell;
            set
            {
                _destinationCell = value;
                OnPropertyChanged(nameof(DestinationCell));
            }
        }

        public bool UseInT2020
        {
            get => _useInT2020;
            set
            {
                _useInT2020 = value;
                OnPropertyChanged(nameof(UseInT2020));
            }
        }

        public string CurrentValue
        {
            get => _currentValue;
            set
            {
                _currentValue = value;
                OnPropertyChanged(nameof(CurrentValue));
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}