using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class JsonDataService : IDataService, IAutoSaveable
    {
        private readonly string _dataFilePath;
        private readonly JsonSerializerOptions _jsonOptions;
        private readonly ProjectDataService _projectDataService;
        private readonly SafeFileWriter _safeWriter;
        private ObservableCollection<IDisplayableItem>? _lastSavedData;
        private DateTime _lastSaveTime = DateTime.MinValue;

        public JsonDataService(string dataFilePath = "data.json")
        {
            Logger.TraceEnter(parameters: new object[] { dataFilePath });
            
            _dataFilePath = dataFilePath;
            _safeWriter = new SafeFileWriter(dataFilePath);
            _projectDataService = new ProjectDataService();
            _jsonOptions = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                Converters = { new JsonStringEnumConverter() }
            };

            Logger.Info("JsonDataService", $"Initialized with data file: {_dataFilePath}");
            Logger.Debug("JsonDataService", "JSON options configured", 
                $"WriteIndented=true, CamelCase=true, StringEnumConverter=true");
            
            Logger.TraceExit();
        }

        public ObservableCollection<IDisplayableItem> LoadItems()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("LoadItems");

            try
            {
                Logger.TraceData("Check", "file existence", _dataFilePath);
                if (!File.Exists(_dataFilePath))
                {
                    Logger.Warning("JsonDataService", $"Data file not found: {_dataFilePath}");
                    Logger.TraceExit(returnValue: "empty collection");
                    return new ObservableCollection<IDisplayableItem>();
                }

                Logger.Debug("JsonDataService", $"Reading data file: {_dataFilePath}");
                var jsonString = File.ReadAllText(_dataFilePath);
                Logger.Trace("JsonDataService", $"Read {jsonString.Length} characters from file");

                // Handle empty or invalid JSON gracefully
                if (string.IsNullOrWhiteSpace(jsonString) || jsonString.Trim() == "[]")
                {
                    Logger.Info("JsonDataService", "Empty JSON file, returning empty collection");
                    Logger.TraceExit(returnValue: "empty collection (empty file)");
                    return new ObservableCollection<IDisplayableItem>();
                }

                // Parse the complete data structure including project data
                var dataStructure = JsonSerializer.Deserialize<DataFileStructure>(jsonString, _jsonOptions);
                Logger.Debug("JsonDataService", $"Deserialized data structure with {dataStructure?.Tasks?.Length ?? 0} tasks and {dataStructure?.ProjectData?.Count ?? 0} projects");

                var result = new ObservableCollection<IDisplayableItem>();
                
                // Load tasks
                if (dataStructure?.Tasks != null)
                {
                    Logger.Trace("JsonDataService", $"Converting {dataStructure.Tasks.Length} TaskItems to ObservableCollection");
                    foreach (var item in dataStructure.Tasks)
                    {
                        Logger.Trace("JsonDataService", $"Adding item: Id1={item.Id1}, Name={item.Name}");
                        // Fix the children collection hierarchy
                        FixChildrenHierarchy(item);
                        result.Add(item);
                        LogItemHierarchy(item, 1);
                    }
                }

                // Load project data
                if (dataStructure?.ProjectData != null)
                {
                    Logger.Trace("JsonDataService", $"Loading {dataStructure.ProjectData.Count} project data items");
                    _projectDataService.LoadProjectDataFromDictionary(dataStructure.ProjectData);
                }

                Logger.Info("JsonDataService", $"Successfully loaded {result.Count} root items and {dataStructure?.ProjectData?.Count ?? 0} project data items");
                Logger.TraceExit(returnValue: $"{result.Count} items");
                return result;
            }
            catch (JsonException jsonEx)
            {
                Logger.Error("JsonDataService", "JSON deserialization failed", jsonEx, 
                    $"File: {_dataFilePath}");
                Logger.TraceExit(returnValue: "empty collection (JSON error)");
                return new ObservableCollection<IDisplayableItem>();
            }
            catch (IOException ioEx)
            {
                Logger.Error("JsonDataService", "File I/O error during load", ioEx, 
                    $"File: {_dataFilePath}");
                Logger.TraceExit(returnValue: "empty collection (IO error)");
                return new ObservableCollection<IDisplayableItem>();
            }
            catch (Exception ex)
            {
                Logger.Critical("JsonDataService", "Unexpected error loading data", ex, 
                    $"File: {_dataFilePath}");
                Logger.TraceExit(returnValue: "empty collection (critical error)");
                return new ObservableCollection<IDisplayableItem>();
            }
        }

        private void FixChildrenHierarchy(TaskItem item)
        {
            // The issue is that JSON deserialization creates the children as concrete TaskItem objects
            // but they get stored in IDisplayableItem collection. This shouldn't cause deserialization
            // issues since TaskItem implements IDisplayableItem. Let's ensure the children are
            // properly connected and recursively fix their children too.
            Logger.Trace("JsonDataService", $"Fixing hierarchy for item: {item.Name}");
            
            if (item.Children != null)
            {
                foreach (var child in item.Children.Cast<TaskItem>())
                {
                    FixChildrenHierarchy(child);
                }
            }
        }

        public void SaveItems(ObservableCollection<IDisplayableItem> items)
        {
            Logger.TraceEnter(parameters: new object[] { $"{items.Count} items" });
            using var perfTracker = Logger.TracePerformance("SaveItems");

            try
            {
                Logger.Debug("JsonDataService", $"Saving {items.Count} items to {_dataFilePath}");
                
                // Convert to TaskItem array for serialization
                Logger.TraceData("Convert", "ObservableCollection to TaskItem[]");
                var taskItems = new TaskItem[items.Count];
                for (int i = 0; i < items.Count; i++)
                {
                    taskItems[i] = (TaskItem)items[i];
                    Logger.Trace("JsonDataService", $"Converting item {i}: Id1={taskItems[i].Id1}, Name={taskItems[i].Name}");
                }

                // Create complete data structure including project data
                var dataStructure = new DataFileStructure
                {
                    Tasks = taskItems,
                    ProjectData = _projectDataService.GetProjectDataDictionary()
                };

                Logger.TraceData("Serialize", "DataFileStructure to JSON");
                var jsonString = JsonSerializer.Serialize(dataStructure, _jsonOptions);
                Logger.Trace("JsonDataService", $"Serialized to {jsonString.Length} characters");

                Logger.TraceData("SafeWrite", "JSON to file", _dataFilePath);
                _safeWriter.SafeWrite(jsonString);
                
                // Update tracking for auto-save
                _lastSavedData = new ObservableCollection<IDisplayableItem>(items);
                _lastSaveTime = DateTime.Now;
                
                Logger.Info("JsonDataService", $"Successfully saved {items.Count} tasks and {dataStructure.ProjectData.Count} project data items to {_dataFilePath}");
                Logger.TraceExit();
            }
            catch (JsonException jsonEx)
            {
                Logger.Error("JsonDataService", "JSON serialization failed", jsonEx, 
                    $"ItemCount: {items.Count}");
                Logger.TraceExit();
            }
            catch (IOException ioEx)
            {
                Logger.Error("JsonDataService", "File I/O error during save", ioEx, 
                    $"File: {_dataFilePath}");
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Critical("JsonDataService", "Unexpected error saving data", ex, 
                    $"File: {_dataFilePath}, ItemCount: {items.Count}");
                Logger.TraceExit();
            }
        }

        private void LogItemHierarchy(TaskItem item, int depth)
        {
            if (!Logger.ShouldLog(LogLevel.Trace)) return;
            
            var indent = new string(' ', depth * 2);
            Logger.Trace("JsonDataService", $"{indent}└─ Child: Id1={item.Id1}, Name={item.Name}, Children={item.Children.Count}");
            
            foreach (var child in item.Children.Cast<TaskItem>())
            {
                LogItemHierarchy(child, depth + 1);
            }
        }

        public ProjectDataService GetProjectDataService()
        {
            return _projectDataService;
        }

        #region IAutoSaveable Implementation

        public string ServiceName => "JsonDataService";

        public bool HasUnsavedChanges()
        {
            // For now, we'll assume changes if no previous save time
            if (_lastSaveTime == DateTime.MinValue)
                return true;

            // In a more sophisticated implementation, we could track individual item changes
            // For now, consider changes if save is older than 5 minutes
            return DateTime.Now - _lastSaveTime > TimeSpan.FromMinutes(5);
        }

        public void AutoSave()
        {
            Logger.TraceEnter();
            try
            {
                // Auto-save would need access to current data
                // This is a simplified implementation - in practice, we'd need the current items
                Logger.Info("JsonDataService", "Auto-save triggered - would save current data if available");
                
                // Note: This would need to be called from a context that has access to current items
                // The TaskViewModel would need to provide this data or register itself with auto-save
                
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("JsonDataService", "Auto-save failed", ex);
                throw;
            }
        }

        #endregion
    }

    public class DataFileStructure
    {
        [JsonPropertyName("tasks")]
        public TaskItem[] Tasks { get; set; } = new TaskItem[0];

        [JsonPropertyName("projectData")]
        public Dictionary<string, ProjectDataItem> ProjectData { get; set; } = new Dictionary<string, ProjectDataItem>();
    }
}