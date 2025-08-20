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
                        break;

                    case Key.N:
                        // N key creates new project
                        Logger.Critical("DataProcessingView", "🔥 N KEY - CREATING NEW PROJECT");
                        if (DataContext is DataProcessingViewModel viewModel)
                        {
                            viewModel.CreateProjectCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.S:
                        // S key saves current project
                        Logger.Critical("DataProcessingView", "🔥 S KEY - SAVING PROJECT");
                        if (DataContext is DataProcessingViewModel saveViewModel)
                        {
                            if (saveViewModel.SaveProjectCommand.CanExecute(null))
                            {
                                saveViewModel.SaveProjectCommand.Execute(null);
                            }
                            e.Handled = true;
                        }
                        break;

                    case Key.D:
                        // D key deletes current project
                        Logger.Critical("DataProcessingView", "🔥 D KEY - DELETING PROJECT");
                        if (DataContext is DataProcessingViewModel deleteViewModel)
                        {
                            if (deleteViewModel.DeleteProjectCommand.CanExecute(null))
                            {
                                deleteViewModel.DeleteProjectCommand.Execute(null);
                            }
                            e.Handled = true;
                        }
                        break;

                    case Key.R:
                        // R key refreshes project list
                        Logger.Critical("DataProcessingView", "🔥 R KEY - REFRESHING PROJECTS");
                        if (DataContext is DataProcessingViewModel refreshViewModel)
                        {
                            refreshViewModel.RefreshProjectsCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.I:
                        // I key imports Excel data
                        Logger.Critical("DataProcessingView", "🔥 I KEY - IMPORTING EXCEL");
                        if (DataContext is DataProcessingViewModel importViewModel)
                        {
                            importViewModel.ImportExcelCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.T:
                        // T key creates Excel template
                        Logger.Critical("DataProcessingView", "🔥 T KEY - CREATING TEMPLATE");
                        if (DataContext is DataProcessingViewModel templateViewModel)
                        {
                            templateViewModel.CreateTemplateCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.E:
                        // E key exports current project
                        Logger.Critical("DataProcessingView", "🔥 E KEY - EXPORTING PROJECT");
                        if (DataContext is DataProcessingViewModel exportViewModel)
                        {
                            exportViewModel.ExportDataCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.A:
                        // A key exports all projects
                        Logger.Critical("DataProcessingView", "🔥 A KEY - EXPORTING ALL PROJECTS");
                        if (DataContext is DataProcessingViewModel exportAllViewModel)
                        {
                            exportAllViewModel.ExportAllProjectsCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.M:
                        // M key opens Excel mapping dialog
                        Logger.Critical("DataProcessingView", "🔥 M KEY - OPENING EXCEL MAPPING");
                        if (DataContext is DataProcessingViewModel mappingViewModel)
                        {
                            mappingViewModel.OpenExcelMappingCommand.Execute(null);
                            e.Handled = true;
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