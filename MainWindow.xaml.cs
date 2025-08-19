using System;
using System.Windows;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Features.TimeTracker;
using PraxisWpf.Features.DataProcessing;
using PraxisWpf.Features.ThemeSelector;
using PraxisWpf.Services;

namespace PraxisWpf
{
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
            Logger.TraceEnter();
            try
            {
                using var perfTracker = Logger.TracePerformance("MainWindow Constructor");

                Logger.Debug("MainWindow", "Initializing WPF components");
                InitializeComponent();

                Logger.Debug("MainWindow", "Initializing data safety service");
                _dataSafetyService = new DataSafetyService();

                Logger.Debug("MainWindow", "Creating ViewModels");
                _taskViewModel = new TaskViewModel();
                _timeViewModel = new TimeViewModel();
                _dataProcessingViewModel = new DataProcessingViewModel();
                _themeViewModel = new ThemeViewModel();
                
                // Register ViewModels with action-based auto-save
                Logger.Debug("MainWindow", "Configuring action-based auto-save");
                var autoSaveService = _dataSafetyService.GetActionBasedAutoSaveService();
                _dataSafetyService.RegisterForActionBasedAutoSave("Tasks", _taskViewModel);
                _dataSafetyService.RegisterForActionBasedAutoSave("TimeTracker", _timeViewModel);
                
                // Configure ViewModels with auto-save service
                _taskViewModel.SetAutoSaveService(autoSaveService);
                _timeViewModel.SetAutoSaveService(autoSaveService);
                
                Logger.Debug("MainWindow", "Starting data safety services");
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

                Logger.Info("MainWindow", "MainWindow initialized successfully");
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Critical("MainWindow", "Failed to initialize MainWindow", ex);
                Logger.TraceExit();
                throw;
            }
        }

        public void ShowTimeEntry()
        {
            Logger.TraceEnter();
            
            TaskViewControl.Visibility = Visibility.Collapsed;
            DataProcessingViewControl.Visibility = Visibility.Collapsed;
            ThemeViewControl.Visibility = Visibility.Collapsed;
            TimeViewControl.Visibility = Visibility.Visible;
            TaskStatusBar.Visibility = Visibility.Collapsed;
            DataStatusBar.Visibility = Visibility.Collapsed;
            ThemeStatusBar.Visibility = Visibility.Collapsed;
            TimeStatusBar.Visibility = Visibility.Visible;
            
            // Focus the time view
            TimeViewControl.Focus();
            
            Logger.Info("MainWindow", "Switched to time entry view");
            Logger.TraceExit();
        }

        public void ShowTasks()
        {
            Logger.TraceEnter();
            
            TimeViewControl.Visibility = Visibility.Collapsed;
            DataProcessingViewControl.Visibility = Visibility.Collapsed;
            ThemeViewControl.Visibility = Visibility.Collapsed;
            TaskViewControl.Visibility = Visibility.Visible;
            TimeStatusBar.Visibility = Visibility.Collapsed;
            DataStatusBar.Visibility = Visibility.Collapsed;
            ThemeStatusBar.Visibility = Visibility.Collapsed;
            TaskStatusBar.Visibility = Visibility.Visible;
            
            // Focus the task view
            TaskViewControl.Focus();
            
            Logger.Info("MainWindow", "Switched to task view");
            Logger.TraceExit();
        }

        public void ShowDataProcessing()
        {
            Logger.TraceEnter();
            
            TaskViewControl.Visibility = Visibility.Collapsed;
            TimeViewControl.Visibility = Visibility.Collapsed;
            ThemeViewControl.Visibility = Visibility.Collapsed;
            DataProcessingViewControl.Visibility = Visibility.Visible;
            TaskStatusBar.Visibility = Visibility.Collapsed;
            TimeStatusBar.Visibility = Visibility.Collapsed;
            ThemeStatusBar.Visibility = Visibility.Collapsed;
            DataStatusBar.Visibility = Visibility.Visible;
            
            // Focus the data processing view
            DataProcessingViewControl.Focus();
            
            Logger.Info("MainWindow", "Switched to data processing view");
            Logger.TraceExit();
        }

        public void ShowThemes()
        {
            Logger.TraceEnter();
            
            TaskViewControl.Visibility = Visibility.Collapsed;
            TimeViewControl.Visibility = Visibility.Collapsed;
            DataProcessingViewControl.Visibility = Visibility.Collapsed;
            ThemeViewControl.Visibility = Visibility.Visible;
            TaskStatusBar.Visibility = Visibility.Collapsed;
            TimeStatusBar.Visibility = Visibility.Collapsed;
            DataStatusBar.Visibility = Visibility.Collapsed;
            ThemeStatusBar.Visibility = Visibility.Visible;
            
            // Focus the theme view
            ThemeViewControl.Focus();
            
            Logger.Info("MainWindow", "Switched to theme view");
            Logger.TraceExit();
        }


        protected override void OnSourceInitialized(EventArgs e)
        {
            Logger.TraceEnter();
            try
            {
                base.OnSourceInitialized(e);
                Logger.Debug("MainWindow", "Window source initialized");
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindow", "Error during source initialization", ex);
                Logger.TraceExit();
                throw;
            }
        }

        protected override void OnActivated(EventArgs e)
        {
            Logger.Trace("MainWindow", "Window activated");
            base.OnActivated(e);
        }

        protected override void OnDeactivated(EventArgs e)
        {
            Logger.Trace("MainWindow", "Window deactivated");
            base.OnDeactivated(e);
        }

        protected override void OnClosed(EventArgs e)
        {
            Logger.TraceEnter();
            try
            {
                Logger.Info("MainWindow", "Window closing - disposing data safety service");
                
                // Dispose data safety service to ensure clean shutdown
                _dataSafetyService?.Dispose();
                
                base.OnClosed(e);
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("MainWindow", "Error during window close", ex);
                Logger.TraceExit();
            }
        }
    }
}