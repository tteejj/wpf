using System;
using System.Collections.Generic;
using PraxisWpf.Interfaces;

namespace PraxisWpf.Services
{
    /// <summary>
    /// Action-based auto-save service that triggers saves on CRUD operations
    /// </summary>
    public class ActionBasedAutoSaveService : IDisposable
    {
        private readonly Dictionary<string, ISaveableService> _saveableServices;
        private readonly SafeFileWriter _taskDataWriter;
        private readonly SafeFileWriter _timeDataWriter;
        private bool _disposed = false;

        public ActionBasedAutoSaveService(string taskDataPath = "data.json", string timeDataPath = "time-data.json")
        {
            Logger.TraceEnter($"taskDataPath={taskDataPath}, timeDataPath={timeDataPath}");

            _saveableServices = new Dictionary<string, ISaveableService>();
            _taskDataWriter = new SafeFileWriter(taskDataPath);
            _timeDataWriter = new SafeFileWriter(timeDataPath);

            Logger.Info("ActionBasedAutoSaveService", "Action-based auto-save service initialized");
            Logger.TraceExit();
        }

        /// <summary>
        /// Registers a service for action-based auto-saving
        /// </summary>
        public void RegisterService(string serviceKey, ISaveableService service)
        {
            Logger.TraceEnter($"serviceKey={serviceKey}, service={service.GetType().Name}");

            _saveableServices[serviceKey] = service;
            Logger.Info("ActionBasedAutoSaveService", $"Registered {service.GetType().Name} with key: {serviceKey}");

            Logger.TraceExit();
        }

        /// <summary>
        /// Triggers immediate save after a CRUD operation
        /// </summary>
        public void SaveAfterAction(string serviceKey, string actionDescription)
        {
            Logger.TraceEnter($"serviceKey={serviceKey}, action={actionDescription}");

            try
            {
                if (_saveableServices.TryGetValue(serviceKey, out var service))
                {
                    Logger.Info("ActionBasedAutoSaveService", $"Auto-saving after action: {actionDescription}");
                    service.Save();
                    Logger.Info("ActionBasedAutoSaveService", $"Auto-save completed for {serviceKey} after {actionDescription}");
                }
                else
                {
                    Logger.Warning("ActionBasedAutoSaveService", $"Service not found for key: {serviceKey}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("ActionBasedAutoSaveService", $"Auto-save failed for {serviceKey} after {actionDescription}: {ex.Message}");
                // Don't rethrow - auto-save failures shouldn't break the user's action
            }

            Logger.TraceExit();
        }

        /// <summary>
        /// Saves all registered services (used on application exit)
        /// </summary>
        public void SaveAll(string reason = "Application Exit")
        {
            Logger.TraceEnter($"reason={reason}");

            var successCount = 0;
            var errorCount = 0;

            foreach (var kvp in _saveableServices)
            {
                try
                {
                    Logger.Debug("ActionBasedAutoSaveService", $"Saving {kvp.Key} for {reason}");
                    kvp.Value.Save();
                    successCount++;
                    Logger.Debug("ActionBasedAutoSaveService", $"Successfully saved {kvp.Key}");
                }
                catch (Exception ex)
                {
                    errorCount++;
                    Logger.Error("ActionBasedAutoSaveService", $"Failed to save {kvp.Key} for {reason}: {ex.Message}");
                }
            }

            if (errorCount > 0)
            {
                Logger.Warning("ActionBasedAutoSaveService", $"{reason} save completed with errors - Success: {successCount}, Errors: {errorCount}");
            }
            else if (successCount > 0)
            {
                Logger.Info("ActionBasedAutoSaveService", $"{reason} save completed successfully - Saved: {successCount} services");
            }
            else
            {
                Logger.Debug("ActionBasedAutoSaveService", $"{reason} save completed - No services registered");
            }

            Logger.TraceExit();
        }

        /// <summary>
        /// Gets simple status information
        /// </summary>
        public ActionBasedAutoSaveStatus GetStatus()
        {
            return new ActionBasedAutoSaveStatus
            {
                RegisteredServices = _saveableServices.Count,
                TaskDataHealthy = _taskDataWriter.IsMainFileHealthy(),
                TimeDataHealthy = _timeDataWriter.IsMainFileHealthy()
            };
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                Logger.TraceEnter();

                // Save all on dispose
                SaveAll("Service Disposal");

                // Clear services
                _saveableServices.Clear();

                _disposed = true;
                Logger.Info("ActionBasedAutoSaveService", "Action-based auto-save service disposed");
                Logger.TraceExit();
            }
        }
    }

    /// <summary>
    /// Simple interface for services that can be saved
    /// </summary>
    public interface ISaveableService
    {
        /// <summary>
        /// Performs the save operation
        /// </summary>
        void Save();

        /// <summary>
        /// Gets the display name of the service for logging
        /// </summary>
        string ServiceName { get; }
    }

    /// <summary>
    /// Status information for the action-based auto-save service
    /// </summary>
    public class ActionBasedAutoSaveStatus
    {
        public int RegisteredServices { get; set; }
        public bool TaskDataHealthy { get; set; }
        public bool TimeDataHealthy { get; set; }

        public string StatusText => 
            $"Action-based auto-save | Services: {RegisteredServices} | " +
            $"Health: {(TaskDataHealthy && TimeDataHealthy ? "GOOD" : "WARNING")}";
    }
}