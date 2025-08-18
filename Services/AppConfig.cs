using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace PraxisWpf.Services
{
    public class LoggingConfig
    {
        public bool Enabled { get; set; } = true;
        public string Level { get; set; } = "Info"; // Trace, Debug, Info, Warning, Error, Critical
        public bool IncludeStackTrace { get; set; } = false;
        public bool IncludeThreadId { get; set; } = true;
        public bool EnablePerformanceLogging { get; set; } = false;
        public string LogFilePath { get; set; } = ""; // Empty means auto-generate
    }

    public class AppConfiguration
    {
        public LoggingConfig Logging { get; set; } = new LoggingConfig();
        public string DataFilePath { get; set; } = "data.json";
        public bool DebugMode { get; set; } = false;
    }

    public static class AppConfig
    {
        private static AppConfiguration? _config;
        private static readonly string _configFilePath = "app-config.json";

        public static AppConfiguration Current
        {
            get
            {
                if (_config == null)
                {
                    LoadConfiguration();
                }
                return _config!;
            }
        }

        public static void LoadConfiguration()
        {
            try
            {
                if (File.Exists(_configFilePath))
                {
                    var jsonString = File.ReadAllText(_configFilePath);
                    _config = JsonSerializer.Deserialize<AppConfiguration>(jsonString, new JsonSerializerOptions
                    {
                        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                        WriteIndented = true,
                        Converters = { new JsonStringEnumConverter() }
                    }) ?? new AppConfiguration();

                    // Initialize logging based on config
                    if (_config.Logging.Enabled)
                    {
                        var logLevel = Enum.Parse<LogLevel>(_config.Logging.Level, true);
                        Logger.Initialize(
                            logLevel,
                            _config.Logging.IncludeStackTrace,
                            _config.Logging.IncludeThreadId,
                            !string.IsNullOrEmpty(_config.Logging.LogFilePath) ? _config.Logging.LogFilePath : null);
                    }

                    Logger.Info("AppConfig", $"Configuration loaded from {_configFilePath}");
                }
                else
                {
                    // Create default configuration
                    _config = new AppConfiguration();
                    SaveConfiguration();
                    Logger.Info("AppConfig", $"Default configuration created at {_configFilePath}");
                }
            }
            catch (Exception ex)
            {
                // Fallback to default config if loading fails
                _config = new AppConfiguration();
                Logger.Error("AppConfig", "Failed to load configuration, using defaults", ex);
            }
        }

        public static void SaveConfiguration()
        {
            try
            {
                if (_config != null)
                {
                    var jsonString = JsonSerializer.Serialize(_config, new JsonSerializerOptions
                    {
                        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                        WriteIndented = true,
                        Converters = { new JsonStringEnumConverter() }
                    });
                    File.WriteAllText(_configFilePath, jsonString);
                    Logger.Debug("AppConfig", $"Configuration saved to {_configFilePath}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error("AppConfig", "Failed to save configuration", ex);
            }
        }

        public static void SetLogLevel(LogLevel level)
        {
            Current.Logging.Level = level.ToString();
            Logger.SetLevel(level);
            SaveConfiguration();
            Logger.Info("AppConfig", $"Log level changed to {level}");
        }

        public static void EnableDebugMode(bool enable = true)
        {
            Current.DebugMode = enable;
            if (enable)
            {
                SetLogLevel(LogLevel.Trace);
                Current.Logging.IncludeStackTrace = true;
                Current.Logging.EnablePerformanceLogging = true;
                Logger.EnableStackTrace(true);
            }
            SaveConfiguration();
            Logger.Info("AppConfig", $"Debug mode {(enable ? "enabled" : "disabled")}");
        }
    }
}