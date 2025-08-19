namespace PraxisWpf.Interfaces
{
    /// <summary>
    /// Interface for services that can be automatically saved
    /// </summary>
    public interface IAutoSaveable
    {
        /// <summary>
        /// Determines if the service has unsaved changes
        /// </summary>
        bool HasUnsavedChanges();

        /// <summary>
        /// Performs the auto-save operation
        /// </summary>
        void AutoSave();

        /// <summary>
        /// Gets the display name of the service for logging
        /// </summary>
        string ServiceName { get; }
    }
}