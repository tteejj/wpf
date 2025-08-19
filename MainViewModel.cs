using System.ComponentModel;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Features.TimeTracker;
using PraxisWpf.Services;

namespace PraxisWpf
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private TaskViewModel? _taskViewModel;
        private TimeViewModel? _timeViewModel;

        public MainViewModel()
        {
            Logger.TraceEnter();
            Logger.TraceExit();
        }

        public TaskViewModel? TaskViewModel
        {
            get 
            { 
                Logger.TraceProperty("TaskViewModel", null, _taskViewModel?.GetType().Name ?? "null");
                return _taskViewModel; 
            }
            set
            {
                var oldValue = _taskViewModel;
                Logger.TraceProperty("TaskViewModel", oldValue?.GetType().Name ?? "null", value?.GetType().Name ?? "null");
                _taskViewModel = value;
                OnPropertyChanged(nameof(TaskViewModel));
                Logger.Debug("MainViewModel", "TaskViewModel changed");
            }
        }

        public TimeViewModel? TimeViewModel
        {
            get 
            { 
                Logger.TraceProperty("TimeViewModel", null, _timeViewModel?.GetType().Name ?? "null");
                return _timeViewModel; 
            }
            set
            {
                var oldValue = _timeViewModel;
                Logger.TraceProperty("TimeViewModel", oldValue?.GetType().Name ?? "null", value?.GetType().Name ?? "null");
                _timeViewModel = value;
                OnPropertyChanged(nameof(TimeViewModel));
                Logger.Debug("MainViewModel", "TimeViewModel changed");
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            Logger.Trace("MainViewModel", $"PropertyChanged: {propertyName}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}