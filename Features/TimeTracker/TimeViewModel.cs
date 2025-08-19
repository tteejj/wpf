using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Input;
using PraxisWpf.Commands;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TimeTracker
{
    public class TimeViewModel : INotifyPropertyChanged
    {
        private readonly ITimeDataService _timeDataService;
        private DateTime _selectedDate;
        private TimeEntry? _selectedTimeEntry;

        public ObservableCollection<TimeEntry> TimeEntries { get; private set; }
        public ObservableCollection<(int Id1, int? Id2, string Name)> AvailableProjects { get; private set; }
        public ObservableCollection<decimal> HourIncrements { get; private set; }

        public ICommand DeleteTimeEntryCommand { get; }
        public ICommand SaveCommand { get; }
        public ICommand PreviousWeekCommand { get; }
        public ICommand NextWeekCommand { get; }
        public ICommand CurrentWeekCommand { get; }
        public ICommand PreviousDayCommand { get; }
        public ICommand NextDayCommand { get; }
        public ICommand TodayCommand { get; }
        public ICommand ExportWeeklyTimesheetCommand { get; }

        public TimeViewModel() : this(new TimeDataService())
        {
            Logger.TraceEnter();
            Logger.TraceExit();
        }

        public TimeViewModel(ITimeDataService timeDataService)
        {
            Logger.TraceEnter(parameters: new object[] { timeDataService.GetType().Name });
            using var perfTracker = Logger.TracePerformance("TimeViewModel Constructor");

            _timeDataService = timeDataService;
            Logger.Debug("TimeViewModel", $"Time data service initialized: {timeDataService.GetType().Name}");

            // Initialize collections
            TimeEntries = _timeDataService.LoadTimeEntries();
            AvailableProjects = new ObservableCollection<(int Id1, int? Id2, string Name)>();
            HourIncrements = new ObservableCollection<decimal>();

            // Populate hour increments (0.25, 0.5, 0.75, 1.0, ... 24.0)
            for (decimal i = 0.25m; i <= 24.0m; i += 0.25m)
            {
                HourIncrements.Add(i);
            }
            Logger.Debug("TimeViewModel", $"Created {HourIncrements.Count} hour increment options");

            // Load available projects
            RefreshAvailableProjects();

            // Initialize to today (or next weekday if weekend)
            _selectedDate = DateTime.Today;
            if (_selectedDate.DayOfWeek == DayOfWeek.Saturday)
                _selectedDate = _selectedDate.AddDays(2);
            else if (_selectedDate.DayOfWeek == DayOfWeek.Sunday)
                _selectedDate = _selectedDate.AddDays(1);
            Logger.Info("TimeViewModel", $"Initialized to week of {_selectedDate:yyyy-MM-dd}");

            // Initialize commands
            DeleteTimeEntryCommand = new RelayCommand(ExecuteDeleteTimeEntry, CanExecuteDeleteTimeEntry);
            SaveCommand = new RelayCommand(ExecuteSave);
            PreviousWeekCommand = new RelayCommand(ExecutePreviousWeek);
            NextWeekCommand = new RelayCommand(ExecuteNextWeek);
            CurrentWeekCommand = new RelayCommand(ExecuteCurrentWeek);
            PreviousDayCommand = new RelayCommand(ExecutePreviousDay);
            NextDayCommand = new RelayCommand(ExecuteNextDay);
            TodayCommand = new RelayCommand(ExecuteToday);
            ExportWeeklyTimesheetCommand = new RelayCommand(ExecuteExportWeeklyTimesheet);

            Logger.Debug("TimeViewModel", "All commands initialized");
            Logger.TraceExit();
        }

        #region Properties

        public DateTime SelectedDate
        {
            get 
            { 
                Logger.TraceProperty("SelectedDate", null, _selectedDate);
                return _selectedDate; 
            }
            set
            {
                var oldValue = _selectedDate;
                Logger.TraceProperty("SelectedDate", oldValue, value);
                
                // Ensure only Monday-Friday
                if (value.DayOfWeek == DayOfWeek.Saturday || value.DayOfWeek == DayOfWeek.Sunday)
                {
                    Logger.Warning("TimeViewModel", $"Invalid date - weekends not allowed: {value:yyyy-MM-dd}");
                    return;
                }
                
                _selectedDate = value.Date;
                OnPropertyChanged(nameof(SelectedDate));
                OnPropertyChanged(nameof(WeekStartDate));
                OnPropertyChanged(nameof(WeekDates));
                OnPropertyChanged(nameof(CurrentWeekEntries));
                OnPropertyChanged(nameof(DayTotal));
                OnPropertyChanged(nameof(WeekTotal));
                RefreshCurrentWeekData();
                Logger.Info("TimeViewModel", $"Selected date changed: {oldValue:yyyy-MM-dd} → {value:yyyy-MM-dd}");
            }
        }

        public DateTime WeekStartDate
        {
            get
            {
                var daysFromMonday = (int)SelectedDate.DayOfWeek - (int)DayOfWeek.Monday;
                if (daysFromMonday < 0) daysFromMonday += 7; // Handle Sunday
                var weekStart = SelectedDate.AddDays(-daysFromMonday);
                Logger.TraceProperty("WeekStartDate", null, weekStart);
                return weekStart;
            }
        }

        public ObservableCollection<DateTime> WeekDates
        {
            get
            {
                var dates = new ObservableCollection<DateTime>();
                var monday = WeekStartDate;
                for (int i = 0; i < 5; i++) // Monday to Friday
                {
                    dates.Add(monday.AddDays(i));
                }
                Logger.TraceProperty("WeekDates", null, $"{dates.Count} dates");
                return dates;
            }
        }

        public ObservableCollection<TimeEntry> CurrentWeekEntries
        {
            get
            {
                var weekEntries = TimeEntries
                    .Where(e => e.Date >= WeekStartDate && e.Date <= WeekStartDate.AddDays(4))
                    .OrderBy(e => e.Date)
                    .ThenBy(e => e.Id1)
                    .ThenBy(e => e.Id2);
                var result = new ObservableCollection<TimeEntry>(weekEntries);
                Logger.TraceProperty("CurrentWeekEntries", null, $"{result.Count} entries");
                return result;
            }
        }

        public decimal DayTotal
        {
            get
            {
                var total = _timeDataService.GetDayTotal(SelectedDate);
                Logger.TraceProperty("DayTotal", null, total);
                return total;
            }
        }

        public decimal WeekTotal
        {
            get
            {
                var total = _timeDataService.GetWeekTotal(WeekStartDate);
                Logger.TraceProperty("WeekTotal", null, total);
                return total;
            }
        }

        public TimeEntry? SelectedTimeEntry
        {
            get 
            { 
                Logger.TraceProperty("SelectedTimeEntry", null, _selectedTimeEntry?.DisplayName ?? "null");
                return _selectedTimeEntry; 
            }
            set
            {
                var oldValue = _selectedTimeEntry;
                Logger.TraceProperty("SelectedTimeEntry", oldValue?.DisplayName ?? "null", value?.DisplayName ?? "null");
                _selectedTimeEntry = value;
                OnPropertyChanged(nameof(SelectedTimeEntry));
                Logger.Info("TimeViewModel", $"Time entry selection changed: '{oldValue?.DisplayName ?? "null"}' → '{value?.DisplayName ?? "null"}'");
            }
        }

        #endregion

        #region Dialog Methods

        public void ShowProjectTimeEntryDialog()
        {
            Logger.TraceEnter();
            
            // Show dialog to select project and enter hours/description
            var dialog = new ProjectTimeEntryDialog(AvailableProjects, SelectedDate);
            var result = dialog.ShowDialog();
            
            if (result == true && dialog.SelectedProject != null)
            {
                var newEntry = new TimeEntry
                {
                    Id1 = dialog.SelectedProject.Value.Id1,
                    Id2 = dialog.SelectedProject.Value.Id2,
                    Date = SelectedDate,
                    Hours = dialog.Hours,
                    Description = dialog.Description
                };

                TimeEntries.Add(newEntry);
                SelectedTimeEntry = newEntry;
                RefreshCurrentWeekData();
                
                Logger.Info("TimeViewModel", $"Added project time entry: {newEntry.ProjectReference} for {newEntry.Hours}h");
            }
            
            Logger.TraceExit();
        }

        public void ShowGenericTimeEntryDialog()
        {
            Logger.TraceEnter();
            
            // Show dialog to enter generic timecode and hours/description
            var dialog = new GenericTimeEntryDialog(SelectedDate);
            var result = dialog.ShowDialog();
            
            if (result == true)
            {
                var newEntry = new TimeEntry
                {
                    Id1 = dialog.TimecodeId,
                    Id2 = null, // Generic timecodes have no Id2
                    Date = SelectedDate,
                    Hours = dialog.Hours,
                    Description = dialog.Description
                };

                TimeEntries.Add(newEntry);
                SelectedTimeEntry = newEntry;
                RefreshCurrentWeekData();
                
                Logger.Info("TimeViewModel", $"Added generic time entry: {newEntry.ProjectReference} for {newEntry.Hours}h");
            }
            
            Logger.TraceExit();
        }

        #endregion

        #region Command Implementations

        private void ExecuteDeleteTimeEntry()
        {
            Logger.TraceEnter();
            if (SelectedTimeEntry == null) return;

            using var perfTracker = Logger.TracePerformance("ExecuteDeleteTimeEntry");

            var entryToDelete = SelectedTimeEntry;
            TimeEntries.Remove(entryToDelete);
            SelectedTimeEntry = null;

            RefreshCurrentWeekData();

            Logger.Info("TimeViewModel", $"Deleted time entry: {entryToDelete.ProjectReference}");
            Logger.TraceExit();
        }

        private bool CanExecuteDeleteTimeEntry()
        {
            var canDelete = SelectedTimeEntry != null;
            Logger.Trace("TimeViewModel", $"CanExecuteDeleteTimeEntry: {canDelete}");
            return canDelete;
        }

        private void ExecuteSave()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("ExecuteSave");
            
            Logger.Info("TimeViewModel", "Saving time data via time data service");
            _timeDataService.SaveTimeEntries(TimeEntries);
            Logger.Info("TimeViewModel", "Time data saved successfully");
            
            Logger.TraceExit();
        }

        private void ExecutePreviousWeek()
        {
            Logger.TraceEnter();
            SelectedDate = WeekStartDate.AddDays(-7); // Go to previous Monday
            Logger.Info("TimeViewModel", $"Navigated to previous week: {WeekStartDate:yyyy-MM-dd}");
            Logger.TraceExit();
        }

        private void ExecuteNextWeek()
        {
            Logger.TraceEnter();
            SelectedDate = WeekStartDate.AddDays(7); // Go to next Monday
            Logger.Info("TimeViewModel", $"Navigated to next week: {WeekStartDate:yyyy-MM-dd}");
            Logger.TraceExit();
        }

        private void ExecuteCurrentWeek()
        {
            Logger.TraceEnter();
            SelectedDate = GetMondayOfCurrentWeek();
            Logger.Info("TimeViewModel", $"Navigated to current week: {WeekStartDate:yyyy-MM-dd}");
            Logger.TraceExit();
        }

        private void ExecutePreviousDay()
        {
            Logger.TraceEnter();
            var newDate = SelectedDate.AddDays(-1);
            // Skip weekends
            if (newDate.DayOfWeek == DayOfWeek.Sunday)
                newDate = newDate.AddDays(-2); // Go to Friday
            else if (newDate.DayOfWeek == DayOfWeek.Saturday)
                newDate = newDate.AddDays(-1); // Go to Friday
            
            SelectedDate = newDate;
            Logger.Info("TimeViewModel", $"Navigated to previous day: {SelectedDate:yyyy-MM-dd}");
            Logger.TraceExit();
        }

        private void ExecuteNextDay()
        {
            Logger.TraceEnter();
            var newDate = SelectedDate.AddDays(1);
            // Skip weekends
            if (newDate.DayOfWeek == DayOfWeek.Saturday)
                newDate = newDate.AddDays(2); // Go to Monday
            else if (newDate.DayOfWeek == DayOfWeek.Sunday)
                newDate = newDate.AddDays(1); // Go to Monday
            
            SelectedDate = newDate;
            Logger.Info("TimeViewModel", $"Navigated to next day: {SelectedDate:yyyy-MM-dd}");
            Logger.TraceExit();
        }

        private void ExecuteToday()
        {
            Logger.TraceEnter();
            var today = DateTime.Today;
            // If today is weekend, go to next Monday
            if (today.DayOfWeek == DayOfWeek.Saturday)
                today = today.AddDays(2);
            else if (today.DayOfWeek == DayOfWeek.Sunday)
                today = today.AddDays(1);
            
            SelectedDate = today;
            Logger.Info("TimeViewModel", $"Navigated to today: {SelectedDate:yyyy-MM-dd}");
            Logger.TraceExit();
        }

        private void ExecuteExportWeeklyTimesheet()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("ExecuteExportWeeklyTimesheet");

            try
            {
                var weekStart = WeekStartDate;
                var weekEnd = weekStart.AddDays(4); // Monday + 4 = Friday
                
                Logger.Info("TimeViewModel", $"Exporting timesheet for week {weekStart:yyyy-MM-dd} to {weekEnd:yyyy-MM-dd}");

                // Get all time entries for the current week
                var weekEntries = TimeEntries.Where(entry => 
                    entry.Date >= weekStart && entry.Date <= weekEnd).ToList();

                if (!weekEntries.Any())
                {
                    Logger.Warning("TimeViewModel", "No time entries found for current week");
                    MessageBox.Show("No time entries found for the current week.", "Export Timesheet", 
                        MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }

                // Group by Id1 and Id2 combination
                var groupedEntries = weekEntries
                    .GroupBy(entry => new { entry.Id1, entry.Id2 })
                    .ToList();

                var exportLines = new StringBuilder();

                foreach (var group in groupedEntries)
                {
                    var id1 = group.Key.Id1;
                    var id2 = group.Key.Id2;
                    
                    // Skip entries without Id2 (generic timecodes)
                    if (!id2.HasValue)
                    {
                        Logger.Debug("TimeViewModel", $"Skipping generic timecode Id1={id1}");
                        continue;
                    }

                    // Calculate daily hours (Mon-Fri)
                    var dailyHours = new decimal[5]; // Mon=0, Tue=1, Wed=2, Thu=3, Fri=4
                    
                    foreach (var entry in group)
                    {
                        var dayOfWeek = entry.Date.DayOfWeek;
                        if (dayOfWeek >= DayOfWeek.Monday && dayOfWeek <= DayOfWeek.Friday)
                        {
                            var dayIndex = (int)dayOfWeek - 1; // Monday = 0
                            dailyHours[dayIndex] += entry.Hours;
                        }
                    }

                    // Skip if no hours for this project
                    if (dailyHours.All(h => h == 0))
                        continue;

                    // Format Id2 with special formatting: V + padded zeros + Id2 + S (total length 12)
                    var id2String = id2.Value.ToString();
                    var paddingLength = 10 - id2String.Length; // V..S takes 2 chars, so 12-2=10 for the number part
                    if (paddingLength < 0) paddingLength = 0; // Don't pad if Id2 is already too long
                    
                    var formattedId2 = $"V{new string('0', paddingLength)}{id2String}S";
                    
                    Logger.Debug("TimeViewModel", $"Formatted Id2: {id2.Value} → {formattedId2}");

                    // Build the export line: id1,tab,formattedId2,tab,tab,tab,tab,mon,tab,tue,tab,wed,tab,thu,tab,fri
                    var line = $"{id1}\t{formattedId2}\t\t\t\t{dailyHours[0]}\t{dailyHours[1]}\t{dailyHours[2]}\t{dailyHours[3]}\t{dailyHours[4]}";
                    exportLines.AppendLine(line);
                    
                    Logger.Debug("TimeViewModel", $"Export line: {line.Replace('\t', '|')}"); // Replace tabs with pipes for logging
                }

                if (exportLines.Length == 0)
                {
                    Logger.Warning("TimeViewModel", "No valid project entries found for export");
                    MessageBox.Show("No valid project entries found for export.", "Export Timesheet", 
                        MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }

                // Copy to clipboard
                var exportText = exportLines.ToString().TrimEnd();
                Clipboard.SetText(exportText);
                
                Logger.Info("TimeViewModel", $"Exported {groupedEntries.Count} project entries to clipboard");
                
                MessageBox.Show($"Weekly timesheet exported to clipboard!\n\nExported {groupedEntries.Count} project entries for week of {weekStart:MMM dd, yyyy}", 
                    "Export Complete", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                Logger.Error("TimeViewModel", "Error exporting weekly timesheet", ex);
                MessageBox.Show($"Error exporting timesheet: {ex.Message}", "Export Error", 
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }

            Logger.TraceExit();
        }

        #endregion

        #region Helper Methods

        private DateTime GetMondayOfCurrentWeek()
        {
            var today = DateTime.Today;
            var daysFromMonday = (int)today.DayOfWeek - (int)DayOfWeek.Monday;
            if (daysFromMonday < 0) daysFromMonday += 7; // Handle Sunday
            return today.AddDays(-daysFromMonday);
        }

        private void RefreshAvailableProjects()
        {
            Logger.TraceEnter();
            AvailableProjects.Clear();
            
            var projects = _timeDataService.GetAvailableProjects();
            foreach (var project in projects)
            {
                AvailableProjects.Add(project);
            }
            
            Logger.Debug("TimeViewModel", $"Refreshed {AvailableProjects.Count} available projects");
            Logger.TraceExit();
        }

        private void RefreshCurrentWeekData()
        {
            OnPropertyChanged(nameof(CurrentWeekEntries));
            OnPropertyChanged(nameof(DayTotal));
            OnPropertyChanged(nameof(WeekTotal));
        }

        #endregion

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            Logger.Trace("TimeViewModel", $"PropertyChanged: {propertyName}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}