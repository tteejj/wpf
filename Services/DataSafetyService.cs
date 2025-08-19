using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using PraxisWpf.Interfaces;

namespace PraxisWpf.Services
{
    /// <summary>
    /// Comprehensive data safety service that coordinates auto-save, backups, and crash recovery
    /// </summary>
    public class DataSafetyService : IDisposable
    {
        private readonly ActionBasedAutoSaveService _actionBasedAutoSaveService;
        private readonly BackupManager _backupManager;
        private readonly SafeFileWriter _taskDataWriter;
        private readonly SafeFileWriter _timeDataWriter;
        private readonly string _taskDataPath;
        private readonly string _timeDataPath;
        private readonly string _recoveryFlagPath;
        private bool _disposed = false;

        public DataSafetyService(string taskDataPath = "data.json", string timeDataPath = "time-data.json")
        {
            Logger.TraceEnter($"taskDataPath={taskDataPath}, timeDataPath={timeDataPath}");

            _taskDataPath = taskDataPath;
            _timeDataPath = timeDataPath;
            _recoveryFlagPath = "recovery.flag";

            _taskDataWriter = new SafeFileWriter(_taskDataPath);
            _timeDataWriter = new SafeFileWriter(_timeDataPath);
            _backupManager = new BackupManager(_taskDataPath, maxBackups: 5);
            _actionBasedAutoSaveService = new ActionBasedAutoSaveService(_taskDataPath, _timeDataPath);

            // Set up application shutdown handling
            if (Application.Current != null)
            {
                Application.Current.SessionEnding += OnApplicationShutdown;
                Application.Current.Exit += OnApplicationExit;
            }

            // Check for crash recovery on startup
            CheckForCrashRecovery();

            Logger.Info("DataSafetyService", "Data safety service initialized with comprehensive protection");
            Logger.TraceExit();
        }

        /// <summary>
        /// Starts the data safety services
        /// </summary>
        public void Start()
        {
            Logger.TraceEnter();

            // Create recovery flag to detect crashes
            CreateRecoveryFlag();

            // Note: ActionBasedAutoSaveService doesn't need to be "started" - it triggers on actions

            // Create initial backup
            CreateStartupBackup();

            Logger.Info("DataSafetyService", "Data safety services started");
            Logger.TraceExit();
        }

        /// <summary>
        /// Registers a service for action-based auto-saving
        /// </summary>
        public void RegisterForActionBasedAutoSave(string serviceKey, ISaveableService service)
        {
            Logger.TraceEnter($"serviceKey={serviceKey}, service={service.ServiceName}");
            _actionBasedAutoSaveService.RegisterService(serviceKey, service);
            Logger.TraceExit();
        }

        /// <summary>
        /// Performs an immediate backup of all data files
        /// </summary>
        public async Task<BackupResult> CreateBackupAsync()
        {
            Logger.TraceEnter();

            var result = new BackupResult();
            
            try
            {
                // Backup task data
                if (File.Exists(_taskDataPath))
                {
                    var taskBackupPath = _backupManager.CreateBackup(_taskDataPath);
                    if (!string.IsNullOrEmpty(taskBackupPath))
                    {
                        result.TaskDataBackup = taskBackupPath;
                        result.Success = true;
                        Logger.Info("DataSafetyService", $"Task data backed up to: {taskBackupPath}");
                    }
                }

                // Backup time data
                if (File.Exists(_timeDataPath))
                {
                    var timeBackupPath = _backupManager.CreateBackup(_timeDataPath);
                    if (!string.IsNullOrEmpty(timeBackupPath))
                    {
                        result.TimeDataBackup = timeBackupPath;
                        result.Success = true;
                        Logger.Info("DataSafetyService", $"Time data backed up to: {timeBackupPath}");
                    }
                }

                result.BackupTime = DateTime.Now;
                
                if (result.Success)
                {
                    Logger.Info("DataSafetyService", "Backup completed successfully");
                }
                else
                {
                    Logger.Warning("DataSafetyService", "No files were backed up");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("DataSafetyService", $"Backup operation failed: {ex.Message}");
                result.Success = false;
                result.ErrorMessage = ex.Message;
            }

            Logger.TraceExit(returnValue: result.Success.ToString());
            return result;
        }

        /// <summary>
        /// Attempts to recover from the latest backup
        /// </summary>
        public async Task<RecoveryResult> RecoverFromBackupAsync()
        {
            Logger.TraceEnter();

            var result = new RecoveryResult();

            try
            {
                // Attempt to recover task data
                if (_backupManager.RestoreLatestBackup(_taskDataPath))
                {
                    result.TaskDataRecovered = true;
                    Logger.Info("DataSafetyService", "Task data recovered from backup");
                }

                // Attempt to recover time data
                if (_backupManager.RestoreLatestBackup(_timeDataPath))
                {
                    result.TimeDataRecovered = true;
                    Logger.Info("DataSafetyService", "Time data recovered from backup");
                }

                result.Success = result.TaskDataRecovered || result.TimeDataRecovered;
                result.RecoveryTime = DateTime.Now;

                if (result.Success)
                {
                    Logger.Info("DataSafetyService", "Data recovery completed successfully");
                }
                else
                {
                    Logger.Warning("DataSafetyService", "No data was recovered from backups");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("DataSafetyService", $"Recovery operation failed: {ex.Message}");
                result.Success = false;
                result.ErrorMessage = ex.Message;
            }

            Logger.TraceExit(returnValue: result.Success.ToString());
            return result;
        }

        /// <summary>
        /// Gets comprehensive data safety status
        /// </summary>
        public DataSafetyStatus GetStatus()
        {
            Logger.TraceEnter();

            var status = new DataSafetyStatus
            {
                ActionBasedAutoSaveStatus = _actionBasedAutoSaveService.GetStatus(),
                BackupStats = _backupManager.GetBackupStats(),
                TaskDataHealthy = _taskDataWriter.IsMainFileHealthy(),
                TimeDataHealthy = _timeDataWriter.IsMainFileHealthy(),
                TaskDataBackupInfo = _taskDataWriter.GetBackupInfo(),
                TimeDataBackupInfo = _timeDataWriter.GetBackupInfo()
            };

            Logger.TraceExit();
            return status;
        }

        /// <summary>
        /// Gets the action-based auto-save service for direct use
        /// </summary>
        public ActionBasedAutoSaveService GetActionBasedAutoSaveService()
        {
            return _actionBasedAutoSaveService;
        }

        /// <summary>
        /// Forces immediate save of all registered services
        /// </summary>
        public void SaveNow()
        {
            Logger.TraceEnter();
            _actionBasedAutoSaveService.SaveAll("Manual Save Request");
            Logger.TraceExit();
        }

        private void CreateRecoveryFlag()
        {
            try
            {
                File.WriteAllText(_recoveryFlagPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
                Logger.Debug("DataSafetyService", "Created recovery flag");
            }
            catch (Exception ex)
            {
                Logger.Warning("DataSafetyService", $"Failed to create recovery flag: {ex.Message}");
            }
        }

        private void RemoveRecoveryFlag()
        {
            try
            {
                if (File.Exists(_recoveryFlagPath))
                {
                    File.Delete(_recoveryFlagPath);
                    Logger.Debug("DataSafetyService", "Removed recovery flag");
                }
            }
            catch (Exception ex)
            {
                Logger.Warning("DataSafetyService", $"Failed to remove recovery flag: {ex.Message}");
            }
        }

        private void CheckForCrashRecovery()
        {
            Logger.TraceEnter();

            try
            {
                if (File.Exists(_recoveryFlagPath))
                {
                    Logger.Warning("DataSafetyService", "Recovery flag detected - application may have crashed previously");
                    
                    var flagContent = File.ReadAllText(_recoveryFlagPath);
                    Logger.Info("DataSafetyService", $"Previous session started at: {flagContent}");

                    // In a real implementation, you might want to show a recovery dialog
                    // For now, just log and continue
                    Logger.Info("DataSafetyService", "Crash recovery check completed - continuing normal startup");
                }
                else
                {
                    Logger.Debug("DataSafetyService", "No recovery flag found - clean startup");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("DataSafetyService", $"Error during crash recovery check: {ex.Message}");
            }

            Logger.TraceExit();
        }

        private void CreateStartupBackup()
        {
            Logger.TraceEnter();

            try
            {
                // Create backup on startup to preserve state before any changes
                var backupTask = CreateBackupAsync();
                // Don't await - let it run in background
                _ = backupTask.ContinueWith(t => 
                {
                    if (t.Result.Success)
                    {
                        Logger.Info("DataSafetyService", "Startup backup completed");
                    }
                    else
                    {
                        Logger.Warning("DataSafetyService", "Startup backup failed");
                    }
                });
            }
            catch (Exception ex)
            {
                Logger.Warning("DataSafetyService", $"Failed to create startup backup: {ex.Message}");
            }

            Logger.TraceExit();
        }

        private void OnApplicationShutdown(object sender, SessionEndingCancelEventArgs e)
        {
            Logger.TraceEnter($"reason={e.ReasonSessionEnding}");
            PerformShutdownSave();
            Logger.TraceExit();
        }

        private void OnApplicationExit(object sender, ExitEventArgs e)
        {
            Logger.TraceEnter($"exitCode={e.ApplicationExitCode}");
            PerformShutdownSave();
            Logger.TraceExit();
        }

        private void PerformShutdownSave()
        {
            Logger.TraceEnter();

            try
            {
                Logger.Info("DataSafetyService", "Performing shutdown save");
                
                // Force immediate save of all services
                _actionBasedAutoSaveService.SaveAll("Application Shutdown");

                // Remove recovery flag to indicate clean shutdown
                RemoveRecoveryFlag();

                Logger.Info("DataSafetyService", "Shutdown save completed");
            }
            catch (Exception ex)
            {
                Logger.Error("DataSafetyService", $"Error during shutdown save: {ex.Message}");
            }

            Logger.TraceExit();
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                Logger.TraceEnter();

                // Perform final save and cleanup
                PerformShutdownSave();

                // Dispose action-based auto-save service
                _actionBasedAutoSaveService?.Dispose();

                // Unregister event handlers
                if (Application.Current != null)
                {
                    Application.Current.SessionEnding -= OnApplicationShutdown;
                    Application.Current.Exit -= OnApplicationExit;
                }

                _disposed = true;
                Logger.Info("DataSafetyService", "Data safety service disposed");
                Logger.TraceExit();
            }
        }
    }

    /// <summary>
    /// Result of a backup operation
    /// </summary>
    public class BackupResult
    {
        public bool Success { get; set; }
        public string TaskDataBackup { get; set; } = string.Empty;
        public string TimeDataBackup { get; set; } = string.Empty;
        public DateTime BackupTime { get; set; }
        public string ErrorMessage { get; set; } = string.Empty;
    }

    /// <summary>
    /// Result of a recovery operation
    /// </summary>
    public class RecoveryResult
    {
        public bool Success { get; set; }
        public bool TaskDataRecovered { get; set; }
        public bool TimeDataRecovered { get; set; }
        public DateTime RecoveryTime { get; set; }
        public string ErrorMessage { get; set; } = string.Empty;
    }

    /// <summary>
    /// Comprehensive data safety status
    /// </summary>
    public class DataSafetyStatus
    {
        public ActionBasedAutoSaveStatus ActionBasedAutoSaveStatus { get; set; } = new();
        public BackupStats BackupStats { get; set; } = new();
        public bool TaskDataHealthy { get; set; }
        public bool TimeDataHealthy { get; set; }
        public FileInfo? TaskDataBackupInfo { get; set; }
        public FileInfo? TimeDataBackupInfo { get; set; }

        public string OverallStatus => 
            $"Auto-save: {ActionBasedAutoSaveStatus.StatusText} | " +
            $"Backups: {BackupStats.TotalBackups} | " +
            $"Health: {(TaskDataHealthy && TimeDataHealthy ? "GOOD" : "WARNING")}";
    }
}