using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Text.Json.Serialization;
using PraxisWpf.Interfaces;
using PraxisWpf.Services;

namespace PraxisWpf.Models
{
    public class TaskItem : IDisplayableItem, INotifyPropertyChanged
    {
        private bool _isExpanded;
        private bool _isInEditMode;
        private string _name = string.Empty;
        private PriorityType _priority = PriorityType.Medium;

        public TaskItem()
        {
            Logger.TraceEnter();
            Children.CollectionChanged += (s, e) => {
                Logger.TraceData("CollectionChanged", "Children", 
                    $"Action={e.Action}, NewItems={e.NewItems?.Count ?? 0}, OldItems={e.OldItems?.Count ?? 0}");
            };
            Logger.TraceExit();
        }

        public int Id1 { get; set; }
        public int Id2 { get; set; }
        
        public string Name
        {
            get 
            { 
                Logger.TraceProperty("Name", null, _name);
                return _name; 
            }
            set
            {
                var oldValue = _name;
                Logger.TraceProperty("Name", oldValue, value);
                _name = value;
                OnPropertyChanged(nameof(Name));
                OnPropertyChanged(nameof(DisplayName));
                Logger.Debug("TaskItem", $"Name changed: '{oldValue}' → '{value}' for Id1={Id1}");
            }
        }

        public DateTime AssignedDate { get; set; } = DateTime.Now;
        public DateTime? DueDate { get; set; }
        public DateTime? BringForwardDate { get; set; }
        
        public PriorityType Priority 
        { 
            get 
            { 
                Logger.TraceProperty("Priority", null, _priority);
                return _priority; 
            }
            set
            {
                var oldValue = _priority;
                Logger.TraceProperty("Priority", oldValue, value);
                _priority = value;
                
                // H=today logic: If priority is set to High and no due date exists, set it to today
                if (value == PriorityType.High && !DueDate.HasValue)
                {
                    DueDate = DateTime.Today;
                    Logger.Info("TaskItem", $"High priority set - DueDate auto-set to today for Id1={Id1}");
                }
                
                OnPropertyChanged(nameof(Priority));
                OnPropertyChanged(nameof(IsHighPriorityToday));
                Logger.Debug("TaskItem", $"Priority changed: {oldValue} → {value} for Id1={Id1}, Name={Name}");
            }
        }

        public bool IsExpanded
        {
            get 
            { 
                Logger.TraceProperty("IsExpanded", null, _isExpanded);
                return _isExpanded; 
            }
            set
            {
                var oldValue = _isExpanded;
                Logger.TraceProperty("IsExpanded", oldValue, value);
                _isExpanded = value;
                OnPropertyChanged(nameof(IsExpanded));
                Logger.Debug("TaskItem", $"IsExpanded changed: {oldValue} → {value} for Id1={Id1}, Name={Name}");
            }
        }

        [JsonIgnore]
        public bool IsInEditMode
        {
            get 
            { 
                Logger.TraceProperty("IsInEditMode", null, _isInEditMode);
                return _isInEditMode; 
            }
            set
            {
                var oldValue = _isInEditMode;
                Logger.TraceProperty("IsInEditMode", oldValue, value);
                _isInEditMode = value;
                OnPropertyChanged(nameof(IsInEditMode));
                Logger.Info("TaskItem", $"Edit mode changed: {oldValue} → {value} for Id1={Id1}, Name={Name}");
            }
        }

        [JsonIgnore]
        public ObservableCollection<IDisplayableItem> Children { get; set; } = new ObservableCollection<IDisplayableItem>();

        // JSON-specific property that serializes/deserializes concrete TaskItem types
        [JsonPropertyName("children")]
        public List<TaskItem> ChildrenForJson
        {
            get
            {
                Logger.Trace("TaskItem", $"Getting ChildrenForJson for Id1={Id1}, Count={Children.Count}");
                return Children.Cast<TaskItem>().ToList();
            }
            set
            {
                Logger.Trace("TaskItem", $"Setting ChildrenForJson for Id1={Id1}, Count={value?.Count ?? 0}");
                Children.Clear();
                if (value != null)
                {
                    foreach (var item in value)
                    {
                        Children.Add(item);
                    }
                }
            }
        }

        [JsonIgnore]
        public string DisplayName => Name;

        [JsonIgnore]
        public bool IsHighPriorityToday => Priority == PriorityType.High && 
                                          DueDate.HasValue && 
                                          DueDate.Value.Date == DateTime.Today;

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            Logger.Trace("TaskItem", $"PropertyChanged: {propertyName} for Id1={Id1}");
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}