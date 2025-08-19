using System;
using System.Windows;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Features.TimeTracker;
using PraxisWpf.Services;

namespace PraxisWpf
{
    public partial class MainWindow : Window
    {
        private TaskViewModel? _taskViewModel;
        private TimeViewModel? _timeViewModel;
        private MainViewModel? _mainViewModel;

        public MainWindow()
        {
            Logger.TraceEnter();
            try
            {
                using var perfTracker = Logger.TracePerformance("MainWindow Constructor");

                Logger.Debug("MainWindow", "Initializing WPF components");
                InitializeComponent();

                Logger.Debug("MainWindow", "Creating ViewModels");
                _taskViewModel = new TaskViewModel();
                _timeViewModel = new TimeViewModel();
                
                // Create a main view model to hold both
                _mainViewModel = new MainViewModel 
                { 
                    TaskViewModel = _taskViewModel,
                    TimeViewModel = _timeViewModel 
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
            TimeViewControl.Visibility = Visibility.Visible;
            TaskStatusBar.Visibility = Visibility.Collapsed;
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
            TaskViewControl.Visibility = Visibility.Visible;
            TimeStatusBar.Visibility = Visibility.Collapsed;
            TaskStatusBar.Visibility = Visibility.Visible;
            
            // Focus the task view
            TaskViewControl.Focus();
            
            Logger.Info("MainWindow", "Switched to task view");
            Logger.TraceExit();
        }

        private void TasksButton_Click(object sender, RoutedEventArgs e)
        {
            ShowTasks();
        }

        private void TimeButton_Click(object sender, RoutedEventArgs e)
        {
            ShowTimeEntry();
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
                Logger.Info("MainWindow", "Window closing");
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