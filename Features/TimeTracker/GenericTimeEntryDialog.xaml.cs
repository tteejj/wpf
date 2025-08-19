using System;
using System.Windows;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TimeTracker
{
    public partial class GenericTimeEntryDialog : Window
    {
        public int TimecodeId { get; set; } = 1000; // Default generic timecode starting point
        public decimal Hours { get; set; } = 1.0m;
        public string Description { get; set; } = string.Empty;
        public DateTime Date { get; set; }

        public GenericTimeEntryDialog(DateTime date)
        {
            Logger.TraceEnter();
            
            InitializeComponent();
            Date = date;
            
            // Populate hours dropdown with 0.25 increments
            for (decimal h = 0.25m; h <= 24.0m; h += 0.25m)
            {
                HoursComboBox.Items.Add(h);
            }
            HoursComboBox.SelectedItem = 1.0m;
            
            // Set data context for binding
            DataContext = this;
            
            // Focus the timecode textbox
            TimecodeTextBox.Focus();
            TimecodeTextBox.SelectAll();
            
            Logger.Info("GenericTimeEntryDialog", $"Dialog initialized for date {date:yyyy-MM-dd}");
            Logger.TraceExit();
        }

        private void AddButton_Click(object sender, RoutedEventArgs e)
        {
            Logger.TraceEnter();
            
            if (!int.TryParse(TimecodeTextBox.Text, out int timecodeId) || timecodeId <= 0)
            {
                MessageBox.Show("Please enter a valid timecode ID (positive number).", "Invalid Timecode ID", 
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                TimecodeTextBox.Focus();
                TimecodeTextBox.SelectAll();
                return;
            }

            if (HoursComboBox.SelectedItem == null || (decimal)HoursComboBox.SelectedItem <= 0)
            {
                MessageBox.Show("Please select valid hours.", "Invalid Hours", 
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            TimecodeId = timecodeId;
            Hours = (decimal)HoursComboBox.SelectedItem;
            Description = DescriptionTextBox.Text ?? string.Empty;

            Logger.Info("GenericTimeEntryDialog", 
                $"Generic time entry confirmed: {TimecodeId} - {Hours}h - '{Description}'");

            DialogResult = true;
            Close();
            
            Logger.TraceExit();
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            Logger.TraceEnter();
            Logger.Info("GenericTimeEntryDialog", "Dialog cancelled");
            DialogResult = false;
            Close();
            Logger.TraceExit();
        }
    }
}