using System;
using System.IO;
using System.Windows;
using System.Windows.Input;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Features.TaskViewer
{
    public partial class NotesDialog : Window
    {
        private readonly TaskItem _task;
        private readonly string _notesType;
        private string _originalText = string.Empty;
        private string _filePath = string.Empty;
        private bool _isModified = false;
        private bool _isSaving = false;

        public NotesDialog(TaskItem task, string notesType = "notes")
        {
            Logger.TraceEnter(parameters: new object[] { task?.DisplayName ?? "null", notesType });
            
            InitializeComponent();
            _task = task ?? throw new ArgumentNullException(nameof(task));
            _notesType = notesType ?? "notes";
            
            SetupNotesEditor();
            Logger.TraceExit();
        }

        private void SetupNotesEditor()
        {
            try
            {
                Logger.TraceEnter();
                using var perfTracker = Logger.TracePerformance("SetupNotesEditor");

                // Update window title and header
                Title = $"{(_notesType == "notes2" ? "Notes2" : "Notes")} Editor - {_task.Name}";
                TaskNameTextBlock.Text = $"{(_notesType == "notes2" ? "Notes2" : "Notes")} for: {_task.Name}";

                // Create Notes directory if it doesn't exist
                var notesDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Notes");
                Directory.CreateDirectory(notesDir);
                Logger.Debug("NotesDialog", $"Notes directory ensured: {notesDir}");

                // Generate safe filename: "{Id1}_{Name}_{notesType}.txt"
                var sanitizedName = string.Join("_", _task.Name.Split(Path.GetInvalidFileNameChars()));
                var fileName = $"{_task.Id1}_{sanitizedName}_{_notesType}.txt";
                _filePath = Path.Combine(notesDir, fileName);
                
                FilePathTextBlock.Text = _filePath;
                Logger.Info("NotesDialog", $"Notes file path: {_filePath}");

                // Load existing content or create new
                if (File.Exists(_filePath))
                {
                    _originalText = File.ReadAllText(_filePath);
                    Logger.Info("NotesDialog", $"Loaded existing notes file with {_originalText.Length} characters");
                }
                else
                {
                    _originalText = $"Notes for: {_task.Name}\n" +
                                   $"Task ID: {_task.Id1}\n" +
                                   $"Created: {DateTime.Now:yyyy-MM-dd HH:mm:ss}\n" +
                                   $"Priority: {_task.Priority}\n" +
                                   "\n" +
                                   "═══════════════════════════════════════════════════════════\n" +
                                   "\n";
                    Logger.Info("NotesDialog", "Created default notes content for new file");
                }

                // Set text and position cursor at end
                NotesTextBox.Text = _originalText;
                NotesTextBox.Focus();
                NotesTextBox.CaretIndex = NotesTextBox.Text.Length;

                // Update UI elements
                UpdateFileStatus();
                UpdateTextStats();

                Logger.Info("NotesDialog", "Notes editor setup completed successfully");
                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("NotesDialog", "Failed to setup notes editor", ex);
                MessageBox.Show($"Failed to setup notes editor: {ex.Message}", "Error", 
                    MessageBoxButton.OK, MessageBoxImage.Error);
                Logger.TraceExit();
                Close();
            }
        }

        private void UpdateFileStatus()
        {
            _isModified = !string.Equals(NotesTextBox.Text, _originalText, StringComparison.Ordinal);
            
            ModifiedIndicator.Text = _isModified ? "Yes" : "No";
            ModifiedIndicator.Foreground = _isModified ? 
                FindResource("CyberWarningBrush") as System.Windows.Media.Brush : 
                FindResource("CyberInfoBrush") as System.Windows.Media.Brush;

            // Update window title to show modified state
            Title = $"Notes Editor - {_task.Name}{(_isModified ? " *" : "")}";
            
            Logger.Trace("NotesDialog", $"File status updated: Modified={_isModified}");
        }

        private void UpdateTextStats()
        {
            var text = NotesTextBox.Text ?? string.Empty;
            var lineCount = text.Split('\n').Length;
            var charCount = text.Length;

            LineCountTextBlock.Text = lineCount.ToString();
            CharCountTextBlock.Text = charCount.ToString();
            
            Logger.Trace("NotesDialog", $"Text stats updated: Lines={lineCount}, Chars={charCount}");
        }

        private void SaveNotes()
        {
            if (_isSaving) return;

            try
            {
                Logger.TraceEnter();
                using var perfTracker = Logger.TracePerformance("SaveNotes");
                _isSaving = true;

                var currentText = NotesTextBox.Text ?? string.Empty;
                
                // Create backup if file exists and content changed significantly
                if (File.Exists(_filePath) && _isModified)
                {
                    var backupPath = _filePath + $".backup.{DateTime.Now:yyyyMMdd_HHmmss}";
                    File.Copy(_filePath, backupPath);
                    Logger.Debug("NotesDialog", $"Created backup: {backupPath}");
                }

                // Save the file
                File.WriteAllText(_filePath, currentText);
                _originalText = currentText;
                
                UpdateFileStatus();
                
                Logger.Info("NotesDialog", $"Notes saved successfully to {_filePath}");

                Logger.TraceExit();
            }
            catch (Exception ex)
            {
                Logger.Error("NotesDialog", "Failed to save notes", ex);
                MessageBox.Show($"Failed to save notes: {ex.Message}", "Error", 
                    MessageBoxButton.OK, MessageBoxImage.Error);
                Logger.TraceExit();
            }
            finally
            {
                _isSaving = false;
            }
        }

        private bool PromptSaveIfModified()
        {
            if (!_isModified) return true;

            Logger.Info("NotesDialog", "Prompting user to save modified notes");
            
            var result = MessageBox.Show(
                $"Notes for '{_task.Name}' have been modified.\n\nDo you want to save your changes?",
                "Unsaved Changes",
                MessageBoxButton.YesNoCancel,
                MessageBoxImage.Question);

            switch (result)
            {
                case MessageBoxResult.Yes:
                    SaveNotes();
                    return !_isModified; // Return true only if save was successful
                case MessageBoxResult.No:
                    Logger.Info("NotesDialog", "User chose not to save changes");
                    return true;
                case MessageBoxResult.Cancel:
                default:
                    Logger.Info("NotesDialog", "User cancelled close operation");
                    return false;
            }
        }

        #region Event Handlers

        private void NotesTextBox_TextChanged(object sender, System.Windows.Controls.TextChangedEventArgs e)
        {
            UpdateFileStatus();
            UpdateTextStats();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            Logger.Trace("NotesDialog", $"Key pressed: {e.Key}, Modifiers: {Keyboard.Modifiers}");

            // Handle keyboard shortcuts
            try
            {
                if (Keyboard.Modifiers == ModifierKeys.Control)
                {
                    switch (e.Key)
                    {
                        case Key.S:
                            Logger.Info("NotesDialog", "Ctrl+S pressed - saving notes");
                            SaveNotes();
                            e.Handled = true;
                            break;
                        case Key.W:
                            Logger.Info("NotesDialog", "Ctrl+W pressed - closing with save prompt");
                            if (PromptSaveIfModified())
                            {
                                DialogResult = true;
                                Close();
                            }
                            e.Handled = true;
                            break;
                    }
                }
                else if (e.Key == Key.Escape)
                {
                    Logger.Info("NotesDialog", "Escape pressed - closing with save prompt");
                    if (PromptSaveIfModified())
                    {
                        DialogResult = false;
                        Close();
                    }
                    e.Handled = true;
                }
                else if (e.Key == Key.F1)
                {
                    // Show help dialog
                    var helpText = "Notes Editor Keyboard Shortcuts:\n\n" +
                                  "Ctrl+S - Save notes\n" +
                                  "Ctrl+W - Save and close\n" +
                                  "Ctrl+Z - Undo\n" +
                                  "Ctrl+Y - Redo\n" +
                                  "Ctrl+A - Select all\n" +
                                  "Ctrl+X/C/V - Cut/Copy/Paste\n" +
                                  "Escape - Close (with save prompt)\n" +
                                  "F1 - Show this help\n\n" +
                                  "Text Navigation:\n" +
                                  "Arrow keys - Move cursor\n" +
                                  "Ctrl+Arrow - Jump by words\n" +
                                  "Home/End - Start/End of line\n" +
                                  "Ctrl+Home/End - Start/End of document\n" +
                                  "Page Up/Down - Scroll by page";
                    
                    MessageBox.Show(helpText, "Notes Editor Help", 
                        MessageBoxButton.OK, MessageBoxImage.Information);
                    e.Handled = true;
                }
            }
            catch (Exception ex)
            {
                Logger.Error("NotesDialog", "Error handling key down event", ex);
            }

            base.OnKeyDown(e);
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            Logger.TraceEnter();
            
            if (!PromptSaveIfModified())
            {
                e.Cancel = true;
                Logger.Info("NotesDialog", "Close operation cancelled by user");
            }
            else
            {
                Logger.Info("NotesDialog", "Notes dialog closing");
            }
            
            Logger.TraceExit();
            base.OnClosing(e);
        }

        #endregion
    }
}