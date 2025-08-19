using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Windows;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TimeTracker
{
    public partial class ProjectTimeEntryDialog : Window
    {
        public (int Id1, int? Id2, string Name)? SelectedProject { get; set; }
        public decimal Hours { get; set; } = 1.0m;
        public string Description { get; set; } = string.Empty;
        public DateTime Date { get; set; }

        public ProjectTimeEntryDialog(ObservableCollection<(int Id1, int? Id2, string Name)> availableProjects, DateTime date)
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
            
            // Set up project list
            ProjectListBox.ItemsSource = availableProjects.Where(p => p.Id2.HasValue).ToList(); // Only projects, not generic codes
            
            // Set data context for binding
            DataContext = this;
            
            // Focus the project list
            ProjectListBox.Focus();
            
            Logger.Info("ProjectTimeEntryDialog", $"Dialog initialized for date {date:yyyy-MM-dd} with {availableProjects.Count} projects");
            Logger.TraceExit();
        }

        private void AddButton_Click(object sender, RoutedEventArgs e)
        {
            Logger.TraceEnter();
            
            if (ProjectListBox.SelectedItem == null)
            {
                MessageBox.Show("Please select a project.", "No Project Selected", 
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (HoursComboBox.SelectedItem == null || (decimal)HoursComboBox.SelectedItem <= 0)
            {
                MessageBox.Show("Please select valid hours.", "Invalid Hours", 
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            SelectedProject = ((int Id1, int? Id2, string Name))ProjectListBox.SelectedItem;
            Hours = (decimal)HoursComboBox.SelectedItem;
            Description = DescriptionTextBox.Text ?? string.Empty;

            Logger.Info("ProjectTimeEntryDialog", 
                $"Project time entry confirmed: {SelectedProject.Value.Id1}.{SelectedProject.Value.Id2} - {Hours}h - '{Description}'");

            DialogResult = true;
            Close();
            
            Logger.TraceExit();
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            Logger.TraceEnter();
            Logger.Info("ProjectTimeEntryDialog", "Dialog cancelled");
            DialogResult = false;
            Close();
            Logger.TraceExit();
        }
    }
}