using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;

namespace PraxisWpf.Services
{
    public class ThemeService
    {
        private readonly Dictionary<string, string> _availableThemes;
        private string _currentTheme = "Cyberpunk";

        public ThemeService()
        {
            Logger.TraceEnter();
            
            _availableThemes = new Dictionary<string, string>
            {
                { "Cyberpunk", "Themes/Cyberpunk.xaml" },
                { "Green Console", "Themes/GreenConsole.xaml" },
                { "Amber Console", "Themes/AmberConsole.xaml" },
                { "Blue Matrix", "Themes/BlueMatrix.xaml" },
                { "High Contrast", "Themes/HighContrast.xaml" }
            };
            
            Logger.Info("ThemeService", $"Initialized with {_availableThemes.Count} available themes");
            Logger.TraceExit();
        }

        /// <summary>
        /// Gets all available theme names
        /// </summary>
        public IEnumerable<string> AvailableThemes => _availableThemes.Keys;

        /// <summary>
        /// Gets the current active theme name
        /// </summary>
        public string CurrentTheme => _currentTheme;

        /// <summary>
        /// Applies a theme by name
        /// </summary>
        public bool ApplyTheme(string themeName)
        {
            Logger.TraceEnter($"themeName={themeName}");
            
            if (string.IsNullOrWhiteSpace(themeName))
            {
                Logger.Warning("ThemeService", "Theme name is null or empty");
                return false;
            }

            if (!_availableThemes.ContainsKey(themeName))
            {
                Logger.Warning("ThemeService", $"Theme '{themeName}' not found in available themes");
                return false;
            }

            try
            {
                var themeUri = _availableThemes[themeName];
                Logger.Info("ThemeService", $"Applying theme '{themeName}' from '{themeUri}'");

                // Get the application's current merged dictionaries
                var app = Application.Current;
                if (app?.Resources?.MergedDictionaries == null)
                {
                    Logger.Error("ThemeService", "Application resources or merged dictionaries are null");
                    return false;
                }

                // Remove existing theme resource dictionaries
                var existingThemes = app.Resources.MergedDictionaries
                    .Where(rd => rd.Source != null && rd.Source.OriginalString.StartsWith("Themes/"))
                    .ToList();

                foreach (var existingTheme in existingThemes)
                {
                    Logger.Debug("ThemeService", $"Removing existing theme: {existingTheme.Source?.OriginalString}");
                    app.Resources.MergedDictionaries.Remove(existingTheme);
                }

                // Load and add the new theme
                var newThemeDict = new ResourceDictionary
                {
                    Source = new Uri(themeUri, UriKind.Relative)
                };

                app.Resources.MergedDictionaries.Add(newThemeDict);
                _currentTheme = themeName;

                Logger.Info("ThemeService", $"Successfully applied theme '{themeName}'");
                Logger.TraceExit();
                return true;
            }
            catch (Exception ex)
            {
                Logger.Error("ThemeService", $"Failed to apply theme '{themeName}': {ex.Message}");
                Logger.TraceExit();
                return false;
            }
        }

        /// <summary>
        /// Gets theme information for display
        /// </summary>
        public ThemeInfo GetThemeInfo(string themeName)
        {
            Logger.TraceEnter($"themeName={themeName}");
            
            if (!_availableThemes.ContainsKey(themeName))
            {
                Logger.Warning("ThemeService", $"Theme '{themeName}' not found");
                return new ThemeInfo { Name = themeName, Description = "Theme not found" };
            }

            var description = themeName switch
            {
                "Cyberpunk" => "Bright cyan/green on black with glow effects",
                "Green Console" => "Classic green terminal text on black background",
                "Amber Console" => "Vintage amber terminal text on black background",
                "Blue Matrix" => "Blue/cyan matrix style with bright highlights",
                "High Contrast" => "Maximum contrast white on black for accessibility",
                _ => "Custom theme"
            };

            var result = new ThemeInfo 
            { 
                Name = themeName, 
                Description = description,
                FilePath = _availableThemes[themeName],
                IsActive = themeName == _currentTheme
            };

            Logger.TraceExit();
            return result;
        }

        /// <summary>
        /// Saves the current theme preference
        /// </summary>
        public void SaveCurrentTheme()
        {
            Logger.TraceEnter();
            
            try
            {
                // For now, we'll just log. Later this could write to settings file
                Logger.Info("ThemeService", $"Saving current theme preference: {_currentTheme}");
                
                // TODO: Implement settings persistence
                // var settings = new { CurrentTheme = _currentTheme };
                // File.WriteAllText("themes.json", JsonSerializer.Serialize(settings));
            }
            catch (Exception ex)
            {
                Logger.Error("ThemeService", $"Failed to save current theme: {ex.Message}");
            }
            
            Logger.TraceExit();
        }

        /// <summary>
        /// Loads the saved theme preference
        /// </summary>
        public void LoadSavedTheme()
        {
            Logger.TraceEnter();
            
            try
            {
                // TODO: Implement settings persistence
                // if (File.Exists("themes.json"))
                // {
                //     var json = File.ReadAllText("themes.json");
                //     var settings = JsonSerializer.Deserialize<dynamic>(json);
                //     var savedTheme = settings.CurrentTheme?.ToString();
                //     if (!string.IsNullOrEmpty(savedTheme) && _availableThemes.ContainsKey(savedTheme))
                //     {
                //         ApplyTheme(savedTheme);
                //     }
                // }
                
                Logger.Info("ThemeService", $"Current theme remains: {_currentTheme}");
            }
            catch (Exception ex)
            {
                Logger.Error("ThemeService", $"Failed to load saved theme: {ex.Message}");
            }
            
            Logger.TraceExit();
        }
    }

    /// <summary>
    /// Information about a theme
    /// </summary>
    public class ThemeInfo
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string FilePath { get; set; } = string.Empty;
        public bool IsActive { get; set; }
    }
}