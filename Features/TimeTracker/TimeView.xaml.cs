using System.Windows.Controls;
using System.Windows.Input;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TimeTracker
{
    public partial class TimeView : UserControl
    {
        public TimeView()
        {
            Logger.TraceEnter();
            try
            {
                using var perfTracker = Logger.TracePerformance("TimeView Constructor");
                
                Logger.Debug("TimeView", "Initializing XAML components");
                InitializeComponent();
                
                // Set up key handling
                Loaded += TimeView_Loaded;
                
                Logger.Info("TimeView", "TimeView initialized successfully");
                Logger.TraceExit();
            }
            catch (System.Exception ex)
            {
                Logger.Critical("TimeView", "Failed to initialize TimeView", ex);
                Logger.TraceExit();
                throw;
            }
        }

        private void TimeView_Loaded(object sender, System.Windows.RoutedEventArgs e)
        {
            Logger.TraceEnter();
            
            // Ensure this control can receive key events
            var focusResult = Focus();
            Logger.Critical("TimeView", $"🔥 TIMEVIEW FOCUS ON LOAD: Success={focusResult}, IsFocused={IsFocused}, IsKeyboardFocused={IsKeyboardFocused}");
            
            Logger.TraceExit();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            Logger.Critical("TimeView", $"🔥 TIMEVIEW KEYDOWN: Key={e.Key}, Handled={e.Handled}");
            
            try
            {
                var viewModel = DataContext as TimeViewModel;
                
                switch (e.Key)
                {
                    case Key.Escape:
                        // Escape key goes back to task view
                        Logger.Critical("TimeView", "🔥 ESCAPE KEY - SWITCHING TO TASKS");
                        var mainWindow = System.Windows.Window.GetWindow(this) as MainWindow;
                        if (mainWindow != null)
                        {
                            Logger.Critical("TimeView", "🔥 ESCAPE KEY - EXECUTING SHOW TASKS");
                            mainWindow.ShowTasks();
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Critical("TimeView", "🔥 ESCAPE KEY - MAIN WINDOW NOT FOUND!");
                        }
                        break;

                    case Key.P:
                        // P key adds project time entry inline
                        Logger.Critical("TimeView", "🔥 P KEY - ADD PROJECT TIME INLINE");
                        if (viewModel?.AddProjectTimeInlineCommand.CanExecute(null) == true)
                        {
                            viewModel.AddProjectTimeInlineCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.N:
                        // N key adds generic/non-project time entry inline
                        Logger.Critical("TimeView", "🔥 N KEY - ADD GENERIC TIME INLINE");
                        if (viewModel?.AddGenericTimeInlineCommand.CanExecute(null) == true)
                        {
                            viewModel.AddGenericTimeInlineCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.Delete:
                        // Delete key removes selected time entry
                        Logger.Critical("TimeView", "🔥 DELETE KEY - REMOVE TIME ENTRY");
                        if (viewModel?.DeleteTimeEntryCommand.CanExecute(null) == true)
                        {
                            viewModel.DeleteTimeEntryCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.S:
                        // Ctrl+S saves time data
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            Logger.Critical("TimeView", "🔥 CTRL+S - SAVE TIME DATA");
                            if (viewModel?.SaveCommand.CanExecute(null) == true)
                            {
                                viewModel.SaveCommand.Execute(null);
                                e.Handled = true;
                            }
                        }
                        break;

                    case Key.E:
                        // E key exports weekly timesheet to clipboard
                        Logger.Critical("TimeView", "🔥 E KEY - EXPORT WEEKLY TIMESHEET");
                        if (viewModel?.ExportWeeklyTimesheetCommand.CanExecute(null) == true)
                        {
                            viewModel.ExportWeeklyTimesheetCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.H:
                        // H key opens theme selection screen
                        Logger.Critical("TimeView", "🔥 H KEY - SWITCHING TO THEMES");
                        var themeMainWindow = System.Windows.Window.GetWindow(this) as MainWindow;
                        if (themeMainWindow != null)
                        {
                            themeMainWindow.ShowThemes();
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Critical("TimeView", "🔥 H KEY - MAIN WINDOW NOT FOUND!");
                        }
                        break;
                }

                if (!e.Handled)
                {
                    base.OnKeyDown(e);
                }
            }
            catch (System.Exception ex)
            {
                Logger.Error("TimeView", "Error handling key down", ex);
            }
        }
    }
}