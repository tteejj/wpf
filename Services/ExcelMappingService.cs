using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using ClosedXML.Excel;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class ExcelMappingService
    {
        public ExcelMappingService()
        {
            Logger.TraceEnter();
            Logger.TraceExit();
        }

        /// <summary>
        /// Gets worksheet names from an Excel file
        /// </summary>
        public List<string> GetWorksheetNames(string filePath)
        {
            Logger.TraceEnter($"filePath={filePath}");
            
            try
            {
                if (!File.Exists(filePath))
                {
                    Logger.Warning("ExcelMappingService", $"File not found: {filePath}");
                    return new List<string>();
                }

                using var workbook = new XLWorkbook(filePath);
                var worksheetNames = workbook.Worksheets.Select(ws => ws.Name).ToList();
                
                Logger.Info("ExcelMappingService", $"Found {worksheetNames.Count} worksheets in {Path.GetFileName(filePath)}");
                Logger.TraceExit($"{worksheetNames.Count} worksheets");
                return worksheetNames;
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelMappingService", $"Failed to read worksheets from {filePath}", ex);
                Logger.TraceExit("empty list");
                return new List<string>();
            }
        }

        /// <summary>
        /// Reads values from source cells and updates the field mappings
        /// </summary>
        public void ReadSourceValues(List<ExcelFieldMapping> fieldMappings, string sourceFilePath, string sourceSheet)
        {
            Logger.TraceEnter($"sourceFilePath={sourceFilePath}, sourceSheet={sourceSheet}");
            
            try
            {
                if (!File.Exists(sourceFilePath))
                {
                    Logger.Warning("ExcelMappingService", $"Source file not found: {sourceFilePath}");
                    return;
                }

                using var workbook = new XLWorkbook(sourceFilePath);
                var worksheet = workbook.Worksheets.FirstOrDefault(ws => ws.Name == sourceSheet);
                
                if (worksheet == null)
                {
                    Logger.Warning("ExcelMappingService", $"Worksheet '{sourceSheet}' not found in {Path.GetFileName(sourceFilePath)}");
                    return;
                }

                foreach (var mapping in fieldMappings)
                {
                    if (string.IsNullOrWhiteSpace(mapping.SourceCell))
                        continue;

                    try
                    {
                        var cell = worksheet.Cell(mapping.SourceCell);
                        mapping.CurrentValue = cell.Value.ToString();
                        Logger.Trace("ExcelMappingService", $"Read {mapping.FieldName}: {mapping.SourceCell} = '{mapping.CurrentValue}'");
                    }
                    catch (Exception ex)
                    {
                        Logger.Warning("ExcelMappingService", $"Failed to read cell {mapping.SourceCell} for {mapping.FieldName}: {ex.Message}");
                        mapping.CurrentValue = "[ERROR]";
                    }
                }

                Logger.Info("ExcelMappingService", $"Read values for {fieldMappings.Count} field mappings");
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelMappingService", "Failed to read source values", ex);
            }
            
            Logger.TraceExit();
        }

        /// <summary>
        /// Executes the mapping by copying values from source to destination cells
        /// </summary>
        public async Task<ExcelMappingResult> ExecuteMappingAsync(List<ExcelFieldMapping> fieldMappings, string sourceFilePath, string sourceSheet, string destinationFilePath, string destinationSheet)
        {
            Logger.TraceEnter($"sourceFilePath={sourceFilePath}, destinationFilePath={destinationFilePath}");
            
            var result = new ExcelMappingResult();
            
            try
            {
                // Validate inputs
                if (!File.Exists(sourceFilePath))
                {
                    result.ErrorMessage = $"Source file not found: {sourceFilePath}";
                    return result;
                }

                if (!File.Exists(destinationFilePath))
                {
                    result.ErrorMessage = $"Destination file not found: {destinationFilePath}";
                    return result;
                }

                // Read from source
                using var sourceWorkbook = new XLWorkbook(sourceFilePath);
                var sourceWorksheet = sourceWorkbook.Worksheets.FirstOrDefault(ws => ws.Name == sourceSheet);
                
                if (sourceWorksheet == null)
                {
                    result.ErrorMessage = $"Source worksheet '{sourceSheet}' not found";
                    return result;
                }

                // Open destination for writing
                using var destWorkbook = new XLWorkbook(destinationFilePath);
                var destWorksheet = destWorkbook.Worksheets.FirstOrDefault(ws => ws.Name == destinationSheet);
                
                if (destWorksheet == null)
                {
                    result.ErrorMessage = $"Destination worksheet '{destinationSheet}' not found";
                    return result;
                }

                // Execute mappings
                var processedCount = 0;
                var t2020Count = 0;
                
                foreach (var mapping in fieldMappings)
                {
                    if (string.IsNullOrWhiteSpace(mapping.SourceCell) || string.IsNullOrWhiteSpace(mapping.DestinationCell))
                        continue;

                    try
                    {
                        // Read source value
                        var sourceCell = sourceWorksheet.Cell(mapping.SourceCell);
                        var value = sourceCell.Value;
                        
                        // Write to destination
                        var destCell = destWorksheet.Cell(mapping.DestinationCell);
                        destCell.Value = value;
                        
                        // Copy formatting if needed
                        destCell.Style = sourceCell.Style;
                        
                        processedCount++;
                        if (mapping.UseInT2020)
                            t2020Count++;
                        
                        Logger.Trace("ExcelMappingService", $"Mapped {mapping.FieldName}: {mapping.SourceCell} → {mapping.DestinationCell} = '{value}'");
                    }
                    catch (Exception ex)
                    {
                        Logger.Warning("ExcelMappingService", $"Failed to map {mapping.FieldName}: {ex.Message}");
                        result.Warnings.Add($"Failed to map {mapping.FieldName}: {ex.Message}");
                    }
                }

                // Save destination file
                destWorkbook.Save();
                
                result.Success = true;
                result.ProcessedCount = processedCount;
                result.T2020Count = t2020Count;
                result.Message = $"Successfully mapped {processedCount} fields ({t2020Count} marked for T2020)";
                
                Logger.Info("ExcelMappingService", result.Message);
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelMappingService", "Mapping execution failed", ex);
                result.ErrorMessage = $"Mapping failed: {ex.Message}";
            }
            
            Logger.TraceExit($"Success={result.Success}");
            return result;
        }

        /// <summary>
        /// Exports T2020 fields to a text file
        /// </summary>
        public async Task<ExcelMappingResult> ExportTextFileAsync(List<ExcelFieldMapping> fieldMappings, string outputPath)
        {
            Logger.TraceEnter($"outputPath={outputPath}");
            
            var result = new ExcelMappingResult();
            
            try
            {
                var t2020Fields = fieldMappings.Where(f => f.UseInT2020).ToList();
                
                if (!t2020Fields.Any())
                {
                    result.ErrorMessage = "No fields marked for T2020 export";
                    return result;
                }

                var lines = new List<string>
                {
                    "# T2020 Field Export",
                    $"# Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
                    $"# Fields: {t2020Fields.Count}",
                    ""
                };

                foreach (var field in t2020Fields)
                {
                    lines.Add($"{field.FieldName}={field.CurrentValue}");
                }

                await File.WriteAllLinesAsync(outputPath, lines);
                
                result.Success = true;
                result.T2020Count = t2020Fields.Count;
                result.Message = $"Exported {t2020Fields.Count} T2020 fields to {Path.GetFileName(outputPath)}";
                
                Logger.Info("ExcelMappingService", result.Message);
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelMappingService", "Text export failed", ex);
                result.ErrorMessage = $"Export failed: {ex.Message}";
            }
            
            Logger.TraceExit($"Success={result.Success}");
            return result;
        }
    }

    public class ExcelMappingResult
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public int ProcessedCount { get; set; }
        public int T2020Count { get; set; }
        public List<string> Warnings { get; set; } = new();
    }
}