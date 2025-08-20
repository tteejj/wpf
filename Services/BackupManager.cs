using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace PraxisWpf.Services
{
    /// <summary>
    /// Manages backup rotation and cleanup
    /// </summary>
    public class BackupManager
    {
        private readonly string _baseDirectory;
        private readonly int _maxBackups;
        private readonly string _backupPrefix = "backup_";

        public BackupManager(string dataFilePath, int maxBackups = 5)
        {
            Logger.TraceEnter($"dataFilePath={dataFilePath}, maxBackups={maxBackups}");

            _baseDirectory = Path.GetDirectoryName(dataFilePath) ?? ".";
            _maxBackups = Math.Max(1, maxBackups); // At least 1 backup

            Logger.Info("BackupManager", $"Initialized - Directory: {_baseDirectory}, Max backups: {_maxBackups}");
            Logger.TraceExit();
        }

        /// <summary>
        /// Creates a timestamped backup of the specified file
        /// </summary>
        public string CreateBackup(string sourceFilePath)
        {
            Logger.TraceEnter($"sourceFilePath={sourceFilePath}");

            try
            {
                if (!File.Exists(sourceFilePath))
                {
                    Logger.Warning("BackupManager", $"Source file does not exist: {sourceFilePath}");
                    return string.Empty;
                }

                var fileName = Path.GetFileName(sourceFilePath);
                var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                var backupFileName = $"{_backupPrefix}{fileName}_{timestamp}";
                var backupPath = Path.Combine(_baseDirectory, backupFileName);

                File.Copy(sourceFilePath, backupPath, overwrite: false);

                Logger.Info("BackupManager", $"Created backup: {backupPath}");

                // Clean up old backups
                CleanupOldBackups(fileName);

                Logger.TraceExit(returnValue: backupPath);
                return backupPath;
            }
            catch (Exception ex)
            {
                Logger.Error("BackupManager", "Failed to create backup", ex);
                Logger.TraceExit(returnValue: "empty");
                return string.Empty;
            }
        }

        /// <summary>
        /// Gets all backup files for a given base file, sorted by creation time (newest first)
        /// </summary>
        public List<BackupInfo> GetBackups(string baseFileName)
        {
            Logger.TraceEnter($"baseFileName={baseFileName}");

            try
            {
                if (string.IsNullOrWhiteSpace(baseFileName))
                {
                    Logger.Warning("BackupManager", "GetBackups called with empty baseFileName");
                    return new List<BackupInfo>();
                }

                var pattern = $@"^{Regex.Escape(_backupPrefix)}{Regex.Escape(baseFileName)}_(\d{8}_\d{6})$";
                var regex = new Regex(pattern);

                var backups = Directory.GetFiles(_baseDirectory)
                    .Select(f => new FileInfo(f))
                    .Where(fi => regex.IsMatch(fi.Name))
                    .OrderByDescending(fi => fi.CreationTime)
                    .Select(fi => new BackupInfo
                    {
                        FilePath = fi.FullName,
                        FileName = fi.Name,
                        CreationTime = fi.CreationTime,
                        Size = fi.Length
                    })
                    .ToList();

                Logger.Info("BackupManager", $"Found {backups.Count} backups for {baseFileName}");
                Logger.TraceExit(returnValue: $"{backups.Count} backups");
                return backups;
            }
            catch (Exception ex)
            {
                Logger.Error("BackupManager", "Failed to get backups", ex);
                Logger.TraceExit(returnValue: "empty list");
                return new List<BackupInfo>();
            }
        }

        /// <summary>
        /// Restores from the most recent backup
        /// </summary>
        public bool RestoreLatestBackup(string targetFilePath)
        {
            Logger.TraceEnter($"targetFilePath={targetFilePath}");

            try
            {
                var fileName = Path.GetFileName(targetFilePath);
                var backups = GetBackups(fileName);

                if (!backups.Any())
                {
                    Logger.Warning("BackupManager", $"No backups found for {fileName}");
                    Logger.TraceExit(returnValue: "false");
                    return false;
                }

                var latestBackup = backups.First(); // Already sorted newest first
                File.Copy(latestBackup.FilePath, targetFilePath, overwrite: true);

                Logger.Info("BackupManager", $"Restored from backup: {latestBackup.FileName}");
                Logger.TraceExit(returnValue: "true");
                return true;
            }
            catch (Exception ex)
            {
                Logger.Error("BackupManager", "Failed to restore from backup", ex);
                Logger.TraceExit(returnValue: "false");
                return false;
            }
        }

        /// <summary>
        /// Cleans up old backup files, keeping only the specified number of most recent backups
        /// </summary>
        private void CleanupOldBackups(string baseFileName)
        {
            Logger.TraceEnter($"baseFileName={baseFileName}");

            try
            {
                var backups = GetBackups(baseFileName);

                if (backups.Count <= _maxBackups)
                {
                    Logger.Debug("BackupManager", $"No cleanup needed - {backups.Count} backups <= {_maxBackups} max");
                    Logger.TraceExit();
                    return;
                }

                var backupsToDelete = backups.Skip(_maxBackups).ToList();

                foreach (var backup in backupsToDelete)
                {
                    try
                    {
                        File.Delete(backup.FilePath);
                        Logger.Debug("BackupManager", $"Deleted old backup: {backup.FileName}");
                    }
                    catch (Exception ex)
                    {
                        Logger.Warning("BackupManager", $"Failed to delete backup: {backup.FileName} - {ex.Message}");
                    }
                }

                Logger.Info("BackupManager", $"Cleanup completed - Deleted {backupsToDelete.Count} old backups");
            }
            catch (Exception ex)
            {
                Logger.Error("BackupManager", "Failed to cleanup old backups", ex);
            }

            Logger.TraceExit();
        }

        /// <summary>
        /// Gets backup statistics
        /// </summary>
        public BackupStats GetBackupStats()
        {
            Logger.TraceEnter();

            try
            {
                var allBackupFiles = Directory.GetFiles(_baseDirectory, $"{_backupPrefix}*")
                    .Select(f => new FileInfo(f))
                    .ToList();

                var stats = new BackupStats
                {
                    TotalBackups = allBackupFiles.Count,
                    TotalSizeBytes = allBackupFiles.Sum(f => f.Length),
                    OldestBackup = allBackupFiles.Count > 0 ? allBackupFiles.Min(f => f.CreationTime) : (DateTime?)null,
                    NewestBackup = allBackupFiles.Count > 0 ? allBackupFiles.Max(f => f.CreationTime) : (DateTime?)null
                };

                Logger.TraceExit(returnValue: $"{stats.TotalBackups} backups");
                return stats;
            }
            catch (Exception ex)
            {
                Logger.Error("BackupManager", "Failed to get backup stats", ex);
                return new BackupStats();
            }
        }

        /// <summary>
        /// Performs cleanup of all backup files older than specified days
        /// </summary>
        public int CleanupByAge(int maxAgeDays)
        {
            Logger.TraceEnter($"maxAgeDays={maxAgeDays}");

            try
            {
                var cutoffDate = DateTime.Now.AddDays(-maxAgeDays);
                var allBackupFiles = Directory.GetFiles(_baseDirectory, $"{_backupPrefix}*")
                    .Select(f => new FileInfo(f))
                    .Where(f => f.CreationTime < cutoffDate)
                    .ToList();

                var deletedCount = 0;
                foreach (var file in allBackupFiles)
                {
                    try
                    {
                        File.Delete(file.FullName);
                        deletedCount++;
                        Logger.Debug("BackupManager", $"Deleted aged backup: {file.Name}");
                    }
                    catch (Exception ex)
                    {
                        Logger.Warning("BackupManager", $"Failed to delete aged backup: {file.Name} - {ex.Message}");
                    }
                }

                Logger.Info("BackupManager", $"Age-based cleanup completed - Deleted {deletedCount} backups older than {maxAgeDays} days");
                Logger.TraceExit(returnValue: deletedCount.ToString());
                return deletedCount;
            }
            catch (Exception ex)
            {
                Logger.Error("BackupManager", "Failed to cleanup backups by age", ex);
                Logger.TraceExit(returnValue: "0");
                return 0;
            }
        }
    }

    /// <summary>
    /// Information about a backup file
    /// </summary>
    public class BackupInfo
    {
        public string FilePath { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
        public DateTime CreationTime { get; set; }
        public long Size { get; set; }
        
        public string FormattedSize => FormatBytes(Size);
        public string AgeDescription => GetAgeDescription(CreationTime);

        private static string FormatBytes(long bytes)
        {
            if (bytes < 1024) return $"{bytes} B";
            if (bytes < 1024 * 1024) return $"{bytes / 1024:F1} KB";
            if (bytes < 1024 * 1024 * 1024) return $"{bytes / (1024 * 1024):F1} MB";
            return $"{bytes / (1024 * 1024 * 1024):F1} GB";
        }

        private static string GetAgeDescription(DateTime creationTime)
        {
            var age = DateTime.Now - creationTime;
            if (age.TotalMinutes < 60) return $"{(int)age.TotalMinutes} min ago";
            if (age.TotalHours < 24) return $"{(int)age.TotalHours} hours ago";
            if (age.TotalDays < 7) return $"{(int)age.TotalDays} days ago";
            return creationTime.ToString("yyyy-MM-dd HH:mm");
        }
    }

    /// <summary>
    /// Backup statistics
    /// </summary>
    public class BackupStats
    {
        public int TotalBackups { get; set; }
        public long TotalSizeBytes { get; set; }
        public DateTime? OldestBackup { get; set; }
        public DateTime? NewestBackup { get; set; }

        public string FormattedTotalSize => TotalSizeBytes < 1024 * 1024 
            ? $"{TotalSizeBytes / 1024:F1} KB" 
            : $"{TotalSizeBytes / (1024 * 1024):F1} MB";
    }
}