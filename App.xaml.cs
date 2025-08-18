using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;
using PraxisWpf.Services;

namespace PraxisWpf
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            try
            {
                // Initialize configuration system first
                AppConfig.LoadConfiguration();
                
                Logger.Info("App", "Application starting up");
                Logger.Debug("App", $"Command line args: {string.Join(" ", e.Args)}");

                // Subscribe to global exception handlers
                AppDomain.CurrentDomain.UnhandledException += (s, args) =>
                {
                    Logger.Critical("App", "Unhandled exception in app domain", args.ExceptionObject as Exception);
                };

                this.DispatcherUnhandledException += (s, args) =>
                {
                    Logger.Critical("App", "Unhandled UI thread exception", args.Exception);
                    args.Handled = true; // Prevent crash
                    MessageBox.Show($"UI Error: {args.Exception.Message}\n\nSee log for details.", "Application Error");
                };

                // Check for debug mode command line argument
                foreach (var arg in e.Args)
                {
                    if (arg.Equals("--debug", StringComparison.OrdinalIgnoreCase) || 
                        arg.Equals("-d", StringComparison.OrdinalIgnoreCase))
                    {
                        AppConfig.EnableDebugMode(true);
                        Logger.Info("App", "Debug mode enabled via command line");
                        break;
                    }
                }

                base.OnStartup(e);
                Logger.Info("App", "Application startup completed successfully");
            }
            catch (Exception ex)
            {
                Logger.Critical("App", "Fatal error during application startup", ex);
                MessageBox.Show($"Fatal error during startup: {ex.Message}\n\nStack trace:\n{ex.StackTrace}", "Application Error", 
                    MessageBoxButton.OK, MessageBoxImage.Error);
                Environment.Exit(1);
            }
        }

        protected override void OnExit(ExitEventArgs e)
        {
            try
            {
                Logger.Info("App", $"Application shutting down with exit code: {e.ApplicationExitCode}");
                Logger.Dispose();
                base.OnExit(e);
            }
            catch (Exception ex)
            {
                // Last ditch logging attempt
                try
                {
                    Logger.Critical("App", "Error during application shutdown", ex);
                }
                catch
                {
                    // If even logging fails, just exit
                }
            }
        }
    }

    // Inverse boolean to visibility converter
    public class InverseBooleanToVisibilityConverter : IValueConverter
    {
        public object Convert(object value, System.Type targetType, object parameter, CultureInfo culture)
        {
            if (value is bool boolValue)
            {
                return boolValue ? Visibility.Collapsed : Visibility.Visible;
            }
            return Visibility.Visible;
        }

        public object ConvertBack(object value, System.Type targetType, object parameter, CultureInfo culture)
        {
            if (value is Visibility visibility)
            {
                return visibility != Visibility.Visible;
            }
            return false;
        }
    }
}