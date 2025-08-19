using System;
using System.ComponentModel;
using System.Text.Json.Serialization;
using PraxisWpf.Services;

namespace PraxisWpf.Models
{
    public class TimeSummary : INotifyPropertyChanged
    {
        private int _id1;
        private int? _id2;
        private DateTime _weekStartDate;
        private decimal _totalHours;

        public TimeSummary()
        {
            Logger.TraceEnter();
            Logger.TraceExit();
        }

        public TimeSummary(int id1, int? id2, DateTime weekStartDate)
        {
            Logger.TraceEnter(parameters: new object[] { id1, id2 ?? -1, weekStartDate });
            _id1 = id1;
            _id2 = id2;
            _weekStartDate = weekStartDate.Date;
            Logger.TraceExit();
        }

        /// <summary>
        /// Primary ID of the project/timecode
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
                OnPropertyChanged(nameof(ProjectReference));
                Logger.Debug("TimeSummary", $"Id1 changed: {oldValue} → {value}");
            }
        }

        /// <summary>
        /// Secondary ID (null for generic timecodes)
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
                OnPropertyChanged(nameof(Id2));
                OnPropertyChanged(nameof(ProjectReference));
                OnPropertyChanged(nameof(IsGeneric));
                Logger.Debug("TimeSummary", $"Id2 changed: {oldValue} → {value}");
            }
        }

        /// <summary>
        /// Start of the week (Monday) for this summary
        /// </summary>
        public DateTime WeekStartDate
        {
            get 
            { 
                Logger.TraceProperty("WeekStartDate", null, _weekStartDate);
                return _weekStartDate; 
            }
            set
            {
                var oldValue = _weekStartDate;
                Logger.TraceProperty("WeekStartDate", oldValue, value);
                _weekStartDate = value.Date;
                OnPropertyChanged(nameof(WeekStartDate));
                OnPropertyChanged(nameof(WeekEndDate));
                Logger.Debug("TimeSummary", $"WeekStartDate changed: {oldValue:yyyy-MM-dd} → {value:yyyy-MM-dd}");
            }
        }

        /// <summary>
        /// Total hours for this project/timecode for the week
        /// </summary>
        public decimal TotalHours
        {
            get 
            { 
                Logger.TraceProperty("TotalHours", null, _totalHours);
                return _totalHours; 
            }
            set
            {
                var oldValue = _totalHours;
                Logger.TraceProperty("TotalHours", oldValue, value);
                _totalHours = value;
                OnPropertyChanged(nameof(TotalHours));
                Logger.Debug("TimeSummary", $"TotalHours changed: {oldValue} → {value} for {ProjectReference}");
            }
        }

        /// <summary>
        /// True if this is a generic timecode summary
        /// </summary>
        [JsonIgnore]
        public bool IsGeneric => !Id2.HasValue;

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
        /// End of the week (Friday) for this summary
        /// </summary>
        [JsonIgnore]
        public DateTime WeekEndDate
        {
            get
            {
                var weekEnd = WeekStartDate.AddDays(4); // Monday + 4 = Friday
                Logger.TraceProperty("WeekEndDate", null, weekEnd);
                return weekEnd;
            }
        }

        /// <summary>
        /// Display name for UI binding
        /// </summary>
        [JsonIgnore]
        public string DisplayName => $"{ProjectReference} - Week {WeekStartDate:MM/dd} - {TotalHours}h";

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            Logger.Trace("TimeSummary", $"PropertyChanged: {propertyName} for {ProjectReference}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public override string ToString()
        {
            return $"TimeSummary: {ProjectReference} week of {WeekStartDate:yyyy-MM-dd} = {TotalHours}h";
        }
    }
}