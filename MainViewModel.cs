using System.ComponentModel;
using System.Runtime.CompilerServices;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Features.TimeTracker;
using PraxisWpf.Features.DataProcessing;
using PraxisWpf.Features.ThemeSelector;

namespace PraxisWpf
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private TaskViewModel? _taskViewModel;
        private TimeViewModel? _timeViewModel;
        private DataProcessingViewModel? _dataProcessingViewModel;
        private ThemeViewModel? _themeViewModel;

        public TaskViewModel? TaskViewModel
        {
            get => _taskViewModel;
            set => SetProperty(ref _taskViewModel, value);
        }

        public TimeViewModel? TimeViewModel
        {
            get => _timeViewModel;
            set => SetProperty(ref _timeViewModel, value);
        }

        public DataProcessingViewModel? DataProcessingViewModel
        {
            get => _dataProcessingViewModel;
            set => SetProperty(ref _dataProcessingViewModel, value);
        }

        public ThemeViewModel? ThemeViewModel
        {
            get => _themeViewModel;
            set => SetProperty(ref _themeViewModel, value);
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        protected bool SetProperty<T>(ref T backingStore, T value, [CallerMemberName] string? propertyName = null)
        {
            if (object.Equals(backingStore, value))
                return false;

            backingStore = value;
            OnPropertyChanged(propertyName);
            return true;
        }
    }
}