using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace PraxisWpf.Models
{
    public class ExcelMappingConfig
    {
        [JsonPropertyName("sourceFilePath")]
        public string SourceFilePath { get; set; } = string.Empty;

        [JsonPropertyName("destinationFilePath")]
        public string DestinationFilePath { get; set; } = string.Empty;

        [JsonPropertyName("sourceSheet")]
        public string SourceSheet { get; set; } = string.Empty;

        [JsonPropertyName("destinationSheet")]
        public string DestinationSheet { get; set; } = string.Empty;

        [JsonPropertyName("fieldMappings")]
        public List<ExcelFieldMappingData> FieldMappings { get; set; } = new();
    }

    public class ExcelFieldMappingData
    {
        [JsonPropertyName("fieldName")]
        public string FieldName { get; set; } = string.Empty;

        [JsonPropertyName("sourceCell")]
        public string SourceCell { get; set; } = string.Empty;

        [JsonPropertyName("destinationCell")]
        public string DestinationCell { get; set; } = string.Empty;

        [JsonPropertyName("useInT2020")]
        public bool UseInT2020 { get; set; }
    }
}