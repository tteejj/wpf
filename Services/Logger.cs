using System;
using System.IO;
using System.Runtime.CompilerServices;
using System.Threading;

namespace PraxisWpf.Services
{
    public enum LogLevel
    {
        Trace = 0,     // Every single operation, property access, method entry/exit
        Debug = 1,     // Detailed debugging info, state changes, data flow
        Info = 2,      // Normal operations, user actions, important state changes
        Warning = 3,   // Potential issues, fallback behaviors
        Error = 4,     // Errors that don't crash the app
        Critical = 5   // Errors that might crash the app
    }

    public static class Logger
    {
        private static readonly object _lockObject = new object();
        private static string _logFilePath = string.Empty;
        private static LogLevel _minLevel = LogLevel.Info;
        private static bool _isEnabled = true;
        private static bool _includeStackTrace = false;
        private static bool _includeThreadId = false;
        private static StreamWriter? _logWriter;

        static Logger()
        {
            Initialize();
        }

        public static void Initialize(
            LogLevel minLevel = LogLevel.Info,
            bool includeStackTrace = false,
            bool includeThreadId = true,
            string? customLogPath = null)
        {
            lock (_lockObject)
            {
                try
                {
                    _minLevel = minLevel;
                    _includeStackTrace = includeStackTrace;
                    _includeThreadId = includeThreadId;

                    // Close existing writer
                    _logWriter?.Close();

                    // Create log file path
                    _logFilePath = customLogPath ?? $"PraxisWpf_{DateTime.Now:yyyy-MM-dd}.log";
                    
                    // Ensure directory exists
                    var directory = Path.GetDirectoryName(_logFilePath);
                    if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                    {
                        Directory.CreateDirectory(directory);
                    }

                    // Create new writer
                    _logWriter = new StreamWriter(_logFilePath, append: true);
                    _logWriter.AutoFlush = true;

                    // Log initialization
                    WriteLog(LogLevel.Info, "Logger", "Logger initialized", 
                        $"Level={minLevel}, StackTrace={includeStackTrace}, ThreadId={includeThreadId}, Path={_logFilePath}");
                }
                catch (Exception ex)
                {
                    // If logging fails, disable it
                    _isEnabled = false;
                    Console.WriteLine($"Logger initialization failed: {ex.Message}");
                }
            }
        }

        public static void SetLevel(LogLevel level)
        {
            _minLevel = level;
            Info("Logger", $"Log level changed to {level}");
        }

        public static void EnableStackTrace(bool enable = true)
        {
            _includeStackTrace = enable;
            Info("Logger", $"Stack trace logging {(enable ? "enabled" : "disabled")}");
        }

        // Method entry/exit tracing
        public static void TraceEnter([CallerMemberName] string methodName = "", [CallerFilePath] string filePath = "", params object[] parameters)
        {
            if (!ShouldLog(LogLevel.Trace)) return;
            var className = GetClassNameFromPath(filePath);
            var paramStr = parameters.Length > 0 ? $" Params: [{string.Join(", ", parameters)}]" : "";
            WriteLog(LogLevel.Trace, className, $"→ ENTER {methodName}{paramStr}");
        }

        public static void TraceExit([CallerMemberName] string methodName = "", [CallerFilePath] string filePath = "", object? returnValue = null)
        {
            if (!ShouldLog(LogLevel.Trace)) return;
            var className = GetClassNameFromPath(filePath);
            var returnStr = returnValue != null ? $" Return: {returnValue}" : "";
            WriteLog(LogLevel.Trace, className, $"← EXIT {methodName}{returnStr}");
        }

        // Property access tracing
        public static void TraceProperty(string propertyName, object? oldValue, object? newValue, [CallerFilePath] string filePath = "")
        {
            if (!ShouldLog(LogLevel.Trace)) return;
            var className = GetClassNameFromPath(filePath);
            WriteLog(LogLevel.Trace, className, $"Property {propertyName}: {oldValue} → {newValue}");
        }

        // Data operation tracing
        public static void TraceData(string operation, string target, object? data = null, [CallerFilePath] string filePath = "")
        {
            if (!ShouldLog(LogLevel.Trace)) return;
            var className = GetClassNameFromPath(filePath);
            var dataStr = data != null ? $" Data: {data}" : "";
            WriteLog(LogLevel.Trace, className, $"DATA {operation} on {target}{dataStr}");
        }

        // Standard logging methods
        public static void Trace(string category, string message, string? details = null)
        {
            WriteLog(LogLevel.Trace, category, message, details);
        }

        public static void Debug(string category, string message, string? details = null)
        {
            WriteLog(LogLevel.Debug, category, message, details);
        }

        public static void Info(string category, string message, string? details = null)
        {
            WriteLog(LogLevel.Info, category, message, details);
        }

        public static void Warning(string category, string message, string? details = null)
        {
            WriteLog(LogLevel.Warning, category, message, details);
        }

        public static void Error(string category, string message, Exception? exception = null, string? details = null)
        {
            var errorDetails = details ?? "";
            if (exception != null)
            {
                errorDetails += $" Exception: {exception.GetType().Name}: {exception.Message}";
                if (_includeStackTrace)
                {
                    errorDetails += $"\nStack: {exception.StackTrace}";
                }
            }
            WriteLog(LogLevel.Error, category, message, errorDetails);
        }

        public static void Critical(string category, string message, Exception? exception = null, string? details = null)
        {
            var errorDetails = details ?? "";
            if (exception != null)
            {
                errorDetails += $" Exception: {exception.GetType().Name}: {exception.Message}";
                errorDetails += $"\nStack: {exception.StackTrace}"; // Always include stack trace for critical
            }
            WriteLog(LogLevel.Critical, category, message, errorDetails);
        }

        // Performance logging
        public static IDisposable TracePerformance(string operation, [CallerFilePath] string filePath = "")
        {
            return new PerformanceTracker(operation, GetClassNameFromPath(filePath));
        }

        public static bool ShouldLog(LogLevel level)
        {
            return _isEnabled && level >= _minLevel;
        }

        private static void WriteLog(LogLevel level, string category, string message, string? details = null)
        {
            if (!ShouldLog(level)) return;

            lock (_lockObject)
            {
                try
                {
                    var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                    var threadId = _includeThreadId ? $"[T{Thread.CurrentThread.ManagedThreadId:D2}]" : "";
                    var levelStr = level.ToString().ToUpper().PadRight(8);
                    var categoryStr = category.PadRight(20);
                    
                    var logLine = $"{timestamp} {threadId}{levelStr} {categoryStr} {message}";
                    
                    if (!string.IsNullOrEmpty(details))
                    {
                        logLine += $" | {details}";
                    }

                    _logWriter?.WriteLine(logLine);

                    // For critical errors, also write to console as backup
                    if (level == LogLevel.Critical)
                    {
                        Console.WriteLine($"CRITICAL: {message}");
                    }
                }
                catch
                {
                    // If logging fails, disable it to prevent cascading failures
                    _isEnabled = false;
                }
            }
        }

        private static string GetClassNameFromPath(string filePath)
        {
            if (string.IsNullOrEmpty(filePath)) return "Unknown";
            var fileName = Path.GetFileNameWithoutExtension(filePath);
            return fileName;
        }

        public static void Dispose()
        {
            lock (_lockObject)
            {
                _logWriter?.Close();
                _logWriter?.Dispose();
                _logWriter = null;
            }
        }
    }

    public class PerformanceTracker : IDisposable
    {
        private readonly string _operation;
        private readonly string _category;
        private readonly DateTime _startTime;
        private bool _disposed = false;

        public PerformanceTracker(string operation, string category)
        {
            _operation = operation;
            _category = category;
            _startTime = DateTime.Now;
            Logger.Trace(_category, $"PERF START: {_operation}");
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                var elapsed = DateTime.Now - _startTime;
                Logger.Debug(_category, $"PERF END: {_operation}", $"Duration: {elapsed.TotalMilliseconds:F2}ms");
                _disposed = true;
            }
        }
    }
}