using System.Collections.Generic;
using System.Windows;

namespace PraxisWpf.Services
{
    public static class HotkeyHelper
    {
        public static class Tasks
        {
            public static readonly Dictionary<string, string> Hotkeys = new()
            {
                { "N", "New Task" },
                { "P", "New Project" },
                { "S", "New Subtask" },
                { "E", "Edit Task" },
                { "Del", "Delete Task" },
                { "O", "Open Notes" },
                { "Shift+O", "Open Notes 2" },
                { "Enter/Space", "Toggle Edit" },
                { "F2", "Edit Mode" },
                { "+", "Expand Item" },
                { "-", "Collapse Item" },
                { "Ctrl++", "Expand All" },
                { "Ctrl+-", "Collapse All" },
                { "←/→", "Collapse/Expand" },
                { "T", "Time Entry" },
                { "D", "Data Processing" },
                { "H", "Themes" },
                { "Ctrl+S", "Save" },
                { "?/F1", "Show Help" }
            };
        }

        public static class Time
        {
            public static readonly Dictionary<string, string> Hotkeys = new()
            {
                { "Esc", "Back to Tasks" },
                { "P", "Add Project Time" },
                { "N", "Add Generic Time" },
                { "E", "Export Timesheet" },
                { "Del", "Delete Entry" },
                { "H", "Themes" },
                { "Ctrl+S", "Save" },
                { "←/→", "Navigate Weeks" },
                { "?", "Show Help" }
            };
        }

        public static class Data
        {
            public static readonly Dictionary<string, string> Hotkeys = new()
            {
                { "Esc", "Back to Tasks" },
                { "N", "New Project" },
                { "S", "Save Project" },
                { "D", "Delete Project" },
                { "R", "Refresh Projects" },
                { "I", "Import Excel" },
                { "T", "Create Template" },
                { "E", "Export Data" },
                { "M", "Excel Mapping" },
                { "B", "Browse Files" },
                { "H", "Themes" },
                { "?", "Show Help" }
            };
        }

        public static class Themes
        {
            public static readonly Dictionary<string, string> Hotkeys = new()
            {
                { "Esc", "Back to Tasks" },
                { "1-6", "Select Theme" },
                { "A", "Apply Theme" },
                { "R", "Refresh Themes" },
                { "?", "Show Help" }
            };
        }

        public static string GetHelpText(string viewName)
        {
            var hotkeys = viewName switch
            {
                "Tasks" => Tasks.Hotkeys,
                "Time" => Time.Hotkeys,
                "Data" => Data.Hotkeys,
                "Themes" => Themes.Hotkeys,
                _ => new Dictionary<string, string>()
            };

            var lines = new List<string> { $"╔═══ {viewName.ToUpper()} HOTKEYS ═══╗", "" };
            
            foreach (var kvp in hotkeys)
            {
                lines.Add($"  {kvp.Key,-12} {kvp.Value}");
            }
            
            lines.Add("");
            lines.Add("Press any key to close this help...");
            
            return string.Join("\n", lines);
        }
    }
}