using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Windows.Input;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TaskViewer
{
    public class TaskViewModel : INotifyPropertyChanged
    {
        private readonly IDataService _dataService;
        private IDisplayableItem? _selectedItem;

        public ObservableCollection<IDisplayableItem> Items { get; private set; }

        public IDisplayableItem? SelectedItem
        {
            get 
            { 
                Logger.TraceProperty("SelectedItem", null, _selectedItem?.DisplayName ?? "null");
                return _selectedItem; 
            }
            set
            {
                var oldValue = _selectedItem;
                Logger.TraceProperty("SelectedItem", oldValue?.DisplayName ?? "null", value?.DisplayName ?? "null");
                _selectedItem = value;
                OnPropertyChanged(nameof(SelectedItem));
                Logger.Info("TaskViewModel", $"Selection changed: '{oldValue?.DisplayName ?? "null"}' → '{value?.DisplayName ?? "null"}'");
            }
        }

        public ICommand NewCommand { get; }
        public ICommand NewProjectCommand { get; }
        public ICommand NewSubtaskCommand { get; }
        public ICommand EditCommand { get; }
        public ICommand DeleteCommand { get; }
        public ICommand SaveCommand { get; }
        public ICommand ExpandCommand { get; }
        public ICommand CollapseCommand { get; }
        public ICommand ExpandAllCommand { get; }
        public ICommand CollapseAllCommand { get; }

        public TaskViewModel() : this(new JsonDataService())
        {
            Logger.TraceEnter();
            Logger.TraceExit();
        }

        public TaskViewModel(IDataService dataService)
        {
            Logger.TraceEnter(parameters: new object[] { dataService.GetType().Name });
            using var perfTracker = Logger.TracePerformance("TaskViewModel Constructor");

            _dataService = dataService;
            Logger.Debug("TaskViewModel", $"Data service initialized: {dataService.GetType().Name}");

            Logger.TraceData("Load", "Items from data service");
            Items = _dataService.LoadItems();
            Logger.Info("TaskViewModel", $"Loaded {Items.Count} root items");

            // Auto-select first item if available
            if (Items.Count > 0)
            {
                SelectedItem = Items[0];
                Logger.Info("TaskViewModel", $"Auto-selected first item: {SelectedItem.DisplayName}");
            }

            // Wire up collection change events
            Items.CollectionChanged += (s, e) => {
                Logger.TraceData("CollectionChanged", "Items", 
                    $"Action={e.Action}, NewItems={e.NewItems?.Count ?? 0}, OldItems={e.OldItems?.Count ?? 0}");
            };

            Logger.TraceData("Initialize", "Commands");
            NewCommand = new RelayCommand(ExecuteNew, CanExecuteNew);
            NewProjectCommand = new RelayCommand(ExecuteNewProject, CanExecuteNewProject);
            NewSubtaskCommand = new RelayCommand(ExecuteNewSubtask, CanExecuteNewSubtask);
            EditCommand = new RelayCommand(ExecuteEdit, CanExecuteEdit);
            DeleteCommand = new RelayCommand(ExecuteDelete, CanExecuteDelete);
            SaveCommand = new RelayCommand(ExecuteSave);
            ExpandCommand = new RelayCommand(ExecuteExpand, CanExecuteExpand);
            CollapseCommand = new RelayCommand(ExecuteCollapse, CanExecuteCollapse);
            ExpandAllCommand = new RelayCommand(ExecuteExpandAll);
            CollapseAllCommand = new RelayCommand(ExecuteCollapseAll);
            Logger.Debug("TaskViewModel", "All commands initialized");

            Logger.TraceExit();
        }

        private void ExecuteNew()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("ExecuteNew");

            var nextId = GetNextId1();
            Logger.Debug("TaskViewModel", $"Creating new task with Id1={nextId}");

            var newTask = new TaskItem
            {
                Id1 = nextId,
                Id2 = 1,
                Name = "New Task",
                IsInEditMode = true,
                Priority = PriorityType.Medium,
                AssignedDate = DateTime.Now,
                DueDate = DateTime.Today.AddDays(7), // Default due date 1 week from now
                BringForwardDate = DateTime.Today.AddDays(1) // Default bring forward tomorrow
            };
            Logger.Debug("TaskViewModel", $"New task created: Id1={newTask.Id1}, Name={newTask.Name}");

            if (SelectedItem != null)
            {
                Logger.Info("TaskViewModel", $"Adding new task as child of '{SelectedItem.DisplayName}'");
                SelectedItem.Children.Add(newTask);
                SelectedItem.IsExpanded = true;
                Logger.TraceData("Add", "child task", $"Parent: {SelectedItem.DisplayName}");
            }
            else
            {
                Logger.Info("TaskViewModel", "Adding new task as root item");
                Items.Add(newTask);
                Logger.TraceData("Add", "root task");
            }

            SelectedItem = newTask;
            Logger.Critical("TaskViewModel", $"🔥 NEW TASK CREATED: Id1={newTask.Id1}, Name='{newTask.Name}', IsInEditMode={newTask.IsInEditMode}");
            Logger.Critical("TaskViewModel", $"🔥 SELECTED ITEM SET TO: {SelectedItem?.DisplayName ?? "NULL"}");
            Logger.Critical("TaskViewModel", $"🔥 TOTAL ROOT ITEMS: {Items.Count}");
            if (SelectedItem != null)
            {
                Logger.Critical("TaskViewModel", $"🔥 SELECTED ITEM CHILDREN: {SelectedItem.Children.Count}");
                Logger.Critical("TaskViewModel", $"🔥 SELECTED ITEM EXPANDED: {SelectedItem.IsExpanded}");
            }
            Logger.TraceExit();
        }

        private bool CanExecuteNew()
        {
            return true;
        }

        private void ExecuteNewProject()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("ExecuteNewProject");

            var nextId = GetNextId1();
            Logger.Debug("TaskViewModel", $"Creating new project with Id1={nextId}");

            var newProject = new TaskItem
            {
                Id1 = nextId,
                Id2 = 1,
                Name = "New Project",
                IsInEditMode = true,
                Priority = PriorityType.Medium,
                AssignedDate = DateTime.Now,
                DueDate = DateTime.Today.AddDays(30), // Default due date 1 month from now for projects
                BringForwardDate = DateTime.Today.AddDays(1)
            };
            Logger.Debug("TaskViewModel", $"New project created: Id1={newProject.Id1}, Name={newProject.Name}");

            // Projects are always added as root items
            Logger.Info("TaskViewModel", "Adding new project as root item");
            Items.Add(newProject);
            Logger.TraceData("Add", "root project");

            SelectedItem = newProject;
            Logger.Critical("TaskViewModel", $"🔥 NEW PROJECT CREATED: Id1={newProject.Id1}, Name='{newProject.Name}', IsInEditMode={newProject.IsInEditMode}");
            Logger.Critical("TaskViewModel", $"🔥 SELECTED ITEM SET TO: {SelectedItem?.DisplayName ?? "NULL"}");
            Logger.Critical("TaskViewModel", $"🔥 TOTAL ROOT ITEMS: {Items.Count}");
            Logger.TraceExit();
        }

        private bool CanExecuteNewProject()
        {
            return true;
        }

        private void ExecuteNewSubtask()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("ExecuteNewSubtask");

            if (SelectedItem == null)
            {
                Logger.Warning("TaskViewModel", "Cannot create subtask: no item selected");
                return;
            }

            var nextId = GetNextId1();
            Logger.Debug("TaskViewModel", $"Creating new subtask with Id1={nextId}");

            var newSubtask = new TaskItem
            {
                Id1 = nextId,
                Id2 = 1,
                Name = "New Subtask",
                IsInEditMode = true,
                Priority = PriorityType.Medium,
                AssignedDate = DateTime.Now,
                DueDate = DateTime.Today.AddDays(7), // Default due date 1 week from now
                BringForwardDate = DateTime.Today.AddDays(1)
            };
            Logger.Debug("TaskViewModel", $"New subtask created: Id1={newSubtask.Id1}, Name={newSubtask.Name}");

            // Subtasks are always added as children of the selected item
            Logger.Info("TaskViewModel", $"Adding new subtask as child of '{SelectedItem.DisplayName}'");
            SelectedItem.Children.Add(newSubtask);
            SelectedItem.IsExpanded = true;
            Logger.TraceData("Add", "subtask", $"Parent: {SelectedItem.DisplayName}");

            SelectedItem = newSubtask;
            Logger.Critical("TaskViewModel", $"🔥 NEW SUBTASK CREATED: Id1={newSubtask.Id1}, Name='{newSubtask.Name}', IsInEditMode={newSubtask.IsInEditMode}");
            Logger.Critical("TaskViewModel", $"🔥 SELECTED ITEM SET TO: {SelectedItem?.DisplayName ?? "NULL"}");
            Logger.TraceExit();
        }

        private bool CanExecuteNewSubtask()
        {
            return SelectedItem != null;
        }

        private void ExecuteEdit()
        {
            if (SelectedItem != null)
            {
                SelectedItem.IsInEditMode = !SelectedItem.IsInEditMode;
            }
        }

        private bool CanExecuteEdit()
        {
            return SelectedItem != null;
        }

        private void ExecuteDelete()
        {
            if (SelectedItem == null) return;

            // Find and remove from parent collection
            if (RemoveFromCollection(Items, SelectedItem))
            {
                SelectedItem = null;
            }
        }

        private bool CanExecuteDelete()
        {
            return SelectedItem != null;
        }

        private void ExecuteSave()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("ExecuteSave");
            
            Logger.Info("TaskViewModel", "Saving data via data service");
            _dataService.SaveItems(Items);
            Logger.Info("TaskViewModel", "Data saved successfully");
            
            Logger.TraceExit();
        }

        private void ExecuteExpand()
        {
            Logger.TraceEnter();
            if (SelectedItem != null)
            {
                Logger.Info("TaskViewModel", $"Expanding item: {SelectedItem.DisplayName}");
                SelectedItem.IsExpanded = true;
                Logger.Debug("TaskViewModel", $"Item '{SelectedItem.DisplayName}' expanded");
            }
            else
            {
                Logger.Warning("TaskViewModel", "Cannot expand: no item selected");
            }
            Logger.TraceExit();
        }

        private bool CanExecuteExpand()
        {
            var canExpand = SelectedItem != null && SelectedItem.Children.Count > 0 && !SelectedItem.IsExpanded;
            Logger.Trace("TaskViewModel", $"CanExecuteExpand: {canExpand}");
            return canExpand;
        }

        private void ExecuteCollapse()
        {
            Logger.TraceEnter();
            if (SelectedItem != null)
            {
                Logger.Info("TaskViewModel", $"Collapsing item: {SelectedItem.DisplayName}");
                SelectedItem.IsExpanded = false;
                Logger.Debug("TaskViewModel", $"Item '{SelectedItem.DisplayName}' collapsed");
            }
            else
            {
                Logger.Warning("TaskViewModel", "Cannot collapse: no item selected");
            }
            Logger.TraceExit();
        }

        private bool CanExecuteCollapse()
        {
            var canCollapse = SelectedItem != null && SelectedItem.Children.Count > 0 && SelectedItem.IsExpanded;
            Logger.Trace("TaskViewModel", $"CanExecuteCollapse: {canCollapse}");
            return canCollapse;
        }

        private void ExecuteExpandAll()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("ExecuteExpandAll");
            
            Logger.Info("TaskViewModel", "Expanding all items");
            var expandedCount = ExpandAllItems(Items);
            Logger.Info("TaskViewModel", $"Expanded {expandedCount} items");
            
            Logger.TraceExit();
        }

        private void ExecuteCollapseAll()
        {
            Logger.TraceEnter();
            using var perfTracker = Logger.TracePerformance("ExecuteCollapseAll");
            
            Logger.Info("TaskViewModel", "Collapsing all items");
            var collapsedCount = CollapseAllItems(Items);
            Logger.Info("TaskViewModel", $"Collapsed {collapsedCount} items");
            
            Logger.TraceExit();
        }

        private int ExpandAllItems(ObservableCollection<IDisplayableItem> items)
        {
            int count = 0;
            foreach (var item in items)
            {
                if (item.Children.Count > 0 && !item.IsExpanded)
                {
                    Logger.Debug("TaskViewModel", $"Expanding: {item.DisplayName}");
                    item.IsExpanded = true;
                    count++;
                }
                count += ExpandAllItems(item.Children);
            }
            return count;
        }

        private int CollapseAllItems(ObservableCollection<IDisplayableItem> items)
        {
            int count = 0;
            foreach (var item in items)
            {
                if (item.Children.Count > 0 && item.IsExpanded)
                {
                    Logger.Debug("TaskViewModel", $"Collapsing: {item.DisplayName}");
                    item.IsExpanded = false;
                    count++;
                }
                count += CollapseAllItems(item.Children);
            }
            return count;
        }

        private bool RemoveFromCollection(ObservableCollection<IDisplayableItem> collection, IDisplayableItem itemToRemove)
        {
            if (collection.Contains(itemToRemove))
            {
                collection.Remove(itemToRemove);
                return true;
            }

            foreach (var item in collection)
            {
                if (RemoveFromCollection(item.Children, itemToRemove))
                {
                    return true;
                }
            }

            return false;
        }

        private int GetNextId1()
        {
            var maxId = GetMaxId1(Items);
            return maxId + 1;
        }

        private int GetMaxId1(ObservableCollection<IDisplayableItem> items)
        {
            int max = 0;
            foreach (var item in items.Cast<TaskItem>())
            {
                if (item.Id1 > max) max = item.Id1;
                var childMax = GetMaxId1(item.Children);
                if (childMax > max) max = childMax;
            }
            return max;
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }

    // Simple RelayCommand implementation
    public class RelayCommand : ICommand
    {
        private readonly System.Action _execute;
        private readonly System.Func<bool>? _canExecute;

        public RelayCommand(System.Action execute, System.Func<bool>? canExecute = null)
        {
            _execute = execute ?? throw new System.ArgumentNullException(nameof(execute));
            _canExecute = canExecute;
        }

        public event System.EventHandler? CanExecuteChanged
        {
            add { CommandManager.RequerySuggested += value; }
            remove { CommandManager.RequerySuggested -= value; }
        }

        public bool CanExecute(object? parameter)
        {
            return _canExecute?.Invoke() ?? true;
        }

        public void Execute(object? parameter)
        {
            _execute();
        }
    }
}