using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Microsoft.Office.Interop.Excel;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class ExcelComService : IDisposable
    {
        private Microsoft.Office.Interop.Excel.Application? _excelApp;
        private bool _disposed = false;

        public ExcelComService()
        {
            Logger.TraceEnter();
            Logger.TraceExit();
        }

        /// <summary>
        /// Gets worksheet names from an Excel file using COM
        /// </summary>
        public List<string> GetWorksheetNames(string filePath)
        {
            Logger.TraceEnter($"filePath={filePath}");
            
            var worksheetNames = new List<string>();
            Workbook? workbook = null;
            
            try
            {
                if (!File.Exists(filePath))
                {
                    Logger.Warning("ExcelComService", $"File not found: {filePath}");
                    return worksheetNames;
                }

                EnsureExcelApp();
                workbook = _excelApp!.Workbooks.Open(filePath, ReadOnly: true);
                
                foreach (object worksheetObj in workbook.Worksheets)
                {
                    var worksheet = (Worksheet)worksheetObj;
                    worksheetNames.Add(worksheet.Name);
                    Marshal.ReleaseComObject(worksheet);
                }
                
                Logger.Info("ExcelComService", $"Found {worksheetNames.Count} worksheets in {Path.GetFileName(filePath)}");
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelComService", $"Failed to read worksheets from {filePath}", ex);
            }
            finally
            {
                if (workbook != null)
                {
                    workbook.Close(false);
                    Marshal.ReleaseComObject(workbook);
                }
            }
            
            Logger.TraceExit($"{worksheetNames.Count} worksheets");
            return worksheetNames;
        }

        /// <summary>
        /// Reads values from source cells and updates the field mappings
        /// </summary>
        public void ReadSourceValues(List<ExcelFieldMapping> fieldMappings, string sourceFilePath, string sourceSheet)
        {
            Logger.TraceEnter($"sourceFilePath={sourceFilePath}, sourceSheet={sourceSheet}");
            
            Workbook? workbook = null;
            Worksheet? worksheet = null;
            
            try
            {
                if (!File.Exists(sourceFilePath))
                {
                    Logger.Warning("ExcelComService", $"Source file not found: {sourceFilePath}");
                    return;
                }

                EnsureExcelApp();
                workbook = _excelApp!.Workbooks.Open(sourceFilePath, ReadOnly: true);
                worksheet = FindWorksheet(workbook, sourceSheet);
                
                if (worksheet == null)
                {
                    Logger.Warning("ExcelComService", $"Worksheet '{sourceSheet}' not found");
                    return;
                }

                foreach (var mapping in fieldMappings)
                {
                    if (string.IsNullOrWhiteSpace(mapping.SourceCell))
                        continue;

                    try
                    {
                        var range = worksheet.Range[mapping.SourceCell];
                        mapping.CurrentValue = range.Value?.ToString() ?? string.Empty;
                        Marshal.ReleaseComObject(range);
                        
                        Logger.Trace("ExcelComService", $"Read {mapping.FieldName}: {mapping.SourceCell} = '{mapping.CurrentValue}'");
                    }
                    catch (Exception ex)
                    {
                        Logger.Warning("ExcelComService", $"Failed to read cell {mapping.SourceCell} for {mapping.FieldName}: {ex.Message}");
                        mapping.CurrentValue = "[ERROR]";
                    }
                }

                Logger.Info("ExcelComService", $"Read values for {fieldMappings.Count} field mappings");
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelComService", "Failed to read source values", ex);
            }
            finally
            {
                if (worksheet != null) Marshal.ReleaseComObject(worksheet);
                if (workbook != null)
                {
                    workbook.Close(false);
                    Marshal.ReleaseComObject(workbook);
                }
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
            Workbook? sourceWorkbook = null;
            Workbook? destWorkbook = null;
            Worksheet? sourceWorksheet = null;
            Worksheet? destWorksheet = null;
            
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

                EnsureExcelApp();
                
                // Open source workbook
                sourceWorkbook = _excelApp!.Workbooks.Open(sourceFilePath, ReadOnly: true);
                sourceWorksheet = FindWorksheet(sourceWorkbook, sourceSheet);
                
                if (sourceWorksheet == null)
                {
                    result.ErrorMessage = $"Source worksheet '{sourceSheet}' not found";
                    return result;
                }

                // Open destination workbook
                destWorkbook = _excelApp.Workbooks.Open(destinationFilePath);
                destWorksheet = FindWorksheet(destWorkbook, destinationSheet);
                
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
                        var sourceRange = sourceWorksheet.Range[mapping.SourceCell];
                        var value = sourceRange.Value;
                        
                        // Write to destination
                        var destRange = destWorksheet.Range[mapping.DestinationCell];
                        destRange.Value = value;
                        
                        // Copy formatting
                        sourceRange.Copy();
                        destRange.PasteSpecial(XlPasteType.xlPasteFormats);
                        
                        Marshal.ReleaseComObject(sourceRange);
                        Marshal.ReleaseComObject(destRange);
                        
                        processedCount++;
                        if (mapping.UseInT2020)
                            t2020Count++;
                        
                        Logger.Trace("ExcelComService", $"Mapped {mapping.FieldName}: {mapping.SourceCell} → {mapping.DestinationCell} = '{value}'");
                    }
                    catch (Exception ex)
                    {
                        Logger.Warning("ExcelComService", $"Failed to map {mapping.FieldName}: {ex.Message}");
                        result.Warnings.Add($"Failed to map {mapping.FieldName}: {ex.Message}");
                    }
                }

                // Clear clipboard
                _excelApp.CutCopyMode = XlCutCopyMode.xlCopy;
                
                // Save destination file
                destWorkbook.Save();
                
                result.Success = true;
                result.ProcessedCount = processedCount;
                result.T2020Count = t2020Count;
                result.Message = $"Successfully mapped {processedCount} fields ({t2020Count} marked for T2020)";
                
                Logger.Info("ExcelComService", result.Message);
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelComService", "Mapping execution failed", ex);
                result.ErrorMessage = $"Mapping failed: {ex.Message}";
            }
            finally
            {
                // Clean up COM objects
                if (sourceWorksheet != null) Marshal.ReleaseComObject(sourceWorksheet);
                if (destWorksheet != null) Marshal.ReleaseComObject(destWorksheet);
                
                if (sourceWorkbook != null)
                {
                    sourceWorkbook.Close(false);
                    Marshal.ReleaseComObject(sourceWorkbook);
                }
                
                if (destWorkbook != null)
                {
                    destWorkbook.Close(true); // Save changes
                    Marshal.ReleaseComObject(destWorkbook);
                }
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
                
                Logger.Info("ExcelComService", result.Message);
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelComService", "Text export failed", ex);
                result.ErrorMessage = $"Export failed: {ex.Message}";
            }
            
            Logger.TraceExit($"Success={result.Success}");
            return result;
        }

        private void EnsureExcelApp()
        {
            if (_excelApp == null)
            {
                _excelApp = new Microsoft.Office.Interop.Excel.Application
                {
                    Visible = false,
                    DisplayAlerts = false,
                    ScreenUpdating = false
                };
                
                Logger.Info("ExcelComService", "Excel COM application initialized");
            }
        }

        private Worksheet? FindWorksheet(Workbook workbook, string sheetName)
        {
            try
            {
                return (Worksheet)workbook.Worksheets[sheetName];
            }
            catch
            {
                return null;
            }
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                Logger.TraceEnter();
                
                if (_excelApp != null)
                {
                    try
                    {
                        _excelApp.Quit();
                        Marshal.ReleaseComObject(_excelApp);
                        _excelApp = null;
                        Logger.Info("ExcelComService", "Excel COM application disposed");
                    }
                    catch (Exception ex)
                    {
                        Logger.Error("ExcelComService", $"Error disposing Excel COM application: {ex.Message}");
                    }
                }
                
                _disposed = true;
                Logger.TraceExit();
            }
        }
    }
}