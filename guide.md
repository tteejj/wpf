### **Project Design Document: WPF TUI Task Manager**

#### **1. Project Overview & Goals**

**1.1. Vision:**
To create a high-performance, keyboard-centric project and task management application. The user experience will mimic the speed and efficiency of a Text-based User Interface (TUI) while leveraging the power and visual flexibility of a Graphical User Interface (GUI) built with WPF. The aesthetic will be a "retro cyberpunk" theme.

**1.2. Core Principles:**
*   **Keyboard First:** All primary operations will be accessible via hotkeys for maximum speed. Mouse interaction is secondary.
*   **Clean Monolith:** The application will be built as a single, self-contained executable. The internal structure will be highly organized and decoupled to allow for easy future expansion without the upfront complexity of a full plugin system.
*   **Data Simplicity:** Data will be stored locally in a human-readable JSON format, managed by the application.
*   **Personalized Workflow:** The application is designed for a single user and will integrate with their custom external tools (notes editor).

**1.3. Initial Milestone (Version 1.0 Goals):**
*   Full CRUD (Create, Read, Update, Delete) functionality for hierarchical projects and tasks.
*   Modal, inline editing of task data.
*   Data persistence via a local JSON file.
*   Expand/collapse functionality for task hierarchies.
*   Integration to launch an external editor for project-specific notes.
*   A fully implemented "cyberpunk" theme.

---

#### **2. Technical Architecture & Structure**

The application will be a single WPF project structured for clarity and maintainability.

**2.1. Project Folder Structure:**

```
YourAppName/
├── App.xaml
├── MainWindow.xaml
│
├── Controls/
│   └── (Custom controls, e.g., a modal dialog)
│
├── Features/
│   ├── TaskViewer/
│   │   ├── TaskView.xaml         (The main grid UI)
│   │   └── TaskViewModel.cs      (The logic for the main grid)
│   │
│   └── TimeTracker/
│       ├── TimeTrackerView.xaml
│       └── TimeTrackerViewModel.cs
│
├── Interfaces/
│   ├── IDisplayableItem.cs     (Contract for any data item)
│   └── IDataService.cs         (Contract for loading/saving data)
│
├── Models/
│   ├── TaskItem.cs             (The concrete data class)
│   └── PriorityType.cs         (Enum for H, M, L priority)
│
├── Services/
│   └── JsonDataService.cs      (Implementation for reading/writing JSON)
│
└── Themes/
    └── Cyberpunk.xaml          (ResourceDictionary for colors, styles)
```

**2.2. Core Components:**

*   **Models:** Simple C# classes (POCOs) that represent the application's data.
    *   `TaskItem`: Implements `IDisplayableItem`. Contains properties like `Id1`, `Id2`, `Name`, `AssignedDate`, and an `ObservableCollection<IDisplayableItem>` for children.
*   **Interfaces (The "API Seed"):**
    *   `IDisplayableItem`: The key to future extensibility. Defines the common properties needed for the UI to display an item (e.g., `DisplayName`, `Children`, `IsExpanded`).
    *   `IDataService`: Defines the methods for data persistence (`LoadItems()`, `SaveItems(items)`). This decouples the application logic from the fact that we're using JSON.
*   **Services:**
    *   `JsonDataService`: Implements `IDataService`. Contains the logic to serialize and deserialize the list of `IDisplayableItem`s to and from `data.json` using `System.Text.Json`.
*   **ViewModels:** The "brains" of the application. Contains all logic and state.
    *   `TaskViewModel`: Manages the collection of all `TaskItem`s. Exposes `ICommand` properties for all user actions (Edit, New, Delete, Expand/Collapse, OpenNotes). Handles the application state (e.g., "Navigation Mode" vs. "Edit Mode").
*   **Views:** The XAML that defines the UI. Contains zero C# code-behind.
    *   `MainWindow.xaml`: The application shell.
    *   `TaskView.xaml`: The main user control. Will contain:
        *   An `ItemsControl` styled to look like pillbox headers.
        *   A `TreeView` to display the hierarchical data. Its `ItemTemplate` will be a `Grid` with fixed-width columns.
        *   A `DataTemplate` with `DataTriggers` to switch between `TextBlock`s (display mode) and `TextBox`es (edit mode).
    *   **Theming:** The `Cyberpunk.xaml` `ResourceDictionary` will contain all `Brush`, `Font`, and `Style` definitions. It will be merged in `App.xaml`.

---

#### **3. Interaction & Data Flow Example: "Edit Item"**

This flow demonstrates how the components work together:

1.  **User Action:** The user selects a row and presses the 'E' key.
2.  **View (XAML):** The `MainWindow`'s `<Window.InputBindings>` catches the key press and invokes the `EditCommand` from the `TaskViewModel`.
3.  **ViewModel:**
    *   The `EditCommand.Execute()` method is called.
    *   It finds the currently selected `TaskItem` in the data collection.
    *   It sets a boolean property on that item, e.g., `SelectedItem.IsInEditMode = true`.
4.  **Data Binding:** The `TreeViewItem` in the View is data-bound to this `TaskItem` object. Its `DataTemplate` has a trigger that monitors the `IsInEditMode` property.
5.  **View (XAML Update):** The trigger fires. It changes the `Visibility` of the `TextBlock`s to `Collapsed` and the `TextBox`es to `Visible`, effectively switching the row to its edit state. The first `TextBox` is given focus.

---

#### **4. Future Extensibility Path**

This design directly supports future enhancements with minimal refactoring:

*   **To Add a New Data Type (e.g., a "Bookmark"):**
    1.  Create a `BookmarkItem.cs` class in `/Models` that implements `IDisplayableItem`.
    2.  Add a new `<DataTemplate TargetType="{x:Type models:BookmarkItem}">` in your View's resources to define how it should look.
    3.  Update the `JsonDataService` to handle serializing this new type.
*   **To Add a New Theme:**
    1.  Create a new `MyTheme.xaml` `ResourceDictionary` in the `/Themes` folder.
    2.  Add logic in the `MainViewModel` to switch the application's merged dictionary to the new theme file.
*   **To Add a New Major Feature/Screen:**
    1.  Create a new folder under `/Features` (e.g., `/Calendar`).
    2.  Build the `CalendarView.xaml` and `CalendarViewModel.cs` within it.
    3.  Add a command to the main `TaskViewModel` to create and display this new view.
