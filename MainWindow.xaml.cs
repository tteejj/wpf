using System;
using System.Windows;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Services;

namespace PraxisWpf
{
    public partial class MainWindow : Window
    {
        private TaskViewModel? _viewModel;

        public MainWindow()
        {
            Logger.TraceEnter();
            try
            {
                using var perfTracker = Logger.TracePerformance("MainWindow Constructor");

                Logger.Debug("MainWindow", "Initializing WPF components");
                InitializeComponent();

                Logger.Debug("MainWindow", "Creating TaskViewModel");
                _viewModel = new TaskViewModel();
                DataContext = _viewModel;

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