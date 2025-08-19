using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace PraxisWpf.Services
{
    /// <summary>
    /// Provides atomic, safe file writing with backup functionality
    /// </summary>
    public class SafeFileWriter
    {
        private readonly string _baseFilePath;
        private readonly string _tempFilePath;
        private readonly string _backupFilePath;

        public SafeFileWriter(string filePath)
        {
            _baseFilePath = filePath;
            _tempFilePath = filePath + ".tmp";
            _backupFilePath = filePath + ".bak";
        }

        /// <summary>
        /// Performs atomic write operation with backup and validation
        /// </summary>
        public void SafeWrite(string content)
        {
            Logger.TraceEnter($"file={_baseFilePath}, content_length={content.Length}");

            try
            {
                // Step 1: Write to temporary file first
                Logger.Debug("SafeFileWriter", "Writing to temporary file");
                File.WriteAllText(_tempFilePath, content, Encoding.UTF8);

                // Step 2: Validate the temporary file
                Logger.Debug("SafeFileWriter", "Validating temporary file");
                if (!ValidateFile(_tempFilePath, content))
                {
                    Logger.Error("SafeFileWriter", "Temporary file validation failed");
                    throw new InvalidOperationException("Temporary file validation failed");
                }

                // Step 3: Create backup of existing file (if exists)
                if (File.Exists(_baseFilePath))
                {
                    Logger.Debug("SafeFileWriter", "Creating backup of existing file");
                    File.Copy(_baseFilePath, _backupFilePath, overwrite: true);
                }

                // Step 4: Atomic move - replace original with temp file
                Logger.Debug("SafeFileWriter", "Performing atomic file replacement");
                File.Move(_tempFilePath, _baseFilePath, overwrite: true);

                // Step 5: Final validation
                if (!ValidateFile(_baseFilePath, content))
                {
                    Logger.Error("SafeFileWriter", "Final file validation failed - restoring backup");
                    RestoreFromBackup();
                    throw new InvalidOperationException("Final file validation failed");
                }

                Logger.Info("SafeFileWriter", $"Successfully wrote {content.Length} characters to {_baseFilePath}");
            }
            catch (Exception ex)
            {
                Logger.Error("SafeFileWriter", "Safe write operation failed", ex);
                CleanupTempFile();
                throw;
            }
            finally
            {
                CleanupTempFile();
                Logger.TraceExit();
            }
        }

        /// <summary>
        /// Performs atomic write operation for JSON objects
        /// </summary>
        public void SafeWriteJson<T>(T data, JsonSerializerOptions options)
        {
            Logger.TraceEnter($"type={typeof(T).Name}");

            try
            {
                var jsonContent = JsonSerializer.Serialize(data, options);
                SafeWrite(jsonContent);
            }
            catch (Exception ex)
            {
                Logger.Error("SafeFileWriter", $"JSON serialization/write failed for {typeof(T).Name}", ex);
                throw;
            }

            Logger.TraceExit();
        }

        /// <summary>
        /// Restores file from backup if available
        /// </summary>
        public bool RestoreFromBackup()
        {
            Logger.TraceEnter();

            try
            {
                if (File.Exists(_backupFilePath))
                {
                    Logger.Info("SafeFileWriter", "Restoring file from backup");
                    File.Copy(_backupFilePath, _baseFilePath, overwrite: true);
                    Logger.Info("SafeFileWriter", "File restored successfully from backup");
                    Logger.TraceExit(returnValue: "true");
                    return true;
                }
                else
                {
                    Logger.Warning("SafeFileWriter", "No backup file available for restore");
                    Logger.TraceExit(returnValue: "false");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Logger.Error("SafeFileWriter", "Failed to restore from backup", ex);
                Logger.TraceExit(returnValue: "false");
                return false;
            }
        }

        /// <summary>
        /// Validates file content integrity
        /// </summary>
        private bool ValidateFile(string filePath, string expectedContent)
        {
            Logger.TraceEnter($"file={filePath}");

            try
            {
                if (!File.Exists(filePath))
                {
                    Logger.Warning("SafeFileWriter", "File does not exist for validation");
                    return false;
                }

                var actualContent = File.ReadAllText(filePath, Encoding.UTF8);
                var isValid = actualContent == expectedContent;

                if (!isValid)
                {
                    Logger.Error("SafeFileWriter", 
                        $"Content validation failed - expected {expectedContent.Length} chars, got {actualContent.Length} chars");
                }

                Logger.TraceExit(returnValue: isValid.ToString());
                return isValid;
            }
            catch (Exception ex)
            {
                Logger.Error("SafeFileWriter", "File validation failed", ex);
                Logger.TraceExit(returnValue: "false");
                return false;
            }
        }

        /// <summary>
        /// Validates JSON file can be deserialized
        /// </summary>
        public bool ValidateJsonFile<T>(string filePath, JsonSerializerOptions options)
        {
            Logger.TraceEnter($"file={filePath}, type={typeof(T).Name}");

            try
            {
                if (!File.Exists(filePath))
                {
                    Logger.Warning("SafeFileWriter", "JSON file does not exist for validation");
                    return false;
                }

                var content = File.ReadAllText(filePath, Encoding.UTF8);
                var obj = JsonSerializer.Deserialize<T>(content, options);
                var isValid = obj != null;

                Logger.TraceExit(returnValue: isValid.ToString());
                return isValid;
            }
            catch (Exception ex)
            {
                Logger.Error("SafeFileWriter", $"JSON validation failed for {typeof(T).Name} - {ex.Message}");
                Logger.TraceExit(returnValue: "false");
                return false;
            }
        }

        /// <summary>
        /// Cleans up temporary file if it exists
        /// </summary>
        private void CleanupTempFile()
        {
            try
            {
                if (File.Exists(_tempFilePath))
                {
                    File.Delete(_tempFilePath);
                    Logger.Debug("SafeFileWriter", "Cleaned up temporary file");
                }
            }
            catch (Exception ex)
            {
                Logger.Warning("SafeFileWriter", $"Failed to cleanup temporary file: {ex.Message}");
            }
        }

        /// <summary>
        /// Gets backup file info if available
        /// </summary>
        public FileInfo? GetBackupInfo()
        {
            return File.Exists(_backupFilePath) ? new FileInfo(_backupFilePath) : null;
        }

        /// <summary>
        /// Checks if main file exists and is readable
        /// </summary>
        public bool IsMainFileHealthy()
        {
            try
            {
                return File.Exists(_baseFilePath) && File.ReadAllText(_baseFilePath).Length > 0;
            }
            catch
            {
                return false;
            }
        }
    }
}