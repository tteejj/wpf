using System.Windows.Controls;
using System.Windows.Input;
using PraxisWpf.Services;

namespace PraxisWpf.Features.DataProcessing
{
    public partial class DataProcessingView : UserControl
    {
        public DataProcessingView()
        {
            Logger.TraceEnter();
            try
            {
                using var perfTracker = Logger.TracePerformance("DataProcessingView Constructor");
                
                Logger.Debug("DataProcessingView", "Initializing XAML components");
                InitializeComponent();
                
                // Set up key handling
                Loaded += DataProcessingView_Loaded;
                
                Logger.Info("DataProcessingView", "DataProcessingView initialized successfully");
                Logger.TraceExit();
            }
            catch (System.Exception ex)
            {
                Logger.Critical("DataProcessingView", "Failed to initialize DataProcessingView", ex);
                Logger.TraceExit();
                throw;
            }
        }

        private void DataProcessingView_Loaded(object sender, System.Windows.RoutedEventArgs e)
        {
            Logger.TraceEnter();
            
            // Ensure this control can receive key events
            var focusResult = Focus();
            Logger.Critical("DataProcessingView", $"🔥 DATAPROCESSINGVIEW FOCUS ON LOAD: Success={focusResult}, IsFocused={IsFocused}, IsKeyboardFocused={IsKeyboardFocused}");
            
            Logger.TraceExit();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            Logger.Critical("DataProcessingView", $"🔥 DATAPROCESSINGVIEW KEYDOWN: Key={e.Key}, Handled={e.Handled}");
            
            try
            {
                switch (e.Key)
                {
                    case Key.Escape:
                        // Escape key goes back to task view
                        Logger.Critical("DataProcessingView", "🔥 ESCAPE KEY - SWITCHING TO TASKS");
                        var mainWindow = System.Windows.Window.GetWindow(this) as MainWindow;
                        if (mainWindow != null)
                        {
                            Logger.Critical("DataProcessingView", "🔥 ESCAPE KEY - EXECUTING SHOW TASKS");
                            mainWindow.ShowTasks();
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Critical("DataProcessingView", "🔥 ESCAPE KEY - MAIN WINDOW NOT FOUND!");
                        }
                        break;

                    case Key.H:
                        // H key opens theme selection screen
                        Logger.Critical("DataProcessingView", "🔥 H KEY - SWITCHING TO THEMES");
                        var themeMainWindow = System.Windows.Window.GetWindow(this) as MainWindow;
                        if (themeMainWindow != null)
                        {
                            themeMainWindow.ShowThemes();
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Critical("DataProcessingView", "🔥 H KEY - MAIN WINDOW NOT FOUND!");
                        }
                        break;
                }

                base.OnKeyDown(e);
                Logger.TraceExit();
            }
            catch (System.Exception ex)
            {
                Logger.Error("DataProcessingView", "Error handling key down", ex);
                Logger.TraceExit();
            }
        }
    }
}