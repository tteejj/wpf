using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using PraxisWpf.Models;

namespace PraxisWpf.Interfaces
{
    public interface ITimeDataService
    {
        /// <summary>
        /// Load all time entries from storage
        /// </summary>
        ObservableCollection<TimeEntry> LoadTimeEntries();

        /// <summary>
        /// Save all time entries to storage
        /// </summary>
        void SaveTimeEntries(ObservableCollection<TimeEntry> timeEntries);

        /// <summary>
        /// Get time entries for a specific date
        /// </summary>
        IEnumerable<TimeEntry> GetTimeEntriesForDate(DateTime date);

        /// <summary>
        /// Get time entries for a specific week (Monday to Friday)
        /// </summary>
        IEnumerable<TimeEntry> GetTimeEntriesForWeek(DateTime weekStartDate);

        /// <summary>
        /// Get time entries for a specific project
        /// </summary>
        IEnumerable<TimeEntry> GetTimeEntriesForProject(int id1, int? id2);

        /// <summary>
        /// Calculate total hours for a project for a specific week
        /// </summary>
        decimal GetProjectWeekTotal(int id1, int? id2, DateTime weekStartDate);

        /// <summary>
        /// Calculate total hours for a specific day
        /// </summary>
        decimal GetDayTotal(DateTime date);

        /// <summary>
        /// Calculate total hours for a specific week
        /// </summary>
        decimal GetWeekTotal(DateTime weekStartDate);

        /// <summary>
        /// Get all project summaries for a specific week
        /// </summary>
        IEnumerable<TimeSummary> GetWeekSummariesByProject(DateTime weekStartDate);

        /// <summary>
        /// Get available projects from the task system for reference
        /// </summary>
        IEnumerable<(int Id1, int? Id2, string Name)> GetAvailableProjects();
    }
}