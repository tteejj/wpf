using System.Linq;
using System.Windows.Controls;
using System.Windows.Input;
using PraxisWpf.Services;

namespace PraxisWpf.Features.ThemeSelector
{
    public partial class ThemeView : UserControl
    {
        public ThemeView()
        {
            Logger.TraceEnter();
            try
            {
                using var perfTracker = Logger.TracePerformance("ThemeView Constructor");
                
                Logger.Debug("ThemeView", "Initializing XAML components");
                InitializeComponent();
                
                // Set up key handling
                Loaded += ThemeView_Loaded;
                
                Logger.Info("ThemeView", "ThemeView initialized successfully");
                Logger.TraceExit();
            }
            catch (System.Exception ex)
            {
                Logger.Critical("ThemeView", "Failed to initialize ThemeView", ex);
                Logger.TraceExit();
                throw;
            }
        }

        private void ThemeView_Loaded(object sender, System.Windows.RoutedEventArgs e)
        {
            Logger.TraceEnter();
            
            // Ensure this control can receive key events
            var focusResult = Focus();
            Logger.Debug("ThemeView", $"ThemeView focus on load: Success={focusResult}, IsFocused={IsFocused}, IsKeyboardFocused={IsKeyboardFocused}");
            
            Logger.TraceExit();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            Logger.Debug("ThemeView", $"ThemeView KeyDown: Key={e.Key}, Handled={e.Handled}");
            
            try
            {
                var viewModel = DataContext as ThemeViewModel;
                
                switch (e.Key)
                {
                    case Key.Escape:
                        // Escape key goes back to task view
                        Logger.Info("ThemeView", "Escape key - switching back to tasks");
                        var mainWindow = System.Windows.Window.GetWindow(this) as MainWindow;
                        if (mainWindow != null)
                        {
                            mainWindow.ShowTasks();
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Warning("ThemeView", "MainWindow not found for navigation");
                        }
                        break;

                    case Key.A:
                        // A key applies the selected theme
                        Logger.Info("ThemeView", "A key - applying selected theme");
                        if (viewModel?.ApplyThemeCommand.CanExecute(null) == true)
                        {
                            viewModel.ApplyThemeCommand.Execute(null);
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Info("ThemeView", "Cannot apply theme - no theme selected or theme already active");
                        }
                        break;

                    case Key.R:
                        // R key refreshes the theme list
                        Logger.Info("ThemeView", "R key - refreshing themes");
                        if (viewModel?.RefreshThemesCommand.CanExecute(null) == true)
                        {
                            viewModel.RefreshThemesCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.D1:
                    case Key.NumPad1:
                        // Number keys select themes by index
                        SelectThemeByIndex(0, viewModel);
                        e.Handled = true;
                        break;

                    case Key.D2:
                    case Key.NumPad2:
                        SelectThemeByIndex(1, viewModel);
                        e.Handled = true;
                        break;

                    case Key.D3:
                    case Key.NumPad3:
                        SelectThemeByIndex(2, viewModel);
                        e.Handled = true;
                        break;

                    case Key.D4:
                    case Key.NumPad4:
                        SelectThemeByIndex(3, viewModel);
                        e.Handled = true;
                        break;

                    case Key.D5:
                    case Key.NumPad5:
                        SelectThemeByIndex(4, viewModel);
                        e.Handled = true;
                        break;
                }

                if (!e.Handled)
                {
                    base.OnKeyDown(e);
                }
            }
            catch (System.Exception ex)
            {
                Logger.Error("ThemeView", "Error handling key down", ex);
            }
        }

        private void SelectThemeByIndex(int index, ThemeViewModel? viewModel)
        {
            if (viewModel?.AvailableThemes == null || index < 0 || index >= viewModel.AvailableThemes.Count)
            {
                Logger.Warning("ThemeView", $"Cannot select theme at index {index} - out of range or no viewmodel");
                return;
            }

            var theme = viewModel.AvailableThemes.ElementAtOrDefault(index);
            if (theme != null)
            {
                viewModel.SelectedTheme = theme;
                Logger.Info("ThemeView", $"Selected theme by number key: {theme.Name}");
            }
        }

        protected override void OnMouseUp(MouseButtonEventArgs e)
        {
            try
            {
                Logger.Debug("ThemeView", "Mouse click on ThemeView - setting focus");
                
                // When clicking anywhere in the theme view, ensure it has focus for keyboard navigation
                if (!IsFocused && !IsKeyboardFocused)
                {
                    Focus();
                }

                // Check if we clicked on a theme item to select it
                var clickedElement = e.OriginalSource as System.Windows.FrameworkElement;
                var themeInfo = clickedElement?.DataContext as ThemeInfo;
                
                if (themeInfo != null && DataContext is ThemeViewModel viewModel)
                {
                    viewModel.SelectedTheme = themeInfo;
                    Logger.Info("ThemeView", $"Theme selected by mouse click: {themeInfo.Name}");
                }

                base.OnMouseUp(e);
            }
            catch (System.Exception ex)
            {
                Logger.Error("ThemeView", "Error handling mouse click", ex);
            }
        }
    }
}