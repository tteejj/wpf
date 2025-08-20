using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Input;
using Microsoft.Win32;
using PraxisWpf.Commands;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Features.DataProcessing
{
    public class ExcelMappingViewModel : INotifyPropertyChanged
    {
        private readonly ExcelMappingService _mappingService;
        private string _sourceFilePath = string.Empty;
        private string _destinationFilePath = string.Empty;
        private string _selectedSourceSheet = string.Empty;
        private string _selectedDestinationSheet = string.Empty;

        public ObservableCollection<ExcelFieldMapping> FieldMappings { get; }
        public ObservableCollection<string> SourceSheets { get; }
        public ObservableCollection<string> DestinationSheets { get; }

        // All 41 hardcoded field names from your Excel system
        private static readonly string[] HardcodedFieldNames = {
            "ProjectId", "RequestDate", "AuditType", "AuditorName", "TPName", "TPEmailAddress", "TPPhoneNumber",
            "CorporateContact", "CorporateContactEmail", "CorporateContactPhone", "SiteName", "SiteAddress",
            "SiteCity", "SiteState", "SiteZip", "SiteCountry", "AttentionContact", "AttentionContactEmail",
            "AttentionContactPhone", "TaxID", "DUNS", "CASNumber", "AssetName", "SerialNumber", "ModelNumber",
            "ManufacturerName", "InstallDate", "Capacity", "CapacityUnit", "TankType", "Product",
            "LeakDetection", "Piping", "Monitoring", "Status", "Comments", "ComplianceDate",
            "NextInspectionDate", "CertificationNumber", "InspectorName", "InspectorLicense"
        };

        public string SourceFilePath
        {
            get => _sourceFilePath;
            set
            {
                _sourceFilePath = value;
                OnPropertyChanged(nameof(SourceFilePath));
                LoadSourceSheets();
            }
        }

        public string DestinationFilePath
        {
            get => _destinationFilePath;
            set
            {
                _destinationFilePath = value;
                OnPropertyChanged(nameof(DestinationFilePath));
                LoadDestinationSheets();
            }
        }

        public string SelectedSourceSheet
        {
            get => _selectedSourceSheet;
            set
            {
                _selectedSourceSheet = value;
                OnPropertyChanged(nameof(SelectedSourceSheet));
                RefreshSourceValues();
            }
        }

        public string SelectedDestinationSheet
        {
            get => _selectedDestinationSheet;
            set
            {
                _selectedDestinationSheet = value;
                OnPropertyChanged(nameof(SelectedDestinationSheet));
            }
        }

        // Commands
        public ICommand BrowseSourceFileCommand { get; }
        public ICommand BrowseDestinationFileCommand { get; }
        public ICommand ExecuteMappingCommand { get; }
        public ICommand ExportTextCommand { get; }
        public ICommand SaveConfigCommand { get; }
        public ICommand LoadConfigCommand { get; }
        public ICommand SelectAllT2020Command { get; }
        public ICommand ClearAllT2020Command { get; }
        public ICommand AutoMapSequentialCommand { get; }

        public ExcelMappingViewModel()
        {
            Logger.TraceEnter();
            
            _mappingService = new ExcelMappingService();
            FieldMappings = new ObservableCollection<ExcelFieldMapping>();
            SourceSheets = new ObservableCollection<string>();
            DestinationSheets = new ObservableCollection<string>();

            // Initialize with all 41 hardcoded field names
            InitializeFieldMappings();

            // Initialize commands
            BrowseSourceFileCommand = new RelayCommand(BrowseSourceFile);
            BrowseDestinationFileCommand = new RelayCommand(BrowseDestinationFile);
            ExecuteMappingCommand = new RelayCommand(async () => await ExecuteMappingAsync(), CanExecuteMapping);
            ExportTextCommand = new RelayCommand(async () => await ExportTextAsync(), CanExportText);
            SaveConfigCommand = new RelayCommand(SaveConfiguration);
            LoadConfigCommand = new RelayCommand(LoadConfiguration);
            SelectAllT2020Command = new RelayCommand(SelectAllT2020);
            ClearAllT2020Command = new RelayCommand(ClearAllT2020);
            AutoMapSequentialCommand = new RelayCommand(AutoMapSequential);

            Logger.Info("ExcelMappingViewModel", $"Initialized with {FieldMappings.Count} field mappings");
            Logger.TraceExit();
        }

        private void InitializeFieldMappings()
        {
            Logger.TraceEnter();
            
            for (int i = 0; i < HardcodedFieldNames.Length; i++)
            {
                var mapping = new ExcelFieldMapping
                {
                    FieldName = HardcodedFieldNames[i],
                    SourceCell = $"A{i + 1}",      // Default to A1, A2, A3...
                    DestinationCell = $"B{i + 1}", // Default to B1, B2, B3...
                    UseInT2020 = false
                };
                FieldMappings.Add(mapping);
            }
            
            Logger.Info("ExcelMappingViewModel", $"Initialized {HardcodedFieldNames.Length} field mappings");
            Logger.TraceExit();
        }

        private void BrowseSourceFile()
        {
            Logger.TraceEnter();
            
            var dialog = new OpenFileDialog
            {
                Title = "Select Source Excel File",
                Filter = "Excel Files|*.xlsx;*.xls|All Files|*.*",
                CheckFileExists = true
            };

            if (dialog.ShowDialog() == true)
            {
                SourceFilePath = dialog.FileName;
                Logger.Info("ExcelMappingViewModel", $"Source file selected: {Path.GetFileName(SourceFilePath)}");
            }
            
            Logger.TraceExit();
        }

        private void BrowseDestinationFile()
        {
            Logger.TraceEnter();
            
            var dialog = new OpenFileDialog
            {
                Title = "Select Destination Excel File",
                Filter = "Excel Files|*.xlsx;*.xls|All Files|*.*",
                CheckFileExists = true
            };

            if (dialog.ShowDialog() == true)
            {
                DestinationFilePath = dialog.FileName;
                Logger.Info("ExcelMappingViewModel", $"Destination file selected: {Path.GetFileName(DestinationFilePath)}");
            }
            
            Logger.TraceExit();
        }

        private void LoadSourceSheets()
        {
            Logger.TraceEnter();
            
            SourceSheets.Clear();
            if (!string.IsNullOrEmpty(SourceFilePath) && File.Exists(SourceFilePath))
            {
                var sheets = _mappingService.GetWorksheetNames(SourceFilePath);
                foreach (var sheet in sheets)
                {
                    SourceSheets.Add(sheet);
                }
                
                if (SourceSheets.Any())
                {
                    SelectedSourceSheet = SourceSheets.First();
                }
            }
            
            Logger.TraceExit();
        }

        private void LoadDestinationSheets()
        {
            Logger.TraceEnter();
            
            DestinationSheets.Clear();
            if (!string.IsNullOrEmpty(DestinationFilePath) && File.Exists(DestinationFilePath))
            {
                var sheets = _mappingService.GetWorksheetNames(DestinationFilePath);
                foreach (var sheet in sheets)
                {
                    DestinationSheets.Add(sheet);
                }
                
                if (DestinationSheets.Any())
                {
                    SelectedDestinationSheet = DestinationSheets.First();
                }
            }
            
            Logger.TraceExit();
        }

        private void RefreshSourceValues()
        {
            Logger.TraceEnter();
            
            if (!string.IsNullOrEmpty(SourceFilePath) && !string.IsNullOrEmpty(SelectedSourceSheet))
            {
                _mappingService.ReadSourceValues(FieldMappings.ToList(), SourceFilePath, SelectedSourceSheet);
                Logger.Info("ExcelMappingViewModel", "Source values refreshed");
            }
            
            Logger.TraceExit();
        }

        private bool CanExecuteMapping()
        {
            return !string.IsNullOrEmpty(SourceFilePath) && 
                   !string.IsNullOrEmpty(DestinationFilePath) && 
                   !string.IsNullOrEmpty(SelectedSourceSheet) && 
                   !string.IsNullOrEmpty(SelectedDestinationSheet);
        }

        private async Task ExecuteMappingAsync()
        {
            Logger.TraceEnter();
            
            try
            {
                var result = await _mappingService.ExecuteMappingAsync(
                    FieldMappings.ToList(),
                    SourceFilePath,
                    SelectedSourceSheet,
                    DestinationFilePath,
                    SelectedDestinationSheet);

                if (result.Success)
                {
                    Logger.Info("ExcelMappingViewModel", result.Message);
                    System.Windows.MessageBox.Show(result.Message, "Mapping Complete", 
                        System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Information);
                }
                else
                {
                    Logger.Error("ExcelMappingViewModel", result.ErrorMessage);
                    System.Windows.MessageBox.Show(result.ErrorMessage, "Mapping Failed", 
                        System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
                }
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelMappingViewModel", "Execute mapping failed", ex);
                System.Windows.MessageBox.Show($"Mapping failed: {ex.Message}", "Error", 
                    System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
            }
            
            Logger.TraceExit();
        }

        private bool CanExportText()
        {
            return FieldMappings.Any(f => f.UseInT2020);
        }

        private async Task ExportTextAsync()
        {
            Logger.TraceEnter();
            
            try
            {
                var dialog = new SaveFileDialog
                {
                    Title = "Save T2020 Export File",
                    Filter = "Text Files|*.txt|All Files|*.*",
                    DefaultExt = ".txt"
                };

                if (dialog.ShowDialog() == true)
                {
                    var result = await _mappingService.ExportTextFileAsync(FieldMappings.ToList(), dialog.FileName);
                    
                    if (result.Success)
                    {
                        Logger.Info("ExcelMappingViewModel", result.Message);
                        System.Windows.MessageBox.Show(result.Message, "Export Complete", 
                            System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Information);
                    }
                    else
                    {
                        Logger.Error("ExcelMappingViewModel", result.ErrorMessage);
                        System.Windows.MessageBox.Show(result.ErrorMessage, "Export Failed", 
                            System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelMappingViewModel", "Export text failed", ex);
                System.Windows.MessageBox.Show($"Export failed: {ex.Message}", "Error", 
                    System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
            }
            
            Logger.TraceExit();
        }

        private void SaveConfiguration()
        {
            Logger.TraceEnter();
            
            try
            {
                var dialog = new SaveFileDialog
                {
                    Title = "Save Configuration",
                    Filter = "JSON Files|*.json|All Files|*.*",
                    DefaultExt = ".json"
                };

                if (dialog.ShowDialog() == true)
                {
                    var config = new ExcelMappingConfig
                    {
                        SourceFilePath = SourceFilePath,
                        DestinationFilePath = DestinationFilePath,
                        SourceSheet = SelectedSourceSheet,
                        DestinationSheet = SelectedDestinationSheet,
                        FieldMappings = FieldMappings.Select(f => new ExcelFieldMappingData
                        {
                            FieldName = f.FieldName,
                            SourceCell = f.SourceCell,
                            DestinationCell = f.DestinationCell,
                            UseInT2020 = f.UseInT2020
                        }).ToList()
                    };

                    var json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
                    File.WriteAllText(dialog.FileName, json);
                    
                    Logger.Info("ExcelMappingViewModel", $"Configuration saved to {Path.GetFileName(dialog.FileName)}");
                    System.Windows.MessageBox.Show("Configuration saved successfully!", "Save Complete", 
                        System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Information);
                }
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelMappingViewModel", "Save configuration failed", ex);
                System.Windows.MessageBox.Show($"Save failed: {ex.Message}", "Error", 
                    System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
            }
            
            Logger.TraceExit();
        }

        private void LoadConfiguration()
        {
            Logger.TraceEnter();
            
            try
            {
                var dialog = new OpenFileDialog
                {
                    Title = "Load Configuration",
                    Filter = "JSON Files|*.json|All Files|*.*"
                };

                if (dialog.ShowDialog() == true)
                {
                    var json = File.ReadAllText(dialog.FileName);
                    var config = JsonSerializer.Deserialize<ExcelMappingConfig>(json);
                    
                    if (config != null)
                    {
                        SourceFilePath = config.SourceFilePath;
                        DestinationFilePath = config.DestinationFilePath;
                        SelectedSourceSheet = config.SourceSheet;
                        SelectedDestinationSheet = config.DestinationSheet;

                        // Update field mappings
                        foreach (var configMapping in config.FieldMappings)
                        {
                            var fieldMapping = FieldMappings.FirstOrDefault(f => f.FieldName == configMapping.FieldName);
                            if (fieldMapping != null)
                            {
                                fieldMapping.SourceCell = configMapping.SourceCell;
                                fieldMapping.DestinationCell = configMapping.DestinationCell;
                                fieldMapping.UseInT2020 = configMapping.UseInT2020;
                            }
                        }
                        
                        Logger.Info("ExcelMappingViewModel", $"Configuration loaded from {Path.GetFileName(dialog.FileName)}");
                        System.Windows.MessageBox.Show("Configuration loaded successfully!", "Load Complete", 
                            System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Information);
                        
                        // Refresh source values if possible
                        RefreshSourceValues();
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Error("ExcelMappingViewModel", "Load configuration failed", ex);
                System.Windows.MessageBox.Show($"Load failed: {ex.Message}", "Error", 
                    System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
            }
            
            Logger.TraceExit();
        }

        private void SelectAllT2020()
        {
            Logger.TraceEnter();
            foreach (var mapping in FieldMappings)
            {
                mapping.UseInT2020 = true;
            }
            Logger.Info("ExcelMappingViewModel", "Selected all fields for T2020");
            Logger.TraceExit();
        }

        private void ClearAllT2020()
        {
            Logger.TraceEnter();
            foreach (var mapping in FieldMappings)
            {
                mapping.UseInT2020 = false;
            }
            Logger.Info("ExcelMappingViewModel", "Cleared all T2020 selections");
            Logger.TraceExit();
        }

        private void AutoMapSequential()
        {
            Logger.TraceEnter();
            for (int i = 0; i < FieldMappings.Count; i++)
            {
                FieldMappings[i].SourceCell = $"A{i + 1}";
                FieldMappings[i].DestinationCell = $"B{i + 1}";
            }
            Logger.Info("ExcelMappingViewModel", "Auto-mapped fields sequentially A1:A41 → B1:B41");
            RefreshSourceValues();
            Logger.TraceExit();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}