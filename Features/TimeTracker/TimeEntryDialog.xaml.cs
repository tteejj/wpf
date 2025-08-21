using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Input;

namespace PraxisWpf.Features.TimeTracker
{
    public enum TimeEntryType { Generic, Project }

    public partial class TimeEntryDialog : Window, INotifyPropertyChanged
    {
        private bool _isProjectEntry;
        private string _headerText = string.Empty;
        private object? _selectedProject;
        private int _timecodeId = 1000;
        private decimal _hours = 1.0m;
        private string _description = string.Empty;

        public DateTime Date { get; set; }
        public ObservableCollection<(int Id1, int? Id2, string Name)> AvailableProjects { get; set; } = new();

        public bool IsProjectEntry 
        { 
            get => _isProjectEntry; 
            set { _isProjectEntry = value; OnPropertyChanged(nameof(IsProjectEntry)); OnPropertyChanged(nameof(IsGenericEntry)); }
        }

        public bool IsGenericEntry => !IsProjectEntry;

        public string HeaderText 
        { 
            get => _headerText; 
            set { _headerText = value; OnPropertyChanged(nameof(HeaderText)); }
        }

        public object? SelectedProject 
        { 
            get => _selectedProject; 
            set { _selectedProject = value; OnPropertyChanged(nameof(SelectedProject)); }
        }

        public int TimecodeId 
        { 
            get => _timecodeId; 
            set { _timecodeId = value; OnPropertyChanged(nameof(TimecodeId)); }
        }

        public decimal Hours 
        { 
            get => _hours; 
            set { _hours = value; OnPropertyChanged(nameof(Hours)); }
        }

        public string Description 
        { 
            get => _description; 
            set { _description = value; OnPropertyChanged(nameof(Description)); }
        }

        // Generic constructor
        public TimeEntryDialog(DateTime date) : this(TimeEntryType.Generic, date, null) { }

        // Project constructor  
        public TimeEntryDialog(DateTime date, ObservableCollection<(int Id1, int? Id2, string Name)> availableProjects) 
            : this(TimeEntryType.Project, date, availableProjects) { }

        private TimeEntryDialog(TimeEntryType entryType, DateTime date, ObservableCollection<(int Id1, int? Id2, string Name)>? availableProjects)
        {
            InitializeComponent();
            
            Date = date;
            IsProjectEntry = entryType == TimeEntryType.Project;
            HeaderText = IsProjectEntry ? "╔═══ ADD PROJECT TIME ENTRY ═══╗" : "╔═══ ADD GENERIC TIME ENTRY ═══╗";
            
            if (availableProjects != null)
                AvailableProjects = availableProjects;

            // Populate hours dropdown with 0.25 increments
            for (decimal h = 0.25m; h <= 24.0m; h += 0.25m)
            {
                HoursComboBox.Items.Add(h);
            }
            HoursComboBox.SelectedItem = 1.0m;

            DataContext = this;
            
            // Focus appropriate control
            Loaded += (s, e) => {
                if (IsProjectEntry)
                    ProjectListBox?.Focus();
                else
                    TimecodeTextBox?.Focus();
            };
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            switch (e.Key)
            {
                case Key.Enter:
                    DialogResult = true;
                    e.Handled = true;
                    break;
                case Key.Escape:
                    DialogResult = false;
                    e.Handled = true;
                    break;
            }
            base.OnKeyDown(e);
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        protected virtual void OnPropertyChanged(string propertyName) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}