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
        private readonly ExcelDataService _excelDataService;
        private readonly LoadingIndicatorService _loadingService;
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
                _excelDataService = new ExcelDataService(_projectDataService);
                _loadingService = new LoadingIndicatorService();

                ProjectIds = new ObservableCollection<string>();
                ProjectDataFields = new ObservableCollection<ProjectDataField>();

                ImportExcelCommand = new RelayCommand(async () => await ImportExcelAsync());
                SyncProjectDataCommand = new RelayCommand(async () => await SyncProjectDataAsync());
                ExportDataCommand = new RelayCommand(async () => await ExportDataAsync());
                BrowseExcelFileCommand = new RelayCommand(() => BrowseExcelFile());
                CreateTemplateCommand = new RelayCommand(async () => await CreateTemplateAsync());
                ExportAllProjectsCommand = new RelayCommand(async () => await ExportAllProjectsAsync());
                CreateProjectCommand = new RelayCommand(() => CreateNewProject());
                SaveProjectCommand = new RelayCommand(async () => await SaveProjectAsync(), () => HasSelectedProject);
                DeleteProjectCommand = new RelayCommand(async () => await DeleteProjectAsync(), () => HasSelectedProject);
                RefreshProjectsCommand = new RelayCommand(() => LoadProjectIds());
                OpenExcelMappingCommand = new RelayCommand(() => OpenExcelMappingDialog());

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
        public ICommand CreateTemplateCommand { get; }
        public ICommand ExportAllProjectsCommand { get; }
        public ICommand CreateProjectCommand { get; }
        public ICommand SaveProjectCommand { get; }
        public ICommand DeleteProjectCommand { get; }
        public ICommand RefreshProjectsCommand { get; }
        public ICommand OpenExcelMappingCommand { get; }

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
                new("Request Date", SelectedProject.RequestDate, value => SelectedProject.RequestDate = value, 
                    ValidateDateFormat, 10),
                new("Audit Type", SelectedProject.AuditType, value => SelectedProject.AuditType = value,
                    value => string.IsNullOrWhiteSpace(value) ? "Audit Type is required" : string.Empty, 11),
                new("Auditor Name", SelectedProject.AuditorName, value => SelectedProject.AuditorName = value,
                    value => string.IsNullOrWhiteSpace(value) ? "Auditor Name is required" : string.Empty, 12),
                new("TP Name", SelectedProject.TPName, value => SelectedProject.TPName = value, null, 13),
                new("TP Email", SelectedProject.TPEmailAddress, value => SelectedProject.TPEmailAddress = value,
                    ValidateEmail, 14),
                new("TP Phone", SelectedProject.TPPhoneNumber, value => SelectedProject.TPPhoneNumber = value,
                    ValidatePhoneNumber, 15),
                new("Corporate Contact", SelectedProject.CorporateContact, value => SelectedProject.CorporateContact = value, null, 16),
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

            try
            {
                var result = await _loadingService.ExecuteWithLoading(
                    async () => await _excelDataService.ImportFromExcelAsync(ExcelFilePath),
                    "Importing Excel data..."
                );

                if (result.Success)
                {
                    StatusMessage = result.Message;
                    AppendToLog($"Import completed: {result.ImportedProjects.Count} projects imported");
                    
                    // Refresh project list and select first imported project
                    LoadProjectIds();
                    if (result.ImportedProjects.Any())
                    {
                        SelectedProjectId = result.ImportedProjects.First().ProjectId ?? string.Empty;
                    }

                    // Log warnings if any
                    foreach (var warning in result.Warnings)
                    {
                        AppendToLog($"Warning: {warning}");
                    }
                }
                else
                {
                    StatusMessage = $"Import failed: {result.ErrorMessage}";
                    AppendToLog($"Import failed: {result.ErrorMessage}");
                }
                
                OnPropertyChanged(nameof(HasProjects));
            }
            catch (Exception ex)
            {
                StatusMessage = $"Import error: {ex.Message}";
                AppendToLog($"Import failed with error: {ex.Message}");
                Logger.Error("DataProcessingViewModel", $"ImportExcelAsync failed: {ex.Message}");
            }
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

            var saveDialog = new SaveFileDialog
            {
                Filter = "Excel Files (*.xlsx)|*.xlsx|CSV Files (*.csv)|*.csv|JSON Files (*.json)|*.json|All Files (*.*)|*.*",
                DefaultExt = "xlsx",
                FileName = $"{SelectedProjectId}_export_{DateTime.Now:yyyyMMdd_HHmmss}"
            };

            if (saveDialog.ShowDialog() == true)
            {
                try
                {
                    var fileExtension = Path.GetExtension(saveDialog.FileName).ToLowerInvariant();
                    
                    if (fileExtension == ".xlsx")
                    {
                        // Use new Excel export
                        var result = await _loadingService.ExecuteWithLoading(
                            async () => await _excelDataService.ExportToExcelAsync(saveDialog.FileName, new List<string> { SelectedProjectId }),
                            "Exporting to Excel..."
                        );

                        if (result.Success)
                        {
                            StatusMessage = result.Message;
                            AppendToLog($"Export completed: {result.ExportedCount} project(s) exported to Excel");
                        }
                        else
                        {
                            StatusMessage = $"Export failed: {result.ErrorMessage}";
                            AppendToLog($"Export failed: {result.ErrorMessage}");
                        }
                    }
                    else
                    {
                        // Use existing export for other formats
                        var success = await _projectDataService.ExportProjectDataAsync(
                            SelectedProjectId, 
                            saveDialog.FileName, 
                            fileExtension.Replace(".", "").ToUpper());
                        
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
                }
                catch (Exception ex)
                {
                    StatusMessage = $"Export failed: {ex.Message}";
                    AppendToLog($"Export error: {ex.Message}");
                    Logger.Error("DataProcessingViewModel", $"ExportDataAsync failed: {ex.Message}");
                }
            }
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

        private void OpenExcelMappingDialog()
        {
            Logger.TraceEnter();
            
            try
            {
                var dialog = new ExcelMappingDialog();
                dialog.Owner = System.Windows.Application.Current.MainWindow;
                
                var result = dialog.ShowDialog();
                
                if (result == true)
                {
                    StatusMessage = "Excel mapping completed successfully";
                    Logger.Info("DataProcessingViewModel", "Excel mapping dialog completed successfully");
                }
                else
                {
                    StatusMessage = "Excel mapping cancelled";
                    Logger.Info("DataProcessingViewModel", "Excel mapping dialog was cancelled");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", "Failed to open Excel mapping dialog", ex);
                StatusMessage = $"Error opening Excel mapping: {ex.Message}";
            }
            
            Logger.TraceExit();
        }

        private void AppendToLog(string message)
        {
            var timestamp = DateTime.Now.ToString("HH:mm:ss");
            IntegrationLog += $"[{timestamp}] {message}\n";
        }

        private void CreateNewProject()
        {
            Logger.TraceEnter();
            
            try
            {
                var newProjectId = $"PROJECT_{DateTime.Now:yyyyMMddHHmmss}";
                var newProject = new ProjectDataItem
                {
                    ProjectId = newProjectId,
                    RequestDate = DateTime.Now.ToString("yyyy-MM-dd"),
                    Status = "New",
                    SiteName = "New Site",
                    AuditType = "TBD"
                };
                
                _projectDataService.UpdateProjectData(newProjectId, newProject);
                ProjectIds.Add(newProjectId);
                SelectedProjectId = newProjectId;
                
                LoadingIndicatorService.Instance.SetStatus($"Created new project: {newProjectId}");
                OnPropertyChanged(nameof(HasProjects));
                
                Logger.Info("DataProcessingViewModel", $"Created new project: {newProjectId}");
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", $"Failed to create project: {ex.Message}");
                LoadingIndicatorService.Instance.SetStatus($"Failed to create project: {ex.Message}");
            }
            
            Logger.TraceExit();
        }

        private async Task SaveProjectAsync()
        {
            if (SelectedProject == null)
            {
                LoadingIndicatorService.Instance.SetStatus("No project selected to save");
                return;
            }
            
            Logger.TraceEnter($"projectId={SelectedProject.ProjectId}");
            
            await LoadingIndicatorService.Instance.ExecuteWithLoading(async () =>
            {
                await Task.Delay(100); // Simulate processing time
                _projectDataService.UpdateProjectData(SelectedProject.ProjectId, SelectedProject);
                AppendToLog($"Project saved: {SelectedProject.ProjectId}");
                Logger.Info("DataProcessingViewModel", $"Saved project: {SelectedProject.ProjectId}");
            }, $"Saving project {SelectedProject.ProjectId}...");
            
            await LoadingIndicatorService.Instance.ShowTemporaryStatus($"Project saved: {SelectedProject.ProjectId}");
            Logger.TraceExit();
        }

        private async Task DeleteProjectAsync()
        {
            if (SelectedProject == null)
            {
                StatusMessage = "No project selected to delete";
                return;
            }
            
            var projectId = SelectedProject.ProjectId;
            Logger.TraceEnter($"projectId={projectId}");
            
            try
            {
                // Simple confirmation via status message
                StatusMessage = $"Deleted project: {projectId}";
                AppendToLog($"Project deleted: {projectId}");
                
                ProjectIds.Remove(projectId);
                SelectedProject = null;
                SelectedProjectId = string.Empty;
                
                OnPropertyChanged(nameof(HasProjects));
                
                Logger.Info("DataProcessingViewModel", $"Deleted project: {projectId}");
            }
            catch (Exception ex)
            {
                Logger.Error("DataProcessingViewModel", $"Failed to delete project: {ex.Message}");
                StatusMessage = $"Delete failed: {ex.Message}";
                AppendToLog($"Delete error: {ex.Message}");
            }
            
            Logger.TraceExit();
        }

        private static string ValidateDateFormat(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return "Date is required";
                
            if (DateTime.TryParse(value, out _))
                return string.Empty;
                
            return "Invalid date format. Please use YYYY-MM-DD or MM/DD/YYYY";
        }
        
        private static string ValidateEmail(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return string.Empty; // Email is optional
                
            if (value.Contains("@") && value.Contains("."))
                return string.Empty;
                
            return "Invalid email format";
        }
        
        private static string ValidatePhoneNumber(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return string.Empty; // Phone is optional
                
            var digits = new string(value.Where(char.IsDigit).ToArray());
            if (digits.Length >= 10)
                return string.Empty;
                
            return "Phone number must contain at least 10 digits";
        }

        private async System.Threading.Tasks.Task CreateTemplateAsync()
        {
            var saveDialog = new SaveFileDialog
            {
                Filter = "Excel Files (*.xlsx)|*.xlsx",
                DefaultExt = "xlsx",
                FileName = $"ProjectDataTemplate_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx"
            };

            if (saveDialog.ShowDialog() == true)
            {
                try
                {
                    var result = await _loadingService.ExecuteWithLoading(
                        async () => await _excelDataService.CreateTemplateAsync(saveDialog.FileName),
                        "Creating Excel template..."
                    );

                    if (result.Success)
                    {
                        StatusMessage = result.Message;
                        AppendToLog($"Template created: {result.FilePath}");
                    }
                    else
                    {
                        StatusMessage = $"Template creation failed: {result.ErrorMessage}";
                        AppendToLog($"Template creation failed: {result.ErrorMessage}");
                    }
                }
                catch (Exception ex)
                {
                    StatusMessage = $"Template creation error: {ex.Message}";
                    AppendToLog($"Template creation error: {ex.Message}");
                    Logger.Error("DataProcessingViewModel", $"CreateTemplateAsync failed: {ex.Message}");
                }
            }
        }

        private async System.Threading.Tasks.Task ExportAllProjectsAsync()
        {
            if (!HasProjects)
            {
                StatusMessage = "No projects available to export";
                return;
            }

            var saveDialog = new SaveFileDialog
            {
                Filter = "Excel Files (*.xlsx)|*.xlsx",
                DefaultExt = "xlsx",
                FileName = $"AllProjects_export_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx"
            };

            if (saveDialog.ShowDialog() == true)
            {
                try
                {
                    var result = await _loadingService.ExecuteWithLoading(
                        async () => await _excelDataService.ExportToExcelAsync(saveDialog.FileName),
                        "Exporting all projects to Excel..."
                    );

                    if (result.Success)
                    {
                        StatusMessage = result.Message;
                        AppendToLog($"Export completed: {result.ExportedCount} project(s) exported to Excel");
                    }
                    else
                    {
                        StatusMessage = $"Export failed: {result.ErrorMessage}";
                        AppendToLog($"Export failed: {result.ErrorMessage}");
                    }
                }
                catch (Exception ex)
                {
                    StatusMessage = $"Export error: {ex.Message}";
                    AppendToLog($"Export error: {ex.Message}");
                    Logger.Error("DataProcessingViewModel", $"ExportAllProjectsAsync failed: {ex.Message}");
                }
            }
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
        private string _validationError = string.Empty;
        private readonly Action<string> _updateAction;
        private readonly Func<string, string>? _validator;

        public ProjectDataField(string key, string value, Action<string> updateAction, Func<string, string>? validator = null, int tabIndex = 0)
        {
            Key = key;
            _value = value ?? string.Empty;
            _updateAction = updateAction;
            _validator = validator;
            TabIndex = tabIndex;
            ValidateValue(_value);
        }

        public string Key { get; }
        public int TabIndex { get; }
        
        public string ValidationError
        {
            get => _validationError;
            private set
            {
                _validationError = value;
                OnPropertyChanged(nameof(ValidationError));
                OnPropertyChanged(nameof(HasError));
            }
        }
        
        public bool HasError => !string.IsNullOrEmpty(ValidationError);

        public string Value
        {
            get => _value;
            set
            {
                _value = value;
                ValidateValue(value);
                if (!HasError)
                {
                    _updateAction(value);
                }
                OnPropertyChanged(nameof(Value));
            }
        }
        
        private void ValidateValue(string value)
        {
            if (_validator != null)
            {
                ValidationError = _validator(value);
            }
            else
            {
                ValidationError = string.Empty;
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}