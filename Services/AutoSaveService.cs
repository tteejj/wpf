using System;
using System.Collections.Generic;
using System.Threading;
using System.Windows.Threading;
using PraxisWpf.Interfaces;

namespace PraxisWpf.Services
{
    /// <summary>
    /// Provides automatic data saving with configurable intervals and safety mechanisms
    /// </summary>
    public class AutoSaveService : IDisposable
    {
        private readonly DispatcherTimer _autoSaveTimer;
        private readonly List<IAutoSaveable> _saveableServices;
        private readonly object _lock = new object();
        private bool _disposed = false;
        private bool _saveInProgress = false;
        private DateTime _lastSaveTime = DateTime.MinValue;
        private int _saveIntervalMinutes = 2; // Default 2 minutes

        public AutoSaveService()
        {
            Logger.TraceEnter();

            _saveableServices = new List<IAutoSaveable>();
            
            // Use DispatcherTimer to ensure saves happen on UI thread
            _autoSaveTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromMinutes(_saveIntervalMinutes)
            };
            _autoSaveTimer.Tick += AutoSaveTimer_Tick;

            Logger.Info("AutoSaveService", $"Initialized with {_saveIntervalMinutes} minute interval");
            Logger.TraceExit();
        }

        /// <summary>
        /// Registers a service for auto-saving
        /// </summary>
        public void RegisterSaveableService(IAutoSaveable service)
        {
            Logger.TraceEnter($"service={service.GetType().Name}");

            lock (_lock)
            {
                if (!_saveableServices.Contains(service))
                {
                    _saveableServices.Add(service);
                    Logger.Info("AutoSaveService", $"Registered {service.GetType().Name} for auto-save");
                }
                else
                {
                    Logger.Warning("AutoSaveService", $"Service {service.GetType().Name} already registered");
                }
            }

            Logger.TraceExit();
        }

        /// <summary>
        /// Unregisters a service from auto-saving
        /// </summary>
        public void UnregisterSaveableService(IAutoSaveable service)
        {
            Logger.TraceEnter($"service={service.GetType().Name}");

            lock (_lock)
            {
                if (_saveableServices.Remove(service))
                {
                    Logger.Info("AutoSaveService", $"Unregistered {service.GetType().Name} from auto-save");
                }
                else
                {
                    Logger.Warning("AutoSaveService", $"Service {service.GetType().Name} was not registered");
                }
            }

            Logger.TraceExit();
        }

        /// <summary>
        /// Starts the auto-save timer
        /// </summary>
        public void Start()
        {
            Logger.TraceEnter();

            if (!_autoSaveTimer.IsEnabled)
            {
                _autoSaveTimer.Start();
                Logger.Info("AutoSaveService", "Auto-save timer started");
            }
            else
            {
                Logger.Debug("AutoSaveService", "Auto-save timer already running");
            }

            Logger.TraceExit();
        }

        /// <summary>
        /// Stops the auto-save timer
        /// </summary>
        public void Stop()
        {
            Logger.TraceEnter();

            if (_autoSaveTimer.IsEnabled)
            {
                _autoSaveTimer.Stop();
                Logger.Info("AutoSaveService", "Auto-save timer stopped");
            }
            else
            {
                Logger.Debug("AutoSaveService", "Auto-save timer already stopped");
            }

            Logger.TraceExit();
        }

        /// <summary>
        /// Sets the auto-save interval
        /// </summary>
        public void SetInterval(int minutes)
        {
            Logger.TraceEnter($"minutes={minutes}");

            if (minutes < 1)
            {
                Logger.Warning("AutoSaveService", "Invalid interval - minimum 1 minute");
                return;
            }

            _saveIntervalMinutes = minutes;
            _autoSaveTimer.Interval = TimeSpan.FromMinutes(minutes);
            
            Logger.Info("AutoSaveService", $"Auto-save interval set to {minutes} minutes");
            Logger.TraceExit();
        }

        /// <summary>
        /// Forces an immediate save of all registered services
        /// </summary>
        public void SaveNow()
        {
            Logger.TraceEnter();

            if (_saveInProgress)
            {
                Logger.Warning("AutoSaveService", "Save already in progress - skipping");
                return;
            }

            PerformAutoSave(isManualSave: true);
            Logger.TraceExit();
        }

        /// <summary>
        /// Gets auto-save status information
        /// </summary>
        public AutoSaveStatus GetStatus()
        {
            lock (_lock)
            {
                return new AutoSaveStatus
                {
                    IsEnabled = _autoSaveTimer.IsEnabled,
                    IntervalMinutes = _saveIntervalMinutes,
                    RegisteredServices = _saveableServices.Count,
                    LastSaveTime = _lastSaveTime,
                    SaveInProgress = _saveInProgress
                };
            }
        }

        private void AutoSaveTimer_Tick(object sender, EventArgs e)
        {
            Logger.TraceEnter();

            if (_saveInProgress)
            {
                Logger.Debug("AutoSaveService", "Save already in progress - skipping auto-save tick");
                return;
            }

            PerformAutoSave(isManualSave: false);
            Logger.TraceExit();
        }

        private void PerformAutoSave(bool isManualSave)
        {
            Logger.TraceEnter($"isManualSave={isManualSave}");
            using var perfTracker = Logger.TracePerformance("PerformAutoSave");

            lock (_lock)
            {
                if (_saveInProgress)
                {
                    Logger.Warning("AutoSaveService", "Save already in progress");
                    return;
                }

                _saveInProgress = true;
            }

            try
            {
                var saveType = isManualSave ? "Manual" : "Auto";
                Logger.Info("AutoSaveService", $"{saveType} save started - {_saveableServices.Count} services");

                var successCount = 0;
                var errorCount = 0;

                foreach (var service in _saveableServices.ToArray()) // ToArray to avoid collection modified exceptions
                {
                    try
                    {
                        Logger.Debug("AutoSaveService", $"Saving {service.GetType().Name}");
                        
                        if (service.HasUnsavedChanges())
                        {
                            service.AutoSave();
                            successCount++;
                            Logger.Debug("AutoSaveService", $"Successfully saved {service.GetType().Name}");
                        }
                        else
                        {
                            Logger.Debug("AutoSaveService", $"No changes to save for {service.GetType().Name}");
                        }
                    }
                    catch (Exception ex)
                    {
                        errorCount++;
                        Logger.Error("AutoSaveService", $"Failed to save {service.GetType().Name}", ex);
                    }
                }

                _lastSaveTime = DateTime.Now;
                
                if (errorCount > 0)
                {
                    Logger.Warning("AutoSaveService", 
                        $"{saveType} save completed with errors - Success: {successCount}, Errors: {errorCount}");
                }
                else if (successCount > 0)
                {
                    Logger.Info("AutoSaveService", 
                        $"{saveType} save completed successfully - Saved: {successCount} services");
                }
                else
                {
                    Logger.Debug("AutoSaveService", $"{saveType} save completed - No changes detected");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("AutoSaveService", "Auto-save operation failed", ex);
            }
            finally
            {
                lock (_lock)
                {
                    _saveInProgress = false;
                }
                Logger.TraceExit();
            }
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                Logger.TraceEnter();

                // Stop timer and perform final save
                Stop();
                SaveNow();

                // Dispose timer
                _autoSaveTimer?.Stop();
                
                // Clear services
                lock (_lock)
                {
                    _saveableServices.Clear();
                }

                _disposed = true;
                Logger.Info("AutoSaveService", "AutoSaveService disposed");
                Logger.TraceExit();
            }
        }
    }

    /// <summary>
    /// Status information for the auto-save service
    /// </summary>
    public class AutoSaveStatus
    {
        public bool IsEnabled { get; set; }
        public int IntervalMinutes { get; set; }
        public int RegisteredServices { get; set; }
        public DateTime LastSaveTime { get; set; }
        public bool SaveInProgress { get; set; }

        public string StatusText => 
            $"Auto-save: {(IsEnabled ? "ON" : "OFF")} | " +
            $"Interval: {IntervalMinutes}min | " +
            $"Services: {RegisteredServices} | " +
            $"Last Save: {(LastSaveTime == DateTime.MinValue ? "Never" : LastSaveTime.ToString("HH:mm:ss"))}";
    }
}