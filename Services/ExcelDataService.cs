using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using ClosedXML.Excel;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    public class ExcelDataService
    {
        private readonly ProjectDataService _projectDataService;

        public ExcelDataService(ProjectDataService projectDataService)
        {
            _projectDataService = projectDataService;
        }

        /// <summary>
        /// Import project data from an Excel file
        /// </summary>
        public async Task<ExcelImportResult> ImportFromExcelAsync(string filePath)
        {
            var result = new ExcelImportResult();
            
            try
            {
                if (!File.Exists(filePath))
                {
                    result.ErrorMessage = "Excel file not found";
                    return result;
                }

                using var workbook = new XLWorkbook(filePath);
                var worksheet = workbook.Worksheets.FirstOrDefault();
                
                if (worksheet == null)
                {
                    result.ErrorMessage = "No worksheets found in Excel file";
                    return result;
                }

                var projects = new List<ProjectDataItem>();
                var headerRow = FindHeaderRow(worksheet);
                
                if (headerRow == 0)
                {
                    result.ErrorMessage = "No valid header row found in Excel file";
                    return result;
                }

                var columnMappings = CreateColumnMappings(worksheet, headerRow);
                var dataRows = worksheet.RowsUsed().Skip(headerRow);

                foreach (var row in dataRows)
                {
                    try
                    {
                        var project = ExtractProjectFromRow(row, columnMappings);
                        if (project != null && !string.IsNullOrEmpty(project.ProjectId))
                        {
                            projects.Add(project);
                        }
                    }
                    catch (Exception ex)
                    {
                        result.Warnings.Add($"Row {row.RowNumber()}: {ex.Message}");
                    }
                }

                // Save projects to data service
                foreach (var project in projects)
                {
                    try
                    {
                        // Use the correct method from ProjectDataService
                        _projectDataService.UpdateProjectData(project.ProjectId!, project);
                        result.ImportedProjects.Add(project);
                    }
                    catch (Exception ex)
                    {
                        result.Warnings.Add($"Failed to save project {project.ProjectId}: {ex.Message}");
                    }
                }

                result.Success = true;
                result.Message = $"Successfully imported {result.ImportedProjects.Count} projects";
                
                Logger.Info("ExcelDataService", $"Imported {result.ImportedProjects.Count} projects from {filePath}");
            }
            catch (Exception ex)
            {
                result.ErrorMessage = $"Failed to import Excel file: {ex.Message}";
                Logger.Error("ExcelDataService", $"Import failed: {ex.Message}");
            }

            return result;
        }

        /// <summary>
        /// Export project data to an Excel file
        /// </summary>
        public async Task<ExcelExportResult> ExportToExcelAsync(string filePath, List<string>? projectIds = null)
        {
            var result = new ExcelExportResult();
            
            try
            {
                var allProjects = _projectDataService.GetProjectDataDictionary();
                var projectsToExport = projectIds?.Any() == true 
                    ? allProjects.Where(p => projectIds.Contains(p.Key)).Select(p => p.Value).ToList()
                    : allProjects.Values.ToList();

                if (!projectsToExport.Any())
                {
                    result.ErrorMessage = "No projects found to export";
                    return result;
                }

                using var workbook = new XLWorkbook();
                var worksheet = workbook.Worksheets.Add("Project Data");

                // Create headers
                var headers = GetExportHeaders();
                for (int i = 0; i < headers.Length; i++)
                {
                    worksheet.Cell(1, i + 1).Value = headers[i];
                    worksheet.Cell(1, i + 1).Style.Font.Bold = true;
                    worksheet.Cell(1, i + 1).Style.Fill.BackgroundColor = XLColor.LightGray;
                }

                // Add data rows
                int rowIndex = 2;
                foreach (var project in projectsToExport)
                {
                    AddProjectToWorksheet(worksheet, project, rowIndex);
                    rowIndex++;
                }

                // Auto-fit columns
                worksheet.Columns().AdjustToContents();

                // Ensure directory exists
                var directory = Path.GetDirectoryName(filePath);
                if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                workbook.SaveAs(filePath);

                result.Success = true;
                result.ExportedCount = projectsToExport.Count();
                result.FilePath = filePath;
                result.Message = $"Successfully exported {projectsToExport.Count()} projects to {filePath}";
                
                Logger.Info("ExcelDataService", $"Exported {projectsToExport.Count()} projects to {filePath}");
            }
            catch (Exception ex)
            {
                result.ErrorMessage = $"Failed to export to Excel file: {ex.Message}";
                Logger.Error("ExcelDataService", $"Export failed: {ex.Message}");
            }

            return result;
        }

        /// <summary>
        /// Get a template Excel file for data entry
        /// </summary>
        public async Task<ExcelExportResult> CreateTemplateAsync(string filePath)
        {
            var result = new ExcelExportResult();
            
            try
            {
                using var workbook = new XLWorkbook();
                var worksheet = workbook.Worksheets.Add("Project Data Template");

                // Create headers
                var headers = GetExportHeaders();
                for (int i = 0; i < headers.Length; i++)
                {
                    worksheet.Cell(1, i + 1).Value = headers[i];
                    worksheet.Cell(1, i + 1).Style.Font.Bold = true;
                    worksheet.Cell(1, i + 1).Style.Fill.BackgroundColor = XLColor.LightBlue;
                    worksheet.Cell(1, i + 1).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
                }

                // Add sample data row
                var sampleProject = CreateSampleProject();
                AddProjectToWorksheet(worksheet, sampleProject, 2);

                // Format sample row differently
                var sampleRange = worksheet.Range($"A2:{worksheet.Cell(2, headers.Length).Address}");
                sampleRange.Style.Fill.BackgroundColor = XLColor.LightYellow;
                sampleRange.Style.Font.Italic = true;

                // Add instructions
                worksheet.Cell(4, 1).Value = "Instructions:";
                worksheet.Cell(4, 1).Style.Font.Bold = true;
                worksheet.Cell(5, 1).Value = "1. Replace the sample data in row 2 with your actual project data";
                worksheet.Cell(6, 1).Value = "2. Add additional rows as needed for more projects";
                worksheet.Cell(7, 1).Value = "3. ProjectId must be unique for each project";
                worksheet.Cell(8, 1).Value = "4. Save the file and use Import in the application";

                // Auto-fit columns
                worksheet.Columns().AdjustToContents();

                // Ensure directory exists
                var directory = Path.GetDirectoryName(filePath);
                if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                workbook.SaveAs(filePath);

                result.Success = true;
                result.FilePath = filePath;
                result.Message = $"Template created successfully at {filePath}";
                
                Logger.Info("ExcelDataService", $"Created template at {filePath}");
            }
            catch (Exception ex)
            {
                result.ErrorMessage = $"Failed to create template: {ex.Message}";
                Logger.Error("ExcelDataService", $"Template creation failed: {ex.Message}");
            }

            return result;
        }

        private int FindHeaderRow(IXLWorksheet worksheet)
        {
            // Look for a row that contains "ProjectId" or "Project ID"
            foreach (var row in worksheet.RowsUsed().Take(10)) // Check first 10 rows
            {
                foreach (var cell in row.CellsUsed())
                {
                    var value = cell.Value.ToString().ToLowerInvariant();
                    if (value.Contains("projectid") || value.Contains("project id") || value.Contains("project_id"))
                    {
                        return row.RowNumber();
                    }
                }
            }
            return 1; // Default to first row
        }

        private Dictionary<string, int> CreateColumnMappings(IXLWorksheet worksheet, int headerRow)
        {
            var mappings = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var headerRowData = worksheet.Row(headerRow);
            
            foreach (var cell in headerRowData.CellsUsed())
            {
                var header = cell.Value.ToString().Trim();
                if (!string.IsNullOrEmpty(header))
                {
                    // Normalize header names
                    var normalizedHeader = NormalizeHeader(header);
                    mappings[normalizedHeader] = cell.Address.ColumnNumber;
                }
            }

            return mappings;
        }

        private string NormalizeHeader(string header)
        {
            return header.ToLowerInvariant()
                         .Replace(" ", "")
                         .Replace("_", "")
                         .Replace("-", "");
        }

        private ProjectDataItem? ExtractProjectFromRow(IXLRow row, Dictionary<string, int> columnMappings)
        {
            var project = new ProjectDataItem();
            
            // Extract ProjectId first - it's required
            var projectId = GetCellValue(row, columnMappings, "projectid");
            if (string.IsNullOrEmpty(projectId))
            {
                return null;
            }
            project.ProjectId = projectId;

            // Extract all other fields
            project.RequestDate = GetCellValue(row, columnMappings, "requestdate");
            project.AuditType = GetCellValue(row, columnMappings, "audittype");
            project.AuditorName = GetCellValue(row, columnMappings, "auditorname");
            project.TPName = GetCellValue(row, columnMappings, "tpname");
            project.TPEmailAddress = GetCellValue(row, columnMappings, "tpemailaddress");
            project.TPPhoneNumber = GetCellValue(row, columnMappings, "tpphonenumber");
            project.CorporateContact = GetCellValue(row, columnMappings, "corporatecontact");
            project.CorporateContactEmail = GetCellValue(row, columnMappings, "corporatecontactemail");
            project.CorporateContactPhone = GetCellValue(row, columnMappings, "corporatecontactphone");
            project.SiteName = GetCellValue(row, columnMappings, "sitename");
            project.SiteAddress = GetCellValue(row, columnMappings, "siteaddress");
            project.SiteCity = GetCellValue(row, columnMappings, "sitecity");
            project.SiteState = GetCellValue(row, columnMappings, "sitestate");
            project.SiteZip = GetCellValue(row, columnMappings, "sitezip");
            project.SiteCountry = GetCellValue(row, columnMappings, "sitecountry");
            project.AttentionContact = GetCellValue(row, columnMappings, "attentioncontact");
            project.AttentionContactEmail = GetCellValue(row, columnMappings, "attentioncontactemail");
            project.AttentionContactPhone = GetCellValue(row, columnMappings, "attentioncontactphone");
            project.TaxID = GetCellValue(row, columnMappings, "taxid");
            project.DUNS = GetCellValue(row, columnMappings, "duns");
            project.CASNumber = GetCellValue(row, columnMappings, "casnumber");
            project.AssetName = GetCellValue(row, columnMappings, "assetname");
            project.SerialNumber = GetCellValue(row, columnMappings, "serialnumber");
            project.ModelNumber = GetCellValue(row, columnMappings, "modelnumber");
            project.ManufacturerName = GetCellValue(row, columnMappings, "manufacturername");
            project.InstallDate = GetCellValue(row, columnMappings, "installdate");
            project.Capacity = GetCellValue(row, columnMappings, "capacity");
            project.CapacityUnit = GetCellValue(row, columnMappings, "capacityunit");
            project.TankType = GetCellValue(row, columnMappings, "tanktype");
            project.Product = GetCellValue(row, columnMappings, "product");
            project.LeakDetection = GetCellValue(row, columnMappings, "leakdetection");
            project.Piping = GetCellValue(row, columnMappings, "piping");
            project.Monitoring = GetCellValue(row, columnMappings, "monitoring");
            project.Status = GetCellValue(row, columnMappings, "status");
            project.Comments = GetCellValue(row, columnMappings, "comments");
            project.ComplianceDate = GetCellValue(row, columnMappings, "compliancedate");
            project.NextInspectionDate = GetCellValue(row, columnMappings, "nextinspectiondate");
            project.CertificationNumber = GetCellValue(row, columnMappings, "certificationnumber");
            project.InspectorName = GetCellValue(row, columnMappings, "inspectorname");
            project.InspectorLicense = GetCellValue(row, columnMappings, "inspectorlicense");

            return project;
        }

        private string GetCellValue(IXLRow row, Dictionary<string, int> columnMappings, string fieldName)
        {
            if (columnMappings.TryGetValue(fieldName, out var columnIndex))
            {
                return row.Cell(columnIndex).Value.ToString().Trim();
            }
            return string.Empty;
        }

        private string[] GetExportHeaders()
        {
            return new[]
            {
                "ProjectId", "RequestDate", "AuditType", "AuditorName", "TPName", "TPEmailAddress", "TPPhoneNumber",
                "CorporateContact", "CorporateContactEmail", "CorporateContactPhone", "SiteName", "SiteAddress",
                "SiteCity", "SiteState", "SiteZip", "SiteCountry", "AttentionContact", "AttentionContactEmail",
                "AttentionContactPhone", "TaxID", "DUNS", "CASNumber", "AssetName", "SerialNumber", "ModelNumber",
                "ManufacturerName", "InstallDate", "Capacity", "CapacityUnit", "TankType", "Product",
                "LeakDetection", "Piping", "Monitoring", "Status", "Comments", "ComplianceDate",
                "NextInspectionDate", "CertificationNumber", "InspectorName", "InspectorLicense"
            };
        }

        private void AddProjectToWorksheet(IXLWorksheet worksheet, ProjectDataItem project, int rowIndex)
        {
            worksheet.Cell(rowIndex, 1).Value = project.ProjectId;
            worksheet.Cell(rowIndex, 2).Value = project.RequestDate;
            worksheet.Cell(rowIndex, 3).Value = project.AuditType;
            worksheet.Cell(rowIndex, 4).Value = project.AuditorName;
            worksheet.Cell(rowIndex, 5).Value = project.TPName;
            worksheet.Cell(rowIndex, 6).Value = project.TPEmailAddress;
            worksheet.Cell(rowIndex, 7).Value = project.TPPhoneNumber;
            worksheet.Cell(rowIndex, 8).Value = project.CorporateContact;
            worksheet.Cell(rowIndex, 9).Value = project.CorporateContactEmail;
            worksheet.Cell(rowIndex, 10).Value = project.CorporateContactPhone;
            worksheet.Cell(rowIndex, 11).Value = project.SiteName;
            worksheet.Cell(rowIndex, 12).Value = project.SiteAddress;
            worksheet.Cell(rowIndex, 13).Value = project.SiteCity;
            worksheet.Cell(rowIndex, 14).Value = project.SiteState;
            worksheet.Cell(rowIndex, 15).Value = project.SiteZip;
            worksheet.Cell(rowIndex, 16).Value = project.SiteCountry;
            worksheet.Cell(rowIndex, 17).Value = project.AttentionContact;
            worksheet.Cell(rowIndex, 18).Value = project.AttentionContactEmail;
            worksheet.Cell(rowIndex, 19).Value = project.AttentionContactPhone;
            worksheet.Cell(rowIndex, 20).Value = project.TaxID;
            worksheet.Cell(rowIndex, 21).Value = project.DUNS;
            worksheet.Cell(rowIndex, 22).Value = project.CASNumber;
            worksheet.Cell(rowIndex, 23).Value = project.AssetName;
            worksheet.Cell(rowIndex, 24).Value = project.SerialNumber;
            worksheet.Cell(rowIndex, 25).Value = project.ModelNumber;
            worksheet.Cell(rowIndex, 26).Value = project.ManufacturerName;
            worksheet.Cell(rowIndex, 27).Value = project.InstallDate;
            worksheet.Cell(rowIndex, 28).Value = project.Capacity;
            worksheet.Cell(rowIndex, 29).Value = project.CapacityUnit;
            worksheet.Cell(rowIndex, 30).Value = project.TankType;
            worksheet.Cell(rowIndex, 31).Value = project.Product;
            worksheet.Cell(rowIndex, 32).Value = project.LeakDetection;
            worksheet.Cell(rowIndex, 33).Value = project.Piping;
            worksheet.Cell(rowIndex, 34).Value = project.Monitoring;
            worksheet.Cell(rowIndex, 35).Value = project.Status;
            worksheet.Cell(rowIndex, 36).Value = project.Comments;
            worksheet.Cell(rowIndex, 37).Value = project.ComplianceDate;
            worksheet.Cell(rowIndex, 38).Value = project.NextInspectionDate;
            worksheet.Cell(rowIndex, 39).Value = project.CertificationNumber;
            worksheet.Cell(rowIndex, 40).Value = project.InspectorName;
            worksheet.Cell(rowIndex, 41).Value = project.InspectorLicense;
        }

        private ProjectDataItem CreateSampleProject()
        {
            return new ProjectDataItem
            {
                ProjectId = "SAMPLE_001",
                RequestDate = DateTime.Now.ToString("yyyy-MM-dd"),
                AuditType = "Environmental Compliance",
                AuditorName = "John Doe",
                TPName = "ABC Third Party",
                TPEmailAddress = "contact@abctp.com",
                TPPhoneNumber = "555-123-4567",
                SiteName = "Sample Facility",
                SiteAddress = "123 Main Street",
                SiteCity = "Anytown",
                SiteState = "ST",
                SiteZip = "12345",
                SiteCountry = "USA",
                Status = "Active",
                Comments = "This is sample data - replace with actual values"
            };
        }
    }

    public class ExcelImportResult
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public List<ProjectDataItem> ImportedProjects { get; set; } = new();
        public List<string> Warnings { get; set; } = new();
    }

    public class ExcelExportResult
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public string FilePath { get; set; } = string.Empty;
        public int ExportedCount { get; set; }
    }
}