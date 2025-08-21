using System;
using System.Windows;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Features.TimeTracker;
using PraxisWpf.Features.DataProcessing;
using PraxisWpf.Features.ThemeSelector;
using PraxisWpf.Services;

namespace PraxisWpf
{
    public enum AppView { Tasks, Time, DataProcessing, Themes }

    public partial class MainWindow : Window
    {
        private TaskViewModel? _taskViewModel;
        private TimeViewModel? _timeViewModel;
        private DataProcessingViewModel? _dataProcessingViewModel;
        private ThemeViewModel? _themeViewModel;
        private MainViewModel? _mainViewModel;
        private DataSafetyService? _dataSafetyService;

        public MainWindow()
        {
            try
            {
                InitializeComponent();

                _dataSafetyService = new DataSafetyService();

                _taskViewModel = new TaskViewModel();
                _timeViewModel = new TimeViewModel();
                _dataProcessingViewModel = new DataProcessingViewModel();
                _themeViewModel = new ThemeViewModel();
                
                // Register ViewModels with action-based auto-save
                var autoSaveService = _dataSafetyService.GetActionBasedAutoSaveService();
                _dataSafetyService.RegisterForActionBasedAutoSave("Tasks", _taskViewModel);
                _dataSafetyService.RegisterForActionBasedAutoSave("TimeTracker", _timeViewModel);
                
                // Configure ViewModels with auto-save service
                _taskViewModel.SetAutoSaveService(autoSaveService);
                _timeViewModel.SetAutoSaveService(autoSaveService);
                
                _dataSafetyService.Start();
                
                // Create a main view model to hold all ViewModels
                _mainViewModel = new MainViewModel 
                { 
                    TaskViewModel = _taskViewModel,
                    TimeViewModel = _timeViewModel,
                    DataProcessingViewModel = _dataProcessingViewModel,
                    ThemeViewModel = _themeViewModel
                };
                DataContext = _mainViewModel;
            }
            catch (Exception ex)
            {
                Logger.Critical("MainWindow", "Failed to initialize MainWindow", ex);
                throw;
            }
        }

        public void ShowView(AppView view)
        {
            // Hide all views
            TaskViewControl.Visibility = Visibility.Collapsed;
            TimeViewControl.Visibility = Visibility.Collapsed;
            DataProcessingViewControl.Visibility = Visibility.Collapsed;
            ThemeViewControl.Visibility = Visibility.Collapsed;
            
            // Hide all status bars
            TaskStatusBar.Visibility = Visibility.Collapsed;
            TimeStatusBar.Visibility = Visibility.Collapsed;
            DataStatusBar.Visibility = Visibility.Collapsed;
            ThemeStatusBar.Visibility = Visibility.Collapsed;
            
            // Show selected view and status bar
            switch (view)
            {
                case AppView.Tasks:
                    TaskViewControl.Visibility = Visibility.Visible;
                    TaskStatusBar.Visibility = Visibility.Visible;
                    TaskViewControl.Focus();
                    break;
                case AppView.Time:
                    TimeViewControl.Visibility = Visibility.Visible;
                    TimeStatusBar.Visibility = Visibility.Visible;
                    TimeViewControl.Focus();
                    break;
                case AppView.DataProcessing:
                    DataProcessingViewControl.Visibility = Visibility.Visible;
                    DataStatusBar.Visibility = Visibility.Visible;
                    DataProcessingViewControl.Focus();
                    break;
                case AppView.Themes:
                    ThemeViewControl.Visibility = Visibility.Visible;
                    ThemeStatusBar.Visibility = Visibility.Visible;
                    ThemeViewControl.Focus();
                    break;
            }
        }

        public void ShowTimeEntry() => ShowView(AppView.Time);
        public void ShowTasks() => ShowView(AppView.Tasks);
        public void ShowDataProcessing() => ShowView(AppView.DataProcessing);
        public void ShowThemes() => ShowView(AppView.Themes);


        protected override void OnClosed(EventArgs e)
        {
            try
            {
                _dataSafetyService?.Dispose();
                base.OnClosed(e);
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindow", "Error during window close", ex);
            }
        }
    }
}