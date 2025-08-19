using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class ExcelIntegrationService
    {
        private readonly string _tempScriptPath;

        public ExcelIntegrationService()
        {
            _tempScriptPath = Path.Combine(Path.GetTempPath(), "ExcelDataFlow");
            Directory.CreateDirectory(_tempScriptPath);
        }

        public async Task<bool> ExtractScriptsFromResourcesAsync()
        {
            try
            {
                var assembly = Assembly.GetExecutingAssembly();
                var resourceNames = assembly.GetManifestResourceNames();

                foreach (var resourceName in resourceNames)
                {
                    if (resourceName.Contains("ExcelDataFlow") && resourceName.EndsWith(".ps1"))
                    {
                        using var stream = assembly.GetManifestResourceStream(resourceName);
                        if (stream != null)
                        {
                            var fileName = Path.GetFileName(resourceName.Replace("PraxisWpf.Resources.ExcelDataFlow.", ""));
                            var filePath = Path.Combine(_tempScriptPath, fileName);
                            
                            using var fileStream = File.Create(filePath);
                            await stream.CopyToAsync(fileStream);
                            
                            Logger.Info("ExcelIntegrationService", $"Extracted script: {fileName}");
                        }
                    }
                }

                return true;
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelIntegrationService", $"Failed to extract scripts: {ex.Message}");
                return false;
            }
        }

        public async Task<ProcessResult> RunExcelExtractionAsync(string sourceExcelFile, string configPath)
        {
            try
            {
                await ExtractScriptsFromResourcesAsync();

                var startScript = Path.Combine(_tempScriptPath, "Start.ps1");
                if (!File.Exists(startScript))
                {
                    return new ProcessResult 
                    { 
                        Success = false, 
                        ErrorMessage = "Excel extraction script not found" 
                    };
                }

                var processInfo = new ProcessStartInfo
                {
                    FileName = "pwsh",
                    Arguments = $"-File \"{startScript}\" -ConfigPath \"{configPath}\" -SourceFile \"{sourceExcelFile}\"",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var process = new Process { StartInfo = processInfo };
                
                var outputBuilder = new StringBuilder();
                var errorBuilder = new StringBuilder();

                process.OutputDataReceived += (sender, e) => 
                {
                    if (!string.IsNullOrEmpty(e.Data))
                        outputBuilder.AppendLine(e.Data);
                };

                process.ErrorDataReceived += (sender, e) => 
                {
                    if (!string.IsNullOrEmpty(e.Data))
                        errorBuilder.AppendLine(e.Data);
                };

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                await process.WaitForExitAsync();

                var result = new ProcessResult
                {
                    Success = process.ExitCode == 0,
                    Output = outputBuilder.ToString(),
                    ErrorMessage = errorBuilder.ToString(),
                    ExitCode = process.ExitCode
                };

                Logger.Info("ExcelIntegrationService", 
                    $"Excel extraction completed with exit code: {process.ExitCode}");

                return result;
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelIntegrationService", $"Excel extraction failed: {ex.Message}");
                return new ProcessResult 
                { 
                    Success = false, 
                    ErrorMessage = ex.Message 
                };
            }
        }

        public async Task<ProcessResult> RunDataExportAsync(string profileName, string outputPath)
        {
            try
            {
                await ExtractScriptsFromResourcesAsync();

                var exportScript = Path.Combine(_tempScriptPath, "RunProfileExport.ps1");
                if (!File.Exists(exportScript))
                {
                    return new ProcessResult 
                    { 
                        Success = false, 
                        ErrorMessage = "Export script not found" 
                    };
                }

                var processInfo = new ProcessStartInfo
                {
                    FileName = "pwsh",
                    Arguments = $"-File \"{exportScript}\" -ProfileName \"{profileName}\" -OutputPath \"{outputPath}\"",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var process = new Process { StartInfo = processInfo };
                
                var outputBuilder = new StringBuilder();
                var errorBuilder = new StringBuilder();

                process.OutputDataReceived += (sender, e) => 
                {
                    if (!string.IsNullOrEmpty(e.Data))
                        outputBuilder.AppendLine(e.Data);
                };

                process.ErrorDataReceived += (sender, e) => 
                {
                    if (!string.IsNullOrEmpty(e.Data))
                        errorBuilder.AppendLine(e.Data);
                };

                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                await process.WaitForExitAsync();

                var result = new ProcessResult
                {
                    Success = process.ExitCode == 0,
                    Output = outputBuilder.ToString(),
                    ErrorMessage = errorBuilder.ToString(),
                    ExitCode = process.ExitCode
                };

                Logger.Info("ExcelIntegrationService", 
                    $"Data export completed with exit code: {process.ExitCode}");

                return result;
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelIntegrationService", $"Data export failed: {ex.Message}");
                return new ProcessResult 
                { 
                    Success = false, 
                    ErrorMessage = ex.Message 
                };
            }
        }

        public async Task<ProjectDataItem?> ParseExtractedDataAsync(string outputPath)
        {
            try
            {
                if (!File.Exists(outputPath))
                    return null;

                var jsonContent = await File.ReadAllTextAsync(outputPath);
                var extractedData = JsonSerializer.Deserialize<Dictionary<string, string>>(jsonContent);
                
                if (extractedData == null)
                    return null;

                var projectData = new ProjectDataItem();

                // Map all 40 fields from the extracted data
                if (extractedData.TryGetValue("RequestDate", out var requestDate))
                    projectData.RequestDate = requestDate;
                if (extractedData.TryGetValue("AuditType", out var auditType))
                    projectData.AuditType = auditType;
                if (extractedData.TryGetValue("AuditorName", out var auditorName))
                    projectData.AuditorName = auditorName;
                if (extractedData.TryGetValue("TPName", out var tpName))
                    projectData.TPName = tpName;
                if (extractedData.TryGetValue("TPEmailAddress", out var tpEmail))
                    projectData.TPEmailAddress = tpEmail;
                if (extractedData.TryGetValue("TPPhoneNumber", out var tpPhone))
                    projectData.TPPhoneNumber = tpPhone;
                if (extractedData.TryGetValue("CorporateContact", out var corpContact))
                    projectData.CorporateContact = corpContact;
                if (extractedData.TryGetValue("CorporateContactEmail", out var corpEmail))
                    projectData.CorporateContactEmail = corpEmail;
                if (extractedData.TryGetValue("CorporateContactPhone", out var corpPhone))
                    projectData.CorporateContactPhone = corpPhone;
                if (extractedData.TryGetValue("SiteName", out var siteName))
                    projectData.SiteName = siteName;
                if (extractedData.TryGetValue("SiteAddress", out var siteAddress))
                    projectData.SiteAddress = siteAddress;
                if (extractedData.TryGetValue("SiteCity", out var siteCity))
                    projectData.SiteCity = siteCity;
                if (extractedData.TryGetValue("SiteState", out var siteState))
                    projectData.SiteState = siteState;
                if (extractedData.TryGetValue("SiteZip", out var siteZip))
                    projectData.SiteZip = siteZip;
                if (extractedData.TryGetValue("SiteCountry", out var siteCountry))
                    projectData.SiteCountry = siteCountry;
                if (extractedData.TryGetValue("AttentionContact", out var attnContact))
                    projectData.AttentionContact = attnContact;
                if (extractedData.TryGetValue("AttentionContactEmail", out var attnEmail))
                    projectData.AttentionContactEmail = attnEmail;
                if (extractedData.TryGetValue("AttentionContactPhone", out var attnPhone))
                    projectData.AttentionContactPhone = attnPhone;
                if (extractedData.TryGetValue("TaxID", out var taxId))
                    projectData.TaxID = taxId;
                if (extractedData.TryGetValue("DUNS", out var duns))
                    projectData.DUNS = duns;
                if (extractedData.TryGetValue("CASNumber", out var casNumber))
                    projectData.CASNumber = casNumber;
                if (extractedData.TryGetValue("AssetName", out var assetName))
                    projectData.AssetName = assetName;
                if (extractedData.TryGetValue("SerialNumber", out var serialNumber))
                    projectData.SerialNumber = serialNumber;
                if (extractedData.TryGetValue("ModelNumber", out var modelNumber))
                    projectData.ModelNumber = modelNumber;
                if (extractedData.TryGetValue("ManufacturerName", out var manufacturer))
                    projectData.ManufacturerName = manufacturer;
                if (extractedData.TryGetValue("InstallDate", out var installDate))
                    projectData.InstallDate = installDate;
                if (extractedData.TryGetValue("Capacity", out var capacity))
                    projectData.Capacity = capacity;
                if (extractedData.TryGetValue("CapacityUnit", out var capacityUnit))
                    projectData.CapacityUnit = capacityUnit;
                if (extractedData.TryGetValue("TankType", out var tankType))
                    projectData.TankType = tankType;
                if (extractedData.TryGetValue("Product", out var product))
                    projectData.Product = product;
                if (extractedData.TryGetValue("LeakDetection", out var leakDetection))
                    projectData.LeakDetection = leakDetection;
                if (extractedData.TryGetValue("Piping", out var piping))
                    projectData.Piping = piping;
                if (extractedData.TryGetValue("Monitoring", out var monitoring))
                    projectData.Monitoring = monitoring;
                if (extractedData.TryGetValue("Status", out var status))
                    projectData.Status = status;
                if (extractedData.TryGetValue("Comments", out var comments))
                    projectData.Comments = comments;
                if (extractedData.TryGetValue("ComplianceDate", out var complianceDate))
                    projectData.ComplianceDate = complianceDate;
                if (extractedData.TryGetValue("NextInspectionDate", out var inspectionDate))
                    projectData.NextInspectionDate = inspectionDate;
                if (extractedData.TryGetValue("CertificationNumber", out var certNumber))
                    projectData.CertificationNumber = certNumber;
                if (extractedData.TryGetValue("InspectorName", out var inspectorName))
                    projectData.InspectorName = inspectorName;
                if (extractedData.TryGetValue("InspectorLicense", out var inspectorLicense))
                    projectData.InspectorLicense = inspectorLicense;

                Logger.Info("ExcelIntegrationService", 
                    $"Successfully parsed project data for site: {projectData.SiteName}");

                return projectData;
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelIntegrationService", $"Failed to parse extracted data: {ex.Message}");
                return null;
            }
        }

        public void Cleanup()
        {
            try
            {
                if (Directory.Exists(_tempScriptPath))
                {
                    Directory.Delete(_tempScriptPath, true);
                    Logger.Info("ExcelIntegrationService", "Cleaned up temporary script files");
                }
            }
            catch (Exception ex)
            {
                Logger.Warning("ExcelIntegrationService", $"Failed to cleanup temp files: {ex.Message}");
            }
        }
    }

    public class ProcessResult
    {
        public bool Success { get; set; }
        public string Output { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public int ExitCode { get; set; }
    }
}