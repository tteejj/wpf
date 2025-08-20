using System.Collections.Generic;

namespace PraxisWpf.Models
{
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