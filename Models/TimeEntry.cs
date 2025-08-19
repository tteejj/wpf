using System;
using System.ComponentModel;
using System.Text.Json.Serialization;
using PraxisWpf.Services;

namespace PraxisWpf.Models
{
    public class TimeEntry : INotifyPropertyChanged
    {
        private int _id1;
        private int? _id2;
        private DateTime _date;
        private decimal _hours;
        private string _description = string.Empty;
        private bool _isGeneric;

        public TimeEntry()
        {
            Logger.TraceEnter();
            _date = DateTime.Today;
            Logger.TraceExit();
        }

        /// <summary>
        /// Primary ID - used for both projects and generic timecodes
        /// </summary>
        public int Id1
        {
            get 
            { 
                Logger.TraceProperty("Id1", null, _id1);
                return _id1; 
            }
            set
            {
                var oldValue = _id1;
                Logger.TraceProperty("Id1", oldValue, value);
                _id1 = value;
                OnPropertyChanged(nameof(Id1));
                Logger.Debug("TimeEntry", $"Id1 changed: {oldValue} → {value}");
            }
        }

        /// <summary>
        /// Secondary ID - only used for projects, null for generic timecodes
        /// </summary>
        public int? Id2
        {
            get 
            { 
                Logger.TraceProperty("Id2", null, _id2);
                return _id2; 
            }
            set
            {
                var oldValue = _id2;
                Logger.TraceProperty("Id2", oldValue, value);
                _id2 = value;
                _isGeneric = !value.HasValue; // Auto-determine if generic
                OnPropertyChanged(nameof(Id2));
                OnPropertyChanged(nameof(IsGeneric));
                OnPropertyChanged(nameof(ProjectReference));
                Logger.Debug("TimeEntry", $"Id2 changed: {oldValue} → {value}, IsGeneric: {_isGeneric}");
            }
        }

        /// <summary>
        /// Date of time entry (Monday-Friday only)
        /// </summary>
        public DateTime Date
        {
            get 
            { 
                Logger.TraceProperty("Date", null, _date);
                return _date; 
            }
            set
            {
                var oldValue = _date;
                Logger.TraceProperty("Date", oldValue, value);
                
                // Ensure only Monday-Friday dates
                if (value.DayOfWeek == DayOfWeek.Saturday || value.DayOfWeek == DayOfWeek.Sunday)
                {
                    Logger.Warning("TimeEntry", $"Invalid date - weekends not allowed: {value:yyyy-MM-dd}");
                    return; // Don't set weekend dates
                }
                
                _date = value.Date; // Ensure time component is stripped
                OnPropertyChanged(nameof(Date));
                OnPropertyChanged(nameof(WeekStartDate));
                Logger.Debug("TimeEntry", $"Date changed: {oldValue:yyyy-MM-dd} → {value:yyyy-MM-dd}");
            }
        }

        /// <summary>
        /// Hours worked (in 0.25 increments only)
        /// </summary>
        public decimal Hours
        {
            get 
            { 
                Logger.TraceProperty("Hours", null, _hours);
                return _hours; 
            }
            set
            {
                var oldValue = _hours;
                Logger.TraceProperty("Hours", oldValue, value);
                
                // Round to nearest 0.25
                var roundedValue = Math.Round(value * 4, MidpointRounding.AwayFromZero) / 4;
                if (roundedValue < 0) roundedValue = 0;
                if (roundedValue > 24) roundedValue = 24; // Max 24 hours per day
                
                _hours = roundedValue;
                OnPropertyChanged(nameof(Hours));
                Logger.Debug("TimeEntry", $"Hours changed: {oldValue} → {roundedValue} (input: {value})");
            }
        }

        /// <summary>
        /// Optional description of work performed
        /// </summary>
        public string Description
        {
            get 
            { 
                Logger.TraceProperty("Description", null, _description);
                return _description; 
            }
            set
            {
                var oldValue = _description;
                Logger.TraceProperty("Description", oldValue, value);
                _description = value ?? string.Empty;
                OnPropertyChanged(nameof(Description));
                Logger.Debug("TimeEntry", $"Description changed: '{oldValue}' → '{value}'");
            }
        }

        /// <summary>
        /// True if this is a generic timecode (Id2 is null), false if project-specific
        /// </summary>
        [JsonIgnore]
        public bool IsGeneric
        {
            get 
            { 
                Logger.TraceProperty("IsGeneric", null, _isGeneric);
                return _isGeneric; 
            }
        }

        /// <summary>
        /// String representation of the project/timecode reference
        /// </summary>
        [JsonIgnore]
        public string ProjectReference
        {
            get
            {
                var reference = IsGeneric ? $"Generic-{Id1}" : $"Project-{Id1}.{Id2}";
                Logger.TraceProperty("ProjectReference", null, reference);
                return reference;
            }
        }

        /// <summary>
        /// Start of the week (Monday) for this time entry
        /// </summary>
        [JsonIgnore]
        public DateTime WeekStartDate
        {
            get
            {
                var daysFromMonday = (int)Date.DayOfWeek - (int)DayOfWeek.Monday;
                if (daysFromMonday < 0) daysFromMonday += 7; // Handle Sunday
                var weekStart = Date.AddDays(-daysFromMonday);
                Logger.TraceProperty("WeekStartDate", null, weekStart);
                return weekStart;
            }
        }

        /// <summary>
        /// Display name for UI binding
        /// </summary>
        [JsonIgnore]
        public string DisplayName => $"{ProjectReference} - {Date:MM/dd} - {Hours}h";

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            Logger.Trace("TimeEntry", $"PropertyChanged: {propertyName} for {ProjectReference}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public override string ToString()
        {
            return $"TimeEntry: {ProjectReference} on {Date:yyyy-MM-dd} for {Hours}h - {Description}";
        }
    }
}