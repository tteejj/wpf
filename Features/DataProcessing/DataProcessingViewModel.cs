using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Input;
using Microsoft.Win32;
using PraxisWpf.Commands;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Features.DataProcessing
{
    public class DataProcessingViewModel : INotifyPropertyChanged
    {
        private readonly ProjectDataService _projectDataService;
        private ProjectDataItem? _selectedProject;
        private string _selectedProjectId = string.Empty;
        private string _excelFilePath = string.Empty;
        private string _integrationLog = string.Empty;
        private string _statusMessage = "Ready";

        public DataProcessingViewModel()
        {
            Logger.TraceEnter();
            
            try
            {
                _projectDataService = new ProjectDataService();

                ProjectIds = new ObservableCollection<string>();
                ProjectDataFields = new ObservableCollection<ProjectDataField>();

                ImportExcelCommand = new RelayCommand(async () => await ImportExcelAsync());
                SyncProjectDataCommand = new RelayCommand(async () => await SyncProjectDataAsync());
                ExportDataCommand = new RelayCommand(async () => await ExportDataAsync());
                BrowseExcelFileCommand = new RelayCommand(() => BrowseExcelFile());

                StatusMessage = "Data Processing ready - No PowerShell dependencies required";
                
                // Load project IDs synchronously - async was causing hangs
                LoadProjectIds();
                
                Logger.Info("DataProcessingViewModel", "DataProcessingViewModel initialized successfully");
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", $"Failed to initialize DataProcessingViewModel: {ex.Message}");
                StatusMessage = $"Initialization error: {ex.Message}";
            }
            
            Logger.TraceExit();
        }

        public ObservableCollection<string> ProjectIds { get; }
        public ObservableCollection<ProjectDataField> ProjectDataFields { get; }

        public ProjectDataItem? SelectedProject
        {
            get => _selectedProject;
            set
            {
                _selectedProject = value;
                OnPropertyChanged(nameof(SelectedProject));
                OnPropertyChanged(nameof(HasSelectedProject));
                UpdateProjectDataFields();
            }
        }

        public string SelectedProjectId
        {
            get => _selectedProjectId;
            set
            {
                _selectedProjectId = value;
                OnPropertyChanged(nameof(SelectedProjectId));
                _ = LoadSelectedProjectAsync(); // Fire-and-forget
            }
        }

        public string ExcelFilePath
        {
            get => _excelFilePath;
            set
            {
                _excelFilePath = value;
                OnPropertyChanged(nameof(ExcelFilePath));
            }
        }

        public string IntegrationLog
        {
            get => _integrationLog;
            set
            {
                _integrationLog = value;
                OnPropertyChanged(nameof(IntegrationLog));
            }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set
            {
                _statusMessage = value;
                OnPropertyChanged(nameof(StatusMessage));
                Logger.Info("DataProcessingViewModel", $"Status: {value}");
            }
        }

        public bool HasSelectedProject => SelectedProject != null;
        public bool HasProjects => ProjectIds.Count > 0;

        public ICommand ImportExcelCommand { get; }
        public ICommand SyncProjectDataCommand { get; }
        public ICommand ExportDataCommand { get; }
        public ICommand BrowseExcelFileCommand { get; }

        private void LoadProjectIds()
        {
            Logger.TraceEnter();
            
            try
            {
                var projectData = _projectDataService.GetAllProjectData();
                ProjectIds.Clear();
                
                foreach (var project in projectData)
                {
                    ProjectIds.Add(project.ProjectId);
                }

                OnPropertyChanged(nameof(HasProjects));
                
                Logger.Info("DataProcessingViewModel", $"Loaded {ProjectIds.Count} project IDs");
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", $"Failed to load project IDs: {ex.Message}");
                StatusMessage = $"Error loading projects: {ex.Message}";
            }
            
            Logger.TraceExit();
        }

        private async Task LoadProjectIdsAsync()
        {
            Logger.TraceEnter();
            
            try
            {
                Logger.Debug("DataProcessingViewModel", "LoadProjectIdsAsync - Starting project data retrieval");
                
                var projectData = _projectDataService.GetAllProjectData();
                
                Logger.Debug("DataProcessingViewModel", $"LoadProjectIdsAsync - Retrieved {projectData.Count()} projects, updating UI");
                
                // Update UI on main thread - but check if dispatcher is available
                if (System.Windows.Application.Current?.Dispatcher != null)
                {
                    System.Windows.Application.Current.Dispatcher.Invoke(() =>
                    {
                        try
                        {
                            Logger.Debug("DataProcessingViewModel", "LoadProjectIdsAsync - Clearing ProjectIds");
                            ProjectIds.Clear();
                            
                            Logger.Debug("DataProcessingViewModel", "LoadProjectIdsAsync - Adding projects to collection");
                            foreach (var project in projectData)
                            {
                                ProjectIds.Add(project.ProjectId);
                            }

                            OnPropertyChanged(nameof(HasProjects));
                            StatusMessage = $"Loaded {ProjectIds.Count} projects";
                            
                            Logger.Info("DataProcessingViewModel", $"LoadProjectIdsAsync - Successfully loaded {ProjectIds.Count} project IDs");
                        }
                        catch (Exception ex)
                        {
                            Logger.Error("DataProcessingViewModel", $"LoadProjectIdsAsync - UI update failed: {ex.Message}");
                            StatusMessage = $"Error updating UI: {ex.Message}";
                        }
                    });
                }
                else
                {
                    Logger.Warning("DataProcessingViewModel", "LoadProjectIdsAsync - No dispatcher available, updating directly");
                    StatusMessage = "Loaded projects (no dispatcher)";
                }
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", $"LoadProjectIdsAsync failed: {ex.Message}");
                
                if (System.Windows.Application.Current?.Dispatcher != null)
                {
                    try
                    {
                        System.Windows.Application.Current.Dispatcher.Invoke(() =>
                        {
                            StatusMessage = $"Error loading projects: {ex.Message}";
                        });
                    }
                    catch (Exception dispatcherEx)
                    {
                        Logger.Error("DataProcessingViewModel", $"LoadProjectIdsAsync - Dispatcher invoke failed: {dispatcherEx.Message}");
                    }
                }
            }
            
            Logger.TraceExit();
        }

        private async Task LoadSelectedProjectAsync()
        {
            if (string.IsNullOrEmpty(SelectedProjectId))
            {
                SelectedProject = null;
                return;
            }

            Logger.TraceEnter($"projectId={SelectedProjectId}");
            StatusMessage = $"Loading project data for {SelectedProjectId}...";

            try
            {
                var projectData = await _projectDataService.GetProjectDataAsync(SelectedProjectId);
                SelectedProject = projectData;
                
                StatusMessage = projectData != null 
                    ? $"Loaded project: {SelectedProjectId}" 
                    : $"No data found for project: {SelectedProjectId}";
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", $"Error loading project: {ex.Message}");
                StatusMessage = $"Error loading project: {ex.Message}";
                SelectedProject = null;
            }

            Logger.TraceExit();
        }

        private void UpdateProjectDataFields()
        {
            ProjectDataFields.Clear();

            if (SelectedProject == null) return;

            Logger.TraceEnter();

            var fields = new List<ProjectDataField>
            {
                new("Request Date", SelectedProject.RequestDate, value => SelectedProject.RequestDate = value),
                new("Audit Type", SelectedProject.AuditType, value => SelectedProject.AuditType = value),
                new("Auditor Name", SelectedProject.AuditorName, value => SelectedProject.AuditorName = value),
                new("TP Name", SelectedProject.TPName, value => SelectedProject.TPName = value),
                new("TP Email", SelectedProject.TPEmailAddress, value => SelectedProject.TPEmailAddress = value),
                new("TP Phone", SelectedProject.TPPhoneNumber, value => SelectedProject.TPPhoneNumber = value),
                new("Corporate Contact", SelectedProject.CorporateContact, value => SelectedProject.CorporateContact = value),
                new("Corporate Email", SelectedProject.CorporateContactEmail, value => SelectedProject.CorporateContactEmail = value),
                new("Corporate Phone", SelectedProject.CorporateContactPhone, value => SelectedProject.CorporateContactPhone = value),
                new("Site Name", SelectedProject.SiteName, value => SelectedProject.SiteName = value),
                new("Site Address", SelectedProject.SiteAddress, value => SelectedProject.SiteAddress = value),
                new("Site City", SelectedProject.SiteCity, value => SelectedProject.SiteCity = value),
                new("Site State", SelectedProject.SiteState, value => SelectedProject.SiteState = value),
                new("Site Zip", SelectedProject.SiteZip, value => SelectedProject.SiteZip = value),
                new("Site Country", SelectedProject.SiteCountry, value => SelectedProject.SiteCountry = value),
                new("Attention Contact", SelectedProject.AttentionContact, value => SelectedProject.AttentionContact = value),
                new("Attention Email", SelectedProject.AttentionContactEmail, value => SelectedProject.AttentionContactEmail = value),
                new("Attention Phone", SelectedProject.AttentionContactPhone, value => SelectedProject.AttentionContactPhone = value),
                new("Tax ID", SelectedProject.TaxID, value => SelectedProject.TaxID = value),
                new("DUNS", SelectedProject.DUNS, value => SelectedProject.DUNS = value),
                new("CAS Number", SelectedProject.CASNumber, value => SelectedProject.CASNumber = value),
                new("Asset Name", SelectedProject.AssetName, value => SelectedProject.AssetName = value),
                new("Serial Number", SelectedProject.SerialNumber, value => SelectedProject.SerialNumber = value),
                new("Model Number", SelectedProject.ModelNumber, value => SelectedProject.ModelNumber = value),
                new("Manufacturer", SelectedProject.ManufacturerName, value => SelectedProject.ManufacturerName = value),
                new("Install Date", SelectedProject.InstallDate, value => SelectedProject.InstallDate = value),
                new("Capacity", SelectedProject.Capacity, value => SelectedProject.Capacity = value),
                new("Capacity Unit", SelectedProject.CapacityUnit, value => SelectedProject.CapacityUnit = value),
                new("Tank Type", SelectedProject.TankType, value => SelectedProject.TankType = value),
                new("Product", SelectedProject.Product, value => SelectedProject.Product = value),
                new("Leak Detection", SelectedProject.LeakDetection, value => SelectedProject.LeakDetection = value),
                new("Piping", SelectedProject.Piping, value => SelectedProject.Piping = value),
                new("Monitoring", SelectedProject.Monitoring, value => SelectedProject.Monitoring = value),
                new("Status", SelectedProject.Status, value => SelectedProject.Status = value),
                new("Comments", SelectedProject.Comments, value => SelectedProject.Comments = value),
                new("Compliance Date", SelectedProject.ComplianceDate, value => SelectedProject.ComplianceDate = value),
                new("Next Inspection", SelectedProject.NextInspectionDate, value => SelectedProject.NextInspectionDate = value),
                new("Cert Number", SelectedProject.CertificationNumber, value => SelectedProject.CertificationNumber = value),
                new("Inspector Name", SelectedProject.InspectorName, value => SelectedProject.InspectorName = value),
                new("Inspector License", SelectedProject.InspectorLicense, value => SelectedProject.InspectorLicense = value)
            };

            foreach (var field in fields)
            {
                ProjectDataFields.Add(field);
            }

            Logger.Info("DataProcessingViewModel", $"Updated {ProjectDataFields.Count} project data fields");
            Logger.TraceExit();
        }

        private async System.Threading.Tasks.Task ImportExcelAsync()
        {
            if (string.IsNullOrEmpty(ExcelFilePath) || !File.Exists(ExcelFilePath))
            {
                StatusMessage = "Please select a valid Excel file";
                return;
            }

            Logger.TraceEnter($"excelFilePath={ExcelFilePath}");
            StatusMessage = "Importing Excel data...";
            AppendToLog("Starting Excel import...");

            try
            {
                var projectId = $"Project_{DateTime.Now:yyyyMMdd_HHmmss}";
                var importedProject = await _projectDataService.ImportProjectFromExcelAsync(ExcelFilePath, projectId);
                
                if (importedProject != null)
                {
                    ProjectIds.Add(projectId);
                    SelectedProjectId = projectId;
                    
                    StatusMessage = $"Successfully imported project: {projectId}";
                    AppendToLog($"Import completed successfully for project: {projectId}");
                    AppendToLog($"Site Name: {importedProject.SiteName}");
                    AppendToLog($"Request Date: {importedProject.RequestDate}");
                }
                else
                {
                    StatusMessage = "Failed to import Excel data";
                    AppendToLog("Import failed - no data extracted");
                }

                OnPropertyChanged(nameof(HasProjects));
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", $"Import failed: {ex.Message}");
                StatusMessage = $"Import failed: {ex.Message}";
                AppendToLog($"Import error: {ex.Message}");
            }

            Logger.TraceExit();
        }

        private async System.Threading.Tasks.Task SyncProjectDataAsync()
        {
            if (string.IsNullOrEmpty(SelectedProjectId) || string.IsNullOrEmpty(ExcelFilePath))
            {
                StatusMessage = "Please select a project and Excel file";
                return;
            }

            Logger.TraceEnter($"projectId={SelectedProjectId}");
            StatusMessage = "Syncing project data...";
            AppendToLog($"Starting sync for project: {SelectedProjectId}");

            try
            {
                var success = await _projectDataService.SyncProjectDataAsync(SelectedProjectId, ExcelFilePath);
                
                if (success)
                {
                    await LoadSelectedProjectAsync();
                    StatusMessage = "Project data synced successfully";
                    AppendToLog("Sync completed successfully");
                }
                else
                {
                    StatusMessage = "Failed to sync project data";
                    AppendToLog("Sync failed");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", $"Sync failed: {ex.Message}");
                StatusMessage = $"Sync failed: {ex.Message}";
                AppendToLog($"Sync error: {ex.Message}");
            }

            Logger.TraceExit();
        }

        private async System.Threading.Tasks.Task ExportDataAsync()
        {
            if (string.IsNullOrEmpty(SelectedProjectId))
            {
                StatusMessage = "Please select a project to export";
                return;
            }

            Logger.TraceEnter($"projectId={SelectedProjectId}");

            var saveDialog = new SaveFileDialog
            {
                Filter = "CSV Files (*.csv)|*.csv|JSON Files (*.json)|*.json|All Files (*.*)|*.*",
                DefaultExt = "csv",
                FileName = $"{SelectedProjectId}_export_{DateTime.Now:yyyyMMdd_HHmmss}"
            };

            if (saveDialog.ShowDialog() == true)
            {
                StatusMessage = "Exporting project data...";
                AppendToLog($"Starting export to: {saveDialog.FileName}");

                try
                {
                    var success = await _projectDataService.ExportProjectDataAsync(
                        SelectedProjectId, 
                        saveDialog.FileName, 
                        Path.GetExtension(saveDialog.FileName).ToUpper().Replace(".", ""));
                    
                    if (success)
                    {
                        StatusMessage = $"Export completed: {saveDialog.FileName}";
                        AppendToLog("Export completed successfully");
                    }
                    else
                    {
                        StatusMessage = "Export failed";
                        AppendToLog("Export failed");
                    }
                }
                catch (Exception ex)
                {
                    Logger.Error("DataProcessingViewModel", $"Export failed: {ex.Message}");
                    StatusMessage = $"Export failed: {ex.Message}";
                    AppendToLog($"Export error: {ex.Message}");
                }
            }

            Logger.TraceExit();
        }

        private void BrowseExcelFile()
        {
            var openDialog = new OpenFileDialog
            {
                Filter = "Excel Files (*.xlsx;*.xls)|*.xlsx;*.xls|All Files (*.*)|*.*",
                DefaultExt = "xlsx"
            };

            if (openDialog.ShowDialog() == true)
            {
                ExcelFilePath = openDialog.FileName;
                StatusMessage = $"Selected Excel file: {Path.GetFileName(ExcelFilePath)}";
                AppendToLog($"Selected file: {ExcelFilePath}");
            }
        }

        private void AppendToLog(string message)
        {
            var timestamp = DateTime.Now.ToString("HH:mm:ss");
            IntegrationLog += $"[{timestamp}] {message}\n";
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    public class ProjectDataField : INotifyPropertyChanged
    {
        private string _value;
        private readonly Action<string> _updateAction;

        public ProjectDataField(string key, string value, Action<string> updateAction)
        {
            Key = key;
            _value = value ?? string.Empty;
            _updateAction = updateAction;
        }

        public string Key { get; }

        public string Value
        {
            get => _value;
            set
            {
                _value = value;
                _updateAction(value);
                OnPropertyChanged(nameof(Value));
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}