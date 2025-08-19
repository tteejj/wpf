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
    public class TimeDataService : ITimeDataService
    {
        private readonly string _timeDataFilePath;
        private readonly JsonSerializerOptions _jsonOptions;
        private readonly IDataService _taskDataService;
        private ObservableCollection<TimeEntry> _timeEntries;

        public TimeDataService(string timeDataFilePath = "time-data.json", IDataService? taskDataService = null)
        {
            Logger.TraceEnter(parameters: new object[] { timeDataFilePath });
            
            _timeDataFilePath = timeDataFilePath;
            _taskDataService = taskDataService ?? new JsonDataService();
            _jsonOptions = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                Converters = { new JsonStringEnumConverter() }
            };

            _timeEntries = LoadTimeEntries();

            Logger.Info("TimeDataService", $"Initialized with time data file: {_timeDataFilePath}");
            Logger.Debug("TimeDataService", $"Loaded {_timeEntries.Count} existing time entries");
            
            Logger.TraceExit();
        }

        public ObservableCollection<TimeEntry> LoadTimeEntries()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("LoadTimeEntries");

            try
            {
                Logger.TraceData("Check", "file existence", _timeDataFilePath);
                if (!File.Exists(_timeDataFilePath))
                {
                    Logger.Warning("TimeDataService", $"Time data file not found: {_timeDataFilePath}");
                    Logger.TraceExit(returnValue: "empty collection");
                    return new ObservableCollection<TimeEntry>();
                }

                Logger.Debug("TimeDataService", $"Reading time data file: {_timeDataFilePath}");
                var jsonString = File.ReadAllText(_timeDataFilePath);
                Logger.Trace("TimeDataService", $"Read {jsonString.Length} characters from file");

                // Handle empty or invalid JSON gracefully
                if (string.IsNullOrWhiteSpace(jsonString) || jsonString.Trim() == "[]")
                {
                    Logger.Info("TimeDataService", "Empty JSON file, returning empty collection");
                    Logger.TraceExit(returnValue: "empty collection (empty file)");
                    return new ObservableCollection<TimeEntry>();
                }

                Logger.TraceData("Deserialize", "JSON to TimeEntry[]");
                var timeEntries = JsonSerializer.Deserialize<TimeEntry[]>(jsonString, _jsonOptions);
                Logger.Debug("TimeDataService", $"Deserialized {timeEntries?.Length ?? 0} time entries from JSON");

                var result = new ObservableCollection<TimeEntry>();
                if (timeEntries != null)
                {
                    Logger.Trace("TimeDataService", $"Converting {timeEntries.Length} TimeEntries to ObservableCollection");
                    foreach (var entry in timeEntries.OrderBy(e => e.Date).ThenBy(e => e.Id1).ThenBy(e => e.Id2))
                    {
                        Logger.Trace("TimeDataService", $"Adding entry: {entry.ProjectReference} on {entry.Date:yyyy-MM-dd} for {entry.Hours}h");
                        result.Add(entry);
                    }
                }

                Logger.Info("TimeDataService", $"Successfully loaded {result.Count} time entries");
                Logger.TraceExit(returnValue: $"{result.Count} entries");
                return result;
            }
            catch (JsonException jsonEx)
            {
                Logger.Error("TimeDataService", "JSON deserialization failed", jsonEx, 
                    $"File: {_timeDataFilePath}");
                Logger.TraceExit(returnValue: "empty collection (JSON error)");
                return new ObservableCollection<TimeEntry>();
            }
            catch (IOException ioEx)
            {
                Logger.Error("TimeDataService", "File I/O error during load", ioEx, 
                    $"File: {_timeDataFilePath}");
                Logger.TraceExit(returnValue: "empty collection (IO error)");
                return new ObservableCollection<TimeEntry>();
            }
            catch (Exception ex)
            {
                Logger.Critical("TimeDataService", "Unexpected error loading time data", ex, 
                    $"File: {_timeDataFilePath}");
                Logger.TraceExit(returnValue: "empty collection (critical error)");
                return new ObservableCollection<TimeEntry>();
            }
        }

        public void SaveTimeEntries(ObservableCollection<TimeEntry> timeEntries)
        {
            Logger.TraceEnter(parameters: new object[] { $"{timeEntries.Count} entries" });
            using var perfTracker = Logger.TracePerformance("SaveTimeEntries");

            try
            {
                Logger.Debug("TimeDataService", $"Saving {timeEntries.Count} time entries to {_timeDataFilePath}");
                
                // Convert to array for serialization, sorted by date then project
                Logger.TraceData("Convert", "ObservableCollection to TimeEntry[]");
                var timeEntryArray = timeEntries
                    .OrderBy(e => e.Date)
                    .ThenBy(e => e.Id1)
                    .ThenBy(e => e.Id2)
                    .ToArray();

                Logger.TraceData("Serialize", "TimeEntry[] to JSON");
                var jsonString = JsonSerializer.Serialize(timeEntryArray, _jsonOptions);
                Logger.Trace("TimeDataService", $"Serialized to {jsonString.Length} characters");

                Logger.TraceData("Write", "JSON to file", _timeDataFilePath);
                File.WriteAllText(_timeDataFilePath, jsonString);
                
                // Update internal cache
                _timeEntries = timeEntries;
                
                Logger.Info("TimeDataService", $"Successfully saved {timeEntries.Count} time entries to {_timeDataFilePath}");
                Logger.TraceExit();
            }
            catch (JsonException jsonEx)
            {
                Logger.Error("TimeDataService", "JSON serialization failed", jsonEx, 
                    $"EntryCount: {timeEntries.Count}");
                Logger.TraceExit();
            }
            catch (IOException ioEx)
            {
                Logger.Error("TimeDataService", "File I/O error during save", ioEx, 
                    $"File: {_timeDataFilePath}");
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Critical("TimeDataService", "Unexpected error saving time data", ex, 
                    $"File: {_timeDataFilePath}, EntryCount: {timeEntries.Count}");
                Logger.TraceExit();
            }
        }

        public IEnumerable<TimeEntry> GetTimeEntriesForDate(DateTime date)
        {
            Logger.TraceEnter(parameters: new object[] { date });
            var targetDate = date.Date;
            var entries = _timeEntries.Where(e => e.Date.Date == targetDate).ToList();
            Logger.Debug("TimeDataService", $"Found {entries.Count} time entries for {targetDate:yyyy-MM-dd}");
            Logger.TraceExit(returnValue: $"{entries.Count} entries");
            return entries;
        }

        public IEnumerable<TimeEntry> GetTimeEntriesForWeek(DateTime weekStartDate)
        {
            Logger.TraceEnter(parameters: new object[] { weekStartDate });
            var startDate = weekStartDate.Date;
            var endDate = startDate.AddDays(4); // Monday to Friday
            var entries = _timeEntries.Where(e => e.Date >= startDate && e.Date <= endDate).ToList();
            Logger.Debug("TimeDataService", $"Found {entries.Count} time entries for week {startDate:yyyy-MM-dd} to {endDate:yyyy-MM-dd}");
            Logger.TraceExit(returnValue: $"{entries.Count} entries");
            return entries;
        }

        public IEnumerable<TimeEntry> GetTimeEntriesForProject(int id1, int? id2)
        {
            Logger.TraceEnter(parameters: new object[] { id1, id2 ?? -1 });
            var entries = _timeEntries.Where(e => e.Id1 == id1 && e.Id2 == id2).ToList();
            var projectRef = id2.HasValue ? $"Project-{id1}.{id2}" : $"Generic-{id1}";
            Logger.Debug("TimeDataService", $"Found {entries.Count} time entries for {projectRef}");
            Logger.TraceExit(returnValue: $"{entries.Count} entries");
            return entries;
        }

        public decimal GetProjectWeekTotal(int id1, int? id2, DateTime weekStartDate)
        {
            Logger.TraceEnter(parameters: new object[] { id1, id2 ?? -1, weekStartDate });
            var weekEntries = GetTimeEntriesForWeek(weekStartDate);
            var projectEntries = weekEntries.Where(e => e.Id1 == id1 && e.Id2 == id2);
            var total = projectEntries.Sum(e => e.Hours);
            var projectRef = id2.HasValue ? $"Project-{id1}.{id2}" : $"Generic-{id1}";
            Logger.Debug("TimeDataService", $"Week total for {projectRef} week of {weekStartDate:yyyy-MM-dd}: {total}h");
            Logger.TraceExit(returnValue: total.ToString());
            return total;
        }

        public decimal GetDayTotal(DateTime date)
        {
            Logger.TraceEnter(parameters: new object[] { date });
            var dayEntries = GetTimeEntriesForDate(date);
            var total = dayEntries.Sum(e => e.Hours);
            Logger.Debug("TimeDataService", $"Day total for {date:yyyy-MM-dd}: {total}h");
            Logger.TraceExit(returnValue: total.ToString());
            return total;
        }

        public decimal GetWeekTotal(DateTime weekStartDate)
        {
            Logger.TraceEnter(parameters: new object[] { weekStartDate });
            var weekEntries = GetTimeEntriesForWeek(weekStartDate);
            var total = weekEntries.Sum(e => e.Hours);
            Logger.Debug("TimeDataService", $"Week total for week of {weekStartDate:yyyy-MM-dd}: {total}h");
            Logger.TraceExit(returnValue: total.ToString());
            return total;
        }

        public IEnumerable<TimeSummary> GetWeekSummariesByProject(DateTime weekStartDate)
        {
            Logger.TraceEnter(parameters: new object[] { weekStartDate });
            var weekEntries = GetTimeEntriesForWeek(weekStartDate);
            
            var summaries = weekEntries
                .GroupBy(e => new { e.Id1, e.Id2 })
                .Where(g => g.Key.Id2.HasValue) // Only projects, not generic timecodes
                .Select(g => new TimeSummary(g.Key.Id1, g.Key.Id2, weekStartDate)
                {
                    TotalHours = g.Sum(e => e.Hours)
                })
                .OrderBy(s => s.Id1)
                .ThenBy(s => s.Id2)
                .ToList();

            Logger.Debug("TimeDataService", $"Generated {summaries.Count} project summaries for week of {weekStartDate:yyyy-MM-dd}");
            Logger.TraceExit(returnValue: $"{summaries.Count} summaries");
            return summaries;
        }

        public IEnumerable<(int Id1, int? Id2, string Name)> GetAvailableProjects()
        {
            Logger.TraceEnter();
            
            try
            {
                var taskItems = _taskDataService.LoadItems();
                var projects = new List<(int Id1, int? Id2, string Name)>();
                
                // Recursively collect all projects and tasks
                CollectProjectsRecursive(taskItems, projects);
                
                var result = projects
                    .OrderBy(p => p.Id1)
                    .ThenBy(p => p.Id2)
                    .ToList();
                
                Logger.Debug("TimeDataService", $"Found {result.Count} available projects");
                Logger.TraceExit(returnValue: $"{result.Count} projects");
                return result;
            }
            catch (Exception ex)
            {
                Logger.Error("TimeDataService", "Error loading available projects", ex);
                Logger.TraceExit(returnValue: "empty list (error)");
                return new List<(int Id1, int? Id2, string Name)>();
            }
        }

        private void CollectProjectsRecursive(ObservableCollection<IDisplayableItem> items, List<(int Id1, int? Id2, string Name)> projects)
        {
            foreach (var item in items.Cast<TaskItem>())
            {
                projects.Add((item.Id1, item.Id2, item.Name));
                
                if (item.Children.Count > 0)
                {
                    CollectProjectsRecursive(item.Children, projects);
                }
            }
        }
    }
}