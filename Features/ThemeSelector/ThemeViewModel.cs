using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Windows.Input;
using PraxisWpf.Commands;
using PraxisWpf.Services;

namespace PraxisWpf.Features.ThemeSelector
{
    public class ThemeViewModel : INotifyPropertyChanged
    {
        private readonly ThemeService _themeService;
        private ThemeInfo? _selectedTheme;

        public ObservableCollection<ThemeInfo> AvailableThemes { get; private set; }
        public ICommand ApplyThemeCommand { get; }
        public ICommand RefreshThemesCommand { get; }

        public ThemeViewModel()
        {
            Logger.TraceEnter();
            
            _themeService = new ThemeService();
            AvailableThemes = new ObservableCollection<ThemeInfo>();
            
            ApplyThemeCommand = new RelayCommand(ExecuteApplyTheme, CanExecuteApplyTheme);
            RefreshThemesCommand = new RelayCommand(ExecuteRefreshThemes);

            LoadThemes();
            
            Logger.Info("ThemeViewModel", "ThemeViewModel initialized successfully");
            Logger.TraceExit();
        }

        public ThemeInfo? SelectedTheme
        {
            get => _selectedTheme;
            set
            {
                if (_selectedTheme != value)
                {
                    _selectedTheme = value;
                    OnPropertyChanged(nameof(SelectedTheme));
                    Logger.Info("ThemeViewModel", $"Selected theme changed to: {value?.Name ?? "null"}");
                }
            }
        }

        public string CurrentThemeName => _themeService.CurrentTheme;

        private void LoadThemes()
        {
            Logger.TraceEnter();
            
            try
            {
                AvailableThemes.Clear();
                
                foreach (var themeName in _themeService.AvailableThemes)
                {
                    var themeInfo = _themeService.GetThemeInfo(themeName);
                    AvailableThemes.Add(themeInfo);
                    
                    // Set the current theme as selected
                    if (themeInfo.IsActive)
                    {
                        _selectedTheme = themeInfo;
                        OnPropertyChanged(nameof(SelectedTheme));
                    }
                }
                
                Logger.Info("ThemeViewModel", $"Loaded {AvailableThemes.Count} themes");
                OnPropertyChanged(nameof(CurrentThemeName));
            }
            catch (System.Exception ex)
            {
                Logger.Error("ThemeViewModel", $"Failed to load themes: {ex.Message}");
            }
            
            Logger.TraceExit();
        }

        private void ExecuteApplyTheme()
        {
            Logger.TraceEnter();
            
            if (SelectedTheme == null)
            {
                Logger.Warning("ThemeViewModel", "No theme selected to apply");
                return;
            }

            try
            {
                var success = _themeService.ApplyTheme(SelectedTheme.Name);
                
                if (success)
                {
                    Logger.Info("ThemeViewModel", $"Successfully applied theme: {SelectedTheme.Name}");
                    _themeService.SaveCurrentTheme();
                    
                    // Refresh theme list to update active status
                    LoadThemes();
                }
                else
                {
                    Logger.Error("ThemeViewModel", $"Failed to apply theme: {SelectedTheme.Name}");
                }
            }
            catch (System.Exception ex)
            {
                Logger.Error("ThemeViewModel", $"Error applying theme: {ex.Message}");
            }
            
            Logger.TraceExit();
        }

        private bool CanExecuteApplyTheme()
        {
            return SelectedTheme != null && !SelectedTheme.IsActive;
        }

        private void ExecuteRefreshThemes()
        {
            Logger.TraceEnter();
            Logger.Info("ThemeViewModel", "Refreshing theme list");
            LoadThemes();
            Logger.TraceExit();
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            Logger.Trace("ThemeViewModel", $"PropertyChanged: {propertyName}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}