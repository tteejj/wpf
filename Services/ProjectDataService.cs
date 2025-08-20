using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Timers;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class ProjectDataService : IDisposable
    {
        private readonly ConcurrentDictionary<string, ProjectDataItem> _projectDataCache;
        private readonly ConcurrentDictionary<string, DateTime> _cacheAccessTimes;
        private readonly Timer _cacheCleanupTimer;
        private readonly object _lockObject = new object();
        private const int CACHE_CLEANUP_INTERVAL_MS = 300000; // 5 minutes
        private const int CACHE_EXPIRY_MINUTES = 30;
        private const int MAX_CACHE_SIZE = 100;
        private bool _disposed = false;

        public ProjectDataService()
        {
            _projectDataCache = new ConcurrentDictionary<string, ProjectDataItem>();
            _cacheAccessTimes = new ConcurrentDictionary<string, DateTime>();
            
            // Set up cache cleanup timer
            _cacheCleanupTimer = new Timer(CACHE_CLEANUP_INTERVAL_MS);
            _cacheCleanupTimer.Elapsed += CleanupCache;
            _cacheCleanupTimer.AutoReset = true;
            _cacheCleanupTimer.Start();
            
            // Initialize with sample project data for demonstration
            InitializeSampleData();
        }
        
        private void InitializeSampleData()
        {
            Logger.TraceEnter();
            
            try
            {
                // Create sample project data based on common project patterns
                var sampleProjects = new[]
                {
                    new ProjectDataItem
                    {
                        ProjectId = "P001",
                        RequestDate = "2024-08-15",
                        AuditType = "Environmental Compliance",
                        AuditorName = "John Smith",
                        SiteName = "Main Manufacturing Site",
                        SiteAddress = "123 Industrial Blvd",
                        SiteCity = "Manufacturing City",
                        SiteState = "CA",
                        SiteZip = "90210",
                        Status = "In Progress",
                        Comments = "Sample project for demonstration"
                    },
                    new ProjectDataItem
                    {
                        ProjectId = "P002", 
                        RequestDate = "2024-08-10",
                        AuditType = "Safety Inspection",
                        AuditorName = "Jane Doe",
                        SiteName = "Warehouse Facility",
                        SiteAddress = "456 Storage Ave",
                        SiteCity = "Warehouse Town",
                        SiteState = "TX",
                        SiteZip = "75001",
                        Status = "Completed",
                        Comments = "Second sample project"
                    }
                };
                
                foreach (var project in sampleProjects)
                {
                    _projectDataCache[project.ProjectId] = project;
                }
                
                Logger.Info("ProjectDataService", $"Initialized {sampleProjects.Length} sample projects");
            }
            catch (Exception ex)
            {
                Logger.Error("ProjectDataService", $"Failed to initialize sample data: {ex.Message}");
            }
            
            Logger.TraceExit();
        }

        public async Task<ProjectDataItem?> GetProjectDataAsync(string projectId)
        {
            Logger.TraceEnter($"projectId={projectId}");

            if (_projectDataCache.TryGetValue(projectId, out var cachedData))
            {
                UpdateCacheAccess(projectId);
                Logger.Info("ProjectDataService", $"Returning cached data for project: {projectId}");
                return cachedData;
            }

            Logger.Info("ProjectDataService", $"No cached data found for project: {projectId}");
            Logger.TraceExit();
            return null;
        }

        public async Task<ProjectDataItem?> ImportProjectFromExcelAsync(string excelFilePath, string projectId)
        {
            Logger.TraceEnter($"excelFilePath={excelFilePath}, projectId={projectId}");

            try
            {
                if (!File.Exists(excelFilePath))
                {
                    Logger.Error("ProjectDataService", $"Excel file not found: {excelFilePath}");
                    return null;
                }

                // Create new empty project
                var projectData = new ProjectDataItem
                {
                    ProjectId = projectId
                };
                
                _projectDataCache[projectId] = projectData;
                Logger.Info("ProjectDataService", $"Created new project: {projectId}");

                Logger.TraceExit();
                return projectData;
            }
            catch (Exception ex)
            {
                Logger.Error("ProjectDataService", 
                    $"Failed to import project from Excel: {ex.Message}");
                Logger.TraceExit();
                return null;
            }
        }

        public async Task<bool> SyncProjectDataAsync(string projectId, string excelFilePath)
        {
            Logger.TraceEnter($"projectId={projectId}, excelFilePath={excelFilePath}");

            try
            {
                var updatedData = await ImportProjectFromExcelAsync(excelFilePath, projectId);
                
                if (updatedData != null)
                {
                    _projectDataCache[projectId] = updatedData;
                    Logger.Info("ProjectDataService", $"Successfully synced project data: {projectId}");
                    Logger.TraceExit();
                    return true;
                }

                Logger.Warning("ProjectDataService", $"Failed to sync project data: {projectId}");
                Logger.TraceExit();
                return false;
            }
            catch (Exception ex)
            {
                Logger.Error("ProjectDataService", 
                    $"Error syncing project data: {ex.Message}");
                Logger.TraceExit();
                return false;
            }
        }

        public void UpdateProjectData(string projectId, ProjectDataItem projectData)
        {
            Logger.TraceEnter($"projectId={projectId}");
            
            projectData.ProjectId = projectId;
            _projectDataCache[projectId] = projectData;
            UpdateCacheAccess(projectId);
            
            Logger.Info("ProjectDataService", $"Updated project data in cache: {projectId}");
            Logger.TraceExit();
        }

        public IEnumerable<ProjectDataItem> GetAllProjectData()
        {
            Logger.TraceEnter();
            
            var result = _projectDataCache.Values.ToList();
            
            Logger.Info("ProjectDataService", $"Returning {result.Count} cached project data items");
            Logger.TraceExit();
            
            return result;
        }

        public bool HasProjectData(string projectId)
        {
            var hasData = _projectDataCache.ContainsKey(projectId);
            Logger.Trace("ProjectDataService", $"Project {projectId} has data: {hasData}");
            return hasData;
        }

        public void LoadProjectDataFromDictionary(Dictionary<string, ProjectDataItem> projectDataDict)
        {
            Logger.TraceEnter($"Loading {projectDataDict.Count} project data items");
            
            _projectDataCache.Clear();
            
            foreach (var kvp in projectDataDict)
            {
                kvp.Value.ProjectId = kvp.Key;
                _projectDataCache[kvp.Key] = kvp.Value;
            }
            
            Logger.Info("ProjectDataService", 
                $"Loaded {_projectDataCache.Count} project data items into cache");
            Logger.TraceExit();
        }

        public Dictionary<string, ProjectDataItem> GetProjectDataDictionary()
        {
            Logger.TraceEnter();
            
            var result = new Dictionary<string, ProjectDataItem>(_projectDataCache);
            
            Logger.Info("ProjectDataService", 
                $"Returning dictionary with {result.Count} project data items");
            Logger.TraceExit();
            
            return result;
        }

        public async Task<bool> ExportProjectDataAsync(string projectId, string outputPath, string format = "CSV")
        {
            Logger.TraceEnter($"projectId={projectId}, outputPath={outputPath}, format={format}");

            try
            {
                if (!_projectDataCache.TryGetValue(projectId, out var projectData))
                {
                    Logger.Warning("ProjectDataService", $"No project data found for: {projectId}");
                    return false;
                }

                // Simple file export - use Excel Mapping Tool for advanced mapping
                try
                {
                    var jsonData = System.Text.Json.JsonSerializer.Serialize(projectData, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
                    await File.WriteAllTextAsync(outputPath, jsonData);
                    
                    Logger.Info("ProjectDataService", $"Exported project data: {projectId} to {outputPath}");
                    Logger.TraceExit();
                    return true;
                }
                catch (Exception exportEx)
                {
                    Logger.Error("ProjectDataService", $"Export failed: {exportEx.Message}");
                    Logger.TraceExit();
                    return false;
                }
            }
            catch (Exception ex)
            {
                Logger.Error("ProjectDataService", 
                    $"Error exporting project data: {ex.Message}");
                Logger.TraceExit();
                return false;
            }
        }

        private void CleanupCache(object? sender, ElapsedEventArgs e)
        {
            if (_disposed) return;
            
            Logger.TraceEnter();
            
            try
            {
                lock (_lockObject)
                {
                    var cutoffTime = DateTime.Now.AddMinutes(-CACHE_EXPIRY_MINUTES);
                    var expiredKeys = _cacheAccessTimes
                        .Where(kvp => kvp.Value < cutoffTime)
                        .Select(kvp => kvp.Key)
                        .ToList();
                    
                    foreach (var key in expiredKeys)
                    {
                        _projectDataCache.TryRemove(key, out _);
                        _cacheAccessTimes.TryRemove(key, out _);
                    }
                    
                    // Enforce max cache size by removing least recently used items
                    if (_projectDataCache.Count > MAX_CACHE_SIZE)
                    {
                        var lruKeys = _cacheAccessTimes
                            .OrderBy(kvp => kvp.Value)
                            .Take(_projectDataCache.Count - MAX_CACHE_SIZE)
                            .Select(kvp => kvp.Key)
                            .ToList();
                        
                        foreach (var key in lruKeys)
                        {
                            _projectDataCache.TryRemove(key, out _);
                            _cacheAccessTimes.TryRemove(key, out _);
                        }
                    }
                    
                    Logger.Info("ProjectDataService", $"Cache cleanup completed. Removed {expiredKeys.Count} expired items. Cache size: {_projectDataCache.Count}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("ProjectDataService", $"Error during cache cleanup: {ex.Message}");
            }
            
            Logger.TraceExit();
        }
        
        private void UpdateCacheAccess(string projectId)
        {
            _cacheAccessTimes[projectId] = DateTime.Now;
        }
        
        public void ClearCache()
        {
            Logger.TraceEnter();
            
            lock (_lockObject)
            {
                var count = _projectDataCache.Count;
                _projectDataCache.Clear();
                _cacheAccessTimes.Clear();
                
                // Re-initialize sample data
                InitializeSampleData();
                
                Logger.Info("ProjectDataService", $"Cache cleared. Removed {count} items and re-initialized sample data");
            }
            
            Logger.TraceExit();
        }
        
        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }
        
        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed && disposing)
            {
                Logger.TraceEnter();
                
                _cacheCleanupTimer?.Stop();
                _cacheCleanupTimer?.Dispose();
                _projectDataCache.Clear();
                _cacheAccessTimes.Clear();
                
                _disposed = true;
                
                Logger.Info("ProjectDataService", "Disposed and cleaned up resources");
                Logger.TraceExit();
            }
        }
    }
}