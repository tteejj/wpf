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
            InitializeComponent();
            Loaded += TaskView_Loaded;
        }

        private void TaskView_Loaded(object sender, System.Windows.RoutedEventArgs e)
        {
            TaskTreeView.Focus();
            
            var window = System.Windows.Window.GetWindow(this);
            if (window != null)
            {
                window.Activated += Window_Activated;
            }
        }

        private void Window_Activated(object sender, EventArgs e)
        {
            TaskTreeView.Focus();
        }

        private void TaskTreeView_SelectedItemChanged(object sender, System.Windows.RoutedPropertyChangedEventArgs<object> e)
        {
            try
            {
                var viewModel = DataContext as TaskViewModel;
                if (viewModel != null && e.NewValue is IDisplayableItem selectedItem)
                {
                    viewModel.SelectedItem = selectedItem;
                    
                    // Ensure TreeView has focus for keyboard navigation
                    if (!TaskTreeView.IsFocused)
                    {
                        TaskTreeView.Focus();
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
                            }
                        }), System.Windows.Threading.DispatcherPriority.Background);
                    }
                }
                else if (e.NewValue == null && viewModel != null)
                {
                    // Handle deselection
                    viewModel.SelectedItem = null;
                }
                else
                {
                    Logger.Warning("TaskView", "Selection change ignored", 
                        $"DataContext is TaskViewModel: {DataContext is TaskViewModel}, " +
                        $"NewValue is IDisplayableItem: {e.NewValue is IDisplayableItem}");
                }
                
            }
            catch (Exception ex)
            {
                Logger.Error("TaskView", "Error handling selection change", ex);
            }
        }

        public override void OnApplyTemplate()
        {
            base.OnApplyTemplate();
            TaskTreeView.Focus();
        }

        private void TaskTreeView_KeyDown(object sender, KeyEventArgs e)
        {
            var viewModel = DataContext as TaskViewModel;
            if (viewModel == null) return;
            
            // Check if we're currently in edit mode by looking for focused TextBox
            var focusedTextBox = Keyboard.FocusedElement as TextBox;
            var isInEditMode = focusedTextBox != null && focusedTextBox.Name == "EditTextBox";

            // If we're in edit mode, only allow Enter/Escape to be processed as hotkeys
            if (isInEditMode && e.Key != Key.Enter && e.Key != Key.Escape)
                return;

            switch (e.Key)
            {
                case Key.N:
                    // N key creates new task
                    if (viewModel.NewCommand.CanExecute(null))
                    {
                        viewModel.NewCommand.Execute(null);
                        
                        // Focus the newly created item's TextBox after a brief delay
                        Dispatcher.BeginInvoke(new Action(() => {
                            FocusEditTextBoxForSelectedItem();
                        }), System.Windows.Threading.DispatcherPriority.Render);
                        
                        e.Handled = true;
                    }
                    break;


                    case Key.E:
                    // E key toggles edit mode
                    if (viewModel.EditCommand.CanExecute(null))
                    {
                        var wasInEditMode = viewModel.SelectedItem?.IsInEditMode ?? false;
                        viewModel.EditCommand.Execute(null);
                        
                        // If we just entered edit mode, focus the TextBox
                        if (!wasInEditMode && (viewModel.SelectedItem?.IsInEditMode ?? false))
                        {
                            Dispatcher.BeginInvoke(new Action(() => {
                                FocusEditTextBoxForSelectedItem();
                            }), System.Windows.Threading.DispatcherPriority.Render);
                        }
                        
                        e.Handled = true;
                    }
                    break;

                case Key.Delete:
                    // Delete key deletes current task
                    if (viewModel.DeleteCommand.CanExecute(null))
                    {
                        viewModel.DeleteCommand.Execute(null);
                        e.Handled = true;
                    }
                    break;

                case Key.S:
                    // Ctrl+S saves data, S alone creates subtask
                    if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                    {
                        if (viewModel.SaveCommand.CanExecute(null))
                        {
                            viewModel.SaveCommand.Execute(null);
                            e.Handled = true;
                        }
                    }
                    else
                    {
                        // S key creates new subtask
                        if (viewModel.NewSubtaskCommand.CanExecute(null))
                        {
                            viewModel.NewSubtaskCommand.Execute(null);
                            
                            // Focus the newly created subtask's TextBox after a brief delay
                            Dispatcher.BeginInvoke(new Action(() => {
                                FocusEditTextBoxForSelectedItem();
                            }), System.Windows.Threading.DispatcherPriority.Render);
                            
                            e.Handled = true;
                        }
                    }
                    break;

                case Key.P:
                    // P key creates new project
                    if (viewModel.NewProjectCommand.CanExecute(null))
                    {
                        viewModel.NewProjectCommand.Execute(null);
                        
                        // Focus the newly created project's TextBox after a brief delay
                        Dispatcher.BeginInvoke(new Action(() => {
                            FocusEditTextBoxForSelectedItem();
                        }), System.Windows.Threading.DispatcherPriority.Render);
                        
                        e.Handled = true;
                    }
                    break;

                    case Key.Enter:
                        // Enter key should toggle edit mode
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            viewModel.EditCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.Space:
                        // Space key should also toggle edit mode
                        if (viewModel.EditCommand.CanExecute(null))
                        {
                            viewModel.EditCommand.Execute(null);
                            e.Handled = true;
                        }
                        break;

                    case Key.F2:
                        // F2 is standard for rename/edit
                        if (viewModel.EditCommand.CanExecute(null))
                        {
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
                            viewModel.SelectedItem.IsExpanded = false;
                            e.Handled = true;
                        }
                        break;

                    case Key.OemPlus:
                    case Key.Add:
                        // + key expands current item or all items (with Ctrl)
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            if (viewModel.ExpandAllCommand.CanExecute(null))
                            {
                                viewModel.ExpandAllCommand.Execute(null);
                                e.Handled = true;
                            }
                        }
                        else
                        {
                            if (viewModel.ExpandCommand.CanExecute(null))
                            {
                                viewModel.ExpandCommand.Execute(null);
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
                                viewModel.CollapseAllCommand.Execute(null);
                                e.Handled = true;
                            }
                        }
                        else
                        {
                            if (viewModel.CollapseCommand.CanExecute(null))
                            {
                                viewModel.CollapseCommand.Execute(null);
                                e.Handled = true;
                            }
                        }
                        break;

                    case Key.T:
                        // T key opens time entry screen
                        var mainWindow = System.Windows.Window.GetWindow(this) as MainWindow;
                        if (mainWindow != null)
                        {
                            mainWindow.ShowTimeEntry();
                            e.Handled = true;
                        }
                        break;

                    case Key.D:
                        // D key opens data processing screen
                        var dataMainWindow = System.Windows.Window.GetWindow(this) as MainWindow;
                        if (dataMainWindow != null)
                        {
                            dataMainWindow.ShowDataProcessing();
                            e.Handled = true;
                        }
                        break;

                    case Key.H:
                        // H key opens theme selection screen
                        var themeMainWindow = System.Windows.Window.GetWindow(this) as MainWindow;
                        if (themeMainWindow != null)
                        {
                            themeMainWindow.ShowThemes();
                            e.Handled = true;
                        }
                        break;

                    case Key.OemQuestion:
                    case Key.F1:
                        // ? or F1 key shows help overlay
                        ShowHelpOverlay();
                        e.Handled = true;
                        break;

                    case Key.O:
                        // O key opens notes editor, Shift+O opens notes2 editor
                        if (Keyboard.Modifiers == ModifierKeys.Shift)
                        {
                            if (viewModel.OpenNotes2Command.CanExecute(null))
                            {
                                viewModel.OpenNotes2Command.Execute(null);
                                e.Handled = true;
                            }
                        }
                        else
                        {
                            if (viewModel.OpenNotesCommand.CanExecute(null))
                            {
                                viewModel.OpenNotesCommand.Execute(null);
                                e.Handled = true;
                            }
                        }
                        break;
            }
        }

        private void EditTextBox_Loaded(object sender, System.Windows.RoutedEventArgs e)
        {
            var textBox = sender as TextBox;
            if (textBox != null)
            {
                // Focus and select all text when edit mode starts
                Dispatcher.BeginInvoke(new Action(() => {
                    textBox.Focus();
                    textBox.SelectAll();
                }), System.Windows.Threading.DispatcherPriority.Input);
            }
        }

        private void EditTextBox_KeyDown(object sender, KeyEventArgs e)
        {
            var textBox = sender as TextBox;
            var viewModel = DataContext as TaskViewModel;
            if (textBox == null || viewModel == null) return;

            switch (e.Key)
            {
                case Key.Enter:
                    // Enter confirms the edit and exits edit mode
                    if (viewModel.SelectedItem != null)
                    {
                        viewModel.SelectedItem.IsInEditMode = false;
                        TaskTreeView.Focus();
                    }
                    e.Handled = true;
                    break;

                case Key.Escape:
                    // Escape cancels the edit and exits edit mode
                    if (viewModel.SelectedItem != null)
                    {
                        viewModel.SelectedItem.IsInEditMode = false;
                        TaskTreeView.Focus();
                    }
                    e.Handled = true;
                    break;

                case Key.Tab:
                    // Tab moves to next edit field
                    var treeViewItem = FindParent<TreeViewItem>(textBox);
                    if (treeViewItem != null)
                    {
                        // Find next focusable control
                        var datePicker = FindVisualChild<DatePicker>(treeViewItem);
                        var comboBox = FindVisualChild<ComboBox>(treeViewItem);
                        
                        if (datePicker != null && datePicker.Visibility == Visibility.Visible)
                        {
                            datePicker.Focus();
                            e.Handled = true;
                        }
                        else if (comboBox != null && comboBox.Visibility == Visibility.Visible)
                        {
                            comboBox.Focus();
                            e.Handled = true;
                        }
                    }
                    break;
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

        // Helper method to find visual parents
        private static T FindParent<T>(DependencyObject child) where T : DependencyObject
        {
            var parent = VisualTreeHelper.GetParent(child);
            while (parent != null)
            {
                if (parent is T result)
                {
                    return result;
                }
                parent = VisualTreeHelper.GetParent(parent);
            }
            return null;
        }

        private void FocusEditTextBoxForSelectedItem()
        {
            var viewModel = DataContext as TaskViewModel;
            if (viewModel?.SelectedItem == null || !viewModel.SelectedItem.IsInEditMode)
                return;

            // Simple focus after UI renders
            Dispatcher.BeginInvoke(new Action(() => {
                var treeViewItem = TaskTreeView.ItemContainerGenerator.ContainerFromItem(viewModel.SelectedItem) as TreeViewItem;
                if (treeViewItem != null)
                {
                    var editTextBox = FindVisualChild<TextBox>(treeViewItem);
                    if (editTextBox?.Name == "EditTextBox")
                    {
                        editTextBox.Focus();
                        editTextBox.SelectAll();
                    }
                }
            }), System.Windows.Threading.DispatcherPriority.Render);
        }

        private void ShowHelpOverlay()
        {
            HelpOverlay.HelpText = HotkeyHelper.GetHelpText("Tasks");
            HelpOverlay.Visibility = Visibility.Visible;
        }

        private void HelpOverlay_CloseRequested(object sender, EventArgs e)
        {
            HelpOverlay.Visibility = Visibility.Collapsed;
            TaskTreeView.Focus(); // Return focus to main control
        }
    }
}