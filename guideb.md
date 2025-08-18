
# 🚀 Prompt Kit: WPF TUI Task Manager (LLM Step-by-Step)

---

## **🔧 Global Reminder Prompt (paste once at start of session)**

Always prepend this when you open a new session with the LLM:

```
We are building a WPF Task Manager app using the MVVM pattern. 
Rules:
- No code-behind in Views (XAML-only for UI, C# ViewModels for logic). 
- Use ObservableCollection for collections. 
- Data stored in local JSON via System.Text.Json.
- Architecture is a clean monolith with clear folder structure.
- Single-user, ~50 items max.
- Keyboard-first UX (commands, hotkeys).
- Retro cyberpunk theme (neon colors, monospace font).
- No plugins, no external DB.
```

---

## **Stage 1: Base Foundation (V0.1)**

**Goal:** Display tasks from JSON.

---

### **Step 1: TaskItem model**

```
Generate TaskItem.cs that implements IDisplayableItem. 
Properties:
- int Id1
- int Id2
- string Name
- DateTime AssignedDate
- PriorityType Priority (enum: High, Medium, Low)
- bool IsExpanded
- bool IsInEditMode
- ObservableCollection<IDisplayableItem> Children
```

---

### **Step 2: PriorityType enum**

```
Generate PriorityType.cs with enum values: High, Medium, Low.
```

---

### **Step 3: Interfaces**

```
Generate IDisplayableItem.cs and IDataService.cs.

IDisplayableItem should have:
- string DisplayName { get; }
- bool IsExpanded { get; set; }
- ObservableCollection<IDisplayableItem> Children { get; }

IDataService should have:
- ObservableCollection<IDisplayableItem> LoadItems();
- void SaveItems(ObservableCollection<IDisplayableItem> items);
```

---

### **Step 4: JSON persistence**

```
Generate JsonDataService.cs that implements IDataService. 
- Reads from "data.json" in app root.
- Serializes/deserializes a collection of TaskItem using System.Text.Json.
- If file does not exist, return empty collection.
```

---

### **Step 5: TaskViewModel**

```
Generate TaskViewModel.cs.
- Property: ObservableCollection<TaskItem> Items.
- Constructor: loads items via JsonDataService.
- Method Save(): saves items via JsonDataService.
```

---

### **Step 6: XAML TreeView**

```
Generate TaskView.xaml. 
- Use a TreeView bound to TaskViewModel.Items.
- Each item should show TaskItem.Name.
- No edit mode yet.
```

---

✅ At this point: you should see tasks loading from `data.json` and displayed in a tree.

---

## **Stage 2: CRUD & Keyboard (V0.5)**

**Goal:** Add/edit/delete with hotkeys.

---

### **Step 7: CRUD commands**

```
Update TaskViewModel.cs.
Add ICommand properties: NewCommand, EditCommand, DeleteCommand.
Implement methods:
- New: adds a TaskItem child to the selected node.
- Edit: toggles IsInEditMode for selected item.
- Delete: removes selected item.
```

---

### **Step 8: Hotkeys**

```
Update MainWindow.xaml.
- Bind N key to TaskViewModel.NewCommand.
- Bind E key to TaskViewModel.EditCommand.
- Bind Delete key to TaskViewModel.DeleteCommand.
```

---

### **Step 9: Inline editing**

```
Update TaskView.xaml.
- DataTemplate for TaskItem should show:
   * TextBlock bound to Name when IsInEditMode = false
   * TextBox bound to Name when IsInEditMode = true
- Use DataTriggers to toggle visibility.
- TextBox should focus automatically in edit mode.
```

---

✅ At this point: You can add, edit, delete tasks with hotkeys.

---

## **Stage 3: Usability (V0.8)**

**Goal:** Make it smoother.

---

### **Step 10: Expand/Collapse hotkeys**

```
Update TaskViewModel.cs.
Add ExpandCommand and CollapseCommand.
Expand sets IsExpanded=true for selected item.
Collapse sets IsExpanded=false.
Bind keys [+] and [-] in MainWindow.xaml.
```

---

### **Step 11: External notes editor**

```
Update TaskViewModel.cs.
Add OpenNotesCommand (bound to hotkey O).
When executed, launch external editor (like notepad.exe) with a file named "{TaskItem.Id1}_{TaskItem.Name}.txt" inside a "Notes" folder.
```

---

### **Step 12: Undo/Redo**

```
Update TaskViewModel.cs.
Implement simple undo/redo:
- Maintain two stacks of actions.
- Actions include Add, Delete, Edit.
- Provide UndoCommand (Ctrl+Z) and RedoCommand (Ctrl+Y).
```

---

✅ Now it behaves like a usable TUI helper.

---

## **Stage 4: Cyberpunk Theme (V1.0)**

---

### **Step 13: Theme XAML**

```
Generate Cyberpunk.xaml ResourceDictionary.
- Background: black
- Foreground: neon green
- Selection: magenta highlight
- Font: monospace (e.g., Consolas)
- Apply styles to TreeView, TextBlock, TextBox, Window.
```

---

### **Step 14: Apply theme**

```
Update App.xaml to merge Cyberpunk.xaml as global ResourceDictionary.
```

---

✅ Now it looks cyberpunk and is feature-complete.

---

# 🏁 After Stage 4

You’ve got your MVP.
Future prompts can add search, new data types, or more themes, but you’ll already have the working app.

---

👉 Do you want me to **bundle these into a single Markdown “playbook”** (copy-paste ready, each stage separated), so you can literally paste it into ChatGPT or another LLM as you work through development? That way it feels like a guided checklist + prompt kit in one.
🚀 Prompt Kit: WPF TUI Task Manager (LLM Step-by-Step)
🔧 Global Reminder Prompt (paste once at start of session)

Always prepend this when you open a new session with the LLM:

We are building a WPF Task Manager app using the MVVM pattern. 
Rules:
- No code-behind in Views (XAML-only for UI, C# ViewModels for logic). 
- Use ObservableCollection for collections. 
- Data stored in local JSON via System.Text.Json.
- Architecture is a clean monolith with clear folder structure.
- Single-user, ~50 items max.
- Keyboard-first UX (commands, hotkeys).
- Retro cyberpunk theme (neon colors, monospace font).
- No plugins, no external DB.

Stage 1: Base Foundation (V0.1)

Goal: Display tasks from JSON.
Step 1: TaskItem model

Generate TaskItem.cs that implements IDisplayableItem. 
Properties:
- int Id1
- int Id2
- string Name
- DateTime AssignedDate
- PriorityType Priority (enum: High, Medium, Low)
- bool IsExpanded
- bool IsInEditMode
- ObservableCollection<IDisplayableItem> Children

Step 2: PriorityType enum

Generate PriorityType.cs with enum values: High, Medium, Low.

Step 3: Interfaces

Generate IDisplayableItem.cs and IDataService.cs.

IDisplayableItem should have:
- string DisplayName { get; }
- bool IsExpanded { get; set; }
- ObservableCollection<IDisplayableItem> Children { get; }

IDataService should have:
- ObservableCollection<IDisplayableItem> LoadItems();
- void SaveItems(ObservableCollection<IDisplayableItem> items);

Step 4: JSON persistence

Generate JsonDataService.cs that implements IDataService. 
- Reads from "data.json" in app root.
- Serializes/deserializes a collection of TaskItem using System.Text.Json.
- If file does not exist, return empty collection.

Step 5: TaskViewModel

Generate TaskViewModel.cs.
- Property: ObservableCollection<TaskItem> Items.
- Constructor: loads items via JsonDataService.
- Method Save(): saves items via JsonDataService.

Step 6: XAML TreeView

Generate TaskView.xaml. 
- Use a TreeView bound to TaskViewModel.Items.
- Each item should show TaskItem.Name.
- No edit mode yet.

✅ At this point: you should see tasks loading from data.json and displayed in a tree.
Stage 2: CRUD & Keyboard (V0.5)

Goal: Add/edit/delete with hotkeys.
Step 7: CRUD commands

Update TaskViewModel.cs.
Add ICommand properties: NewCommand, EditCommand, DeleteCommand.
Implement methods:
- New: adds a TaskItem child to the selected node.
- Edit: toggles IsInEditMode for selected item.
- Delete: removes selected item.

Step 8: Hotkeys

Update MainWindow.xaml.
- Bind N key to TaskViewModel.NewCommand.
- Bind E key to TaskViewModel.EditCommand.
- Bind Delete key to TaskViewModel.DeleteCommand.

Step 9: Inline editing

Update TaskView.xaml.
- DataTemplate for TaskItem should show:
   * TextBlock bound to Name when IsInEditMode = false
   * TextBox bound to Name when IsInEditMode = true
- Use DataTriggers to toggle visibility.
- TextBox should focus automatically in edit mode.

✅ At this point: You can add, edit, delete tasks with hotkeys.
Stage 3: Usability (V0.8)

Goal: Make it smoother.
Step 10: Expand/Collapse hotkeys

Update TaskViewModel.cs.
Add ExpandCommand and CollapseCommand.
Expand sets IsExpanded=true for selected item.
Collapse sets IsExpanded=false.
Bind keys [+] and [-] in MainWindow.xaml.

Step 11: External notes editor

Update TaskViewModel.cs.
Add OpenNotesCommand (bound to hotkey O).
When executed, launch external editor (like notepad.exe) with a file named "{TaskItem.Id1}_{TaskItem.Name}.txt" inside a "Notes" folder.

Step 12: Undo/Redo

Update TaskViewModel.cs.
Implement simple undo/redo:
- Maintain two stacks of actions.
- Actions include Add, Delete, Edit.
- Provide UndoCommand (Ctrl+Z) and RedoCommand (Ctrl+Y).

✅ Now it behaves like a usable TUI helper.
Stage 4: Cyberpunk Theme (V1.0)
Step 13: Theme XAML

Generate Cyberpunk.xaml ResourceDictionary.
- Background: black
- Foreground: neon green
- Selection: magenta highlight
- Font: monospace (e.g., Consolas)
- Apply styles to TreeView, TextBlock, TextBox, Window.

Step 14: Apply theme

Update App.xaml to merge Cyberpunk.xaml as global ResourceDictionary.

✅ Now it looks cyberpunk and is feature-complete.
🏁 After Stage 4

You’ve got your MVP.
Future prompts can add search, new data types, or more themes, but you’ll already have the working app.

👉 Do you want me to bundle these into a single Markdown “playbook” (copy-paste ready, each stage separated), so you can literally paste it into ChatGPT or another LLM as you work through development? That way it feels like a guided checklist + prompt kit in one.

You’ve got your MVP.
Future prompts can add search, new data types, or more themes, but you’ll already have the working app.

👉 Do you want me to bundle these into a single Markdown “playbook” (copy-paste ready, each stage separated), so you can literally paste it into ChatGPT or another LLM as you work through development? That way it feels like a guided checklist + prompt kit in one.
---

# 🚀 Prompt Kit: WPF TUI Task Manager (LLM Step-by-Step)

---

## **🔧 Global Reminder Prompt (paste once at start of session)**

Always prepend this when you open a new session with the LLM:

```
We are building a WPF Task Manager app using the MVVM pattern. 
Rules:
- No code-behind in Views (XAML-only for UI, C# ViewModels for logic). 
- Use ObservableCollection for collections. 
- Data stored in local JSON via System.Text.Json.
- Architecture is a clean monolith with clear folder structure.
- Single-user, ~50 items max.
- Keyboard-first UX (commands, hotkeys).
- Retro cyberpunk theme (neon colors, monospace font).
- No plugins, no external DB.
```

---

## **Stage 1: Base Foundation (V0.1)**

**Goal:** Display tasks from JSON.

---

### **Step 1: TaskItem model**

```
Generate TaskItem.cs that implements IDisplayableItem. 
Properties:
- int Id1
- int Id2
- string Name
- DateTime AssignedDate
- PriorityType Priority (enum: High, Medium, Low)
- bool IsExpanded
- bool IsInEditMode
- ObservableCollection<IDisplayableItem> Children
```

---

### **Step 2: PriorityType enum**

```
Generate PriorityType.cs with enum values: High, Medium, Low.
```

---

### **Step 3: Interfaces**

```
Generate IDisplayableItem.cs and IDataService.cs.

IDisplayableItem should have:
- string DisplayName { get; }
- bool IsExpanded { get; set; }
- ObservableCollection<IDisplayableItem> Children { get; }

IDataService should have:
- ObservableCollection<IDisplayableItem> LoadItems();
- void SaveItems(ObservableCollection<IDisplayableItem> items);
```

---

### **Step 4: JSON persistence**

```
Generate JsonDataService.cs that implements IDataService. 
- Reads from "data.json" in app root.
- Serializes/deserializes a collection of TaskItem using System.Text.Json.
- If file does not exist, return empty collection.
```

---

### **Step 5: TaskViewModel**

```
Generate TaskViewModel.cs.
- Property: ObservableCollection<TaskItem> Items.
- Constructor: loads items via JsonDataService.
- Method Save(): saves items via JsonDataService.
```

---

### **Step 6: XAML TreeView**

```
Generate TaskView.xaml. 
- Use a TreeView bound to TaskViewModel.Items.
- Each item should show TaskItem.Name.
- No edit mode yet.
```

---

✅ At this point: you should see tasks loading from `data.json` and displayed in a tree.

---

## **Stage 2: CRUD & Keyboard (V0.5)**

**Goal:** Add/edit/delete with hotkeys.

---

### **Step 7: CRUD commands**

```
Update TaskViewModel.cs.
Add ICommand properties: NewCommand, EditCommand, DeleteCommand.
Implement methods:
- New: adds a TaskItem child to the selected node.
- Edit: toggles IsInEditMode for selected item.
- Delete: removes selected item.
```

---

### **Step 8: Hotkeys**

```
Update MainWindow.xaml.
- Bind N key to TaskViewModel.NewCommand.
- Bind E key to TaskViewModel.EditCommand.
- Bind Delete key to TaskViewModel.DeleteCommand.
```

---

### **Step 9: Inline editing**

```
Update TaskView.xaml.
- DataTemplate for TaskItem should show:
   * TextBlock bound to Name when IsInEditMode = false
   * TextBox bound to Name when IsInEditMode = true
- Use DataTriggers to toggle visibility.
- TextBox should focus automatically in edit mode.
```

---

✅ At this point: You can add, edit, delete tasks with hotkeys.

---

## **Stage 3: Usability (V0.8)**

**Goal:** Make it smoother.

---

### **Step 10: Expand/Collapse hotkeys**

```
Update TaskViewModel.cs.
Add ExpandCommand and CollapseCommand.
Expand sets IsExpanded=true for selected item.
Collapse sets IsExpanded=false.
Bind keys [+] and [-] in MainWindow.xaml.
```

---

### **Step 11: External notes editor**

```
Update TaskViewModel.cs.
Add OpenNotesCommand (bound to hotkey O).
When executed, launch external editor (like notepad.exe) with a file named "{TaskItem.Id1}_{TaskItem.Name}.txt" inside a "Notes" folder.
```

---

### **Step 12: Undo/Redo**

```
Update TaskViewModel.cs.
Implement simple undo/redo:
- Maintain two stacks of actions.
- Actions include Add, Delete, Edit.
- Provide UndoCommand (Ctrl+Z) and RedoCommand (Ctrl+Y).
```

---

✅ Now it behaves like a usable TUI helper.

---

## **Stage 4: Cyberpunk Theme (V1.0)**

---

### **Step 13: Theme XAML**

```
Generate Cyberpunk.xaml ResourceDictionary.
- Background: black
- Foreground: neon green
- Selection: magenta highlight
- Font: monospace (e.g., Consolas)
- Apply styles to TreeView, TextBlock, TextBox, Window.
```

---

### **Step 14: Apply theme**

```
Update App.xaml to merge Cyberpunk.xaml as global ResourceDictionary.
```

---

✅ Now it looks cyberpunk and is feature-complete.

---

# 🏁 After Stage 4

You’ve got your MVP.
Future prompts can add search, new data types, or more themes, but you’ll already have the working app.

---

👉 Do you want me to **bundle these into a single Markdown “playbook”** (copy-paste ready, each stage separated), so you can literally paste it into ChatGPT or another LLM as you work through development? That way it feels like a guided checklist + prompt kit in one.
🚀 Prompt Kit: WPF TUI Task Manager (LLM Step-by-Step)
🔧 Global Reminder Prompt (paste once at start of session)

Always prepend this when you open a new session with the LLM:

We are building a WPF Task Manager app using the MVVM pattern. 
Rules:
- No code-behind in Views (XAML-only for UI, C# ViewModels for logic). 
- Use ObservableCollection for collections. 
- Data stored in local JSON via System.Text.Json.
- Architecture is a clean monolith with clear folder structure.
- Single-user, ~50 items max.
- Keyboard-first UX (commands, hotkeys).
- Retro cyberpunk theme (neon colors, monospace font).
- No plugins, no external DB.

Stage 1: Base Foundation (V0.1)

Goal: Display tasks from JSON.
Step 1: TaskItem model

Generate TaskItem.cs that implements IDisplayableItem. 
Properties:
- int Id1
- int Id2
- string Name
- DateTime AssignedDate
- PriorityType Priority (enum: High, Medium, Low)
- bool IsExpanded
- bool IsInEditMode
- ObservableCollection<IDisplayableItem> Children

Step 2: PriorityType enum

Generate PriorityType.cs with enum values: High, Medium, Low.

Step 3: Interfaces

Generate IDisplayableItem.cs and IDataService.cs.

IDisplayableItem should have:
- string DisplayName { get; }
- bool IsExpanded { get; set; }
- ObservableCollection<IDisplayableItem> Children { get; }

IDataService should have:
- ObservableCollection<IDisplayableItem> LoadItems();
- void SaveItems(ObservableCollection<IDisplayableItem> items);

Step 4: JSON persistence

Generate JsonDataService.cs that implements IDataService. 
- Reads from "data.json" in app root.
- Serializes/deserializes a collection of TaskItem using System.Text.Json.
- If file does not exist, return empty collection.

Step 5: TaskViewModel

Generate TaskViewModel.cs.
- Property: ObservableCollection<TaskItem> Items.
- Constructor: loads items via JsonDataService.
- Method Save(): saves items via JsonDataService.

Step 6: XAML TreeView

Generate TaskView.xaml. 
- Use a TreeView bound to TaskViewModel.Items.
- Each item should show TaskItem.Name.
- No edit mode yet.

✅ At this point: you should see tasks loading from data.json and displayed in a tree.
Stage 2: CRUD & Keyboard (V0.5)

Goal: Add/edit/delete with hotkeys.
Step 7: CRUD commands

Update TaskViewModel.cs.
Add ICommand properties: NewCommand, EditCommand, DeleteCommand.
Implement methods:
- New: adds a TaskItem child to the selected node.
- Edit: toggles IsInEditMode for selected item.
- Delete: removes selected item.

Step 8: Hotkeys

Update MainWindow.xaml.
- Bind N key to TaskViewModel.NewCommand.
- Bind E key to TaskViewModel.EditCommand.
- Bind Delete key to TaskViewModel.DeleteCommand.

Step 9: Inline editing

Update TaskView.xaml.
- DataTemplate for TaskItem should show:
   * TextBlock bound to Name when IsInEditMode = false
   * TextBox bound to Name when IsInEditMode = true
- Use DataTriggers to toggle visibility.
- TextBox should focus automatically in edit mode.

✅ At this point: You can add, edit, delete tasks with hotkeys.
Stage 3: Usability (V0.8)

Goal: Make it smoother.
Step 10: Expand/Collapse hotkeys

Update TaskViewModel.cs.
Add ExpandCommand and CollapseCommand.
Expand sets IsExpanded=true for selected item.
Collapse sets IsExpanded=false.
Bind keys [+] and [-] in MainWindow.xaml.

Step 11: External notes editor

Update TaskViewModel.cs.
Add OpenNotesCommand (bound to hotkey O).
When executed, launch external editor (like notepad.exe) with a file named "{TaskItem.Id1}_{TaskItem.Name}.txt" inside a "Notes" folder.

Step 12: Undo/Redo

Update TaskViewModel.cs.
Implement simple undo/redo:
- Maintain two stacks of actions.
- Actions include Add, Delete, Edit.
- Provide UndoCommand (Ctrl+Z) and RedoCommand (Ctrl+Y).

✅ Now it behaves like a usable TUI helper.
Stage 4: Cyberpunk Theme (V1.0)
Step 13: Theme XAML

Generate Cyberpunk.xaml ResourceDictionary.
- Background: black
- Foreground: neon green
- Selection: magenta highlight
- Font: monospace (e.g., Consolas)
- Apply styles to TreeView, TextBlock, TextBox, Window.

Step 14: Apply theme

Update App.xaml to merge Cyberpunk.xaml as global ResourceDictionary.

✅ Now it looks cyberpunk and is feature-complete.
🏁 After Stage 4

You’ve got your MVP.
Future prompts can add search, new data types, or more themes, but you’ll already have the working app.

👉 Do you want me to bundle these into a single Markdown “playbook” (copy-paste ready, each stage separated), so you can literally paste it into ChatGPT or another LLM as you work through development? That way it feels like a guided checklist + prompt kit in one.
