using System;
using System.ComponentModel;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace PraxisWpf.Services
{
    /// <summary>
    /// Service for managing loading indicators and user feedback across the application
    /// </summary>
    public class LoadingIndicatorService : INotifyPropertyChanged
    {
        private static LoadingIndicatorService? _instance;
        private bool _isLoading;
        private string _loadingMessage = "Loading...";
        private string _statusMessage = "Ready";
        private int _progressValue;
        private int _progressMaximum = 100;
        private bool _showProgress;

        private LoadingIndicatorService()
        {
            // Ensure all properties are properly initialized
            _progressValue = 0;
            _progressMaximum = 100;
            _isLoading = false;
            _showProgress = false;
        }

        public static LoadingIndicatorService Instance 
        { 
            get 
            { 
                if (_instance == null)
                {
                    _instance = new LoadingIndicatorService();
                    Logger.Info("LoadingIndicatorService", "Singleton instance created");
                }
                return _instance;
            } 
        }

        public bool IsLoading
        {
            get => _isLoading;
            private set
            {
                if (_isLoading != value)
                {
                    _isLoading = value;
                    OnPropertyChanged(nameof(IsLoading));
                    Logger.Debug("LoadingIndicatorService", $"Loading state changed: {value}");
                }
            }
        }

        public string LoadingMessage
        {
            get => _loadingMessage;
            private set
            {
                if (_loadingMessage != value)
                {
                    _loadingMessage = value;
                    OnPropertyChanged(nameof(LoadingMessage));
                    Logger.Debug("LoadingIndicatorService", $"Loading message: {value}");
                }
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            private set
            {
                if (_statusMessage != value)
                {
                    _statusMessage = value;
                    OnPropertyChanged(nameof(StatusMessage));
                    Logger.Info("LoadingIndicatorService", $"Status: {value}");
                }
            }
        }

        public int ProgressValue
        {
            get => _progressValue;
            private set
            {
                if (_progressValue != value)
                {
                    _progressValue = value;
                    OnPropertyChanged(nameof(ProgressValue));
                    OnPropertyChanged(nameof(ProgressPercentage));
                }
            }
        }

        public int ProgressMaximum
        {
            get => _progressMaximum;
            private set
            {
                if (_progressMaximum != value)
                {
                    _progressMaximum = value;
                    OnPropertyChanged(nameof(ProgressMaximum));
                    OnPropertyChanged(nameof(ProgressPercentage));
                }
            }
        }

        public bool ShowProgress
        {
            get => _showProgress;
            private set
            {
                if (_showProgress != value)
                {
                    _showProgress = value;
                    OnPropertyChanged(nameof(ShowProgress));
                }
            }
        }

        public string ProgressPercentage => ProgressMaximum > 0 
            ? $"{(ProgressValue * 100 / ProgressMaximum):F0}%" 
            : "0%";

        /// <summary>
        /// Show loading indicator with message
        /// </summary>
        public void ShowLoading(string message = "Loading...")
        {
            DispatchToUI(() =>
            {
                LoadingMessage = message;
                IsLoading = true;
                ShowProgress = false;
            });
        }

        /// <summary>
        /// Show loading indicator with progress
        /// </summary>
        public void ShowLoadingWithProgress(string message = "Loading...", int maximum = 100)
        {
            DispatchToUI(() =>
            {
                LoadingMessage = message;
                ProgressMaximum = maximum;
                ProgressValue = 0;
                ShowProgress = true;
                IsLoading = true;
            });
        }

        /// <summary>
        /// Update progress value
        /// </summary>
        public void UpdateProgress(int value, string? message = null)
        {
            DispatchToUI(() =>
            {
                ProgressValue = Math.Min(value, ProgressMaximum);
                if (!string.IsNullOrEmpty(message))
                {
                    LoadingMessage = message;
                }
            });
        }

        /// <summary>
        /// Hide loading indicator
        /// </summary>
        public void HideLoading()
        {
            DispatchToUI(() =>
            {
                IsLoading = false;
                ShowProgress = false;
                ProgressValue = 0;
            });
        }

        /// <summary>
        /// Set status message (persists after loading)
        /// </summary>
        public void SetStatus(string message)
        {
            DispatchToUI(() =>
            {
                StatusMessage = message;
            });
        }

        /// <summary>
        /// Show temporary status message that clears after delay
        /// </summary>
        public async Task ShowTemporaryStatus(string message, int durationMs = 3000)
        {
            SetStatus(message);
            await Task.Delay(durationMs);
            if (StatusMessage == message) // Only clear if it hasn't been changed
            {
                SetStatus("Ready");
            }
        }

        /// <summary>
        /// Execute async operation with loading indicator
        /// </summary>
        public async Task<T> ExecuteWithLoading<T>(Func<Task<T>> operation, string message = "Processing...")
        {
            try
            {
                ShowLoading(message);
                var result = await operation();
                HideLoading();
                return result;
            }
            catch (Exception ex)
            {
                HideLoading();
                SetStatus($"Error: {GetUserFriendlyErrorMessage(ex)}");
                throw;
            }
        }

        /// <summary>
        /// Execute async operation with loading indicator (no return value)
        /// </summary>
        public async Task ExecuteWithLoading(Func<Task> operation, string message = "Processing...")
        {
            try
            {
                ShowLoading(message);
                await operation();
                HideLoading();
            }
            catch (Exception ex)
            {
                HideLoading();
                SetStatus($"Error: {GetUserFriendlyErrorMessage(ex)}");
                throw;
            }
        }

        private string GetUserFriendlyErrorMessage(Exception ex)
        {
            return ex switch
            {
                UnauthorizedAccessException => "Access denied. Please check file permissions.",
                System.IO.FileNotFoundException => "Required file not found. Please check the file path.",
                System.IO.DirectoryNotFoundException => "Directory not found. Please check the path.",
                InvalidOperationException => "Operation not allowed at this time. Please try again.",
                TimeoutException => "Operation timed out. Please try again.",
                _ => "An unexpected error occurred. Please try again."
            };
        }

        private void DispatchToUI(Action action)
        {
            if (System.Windows.Application.Current?.Dispatcher != null)
            {
                if (System.Windows.Application.Current.Dispatcher.CheckAccess())
                {
                    action();
                }
                else
                {
                    System.Windows.Application.Current.Dispatcher.BeginInvoke(action, DispatcherPriority.Normal);
                }
            }
            else
            {
                action(); // Fallback for unit tests or non-UI contexts
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}