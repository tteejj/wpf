using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class JsonDataService : IDataService
    {
        private readonly string _dataFilePath;
        private readonly JsonSerializerOptions _jsonOptions;

        public JsonDataService(string dataFilePath = "data.json")
        {
            Logger.TraceEnter(parameters: new object[] { dataFilePath });
            
            _dataFilePath = dataFilePath;
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

                Logger.TraceData("Deserialize", "JSON to TaskItem[]");
                var taskItems = JsonSerializer.Deserialize<TaskItem[]>(jsonString, _jsonOptions);
                Logger.Debug("JsonDataService", $"Deserialized {taskItems?.Length ?? 0} items from JSON");

                var result = new ObservableCollection<IDisplayableItem>();
                if (taskItems != null)
                {
                    Logger.Trace("JsonDataService", $"Converting {taskItems.Length} TaskItems to ObservableCollection");
                    foreach (var item in taskItems)
                    {
                        Logger.Trace("JsonDataService", $"Adding item: Id1={item.Id1}, Name={item.Name}");
                        // Fix the children collection hierarchy
                        FixChildrenHierarchy(item);
                        result.Add(item);
                        LogItemHierarchy(item, 1);
                    }
                }

                Logger.Info("JsonDataService", $"Successfully loaded {result.Count} root items");
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

                Logger.TraceData("Serialize", "TaskItem[] to JSON");
                var jsonString = JsonSerializer.Serialize(taskItems, _jsonOptions);
                Logger.Trace("JsonDataService", $"Serialized to {jsonString.Length} characters");

                Logger.TraceData("Write", "JSON to file", _dataFilePath);
                File.WriteAllText(_dataFilePath, jsonString);
                
                Logger.Info("JsonDataService", $"Successfully saved {items.Count} items to {_dataFilePath}");
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
    }
}