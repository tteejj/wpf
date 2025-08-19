using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class ProjectDataService
    {
        private readonly ExcelIntegrationService _excelService;
        private readonly Dictionary<string, ProjectDataItem> _projectDataCache;

        public ProjectDataService()
        {
            _excelService = new ExcelIntegrationService();
            _projectDataCache = new Dictionary<string, ProjectDataItem>();
        }

        public async Task<ProjectDataItem?> GetProjectDataAsync(string projectId)
        {
            Logger.TraceEnter($"projectId={projectId}");

            if (_projectDataCache.TryGetValue(projectId, out var cachedData))
            {
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

                // Create temporary config for extraction
                var tempConfigPath = Path.Combine(Path.GetTempPath(), $"excel_config_{projectId}.json");
                
                // Run Excel extraction
                var extractResult = await _excelService.RunExcelExtractionAsync(excelFilePath, tempConfigPath);
                
                if (!extractResult.Success)
                {
                    Logger.Error("ProjectDataService", 
                        $"Excel extraction failed: {extractResult.ErrorMessage}");
                    return null;
                }

                // Parse the extracted data
                var outputPath = Path.Combine(Path.GetTempPath(), $"extracted_data_{projectId}.json");
                var projectData = await _excelService.ParseExtractedDataAsync(outputPath);
                
                if (projectData != null)
                {
                    projectData.ProjectId = projectId;
                    _projectDataCache[projectId] = projectData;
                    
                    Logger.Info("ProjectDataService", 
                        $"Successfully imported project data for: {projectId}");
                    
                    // Clean up temp files
                    try
                    {
                        if (File.Exists(tempConfigPath)) File.Delete(tempConfigPath);
                        if (File.Exists(outputPath)) File.Delete(outputPath);
                    }
                    catch { /* Ignore cleanup errors */ }
                }

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

                var exportResult = await _excelService.RunDataExportAsync(projectId, outputPath);
                
                if (exportResult.Success)
                {
                    Logger.Info("ProjectDataService", 
                        $"Successfully exported project data: {projectId} to {outputPath}");
                    Logger.TraceExit();
                    return true;
                }
                else
                {
                    Logger.Error("ProjectDataService", 
                        $"Export failed: {exportResult.ErrorMessage}");
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

        public void Dispose()
        {
            Logger.TraceEnter();
            _excelService?.Cleanup();
            _projectDataCache.Clear();
            Logger.Info("ProjectDataService", "Disposed and cleaned up resources");
            Logger.TraceExit();
        }
    }
}