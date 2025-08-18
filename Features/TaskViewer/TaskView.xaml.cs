using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using PraxisWpf.Interfaces;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TaskViewer
{
    public partial class TaskView : UserControl
    {
        public TaskView()
        {
            Logger.TraceEnter();
            try
            {
                using var perfTracker = Logger.TracePerformance("TaskView Constructor");
                
                Logger.Debug("TaskView", "Initializing XAML components");
                InitializeComponent();
                
                // Set up foolproof focus management
                Loaded += TaskView_Loaded;
                
                Logger.Info("TaskView", "TaskView initialized successfully");
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Critical("TaskView", "Failed to initialize TaskView", ex);
                Logger.TraceExit();
                throw;
            }
        }

        private void TaskView_Loaded(object sender, System.Windows.RoutedEventArgs e)
        {
            Logger.TraceEnter();
            
            // Ensure TreeView gets focus when control loads (foolproof data focus)
            var focusResult = TaskTreeView.Focus();
            Logger.Critical("TaskView", $"🔥 TREEVIEW FOCUS ON LOAD: Success={focusResult}, IsFocused={TaskTreeView.IsFocused}, IsKeyboardFocused={TaskTreeView.IsKeyboardFocused}");
            
            // Hook window activation to ensure focus returns to data
            var window = System.Windows.Window.GetWindow(this);
            if (window != null)
            {
                window.Activated += Window_Activated;
                Logger.Critical("TaskView", "🔥 WINDOW ACTIVATION HANDLER ATTACHED");
            }
            
            Logger.TraceExit();
        }

        private void Window_Activated(object sender, EventArgs e)
        {
            Logger.TraceEnter();
            
            // When window is activated (Alt+Tab back), ensure TreeView has focus
            TaskTreeView.Focus();
            Logger.Debug("TaskView", "TreeView focused on window activation (foolproof data focus)");
            
            Logger.TraceExit();
        }

        private void TaskTreeView_SelectedItemChanged(object sender, System.Windows.RoutedPropertyChangedEventArgs<object> e)
        {
            Logger.TraceEnter(parameters: new object[] { 
                e.OldValue?.ToString() ?? "null", 
                e.NewValue?.ToString() ?? "null" 
            });

            try
            {
                var viewModel = DataContext as TaskViewModel;
                if (viewModel != null && e.NewValue is IDisplayableItem selectedItem)
                {
                    Logger.Info("TaskView", $"TreeView selection changed to: {selectedItem.DisplayName}");
                    viewModel.SelectedItem = selectedItem;
                    Logger.Debug("TaskView", "ViewModel.SelectedItem updated");
                    
                    // Ensure TreeView has focus for keyboard navigation
                    if (!TaskTreeView.IsFocused)
                    {
                        TaskTreeView.Focus();
                        Logger.Debug("TaskView", "TreeView focused for keyboard navigation");
                    }
                    
                    // Ensure selected item is visible and focused properly
                    if (e.NewValue != null)
                    {
                        // Use Dispatcher to ensure TreeViewItem is generated
                        Dispatcher.BeginInvoke(new Action(() => {
                            var treeViewItem = TaskTreeView.ItemContainerGenerator.ContainerFromItem(e.NewValue) as TreeViewItem;
                            if (treeViewItem != null)
                            {
                                treeViewItem.BringIntoView();
                                treeViewItem.IsSelected = true;
                                Logger.Debug("TaskView", "Selected item brought into view and selected");
                            }
                        }), System.Windows.Threading.DispatcherPriority.Background);
                    }
                }
                else if (e.NewValue == null && viewModel != null)
                {
                    // Handle deselection
                    viewModel.SelectedItem = null;
                    Logger.Debug("TaskView", "Selection cleared");
                }
                else
                {
                    Logger.Warning("TaskView", "Selection change ignored", 
                        $"DataContext is TaskViewModel: {DataContext is TaskViewModel}, " +
                        $"NewValue is IDisplayableItem: {e.NewValue is IDisplayableItem}");
                }
                
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("TaskView", "Error handling selection change", ex);
                Logger.TraceExit();
            }
        }

        public override void OnApplyTemplate()
        {
            base.OnApplyTemplate();
            
            // Ensure TreeView gets initial focus (foolproof data focus)
            Logger.Debug("TaskView", "Applying template and setting foolproof data focus");
            TaskTreeView.Focus();
        }

        private void TaskTreeView_KeyDown(object sender, KeyEventArgs e)
        {
            Logger.Critical("TaskView", $"🔥 TREEVIEW KEYDOWN: Key={e.Key}, Handled={e.Handled}, Source={e.Source?.GetType().Name}, OriginalSource={e.OriginalSource?.GetType().Name}");
            Logger.TraceEnter(parameters: new object[] { e.Key.ToString() });

            try
            {
                var viewModel = DataContext as TaskViewModel;
                if (viewModel == null) 
                {
                    Logger.Critical("TaskView", "🔥 VIEWMODEL IS NULL!");
                    return;
                }
                
                // Check if we're currently in edit mode by looking for focused TextBox
                var focusedTextBox = Keyboard.FocusedElement as TextBox;
                var isInEditMode = focusedTextBox != null && focusedTextBox.Name == "EditTextBox";
                
                Logger.Critical("TaskView", $"🔥 ABOUT TO PROCESS KEY: {e.Key}, IsInEditMode: {isInEditMode}");

                // If we're in edit mode, only allow Enter/Escape to be processed as hotkeys
                if (isInEditMode && e.Key != Key.Enter && e.Key != Key.Escape)
                {
                    Logger.Critical("TaskView", $"🔥 IN EDIT MODE - IGNORING KEY: {e.Key}");
                    return;
                }

                switch (e.Key)
                {
                    case Key.N:
                        Logger.Critical("TaskView", "🔥 N KEY CASE HIT!");
                        // N key creates new task
                        if (viewModel.NewCommand.CanExecute(null))
                        {
                            Logger.Critical("TaskView", "🔥 N KEY - EXECUTING NEW COMMAND");
                            viewModel.NewCommand.Execute(null);
                            Logger.Critical("TaskView", "🔥 N KEY - NEW COMMAND EXECUTED");
                            
                            // Focus the newly created item's TextBox after a brief delay
                            Dispatcher.BeginInvoke(new Action(() => {
                                FocusEditTextBoxForSelectedItem();
                            }), System.Windows.Threading.DispatcherPriority.Render);
                            
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Critical("TaskView", "🔥 N KEY - NEW COMMAND CAN'T EXECUTE!");
                        }
                        break;

                    case Key.P:
                        Logger.Critical("TaskView", "🔥 P KEY CASE HIT!");
                        // P key creates new project
                        if (viewModel.NewProjectCommand.CanExecute(null))
                        {
                            Logger.Critical("TaskView", "🔥 P KEY - EXECUTING NEW PROJECT COMMAND");
                            viewModel.NewProjectCommand.Execute(null);
                            Logger.Critical("TaskView", "🔥 P KEY - NEW PROJECT COMMAND EXECUTED");
                            
                            // Focus the newly created project's TextBox after a brief delay
                            Dispatcher.BeginInvoke(new Action(() => {
                                FocusEditTextBoxForSelectedItem();
                            }), System.Windows.Threading.DispatcherPriority.Render);
                            
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Critical("TaskView", "🔥 P KEY - NEW PROJECT COMMAND CAN'T EXECUTE!");
                        }
                        break;

                    case Key.E:
                        Logger.Critical("TaskView", "🔥 E KEY CASE HIT!");
                        // E key toggles edit mode (simple)
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            Logger.Critical("TaskView", "🔥 E KEY - EXECUTING EDIT COMMAND");
                            var wasInEditMode = viewModel.SelectedItem?.IsInEditMode ?? false;
                            viewModel.EditCommand.Execute(null);
                            Logger.Critical("TaskView", "🔥 E KEY - EDIT COMMAND EXECUTED");
                            
                            // If we just entered edit mode, focus the TextBox
                            if (!wasInEditMode && (viewModel.SelectedItem?.IsInEditMode ?? false))
                            {
                                Dispatcher.BeginInvoke(new Action(() => {
                                    FocusEditTextBoxForSelectedItem();
                                }), System.Windows.Threading.DispatcherPriority.Render);
                            }
                            
                            e.Handled = true;
                        }
                        else
                        {
                            Logger.Critical("TaskView", "🔥 E KEY - EDIT COMMAND CAN'T EXECUTE!");
                        }
                        break;

                    case Key.Delete:
                        // Delete key deletes current task
                        if (viewModel.DeleteCommand.CanExecute(null))
                        {
                            Logger.Info("TaskView", "Delete key pressed - deleting task");
                            viewModel.DeleteCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.S:
                        Logger.Critical("TaskView", "🔥 S KEY CASE HIT!");
                        // Ctrl+S saves data, S alone creates subtask
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            Logger.Critical("TaskView", "🔥 CTRL+S DETECTED!");
                            if (viewModel.SaveCommand.CanExecute(null))
                            {
                                Logger.Critical("TaskView", "🔥 CTRL+S - EXECUTING SAVE COMMAND");
                                viewModel.SaveCommand.Execute(null);
                                Logger.Critical("TaskView", "🔥 CTRL+S - SAVE COMMAND EXECUTED");
                                e.Handled = true;
                            }
                            else
                            {
                                Logger.Critical("TaskView", "🔥 CTRL+S - SAVE COMMAND CAN'T EXECUTE!");
                            }
                        }
                        else
                        {
                            Logger.Critical("TaskView", "🔥 S KEY WITHOUT CTRL - CREATING SUBTASK");
                            // S key creates new subtask
                            if (viewModel.NewSubtaskCommand.CanExecute(null))
                            {
                                Logger.Critical("TaskView", "🔥 S KEY - EXECUTING NEW SUBTASK COMMAND");
                                viewModel.NewSubtaskCommand.Execute(null);
                                Logger.Critical("TaskView", "🔥 S KEY - NEW SUBTASK COMMAND EXECUTED");
                                
                                // Focus the newly created subtask's TextBox after a brief delay
                                Dispatcher.BeginInvoke(new Action(() => {
                                    FocusEditTextBoxForSelectedItem();
                                }), System.Windows.Threading.DispatcherPriority.Render);
                                
                                e.Handled = true;
                            }
                            else
                            {
                                Logger.Critical("TaskView", "🔥 S KEY - NEW SUBTASK COMMAND CAN'T EXECUTE!");
                            }
                        }
                        break;

                    case Key.Enter:
                        // Enter key should toggle edit mode
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            Logger.Info("TaskView", "Enter key pressed - toggling edit mode");
                            viewModel.EditCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.Space:
                        // Space key should also toggle edit mode
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            Logger.Info("TaskView", "Space key pressed - toggling edit mode");
                            viewModel.EditCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.F2:
                        // F2 is standard for rename/edit
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            Logger.Info("TaskView", "F2 key pressed - entering edit mode");
                            viewModel.EditCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.Right:
                        // Right arrow should expand if collapsed
                        if (viewModel.SelectedItem != null && 
                            viewModel.SelectedItem.Children.Count > 0 && 
                            !viewModel.SelectedItem.IsExpanded)
                        {
                            Logger.Info("TaskView", "Right arrow pressed - expanding item");
                            viewModel.SelectedItem.IsExpanded = true;
                            e.Handled = true;
                        }
                        break;

                    case Key.Left:
                        // Left arrow should collapse if expanded
                        if (viewModel.SelectedItem != null && 
                            viewModel.SelectedItem.Children.Count > 0 && 
                            viewModel.SelectedItem.IsExpanded)
                        {
                            Logger.Info("TaskView", "Left arrow pressed - collapsing item");
                            viewModel.SelectedItem.IsExpanded = false;
                            e.Handled = true;
                        }
                        break;

                    case Key.OemPlus:
                    case Key.Add:
                        Logger.Critical("TaskView", "🔥 + KEY CASE HIT!");
                        // + key expands current item or all items (with Ctrl)
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            Logger.Critical("TaskView", "🔥 CTRL+ DETECTED!");
                            if (viewModel.ExpandAllCommand.CanExecute(null))
                            {
                                Logger.Critical("TaskView", "🔥 CTRL+ - EXECUTING EXPAND ALL COMMAND");
                                viewModel.ExpandAllCommand.Execute(null);
                                Logger.Critical("TaskView", "🔥 CTRL+ - EXPAND ALL COMMAND EXECUTED");
                                e.Handled = true;
                            }
                        }
                        else
                        {
                            Logger.Critical("TaskView", "🔥 + KEY (NO CTRL) DETECTED!");
                            if (viewModel.ExpandCommand.CanExecute(null))
                            {
                                Logger.Critical("TaskView", "🔥 + KEY - EXECUTING EXPAND COMMAND");
                                viewModel.ExpandCommand.Execute(null);
                                Logger.Critical("TaskView", "🔥 + KEY - EXPAND COMMAND EXECUTED");
                                e.Handled = true;
                            }
                        }
                        break;

                    case Key.OemMinus:
                    case Key.Subtract:
                        // - key collapses current item or all items (with Ctrl)
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            if (viewModel.CollapseAllCommand.CanExecute(null))
                            {
                                Logger.Info("TaskView", "Ctrl- pressed - collapsing all items");
                                viewModel.CollapseAllCommand.Execute(null);
                                e.Handled = true;
                            }
                        }
                        else
                        {
                            if (viewModel.CollapseCommand.CanExecute(null))
                            {
                                Logger.Info("TaskView", "- pressed - collapsing current item");
                                viewModel.CollapseCommand.Execute(null);
                                e.Handled = true;
                            }
                        }
                        break;
                }

                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("TaskView", "Error handling key down", ex);
                Logger.TraceExit();
            }
        }

        private void EditTextBox_Loaded(object sender, System.Windows.RoutedEventArgs e)
        {
            Logger.TraceEnter();
            
            try
            {
                var textBox = sender as TextBox;
                if (textBox != null)
                {
                    // Focus and select all text when edit mode starts
                    // Use Dispatcher to ensure this happens after the UI is fully rendered
                    Dispatcher.BeginInvoke(new Action(() => {
                        var focusResult = textBox.Focus();
                        textBox.SelectAll();
                        Logger.Critical("TaskView", $"🔥 EDIT TEXTBOX LOADED: Focus={focusResult}, IsFocused={textBox.IsFocused}, Text='{textBox.Text}'");
                    }), System.Windows.Threading.DispatcherPriority.Input);
                }
                else
                {
                    Logger.Critical("TaskView", "🔥 EDIT TEXTBOX LOADED BUT SENDER IS NOT TEXTBOX!");
                }
                
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Critical("TaskView", "🔥 ERROR IN EDIT TEXTBOX LOADED", ex);
                Logger.TraceExit();
            }
        }

        private void EditTextBox_KeyDown(object sender, KeyEventArgs e)
        {
            Logger.TraceEnter(parameters: new object[] { e.Key.ToString() });

            try
            {
                var textBox = sender as TextBox;
                var viewModel = DataContext as TaskViewModel;
                if (textBox == null || viewModel == null) return;

                switch (e.Key)
                {
                    case Key.Enter:
                        // Enter confirms the edit and exits edit mode
                        Logger.Info("TaskView", "Enter pressed in TextBox - confirming edit");
                        if (viewModel.SelectedItem != null)
                        {
                            viewModel.SelectedItem.IsInEditMode = false;
                            // Force focus back to TreeView (foolproof data focus)
                            TaskTreeView.Focus();
                            Logger.Debug("TaskView", "Focus returned to TreeView after edit completion");
                        }
                        e.Handled = true;
                        break;

                    case Key.Escape:
                        // Escape cancels the edit and exits edit mode
                        Logger.Info("TaskView", "Escape pressed in TextBox - canceling edit");
                        if (viewModel.SelectedItem != null)
                        {
                            viewModel.SelectedItem.IsInEditMode = false;
                            // Force focus back to TreeView (foolproof data focus)
                            TaskTreeView.Focus();
                            Logger.Debug("TaskView", "Focus returned to TreeView after edit cancellation");
                            // TODO: Revert changes if needed
                        }
                        e.Handled = true;
                        break;
                }

                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("TaskView", "Error handling TextBox key down", ex);
                Logger.TraceExit();
            }
        }

        // Helper method to find visual children
        private static T FindVisualChild<T>(DependencyObject parent) where T : DependencyObject
        {
            for (int i = 0; i < VisualTreeHelper.GetChildrenCount(parent); i++)
            {
                var child = VisualTreeHelper.GetChild(parent, i);
                if (child is T result)
                {
                    return result;
                }
                
                var childOfChild = FindVisualChild<T>(child);
                if (childOfChild != null)
                {
                    return childOfChild;
                }
            }
            return null;
        }

        private void FocusEditTextBoxForSelectedItem()
        {
            try
            {
                var viewModel = DataContext as TaskViewModel;
                if (viewModel?.SelectedItem == null || !viewModel.SelectedItem.IsInEditMode)
                {
                    Logger.Critical("TaskView", "🔥 FocusEditTextBoxForSelectedItem: No selected item in edit mode");
                    return;
                }

                // Find the TreeViewItem for the selected item
                var treeViewItem = TaskTreeView.ItemContainerGenerator.ContainerFromItem(viewModel.SelectedItem) as TreeViewItem;
                if (treeViewItem == null)
                {
                    Logger.Critical("TaskView", "🔥 FocusEditTextBoxForSelectedItem: TreeViewItem not found");
                    return;
                }

                // Find the EditTextBox within this TreeViewItem
                var editTextBox = FindVisualChild<TextBox>(treeViewItem);
                if (editTextBox != null && editTextBox.Name == "EditTextBox")
                {
                    var focusResult = editTextBox.Focus();
                    editTextBox.SelectAll();
                    Logger.Critical("TaskView", $"🔥 FocusEditTextBoxForSelectedItem: Focus={focusResult}, IsFocused={editTextBox.IsFocused}");
                }
                else
                {
                    Logger.Critical("TaskView", "🔥 FocusEditTextBoxForSelectedItem: EditTextBox not found in TreeViewItem");
                }
            }
            catch (Exception ex)
            {
                Logger.Critical("TaskView", "🔥 FocusEditTextBoxForSelectedItem: Exception", ex);
            }
        }
    }
}