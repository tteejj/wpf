using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Text.Json.Serialization;
using PraxisWpf.Interfaces;

namespace PraxisWpf.Models
{
    public class ProjectDataItem : IDisplayableItem, INotifyPropertyChanged
    {
        private string _projectId = string.Empty;
        private bool _isExpanded = false;
        private bool _isInEditMode = false;

        [JsonPropertyName("projectId")]
        public string ProjectId
        {
            get => _projectId;
            set { _projectId = value; OnPropertyChanged(nameof(ProjectId)); OnPropertyChanged(nameof(DisplayName)); }
        }

        // All 40 fields from exceldataflow configuration
        [JsonPropertyName("requestDate")]
        public string RequestDate { get; set; } = string.Empty;

        [JsonPropertyName("auditType")]
        public string AuditType { get; set; } = string.Empty;

        [JsonPropertyName("auditorName")]
        public string AuditorName { get; set; } = string.Empty;

        [JsonPropertyName("tpName")]
        public string TPName { get; set; } = string.Empty;

        [JsonPropertyName("tpEmailAddress")]
        public string TPEmailAddress { get; set; } = string.Empty;

        [JsonPropertyName("tpPhoneNumber")]
        public string TPPhoneNumber { get; set; } = string.Empty;

        [JsonPropertyName("corporateContact")]
        public string CorporateContact { get; set; } = string.Empty;

        [JsonPropertyName("corporateContactEmail")]
        public string CorporateContactEmail { get; set; } = string.Empty;

        [JsonPropertyName("corporateContactPhone")]
        public string CorporateContactPhone { get; set; } = string.Empty;

        [JsonPropertyName("siteName")]
        public string SiteName { get; set; } = string.Empty;

        [JsonPropertyName("siteAddress")]
        public string SiteAddress { get; set; } = string.Empty;

        [JsonPropertyName("siteCity")]
        public string SiteCity { get; set; } = string.Empty;

        [JsonPropertyName("siteState")]
        public string SiteState { get; set; } = string.Empty;

        [JsonPropertyName("siteZip")]
        public string SiteZip { get; set; } = string.Empty;

        [JsonPropertyName("siteCountry")]
        public string SiteCountry { get; set; } = string.Empty;

        [JsonPropertyName("attentionContact")]
        public string AttentionContact { get; set; } = string.Empty;

        [JsonPropertyName("attentionContactEmail")]
        public string AttentionContactEmail { get; set; } = string.Empty;

        [JsonPropertyName("attentionContactPhone")]
        public string AttentionContactPhone { get; set; } = string.Empty;

        [JsonPropertyName("taxId")]
        public string TaxID { get; set; } = string.Empty;

        [JsonPropertyName("duns")]
        public string DUNS { get; set; } = string.Empty;

        [JsonPropertyName("casNumber")]
        public string CASNumber { get; set; } = string.Empty;

        [JsonPropertyName("assetName")]
        public string AssetName { get; set; } = string.Empty;

        [JsonPropertyName("serialNumber")]
        public string SerialNumber { get; set; } = string.Empty;

        [JsonPropertyName("modelNumber")]
        public string ModelNumber { get; set; } = string.Empty;

        [JsonPropertyName("manufacturerName")]
        public string ManufacturerName { get; set; } = string.Empty;

        [JsonPropertyName("installDate")]
        public string InstallDate { get; set; } = string.Empty;

        [JsonPropertyName("capacity")]
        public string Capacity { get; set; } = string.Empty;

        [JsonPropertyName("capacityUnit")]
        public string CapacityUnit { get; set; } = string.Empty;

        [JsonPropertyName("tankType")]
        public string TankType { get; set; } = string.Empty;

        [JsonPropertyName("product")]
        public string Product { get; set; } = string.Empty;

        [JsonPropertyName("leakDetection")]
        public string LeakDetection { get; set; } = string.Empty;

        [JsonPropertyName("piping")]
        public string Piping { get; set; } = string.Empty;

        [JsonPropertyName("monitoring")]
        public string Monitoring { get; set; } = string.Empty;

        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;

        [JsonPropertyName("comments")]
        public string Comments { get; set; } = string.Empty;

        [JsonPropertyName("complianceDate")]
        public string ComplianceDate { get; set; } = string.Empty;

        [JsonPropertyName("nextInspectionDate")]
        public string NextInspectionDate { get; set; } = string.Empty;

        [JsonPropertyName("certificationNumber")]
        public string CertificationNumber { get; set; } = string.Empty;

        [JsonPropertyName("inspectorName")]
        public string InspectorName { get; set; } = string.Empty;

        [JsonPropertyName("inspectorLicense")]
        public string InspectorLicense { get; set; } = string.Empty;

        // IDisplayableItem implementation
        [JsonIgnore]
        public string DisplayName => !string.IsNullOrEmpty(SiteName) ? $"{ProjectId} - {SiteName}" : ProjectId;

        [JsonIgnore]
        public ObservableCollection<IDisplayableItem> Children { get; set; } = new ObservableCollection<IDisplayableItem>();

        [JsonPropertyName("isExpanded")]
        public bool IsExpanded
        {
            get => _isExpanded;
            set { _isExpanded = value; OnPropertyChanged(nameof(IsExpanded)); }
        }

        [JsonIgnore]
        public bool IsInEditMode
        {
            get => _isInEditMode;
            set { _isInEditMode = value; OnPropertyChanged(nameof(IsInEditMode)); }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}